---@type string, LegacyForeverNamespace
local _, ns = ...
local L = ns.L

local PIN_TEMPLATE = "LegacyForeverPinTemplate"
-- Unseen ground reads darker, the fog-of-war convention (a warm tint vanished on the
-- parchment); darker still under the mouse.
local AREA_ALPHA, AREA_HOVER_ALPHA = 0.25, 0.4
local POINTS_ICON = ns.POINTS_ICON

local KIND_LABEL = {
	explore = L["Undiscovered area"],
	instance = L["Dungeon or raid"],
	kill = L["Defeat"],
	quest = L["Quest"],
	reputation = REPUTATION,
}

---@param challenge number
---@return string?
local function PointsText(challenge)
	local points = ns.Live.Points(challenge)
	if points then
		return L["%s %d Legacy |4point:points;"]:format(ns.Art.Markup(POINTS_ICON, 14), points)
	end
end

---@param tooltip GameTooltip
---@param challenge number
local function AddPointsLine(tooltip, challenge)
	local text = PointsText(challenge)
	if text then
		GameTooltip_AddNormalLine(tooltip, text)
	end
end

-- Points belong to the whole challenge, so a feeding achievement (an "Explore <zone>")
-- names what it counts toward rather than implying each step is worth them.
---@param tooltip GameTooltip
---@param group LegacyGroup
local function AddRewardLine(tooltip, group)
	if group.achievement == group.challenge then
		AddPointsLine(tooltip, group.challenge)
		return
	end
	local points = PointsText(group.challenge)
	local name = ns.Live.Name(group.challenge)
	-- Explorer pays once for exploring all of Azeroth (Explore Azeroth), so one area is a
	-- small share of a single point; say so rather than let it read as a point per area.
	local line
	if not points then
		line = L["Part of %s"]:format(name)
	elseif ns.MapContents.IsExploration(group) then
		line = L["Part of %s: %s for exploring every zone"]:format(name, points)
	else
		line = L["Part of %s: %s for the whole challenge"]:format(name, points)
	end
	GameTooltip_AddNormalLine(tooltip, line)
end

-- "9 of 12 areas left" for an exploration achievement, from live progress.
---@param group LegacyGroup
---@return string
local function AreasLeftText(group)
	local done, total = ns.Model.Tally(ns.Live.Criteria(group.achievement) or {})
	return L["%s: %d of %d areas left"]:format(ns.Live.Name(group.achievement), total - done, total)
end

---@param tooltip GameTooltip
---@param group LegacyGroup
local function AddGroupTooltip(tooltip, group)
	if ns.MapContents.IsExploration(group) then
		GameTooltip_SetTitle(tooltip, ns.Live.Name(group.achievement))
		GameTooltip_AddNormalLine(tooltip, AreasLeftText(group))
		for _, objective in ipairs(group.objectives) do
			GameTooltip_AddColoredLine(tooltip, objective.text, WHITE_FONT_COLOR)
		end
	else
		GameTooltip_SetTitle(tooltip, ns.Live.Name(group.challenge))
		for _, objective in ipairs(group.objectives) do
			local label = KIND_LABEL[objective.entry.kind]
			GameTooltip_AddColoredLine(tooltip, ("%s: %s"):format(label, objective.text), WHITE_FONT_COLOR)
		end
	end
	AddRewardLine(tooltip, group)
end

---@param tooltip GameTooltip
---@param group LegacyGroup
---@param objective LegacyObjective
local function AddPinTooltip(tooltip, group, objective)
	if objective.entry.kind == "explore" then
		GameTooltip_SetTitle(tooltip, objective.text)
		GameTooltip_AddNormalLine(tooltip, KIND_LABEL.explore)
		GameTooltip_AddHighlightLine(tooltip, AreasLeftText(group))
	else
		GameTooltip_SetTitle(tooltip, ns.Live.Name(group.challenge))
		local label = KIND_LABEL[objective.entry.kind]
		GameTooltip_AddColoredLine(tooltip, ("%s: %s"):format(label, objective.text), WHITE_FONT_COLOR)
	end
	AddRewardLine(tooltip, group)
end

---@param tooltip GameTooltip
---@param zone LegacyContinentZone
local function AddZoneTooltip(tooltip, zone)
	GameTooltip_SetTitle(tooltip, zone.name)
	GameTooltip_AddHighlightLine(
		tooltip,
		(zone.count == 1 and L["%d Legacy objective left"] or L["%d Legacy objectives left"]):format(zone.count)
	)
	for _, group in ipairs(zone.groups) do
		GameTooltip_AddNormalLine(tooltip, L["%s: %d left"]:format(ns.Live.Name(group.challenge), #group.objectives))
	end
	ns.Completion.AddSummary(tooltip, zone.uiMapID)
	GameTooltip_AddInstructionLine(tooltip, L["Click the zone to see where."])
end

---@param key 'showAreas'|'showEntrances'|'whatsNew'|'suggestFamily'
local function ToggleSetting(key)
	ns.Saved.Set(key, not ns.Saved.Get(key))
end

--[[ Button: sits in the map's top-right button column and lists this map's objectives ]]

-- Each entry is a checkbox for our own tracker (Forever refuses Blizzard's): a zone's
-- entry tracks only this zone's share of its challenge (Model.ZoneKey), "No fixed location"
-- the whole challenge. The tracker's challenge names open the Legacy panel.
local TRACK_HINT = L["Click to track, with live progress."]
-- The same line as the switch's row on the Settings page.
local ENTRANCES_TOOLTIP = L["Turn this off if another addon already marks them. The Legacy map menu still lists them."]

---@param name string
---@param count number
---@return string
local function ChallengeText(name, count)
	return ("%s |cffffffff(%d)|r"):format(name, count)
end

-- Each entry wears the icon it has on the map: the Legacy pin, or for exploration the
-- compass of the undiscovered-area shading (as under "What counts").
---@param root SharedMenuDescriptionProxy
---@param group LegacyGroup
local function AddGroup(root, group)
	local icon = ns.Completion.Icon(ns.MapContents.IsExploration(group) and "areas" or "legacy", 14)
	local name = ("%s %s"):format(icon, ns.Live.Name(group.achievement))
	local button = root:CreateCheckbox(
		ChallengeText(name, #group.objectives),
		ns.Tracker.IsTracked,
		ns.Tracker.Toggle,
		ns.Model.ZoneKey(group)
	)
	button:SetTooltip(function(tooltip)
		AddGroupTooltip(tooltip, group)
		GameTooltip_AddInstructionLine(tooltip, TRACK_HINT)
	end)
end

---@param menu SharedMenuDescriptionProxy
---@param item LegacyUnlocated
local function AddUnlocatedItem(menu, item)
	local text = ChallengeText(ns.Live.Name(item.challenge), item.open)
	local button = menu:CreateCheckbox(text, ns.Tracker.IsTracked, ns.Tracker.Toggle, item.challenge)
	button:SetTooltip(function(tooltip)
		GameTooltip_SetTitle(tooltip, ns.Live.Name(item.challenge))
		GameTooltip_AddNormalLine(tooltip, L["Levels, skills, ranks and anything without a fixed place."])
		AddPointsLine(tooltip, item.challenge)
		GameTooltip_AddInstructionLine(tooltip, TRACK_HINT)
	end)
end

-- Ordered groups keyed by name, so submenus keep the order items first appear in.
---@param list LegacyMenuGroup[]
---@param byName table<string, LegacyMenuGroup>
---@param name string
---@return LegacyMenuGroup
local function Group(list, byName, name)
	local group = byName[name]
	if not group then
		group = { name = name, items = {}, subs = {}, subsByName = {} }
		byName[name] = group
		list[#list + 1] = group
	end
	return group
end

-- Grouped like the Legacy panel: the game's category, under its parent when it has
-- one (Classes > Priest, PvP > Ranks), so no submenu runs off the screen.
---@param root SharedMenuDescriptionProxy
local function AddUnlocated(root)
	local unlocated = ns.Model.Unlocated(ns.Data, ns.Live.Visible(), ns.Live.Criteria)
	if #unlocated == 0 then
		return
	end
	local tops, topsByName = {}, {}
	for _, item in ipairs(unlocated) do
		local name, parentID = GetCategoryInfo(GetAchievementCategory(item.challenge))
		local parentName = parentID and parentID > 0 and GetCategoryInfo(parentID)
		if parentName then
			local top = Group(tops, topsByName, parentName)
			local sub = Group(top.subs, top.subsByName, name)
			sub.items[#sub.items + 1] = item
		else
			local top = Group(tops, topsByName, name or OTHER)
			top.items[#top.items + 1] = item
		end
	end
	local submenu = root:CreateButton(ChallengeText(L["No fixed location"], #unlocated))
	for _, top in ipairs(tops) do
		local topMenu = submenu:CreateButton(top.name)
		for _, sub in ipairs(top.subs) do
			local subMenu = topMenu:CreateButton(sub.name)
			for _, item in ipairs(sub.items) do
				AddUnlocatedItem(subMenu, item)
			end
		end
		for _, item in ipairs(top.items) do
			AddUnlocatedItem(topMenu, item)
		end
	end
end

---@param root SharedMenuDescriptionProxy
---@param uiMapID number?
local function BuildMenu(root, uiMapID)
	root:SetTag("MENU_LEGACY_HERE")
	local mapInfo = uiMapID and C_Map.GetMapInfo(uiMapID)
	root:CreateTitle(mapInfo and mapInfo.name or ns.TITLE)
	local groups = ns.MapContents.Objectives(uiMapID)
	if #groups == 0 then
		root:CreateTitle("|cff808080" .. L["Nothing left to do here"] .. "|r")
	end
	for _, group in ipairs(groups) do
		AddGroup(root, group)
	end
	root:CreateDivider()
	root:CreateCheckbox(L["Show undiscovered areas"], ns.Saved.Get, ToggleSetting, "showAreas")
	local entrances =
		root:CreateCheckbox(L["Show dungeon and raid entrances"], ns.Saved.Get, ToggleSetting, "showEntrances")
	entrances:SetTooltip(function(tooltip)
		GameTooltip_SetTitle(tooltip, L["Show dungeon and raid entrances"])
		GameTooltip_AddNormalLine(tooltip, ENTRANCES_TOOLTIP)
	end)
	AddUnlocated(root)
	root:CreateDivider()
	ns.Completion.AddMenu(root)
	root:CreateDivider()
	ns.Live.LockPanelEntry(root:CreateButton(L["Open the Legacy panel"], ToggleLegacySystemUI))
	root:CreateDivider()
	root:CreateCheckbox(L["What's new after an update"], ns.Saved.Get, ToggleSetting, "whatsNew")
	local family =
		root:CreateCheckbox(L["Suggest my other Forever addons"], ns.Saved.Get, ToggleSetting, "suggestFamily")
	family:SetTooltip(function(tooltip)
		GameTooltip_SetTitle(tooltip, L["Suggest my other Forever addons"])
		GameTooltip_AddNormalLine(
			tooltip,
			L["Show a quiet line where one of my other Forever addons would help. Only for addons you don't have."]
		)
	end)
end

---@class LegacyForeverMapButtonMixin : DropdownButton
---@field GetParent fun(self: LegacyForeverMapButtonMixin): WorldMapFrame
---@field Count FontString
---@field Icon Texture
---@field count number
LegacyForeverMapButtonMixin = {}

function LegacyForeverMapButtonMixin:OnLoad()
	self:SetupMenu(function(_, root)
		BuildMenu(root, self:GetParent():GetMapID())
	end)
end

-- Below whichever other top-right buttons are actually showing there: rulesets disable Blizzard's
-- (C_GameRules), layout addons move them, and this client keeps them unnamed, so the map's own list
-- of overlay frames is checked per refresh.
local BUTTON_SPACING = -32

---@param map WorldMapFrame
---@param own Frame
---@return number
local function TopRightOffset(map, own)
	local offsetY = -2
	-- The map's own list holds Blizzard's tracking options and pin buttons as well as ours.
	---@diagnostic disable-next-line: undefined-field
	for _, button in ipairs(map.overlayFrames or {}) do
		if button ~= own and button:IsShown() and button:GetPoint(1) == "TOPRIGHT" then
			offsetY = offsetY + BUTTON_SPACING
		end
	end
	-- Krowi_WorldMapButtons (Questie and others) lays its buttons along the top row from this
	-- same corner, outside the map's list.
	local index = 1
	local other = _G["Krowi_WorldMapButtons" .. index]
	while other do
		if other:IsShown() then
			return offsetY + BUTTON_SPACING
		end
		index = index + 1
		other = _G["Krowi_WorldMapButtons" .. index]
	end
	return offsetY
end

function LegacyForeverMapButtonMixin:Refresh()
	---@type WorldMapFrame
	local map = self:GetParent()
	self:ClearAllPoints()
	self:SetPoint("TOPRIGHT", map:GetCanvasContainer(), "TOPRIGHT", -4, TopRightOffset(map, self))
	local _, count = ns.MapContents.Objectives(map:GetMapID())
	self.Count:SetFontObject(
		count >= 100 and GameFontNormalTiny or count >= 10 and GameFontNormalSmall or GameFontNormal
	)
	self.Count:SetText(count > 0 and tostring(count) or "")
	self.Icon:SetDesaturated(count == 0)
	self.count = count
end

function LegacyForeverMapButtonMixin:OnShow()
	self:Refresh()
end

function LegacyForeverMapButtonMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip_SetTitle(GameTooltip, ns.TITLE)
	if self.count and self.count > 0 then
		GameTooltip_AddNormalLine(GameTooltip, L["%d unfinished Legacy objectives on this map."]:format(self.count))
	else
		GameTooltip_AddNormalLine(GameTooltip, L["No unfinished Legacy objectives with a place on this map."])
	end
	GameTooltip:Show()
end

function LegacyForeverMapButtonMixin:OnLeave()
	GameTooltip:Hide()
end

-- Closing the map hides the button without an OnLeave.
function LegacyForeverMapButtonMixin:OnHide()
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

--[[ Pins: one per unfinished objective the data can place on this map, on frames of our own (UI/MapCanvas.lua) ]]

---@class LegacyObjectivePin : LegacyCanvasPin
---@field Icon Texture
---@field Portal Texture
---@field Highlight Texture
---@field group? LegacyGroup
---@field objective? LegacyObjective
---@field zone? LegacyContinentZone
local ObjectivePin = CreateFromMixins(ns.MapCanvas.PinMixin)

function ObjectivePin:OnLoad()
	self.takesMouse = true
	self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
	self:SetScalingLimits(1, 1.0, 1.2)
end

---@param group LegacyGroup?
---@param objective LegacyObjective?
---@param zone LegacyContinentZone?
function ObjectivePin:OnAcquired(group, objective, zone)
	self.group = group
	self.objective = objective
	self.zone = zone
	-- A zone badge lets the click open the zone below it.
	self.clicks = self:Destination() ~= nil
	self:Layout(objective and objective.entry)
	if zone then
		self:SetPosition(zone.x, zone.y)
	elseif objective then
		self:SetPosition(objective.entry.x, objective.entry.y)
	end
end

-- At an entrance: the retail portal the map already uses there, with a small shield on its corner, so the
-- entrance still reads as one and the Legacy step as a badge on it. Anywhere else: the shield alone.
---@param entry LegacyEntry?
function ObjectivePin:Layout(entry)
	local instance = entry and entry.instance
	self.Icon:ClearAllPoints()
	self.Highlight:ClearAllPoints()
	self.Portal:SetShown(instance ~= nil)
	if entry and instance then
		local atlas = entry.raid and "Raid" or "Dungeon"
		self:SetSize(32, 32)
		self.Portal:SetAtlas(atlas) -- art-ok: both portals are square atlases, over the 32x32 pin
		ns.Art.Fit(self.Icon, POINTS_ICON, 12, 17)
		self.Icon:SetPoint("BOTTOMRIGHT", 2, -2)
		self.Highlight:SetAtlas(atlas) -- art-ok: the portal again, over the square Portal texture
		self.Highlight:SetAllPoints(self.Portal)
	else
		self:SetSize(20, 20)
		ns.Art.Fit(self.Icon, POINTS_ICON, 14, 20)
		self.Icon:SetPoint("CENTER")
		self.Highlight:SetAtlas(POINTS_ICON) -- art-ok: the shield again, over the Icon that Art.Fit sized
		self.Highlight:SetAllPoints(self.Icon)
	end
end

-- Where a click takes the player: only an objective with coordinates in the data, on the zone map they are for.
---@return number? uiMapID
---@return number? x
---@return number? y
function ObjectivePin:Destination()
	local entry = self.objective and self.objective.entry
	if self.group and entry and entry.x and entry.y then
		return self.group.uiMapID, entry.x, entry.y
	end
end

function ObjectivePin:OnMouseEnter()
	self.Highlight:Show()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if self.zone then
		AddZoneTooltip(GameTooltip, self.zone)
	elseif self.group and self.objective then
		AddPinTooltip(GameTooltip, self.group, self.objective)
		if self:Destination() then
			GameTooltip_AddInstructionLine(GameTooltip, ns.NavigateHint())
			local companion = ns.CompanionHint()
			if companion then
				GameTooltip_AddDisabledLine(GameTooltip, companion)
			end
		end
	end
	GameTooltip:Show()
end

---@param button string
function ObjectivePin:OnMouseClickAction(button)
	local uiMapID, x, y = self:Destination()
	if button == "LeftButton" and uiMapID and x and y and self.objective then
		ns.Navigate(uiMapID, x, y, self.objective.text)
	end
end

function ObjectivePin:OnMouseLeave()
	self.Highlight:Hide()
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

-- One frame per zone map holding every undiscovered area, drawn from the same map tiles Blizzard reveals on
-- discovery (see MapExplorationPinMixin:RefreshOverlays). It never takes the mouse, which would swallow the map's own
-- clicks (right-click to zoom out, drag to pan): while the cursor is on bare map, the area under it is polled
-- (MapContents.AreaAt).
---@class LegacyAreaPin : LegacyCanvasPin
---@field textures LegacyTexturePool
---@field shade? LegacyShade
---@field hovered? LegacyShadedArea
---@field cursorX? number
---@field cursorY? number
---@field drawn table<string, Texture[]>
local AreaPin = CreateFromMixins(ns.MapCanvas.PinMixin)

function AreaPin:OnLoad()
	self:SetIgnoreGlobalPinScale(true)
	self:UseFrameLevelType("PIN_FRAME_LEVEL_MAP_EXPLORATION")
	self.textures = CreateTexturePool(self, "OVERLAY")
	self.drawn = {}
	-- The area scan runs only when the cursor moves over the canvas; the position is in canvas pixels, so a zoom or
	-- pan under a still cursor counts as a move.
	self:SetScript("OnUpdate", function()
		if self:GetMap():IsCanvasMouseFocus() then
			local x, y = self:CursorPosition()
			if x ~= self.cursorX or y ~= self.cursorY then
				self.cursorX, self.cursorY = x, y
				self:HoverAt(x, y)
			end
		else
			self.cursorX, self.cursorY = nil, nil
			if self.hovered then
				self:Highlight(nil)
			end
		end
	end)
	-- The polling stops while the map is closed, so the hovered area's shade and tooltip go now.
	self:SetScript("OnHide", function()
		self:Highlight(nil)
	end)
end

function AreaPin:OnReleased()
	self:Highlight(nil)
	self.textures:ReleaseAll()
	self.shade, self.drawn = nil, {}
	self.cursorX, self.cursorY = nil, nil
end

local masks = setmetatable({}, { __mode = "k" })

---@param tile LegacyShadeTile
---@return Texture
function AreaPin:DrawTile(tile)
	local texture = self.textures:Acquire()
	if masks[texture] then
		texture:RemoveMaskTexture(masks[texture])
		masks[texture] = nil
	end
	local mask = self:GetMap():GetMaskTexture()
	if mask and self:GetMap():GetUseMaskTexture() then
		texture:AddMaskTexture(mask)
		masks[texture] = mask
	end
	-- art-ok: a map tile at the size and crop the generated data gives it, and the pool only ever draws files
	texture:SetTexture(tile.file, nil, nil, "TRILINEAR")
	texture:SetSize(tile.width, tile.height)
	texture:SetTexCoord(0, tile.u, 0, tile.v)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", tile.x, -tile.y)
	texture:SetVertexColor(0, 0, 0, AREA_ALPHA)
	texture:Show()
	return texture
end

---@param shade LegacyShade
function AreaPin:OnAcquired(shade)
	self:SetSize(self:GetMap():GetCanvas():GetSize())
	self:SetPosition(0.5, 0.5)
	self.shade = shade
	for _, shaded in ipairs(shade.areas) do
		local textures = {}
		for _, tile in ipairs(shaded.tiles) do
			textures[#textures + 1] = self:DrawTile(tile)
		end
		self.drawn[shaded.area.key] = textures
	end
end

-- The cursor in canvas pixels, the space overlay offsets are in.
---@return number x
---@return number y
function AreaPin:CursorPosition()
	local scale = self:GetEffectiveScale()
	local x, y = GetCursorPosition()
	return x / scale - self:GetLeft(), self:GetTop() - y / scale
end

---@param x number
---@param y number
function AreaPin:HoverAt(x, y)
	local shaded = self.shade and ns.MapContents.AreaAt(self.shade, x, y) or nil
	if shaded ~= self.hovered then
		self:Highlight(shaded)
	end
end

---@param shaded LegacyShadedArea?
function AreaPin:Highlight(shaded)
	if self.hovered then
		for _, texture in ipairs(self.drawn[self.hovered.area.key]) do
			texture:SetVertexColor(0, 0, 0, AREA_ALPHA)
		end
		-- Only our own tooltip: a pin the cursor just moved onto has already shown its own.
		if GameTooltip:GetOwner() == self then
			GameTooltip:Hide()
		end
	end
	self.hovered = shaded
	if not shaded then
		return
	end
	for _, texture in ipairs(self.drawn[shaded.area.key]) do
		texture:SetVertexColor(0, 0, 0, AREA_HOVER_ALPHA)
	end
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
	local objective = shaded.objective
	if objective then
		AddPinTooltip(GameTooltip, objective.group, objective.objective)
	else
		GameTooltip_SetTitle(GameTooltip, shaded.area.name)
		GameTooltip_AddNormalLine(GameTooltip, KIND_LABEL.explore)
	end
	GameTooltip:Show()
end

--[[ Wiring ]]

local function Attach()
	local map = WorldMapFrame
	local MapCanvas = ns.MapCanvas
	local pins = MapCanvas.Pool(map, ObjectivePin, { template = PIN_TEMPLATE, marker = "legacy" })
	local areas = MapCanvas.Pool(map, AreaPin)
	local refreshPending = false

	-- Our pins are our own frames, but a pass-through change is refused in combat, so a redraw in combat hides them
	-- and waits for its end.
	local function Draw()
		if InCombatLockdown() then
			refreshPending = true
			MapCanvas.SetShown(map, false)
			return
		end
		refreshPending = false
		pins:ReleaseAll()
		areas:ReleaseAll()
		local drawn = ns.MapContents.Drawn(map:GetMapID())
		for _, zone in ipairs(drawn.badges) do
			pins:Acquire(nil, nil, zone)
		end
		for _, pin in ipairs(drawn.pins) do
			pins:Acquire(pin.group, pin.objective)
		end
		if drawn.shade then
			areas:Acquire(drawn.shade)
		end
		MapCanvas.SetShown(map, true)
	end

	-- A button of our own in the map's top-right column; Refresh anchors it (see TopRightOffset).
	local button = MapCanvas.FrameUnder("DropdownButton", map, "LegacyForeverMapButtonTemplate")
	---@cast button LegacyForeverMapButtonMixin
	button:SetFrameStrata("HIGH")

	MapCanvas.Watch(map, function(_, what)
		if what == "show" or what == "map" or what == "size" then
			Draw()
			button:Refresh()
		end
	end)
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function()
		if refreshPending and map:IsShown() then
			Draw()
		end
	end)

	function ns.OpenMapMenu()
		if not button:IsMenuOpen() then
			button:OpenMenu()
		end
	end

	function ns.RefreshMap()
		if map:IsShown() then
			Draw()
			button:Refresh()
		end
	end
	-- Progress moves the pins and the "On the world map" switch the badges: zone completion's notice covers both.
	ns.ZoneCompletion.OnChange(ns.RefreshMap)
	ns.Saved.OnChange(function(key)
		if key == "showAreas" or key == "showEntrances" then
			ns.RefreshMap()
		end
	end)
	button:Refresh()
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Attach)
