-- Run from the repository root: luajit tests/settings_spec.lua
-- ns.Saved is the one owner of the saved switches: a missing key is its default, a saved value always wins, a
-- write lands where old save files keep it, and every write tells the listeners.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

SlashCmdList = {}
local ns = {}
assert(loadfile("Locales/enUS.lua"))("LegacyForever", ns)
assert(loadfile("Core/SafeCall.lua"))("LegacyForever", ns)
assert(loadfile("Core/Core.lua"))("LegacyForever", ns)
assert(loadfile("Core/Saved.lua"))("LegacyForever", ns)
assert(loadfile("Core/Model.lua"))("LegacyForever", ns)
local Saved = ns.Saved
local ZONE_KEYS = { "map", "tracker", "mapCollapsed", "trackerCollapsed" }
for _, category in ipairs(ns.Model.COMPLETION_CATEGORIES) do
	ZONE_KEYS[#ZONE_KEYS + 1] = "count_" .. category
end

-- A fresh install: no saved variables at all.
LegacyForeverDB = nil
check(Saved.Get("showAreas") == true, "areas are shaded out of the box")
check(
	Saved.Get("whatsNew") == true and Saved.Get("suggestFamily") == true,
	"update line and family hints on out of the box"
)
check(Saved.Get("map") == true and Saved.Get("tracker") == false, "on the map, not in the tracker")
check(not Saved.Get("mapCollapsed") and not Saved.Get("trackerCollapsed"), "expanded out of the box")
for _, category in ipairs({ "areas", "dungeons", "raids", "legacy" }) do
	check(Saved.Get("count_" .. category) == true, category .. " count out of the box")
end
for _, category in ipairs({ "taxis", "reputations", "quests" }) do
	check(Saved.Get("count_" .. category) == false, category .. " wait to be ticked")
end
check(Saved.Get("unknown") == false and Saved.Default("unknown") == false, "an undeclared key reads as off")
check(LegacyForeverDB.showAreas == nil, "reading a default saves nothing")
for _, key in ipairs(ZONE_KEYS) do
	check(Saved.Default(key) == Saved.Get(key), key .. " reads as its default")
	check(LegacyForeverDB.zoneCompletion[key] == nil, key .. " is not written by a read")
end

-- A save file from before the defaults were declared: every saved true or false keeps its meaning.
LegacyForeverDB = {
	showAreas = false,
	zoneCompletion = { map = false, tracker = true, mapCollapsed = true, count_areas = false, count_quests = true },
}
check(Saved.Get("showAreas") == false, "a saved off stays off")
check(Saved.Get("map") == false and Saved.Get("tracker") == true, "saved surfaces win")
check(Saved.Get("mapCollapsed") == true and Saved.Get("trackerCollapsed") == false, "saved collapse wins")
check(Saved.Get("count_areas") == false and Saved.Get("count_quests") == true, "saved categories win")
check(Saved.Get("count_raids") == true, "a key the old file lacks is its default")
check(Saved.Default("showAreas") == true and Saved.Default("map") == true, "a saved value leaves the default alone")

-- Saved true for a default-on switch is still on.
LegacyForeverDB = { showAreas = true }
check(Saved.Get("showAreas") == true, "a saved on stays on")

-- The pre-0.8 "Suggest companion addons" switch: turned off, it turns the family suggestions off once and
-- goes; on or unset, it just goes.
LegacyForeverDB = { companions = false }
check(Saved.Get("suggestFamily") == false, "an old off turns the family suggestions off")
check(LegacyForeverDB.companions == nil and LegacyForeverDB.suggestFamily == false, "the old switch is gone")
Saved.Set("suggestFamily", true)
check(Saved.Get("suggestFamily") == true, "turning them back on sticks: the migration ran once")
LegacyForeverDB = { companions = true }
check(Saved.Get("suggestFamily") == true and LegacyForeverDB.suggestFamily == nil, "an old on keeps the default")
check(LegacyForeverDB.companions == nil, "an old on is dropped too")
LegacyForeverDB = { companions = false }
check(ns.FamilyDB() == LegacyForeverDB and LegacyForeverDB.suggestFamily == false, "the family table is migrated")

-- Writes keep the shape save files already have: three switches at the top, the rest under zoneCompletion
-- by the same keys, beside the data tables and untouched by them.
local tracked = { "a:1" }
LegacyForeverDB = { tracked = tracked, lastVersion = "0.6.0", zoneCompletion = { count_taxis = true } }
for _, key in ipairs({ "showAreas", "whatsNew", "suggestFamily" }) do
	Saved.Set(key, false)
	check(LegacyForeverDB[key] == false and Saved.Get(key) == false, key .. " is saved at the top level")
	check(LegacyForeverDB.zoneCompletion[key] == nil, key .. " stays out of zone completion")
end
for _, key in ipairs(ZONE_KEYS) do
	local value = not Saved.Get(key)
	Saved.Set(key, value)
	check(
		LegacyForeverDB.zoneCompletion[key] == value and Saved.Get(key) == value,
		key .. " is saved in zoneCompletion"
	)
	check(LegacyForeverDB[key] == nil, key .. " stays out of the top level")
end
check(LegacyForeverDB.tracked == tracked and ns.SavedTable("tracked") == tracked, "the tracked list is left alone")
check(LegacyForeverDB.lastVersion == "0.6.0", "the remembered version is left alone")
check(Saved.SeenVersion("0.7.0") == "0.6.0" and LegacyForeverDB.lastVersion == "0.7.0", "a new version is remembered")

-- With no saved variables loaded at all, a write makes the table it needs.
LegacyForeverDB = nil
Saved.Set("tracker", true)
check(LegacyForeverDB.zoneCompletion.tracker == true, "a write on an empty save file lands")
LegacyForeverDB = nil
check(Saved.SeenVersion("0.7.0") == nil and LegacyForeverDB.lastVersion == "0.7.0", "a first install has no version")
check(next(ns.SavedTable("flightPaths")) == nil and LegacyForeverDB.flightPaths, "a data table is made on first use")
check(ns.TrackerHostSettings().attached == true, "the shared tracker starts attached")
LegacyForeverDB.trackerHost = "broken"
check(ns.TrackerHostSettings().attached == true, "a malformed tracker record is replaced")

-- The change notice: every write tells every listener the key and its new value, after the value is saved,
-- in the order they registered.
LegacyForeverDB = nil
local heard = {}
Saved.OnChange(function(key, value)
	heard[#heard + 1] = ("first %s=%s saved=%s"):format(key, tostring(value), tostring(Saved.Get(key)))
end)
Saved.OnChange(function(key)
	heard[#heard + 1] = "second " .. key
end)
Saved.Set("count_quests", true)
check(
	table.concat(heard, ", ") == "first count_quests=true saved=true, second count_quests",
	"listeners hear a write in order, with the value already saved"
)
Saved.Set("showAreas", false)
Saved.Set("showAreas", false)
check(#heard == 6 and heard[5] == "first showAreas=false saved=false", "a repeated write is told again")
Saved.Get("showAreas")
check(#heard == 6, "a read tells nobody")
LegacyForeverDB = nil

-- A bare /lf opens the map's Legacy menu, where the options live, as the compartment entry does.
function strtrim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
local calls, printed = {}, {}
WorldMapFrame = {
	IsShown = function()
		return calls.map ~= nil
	end,
}
C_Map = {
	OpenWorldMap = function(uiMapID)
		assert(uiMapID == nil, "the menu opens the map where the player is")
		calls.map = (calls.map or 0) + 1
	end,
}
function ns.OpenMapMenu()
	calls.menu = (calls.menu or 0) + 1
end
function ns.Print(text)
	printed[#printed + 1] = text
end
SlashCmdList.LEGACYFOREVER("")
check(calls.map == 1 and calls.menu == 1 and #printed == 0, "a bare /lf opens the map and its menu")
LegacyForever_OnAddonCompartmentClick()
check(calls.map == 1 and calls.menu == 2, "the compartment entry opens the menu on the open map")
SlashCmdList.LEGACYFOREVER("help")
check(#printed == 4 and calls.menu == 2, "/lf help prints the commands")
check(printed[2] == "/lf report - show a report to copy into a bug report", "the help names /lf report")

-- The Settings page: the same options as subcategories with an index page, every row through
-- RegisterInitializer (CreateCheckbox and layout:AddInitializer would taint the settings search), and every
-- row a proxy onto ns.Saved, so the page and the map menu's own toggles share one value.
local registered, subcategories, opened = {}, {}, {}
local function Category(name)
	return {
		name = name,
		GetID = function()
			return name
		end,
	}
end
local trackerState = { attached = true }
local attachmentChanged
local notified = {}
ns.TrackerHost = {
	GetSettings = function()
		return trackerState
	end,
	SetAttached = function(value)
		trackerState.attached = value
		attachmentChanged()
	end,
	OnAttachmentChanged = function(callback)
		attachmentChanged = callback
	end,
}
Settings = {
	-- As ProxySettingMixin: no value of its own, and a set only when the value differs.
	RegisterProxySetting = function(_, variable, varType, name, default, get, set)
		return {
			variable = variable,
			key = (variable:gsub("^LegacyForever_", "")),
			varType = varType,
			name = name,
			default = default,
			GetValue = get,
			SetValue = function(_, value)
				if get() ~= value then
					set(value)
				end
			end,
		}
	end,
	NotifyUpdate = function(variable)
		notified[#notified + 1] = variable
	end,
	VarType = { Boolean = "boolean" },
	RegisterVerticalLayoutCategory = function(name)
		check(name == "Legacy Forever", "the category is named after the addon")
		return Category(name)
	end,
	RegisterVerticalLayoutSubcategory = function(_parent, name)
		subcategories[#subcategories + 1] = { category = Category(name) }
		return subcategories[#subcategories].category
	end,
	RegisterCanvasLayoutSubcategory = function(parent, frame, name)
		check(parent.name == "Legacy Forever" and frame.Refresh, "the Forever addons page is the shared panel")
		subcategories[#subcategories + 1] = { category = Category(name), frame = frame }
		return subcategories[#subcategories].category
	end,
	RegisterAddOnSetting = function()
		error("a row that writes the saved table itself; use a proxy onto ns.Saved")
	end,
	CreateCheckbox = function()
		error("addon code inserted a row; use Settings.RegisterInitializer")
	end,
	CreateCheckboxInitializer = function(setting, options, tooltip)
		check(setting.varType == "boolean" and options == nil, "boolean rows only")
		local initializer = { setting = setting, tooltip = tooltip, modify = {} }
		function initializer.AddModifyPredicate(self, predicate)
			self.modify[#self.modify + 1] = predicate
		end
		return initializer
	end,
	RegisterInitializer = function(category, initializer)
		registered[#registered + 1] = { category = category, initializer = initializer }
	end,
	RegisterAddOnCategory = function(category)
		check(category.name == "Legacy Forever", "the category is registered")
	end,
	OpenToCategory = function(id)
		opened[#opened + 1] = id
	end,
}
function CreateSettingsButtonInitializer(name, text, click, _tooltip, addSearchTags)
	check(text == "Open" and addSearchTags == false, "index buttons stay out of search")
	return { button = true, name = name, click = click }
end
local questsUsable = true
ns.Completion = {
	Label = function(key)
		return key
	end,
	QuestsUsable = function()
		return questsUsable
	end,
	QuestsStatusText = function()
		return "a quest source"
	end,
}
-- The shared Forever addons page builds its rows the first time it shows; until then it is one empty frame.
function CreateFrame(kind)
	check(kind == "Frame", "the page is built when it first shows")
	return { SetScript = function() end, Hide = function() end }
end
assert(loadfile("UI/ForeverFamily.lua"))("LegacyForever", ns)
local panelArgs = {}
local CreatePanel = ns.Family.CreatePanel
ns.Family.CreatePanel = function(parent, db, current)
	panelArgs.db, panelArgs.current = db, current
	return CreatePanel(parent, db, current)
end
assert(loadfile("UI/Settings.lua"))("LegacyForever", ns)
check(LegacyForeverDB == nil or next(LegacyForeverDB.zoneCompletion or {}) == nil, "building the page saves nothing")

-- Every section is a subpage; the index holds one button per subpage, in order.
check(#subcategories == 5, "five subcategory groups")
local names = { "World map", "Objective tracker", "What counts", "Updates", "Forever addons" }
for index, name in ipairs(names) do
	check(subcategories[index].category.name == name, name .. " is a subcategory")
end
local kinds, expectedKinds =
	{}, {
		"button@Legacy Forever",
		"checkbox@World map",
		"checkbox@World map",
		"button@Legacy Forever",
		"checkbox@Objective tracker",
		"checkbox@Objective tracker",
		"button@Legacy Forever",
	}
for _ = 1, 7 do
	expectedKinds[#expectedKinds + 1] = "checkbox@What counts"
end
expectedKinds[#expectedKinds + 1] = "button@Legacy Forever"
expectedKinds[#expectedKinds + 1] = "checkbox@Updates"
expectedKinds[#expectedKinds + 1] = "button@Legacy Forever"
for index, entry in ipairs(registered) do
	kinds[index] = (entry.initializer.button and "button" or "checkbox") .. "@" .. entry.category.name
end
check(table.concat(kinds, " ") == table.concat(expectedKinds, " "), table.concat(kinds, " "))

-- Every setting keeps its key and default, and has a variable of its own.
local byKey = {}
for _, entry in ipairs(registered) do
	local setting = entry.initializer.setting
	if setting then
		byKey[setting.key] = setting
	end
end
local expected = {
	trackerAttached = true,
	showAreas = true,
	map = true,
	tracker = false,
	count_areas = true,
	count_taxis = false,
	count_dungeons = true,
	count_raids = true,
	count_legacy = true,
	count_reputations = false,
	count_quests = false,
	whatsNew = true,
}
for key, default in pairs(expected) do
	check(byKey[key], key .. " is on the page")
	check(byKey[key].default == default, key .. " keeps its default")
	check(byKey[key].variable == "LegacyForever_" .. key, key .. " has its own setting variable")
end

-- The index buttons open their subpages, and never land in search.
local buttons = {}
for _, entry in ipairs(registered) do
	if entry.initializer.button then
		buttons[entry.initializer.name] = entry.initializer
	end
end
for _, name in ipairs(names) do
	buttons[name].click()
end
check(
	table.concat(opened, " ") == "World map Objective tracker What counts Updates Forever addons",
	"each button opens its subpage"
)

-- Quests grey out without Questie, as the map menu's box does, and the name and tooltip are translated.
local quests = byKey.count_quests
check(quests.name == "quests", "a category row is named by its label")
check(#registered[8].initializer.modify == 0, "only quests can grey out")
local questsRow
for _, entry in ipairs(registered) do
	if entry.initializer.setting == quests then
		questsRow = entry.initializer
	end
end
check(questsRow.modify[1](), "quests are usable while Questie is ready")
questsUsable = false
check(not questsRow.modify[1](), "quests grey out without Questie")
check(questsRow.tooltip() == "a quest source", "the quest row explains its status")

-- The tracker row says which section it switches: the Legacy section of tracked challenges is not its to hide.
local trackerRow
for _, entry in ipairs(registered) do
	if entry.initializer.setting == byKey.tracker then
		trackerRow = entry.initializer
	end
end
check(byKey.tracker.name == "Zone completion in the tracker", "the tracker row names zone completion")
check(trackerRow.tooltip:find("Legacy section", 1, true), "and says tracked challenges stay")

-- A row saves through ns.Saved, so whoever listens for the switch hears a tick on the page exactly as it hears
-- the map menu; a write from elsewhere has the row read its value again.
local before = #heard
check(byKey.map:GetValue() == true and byKey.tracker:GetValue() == false, "a row shows the default while unset")
byKey.map:SetValue(false)
check(LegacyForeverDB.zoneCompletion.map == false, "a row saves where the map menu does")
check(heard[before + 1] == "first map=false saved=false" and #heard == before + 2, "a row tells the listeners once")
check(notified[#notified] == "LegacyForever_map", "and its own row reads the value again")
byKey.count_areas:SetValue(false)
check(heard[#heard] == "second count_areas" and not Saved.Get("count_areas"), "a counted row saves and tells")
Saved.Set("showAreas", false)
check(byKey.showAreas:GetValue() == false, "a toggle elsewhere shows on the row")
check(notified[#notified] == "LegacyForever_showAreas", "a toggle elsewhere has the row read again")

check(byKey.trackerAttached:GetValue() == true, "shared tracker starts attached")
byKey.trackerAttached:SetValue(false)
check(not byKey.trackerAttached:GetValue(), "toggle detaches shared tracker")
check(notified[#notified] == "LegacyForever_trackerAttached", "change notifies proxy")
trackerState.attached = true
attachmentChanged()
check(byKey.trackerAttached:GetValue(), "other addon updates same shared state")

-- The Forever addons page carries "Suggest my other Forever addons": it reads and writes suggestFamily in
-- Legacy's own saved table (migrated from the old switch, as ns.FamilyDB returns it), and the map menu reads the
-- same key. Legacy's own row says "This addon".
check(byKey.suggestFamily == nil and byKey.companions == nil, "the family switch is the shared page's, not a row")
check(panelArgs.db == ns.FamilyDB and panelArgs.current == "LegacyForever", "the page gets Legacy's saved table")
LegacyForeverDB = { companions = false }
check(panelArgs.db().suggestFamily == false and LegacyForeverDB.companions == nil, "read through the migration")

print(("settings_spec: %d checks passed"):format(checks))
