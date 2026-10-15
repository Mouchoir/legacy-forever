-- Run from the repository root: luajit tests/live_spec.lua
-- Core/Live.lua over a stubbed client: what it reads, what it keeps between reads, and which game
-- events make it read again.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

-- Challenges 100 and 101 carry rewards; 50 is a helper achievement the game lists beside them.
-- Achievement 60 is a single step the data places as criterion 77; 61 is one it never placed.
local ns = {
	Data = {
		rewards = { [100] = true, [101] = true },
		zones = { [2] = { { achievement = 60, criteria = 77, kind = "kill" } } },
		completion = { [2] = { taxis = { { node = 10 } } } },
	},
}
local records = {}
function ns.SavedTable(key)
	assert(key == "flightPaths")
	return records
end

local guid
UnitGUID = function()
	return guid
end
UnitFactionGroup = function()
	return "Alliance"
end
Enum = { UIMapType = { Continent = 2 }, FlightPathState = { Unreachable = 0 } }
local mapInfoReads = 0
C_Map = {
	GetMapInfo = function(id)
		mapInfoReads = mapInfoReads + 1
		return id == 2 and { mapID = 2, mapType = 3, parentMapID = 1 } or { mapID = 1, mapType = 2 }
	end,
	GetBestMapForUnit = function()
		return 2
	end,
}
C_MapExplorationInfo = {
	GetExploredMapTextures = function()
		return nil
	end,
}
C_TaxiMap = {
	GetAllTaxiNodes = function()
		return { { nodeID = 10, state = 1 } }
	end,
}
local questLogReads = 0
C_QuestLog = {
	GetAllCompletedQuestIDs = function()
		questLogReads = questLogReads + 1
		return { 1, 2 }
	end,
}
C_Reputation = {
	GetFactionDataByID = function(factionID)
		return factionID == 21 and { reaction = 4 } or nil
	end,
}
local timers = {}
C_Timer = {
	After = function(_, callback)
		timers[#timers + 1] = callback
	end,
}
tContains = function(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

-- The game's achievements. A criterion is { text, type, completed, quantity, required, asset, id }.
local achievements = {
	[100] = {
		name = "Explorer",
		criteria = { { "Reach level 20", 5, false, 12, 20, 0, 31 }, { "Explore Felwood", 8, true, 1, 1, 50, 30 } },
	},
	[101] = { name = "Earned", completed = true, criteria = {} },
	[50] = { name = "Explore Felwood", criteria = {} },
	[60] = { name = "Conqueror of the Lair", description = "Defeat Onyxia", criteria = {} },
	[61] = { name = "Unplaced", description = "", completed = true, criteria = {} },
}
local listed = { 100, 101, 50 }
-- Counts criteria reads, to tell a kept answer from a fresh one.
local criteriaReads = 0
GetCategoryList = function()
	return { 1 }
end
GetCategoryNumAchievements = function()
	return #listed
end
GetAchievementInfo = function(id, index)
	id = index and listed[index] or id
	local achievement = achievements[id]
	if achievement then
		return id, achievement.name, 0, achievement.completed == true, nil, nil, nil, achievement.description
	end
end
GetAchievementNumCriteria = function(id)
	criteriaReads = criteriaReads + 1
	return achievements[id] and #achievements[id].criteria
end
GetAchievementCriteriaInfo = function(id, index)
	local text, criteriaType, completed, quantity, required, asset, criteriaID =
		unpack(achievements[id].criteria[index])
	return text, criteriaType, completed, quantity, required, nil, nil, asset, nil, criteriaID
end

local onEvent
local registered = {}
CreateFrame = function()
	return {
		RegisterEvent = function(_, event)
			registered[event] = true
		end,
		SetScript = function(_, script, callback)
			assert(script == "OnEvent")
			onEvent = callback
		end,
	}
end

assert(loadfile("Core/SafeCall.lua"))("LegacyForever", ns)
assert(loadfile("Core/Live.lua"))("LegacyForever", ns)
local Live = ns.Live

-- Flight paths are recorded per character, from a flight master's own list.
local snapshot = Live.ZoneSnapshot(2)
check(next(records) == nil, "no GUID must not create a flight record")
check(snapshot.taxis[10] == nil, "flight paths remain unknown without a GUID")
onEvent(nil, "TAXIMAP_OPENED")
check(next(records) == nil, "an early flight-master event must not persist an anonymous record")
guid = "Player-test"
Live.Invalidate()
snapshot = Live.ZoneSnapshot(2)
check(records[guid] and snapshot.taxis[10] == nil, "a new character has no known continents")
onEvent(nil, "TAXIMAP_OPENED")
snapshot = Live.ZoneSnapshot(2)
check(snapshot.taxis[10] == true, "a later flight-master visit records this character's known nodes")
check(snapshot.completed[2] and not snapshot.completed[3], "turned-in quests come from the quest log")
onEvent(nil, "QUEST_TURNED_IN", 3)
snapshot = Live.ZoneSnapshot(2)
check(snapshot.completed[3], "a quest turned in since is counted without rereading the log")

-- What the game lists: unfinished reward-bearing challenges only.
local visible = Live.Visible()
check(visible[100] and not visible[101] and not visible[50], "finished challenges and helper achievements are left out")

-- Criteria are keyed by ID, with the game's order kept as `index`.
local steps = assert(Live.Criteria(100))
check(steps[31].index == 1 and steps[30].index == 2, "criteria are filed by ID, in game order")
check(steps[31].quantity == 12 and steps[31].required == 20 and not steps[31].completed, "a counted step's progress")
check(steps[30].type == 8 and steps[30].asset == 50 and steps[30].completed, "an earn-achievement step names it")
-- A single-step achievement reports no criteria: it is its own step.
local single = assert(Live.Criteria(60))
check(single[77].text == "Defeat Onyxia" and single[77].completed == false, "filed under the placed criterion")
check(single[77].index == 1 and single[0] == nil, "and nowhere else")
local unplaced = assert(Live.Criteria(61))
check(unplaced[0].text == "Unplaced" and unplaced[0].completed, "an unplaced one under 0, named when undescribed")
check(Live.Criteria(999) == nil, "an achievement the game doesn't know has no criteria")
check(Live.Name(100) == "Explorer", "names come from the game")
check(snapshot.criteria == Live.Criteria, "a zone snapshot reads steps through the same criteria")
check(snapshot.reaction(21) == 4 and snapshot.reaction(22) == 0, "a faction not met yet is not Friendly")

-- The map hierarchy never changes, so a map's continent is walked once and then kept.
local readsBefore = mapInfoReads
check(Live.ContinentOf(3) == 1, "a map on continent 1 reports it")
local afterWalk = mapInfoReads
check(afterWalk > readsBefore, "the first walk reads the map")
Live.ContinentOf(3)
check(mapInfoReads == afterWalk, "a map's continent is kept after the first walk")

-- Listeners run once per burst of events, half a second after the first.
local notified = 0
Live.OnChange(function()
	notified = notified + 1
end)
check(#timers == 1 and notified == 0, "the events so far asked for one deferred notice")
timers[1]()
check(notified == 1, "which runs the listeners once")

-- Fires a registered event twice, as a burst, and reports what Live then reads again.
---@param event string
---@param ... any
---@return { visible: boolean, criteria: boolean, snapshot: boolean, questLog: boolean } reread
local function Burst(event, ...)
	assert(registered[event], event .. " is not registered")
	timers, notified = {}, 0
	onEvent(nil, event, ...)
	onEvent(nil, event, ...)
	check(#timers == 1 and notified == 0, event .. ": one deferred notice for the burst")
	timers[1]()
	check(notified == 1, event .. ": listeners run once")
	local criteriaBefore, questLogBefore = criteriaReads, questLogReads
	Live.Criteria(100)
	local reread = { visible = Live.Visible() ~= visible, snapshot = Live.ZoneSnapshot(2) ~= snapshot }
	reread.criteria, reread.questLog = criteriaReads ~= criteriaBefore, questLogReads ~= questLogBefore
	visible, snapshot = Live.Visible(), Live.ZoneSnapshot(2)
	return reread
end

for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
	local reread = Burst(event)
	check(
		not (reread.visible or reread.criteria or reread.snapshot or reread.questLog),
		event .. ": moving between zones changes nobody's progress"
	)
end
for _, event in ipairs({ "TAXI_NODE_STATUS_CHANGED", "TAXIMAP_OPENED", "UPDATE_FACTION" }) do
	local reread = Burst(event)
	check(reread.snapshot, event .. ": zone snapshots are rebuilt")
	check(not (reread.visible or reread.criteria or reread.questLog), event .. ": achievements and quests are kept")
end
local turnedIn = Burst("QUEST_TURNED_IN", 4)
check(turnedIn.snapshot and snapshot.completed[4], "QUEST_TURNED_IN: zone snapshots are rebuilt with the quest")
check(not (turnedIn.visible or turnedIn.criteria or turnedIn.questLog), "QUEST_TURNED_IN: nothing else is reread")
for _, event in ipairs({ "ACHIEVEMENT_EARNED", "RECEIVED_ACHIEVEMENT_LIST", "PLAYER_ENTERING_WORLD" }) do
	local reread = Burst(event)
	check(
		reread.visible and reread.criteria and reread.snapshot and reread.questLog,
		event .. ": everything is read from the game again"
	)
end
-- Progress moves without changing which challenges the game lists, so the list is kept.
for _, event in ipairs({ "CRITERIA_UPDATE", "MAP_EXPLORATION_UPDATED" }) do
	local reread = Burst(event)
	check(reread.criteria, event .. ": criteria are read again")
	check(not reread.visible and not reread.questLog, event .. ": the list and the quest log are kept")
end
-- A discovered area also moves the explored overlays a snapshot holds.
check(Burst("MAP_EXPLORATION_UPDATED").snapshot, "MAP_EXPLORATION_UPDATED: zone snapshots are rebuilt")
check(not Burst("CRITERIA_UPDATE").snapshot, "CRITERIA_UPDATE: zone snapshots are kept")
local count = 0
for _ in pairs(registered) do
	count = count + 1
end
check(count == 12, "no event is registered without a check above")

-- Between events an answer is kept, known or not.
local before = criteriaReads
Live.Criteria(100)
Live.Criteria(999)
Live.Criteria(999)
check(criteriaReads == before + 1, "criteria are read once, even when the game has none")
print(("live_spec: %d checks passed"):format(checks))
