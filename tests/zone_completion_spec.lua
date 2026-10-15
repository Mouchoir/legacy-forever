-- Run from the repository root: luajit tests/zone_completion_spec.lua
-- ns.ZoneCompletion over the real Model and Saved, with the game's progress, the quest source and the clock faked.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

-- Zones 1 and 2 sit on continent 10, zones 3 and 4 on continent 20, the rest on continent 30. Zone 4 has nothing
-- to count; the others have one area each, zone 1 a dungeon wing too and zone 5 a Legacy objective. Zones 1 and 9
-- have quests.
---@param key string
local function OneArea(key)
	return {
		areas = { { name = key, key = key } },
		taxis = {},
		dungeons = {},
		raids = {},
		legacy = {},
		reputations = {},
	}
end
local data = {
	completion = {
		[1] = {
			areas = { { name = "North", key = "a" } },
			taxis = {
				{ node = 7, name = "Ours", faction = "Alliance" },
				{ node = 8, name = "Theirs", faction = "Horde" },
			},
			dungeons = { { name = "Wing", refs = { { 900, 1 } } } },
			raids = {},
			legacy = {},
			reputations = {},
		},
		[2] = OneArea("b"),
		[3] = OneArea("c"),
		[4] = { areas = {}, taxis = {}, dungeons = {}, raids = {}, legacy = {}, reputations = {} },
		[5] = OneArea("e"),
		[6] = OneArea("f"),
		[7] = OneArea("g"),
		[8] = OneArea("h"),
		[9] = OneArea("i"),
	},
}
data.completion[5].legacy = { { name = "Step", refs = { { 901, 1 } } } }
local continents = { 10, 10, 20, 20, 30, 30, 30, 30, 30 }

-- Steps done by achievement: the wing is 900, zone 5's Legacy objective 901.
local explored, stepsDone, taxis = {}, { [900] = false, [901] = false }, {}
local now = 100
local live, printed, questReads = {}, {}, {}
local currentZone = 1
local completed = { [501] = true }
-- A cold QuestieDB index: a deferred read sees it as loading (false) instead of building it.
local questsCold = false
local zoneQuests = {
	[1] = { { name = "Wolves", ids = { 501 } }, { name = "Bears", ids = { 502 } } },
	[9] = { { name = "Boars", ids = { 503 } } },
}
local ns = { Data = data }
ns.Live = {
	-- One shared table per zone, as the real one caches it.
	ZoneSnapshot = function(uiMapID)
		return {
			explored = explored,
			taxis = taxis,
			faction = "Alliance",
			criteria = function(achievementID)
				local done = stepsDone[achievementID]
				if done ~= nil then
					return { { completed = done } }
				end
			end,
			reaction = function()
				return 0
			end,
			quests = function()
				return ns.Quests.Zone(uiMapID)
			end,
			completed = completed,
		}
	end,
	ContinentOf = function(uiMapID)
		return continents[uiMapID]
	end,
	CurrentZone = function()
		return currentZone
	end,
	OnChange = function(callback)
		live[#live + 1] = callback
	end,
}
-- Progress changed: what Live tells its listeners after a burst of game events.
local function Progress()
	for _, callback in ipairs(live) do
		callback()
	end
end
ns.Quests = {
	Zone = function(uiMapID, deferred)
		questReads[#questReads + 1] = deferred == true
		if questsCold and deferred then
			return false
		end
		return zoneQuests[uiMapID] or {}
	end,
	Cold = function()
		return questsCold
	end,
	Status = function()
		return "ready"
	end,
	Failure = function()
		return nil
	end,
}
function ns.Print(msg)
	printed[#printed + 1] = msg
end
GetTime = function()
	return now
end
C_Map = {
	GetMapInfo = function()
		return { name = "Elwynn Forest" }
	end,
}

for _, file in ipairs({ "Core/Saved.lua", "Core/Model.lua", "Core/ZoneCompletion.lua" }) do
	assert(loadfile(file))("LegacyForever", ns)
end
local Zones, Saved = ns.ZoneCompletion, ns.Saved
check(#live == 1, "one listener on the game's progress")

local changes, news = 0, {}
Zones.OnChange(function()
	changes = changes + 1
end)
Zones.OnComplete(function(uiMapID)
	news[#news + 1] = uiMapID
end)

--[[ Results ]]

-- A new save file counts areas and dungeons, not flight paths or quests.
local result = assert(Zones.Result(1))
check(result.done == 0 and result.total == 2 and result.percent == 0, "an area and a wing, neither done")
check(result.areas and result.dungeons and not result.taxis and not result.quests, "only what counts is in the result")
check(Zones.IsCounted("areas") and not Zones.IsCounted("quests"), "what counts reads the saved switches")
check(Zones.Result(99) == nil and Zones.Result(nil) == nil and Zones.Of(99) == nil, "no data, no result")
check(
	Zones.Result(4).total == 0 and Zones.Of(4) == nil,
	"a zone with nothing to count has a result but nothing to draw"
)
check(Zones.Of(1).total == 2, "a zone with something to count is drawn")

-- Flight paths are the player's side only, in the result and in the audit.
LegacyForeverDB = { zoneCompletion = { count_taxis = true, count_quests = true } }
taxis[7] = false
result = assert(Zones.Result(1))
check(result.taxis.total == 1 and result.taxis.left[1] == "Ours", "the other side's flight path is left out")
Zones.Audit()
local audit = table.concat(printed, "\n")
check(audit:find("flight path 7 (Ours): not known", 1, true), "the audit lists the player's flight path")
check(not audit:find("Theirs", 1, true), "the audit leaves out the other side's, as the count does")
check(audit:find("areas 0/1, taxis 0/1, dungeons 0/1", 1, true), "the audit counts every category, ticked or not")

-- Quests: every result reads them deferred, so no draw builds QuestieDB's index; only the typed audit reads
-- them in full. The rest of the snapshot (here the turned-in quests) reaches both the same way.
questReads, printed = {}, {}
Zones.Audit()
check(#questReads == 1 and questReads[1] == false, "the audit reads the quests in full")
questReads = {}
result = assert(Zones.Result(1))
check(#questReads == 1 and questReads[1] == true, "a result reads the quests deferred")
check(result.quests.done == 1 and result.quests.total == 2, "one quest of two turned in")
questReads = {}
assert(Zones.Of(1))
Zones.Continent(10)
check(#questReads == 3, "the map's and tracker's reads read quests")
for _, wasDeferred in ipairs(questReads) do
	check(wasDeferred, "and every one of them deferred")
end
-- A cold index: the zone, its continent and the tracker's result all read quests as pending, never a build.
questsCold = true
local cold = assert(Zones.Of(1))
check(cold.quests.total == 0 and cold.quests.pending == 1, "a cold index draws the zone's quests as pending")
check(cold.done == result.done - 1 and cold.total == result.total - 2, "and leaves them out of the counts")
questsCold = false
check(assert(Zones.Of(1)).quests.total == 2, "the zone's quests are counted once the index is built")
LegacyForeverDB = nil
taxis[7] = nil

-- A continent: its zones that count something, and how many are complete.
explored.b = true
local continent = assert(Zones.Continent(10))
check(continent.zones == 2 and continent.complete == 1 and continent.percent == 50, "one of two zones complete")
check(Zones.Continent(20).zones == 1, "a zone with nothing to count is not one of the continent's zones")
check(Zones.Continent(40) == nil, "a continent with no zones has no result")
explored.b = nil

--[[ When a completion is news ]]

-- Complete at login is not news: the first check only notes it, and it never becomes news later.
explored.c = true
Progress()
check(changes == 1 and #news == 0, "a zone already complete at the first check is not news")
-- Still quiet a few seconds in, while the game is sending achievement progress.
now = now + 9
explored.b = true
Progress()
check(changes == 2 and #news == 0, "a completion inside the quiet window is not news")
now = now + 60
Progress()
check(#news == 0, "what the quiet window noted stays quiet afterwards")

-- Real progress after the window is news, once.
explored.a = true
Progress()
check(#news == 0, "a zone with a wing left is not complete")
stepsDone[900] = true
Progress()
check(#news == 1 and news[1] == 1, "finishing a zone is news")
Progress()
check(#news == 1 and changes == 6, "and only once, however often progress is checked")

--[[ What counts ]]

-- Unticking a category is not news, now or when progress is next checked.
explored.e = true
Progress()
check(#news == 1 and not Zones.Result(5).complete, "zone 5's Legacy objective is still left")
changes = 0
Saved.Set("count_legacy", false)
check(Zones.Result(5).complete and #news == 1, "unticking a category that completes a zone is not news")
check(changes == 1, "but what counts changing is a change")
Progress()
check(#news == 1, "nor is it news at the next progress check")

-- Nothing counted is neither complete nor news.
Saved.Set("count_areas", false)
explored.g = true
Progress()
check(#news == 1 and not Zones.Of(7), "a zone with nothing counted never completes")
Saved.Set("count_areas", true)
check(Zones.Result(7).complete and #news == 1, "ticking a category back is not news either")
Progress()
check(#news == 1, "nor afterwards")

-- Switched off entirely: completions are noted, not announced. One surface on is enough for news.
check(Zones.IsShown("map") and not Zones.IsShown("tracker"), "a new save file shows the map only")
Saved.Set("map", false)
explored.f = true
Progress()
check(#news == 1, "no news with zone completion off on the map and the tracker")
Saved.Set("tracker", true)
Progress()
check(#news == 1, "a completion noted while off is not announced on switching back on")
Saved.Set("count_legacy", true)
stepsDone[901] = true
Progress()
check(#news == 1, "a zone noted under other rules is not announced again")
explored.h = true
Progress()
check(#news == 2 and news[2] == 8, "with the tracker alone switched on, a completion is news")

--[[ The one notice ]]

changes = 0
Progress()
check(changes == 1, "progress is a change")
Saved.Set("map", true)
Saved.Set("tracker", false)
check(Zones.IsShown("map") and not Zones.IsShown("tracker"), "the surfaces read the saved switches")
check(changes == 3, "each surface switch is a change")
Saved.Set("count_quests", true)
check(changes == 4, "what counts is a change")
Saved.Set("mapCollapsed", true)
Saved.Set("trackerCollapsed", true)
Saved.Set("showAreas", false)
check(changes == 4, "a collapse state or another addon switch is not")
local order = {}
Zones.OnChange(function()
	order[#order + 1] = "second"
end)
Zones.OnChange(function()
	order[#order + 1] = "third"
end)
Progress()
check(
	changes == 5 and order[1] == "second" and order[2] == "third",
	"listeners hear once each, in the order registered"
)

--[[ News without building QuestieDB's index ]]

-- Checking for news reads every zone's quests deferred, so entering the world never builds the index.
check(Zones.IsCounted("quests"), "quests count here")
questReads = {}
Progress()
local plain = 0
for _, wasDeferred in ipairs(questReads) do
	plain = plain + (wasDeferred and 0 or 1)
end
check(#questReads > 0 and plain == 0, "checking for news reads every zone's quests deferred")

-- A cold index reads as loading: a zone otherwise done is pending, not complete and not noted, and when the
-- index is built (Live's next change) it is news like any other completion.
questsCold = true
explored.i = true
completed[503] = true
Progress()
check(#news == 2, "a zone whose quests are still loading is not complete")
questsCold = false
Progress()
check(#news == 3 and news[3] == 9, "once its quests are read, completing the zone is news")
Progress()
check(#news == 3, "and only once")

-- Only Quests counted, ticked on a cold index: the zone is still drawn, pending with no percent, and a zone
-- the tick completes is not news when the build's notice checks again a frame later.
zoneQuests[4] = { { name = "Kobolds", ids = { 504 } } }
completed[504] = true
for _, key in ipairs({ "quests", "areas", "taxis", "dungeons", "raids", "legacy", "reputations" }) do
	Saved.Set("count_" .. key, false)
end
questsCold = true
Saved.Set("count_quests", true)
local pending = assert(Zones.Of(4), "a zone whose only counted items are pending is drawn")
check(pending.total == 0 and pending.pending == 1 and pending.percent == nil, "pending, with no percent yet")
check(#news == 3, "nothing is complete while the quests load")
questsCold = false
Progress()
check(Zones.Result(4).complete and #news == 3, "a zone completed by ticking Quests is not news once they load")
Progress()
check(#news == 3, "nor at the next check")

print(("zone_completion_spec: %d checks passed"):format(checks))
