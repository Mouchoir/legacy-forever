local _, addon = ...

---@class LegacyForeverNamespace
---@field TITLE string
---@field POINTS_ICON string
---@field WHATS_NEW string
---@field CompanionHint fun(): string?
---@field WhatsNew fun()
---@field L table<string, string>
---@field Art LegacyArt
---@field Saved LegacySaved
---@field Data LegacyData
---@field Model LegacyModel
---@field Live LegacyLive
---@field Quests LegacyQuests
---@field TrackerHost ForeverTrackerHostAPI
---@field Family ForeverFamilyAPI
---@field FamilyDB fun(): LegacySavedVariables
---@field Tracker LegacyTracker
---@field ZoneCompletion LegacyZoneCompletion
---@field Completion LegacyCompletion
---@field MapContents LegacyMapContents
---@field MapCanvas LegacyMapCanvas the views of our own on the world map (UI/MapCanvas.lua)
---@field RefreshMap fun()
---@field OpenMapMenu fun()
---@field Navigate fun(uiMapID: number, x: number, y: number, title: string)
---@field NavigateHint fun(): string
---@field Guide fun(uiMapID: number, x: number, y: number, title: string): boolean, ("combat"|"unavailable")?
---@field SafeCall fun(label: string, fn: function, ...: any): boolean, ... run fn as pcall does (Core/SafeCall.lua)
---@field RecordError fun(label: string, message: any, stack?: string) keep an error caught another way, for the report
---@field CaughtErrors fun(): LegacyCaughtError[] this session's caught errors, oldest first, as copies
---@field CutText fun(text: string, limit: integer): string text cut to `limit` bytes on a UTF-8 boundary, ending "..."
---@field Report LegacyReportModule the report window (UI/Report.lua)
---@field AuditLines fun(): string[] what /lf audit prints (Core/Report.lua)
---@field ReportLines fun(): string[] Legacy Forever's own lines in the report (Core/Report.lua)
local ns = addon
local L = ns.L

ns.TITLE = "Legacy Forever"
-- The Legacy shield: map pins, the map button, menu entries and the zone-completion count all wear it.
ns.POINTS_ICON = "UI-Legacy-Points-icon-c60"
-- One sentence for the chat line after an update (WhatsNew.lua): the headline of the release this ships in.
ns.WHATS_NEW = L["The tracker sections now move clear of Questie's quest list."]

---@param msg string
function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. ns.TITLE .. "|r " .. msg)
end

-- /lf audit: the same lines /lf report shows (Core/Report.lua), in chat.
local function Audit()
	for _, line in ipairs(ns.AuditLines()) do
		ns.Print(line)
	end
end

-- Every criterion the game reports for one achievement, for reporting data mismatches.
---@param achievementID number
local function Criteria(achievementID)
	local count = GetAchievementNumCriteria(achievementID) or 0
	ns.Print(
		("achievement %d (%s): %d criteria"):format(achievementID, ns.Live.Name(achievementID) or "unknown", count)
	)
	for index = 1, count do
		local text, criteriaType, completed, _, _, _, _, asset, _, criteriaID =
			GetAchievementCriteriaInfo(achievementID, index)
		ns.Print(
			("  %d: id %s type %s asset %s %s%s"):format(
				index,
				tostring(criteriaID),
				tostring(criteriaType),
				tostring(asset),
				text or "",
				completed and " (done)" or ""
			)
		)
	end
end

-- The options live in the map's Legacy menu, so the slash command and the compartment entry both open it.
local function OpenMenu()
	if not (WorldMapFrame and WorldMapFrame:IsShown()) then
		C_Map.OpenWorldMap()
	end
	ns.OpenMapMenu()
end

SLASH_LEGACYFOREVER1 = "/lf"
SLASH_LEGACYFOREVER2 = "/legacyforever"
local function Slash(msg)
	local command = strtrim(msg or ""):lower()
	-- Lenient: "criteria 684", "criteria <684>" and a bare "684" all work.
	local achievementID = (command:find("^criteria") or command:find("^%d+$")) and tonumber(command:match("%d+"))
	if command == "report" then
		-- The report is for when something is wrong, so a failing audit still opens it, with the error listed.
		local ok, lines = ns.SafeCall("report lines", ns.ReportLines)
		ns.Report.Show(ns.Report.Text(ok and lines or { "audit: failed, see Errors" }))
	elseif command == "audit" then
		Audit()
	elseif achievementID then
		Criteria(achievementID)
	elseif command:find("^criteria") then
		ns.Print("usage: /lf criteria 684")
	elseif command == "" then
		OpenMenu()
	else
		ns.Print(L["/lf - open the world map and its Legacy menu"])
		ns.Print(L["/lf report - show a report to copy into a bug report"])
		ns.Print(L["/lf audit - check the bundled data against the game"])
		ns.Print(L["/lf criteria 684 - list what the game reports for one achievement"])
	end
end
SlashCmdList.LEGACYFOREVER = function(msg)
	ns.SafeCall("slash command", Slash, msg)
end

LegacyForever_OnAddonCompartmentClick = OpenMenu
