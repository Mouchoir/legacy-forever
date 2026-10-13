---@type string, LegacyForeverNamespace
local _, ns = ...

-- Zone completion without a frame: a zone's or continent's result under what the player counts, when a
-- completion is news, and the one notice that any of it may have changed. The tracker section, the map's
-- corner, the toast and the menu (UI/Completion.lua), the map and LegacyForever.API all read and listen here.
---@class LegacyZoneCompletion
local ZoneCompletion = {}
ns.ZoneCompletion = ZoneCompletion

-- Whether zone completion is drawn on a surface: the world map (its corner and the continent badges) or the
-- objective tracker.
---@param surface LegacySurface
---@return boolean
function ZoneCompletion.IsShown(surface)
	return ns.Saved.Get(surface)
end

-- "What counts": whether a category is part of the percentage.
---@param category LegacyCategoryKey
---@return boolean
function ZoneCompletion.IsCounted(category)
	return ns.Saved.Get("count_" .. category)
end

-- A zone's completion, even when nothing counts; nil for a map without completion data.
-- `deferred` reads the zone's quests without building QuestieDB's index (see Quests.Zone).
---@param uiMapID number?
---@param deferred? boolean
---@return LegacyZoneResult?
function ZoneCompletion.Result(uiMapID, deferred)
	local zone = uiMapID and ns.Data.completion[uiMapID]
	if not uiMapID or not zone then
		return nil
	end
	local snapshot = ns.Live.ZoneSnapshot(uiMapID)
	if deferred then
		-- The cached snapshot with only its quest read swapped.
		---@type LegacySnapshot
		snapshot = setmetatable({
			quests = function()
				return ns.Quests.Zone(uiMapID, true)
			end,
		}, { __index = snapshot })
	end
	return ns.Model.ZoneCompletion(zone, snapshot, ZoneCompletion.IsCounted)
end

-- What the map and tracker draw: the zone's completion, or nil when it has nothing to count.
---@param uiMapID number?
---@return LegacyZoneResult?
function ZoneCompletion.Of(uiMapID)
	local result = ZoneCompletion.Result(uiMapID)
	return result and result.total > 0 and result or nil
end

-- How many of a continent's zones are complete, counting what the player counts; nil when none counts anything.
-- Every zone on the continent is computed on each call.
---@param continentID number
---@return LegacyContinentResult?
function ZoneCompletion.Continent(continentID)
	local results = {}
	for uiMapID in pairs(ns.Data.completion) do
		if ns.Live.ContinentOf(uiMapID) == continentID then
			results[#results + 1] = ZoneCompletion.Result(uiMapID)
		end
	end
	return ns.Model.ContinentCompletion(results)
end

--[[ The one notice ]]

---@type (fun())[]
local listeners = {}

-- Called whenever a result or where it is drawn may have changed: progress, a quest source, the zone the
-- player is in, "What counts", or the map and tracker switches. Listeners run in the order registered.
---@param callback fun()
function ZoneCompletion.OnChange(callback)
	listeners[#listeners + 1] = callback
end

local function Changed()
	for _, callback in ipairs(listeners) do
		callback()
	end
end

--[[ A zone reaching 100% ]]

---@type (fun(uiMapID: number))[]
local completeListeners = {}

-- Called with a zone that has just reached 100% of what the player counts, once per zone per session, and
-- only when that is news (see CheckNews).
---@param callback fun(uiMapID: number)
function ZoneCompletion.OnComplete(callback)
	completeListeners[#completeListeners + 1] = callback
end

-- Zones already complete when you log in are not news. The first check (on entering the
-- world, however long the loading screen took) and those in the few seconds after it, while
-- the game is still sending achievement progress, only note completions.
local QUIET_SECONDS = 10
---@type number?
local quietUntil
---@type LegacySet
local rewarded = {}

-- The reward follows "What counts", as the percentage does, so 100% on screen is what earns it.
-- Read deferred: this runs for every zone on every progress change, the first just after entering the world,
-- and must not build QuestieDB's index there. A cold index reads as pending, so the zone is not complete and
-- not noted; the build on the next frame announces a change, and the zone is checked again with its quests.
---@param uiMapID number
---@return boolean
local function IsComplete(uiMapID)
	local result = ZoneCompletion.Result(uiMapID, true)
	---@cast result -nil
	return ns.Model.CompletionCounts(result) and result.complete
end

-- Unticking a category isn't progress, so a zone that completes that way (`silent`) is noted without news.
---@param silent? boolean
local function CheckNews(silent)
	quietUntil = quietUntil or GetTime() + QUIET_SECONDS
	local quiet = silent or GetTime() < quietUntil
	for uiMapID in pairs(ns.Data.completion) do
		if not rewarded[uiMapID] and IsComplete(uiMapID) then
			rewarded[uiMapID] = true
			-- Someone who has switched zone completion off entirely doesn't want its toasts.
			if not quiet and (ZoneCompletion.IsShown("map") or ZoneCompletion.IsShown("tracker")) then
				for _, callback in ipairs(completeListeners) do
					callback(uiMapID)
				end
			end
		end
	end
end

ns.Live.OnChange(function()
	Changed()
	CheckNews()
end)

-- A switch was saved, from the Legacy map menu, the Settings page or anywhere else. A counted category
-- re-checks completions silently before the notice. The collapse states redraw themselves where they are
-- clicked.
ns.Saved.OnChange(function(key)
	if key == "map" or key == "tracker" then
		Changed()
	elseif key:find("^count_") then
		CheckNews(true)
		Changed()
	end
end)

-- For /lf audit: the current zone's counts against what the game reports.
function ZoneCompletion.Audit()
	local uiMapID = ns.Live.CurrentZone()
	if not uiMapID then
		ns.Print("zone completion: no data for the zone you're in.")
		return
	end
	local zone = ns.Data.completion[uiMapID]
	local snapshot = ns.Live.ZoneSnapshot(uiMapID)
	local result = ns.Model.ZoneCompletion(zone, snapshot)
	local parts = {}
	for _, key in ipairs(ns.Model.COMPLETION_CATEGORIES) do
		local category = result[key]
		parts[#parts + 1] = category and ("%s %d/%d"):format(key, category.done, category.total) or (key .. " -")
	end
	ns.Print(("quests from QuestieDB: %s"):format(ns.Quests.Failure() or ns.Quests.Status()))
	ns.Print(
		("zone completion for %s (map %d): %s"):format(
			C_Map.GetMapInfo(uiMapID).name,
			uiMapID,
			table.concat(parts, ", ")
		)
	)

	local known = {}
	for _, area in ipairs(zone.areas) do
		known[area.key] = true
	end
	for key in pairs(snapshot.explored) do
		if not known[key] then
			ns.Print("  explored area not in the data: " .. key)
		end
	end
	if next(snapshot.explored) == nil then
		ns.Print("  the game reports nothing explored in this zone")
	end

	for _, taxi in ipairs(ns.Model.ForFaction(zone.taxis, snapshot.faction, "faction")) do
		local learned = snapshot.taxis[taxi.node]
		local state = learned == nil and "unknown until you open a flight master on this continent"
			or learned and "known"
			or "not known"
		ns.Print(("  flight path %d (%s): %s"):format(taxi.node, taxi.name, state))
	end
end
