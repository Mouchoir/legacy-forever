---@type string, LegacyForeverNamespace
local _, ns = ...
local L = ns.L

-- Forever's ruleset refuses achievement tracking (C_ContentTracking reports
-- Untrackable), so tracked challenges get their own section in Blizzard's
-- objective tracker, laid out like its achievement section. Entries are whole
-- challenges or one zone's share of one (Model.ZoneKey).
---@class LegacyTracker
local Tracker = {}
ns.Tracker = Tracker

-- Matches Blizzard's achievement section: five steps, then "...".
local MAX_STEPS = 5

---@return LegacyTrackingKey[]
local function Tracked()
	return ns.SavedTable("tracked")
end

---@param list LegacyTrackingKey[]
---@param value LegacyTrackingKey
---@return number?
local function IndexOf(list, value)
	for index, item in ipairs(list) do
		if item == value then
			return index
		end
	end
end

---@param key LegacyTrackingKey
---@return boolean
function Tracker.IsTracked(key)
	return IndexOf(Tracked(), key) ~= nil
end

---@type LegacyTrackerModule?
local module

function Tracker.Refresh()
	if module then
		module:MarkDirty()
	end
end

---@param key LegacyTrackingKey
function Tracker.Toggle(key)
	local tracked = Tracked()
	local index = IndexOf(tracked, key)
	if index then
		table.remove(tracked, index)
	else
		tracked[#tracked + 1] = key
	end
	Tracker.Refresh()
end

-- Everything tracked under a challenge: the whole challenge and every zone share of it.
---@param challenge number
local function StopTracking(challenge)
	local tracked, visible = Tracked(), ns.Live.Visible()
	for index = #tracked, 1, -1 do
		if ns.Model.TrackedChallenge(ns.Data, tracked[index], visible) == challenge then
			table.remove(tracked, index)
		end
	end
	Tracker.Refresh()
end

---@class LegacyChallengeTracker : LegacyTrackerModule
local ModuleMixin = { headerText = L["Legacy"] }

---@param block LegacyTrackerBlock
---@param mouseButton string
function ModuleMixin:OnBlockHeaderClick(block, mouseButton)
	if mouseButton ~= "RightButton" then
		ns.Live.ShowInLegacyPanel(block.id)
		return
	end
	MenuUtil.CreateContextMenu(self:GetContextMenuParent(), function(_, root)
		root:SetTag("MENU_LEGACY_HERE_TRACKER", block)
		root:CreateTitle(ns.Live.Name(block.id))
		ns.Live.LockPanelEntry(root:CreateButton(L["Open in the Legacy panel"], function()
			ns.Live.ShowInLegacyPanel(block.id)
		end))
		root:CreateButton(L["Stop tracking"], function()
			StopTracking(block.id)
		end)
	end)
end

-- The challenge as the block header, then quest-style lines: "12/20 Reach level 20",
-- "0/12 Explore Felwood". A challenge the game no longer lists (earned, or not this
-- character's variant) is skipped but stays tracked.
function ModuleMixin:LayoutContents()
	local blocks = ns.Model.TrackedBlocks(ns.Data, Tracked(), ns.Live.Visible(), ns.Live.Criteria, ns.Live.Name)
	for _, tracked in ipairs(blocks) do
		local block = self:GetBlock(tracked.challenge)
		block:SetHeader(ns.Live.Name(tracked.challenge))
		for index, line in ipairs(tracked.lines) do
			if index > MAX_STEPS then
				block:AddObjective("Extra", "...", nil, nil, OBJECTIVE_DASH_STYLE_HIDE)
				break
			end
			-- The client can report a step or a challenge name as nil while it is still loading: show what is
			-- known, and skip a line with nothing to show.
			local text = line.detail and line.text and (line.detail .. " " .. line.text) or line.text or line.detail
			if text then
				block:AddObjective(index, text)
			end
		end
		if not self:LayoutBlock(block) then
			return
		end
	end
end

---@type LegacyTrackerModule[]
local modules = {}

---@param trackerModule LegacyTrackerModule
local function Attach(trackerModule)
	if ForeverTrackerHost then
		ForeverTrackerHost.Attach(trackerModule)
		return
	end
	-- The shared private host is optional; standalone companions stay inert until it loads.
end

local function AttachAll()
	for _, trackerModule in ipairs(modules) do
		Attach(trackerModule)
	end
end

---@param trackerModule LegacyTrackerModule
---@return boolean
local function IsAttached(trackerModule)
	if ForeverTrackerHost then
		return ForeverTrackerHost.IsAttached(trackerModule)
	end
	return false
end

---@return boolean
function Tracker.IsAttached()
	return module ~= nil and IsAttached(module)
end

---@return number
function Tracker.Count()
	return #Tracked()
end

local function Available()
	return ObjectiveTrackerManager and ObjectiveTrackerFrame
end

-- A section of our own in the objective tracker, laid out by `mixin`. Returns nil
-- when the tracker isn't available (Register reports that once).
---@param name string
---@param mixin LegacyTrackerModule
---@param uiOrder number
---@return LegacyTrackerModule?
function Tracker.AddModule(name, mixin, uiOrder)
	if not Available() then
		return nil
	end
	---@class LegacyTrackerModule : ObjectiveTrackerModuleTemplate
	---@field Header LegacyTrackerHeader
	---@field headerText? string
	---@field uiOrder number
	---@field GetBlock fun(self: LegacyTrackerModule, id: number): LegacyTrackerBlock
	local trackerModule = CreateFrame("Frame", name, UIParent, "ObjectiveTrackerModuleTemplate")
	Mixin(trackerModule, mixin)
	trackerModule:SetHeader(mixin.headerText or "")
	trackerModule.uiOrder = uiOrder
	if #modules == 0 then
		EventUtil.ContinueAfterAllEvents(function()
			C_Timer.After(0, AttachAll)
		end, "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED")
	end
	modules[#modules + 1] = trackerModule
	Attach(trackerModule)
	return trackerModule
end

-- Runs after both events and the deferred attach pass: checking any sooner can warn about a
-- section that is about to attach.
local function WarnIfUnattached()
	for _, trackerModule in ipairs(modules) do
		if not IsAttached(trackerModule) then
			ns.Print(L["couldn't add a section to the objective tracker; please report /lf audit."])
			return
		end
	end
end

local function Register()
	if not Available() then
		ns.Print(L["the objective tracker isn't available, so tracked challenges can't be shown."])
		return
	end
	module = Tracker.AddModule("LegacyForeverObjectiveTracker", ModuleMixin, 0)
	EventUtil.ContinueAfterAllEvents(function()
		C_Timer.After(5, WarnIfUnattached)
	end, "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED")
end

Register()
ns.Live.OnChange(Tracker.Refresh)
