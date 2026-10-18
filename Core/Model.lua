---@type string, LegacyForeverNamespace
local _, ns = ...

-- Pure logic over the generated data and a snapshot of live progress; no WoW API
-- calls, so tests/model_spec.lua can exercise it under plain LuaJIT.
--
-- `visible` is the set of unfinished reward-bearing challenges the game shows this
-- character (Forever ships two variant sets and the client lists only one).
-- `criteria(achievementID)` returns { [criteriaID] = { text, completed, type, asset,
-- quantity, required, index } }
-- or nil when the game has no data for that achievement.
---@class LegacyModel
local Model = {}
ns.Model = Model

-- Criteria type 8: "earn achievement X", where X is the criterion's asset.
local EARN_ACHIEVEMENT = 8

-- The visible challenge an objective counts toward, or nil if none is visible.
---@param data LegacyData
---@param achievementID number
---@param visible LegacySet
---@return number?
function Model.OwningChallenge(data, achievementID, visible)
	if visible[achievementID] then
		return achievementID
	end
	for _, reward in ipairs(data.feeds[achievementID] or {}) do
		if visible[reward] then
			return reward
		end
	end
	return nil
end

-- Unfinished objectives in one zone, grouped by the achievement that holds them
-- (a challenge, or the exploration achievement feeding it). Objectives whose live
-- progress is unknown are left out rather than shown as unfinished; Audit reports them.
-- With `includeDone`, a cleared dungeon or raid entrance is kept as well, marked
-- `done`, so the map can show which instances are finished and which are not.
---@param data LegacyData
---@param uiMapID number
---@param visible LegacySet
---@param criteria LegacyCriteriaReader
---@param includeDone boolean? also keep cleared dungeon and raid entrances, marked done
---@return LegacyGroup[]
function Model.ZoneObjectives(data, uiMapID, visible, criteria, includeDone)
	---@type LegacyGroup[], table<number, LegacyGroup>
	local groups, byAchievement = {}, {}
	for _, entry in ipairs(data.zones[uiMapID] or {}) do
		local challenge = Model.OwningChallenge(data, entry.achievement, visible)
		local live = challenge and criteria(entry.achievement)
		local progress = live and live[entry.criteria]
		if challenge and progress and (not progress.completed or (includeDone and entry.kind == "instance")) then
			local group = byAchievement[entry.achievement]
			if not group then
				group = { achievement = entry.achievement, challenge = challenge, uiMapID = uiMapID, objectives = {} }
				byAchievement[entry.achievement] = group
				groups[#groups + 1] = group
			end
			group.objectives[#group.objectives + 1] =
				{ entry = entry, text = progress.text, done = progress.completed or nil }
		end
	end
	return groups
end

---@param groups LegacyGroup[]
---@return number
function Model.CountObjectives(groups)
	local count = 0
	for _, group in ipairs(groups) do
		count = count + #group.objectives
	end
	return count
end

---@param data LegacyData
---@return LegacySet
local function LocatedCriteria(data)
	local located = {}
	for _, entries in pairs(data.zones) do
		for _, entry in ipairs(entries) do
			located[entry.criteria] = true
		end
	end
	return located
end

-- Unfinished criteria no zone places, counting through "earn achievement X" into
-- X's own criteria when X is a feeding achievement (the generator rejects cycles).
---@param data LegacyData
---@param located LegacySet
---@param criteria LegacyCriteriaReader
---@param achievementID number
---@return number
local function OpenUnlocated(data, located, criteria, achievementID)
	local open = 0
	for criteriaID, progress in pairs(criteria(achievementID) or {}) do
		if not progress.completed and not located[criteriaID] then
			if progress.type == EARN_ACHIEVEMENT and data.feeds[progress.asset] then
				open = open + OpenUnlocated(data, located, criteria, progress.asset)
			else
				open = open + 1
			end
		end
	end
	return open
end

-- Visible challenges with unfinished criteria no zone accounts for: levels, skills,
-- ranks, and anything whose location the data can't establish.
---@param data LegacyData
---@param visible LegacySet
---@param criteria LegacyCriteriaReader
---@return LegacyUnlocated[]
function Model.Unlocated(data, visible, criteria)
	local located = LocatedCriteria(data)
	local result = {}
	for challenge in pairs(visible) do
		local open = OpenUnlocated(data, located, criteria, challenge)
		if open > 0 then
			result[#result + 1] = { challenge = challenge, open = open }
		end
	end
	table.sort(result, function(a, b)
		return a.challenge < b.challenge
	end)
	return result
end

-- Done/total of an achievement's criteria.
---@param steps LegacyCriteria
---@return number done
---@return number total
function Model.Tally(steps)
	local done, total = 0, 0
	for _, step in pairs(steps) do
		total = total + 1
		done = done + (step.completed and 1 or 0)
	end
	return done, total
end

-- One unfinished step as a tracker line: "3/10" for counted criteria, done/total of X's
-- criteria for "earn achievement X". `seen` names the step, so a block never lists it twice.
---@param criteriaID number
---@param progress LegacyProgress
---@param criteria LegacyCriteriaReader
---@return LegacyTrackerLine
local function StepLine(criteriaID, progress, criteria)
	local detail, seen
	local sub = progress.type == EARN_ACHIEVEMENT and criteria(progress.asset)
	if sub then
		detail = ("%d/%d"):format(Model.Tally(sub))
		seen = "a" .. progress.asset
	elseif progress.required and progress.required > 1 then
		detail = ("%d/%d"):format(progress.quantity, progress.required)
	end
	return { text = progress.text, detail = detail, seen = seen or ("c" .. criteriaID) }
end

-- A tracked challenge's unfinished steps in game order, each with its progress.
---@param challenge number
---@param criteria LegacyCriteriaReader
---@return LegacyTrackerLine[]
function Model.TrackerLines(challenge, criteria)
	local open = {}
	for criteriaID, progress in pairs(criteria(challenge) or {}) do
		if not progress.completed then
			open[#open + 1] = { id = criteriaID, progress = progress }
		end
	end
	table.sort(open, function(a, b)
		return a.progress.index < b.progress.index
	end)
	local lines = {}
	for _, step in ipairs(open) do
		lines[#lines + 1] = StepLine(step.id, step.progress, criteria)
	end
	return lines
end

-- What the map menu tracks for one zone's group: a number is a whole challenge (all 0.3.0
-- stored, and what "No fixed location" still tracks); a string is one zone's share of it.
-- A feeding achievement ("Explore Felwood") is tracked whole, as "<achievement>", wherever
-- it is ticked; objectives a challenge places itself (its dungeons) as "<challenge>:<uiMapID>".
---@param group LegacyGroup
---@return string
function Model.ZoneKey(group)
	if group.achievement ~= group.challenge then
		return tostring(group.achievement)
	end
	return ("%d:%d"):format(group.challenge, group.uiMapID)
end

---@param key string
---@return number? achievement
---@return number? uiMapID
local function ParseKey(key)
	local achievement, uiMapID = key:match("^(%d+):?(%d*)$")
	return tonumber(achievement), tonumber(uiMapID)
end

-- The visible challenge a tracked entry belongs to, or nil while the game lists none.
---@param data LegacyData
---@param key LegacyTrackingKey
---@param visible LegacySet
---@return number?
function Model.TrackedChallenge(data, key, visible)
	if type(key) == "number" then
		return visible[key] and key or nil
	end
	local achievement = ParseKey(key)
	if not achievement then
		return nil
	end
	return Model.OwningChallenge(data, achievement, visible)
end

-- A tracked zone share's unfinished lines: a feeding achievement as one done/total line
-- under its own name, a challenge's own objectives in that zone one line each.
---@param data LegacyData
---@param key string
---@param criteria LegacyCriteriaReader
---@param name fun(achievementID: number): string
---@return LegacyTrackerLine[]
local function ZoneLines(data, key, criteria, name)
	local achievement, uiMapID = ParseKey(key)
	if not achievement then
		return {}
	end
	local steps = criteria(achievement)
	if not steps then
		return {}
	end
	if not uiMapID then
		local done, total = Model.Tally(steps)
		if done == total then
			return {}
		end
		return { { text = name(achievement), detail = ("%d/%d"):format(done, total), seen = "a" .. achievement } }
	end
	local lines = {}
	for _, entry in ipairs(data.zones[uiMapID] or {}) do
		local progress = entry.achievement == achievement and steps[entry.criteria]
		if progress and not progress.completed then
			lines[#lines + 1] = StepLine(entry.criteria, progress, criteria)
		end
	end
	return lines
end

-- The tracker's blocks, one per visible challenge in the order first tracked: the zone shares
-- ticked under it, then (when the whole challenge is tracked) its other unfinished steps.
-- A challenge tracked only through zones drops out once none of them has anything left.
---@param data LegacyData
---@param tracked LegacyTrackingKey[]
---@param visible LegacySet
---@param criteria LegacyCriteriaReader
---@param name fun(achievementID: number): string
---@return LegacyTrackedBlock[]
function Model.TrackedBlocks(data, tracked, visible, criteria, name)
	---@type LegacyTrackedBlock[], table<number, LegacyTrackedBlock>
	local blocks, byChallenge = {}, {}
	for _, key in ipairs(tracked) do
		local challenge = Model.TrackedChallenge(data, key, visible)
		if challenge then
			local block = byChallenge[challenge]
			if not block then
				block = { challenge = challenge, lines = {}, seen = {} }
				byChallenge[challenge] = block
				blocks[#blocks + 1] = block
			end
			if type(key) == "number" then
				block.whole = true
			else
				for _, line in ipairs(ZoneLines(data, key, criteria, name)) do
					if not block.seen[line.seen] then
						block.seen[line.seen] = true
						block.lines[#block.lines + 1] = line
					end
				end
			end
		end
	end
	local shown = {}
	for _, block in ipairs(blocks) do
		if block.whole then
			for _, line in ipairs(Model.TrackerLines(block.challenge, criteria)) do
				if not block.seen[line.seen] then
					block.lines[#block.lines + 1] = line
				end
			end
		end
		if block.whole or #block.lines > 0 then
			shown[#shown + 1] = block
		end
	end
	return shown
end

-- One category of a zone's completion: { done, total, pending, complete, left = { names } }, or nil when
-- the zone has none. `state(item)` returns true (done),
-- false (not done) or nil (unknown, left out of the count).
---@generic T: { name: string }
---@param items T[]?
---@param state fun(item: T): boolean?
---@return LegacyCategory?
local function CompletionCategory(items, state)
	if not items or #items == 0 then
		return nil
	end
	local category = { done = 0, total = 0, left = {}, pending = 0 }
	for _, item in ipairs(items) do
		local done = state(item)
		if done == nil then
			category.pending = category.pending + 1
		else
			category.total = category.total + 1
			if done then
				category.done = category.done + 1
			else
				category.left[#category.left + 1] = item.name
			end
		end
	end
	category.complete = category.done == category.total and category.pending == 0
	return category
end

---@type LegacyCategoryKey[]
Model.COMPLETION_CATEGORIES = { "areas", "taxis", "dungeons", "raids", "legacy", "reputations", "quests" }

-- Quest fields that tie a quest to a profession, a reputation, a spell or a level cap: whether a
-- character can ever take it isn't known, so it never counts.
local QUEST_GATES = {
	"requiredSkill",
	"requiredMinRep",
	"requiredMaxRep",
	"requiredRanks",
	"requiredSpell",
	"requiredSpecialization",
	"requiredMaxLevel",
}
-- Quests that end a quest's availability once done: a breadcrumb's destination, the quest that
-- replaces it. The quest counts as done once one of these is, as it can't be taken any more.
local QUEST_CLOSERS = { "nextQuestInChain", "breadcrumbForQuestId", "availableUntilCompleted" }
local REPEATABLE, DAILY = 1, 4096

-- QuestieDB reads an unset number as 0 and an unset list as nil.
---@param value any
---@return boolean
local function IsSet(value)
	if type(value) == "table" then
		return next(value) ~= nil
	end
	return value ~= nil and value ~= 0
end

---@param value number?
---@param flag number
---@return boolean
local function HasFlag(value, flag)
	return math.floor((value or 0) / flag) % 2 == 1
end

-- Each zone's quests for this character, from QuestieDB: every quest the character's race
-- and class could ever take there, whatever its level or what it has done, so a zone's total holds.
-- Left out: repeatable and daily quests, quests filed under an instance or a sort (class, profession,
-- holiday) rather than a zone, quests Questie hides (never in the game, or a holiday's), quests with
-- no giver or object to start them, gated ones (QUEST_GATES), and quests after a choice this
-- character could make the other way. Mutually exclusive quests in a zone count once, done when any is.
---@param source LegacyQuestSource
---@param zones table<number, any>
---@return table<number, LegacyQuestItem[]>
function Model.QuestIndex(source, zones)
	---@type table<number, boolean>
	local reachable = {}
	local Reachable

	-- Whether `questID` stays open whichever way the character goes: none of its exclusive
	-- partners that the character could take instead is outside `allowed`.
	---@param questID number
	---@param allowed table<number, boolean>
	---@return boolean
	local function Unforked(questID, allowed)
		for _, partner in ipairs(source.get(questID, "exclusiveTo") or {}) do
			if not allowed[partner] and Reachable(partner) then
				return false
			end
		end
		return true
	end

	---@param questID number
	---@return boolean
	local function Follows(questID)
		for _, key in ipairs({ "preQuestGroup", "parentQuest", "availableStartingWith" }) do
			local value = source.get(questID, key)
			for _, required in ipairs(type(value) == "table" and value or IsSet(value) and { value } or {}) do
				if not (Reachable(required) and Unforked(required, {})) then
					return false
				end
			end
		end
		local alternatives = source.get(questID, "preQuestSingle")
		if not IsSet(alternatives) then
			return true
		end
		local allowed = {}
		for _, alternative in ipairs(alternatives) do
			allowed[alternative] = true
		end
		for _, alternative in ipairs(alternatives) do
			if Reachable(alternative) and Unforked(alternative, allowed) then
				return true
			end
		end
		return false
	end

	-- Whether the character can ever take the quest, as far as the data can establish.
	---@param questID number
	---@return boolean
	function Reachable(questID)
		local known = reachable[questID]
		if known ~= nil then
			return known
		end
		reachable[questID] = false -- a prerequisite cycle is never reachable
		local ok = source.get(questID, "name") ~= nil
			and not source.hidden(questID)
			and source.race(source.get(questID, "requiredRaces") or 0)
			and source.class(source.get(questID, "requiredClasses") or 0)
		for _, key in ipairs(QUEST_GATES) do
			ok = ok and not IsSet(source.get(questID, key))
		end
		ok = ok and Follows(questID)
		reachable[questID] = ok
		return ok
	end

	-- The zone a quest counts in, or nil when it doesn't count.
	---@param questID number
	---@return number?
	local function CountedIn(questID)
		local zoneOrSort = source.get(questID, "zoneOrSort") or 0
		local uiMapID = zoneOrSort > 0 and source.zone(zoneOrSort)
		if not uiMapID or not zones[uiMapID] then
			return nil
		end
		local flags = source.get(questID, "specialFlags")
		if HasFlag(flags, REPEATABLE) or HasFlag(source.get(questID, "questFlags"), DAILY) then
			return nil
		end
		local startedBy = source.get(questID, "startedBy") or {}
		if not (IsSet(startedBy[1]) or IsSet(startedBy[2])) or not Reachable(questID) then
			return nil
		end
		return uiMapID
	end

	-- Counted quests by zone, then joined with their exclusive partners in the same zone.
	---@type table<number, number>, table<number, number>
	local zoneOf, root = {}, {}
	---@param questID number
	---@return number
	local function Find(questID)
		while root[questID] ~= questID do
			questID = root[questID]
		end
		return questID
	end
	for _, questID in ipairs(source.ids) do
		zoneOf[questID] = CountedIn(questID)
		if zoneOf[questID] then
			root[questID] = questID
		end
	end
	for questID in pairs(root) do
		for _, partner in ipairs(source.get(questID, "exclusiveTo") or {}) do
			if root[partner] and zoneOf[partner] == zoneOf[questID] then
				local a, b = Find(questID), Find(partner)
				root[math.max(a, b)] = math.min(a, b)
			end
		end
	end

	---@type table<number, LegacyQuestItem>
	local items = {}
	for _, questID in ipairs(source.ids) do
		if root[questID] then
			local key = Find(questID)
			local item = items[key]
			if not item then
				item = { name = source.get(key, "name"), ids = {}, uiMapID = zoneOf[key] }
				items[key] = item
			end
			item.ids[#item.ids + 1] = questID
			for _, partner in ipairs(source.get(questID, "exclusiveTo") or {}) do
				item.ids[#item.ids + 1] = partner
			end
			for _, closer in ipairs(QUEST_CLOSERS) do
				local closerID = source.get(questID, closer)
				if IsSet(closerID) then
					item.ids[#item.ids + 1] = closerID
				end
			end
		end
	end
	---@type table<number, LegacyQuestItem[]>
	local index = {}
	for _, item in pairs(items) do
		local list = index[item.uiMapID] or {}
		list[#list + 1] = item
		index[item.uiMapID] = list
	end
	for _, list in pairs(index) do
		table.sort(list, function(a, b)
			if a.name ~= b.name then
				return a.name < b.name
			end
			return a.ids[1] < b.ids[1]
		end)
	end
	return index
end

-- A zone quest is done once the character has turned in any of its IDs; unknown until the game says.
---@param item LegacyQuestItem
---@param completed LegacySet?
---@return boolean?
local function QuestDone(item, completed)
	if not completed then
		return nil
	end
	for _, questID in ipairs(item.ids) do
		if completed[questID] then
			return true
		end
	end
	return false
end

-- The zone's quests: absent without a source, one pending item while the source is still loading.
---@param snapshot LegacySnapshot
---@return LegacyCategory?
local function QuestCategory(snapshot)
	local items = snapshot.quests and snapshot.quests()
	if items == false then
		return { done = 0, total = 0, left = {}, pending = 1, complete = false }
	end
	return CompletionCategory(items, function(item)
		return QuestDone(item, snapshot.completed)
	end)
end

-- A wing or Legacy objective counts as done when any of its Legacy steps (either variant) is;
-- unknown while the game reports none of them.
---@param refs LegacyRefs
---@param criteria LegacyCriteriaReader
---@return boolean?
local function RefsDone(refs, criteria)
	local state
	for _, ref in ipairs(refs) do
		local progress = (criteria(ref[1]) or {})[ref[2]]
		if progress then
			if progress.completed then
				return true
			end
			state = false
		end
	end
	return state
end

-- A raid is done when every boss is, and a boss when any of its refs is; unknown while any boss is.
---@param raid LegacyRaid
---@param criteria LegacyCriteriaReader
---@return boolean?
local function RaidDone(raid, criteria)
	local done = true
	for _, boss in ipairs(raid.bosses) do
		local bossDone = RefsDone(boss.refs, criteria)
		if bossDone == nil then
			return nil
		end
		done = done and bossDone
	end
	return done
end

-- A zone's reputation counts once the player is Friendly (reaction 5) or better with it.
local REPUTATION_TARGET = 5

-- Entries for the player's side: those with no side under `sideKey`, Neutral ones, and the player's faction's.
---@generic T
---@param items T[]?
---@param faction string
---@param sideKey string
---@return T[]
function Model.ForFaction(items, faction, sideKey)
	local own = {}
	for _, item in ipairs(items or {}) do
		local side = item[sideKey]
		if side == nil or side == "Neutral" or side == faction then
			own[#own + 1] = item
		end
	end
	return own
end

-- A zone's completion, GW2 style: every area, flight path, dungeon, raid, Legacy objective, local
-- reputation and quest counts once.
-- Items whose state is unknown (nil) are `pending`: shown, but outside done/total and the percent.
-- `snapshot` = { explored = set of overlay keys, taxis = { [node] = known } once a
-- flight master on the zone's continent has been opened (until then every node is pending),
-- faction = "Alliance" | "Horde",
-- criteria = the reader described at the top of this file, reaction = function(factionID) -> number,
-- quests = function() -> the zone's LegacyQuestItem[], false while loading, or nil,
-- completed = set of turned-in quest IDs or nil }.
-- Areas, flight paths and reputations are per character; dungeon wings, raids and Legacy
-- objectives are account-wide Legacy steps, done when any of their refs is (a raid: every boss).
-- `counted(key)`, when given, says which categories the player counts; the rest are left out entirely.
---@param zone LegacyZone
---@param snapshot LegacySnapshot
---@param counted? fun(key: LegacyCategoryKey): boolean
---@return LegacyZoneResult
function Model.ZoneCompletion(zone, snapshot, counted)
	---@type LegacyZoneResult
	local result = {
		areas = CompletionCategory(zone.areas, function(area)
			return snapshot.explored[area.key] == true
		end),
		taxis = CompletionCategory(Model.ForFaction(zone.taxis, snapshot.faction, "faction"), function(taxi)
			return snapshot.taxis[taxi.node]
		end),
		dungeons = CompletionCategory(zone.dungeons, function(wing)
			return RefsDone(wing.refs, snapshot.criteria)
		end),
		raids = CompletionCategory(zone.raids, function(raid)
			return RaidDone(raid, snapshot.criteria)
		end),
		legacy = CompletionCategory(zone.legacy, function(objective)
			return RefsDone(objective.refs, snapshot.criteria)
		end),
		reputations = CompletionCategory(Model.ForFaction(zone.reputations, snapshot.faction, "side"), function(rep)
			return snapshot.reaction(rep.faction) >= REPUTATION_TARGET
		end),
		-- Built from QuestieDB only when counted: the first zone reads its whole database.
		quests = (not counted or counted("quests")) and QuestCategory(snapshot) or nil,
		done = 0,
		total = 0,
		pending = 0,
		complete = false,
	}
	for _, key in ipairs(Model.COMPLETION_CATEGORIES) do
		if counted and not counted(key) then
			result[key] = nil
		end
		local category = result[key]
		if category then
			result.done = result.done + category.done
			result.total = result.total + category.total
			result.pending = result.pending + category.pending
		end
	end
	result.complete = result.done == result.total and result.pending == 0
	-- Floored, and held under 100 while anything is pending, so 100% means nothing is left.
	result.percent = result.total > 0 and math.floor(100 * result.done / result.total) or nil
	if result.percent and not result.complete then
		result.percent = math.min(result.percent, 99)
	end
	return result
end

-- Whether a zone completion counts anything at all: a zone with every category switched off
-- (or none to count) is neither complete nor incomplete.
---@param result LegacyZoneResult
---@return boolean
function Model.CompletionCounts(result)
	return result.total > 0 or result.pending > 0
end

-- A continent's zone completion from its zones' results: { complete, zones, percent },
-- or nil when none of them counts anything.
---@param results LegacyZoneResult[]
---@return LegacyContinentResult?
function Model.ContinentCompletion(results)
	local continent = { complete = 0, zones = 0 }
	for _, result in ipairs(results) do
		if Model.CompletionCounts(result) then
			continent.zones = continent.zones + 1
			if result.complete then
				continent.complete = continent.complete + 1
			end
		end
	end
	if continent.zones == 0 then
		return nil
	end
	continent.percent = math.floor(100 * continent.complete / continent.zones)
	return continent
end
