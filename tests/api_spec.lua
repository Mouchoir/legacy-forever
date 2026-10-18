-- Run from the repository root: luajit tests/api_spec.lua
-- LegacyForever.API over the real Model, Quests, ZoneCompletion, Completion and Navigate, with the game's
-- progress faked.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

-- Map 100 has two areas, a dungeon wing and five located criteria; 200 has nothing to count.
local data = {
	build = "test",
	rewards = { [10] = true, [20] = true, [30] = true },
	feeds = {},
	zones = {
		[100] = {
			{ achievement = 10, criteria = 1, kind = "explore", x = 0.1, y = 0.2 },
			{ achievement = 10, criteria = 2, kind = "explore", x = 0.3, y = 0.4 },
			{ achievement = 20, criteria = 5, kind = "kill" },
			{ achievement = 10, criteria = 3, kind = "explore", x = 0.5, y = 0.5 },
			{ achievement = 30, criteria = 7, kind = "quest", x = 0.6, y = 0.6 },
		},
	},
	completion = {
		[100] = {
			areas = { { name = "North", key = "0:0:1:1" }, { name = "South", key = "0:1:1:1" } },
			taxis = {},
			dungeons = { { name = "Wing", refs = { { 900, 1 } } } },
			raids = {},
			legacy = {},
			reputations = {},
		},
		[200] = { areas = {}, taxis = {}, dungeons = {}, raids = {}, legacy = {}, reputations = {} },
	},
}

-- Live progress: achievement 30 is finished, so not visible; criterion 3 is unknown to the game, and so is
-- the wing's step (achievement 900) until a check below reports it.
local visible = { [10] = true, [20] = true }
local criteria = {
	[10] = {
		[1] = { text = "Explore North", completed = false, index = 1 },
		[2] = { text = "Explore South", completed = true, index = 2 },
	},
	[20] = { [5] = { text = "Slay ogres", completed = false, quantity = 3, required = 10, index = 1 } },
}
local settings = {}
local timers, errors, printed, waypoints, journeys = {}, {}, {}, {}, {}

local ns = { Data = data }
SlashCmdList = {}
-- The GlobalStrings UI/Completion.lua labels its categories with.
DUNGEONS, RAIDS, QUESTS_LABEL = "Dungeons", "Raids", "Quests"
assert(loadfile("Locales/enUS.lua"))("LegacyForever", ns)
assert(loadfile("Core/SafeCall.lua"))("LegacyForever", ns)
assert(loadfile("Core/Core.lua"))("LegacyForever", ns)
assert(loadfile("Core/Art.lua"))("LegacyForever", ns)
assert(loadfile("Core/Saved.lua"))("LegacyForever", ns)
-- The save file: the specs below edit what counts in it directly, as a hand-edited file would.
LegacyForeverDB = { zoneCompletion = settings }
local live = {}
ns.Live = {
	Visible = function()
		return visible
	end,
	Criteria = function(achievementID)
		return criteria[achievementID]
	end,
	ZoneSnapshot = function(uiMapID)
		return {
			explored = { ["0:0:1:1"] = true },
			taxis = {},
			faction = "Alliance",
			criteria = function(achievementID)
				return criteria[achievementID]
			end,
			reaction = function()
				return 0
			end,
			quests = function()
				return ns.Quests.Zone(uiMapID)
			end,
			completed = { [501] = true },
		}
	end,
	CurrentZone = function()
		return 100
	end,
	ContinentOf = function(uiMapID)
		return uiMapID == 100 and 1 or nil
	end,
	OnChange = function(callback)
		live[#live + 1] = callback
	end,
	-- The real one debounces; the listeners run straight away here.
	Invalidate = function()
		for _, callback in ipairs(live) do
			callback()
		end
	end,
}
function ns.Print(msg)
	printed[#printed + 1] = msg
end
local zoneTracker
ns.Tracker = {
	AddModule = function(_, mixin)
		zoneTracker = mixin
		return nil
	end,
}

-- The client.
C_Timer = {
	After = function(_, callback)
		timers[#timers + 1] = callback
	end,
}
local function RunTimers()
	local due = timers
	timers = {}
	for _, callback in ipairs(due) do
		callback()
	end
end
local faction = "Alliance"
UnitFactionGroup = function()
	return faction
end
UnitRace = function()
	return "Human", "Human", 1
end
UnitClass = function()
	return "Paladin", "PALADIN", 2
end
local inCombat = false
InCombatLockdown = function()
	return inCombat
end
geterrorhandler = function()
	return function(message)
		errors[#errors + 1] = message
	end
end
GetTime = function()
	return 0
end
-- The escape stores height first (Blizzard's CreateAtlasMarkup); sizes from UiTextureAtlasMember, 1.60.1.70009.
CreateAtlasMarkup = function(atlas, width, height)
	return ("|A:%s:%d:%d|a"):format(atlas, height, width)
end
local atlases = {
	["UI-Legacy-Points-icon-c60"] = { width = 50, height = 73 },
	["islands-queue-prop-compass"] = { width = 300, height = 297 },
	flightmaster = { width = 32, height = 32 },
}
C_Texture = {
	GetAtlasInfo = function(atlas)
		return atlases[atlas]
	end,
}
-- The world map, which fails on any write (tests/strict_map.lua); the corner overlay attaches once it loads.
local Kit = dofile("tests/strict_map.lua")
Kit.mapID = 100
Enum = Enum or {}
WorldMapFrame, CreateFrame, Mixin, CreateFromMixins = Kit.map, Kit.CreateFrame, nil, nil
do
	local env = {}
	Kit.Install(env)
	Mixin, CreateFromMixins, Saturate, Lerp = env.Mixin, env.CreateFromMixins, env.Saturate, env.Lerp
end
local onMapLoaded = {}
EventUtil = {
	ContinueOnAddOnLoaded = function(addon, callback)
		assert(addon == "Blizzard_WorldMap")
		onMapLoaded[#onMapLoaded + 1] = callback
	end,
}
AlertFrame = {
	AddQueuedAlertFrameSubSystem = function()
		return { AddAlert = function() end }
	end,
}
local canSet = true
local openedMap
C_Map = {
	OpenWorldMap = function(uiMapID)
		openedMap = uiMapID
	end,
	GetMapInfo = function(uiMapID)
		return uiMapID == 100 and { name = "Elwynn Forest" } or nil
	end,
	CanSetUserWaypointOnMap = function()
		return canSet
	end,
	SetUserWaypoint = function(point)
		waypoints[#waypoints + 1] = point
	end,
}
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
UiMapPoint = {
	CreateFromCoordinates = function(map, x, y)
		return { uiMapID = map, x = x, y = y }
	end,
}

-- QuestieDB, installed later: quest 501 (turned in) and 502 start in area 12, which is map 100.
local scans = 0
local function InstallQuestieDB()
	local quests = {
		[501] = { name = "Wolves", zoneOrSort = 12, startedBy = { { 5 } } },
		[502] = { name = "Bears", zoneOrSort = 12, startedBy = { { 5 } } },
	}
	LibQuestieDB = {
		RequireContract = function()
			return true
		end,
		Quest = {
			Get = function(questID, key)
				return quests[questID] and quests[questID][key]
			end,
			GetAllIds = function()
				scans = scans + 1
				return { 501, 502 }
			end,
		},
		Support = {
			Get = function()
				return {
					private = {
						areaIdToUiMapId = { [12] = 100 },
						subZoneToParentZone = {},
						dungeons = {},
					},
				}
			end,
		},
	}
end

for _, file in ipairs({
	"Core/Model.lua",
	"Integrations/Quests.lua",
	"Integrations/Navigate.lua",
	"Core/ZoneCompletion.lua",
	"UI/ForeverFamily.lua",
	"UI/MapCanvas.lua",
	"UI/Completion.lua",
	"Core/API.lua",
}) do
	assert(loadfile(file))("LegacyForever", ns)
end
-- The zone's corner on the world map: a frame of ours, never one of the map's overlay frames or data providers.
check(#onMapLoaded == 1, "the corner overlay waits for the world map to load")
onMapLoaded[1]()
local overlay = Kit.Made("LegacyForeverZoneOverlayTemplate")[1]
check(overlay and overlay:GetParent() == Kit.map, "the corner overlay is a frame of ours on the map")
local color = {
	GetRGB = function()
		return 1, 1, 1
	end,
	WrapTextInColorCode = function(_, text)
		return text
	end,
}
NORMAL_FONT_COLOR, GREEN_FONT_COLOR, HIGHLIGHT_FONT_COLOR, GRAY_FONT_COLOR = color, color, color, color
overlay:Hide()
local errorsBefore = #errors
Kit.Tick()
check(overlay.shown and overlay.Title.text:find("Elwynn Forest", 1, true), "opening the map fills in its corner")
Kit.mapID = 200
Kit.Tick()
check(not overlay.shown, "turning to a map with nothing to count hides the corner")
Kit.mapID = 100
Kit.Tick()
check(overlay.shown, "turning back shows it again")
check(#errors == errorsBefore, "the corner draws without an error")

zoneTracker:OnBlockHeaderClick({ id = 100 }, "LeftButton")
check(openedMap == 100, "a click on the zone's tracker header asks the game to open its map")
local API = LegacyForever.API
check(API.version == 1, "version 1")

local function Category(summary, key)
	for _, category in ipairs(summary.categories) do
		if category.key == key then
			return category
		end
	end
end

-- The zone summary: one area of two, the wing's state unknown, so pending and outside the total.
local summary = assert(API.ZoneSummary(100))
check(summary.map == 100 and summary.name == "Elwynn Forest", "the summary names its map")
check(summary.done == 1 and summary.total == 2 and summary.pending == 1, "a pending wing stays outside the total")
check(not summary.complete and summary.questsStatus == "disabled", "incomplete, quests not counted by default")
local areas, dungeons = Category(summary, "areas"), Category(summary, "dungeons")
check(areas.scope == "character" and areas.done == 1 and areas.total == 2, "areas are this character's")
check(dungeons.scope == "account" and dungeons.total == 0 and dungeons.pending == 1, "a wing is account-wide")
check(not dungeons.complete, "an all-pending category never claims complete")
check(not Category(summary, "taxis") and not Category(summary, "quests"), "empty and uncounted categories are left out")

-- Fresh copies: changing a result changes nothing the next call returns.
summary.categories[1].done, summary.done, summary.categories = 99, 99, nil
local again = assert(API.ZoneSummary(100))
check(again.done == 1 and Category(again, "areas").done == 1, "a summary is a detached copy")

-- Errors: bad input, no data, the player not known yet.
check(select(2, API.ZoneSummary("100")) == "invalid", "a string map is invalid")
check(select(2, API.ZoneSummary(100.5)) == "invalid", "a fractional map is invalid")
check(select(2, API.ZoneSummary(0 / 0)) == "invalid", "NaN is invalid")
check(select(2, API.ZoneSummary(999)) == "unsupported", "a map without data is unsupported")
faction = nil
check(select(2, API.ZoneSummary(100)) == "loading", "no faction yet is loading")
faction = "Alliance"

-- What counts: areas off leaves them out; with nothing counted, nothing is complete.
settings.count_areas = false
summary = assert(API.ZoneSummary(100))
check(not Category(summary, "areas") and summary.total == 0, "an uncounted category is left out")
criteria[900] = { { completed = true } }
summary = assert(API.ZoneSummary(100))
check(summary.complete and Category(summary, "dungeons").complete, "the counted wing done is complete")
settings.count_dungeons = false
summary = assert(API.ZoneSummary(100))
check(#summary.categories == 0 and not summary.complete, "an all-disabled summary is never complete")
local empty = assert(API.ZoneSummary(200))
check(#empty.categories == 0 and empty.total == 0 and not empty.complete, "an empty zone is never complete")
settings.count_areas, settings.count_dungeons, criteria[900] = nil, nil, nil

-- Quests: counted without QuestieDB is missing; a cold QuestieDB reads as loading without scanning.
settings.count_quests = true
summary = assert(API.ZoneSummary(100))
check(summary.questsStatus == "missing" and not Category(summary, "quests"), "no QuestieDB, no quests")
InstallQuestieDB()
local fired = 0
local unsubscribe = API.Subscribe(function()
	fired = fired + 1
end)
summary = assert(API.ZoneSummary(100))
local quests = Category(summary, "quests")
check(summary.questsStatus == "loading" and scans == 0, "a cold QuestieDB is loading, with no scan in the read")
check(quests and quests.total == 0 and quests.pending == 1 and not quests.complete, "loading quests are pending")
API.ZoneSummary(100)
check(#timers == 1, "one build is scheduled however often the API reads")
RunTimers()
check(scans == 1 and fired == 1, "the build runs on the next frame and notifies subscribers")
summary = assert(API.ZoneSummary(100))
quests = Category(summary, "quests")
check(summary.questsStatus == "ready", "quests are ready once built")
check(quests.scope == "character" and quests.done == 1 and quests.total == 2, "quests count this character's")
-- A synchronous reader (the typed audit) building the index first still leaves the waiter notified.
local scansBefore = scans
assert(loadfile("Integrations/Quests.lua"))("LegacyForever", ns)
check(assert(API.ZoneSummary(100)).questsStatus == "loading" and #timers == 1, "a fresh index is cold again")
ns.Quests.Zone(100)
check(scans == scansBefore + 1 and assert(API.ZoneSummary(100)).questsStatus == "ready", "another reader built it")
RunTimers()
check(fired == 2 and scans == scansBefore + 1, "the waiter still hears, and nothing is scanned twice")
settings.count_quests = nil

-- Subscribe: a settings change notifies; an erroring subscriber doesn't stop the rest; unsubscribe stops it.
local toggles = {}
local root = {}
function root.CreateTitle() end
function root.CreateButton()
	return root
end
function root.CreateCheckbox(_, _, _, toggle, key)
	toggles[key] = toggle
	return { SetEnabled = function() end, SetTooltip = function() end }
end
ns.Completion.AddMenu(root)
local unsubscribeFailing = API.Subscribe(function()
	error("subscriber bug")
end)
toggles.areas("areas")
check(settings.count_areas == false and fired == 3 and #errors == 1, "a settings change notifies every subscriber")
unsubscribe()
unsubscribe()
unsubscribeFailing()
ns.Live.Invalidate()
toggles.areas("areas")
check(fired == 3 and #errors == 1, "unsubscribing, even twice, stops the callbacks")
check(not pcall(API.Subscribe, "nope"), "a non-function subscriber is refused")

-- Targets: unfinished, known to the game and visible only; done, unknown and finished challenges are left out.
local targets = assert(API.Targets(100, 5))
check(#targets == 2, "two unfinished objectives")
check(targets[1].text == "Explore North" and targets[1].kind == "explore", "in the data's order")
check(targets[1].achievementID == 10 and targets[1].criteriaID == 1, "a target names its criterion")
check(targets[1].place.map == 100 and targets[1].place.x == 0.1 and targets[1].place.y == 0.2, "a located place")
check(targets[1].quantity == nil, "a one-step criterion has no quantity")
check(targets[2].place == nil, "no place without coordinates")
check(targets[2].quantity == 3 and targets[2].required == 10, "counted progress")
check(assert(API.Targets(100, 5))[1].key == targets[1].key, "keys are stable across calls")
targets[1].place.x, targets[1].text = 9, "changed"
check(assert(API.Targets(100, 5))[1].place.x == 0.1 and data.zones[100][1].x == 0.1, "targets are detached copies")
check(#assert(API.Targets(100, 0)) == 1 and #assert(API.Targets(100, 1.7)) == 1, "the limit is clamped up to 1")
check(#assert(API.Targets(100, 99)) == 2, "the limit is clamped to 5")
check(#assert(API.Targets(200, 5)) == 0, "a zone with nothing unfinished known is empty")
check(select(2, API.Targets(999, 5)) == "unsupported", "a map without data is unsupported")
check(select(2, API.Targets(100, "5")) == "invalid", "a string limit is invalid")

-- Navigate: re-validated, and only a journey or waypoint is success.
check(API.Navigate(100, targets[1].key) == true, "a current key navigates")
check(#waypoints == 1 and waypoints[1].x == 0.1 and waypoints[1].y == 0.2, "through the native waypoint")
local ok, reason = API.Navigate(100, targets[2].key)
check(not ok and reason == "unlocated" and #waypoints == 1, "no coordinates, no waypoint")
ok, reason = API.Navigate(100, "nonsense")
check(not ok and reason == "invalid", "a malformed key is invalid")
ok, reason = API.Navigate(999, targets[1].key)
check(not ok and reason == "invalid", "a map without data is invalid")
canSet = false
ok, reason = API.Navigate(100, targets[1].key)
check(not ok and reason == "unavailable", "a map without waypoints is unavailable")
ShortestPathForever = {
	API = {
		version = 1,
		Navigate = function(...)
			journeys[#journeys + 1] = { ... }
			return false
		end,
	},
}
inCombat = true
ok, reason = API.Navigate(100, targets[1].key)
check(not ok and reason == "combat" and #journeys == 1, "Shortest Path declining in combat is combat")
check(#printed == 0, "chat is never the result")
ShortestPathForever, canSet, inCombat = nil, true, false
criteria[10][1].completed = true
ok, reason = API.Navigate(100, targets[1].key)
check(not ok and reason == "stale" and #waypoints == 1, "a finished objective's key is stale")

-- Art is never stretched: inline icons keep the atlas's shape within 2% in whole pixels.
local function Shape(markup)
	local height, width = markup:match(":(%d+):(%d+)|a$")
	return tonumber(width), tonumber(height)
end
for _, size in ipairs({ 12, 14 }) do
	local width, height = Shape(ns.Completion.Icon("legacy", size))
	check(height <= size and height >= size - 2, "the Legacy shield stays about " .. size .. " tall")
	check(math.abs(width / height / (50 / 73) - 1) <= 0.025, "the Legacy shield keeps its 50 by 73 shape")
end
check(ns.Completion.Icon("areas", 14) == "|A:islands-queue-prop-compass:14:14|a", "a near-square compass")
check(ns.Completion.Icon("taxis", 12) == "|A:flightmaster:12:12|a", "a square atlas fills the square")

-- Every draw path on a cold index: the tracker's section, a badge's tooltip (which reads its continent), the map's
-- corner and badges. None builds the index during the draw; quests draw as pending, and one build is
-- scheduled for the next frame.
local drawn = {}
-- A frame, font string, block or tooltip that takes any call and keeps the text it is given.
local function Stub()
	return setmetatable({}, {
		__index = function(stub, method)
			local fn = function(_, ...)
				for index = 1, select("#", ...) do
					local value = (select(index, ...))
					if type(value) == "string" then
						drawn[#drawn + 1] = value
					end
				end
				return Stub()
			end
			rawset(stub, method, fn)
			return fn
		end,
	})
end
local function Color()
	return {
		r = 1,
		g = 1,
		b = 1,
		GetRGB = function()
			return 1, 1, 1
		end,
		WrapTextInColorCode = function(_, text)
			return text
		end,
	}
end
NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR, GREEN_FONT_COLOR, GRAY_FONT_COLOR = Color(), Color(), Color(), Color()
local function Line(_, text)
	drawn[#drawn + 1] = text
end
GameTooltip_AddBlankLineToTooltip, GameTooltip_AddHighlightLine, GameTooltip_AddNormalLine = Line, Line, Line
settings.tracker, settings.count_quests = true, true
assert(loadfile("Integrations/Quests.lua"))("LegacyForever", ns)
local scansCold = scans
check(ns.Quests.Cold(), "a fresh index is cold")
local module = Stub()
module.Header = { Percent = Stub(), Progress = Stub() }
zoneTracker.LayoutContents(module)
ns.Completion.AddSummary(Stub(), 100)
local corner = assert(ns.ZoneCompletion.Of(100))
local badges = assert(ns.ZoneCompletion.Continent(1))
check(scans == scansCold and #timers == 1, "no draw builds a cold index; one build is scheduled")
check(corner.quests.total == 0 and corner.quests.pending == 1, "the corner draws quests as pending")
check(badges.zones == 1 and badges.complete == 0, "the continent counts the zone, not complete while its quests load")
local text = table.concat(drawn, "\n")
check(text:find("Elwynn Forest", 1, true) and text:find("?", 1, true), "the tracker and tooltip draw quests as ?")
RunTimers()
check(scans == scansCold + 1 and not ns.Quests.Cold(), "the next frame builds the index once")
check(assert(ns.ZoneCompletion.Of(100)).quests.total == 2, "and the next draw counts the zone's quests")
settings.tracker, settings.count_quests = nil, nil

-- The zone completion tooltip: a grey Adventure Guide Forever line while it isn't installed, behind the shared
-- family switch, and never for one that is on, turned off, switched off or dismissed.
local agf = "missing"
C_AddOns = {
	IsAddOnLoaded = function(folder)
		return folder == "AdventureGuideForever" and agf == "on"
	end,
	DoesAddOnExist = function(folder)
		return folder ~= "AdventureGuideForever" or agf ~= "missing"
	end,
}
WHITE_FONT_COLOR = Color()
GameTooltip_SetTitle, GameTooltip_AddColoredLine, GameTooltip_AddInstructionLine = Line, Line, Line
GameTooltip_AddDisabledLine = Line
GameTooltip = {
	SetOwner = function() end,
	AddDoubleLine = Line,
	Show = function() end,
}
local AGF_LINE = "Adventure Guide Forever routes the quests left in this zone."
local function ZoneTooltip()
	drawn = {}
	LegacyForeverZoneOverlayMixin.OnEnter({ name = "Elwynn Forest", result = assert(ns.ZoneCompletion.Of(100)) })
	local found = 0
	for index, line in ipairs(drawn) do
		if line == AGF_LINE then
			found = found + 1
			check(index == #drawn - 1, "the line sits under the counts, above the click hint")
		end
	end
	return found
end
check(ZoneTooltip() == 1, "Adventure Guide missing: one grey line, on by default")
agf = "off"
check(ZoneTooltip() == 0, "installed but turned off: no line, the player chose that")
agf = "on"
check(ZoneTooltip() == 0, "on: no line")
agf = "missing"
LegacyForeverDB.suggestFamily = false
check(ZoneTooltip() == 0, "switched off: no line")
LegacyForeverDB.suggestFamily = nil
LegacyForeverDB.familyDismissed = { ["LegacyForever.zoneAdventureGuide"] = true }
check(ZoneTooltip() == 0, "dismissed: no line")
LegacyForeverDB.familyDismissed = nil
settings.count_areas, criteria[900] = false, { { completed = true } }
ns.Live.Invalidate()
check(assert(ns.ZoneCompletion.Of(100)).complete and ZoneTooltip() == 0, "a zone with nothing left: no line")
settings.count_areas, criteria[900] = nil, nil
ns.Live.Invalidate()
LegacyForeverDB.companions = false
check(ZoneTooltip() == 0, "an old Suggest companion addons off carries over")
check(LegacyForeverDB.suggestFamily == false and LegacyForeverDB.companions == nil, "and is migrated once")

print(("api_spec: %d checks passed"):format(checks))
