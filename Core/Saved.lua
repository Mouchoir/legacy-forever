local _, addon = ...

-- A class, not a reference, so ns.SavedTable keeps its overloads for the files that own a data table.
---@class LegacyForeverNamespace
local ns = addon

-- What the addon keeps between sessions, and the only file that names LegacyForeverDB. Switches are read and
-- written by their saved key alone; where a key sits in the saved table, what it defaults to and who hears
-- about a change stay in here. The toc loads the saved variables before any file runs
-- (LoadSavedVariablesFirst), but Forever's beta client can start without them, so every access makes the
-- table it needs.
---@class LegacySaved
local Saved = {}
ns.Saved = Saved

-- Every switch's default. A saved switch stays nil until the player changes it, and nil reads as the
-- default here, so an old save file and a new option always agree.
---@type LegacyDefaults
local DEFAULTS = {
	-- The shading is the quickest way to see what a zone still hides.
	showAreas = true,
	-- One chat line after an update, never on a first install.
	whatsNew = true,
	-- A grey line where one of the other Forever addons, not installed, would do more for you. The shared
	-- Forever addons page (UI/ForeverFamily.lua) reads it from the saved table by this name.
	suggestFamily = true,
	zoneCompletion = {
		-- The map is on so the feature is visible; the tracker takes screen space, so it waits to be asked.
		map = true,
		tracker = false,
		mapCollapsed = false,
		trackerCollapsed = false,
		-- Only Legacy objectives count: areas (each an "Explore <zone>" step toward Explorer), Spelunker
		-- dungeons, Conqueror raids and the zone's other Legacy steps. No Legacy challenge asks for flight
		-- paths, these reputations or quests, so they wait under "What counts" to be ticked.
		count_areas = true,
		count_taxis = false,
		count_dungeons = true,
		count_raids = true,
		count_legacy = true,
		count_reputations = false,
		count_quests = false,
	},
}

---@return LegacySavedVariables
local function Root()
	LegacyForeverDB = LegacyForeverDB or {}
	local root = LegacyForeverDB
	-- Before 0.8 the Shortest Path line had its own switch, "Suggest companion addons". A player who turned it
	-- off has every family suggestion off, once: the old key goes, so turning the new one back on sticks.
	if root.companions ~= nil then
		if root.companions == false then
			root.suggestFamily = false
		end
		root.companions = nil
	end
	return root
end

-- The saved table itself, for the shared Forever addons code, which reads suggestFamily and keeps the
-- dismissed suggestions (familyDismissed) in it.
---@return LegacySavedVariables
function ns.FamilyDB()
	return Root()
end

-- A table of the addon's own data in the saved variables. Its owner (the tracked list, the flight path
-- records) reads and writes it; callers look it up each time rather than holding on to it.
---@overload fun(key: 'tracked'): LegacyTrackingKey[]
---@overload fun(key: 'flightPaths'): table<string, LegacyFlightRecord>
---@param key 'tracked'|'flightPaths'
---@return LegacyTrackingKey[]|table<string, LegacyFlightRecord>
function ns.SavedTable(key)
	local root = Root()
	root[key] = root[key] or {}
	return root[key]
end

---@return ForeverTrackerSettings
function ns.TrackerHostSettings()
	local root = Root()
	if type(root.trackerHost) ~= "table" then
		root.trackerHost = { attached = true }
	end
	return root.trackerHost
end

-- Where a switch is saved and where its default is declared: the top-level switches beside the data,
-- every other key (the zone completion surfaces, collapse states and "count_" .. category) under
-- zoneCompletion, as save files have always had them.
---@param key string
---@return table<string, boolean> saved
---@return table<string, boolean> defaults
local function Home(key)
	local root = Root()
	if type(DEFAULTS[key]) == "boolean" then
		return root, DEFAULTS
	end
	root.zoneCompletion = root.zoneCompletion or {}
	return root.zoneCompletion, DEFAULTS.zoneCompletion
end

-- A switch's default; a key nothing declares is off.
---@param key string
---@return boolean
function Saved.Default(key)
	local _, defaults = Home(key)
	return defaults[key] == true
end

-- A switch: what the player saved, its default while unset. Reading never writes the switch.
---@param key string
---@return boolean
function Saved.Get(key)
	local value = Home(key)[key]
	if value == nil then
		return Saved.Default(key)
	end
	return value
end

---@type (fun(key: string, value: boolean))[]
local listeners = {}

-- Called after every Set with the key and its new value, in the order registered. A listener picks the keys
-- it draws from.
---@param callback fun(key: string, value: boolean)
function Saved.OnChange(callback)
	listeners[#listeners + 1] = callback
end

-- Save a switch and tell the listeners, whoever asked: a menu, the Settings page, a collapse arrow.
---@param key string
---@param value boolean
function Saved.Set(key, value)
	Home(key)[key] = value
	for _, callback in ipairs(listeners) do
		ns.SafeCall("settings listener", callback, key, value)
	end
end

-- Remember the running version, and return the one remembered before it (nil on a first install).
---@param version string
---@return string? last
function Saved.SeenVersion(version)
	local root = Root()
	local last = root.lastVersion
	root.lastVersion = version
	return last
end
