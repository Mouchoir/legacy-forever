---@type string, LegacyForeverNamespace
local addonName, ns = ...
local L = ns.L

-- Options -> AddOns -> Legacy Forever: a short index page, then a stock subpage per group so no page grows
-- tall. Every row goes in through Settings.RegisterInitializer, which inserts it from Blizzard's secure
-- delegate: Settings.CreateCheckbox inserts from our code instead, and the settings search reads every layout,
-- so that tainted it, and a restricted button in its results (Social's Discord Sign In) was then blocked and
-- blamed on this addon.
-- The Legacy map menu keeps its own toggles. Both ends go through ns.Saved, so the two never disagree; the one
-- exception is "Suggest my other Forever addons", which the shared Forever addons page writes in the saved
-- table itself and the map menu reads each time it opens.

local PREFIX = "LegacyForever_"

-- One switch: the same key, default and tooltip the Legacy map menu uses. The row is a proxy: it holds no
-- value of its own and reads and saves through ns.Saved, which redraws whatever the switch affects. `usable`
-- greys the row out. The row inserts from Blizzard's delegate.
---@param category SettingsCategoryMixin
---@param key string
---@param name string
---@param tooltip? string|fun(): string?
---@param usable? fun(): boolean
local function AddCheckbox(category, key, name, tooltip, usable)
	local setting = Settings.RegisterProxySetting(
		category,
		PREFIX .. key,
		Settings.VarType.Boolean,
		name,
		ns.Saved.Default(key),
		function()
			return ns.Saved.Get(key)
		end,
		function(value)
			ns.Saved.Set(key, value)
		end
	)
	local initializer = Settings.CreateCheckboxInitializer(setting, nil, tooltip)
	if usable then
		initializer:AddModifyPredicate(usable)
	end
	Settings.RegisterInitializer(category, initializer)
end

-- A switch saved from anywhere (the Legacy map menu, this page): its row reads the value again, so the page
-- stays in step while it is open. A switch with no row (a collapse state) has no setting to notify.
ns.Saved.OnChange(function(key)
	Settings.NotifyUpdate(PREFIX .. key)
end)

-- A subpage's button on the index, which opens it. The index stays out of search: the search finds the
-- settings themselves.
---@param category SettingsCategoryMixin
---@param subcategory SettingsCategoryMixin
---@param name string
---@return SettingsCategoryMixin
local function IndexButton(category, subcategory, name)
	Settings.RegisterInitializer(
		category,
		CreateSettingsButtonInitializer(name, L["Open"], function()
			Settings.OpenToCategory(subcategory:GetID())
		end, nil, false)
	)
	return subcategory
end

-- A subpage of rows and its button on the index.
---@param category SettingsCategoryMixin
---@param name string
---@return SettingsCategoryMixin
local function Section(category, name)
	return IndexButton(category, Settings.RegisterVerticalLayoutSubcategory(category, name), name)
end

local category = Settings.RegisterVerticalLayoutCategory(ns.TITLE)

local map = Section(category, L["World map"])
AddCheckbox(map, "showAreas", L["Show undiscovered areas"])
AddCheckbox(
	map,
	"map",
	L["On the world map"],
	L["The zone you're viewing in the map's corner, and a badge on each zone of a continent map."]
)

local tracker = Section(category, L["Objective tracker"])
local host = ns.TrackerHost
if host and host.GetSettings and host.SetAttached and host.OnAttachmentChanged then
	local variable = PREFIX .. "trackerAttached"
	local attachment = Settings.RegisterProxySetting(
		tracker,
		variable,
		Settings.VarType.Boolean,
		L["Attach to quest tracker"],
		true,
		function()
			return host.GetSettings().attached
		end,
		function(value)
			host.SetAttached(value)
		end
	)
	Settings.RegisterInitializer(
		tracker,
		Settings.CreateCheckboxInitializer(
			attachment,
			nil,
			L["Turn this off to drag the shared Forever tracker anywhere on screen."]
		)
	)
	host.OnAttachmentChanged(function()
		Settings.NotifyUpdate(variable)
	end)
end

-- Named in full: this page has no "Zone completion" title above the row, as the map menu has, and the Legacy
-- section of tracked challenges is not this switch's to hide.
AddCheckbox(
	tracker,
	"tracker",
	L["Zone completion in the tracker"],
	L["The zone you're in and what is left to do there. Challenges you track keep their own Legacy section."]
)

local counts = Section(category, L["What counts"])
for _, key in ipairs(ns.Model.COMPLETION_CATEGORIES) do
	local tooltip
	local usable
	if key == "quests" then
		tooltip = ns.Completion.QuestsStatusText
		usable = ns.Completion.QuestsUsable
	end
	AddCheckbox(counts, "count_" .. key, ns.Completion.Label(key), tooltip, usable)
end

local updates = Section(category, L["Updates"])
AddCheckbox(updates, "whatsNew", L["What's new after an update"])

-- The Forever addons page is shared by all five addons (UI/ForeverFamily.lua), with "Suggest my other Forever
-- addons" on it. ns.Family is bound to Legacy's L, so the page reads in Legacy's translations whichever addon's
-- copy of the file is in use. It reads and writes suggestFamily in the saved table itself; the map menu reads it
-- on opening.
local familyName = L["Forever addons"]
local familyPanel = ns.Family.CreatePanel(nil, ns.FamilyDB, addonName)
IndexButton(category, Settings.RegisterCanvasLayoutSubcategory(category, familyPanel, familyName), familyName)

Settings.RegisterAddOnCategory(category)
