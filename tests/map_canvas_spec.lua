-- Run from the repository root: luajit tests/map_canvas_spec.lua
-- UI/MapCanvas.lua and UI/Map.lua on a world map that fails on any write (tests/strict_map.lua): Legacy draws its pins,
-- undiscovered areas and map button on frames of its own, adds no data provider, acquires no pin and adds no overlay
-- frame, and keeps every pin's behaviour: placing, scaling, tooltips, clicks, and waiting out combat.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local Kit = dofile("tests/strict_map.lua")
Kit.Install(_G)

local attach
EventUtil = {
	ContinueOnAddOnLoaded = function(addon, callback)
		assert(addon == "Blizzard_WorldMap")
		attach = callback
	end,
}
REPUTATION = "Reputation"
WHITE_FONT_COLOR = {}
Enum = {}

-- The tooltip: who owns it and what it says.
local tooltip = { lines = {} }
GameTooltip = {
	SetOwner = function(_, owner)
		tooltip.owner, tooltip.lines = owner, {}
	end,
	GetOwner = function()
		return tooltip.owner
	end,
	Show = function()
		tooltip.shown = true
	end,
	Hide = function()
		tooltip.shown, tooltip.owner = false, nil
	end,
}
local function Line(_, text)
	tooltip.lines[#tooltip.lines + 1] = text
end
GameTooltip_SetTitle, GameTooltip_AddNormalLine, GameTooltip_AddHighlightLine = Line, Line, Line
GameTooltip_AddInstructionLine, GameTooltip_AddDisabledLine = Line, Line
GameTooltip_AddColoredLine = Line

-- What the map shows: on map 1429 an objective with a place and a shaded area; on continent 1415 a zone badge.
local group = { challenge = 10, achievement = 10, uiMapID = 1429, objectives = {} }
local objective = { text = "Slay Hogger", entry = { kind = "kill", x = 0.25, y = 0.5 } }
group.objectives[1] = objective
local badge = { name = "Elwynn Forest", uiMapID = 1429, x = 0.6, y = 0.7, count = 1, groups = { group } }
local area = { name = "Northshire", key = "0:0:1:1" }
local shade = {
	areas = { { area = area, tiles = { { file = 1, x = 0, y = 0, width = 256, height = 256, u = 1, v = 1 } } } },
}
local drawn = {
	[1429] = { badges = {}, pins = { { group = group, objective = objective } }, shade = shade },
	[1415] = { badges = { badge }, pins = {} },
}
local navigated, hovering, switched = {}, nil, nil

local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	POINTS_ICON = "UI-Legacy-Points-icon-c60",
	Art = { Fit = function() end },
	SafeCall = function(_, fn, ...)
		return true, fn(...)
	end,
	Live = {
		Name = function()
			return "Defender of Elwynn"
		end,
		Points = function()
			return nil
		end,
	},
	MapContents = {
		Drawn = function(uiMapID)
			return drawn[uiMapID] or { badges = {}, pins = {} }
		end,
		Objectives = function()
			return {}, 1
		end,
		IsExploration = function()
			return false
		end,
		AreaAt = function()
			return hovering
		end,
	},
	Completion = { AddSummary = function() end },
	NavigateHint = function()
		return "Click to travel there."
	end,
	CompanionHint = function()
		return nil
	end,
	Navigate = function(uiMapID, x, y, title)
		navigated[#navigated + 1] = { uiMapID, x, y, title }
	end,
	ZoneCompletion = { OnChange = function() end },
	Saved = {
		Get = function()
			return true
		end,
		OnChange = function(callback)
			switched = callback
		end,
	},
}

assert(loadfile("UI/MapCanvas.lua"))("LegacyForever", ns)
assert(loadfile("UI/Map.lua"))("LegacyForever", ns)
check(attach, "UI/Map.lua waits for the world map to load")
attach()

local function Pins()
	local shown = {}
	for _, frame in ipairs(Kit.Made("LegacyForeverPinTemplate")) do
		if frame.shown then
			shown[#shown + 1] = frame
		end
	end
	return shown
end
local function Areas()
	local shown = {}
	for _, frame in ipairs(Kit.frames) do
		if frame.shade and frame.shown then
			shown[#shown + 1] = frame
		end
	end
	return shown
end
local button = Kit.Made("LegacyForeverMapButtonTemplate")[1]
check(button and button:GetParent() == Kit.map, "the map button is a frame of ours on the map, not an overlay frame")

-- Opening the map draws on the next frame of the view, under a host and layer of ours on the canvas.
Kit.Tick()
local pins = Pins()
check(#pins == 1 and #Areas() == 1, "opening a zone map draws its objective and its undiscovered areas")
local pin = pins[1]
local host = pin:GetParent():GetParent()
check(host:GetParent() == Kit.canvas, "the pins sit on a layer of ours over the map's canvas")
check(pin.level == 30 and Areas()[1].level == 20, "pins take the map's frame levels for their kind")
check(pin.point[2] == Kit.canvas and pin.point[4] == 250 and pin.point[5] == -350, "the pin sits at its map fraction")
check(math.abs(pin.scale - 1) < 1e-9, "zoomed out, the pin is at its start scale")
check(
	pin.mouse and pin.mouseClicks and #pin.passThrough == 1 and pin.passThrough[1] == "RightButton",
	"right-click zooms out"
)
local areaFrame = Areas()[1]
check(areaFrame.mouse == false, "the shading never takes the mouse, so the map keeps its clicks and drags")
check(areaFrame.width == 1000 and areaFrame.height == 700, "the shading covers the canvas")

-- Zooming in grows the pin to its end scale, divided by the canvas's own scale so it stays the same on screen.
Kit.zoom, Kit.scale = 1, 2
Kit.Tick()
check(math.abs(pin.scale - 0.6) < 1e-9, "zoomed in, the pin keeps its end size on screen")
check(pin.point[4] == 250 / 0.6, "a rescaled pin stays on its spot")
Kit.zoom, Kit.scale = 0, 1
Kit.Tick()

-- Pointing at the pin shows its tooltip; a left press and release on it travels there.
pin:Run("OnEnter")
check(tooltip.owner == pin and pin.Highlight.shown, "pointing at a pin highlights it and shows its tooltip")
check(tooltip.lines[#tooltip.lines] == "Click to travel there.", "the tooltip says what a click does")
Kit.mouseOver = pin
Kit.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Kit.Fire("GLOBAL_MOUSE_UP", "LeftButton")
check(#navigated == 1 and navigated[1][1] == 1429 and navigated[1][4] == "Slay Hogger", "a click travels there")
Kit.Fire("GLOBAL_MOUSE_DOWN", "RightButton")
Kit.Fire("GLOBAL_MOUSE_UP", "RightButton")
check(#navigated == 1, "a right-click is the map's, to zoom out")
Kit.mouseOver = nil
Kit.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Kit.mouseOver = pin
Kit.Fire("GLOBAL_MOUSE_UP", "LeftButton")
check(#navigated == 1, "a press that began off the pin is no click on it")
Kit.mouseOver = nil
pin:Run("OnLeave")
check(tooltip.owner == nil and not pin.Highlight.shown, "leaving the pin hides its tooltip")

-- Hovering bare map over an undiscovered area darkens it and names it.
Kit.mouseFocus, hovering = true, shade.areas[1]
Kit.Tick()
check(tooltip.owner == areaFrame and tooltip.lines[1] == "Northshire", "an undiscovered area names itself")
Kit.mouseFocus = false
Kit.Tick()
check(tooltip.owner == nil, "the cursor leaving the canvas hides the area's tooltip")

-- Nothing of ours is made inside an open window, the canvas holds one frame of ours, and no pin has a click script
-- or a field the map reads off its mouse focus.
local onCanvas = 0
for _, frame in ipairs(Kit.frames) do
	if frame ~= Kit.canvas and frame ~= Kit.container then
		check(frame.madeUnder == nil, "every frame of ours is made with no parent")
	end
	onCanvas = onCanvas + (frame.parent == Kit.canvas and 1 or 0)
	if frame.template == "LegacyForeverPinTemplate" or frame.shade then
		for _, script in ipairs({ "OnClick", "OnMouseDown", "OnMouseUp", "OnDoubleClick" }) do
			check(frame.scripts[script] == nil, "a pin has no " .. script .. " script")
		end
		check(frame.owningMap == nil and frame.pinTemplate == nil, "a pin carries no field the map reads")
	end
end
check(onCanvas == 1, "the canvas holds exactly one frame of ours, the view's host")

-- The map switches redraw at once; any other switch leaves the map alone.
local before = #Kit.frames
drawn[1429].pins = {}
switched("whatsNew", false)
check(#Pins() == 1, "a switch the map does not draw from leaves it alone")
switched("showEntrances", false)
check(#Pins() == 0 and #Areas() == 1, "turning entrances off redraws the pins")
drawn[1429].pins = { { group = group, objective = objective } }
switched("showAreas", true)
check(#Pins() == 1 and #Kit.frames == before, "a redraw reuses the pins it released")

-- Other addons find the shown pins through ForeverMapMarkers.
local markers = ForeverMapMarkers.LegacyForever(Kit.map)
check(#markers == 1 and markers[1].x == 0.25 and markers[1].kind == "legacy", "the pins are listed for other addons")

-- On a continent: the zone badge passes every click through to the map, which opens the zone.
Kit.mapID = 1415
check(#ForeverMapMarkers.LegacyForever(Kit.map) == 0, "a map just turned to lists nothing until it is drawn")
Kit.Tick()
pins = Pins()
check(#pins == 1 and #Areas() == 0, "turning the map redraws: the continent shows its zone badge")
check(pins[1].mouseClicks == false, "a zone badge lets the map take its clicks")
Kit.mouseOver = pins[1]
pins[1]:Run("OnEnter")
Kit.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Kit.Fire("GLOBAL_MOUSE_UP", "LeftButton")
check(#navigated == 1, "a zone badge never travels")
check(tooltip.lines[1] == "Elwynn Forest", "a zone badge's tooltip names the zone")
Kit.mouseOver = nil

-- Combat: a redraw then hides every pin of ours and waits; its end draws once and shows them again.
Kit.mapID = 1429
Kit.combat = true
Kit.Tick()
check(not pin:GetParent().shown, "a redraw in combat hides our pins and acquires none")
check(#ForeverMapMarkers.LegacyForever(Kit.map) == 0, "hidden pins are not listed for other addons")
ns.RefreshMap()
Kit.combat = false
Kit.Fire("PLAYER_REGEN_ENABLED")
check(pin:GetParent().shown and #Pins() == 1, "the end of combat draws the zone and shows our pins again")

-- Settings redraw an open map; closing it ends the view's clicks and hides any tooltip of ours.
pins = Pins()
pins[1]:Run("OnEnter")
Kit.Close()
check(tooltip.owner == nil, "closing the map hides a pin's tooltip")
Kit.visible = true
Kit.Tick()
check(#Pins() == 1, "opening the map again draws it again")

-- Under the gamepad interface, the pin nearest the map's cursor shows its tooltip, as the map's own pins do.
Enum.InputDeviceInterfaceType = { Gamepad = 2 }
C_InputInterfaceStyle = {
	GetCurrentStyle = function()
		return 2
	end,
}
Kit.Close()
Kit.visible = true
pins = Pins()
pins[1].centerX, pins[1].centerY = 100, 100
SoftCursor = {
	IsShown = function()
		return true
	end,
	GetRect = function()
		return 95, 95, 10, 10
	end,
	GetEffectiveScale = function()
		return 1
	end,
}
Kit.Tick()
check(tooltip.owner == Pins()[1], "the gamepad's map cursor points at the pin under it")
SoftCursor.GetRect = function()
	return 300, 300, 10, 10
end
Kit.Tick()
check(tooltip.owner == nil, "moving the map cursor away leaves the pin")
Kit.mouseOver = Pins()[1]
Pins()[1]:Run("OnEnter")
Kit.Tick()
check(tooltip.owner == Pins()[1], "the map cursor never takes away a pin the mouse is on")
Kit.mouseOver = nil
Pins()[1]:Run("OnLeave")

ns.OpenMapMenu()
check(button.opened, "/lf opens the map button's menu")

print(("map_canvas: %d checks passed"):format(checks))
