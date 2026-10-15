---@type string, LegacyForeverNamespace
local _, ns = ...

-- LegacyForever.API: zone completion and the zone's unfinished Legacy objectives for other addons, read from
-- the same computations the map and tracker draw. Every call returns fresh tables. docs/api.md has the contract.
-- Areas, flight paths, reputations and quests are this character's; dungeon wings, raids and Legacy
-- objectives are account-wide Legacy steps.
---@type table<LegacyCategoryKey, "character"|"account">
local SCOPES = {
	areas = "character",
	taxis = "character",
	dungeons = "account",
	raids = "account",
	legacy = "account",
	reputations = "character",
	quests = "character",
}
local MAX_TARGETS = 5

-- NaN and infinities fail `% 1 == 0`.
---@param value any
---@return boolean
local function IsInteger(value)
	return type(value) == "number" and value % 1 == 0
end

---@return "disabled"|"ready"|"loading"|"missing"|"unsupported"
local function QuestsStatus()
	if not ns.ZoneCompletion.IsCounted("quests") then
		return "disabled"
	end
	if ns.Quests.Cold() then
		return "loading"
	end
	return ns.Quests.Status()
end

---@param map integer
---@return LFZoneSummary?
---@return LFReadError?
local function ZoneSummary(map)
	if not IsInteger(map) then
		return nil, "invalid"
	end
	if not ns.Data.completion[map] then
		return nil, "unsupported"
	end
	-- Flight paths and reputations are filtered by side, which the game reports once the player exists.
	if not UnitFactionGroup("player") then
		return nil, "loading"
	end
	local result = assert(ns.ZoneCompletion.Result(map))
	---@type LFCategorySummary[]
	local categories = {}
	for _, key in ipairs(ns.Model.COMPLETION_CATEGORIES) do
		local category = result[key]
		if category then
			categories[#categories + 1] = {
				key = key,
				scope = SCOPES[key],
				done = category.done,
				total = category.total,
				pending = category.pending,
				complete = category.complete,
			}
		end
	end
	local info = C_Map.GetMapInfo(map)
	return {
		map = map,
		name = info and info.name or "",
		done = result.done,
		total = result.total,
		pending = result.pending,
		-- A zone with nothing counted is neither complete nor incomplete.
		complete = result.complete and ns.Model.CompletionCounts(result),
		categories = categories,
		questsStatus = QuestsStatus(),
	}
end

-- A target's key: its criterion, which appears at most once in a zone's data.
---@param entry LegacyEntry
---@return string
local function Key(entry)
	return ("%d:%d"):format(entry.achievement, entry.criteria)
end

-- The zone's unfinished objectives of visible challenges, in the data's order.
---@param map integer
---@return LegacyObjective[]
local function Objectives(map)
	local objectives = {}
	for _, group in ipairs(ns.Model.ZoneObjectives(ns.Data, map, ns.Live.Visible(), ns.Live.Criteria)) do
		for _, objective in ipairs(group.objectives) do
			objectives[#objectives + 1] = objective
		end
	end
	return objectives
end

---@param map integer
---@return boolean
local function KnownMap(map)
	return ns.Data.zones[map] ~= nil or ns.Data.completion[map] ~= nil
end

---@param map integer
---@param limit integer
---@return LFTarget[]?
---@return LFReadError?
local function Targets(map, limit)
	if not IsInteger(map) or type(limit) ~= "number" or limit ~= limit then
		return nil, "invalid"
	end
	if not KnownMap(map) then
		return nil, "unsupported"
	end
	limit = math.max(1, math.min(MAX_TARGETS, math.floor(limit)))
	---@type LFTarget[]
	local targets = {}
	for _, objective in ipairs(Objectives(map)) do
		if #targets == limit then
			break
		end
		local entry = objective.entry
		---@type LFTarget
		local target = {
			key = Key(entry),
			text = objective.text,
			kind = entry.kind,
			achievementID = entry.achievement,
			criteriaID = entry.criteria,
		}
		local progress = (ns.Live.Criteria(entry.achievement) or {})[entry.criteria]
		if progress and progress.required and progress.required > 1 then
			target.quantity = progress.quantity
			target.required = progress.required
		end
		if entry.x and entry.y then
			target.place = { map = map, x = entry.x, y = entry.y }
		end
		targets[#targets + 1] = target
	end
	return targets
end

---@param value number?
---@return boolean
local function Normalised(value)
	return type(value) == "number" and value >= 0 and value <= 1
end

---@param map integer
---@param key string
---@return boolean
---@return LFNavError?
local function Navigate(map, key)
	if not IsInteger(map) or type(key) ~= "string" or not KnownMap(map) or not key:find("^%d+:%d+$") then
		return false, "invalid"
	end
	-- Read again rather than trusted: the objective may have been finished since the key was handed out.
	for _, objective in ipairs(Objectives(map)) do
		local entry = objective.entry
		if Key(entry) == key then
			if not (Normalised(entry.x) and Normalised(entry.y)) then
				return false, "unlocated"
			end
			local guided, reason = ns.Guide(map, entry.x, entry.y, objective.text)
			return guided, reason
		end
	end
	return false, "stale"
end

---@class LegacySubscription
---@field callback fun()
---@field active boolean

---@type LegacySubscription[]
local subscriptions = {}

---@param callback fun()
---@return fun()
local function Subscribe(callback)
	if type(callback) ~= "function" then
		error("LegacyForever.API.Subscribe: callback must be a function", 2)
	end
	---@type LegacySubscription
	local subscription = { callback = callback, active = true }
	subscriptions[#subscriptions + 1] = subscription
	return function()
		subscription.active = false
		for index, other in ipairs(subscriptions) do
			if other == subscription then
				table.remove(subscriptions, index)
				return
			end
		end
	end
end

-- Progress, a quest source or "What counts" changed. A copy, so a callback may unsubscribe; errors go to the
-- game's error handler without stopping the other subscribers.
ns.ZoneCompletion.OnChange(function()
	local current = {}
	for index, subscription in ipairs(subscriptions) do
		current[index] = subscription
	end
	for _, subscription in ipairs(current) do
		if subscription.active then
			xpcall(subscription.callback, geterrorhandler())
		end
	end
end)

LegacyForever = {
	API = { version = 1, ZoneSummary = ZoneSummary, Targets = Targets, Navigate = Navigate, Subscribe = Subscribe },
}
