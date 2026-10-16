-- Run from the repository root: luajit tests/family_locale_spec.lua
-- Legacy's Forever addons page reads in Legacy's own translations even when another Forever addon's copy of the
-- shared UI/ForeverFamily.lua loaded first (cjber/shortest-path-forever#201), and Legacy's French covers every
-- phrase that file shows.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

function GetLocale()
	return "frFR"
end
local function English()
	return {
		L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
	}
end
local function LoadLegacy()
	local legacy = {}
	assert(loadfile("Locales/enUS.lua"))("LegacyForever", legacy)
	assert(loadfile("Locales/frFR.lua"))("LegacyForever", legacy)
	assert(loadfile("UI/ForeverFamily.lua"))("LegacyForever", legacy)
	return legacy
end

-- An older copy (VERSION 2, as shipped) loaded first: Legacy's newer copy takes over, bound to Legacy's L.
ForeverFamily = { VERSION = 2 }
local legacy = LoadLegacy()
check(ForeverFamily.VERSION == 3 and legacy.Family == ForeverFamily.For(legacy.L), "a newer copy takes over")

-- A VERSION 3 copy of an English-only addon loaded first, as Shortest Path Forever does (Legacy's OptionalDeps):
-- it stays in use, and each addon's view keeps its own L.
ForeverFamily = nil
local other = English()
assert(loadfile("UI/ForeverFamily.lua"))("ShortestPathForever", other)
local Family = ForeverFamily
legacy = LoadLegacy()
check(ForeverFamily == Family and other.Family == Family.For(other.L), "the first copy stays in use")
check(legacy.Family == Family.For(legacy.L) and legacy.Family ~= other.Family, "Legacy's view is its own")

local seen = {}
local CreatePanel, ShowLink = Family.CreatePanel, Family.ShowLink
Family.CreatePanel = function(_, _, _, locale)
	seen.panel = locale
end
Family.ShowLink = function(_, _, _, _, locale)
	seen.link = locale
end
legacy.Family.CreatePanel(nil, {}, "LegacyForever")
legacy.Family.ShowLink(nil, nil, "ShortestPathForever")
check(seen.panel == legacy.L and seen.link == legacy.L, "Legacy's page and window are built with Legacy's L")
other.Family.CreatePanel(nil, {}, "ShortestPathForever")
other.Family.ShowLink(nil, nil, "LegacyForever")
check(seen.panel == other.L and seen.link == other.L, "the other addon's page and window keep its L")
Family.CreatePanel, Family.ShowLink = CreatePanel, ShowLink

-- The real page, drawn through the other addon's copy: its text is Legacy's French.
local texts = {}
local function Widget()
	return setmetatable({}, {
		__index = function(self, method)
			local fn
			if method == "SetText" then
				fn = function(_, text)
					texts[#texts + 1] = text
				end
			elseif method:find("^Create") then
				fn = function()
					return Widget()
				end
			elseif method == "SetScript" then
				fn = function(widget, event, handler)
					rawset(widget, event, handler)
				end
			else
				fn = function() end
			end
			rawset(self, method, fn)
			return fn
		end,
	})
end
function CreateFrame()
	return Widget()
end
C_AddOns = {
	IsAddOnLoaded = function()
		return false
	end,
	DoesAddOnExist = function()
		return false
	end,
}
local panel = legacy.Family.CreatePanel(nil, {}, "LegacyForever")
panel.OnShow(panel)
local shown = table.concat(texts, "\n")
for _, phrase in ipairs({ "Suggest my other Forever addons", "Copy link", "This addon", "Not installed" }) do
	local french = rawget(legacy.L, phrase)
	check(french and shown:find(french, 1, true), "the page shows Legacy's French for " .. phrase)
end
for _, addon in ipairs(Family.ADDONS) do
	check(shown:find(rawget(legacy.L, addon.line), 1, true), "the page shows " .. addon.name .. "'s line in French")
end

-- Every phrase the shared file sends through L has a French entry, so none falls back to English on the page or
-- in the link window. A phrase reworded in a later sync without a new translation fails here.
local file = assert(io.open("UI/ForeverFamily.lua", "rb"))
local source = file:read("*a")
file:close()
local phrases = 0
for phrase in source:gmatch('L%[%s*"(.-)"%s*%]') do
	phrases = phrases + 1
	check(type(rawget(legacy.L, phrase)) == "string", "frFR translates: " .. phrase)
end
check(phrases >= 16, "the shared file's phrases are found")

print(("family_locale_spec: %d checks passed"):format(checks))
