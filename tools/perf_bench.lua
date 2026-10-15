-- Headless cost bench for the frame-free half of Legacy Forever (run from the repository root:
-- luajit tools/perf_bench.lua). It loads the real Data, Saved, Model, Live, Quests, ZoneCompletion
-- and MapContents over a stubbed client and reports CPU time and game-API call counts for load, the
-- login read, each event burst and each map/tracker build. UI files need frames and are not measured
-- here; tests/*_spec.lua cover their contract.
--
-- The client's own calls are stubs, so their cost is not what a frame sees: the API counts matter,
-- because each one is a call into the game. The Lua timings are real and show what the addon itself
-- costs, per call, once the client answers.
local ACHIEVEMENTS = 434 -- Forever 1.60.1.70205's Achievement table size
local CATEGORIES = 53

local api = {}
local function bump(name)
	api[name] = (api[name] or 0) + 1
end
local function reset()
	api = {}
end

---@param data LegacyData
---@return table
local function Environment(data)
	local criteria = {}
	local function place(achievementID, criteriaID)
		local steps = criteria[achievementID]
		if not steps then
			steps = { n = 0 }
			criteria[achievementID] = steps
		end
		if not steps[criteriaID] then
			steps.n = steps.n + 1
			steps[criteriaID] = {
				text = ("Step %d"):format(criteriaID),
				type = 0,
				completed = false,
				quantity = 0,
				required = 1,
				index = steps.n,
				criteriaID = criteriaID,
			}
		end
	end
	for _, entries in pairs(data.zones) do
		for _, entry in ipairs(entries) do
			place(entry.achievement, entry.criteria)
		end
	end
	for challenge in pairs(data.rewards) do
		criteria[challenge] = criteria[challenge] or { n = 0 }
	end

	local listed = {}
	for achievementID in pairs(criteria) do
		listed[#listed + 1] = achievementID
	end
	for index = #listed + 1, ACHIEVEMENTS do
		listed[index] = 1000000 + index
	end
	local perCategory = math.ceil(#listed / CATEGORIES)

	local guid = "Player-bench"
	local timers = {}
	local names = {}
	local env = {}
	env.GetCategoryList = function()
		bump("GetCategoryList")
		local list = {}
		for index = 1, CATEGORIES do
			list[index] = index
		end
		return list
	end
	env.GetCategoryNumAchievements = function()
		bump("GetCategoryNumAchievements")
		return perCategory
	end
	env.GetAchievementInfo = function(id, index)
		bump("GetAchievementInfo")
		local achievementID = index and listed[((id - 1) * perCategory) + index] or id
		if not achievementID then
			return nil
		end
		return achievementID, ("Challenge %d"):format(achievementID), 0, false, nil, nil, nil, ""
	end
	env.GetAchievementNumCriteria = function(id)
		bump("GetAchievementNumCriteria")
		local steps = criteria[id]
		return steps and steps.n or 0
	end
	env.GetAchievementCriteriaInfo = function(id, index)
		bump("GetAchievementCriteriaInfo")
		local steps = criteria[id]
		if not steps then
			return nil
		end
		for _, step in pairs(steps) do
			if type(step) == "table" and step.index == index then
				return step.text,
					step.type,
					step.completed,
					step.quantity,
					step.required,
					nil,
					nil,
					nil,
					nil,
					step.criteriaID
			end
		end
	end
	env.UnitGUID = function()
		bump("UnitGUID")
		return guid
	end
	env.UnitFactionGroup = function()
		bump("UnitFactionGroup")
		return "Alliance"
	end
	env.UnitRace = function()
		return "Human", "Human", 1
	end
	env.UnitClass = function()
		return "Warrior", "WARRIOR", 1
	end
	env.Enum = { UIMapType = { Continent = 2 }, FlightPathState = { Unreachable = 0 } }
	env.C_Map = {
		GetMapInfo = function(id)
			bump("GetMapInfo")
			names[id] = names[id] or ("Map " .. tostring(id))
			local continent = id == 1
			return { mapID = id, mapType = continent and 2 or 3, parentMapID = continent and 0 or 1, name = names[id] }
		end,
		GetBestMapForUnit = function()
			bump("GetBestMapForUnit")
			return 2
		end,
		GetMapRectOnMap = function()
			bump("GetMapRectOnMap")
			return 0, 100, 0, 100
		end,
	}
	env.C_MapExplorationInfo = {
		GetExploredMapTextures = function()
			bump("GetExploredMapTextures")
			return nil
		end,
	}
	env.C_TaxiMap = {
		GetAllTaxiNodes = function()
			bump("GetAllTaxiNodes")
			return { { nodeID = 10, state = 1 } }
		end,
	}
	env.C_QuestLog = {
		GetAllCompletedQuestIDs = function()
			bump("GetAllCompletedQuestIDs")
			return { 1, 2, 3 }
		end,
	}
	env.C_Reputation = {
		GetFactionDataByID = function()
			bump("GetFactionDataByID")
			return nil
		end,
	}
	env.C_Timer = {
		After = function(_, callback)
			bump("C_Timer.After")
			timers[#timers + 1] = callback
		end,
	}
	env.GetTime = function()
		bump("GetTime")
		return 0
	end
	env.tContains = function(list, value)
		for _, item in ipairs(list) do
			if item == value then
				return true
			end
		end
		return false
	end
	env.CreateFrame = function()
		return {
			RegisterEvent = function() end,
			SetScript = function(_, script, callback)
				assert(script == "OnEvent")
				env.onEvent = callback
			end,
		}
	end
	env.drainTimers = function()
		local drained = timers
		timers = {}
		return drained
	end
	return setmetatable(env, { __index = _G })
end

local function load(env, path, ns)
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	chunk("LegacyForever", ns)
end

local function counts(calls)
	local parts = {}
	for _, name in ipairs(calls) do
		if api[name] and api[name] > 0 then
			parts[#parts + 1] = ("%s=%d"):format(name, api[name])
		end
	end
	return table.concat(parts, " ")
end

local function report(title, seconds, calls)
	print(("  %-46s %9.4f ms  %s"):format(title, seconds * 1000, counts(calls)))
end

local function once(title, calls, fn)
	reset()
	local start = os.clock()
	local value = fn()
	report(title, os.clock() - start, calls)
	return value
end

local function repeated(title, iterations, calls, fn)
	reset()
	local start = os.clock()
	for _ = 1, iterations do
		fn()
	end
	local elapsed = os.clock() - start
	print(
		("  %-46s %9.4f ms  %8.2f us/call  %s"):format(title, elapsed * 1000, elapsed * 1e6 / iterations, counts(calls))
	)
end

---@type LegacyForeverNamespace
local ns = {}
local harness = setmetatable({}, { __index = _G })

local start = os.clock()
load(harness, "Data/Legacy.lua", ns)
print(("  %-46s %9.4f ms"):format("load Data/Legacy.lua", (os.clock() - start) * 1000))

local data = ns.Data
local env = Environment(data)
print(("bench: %d achievements in %d categories"):format(ACHIEVEMENTS, CATEGORIES))

for _, path in ipairs({
	"Core/SafeCall.lua",
	"Core/Saved.lua",
	"Core/Model.lua",
	"Core/Live.lua",
	"Integrations/Quests.lua",
	"Core/ZoneCompletion.lua",
	"UI/MapContents.lua",
}) do
	reset()
	start = os.clock()
	load(env, path, ns)
	report("load " .. path, os.clock() - start, {})
end

local Live = ns.Live
local Model = ns.Model
local ZoneCompletion = ns.ZoneCompletion
local MapContents = ns.MapContents

print("bench: login")
once("Live.Visible() first read", { "GetCategoryList", "GetCategoryNumAchievements", "GetAchievementInfo" }, function()
	return Live.Visible()
end)
once("Live.Criteria() all rewards", { "GetAchievementNumCriteria", "GetAchievementCriteriaInfo" }, function()
	for achievementID in pairs(data.rewards) do
		Live.Criteria(achievementID)
	end
end)

print("bench: event bursts and redraws")
local function burst(label)
	reset()
	local before = os.clock()
	env.onEvent(nil, "CRITERIA_UPDATE")
	report(label .. " handler", os.clock() - before, { "GetAchievementNumCriteria", "GetAchievementCriteriaInfo" })
	reset()
	before = os.clock()
	local heard = env.drainTimers()
	for _, callback in ipairs(heard) do
		callback()
	end
	report(label .. " deferred notice", os.clock() - before, {
		"GetMapInfo",
		"GetAchievementNumCriteria",
		"GetAchievementCriteriaInfo",
		"GetExploredMapTextures",
		"GetAllCompletedQuestIDs",
		"UnitFactionGroup",
	})
end
burst("CRITERIA_UPDATE")

-- The redraw a notifier asks for, as the tracker and map would do it.
local tracked = { 684, 61499, 61500 }
once("Model.TrackedBlocks(3 tracked)", { "GetAchievementNumCriteria" }, function()
	return Model.TrackedBlocks(data, tracked, Live.Visible(), Live.Criteria, Live.Name)
end)
once("Model.Unlocated() menu build", { "GetAchievementNumCriteria" }, function()
	return Model.Unlocated(data, Live.Visible(), Live.Criteria)
end)

local zoneMap
for uiMapID in pairs(data.zones) do
	if data.completion[uiMapID] then
		zoneMap = uiMapID
		break
	end
end
once(("MapContents.Drawn(zone %d)"):format(zoneMap), { "GetMapInfo", "GetExploredMapTextures" }, function()
	return MapContents.Drawn(zoneMap)
end)
once("MapContents.Drawn(continent 1)", { "GetMapInfo", "GetExploredMapTextures" }, function()
	return MapContents.Drawn(1)
end)
once("ZoneCompletion.Continent(1)", { "GetMapInfo", "GetExploredMapTextures" }, function()
	return ZoneCompletion.Continent(1)
end)

-- What one CRITERIA_UPDATE actually costs the client: the event, its deferred notice, then the
-- redraw the notice asked for. The tracker keeps its own frame and lays out on the next frame.
local function cycle(label, mapShown)
	reset()
	local before = os.clock()
	env.onEvent(nil, "CRITERIA_UPDATE")
	local heard = env.drainTimers()
	for _, callback in ipairs(heard) do
		callback()
	end
	if mapShown then
		MapContents.Drawn(1)
	end
	Live.Visible()
	Model.TrackedBlocks(data, tracked, Live.Visible(), Live.Criteria, Live.Name)
	local names = {
		"GetCategoryList",
		"GetCategoryNumAchievements",
		"GetAchievementInfo",
		"GetAchievementNumCriteria",
		"GetExploredMapTextures",
		"GetMapInfo",
		"GetAllCompletedQuestIDs",
	}
	print(("  %-46s %9.4f ms  %s"):format(label, (os.clock() - before) * 1000, counts(names)))
end
cycle("CRITERIA_UPDATE cycle (tracker redraw)", false)
cycle("CRITERIA_UPDATE cycle (map open)", true)

print("bench: repeated, to separate the addon's Lua from the client's calls")
repeated("Live.Visible() (list kept)", 1000, { "GetCategoryList", "GetAchievementInfo" }, function()
	Live.Visible()
end)
repeated("ZoneCompletion.Result(zone) kept", 1000, {}, function()
	ZoneCompletion.Result(zoneMap)
end)
repeated("ZoneCompletion.Continent(1)", 1000, { "GetMapInfo" }, function()
	ZoneCompletion.Continent(1)
end)
repeated("MapContents.Drawn(continent 1)", 1000, { "GetMapInfo" }, function()
	MapContents.Drawn(1)
end)
local drawn = MapContents.Drawn(zoneMap)
if drawn.shade then
	repeated("MapContents.AreaAt(one hover frame)", 1000, {}, function()
		MapContents.AreaAt(drawn.shade, 10, 10)
	end)
	print(("  Areas in the shaded zone: %d"):format(#drawn.shade.zone.areas))
else
	print("  no shaded zone to bench AreaAt against")
end

print("bench: done")
