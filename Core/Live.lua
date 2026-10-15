---@type string, LegacyForeverNamespace
local _, ns = ...

-- Reads progress from the game, rebuilt from live APIs each session. The one thing the
-- game won't say is which flight paths a character knows, so that is recorded (FlightRecord).
---@class LegacyLive
local Live = {}
ns.Live = Live

local LEGACY_POINTS_CURRENCY = 4225

---@type LegacySet?
local visible
---@type table<number, LegacyCriteria|false>
local criteriaCache = {}
---@type (fun())[]
local listeners = {}

-- The unfinished challenges the game lists for this character, exactly as the Legacy
-- panel enumerates them. The game's list also holds the helper achievements that feed
-- them; only reward-bearing challenges go in this set.
-- Completed ones are dropped here: an alt's own exploration can't advance a challenge
-- the account has already earned.
---@return LegacySet
function Live.Visible()
	if visible then
		return visible
	end
	visible = {}
	for _, categoryID in ipairs(GetCategoryList() or {}) do
		for index = 1, GetCategoryNumAchievements(categoryID) or 0 do
			local achievementID, _, _, completed = GetAchievementInfo(categoryID, index)
			if achievementID and ns.Data.rewards[achievementID] and not completed then
				visible[achievementID] = true
			end
		end
	end
	return visible
end

-- Criteria IDs the data places for each achievement, built once.
---@type table<number, number[]>?
local locatedByAchievement
---@param achievementID number
---@return number[]?
local function LocatedCriteria(achievementID)
	if not locatedByAchievement then
		locatedByAchievement = {}
		for _, entries in pairs(ns.Data.zones) do
			for _, entry in ipairs(entries) do
				local list = locatedByAchievement[entry.achievement] or {}
				list[#list + 1] = entry.criteria
				locatedByAchievement[entry.achievement] = list
			end
		end
	end
	return locatedByAchievement[achievementID]
end

-- A single-step achievement (e.g. Conqueror of the Lair) reports no criteria: the
-- achievement is the step, described by its description. File its completion under
-- the criterion the data placed, or under 0 (never placed) so it still counts as unplaced.
---@param achievementID number
---@return LegacyCriteria?
local function WholeAchievement(achievementID)
	local _, name, _, completed, _, _, _, description = GetAchievementInfo(achievementID)
	if not name then
		return nil
	end
	local text = description and description ~= "" and description or name
	local result = {}
	for _, criteriaID in ipairs(LocatedCriteria(achievementID) or { 0 }) do
		result[criteriaID] = { text = text, completed = completed, index = 1 }
	end
	return result
end

-- Criteria by ID rather than index: DB2 order and API order need not agree.
---@param achievementID number
---@return LegacyCriteria?
function Live.Criteria(achievementID)
	local cached = criteriaCache[achievementID]
	if cached ~= nil then
		return cached or nil
	end
	local result
	local count = GetAchievementNumCriteria(achievementID)
	if count and count > 0 then
		result = {}
		for index = 1, count do
			local text, criteriaType, completed, quantity, required, _, _, asset, _, criteriaID =
				GetAchievementCriteriaInfo(achievementID, index)
			if criteriaID then
				result[criteriaID] = {
					text = text,
					completed = completed,
					type = criteriaType,
					asset = asset,
					quantity = quantity,
					required = required,
					index = index,
				}
			end
		end
	end
	if count == 0 then
		result = WholeAchievement(achievementID)
	end
	criteriaCache[achievementID] = result or false
	return result
end

---@param achievementID number
---@return string
function Live.Name(achievementID)
	local _, name = GetAchievementInfo(achievementID)
	return name
end

---@param achievementID number
---@return number?
function Live.Points(achievementID)
	if not C_Traits or not C_Traits.GetTraitCurrencyForAchievement then
		return nil
	end
	local points = C_Traits.GetTraitCurrencyForAchievement(LEGACY_POINTS_CURRENCY, achievementID)
	return points and points > 0 and points or nil
end

-- The panel opens on its first page and only Legacy.SelectPage switches to the challenges page.
local CHALLENGES_PAGE = 2

-- The game keeps its Legacy panel shut until the reward track has renown, and its toggle then does nothing.
---@return boolean
function Live.PanelLocked()
	return C_MajorFactions.GetCurrentRenownLevel(Constants.LegacyConsts.LEGACY_REWARD_TRACK_FACTION_ID) <= 0
end

-- A menu entry that opens the panel: greyed out with the game's own reason while it is locked.
---@param button ElementMenuDescriptionProxy
function Live.LockPanelEntry(button)
	if Live.PanelLocked() then
		button:SetEnabled(false)
		button:SetTooltip(function(tooltip)
			GameTooltip_AddErrorLine(tooltip, LEGACY_MICRO_BUTTON_LOCKED_TOOLTIP)
		end)
	end
end

-- Opens Blizzard's Legacy panel on this challenge.
---@param achievementID number
function Live.ShowInLegacyPanel(achievementID)
	if Live.PanelLocked() then
		UIErrorsFrame:AddMessage(LEGACY_MICRO_BUTTON_LOCKED_TOOLTIP, RED_FONT_COLOR:GetRGB())
		return
	end
	if not (LegacySystemFrame and LegacySystemFrame:IsShown()) then
		ToggleLegacySystemUI()
	end
	EventRegistry:TriggerEvent("Legacy.SelectPage", CHALLENGES_PAGE)
	if AchievementFrame_SelectAchievement then
		AchievementFrame_SelectAchievement(achievementID, true)
	end
end

---@param callback fun()
function Live.OnChange(callback)
	listeners[#listeners + 1] = callback
end

-- CRITERIA_UPDATE fires in bursts (every kill, every discovered area), so
-- invalidation is immediate but listeners run once per burst.
local pending = false
local function Notify()
	pending = false
	for _, callback in ipairs(listeners) do
		ns.SafeCall("progress listener", callback)
	end
end

---@type table<number, LegacySnapshot>
local snapshots = {}
-- The quests this character has turned in, re-read after each invalidation and kept up to date by QUEST_TURNED_IN
-- in between.
---@type LegacySet?
local completedQuests

local function Changed()
	if not pending then
		pending = true
		C_Timer.After(0.5, Notify)
	end
end

function Live.Invalidate()
	visible = nil
	criteriaCache = {}
	snapshots = {}
	completedQuests = nil
	Changed()
end

-- A criterion moved without changing which challenges the game lists: an achievement that
-- completes fires ACHIEVEMENT_EARNED beside CRITERIA_UPDATE, so the list and the snapshots
-- (whose explored and known-flight-path parts did not move) are kept and only progress is read.
local function InvalidateProgress()
	criteriaCache = {}
	Changed()
end

-- A discovered area is both progress and the overlay the snapshot holds, so both are rebuilt.
local function InvalidateExploration()
	criteriaCache = {}
	snapshots = {}
	Changed()
end

-- A faction the player hasn't met yet has no data, which is simply not Friendly yet.
---@param factionID number
---@return number
local function Reaction(factionID)
	local data = C_Reputation.GetFactionDataByID(factionID)
	return data and data.reaction or 0
end

---@param texture UiMapExplorationInfo
local function OverlayKey(texture)
	return ("%d:%d:%d:%d"):format(texture.offsetX, texture.offsetY, texture.textureWidth, texture.textureHeight)
end

-- The continent a map sits on, or nil above continent level. The map hierarchy never changes, so
-- the walk is kept: a zone's continent is read again on every map badge, snapshot and tooltip.
---@type table<number, number>
local continents = {}
---@param uiMapID number
---@return number?
function Live.ContinentOf(uiMapID)
	local cached = continents[uiMapID]
	if cached then
		return cached
	end
	local info = C_Map.GetMapInfo(uiMapID)
	while info and info.mapType > Enum.UIMapType.Continent do
		info = C_Map.GetMapInfo(info.parentMapID)
	end
	local continent = info and info.mapType == Enum.UIMapType.Continent and info.mapID or nil
	if continent then
		continents[uiMapID] = continent
	end
	return continent
end

-- Which flight paths this character knows. Zone maps report every node as discovered on
-- Forever, so the only reliable source is a flight master's own list: opening one records
-- the known nodes for its continent. Until then that continent's flight paths are unknown.
---@return LegacyFlightRecord
local function FlightRecord()
	local records = ns.SavedTable("flightPaths")
	local guid = UnitGUID("player")
	-- UnitGUID can be absent before the player exists; do not index saved records with nil.
	if not guid then
		return { known = {}, continents = {} }
	end
	records[guid] = records[guid] or { known = {}, continents = {} }
	return records[guid]
end

local function RecordFlightMaster()
	local continent = Live.ContinentOf(C_Map.GetBestMapForUnit("player") or 0)
	if not continent then
		return
	end
	local nodes = C_TaxiMap.GetAllTaxiNodes(continent)
	if not nodes or #nodes == 0 then
		return
	end
	local record = FlightRecord()
	record.continents[continent] = true
	for _, node in ipairs(nodes) do
		record.known[node.nodeID] = node.state ~= Enum.FlightPathState.Unreachable or nil
	end
end

-- Nil until the game answers; an empty list is a new character's answer.
---@return LegacySet?
local function CompletedQuests()
	if not completedQuests and C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
		local ids = C_QuestLog.GetAllCompletedQuestIDs()
		if ids then
			completedQuests = {}
			for _, questID in ipairs(ids) do
				completedQuests[questID] = true
			end
		end
	end
	return completedQuests
end

-- Live progress for Model.ZoneCompletion.
---@param uiMapID number
---@return LegacySnapshot
function Live.ZoneSnapshot(uiMapID)
	local snapshot = snapshots[uiMapID]
	if snapshot then
		return snapshot
	end
	snapshot = {
		explored = {},
		taxis = {},
		faction = UnitFactionGroup("player"),
		criteria = Live.Criteria,
		reaction = Reaction,
		quests = function()
			return ns.Quests.Zone(uiMapID)
		end,
		completed = CompletedQuests(),
	}
	-- A zone this character has never entered reports no textures at all (nil), which
	-- means nothing explored yet rather than unknown.
	for _, texture in ipairs(C_MapExplorationInfo.GetExploredMapTextures(uiMapID) or {}) do
		snapshot.explored[OverlayKey(texture)] = true
	end
	local record = FlightRecord()
	if record.continents[Live.ContinentOf(uiMapID) or 0] then
		for _, taxi in ipairs(ns.Data.completion[uiMapID].taxis) do
			snapshot.taxis[taxi.node] = record.known[taxi.node] == true
		end
	end
	snapshots[uiMapID] = snapshot
	return snapshot
end

-- The zone the player is in, walking up from a cave or city sub-map to the first map
-- with completion data; nil on a continent or anywhere the data doesn't cover.
---@return number?
function Live.CurrentZone()
	local uiMapID = C_Map.GetBestMapForUnit("player")
	while uiMapID and not ns.Data.completion[uiMapID] do
		local info = C_Map.GetMapInfo(uiMapID)
		if not info or info.mapType <= Enum.UIMapType.Continent then
			return nil
		end
		uiMapID = info.parentMapID
	end
	return uiMapID
end

-- Only these can add or drop a challenge from the game's list, so only these reread it.
local LIST_CHANGES = { "ACHIEVEMENT_EARNED", "RECEIVED_ACHIEVEMENT_LIST", "PLAYER_ENTERING_WORLD" }
local PROGRESS_CHANGES = { "CRITERIA_UPDATE", "MAP_EXPLORATION_UPDATED" }
-- Flight paths and reputation feed only the zone snapshots.
local SNAPSHOT_CHANGES = { "TAXI_NODE_STATUS_CHANGED", "TAXIMAP_OPENED", "UPDATE_FACTION" }
local FLIGHT_MASTER = { TAXIMAP_OPENED = true, TAXI_NODE_STATUS_CHANGED = true }
-- Moving between zones changes which zone is shown, not anyone's progress.
local ZONE_CHANGES = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }

local events = CreateFrame("Frame")
for _, event in ipairs(LIST_CHANGES) do
	events:RegisterEvent(event)
end
for _, event in ipairs(PROGRESS_CHANGES) do
	events:RegisterEvent(event)
end
for _, event in ipairs(ZONE_CHANGES) do
	events:RegisterEvent(event)
end
for _, event in ipairs(SNAPSHOT_CHANGES) do
	events:RegisterEvent(event)
end
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function(_, event, questID)
	if tContains(ZONE_CHANGES, event) then
		Changed()
	elseif event == "QUEST_TURNED_IN" then
		-- The game's own list may not have the quest yet when this fires.
		if completedQuests and questID then
			completedQuests[questID] = true
		end
		snapshots = {}
		Changed()
	elseif event == "CRITERIA_UPDATE" then
		InvalidateProgress()
	elseif event == "MAP_EXPLORATION_UPDATED" then
		InvalidateExploration()
	elseif tContains(SNAPSHOT_CHANGES, event) then
		if FLIGHT_MASTER[event] then
			RecordFlightMaster()
		end
		snapshots = {}
		Changed()
	else
		Live.Invalidate()
	end
end)
