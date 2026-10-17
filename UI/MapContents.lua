---@type string, LegacyForeverNamespace
local _, ns = ...

-- What the world map shows for a map ID, as plain tables: the objectives its button counts and its
-- menu lists, and what the pin provider draws. UI/Map.lua turns the answer into pins, textures and
-- tooltips; tests/map_contents_spec.lua drives this file with stubbed client globals.
---@class LegacyMapContents
local MapContents = {}
ns.MapContents = MapContents

---@class LegacyMapPin
---@field group LegacyGroup
---@field objective LegacyObjective

-- One map tile of a shaded area, placed in canvas pixels from the canvas's top-left.
---@class LegacyShadeTile
---@field file? number
---@field x number
---@field y number
---@field width number
---@field height number
---@field u number
---@field v number

---@class LegacyShadedArea
---@field area LegacyArea
---@field tiles LegacyShadeTile[]
---@field objective? LegacyAreaObjective the Legacy step this area is, when it is one

---@class LegacyShade
---@field zone LegacyZone
---@field areas LegacyShadedArea[]
---@field byKey table<string, LegacyShadedArea>

---@class LegacyMapDrawing
---@field badges LegacyContinentZone[] a continent's zone badges
---@field pins LegacyMapPin[] a zone's place-bound objectives
---@field shade? LegacyShade a zone's undiscovered areas, when there are any to shade

-- Exploration is shaded on the zone map; everything else is pinned.
---@param group LegacyGroup
---@return boolean
function MapContents.IsExploration(group)
	return group.objectives[1].entry.kind == "explore"
end

-- The unfinished objectives the data places on this map, and how many: the map button's count and
-- its menu's entries.
---@param uiMapID number?
---@return LegacyGroup[] groups
---@return number count
function MapContents.Objectives(uiMapID)
	if not uiMapID then
		return {}, 0
	end
	local groups = ns.Model.ZoneObjectives(ns.Data, uiMapID, ns.Live.Visible(), ns.Live.Criteria)
	return groups, ns.Model.CountObjectives(groups)
end

-- On a continent, one badge per zone with unfinished objectives, instead of every pin; its tooltip gives the count.
-- Exploration is left to the zone map's shading, so badges count place-bound objectives only.
---@param continentID number
---@return LegacyContinentZone[]
local function Badges(continentID)
	local zones = {}
	for uiMapID in pairs(ns.Data.zones) do
		local info = C_Map.GetMapInfo(uiMapID)
		if info and ns.Live.ContinentOf(uiMapID) == continentID then
			local groups = {}
			for _, group in ipairs((MapContents.Objectives(uiMapID))) do
				if not MapContents.IsExploration(group) then
					groups[#groups + 1] = group
				end
			end
			local count = ns.Model.CountObjectives(groups)
			local left, right, top, bottom = C_Map.GetMapRectOnMap(uiMapID, continentID)
			if count > 0 and left then
				zones[#zones + 1] = {
					uiMapID = uiMapID,
					name = info.name,
					groups = groups,
					count = count,
					x = (left + right) / 2,
					y = (top + bottom) / 2,
				}
			end
		end
	end
	return zones
end

-- offsetX, offsetY, width, height from an overlay key ("offsetX:offsetY:width:height").
---@param key string
---@return number offsetX
---@return number offsetY
---@return number width
---@return number height
local function OverlayRect(key)
	local offsetX, offsetY, width, height = key:match("^(%d+):(%d+):(%d+):(%d+)$")
	-- The generator validates overlay keys; fail here if another caller violates that contract.
	return assert(tonumber(offsetX)), assert(tonumber(offsetY)), assert(tonumber(width)), assert(tonumber(height))
end

-- A tile's drawn size and how much of its power-of-two file that covers; only the last
-- tile in a row or column is partial.
---@param total number
---@param tileSize number
---@param index number
---@param count number
---@return number pixels
---@return number fraction
local function TileSpan(total, tileSize, index, count)
	if index < count then
		return tileSize, 1
	end
	local pixels = total % tileSize
	if pixels == 0 then
		pixels = tileSize
	end
	local file = 16
	while file < pixels do
		file = file * 2
	end
	return pixels, pixels / file
end

-- An area's tiles laid out as Blizzard's MapExplorationPinMixin:RefreshOverlays does it: row-major
-- through the overlay's tile list, from the overlay's top-left.
---@param area LegacyArea
---@param tileWidth number
---@param tileHeight number
---@return LegacyShadeTile[]
local function AreaTiles(area, tileWidth, tileHeight)
	local offsetX, offsetY, width, height = OverlayRect(area.key)
	local wide, tall = math.ceil(width / tileWidth), math.ceil(height / tileHeight)
	local tiles = {}
	for row = 1, tall do
		local tileH, v = TileSpan(height, tileHeight, row, tall)
		for col = 1, wide do
			local tileW, u = TileSpan(width, tileWidth, col, wide)
			tiles[#tiles + 1] = {
				file = area.tiles[(row - 1) * wide + col],
				x = offsetX + tileWidth * (col - 1),
				y = offsetY + tileHeight * (row - 1),
				width = tileW,
				height = tileH,
				u = u,
				v = v,
			}
		end
	end
	return tiles
end

-- The zone's undiscovered areas that have map tiles; nil for a map without shading data, with the
-- shading switched off, or with nothing left to discover.
---@param uiMapID number
---@return LegacyShade?
local function Shade(uiMapID)
	local zone = ns.Saved.Get("showAreas") and ns.Data.completion[uiMapID]
	if not (zone and zone.tileWidth and zone.tileHeight) then
		return nil
	end
	local explored = ns.Live.ZoneSnapshot(uiMapID).explored
	---@type LegacyShade
	local shade = { zone = zone, areas = {}, byKey = {} }
	for _, area in ipairs(zone.areas) do
		if area.tiles and not explored[area.key] then
			local shaded = { area = area, tiles = AreaTiles(area, zone.tileWidth, zone.tileHeight) }
			shade.areas[#shade.areas + 1] = shaded
			shade.byKey[area.key] = shaded
		end
	end
	return #shade.areas > 0 and shade or nil
end

-- What the pin provider draws. A continent gets zone badges, which follow zone completion's "On the
-- world map" switch, so turning it off leaves continents bare. A zone gets a pin per place-bound
-- objective (bosses, dungeons, quests) and its undiscovered areas shaded; exploration is never
-- pinned, a shaded area carrying its Legacy step for the hover instead. "Show dungeon and raid entrances"
-- off leaves out only the entrance pins: the button still counts them and its menu still lists them.
---@param uiMapID number?
---@return LegacyMapDrawing
function MapContents.Drawn(uiMapID)
	---@type LegacyMapDrawing
	local drawn = { badges = {}, pins = {} }
	local entrances = ns.Saved.Get("showEntrances")
	local info = uiMapID and C_Map.GetMapInfo(uiMapID)
	if uiMapID and info and info.mapType == Enum.UIMapType.Continent then
		if ns.ZoneCompletion.IsShown("map") then
			drawn.badges = Badges(uiMapID)
		end
		return drawn
	end
	local shade = uiMapID and Shade(uiMapID) or nil
	for _, group in ipairs((MapContents.Objectives(uiMapID))) do
		for _, objective in ipairs(group.objectives) do
			local entry = objective.entry
			local shaded = entry.kind == "explore" and shade and shade.byKey[entry.key]
			if shaded then
				shaded.objective = { group = group, objective = objective }
			elseif entry.x and entry.kind ~= "explore" and (entrances or entry.kind ~= "instance") then
				drawn.pins[#drawn.pins + 1] = { group = group, objective = objective }
			end
		end
	end
	drawn.shade = shade
	return drawn
end

-- The shaded area under a point on the map canvas, or nil. The area is picked among all the zone's
-- areas, explored or not, so an explored label never lights up the unexplored neighbour whose
-- rectangle overlaps it. Overlay textures are rectangles around irregular shapes and overlap, so of
-- the areas whose texture holds the point, the one whose centre (its hit rectangle's, Blizzard's own
-- label target, else the texture's) is nearest wins.
---@param shade LegacyShade
---@param x number
---@param y number
---@return LegacyShadedArea?
function MapContents.AreaAt(shade, x, y)
	local best, bestDistance
	for _, area in ipairs(shade.zone.areas) do
		local offsetX, offsetY, width, height = OverlayRect(area.key)
		if x >= offsetX and x <= offsetX + width and y >= offsetY and y <= offsetY + height then
			local left, top, right, bottom = offsetX, offsetY, offsetX + width, offsetY + height
			if area.hit then
				left, top, right, bottom = area.hit[1], area.hit[2], area.hit[3], area.hit[4]
			end
			local dx, dy = x - (left + right) / 2, y - (top + bottom) / 2
			local distance = dx * dx + dy * dy
			if not bestDistance or distance < bestDistance then
				best, bestDistance = area, distance
			end
		end
	end
	return best and shade.byKey[best.key] or nil
end
