-- Run from the repository root: luajit tests/report_spec.lua
-- /lf report (UI/Report.lua, Core/Report.lua, Core/SafeCall.lua): one selected block of text with the versions,
-- character, place, the audit lines, the caught errors and the other addons, never longer than one message; and
-- ns.SafeCall, which keeps errors for it and still hands them to the game's error handler.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end
local function has(text, part, label)
	check(text:find(part, 1, true) ~= nil, ("%s: %q not in\n%s"):format(label, part, text))
end

-- Map 100 has one located objective of challenge 10, which the game lists unfinished.
local data = {
	build = "1.60.1.70374",
	rewards = { [10] = true },
	feeds = {},
	zones = { [100] = { { achievement = 10, criteria = 1, kind = "explore", x = 0.1, y = 0.2 } } },
	completion = {},
}

-- The client.
local frames, handled = {}, {}
local focus
local metadata = {
	LegacyForever = { Version = "1.2.3" },
	Questie = { Version = "9.1.0" },
	ShortestPathForever = { Version = "0.9.0" },
}
local addons = { "LegacyForever", "Questie", "ShortestPathForever", "NotLoaded" }
C_AddOns = {
	GetAddOnMetadata = function(name, field)
		return metadata[name] and metadata[name][field]
	end,
	GetNumAddOns = function()
		return #addons
	end,
	GetAddOnInfo = function(index)
		return addons[index], addons[index]
	end,
	IsAddOnLoaded = function(index)
		return metadata[addons[index]] ~= nil
	end,
}
GetBuildInfo = function()
	return "1.60.1", "70374", "", 16001
end
GetLocale = function()
	return "enUS"
end
GetTime = function()
	return 42
end
UnitLevel = function()
	return 31
end
UnitClass = function()
	return "Paladin", "PALADIN", 2
end
UnitRace = function()
	return "Human", "Human", 1
end
UnitFactionGroup = function()
	return "Alliance"
end
geterrorhandler = function()
	return function(message)
		handled[#handled + 1] = message
	end
end
C_Map = {
	GetBestMapForUnit = function()
		return 1429
	end,
	GetPlayerMapPosition = function()
		return {
			GetXY = function()
				return 0.4123, 0.6501
			end,
		}
	end,
	GetMapInfo = function()
		return { name = "Elwynn Forest" }
	end,
}
C_Texture = { GetAtlasInfo = function() end }
strtrim = function(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
UIParent = {}
UISpecialFrames = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

-- A frame keeps its scripts, text and shown state; any other method does nothing.
local Methods = {}
function Methods:SetScript(name, fn)
	self.scripts[name] = fn
end
function Methods:SetText(text)
	self.text = text
end
function Methods:GetText()
	return self.text or ""
end
function Methods:SetTitle(text)
	self.title = text
end
function Methods:Show()
	self.shown = true
end
function Methods:Hide()
	self.shown = false
end
function Methods:IsShown()
	return self.shown == true
end
function Methods:GetParent()
	return self.parent
end
function Methods:SetFocus()
	focus = self
end
function Methods:HighlightText()
	self.highlighted = self.text
end
function Methods:SetTexture(file)
	self.file = file
end
function Methods:SetSize(width, height)
	self.width, self.height = width, height
end
local function Object(kind, parent, template)
	local object = { kind = kind, parent = parent, template = template, scripts = {} }
	return setmetatable(object, {
		-- Methods are capitalised; any other key is a field, nil until set.
		__index = function(_, key)
			return Methods[key] or (key:find("^%u") and function() end or nil)
		end,
	})
end
function Methods:CreateFontString()
	return Object("FontString", self)
end
function Methods:GetPortrait()
	self.portrait = self.portrait or Object("Texture", self)
	return self.portrait
end
CreateFrame = function(kind, _, parent, template)
	local frame = Object(kind, parent, template)
	frames[#frames + 1] = frame
	return frame
end

local ns = { Data = data }
assert(loadfile("Locales/enUS.lua"))("LegacyForever", ns)
for _, file in ipairs({ "Core/SafeCall.lua", "Core/Core.lua", "Core/Art.lua", "Core/Saved.lua", "Core/Model.lua" }) do
	assert(loadfile(file))("LegacyForever", ns)
end
local printed = {}
function ns.Print(msg)
	printed[#printed + 1] = msg
end
ns.Live = {
	Visible = function()
		return { [10] = true }
	end,
	Criteria = function()
		return { [1] = { text = "Explore North", completed = false, index = 1 } }
	end,
}
ns.Tracker = {
	Count = function()
		return 2
	end,
	IsAttached = function()
		return true
	end,
}
ns.ZoneCompletion = {
	AuditLines = function(lines)
		lines[#lines + 1] = "zone completion for Elwynn Forest (map 1429): areas 3/9"
		return lines
	end,
}
for _, file in ipairs({ "Core/Report.lua", "UI/Report.lua" }) do
	assert(loadfile(file))("LegacyForever", ns)
end
local Slash = SlashCmdList.LEGACYFOREVER

-- The window: the edit box has the focus with the whole report selected, in a stock portrait frame.
Slash("report")
local edit = focus
check(edit and edit.kind == "EditBox", "the report's edit box has the focus")
local window = edit:GetParent():GetParent():GetParent()
local text = edit:GetText()
check(edit.highlighted == text, "the whole report is selected")
check(window.template == "PortraitFrameTemplate" and window:IsShown(), "a stock portrait frame, shown")
check(UISpecialFrames[1] == "LegacyForeverReport", "Escape closes it as a panel")
check(window.title == "Legacy Forever report", "its title")
check(window.portrait.file == "Interface\\AddOns\\LegacyForever\\media\\Icon", "the addon icon as its portrait")
check(window.portrait.width == 62 and window.portrait.height == 62, "drawn square")
has(text, "LegacyForever 1.2.3 | WoW 1.60.1 (70374) 16001 | enUS", "versions, build and locale")
has(text, "Character: level 31 Human PALADIN, Alliance", "character, with no name")
has(text, "Place: map 1429 (Elwynn Forest) 41.2, 65.0", "place")
has(text, "data from build 1.60.1.70374, client build 1.60.1.70374", "the audit's build line")
has(text, "1 unfinished Legacy challenges listed for this character", "the audit's challenges")
has(text, "1 located objectives checked, 0 unknown to the game", "the audit's objectives")
has(text, "tracker: 2 tracked, Legacy section in the objective tracker", "the audit's tracker line")
has(text, "zone completion for Elwynn Forest (map 1429): areas 3/9", "the audit's zone completion")
has(text, "Errors: none caught", "no errors yet")
has(text, "Other addons (2): Questie 9.1.0, ShortestPathForever 0.9.0", "the other loaded addons with versions")
check(#printed == 0, "nothing in chat")

-- /lf audit prints the same lines in chat.
Slash("audit")
check(printed[1] == "data from build 1.60.1.70374, client build 1.60.1.70374", "the audit starts with the build")
check(printed[#printed] == "zone completion for Elwynn Forest (map 1429): areas 3/9", "and ends with the zone")
for _, line in ipairs(printed) do
	has(text, line, "every audit line is in the report")
end

-- Read-only: a key typed in the box puts the report back, selected. Escape hides it; the frame is made once.
edit.text, edit.highlighted = "x", nil
edit.scripts.OnTextChanged(edit, true)
check(edit:GetText() == text and edit.highlighted == text, "typing restores the report, selected")
edit.scripts.OnEscapePressed(edit)
check(not window:IsShown(), "Escape hides it")
local made = #frames
Slash("report")
check(window:IsShown() and #frames == made, "shown again, in the same frame")

-- ns.SafeCall: pcall's answers, and each failure kept (label, count, short stack) and passed to the error handler.
local ok, a, b, c = ns.SafeCall("test", function(x)
	return x, nil, 3
end, 1)
check(ok == true and a == 1 and b == nil and c == 3, "SafeCall returns what pcall would, nils included")
check(#ns.CaughtErrors() == 0, "nothing caught")
local failed, message = ns.SafeCall("test", error, "boom", 0)
check(failed == false and message == "boom", "a failure is false and the error")
check(#handled == 1 and handled[1] == "boom", "and is passed to the game's error handler")
ns.SafeCall("test", error, "boom", 0)
local caught = ns.CaughtErrors()
check(#caught == 1 and caught[1].count == 2 and caught[1].label == "test", "a repeat is one entry, counted")
ns.SafeCall("deep", function()
	local t = nil
	return t.field
end)
caught = ns.CaughtErrors()
check(caught[2].label == "deep", "newest last")
has(caught[2].stack, "report_spec.lua:", "the stack names the file")
for index = 1, 6 do
	ns.SafeCall("many", error, "error " .. index, 0)
end
caught = ns.CaughtErrors()
check(#caught == 5 and caught[5].message == "error 6" and caught[1].message == "error 2", "the last five kept")
caught[1].message = "changed"
check(ns.CaughtErrors()[1].message == "error 2", "CaughtErrors returns copies")
local cut = ns.CutText(("é"):rep(10), 10):sub(1, -4)
check(cut == ("é"):rep(3), "a cut never splits a character")
ns.SafeCall("long", error, ("x"):rep(400), 0)
check(#ns.CaughtErrors()[5].message == 300, "a long message is cut")
Slash("report")
text = focus:GetText()
has(text, "Errors (5):", "the report lists the caught errors")
has(text, "- [long] x1 xxx", "newest first")
check(#text <= 2000, "still one message")

-- A failing settings listener is caught and kept; the listeners after it still run.
local heard = 0
ns.Saved.OnChange(function()
	error("listener failed", 0)
end)
ns.Saved.OnChange(function()
	heard = heard + 1
end)
ns.Saved.Set("map", false)
caught = ns.CaughtErrors()
check(heard == 1, "the next listener still runs")
check(caught[#caught].label == "settings listener" and caught[#caught].message == "listener failed", "caught")

-- A failing audit: /lf audit's error is caught and reported; /lf report still opens, listing it.
local before = #handled
ns.ZoneCompletion.AuditLines = function()
	error("audit failed", 0)
end
Slash("audit")
caught = ns.CaughtErrors()
check(caught[#caught].label == "slash command" and #handled == before + 1, "a failing command is caught and reported")
focus = nil
Slash("report")
text = focus and focus:GetText() or ""
has(text, "audit: failed, see Errors", "a failing audit still opens the report")
has(text, "- [report lines] x1 audit failed", "with the audit's error listed first")

-- A long audit is cut to its room, so the errors after it still fit.
ns.ZoneCompletion.AuditLines = function(lines)
	for index = 1, 40 do
		lines[#lines + 1] = ("  explored area not in the data: %d:%d:%d:%d"):format(index, index, index, index)
	end
	return lines
end
Slash("report")
text = focus:GetText()
check(not text:find("40:40:40:40", 1, true), "a long audit is cut")
has(text, "- [report lines] x1 audit failed", "and the errors still fit")
check(#text <= 2000, "in one message")

-- Many other addons: the list says how many more, and the report stays one message.
for index = 1, 300 do
	local name = ("SomeAddon%03d"):format(index)
	addons[#addons + 1] = name
	metadata[name] = { Version = "1.0." .. index }
end
ns.ZoneCompletion.AuditLines = function(lines)
	return lines
end
Slash("report")
text = focus:GetText()
check(#text <= 2000, "many addons: one message")
has(text, "Other addons (302): Questie 9.1.0, ", "many addons: counted")
has(text, " more", "many addons: the rest counted")
check(not text:find("SomeAddon300", 1, true), "many addons: the last left out")

print(("report_spec: %d checks passed"):format(checks))
