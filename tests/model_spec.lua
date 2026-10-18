-- Run from the repository root: luajit tests/model_spec.lua
local ns = {}
assert(loadfile("Core/Model.lua"))("LegacyForever", ns)
local Model = ns.Model
local checks = 0

local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Two reward variants (100, 200) fed by one exploration achievement (10); a kill
-- criterion placed directly on reward 100; a level criterion with no place.
local data = {
	rewards = { [100] = true, [200] = true },
	feeds = { [10] = { 100, 200 } },
	zones = {
		[1] = {
			{ achievement = 10, criteria = 1, kind = "explore", x = 0.1, y = 0.2 },
			{ achievement = 10, criteria = 2, kind = "explore" },
			{ achievement = 100, criteria = 3, kind = "kill" },
		},
		[2] = { { achievement = 10, criteria = 4, kind = "explore" } },
	},
}

local live = {
	[10] = {
		[1] = { text = "Area A", completed = false, index = 1 },
		[2] = { text = "Area B", completed = true, index = 2 },
		[4] = { text = "Area C", completed = false, index = 3 },
		[8] = { text = "Unplaced area", completed = false, index = 4 },
	},
	[100] = {
		[3] = { text = "Boss", completed = false, index = 2 },
		[5] = { text = "Reach level 20", completed = false, index = 1, quantity = 12, required = 20 },
		[6] = { text = "Explore", completed = false, index = 3, type = 8, asset = 10 },
		[7] = { text = "Done already", completed = true, index = 4 },
	},
}
local function criteria(id)
	return live[id]
end

-- Ownership follows whichever variant the client lists.
equal(Model.OwningChallenge(data, 10, { [200] = true }), 200, "feeding achievement owned by visible variant")
equal(Model.OwningChallenge(data, 100, { [100] = true }), 100, "challenge owns itself")
equal(Model.OwningChallenge(data, 10, {}), nil, "no visible owner")

local visible = { [100] = true }
local groups = Model.ZoneObjectives(data, 1, visible, criteria)
equal(#groups, 2, "one group per holding achievement")
equal(groups[1].achievement, 10, "exploration group first, in data order")
equal(groups[1].challenge, 100, "exploration group credits the visible challenge")
equal(#groups[1].objectives, 1, "completed area left out")
equal(groups[1].objectives[1].text, "Area A", "live criterion text")
equal(groups[2].objectives[1].entry.kind, "kill", "direct objective kept")
equal(Model.CountObjectives(groups), 2, "count across groups")
equal(("%d/%d"):format(Model.Tally(live[10])), "1/4", "done and total of an achievement's criteria")

-- A cleared dungeon or raid entrance is kept only when asked for, so the map can fade it.
local entrance = {
	rewards = { [100] = true },
	feeds = {},
	zones = { [1] = { { achievement = 100, criteria = 3, kind = "instance", x = 0.4, y = 0.5 } } },
}
local cleared = { [100] = { [3] = { text = "The Deadmines", completed = true, index = 1 } } }
local function clearedProgress(id)
	return cleared[id]
end
equal(
	#Model.ZoneObjectives(entrance, 1, visible, clearedProgress),
	0,
	"a cleared entrance is not an unfinished objective"
)
local kept = Model.ZoneObjectives(entrance, 1, visible, clearedProgress, true)
equal(#kept, 1, "with includeDone a cleared entrance is kept")
equal(kept[1].objectives[1].done, true, "and marked done")
equal(kept[1].objectives[1].entry.kind, "instance", "the cleared entrance")

equal(#Model.ZoneObjectives(data, 1, {}, criteria), 0, "nothing without a visible challenge")
equal(#Model.ZoneObjectives(data, 3, visible, criteria), 0, "unknown map")
local unknown = Model.ZoneObjectives(data, 1, visible, function()
	return nil
end)
equal(#unknown, 0, "unknown progress is not shown as unfinished")

-- Located criteria are excluded; "earn achievement 10" counts only 10's unplaced criteria.
local unlocated = Model.Unlocated(data, visible, criteria)
equal(#unlocated, 1, "one challenge with unplaced work")
equal(unlocated[1].challenge, 100, "unplaced challenge")
equal(unlocated[1].open, 2, "the level criterion plus the unplaced area under 10")
equal(#Model.Unlocated(data, { [200] = true }, criteria), 0, "variant without live criteria")

-- Tracker: unfinished steps in game order, with counts and sub-achievement progress.
local lines = Model.TrackerLines(100, criteria)
equal(#lines, 3, "completed step left out of the tracker")
equal(lines[1].text, "Reach level 20", "tracker follows game order")
equal(lines[1].detail, "12/20", "counted criterion shows quantity")
equal(lines[2].detail, nil, "single step has no count")
equal(lines[3].detail, "1/4", "earn-achievement step shows its criteria done")
equal(#Model.TrackerLines(999, criteria), 0, "unknown challenge has no lines")

-- Tracking from the map menu keys one zone's share, not the whole challenge.
equal(Model.ZoneKey(groups[1]), "10", "a feeding achievement is tracked as itself")
equal(Model.ZoneKey(groups[2]), "100:1", "a challenge's own objectives are tracked per zone")
equal(Model.TrackedChallenge(data, "10", { [200] = true }), 200, "a zone share follows the visible variant")
equal(Model.TrackedChallenge(data, "100:1", visible), 100, "a zone share of a challenge")
equal(Model.TrackedChallenge(data, 100, visible), 100, "a number is the whole challenge")
equal(Model.TrackedChallenge(data, 100, {}), nil, "a challenge the game doesn't list")

local function name(id)
	return "Achievement " .. id
end
local function Blocks(tracked, lookup)
	return Model.TrackedBlocks(data, tracked, visible, lookup or criteria, name)
end
local function Text(line)
	return line.detail and (line.detail .. " " .. line.text) or line.text
end

local blocks = Blocks({ "10", "100:1" })
equal(#blocks, 1, "zone shares of one challenge share its block")
equal(blocks[1].challenge, 100, "the block is the challenge")
equal(blocks[1].whole, nil, "tracked only through zones")
equal(#blocks[1].lines, 2, "one line per zone share, no whole-challenge steps")
equal(Text(blocks[1].lines[1]), "1/4 Achievement 10", "a feeding achievement's progress under its name")
equal(Text(blocks[1].lines[2]), "Boss", "a challenge's own objective in that zone")

blocks = Blocks({ 100 })
equal(#blocks[1].lines, 3, "a saved whole challenge still shows every step")
equal(Text(blocks[1].lines[1]), "12/20 Reach level 20", "whole-challenge steps in game order")

blocks = Blocks({ "10", 100 })
equal(blocks[1].whole, true, "whole and zone tracking together")
equal(#blocks[1].lines, 3, "the step the zone line covers isn't repeated")
equal(Text(blocks[1].lines[1]), "1/4 Achievement 10", "zone shares first")
equal(Text(blocks[1].lines[3]), "Boss", "then the challenge's other steps")

local explored = function(id)
	if id == 10 then
		return { [1] = { completed = true, index = 1 } }
	end
	return live[id]
end
equal(#Blocks({ "10" }, explored), 0, "a finished zone share leaves no empty header")
equal(#Blocks({ "10", 100 }, explored)[1].lines, 3, "a whole challenge stays with its own steps")
equal(#Blocks({ "10" }, function() end), 0, "unknown progress shows nothing")

-- Zone completion: own-faction and neutral flight paths only, unknown wings left out.
local zone = {
	areas = { { key = "0:0:10:10", name = "Kharanos" }, { key = "10:0:10:10", name = "Gol'Bolar Quarry" } },
	taxis = {
		{ node = 6, faction = "Alliance", name = "Ironforge" },
		{ node = 7, faction = "Horde", name = "Kargath" },
		{ node = 8, faction = "Neutral", name = "Ratchet" },
		{ node = 9, faction = "Neutral", name = "Unlisted" },
	},
	dungeons = {
		{ name = "Gnomeregan", refs = { { 1, 1 } } },
		{ name = "Unknown wing", refs = { { 2, 2 } } },
	},
	legacy = {
		{ name = "Lord Valthalak Laid to Rest", refs = { { 3, 3 }, { 4, 4 } } },
	},
	reputations = {
		{ faction = 21, name = "Booty Bay" },
		{ faction = 589, name = "Wintersaber Trainers", side = "Alliance" },
		{ faction = 530, name = "Darkspear Trolls", side = "Horde" },
	},
}
local snapshot = {
	explored = { ["0:0:10:10"] = true },
	taxis = { [6] = true, [7] = false, [8] = false },
	faction = "Alliance",
	-- Gnomeregan's step is open, the unknown wing's achievement (2) isn't reported, and only the
	-- second variant of the Legacy objective is done.
	criteria = function(achievementID)
		return ({
			[1] = { [1] = { completed = false } },
			[3] = { [3] = { completed = false } },
			[4] = { [4] = { completed = true } },
		})[achievementID]
	end,
	reaction = function(factionID)
		return factionID == 21 and 5 or 4
	end,
}
local completion = Model.ZoneCompletion(zone, snapshot)
equal(completion.areas.done, 1, "one area explored")
equal(completion.areas.left[1], "Gol'Bolar Quarry", "unexplored area named")
equal(completion.taxis.total, 2, "other faction's and unlisted flight paths left out")
equal(completion.taxis.pending, 1, "an unknown flight path is pending, outside the total")
equal(completion.dungeons.total, 1, "wing with unknown progress left out")
equal(completion.legacy.done, 1, "a Legacy objective is done when any variant is")
equal(completion.reputations.total, 2, "the other faction's reputation is left out")
equal(completion.reputations.done, 1, "Friendly counts, Neutral doesn't")
equal(completion.reputations.left[1], "Wintersaber Trainers", "reputation still to earn named")
equal(completion.total, 8, "items across categories")
equal(completion.percent, 50, "percent of items done")
equal(Model.ZoneCompletion({}, snapshot).percent, nil, "empty zone has no percent")
local noAreas = Model.ZoneCompletion(zone, snapshot, function(key)
	return key ~= "areas"
end)
equal(noAreas.areas, nil, "an uncounted category is left out")
equal(noAreas.total, completion.total - completion.areas.total, "and drops out of the total")

snapshot.taxis = {}
local unvisited = Model.ZoneCompletion(zone, snapshot).taxis
equal(unvisited and unvisited.total, 0, "flight paths before a flight master visit are all pending")
equal(unvisited and unvisited.pending, 3, "own-faction and neutral ones")
snapshot.explored = { ["0:0:10:10"] = true, ["10:0:10:10"] = true }
local onlyKnown = Model.ZoneCompletion({ areas = zone.areas, taxis = zone.taxis }, snapshot)
equal(onlyKnown.percent, 99, "everything known done, with flight paths pending, stays under 100%")
equal(onlyKnown.complete, false, "and isn't complete")
-- A raid is done when every boss is; a boss when either of its variants is.
local raidZone = {
	raids = {
		{
			name = "Onyxia's Lair",
			bosses = { { name = "Onyxia", refs = { { 50, 1 }, { 51, 1 } } }, { name = "Whelps", refs = { { 52, 1 } } } },
		},
	},
}
local done = {}
local raidSnapshot = {
	criteria = function(achievementID)
		if not done.unknown or done[achievementID] then
			return { { completed = done[achievementID] == true } }
		end
	end,
}
equal(Model.ZoneCompletion(raidZone, raidSnapshot).raids.done, 0, "no boss down, raid not done")
done[51] = true
local raids = Model.ZoneCompletion(raidZone, raidSnapshot).raids
equal(raids.done, 0, "one boss down of two, raid still not done")
equal(raids.left[1], "Onyxia's Lair", "the raid is named, not its bosses")
done[52] = true
equal(Model.ZoneCompletion(raidZone, raidSnapshot).complete, true, "every boss down by any variant")
done[52], done.unknown = nil, true
equal(Model.ZoneCompletion(raidZone, raidSnapshot).raids.pending, 1, "an unknown boss leaves the raid pending")

-- A step is known by its criterion, not its achievement: one the game lists without that criterion is unknown,
-- and one known open variant is enough to count the objective as not done.
local steps = { [3] = { [9] = { completed = true } } }
local stepSnapshot = {
	criteria = function(achievementID)
		return steps[achievementID]
	end,
}
local legacy = Model.ZoneCompletion({ legacy = zone.legacy }, stepSnapshot).legacy
equal(legacy and legacy.pending, 1, "an achievement reported without the step leaves it unknown")
steps[4] = { [4] = { completed = false } }
legacy = Model.ZoneCompletion({ legacy = zone.legacy }, stepSnapshot).legacy
equal(legacy and legacy.total, 1, "one variant known is enough to count the objective")
equal(legacy and legacy.done, 0, "and it is not done while that variant is open")

-- A continent counts its zones that count anything, complete or not.
local continent = Model.ContinentCompletion({
	{ total = 3, pending = 0, complete = true },
	{ total = 4, pending = 1, complete = false },
	{ total = 0, pending = 0, complete = true },
})
equal(continent.zones, 2, "a zone counting nothing is left out")
equal(continent.complete, 1, "complete zones")
equal(continent.percent, 50, "continent percent")
equal(Model.ContinentCompletion({ { total = 0, pending = 0, complete = true } }), nil, "no zone counts anything")
print(("model_spec: %d checks passed"):format(checks))
