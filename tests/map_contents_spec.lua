-- Run from the repository root: luajit tests/map_contents_spec.lua
-- UI/MapContents.lua over the real Core/Model.lua, with the client's map API and live progress stubbed.
local CONTINENT, ZONE, EXPLORE_ONLY, OFF_MAP, ELSEWHERE, UNKNOWN, PLAIN = 1, 10, 11, 12, 20, 30, 40

-- Zone 10: an exploration achievement (500) feeding challenge 100, and the challenge's own steps there.
local areaA = { name = "Area A", key = "0:0:100:100", tiles = { 71 } }
local areaB = { name = "Area B", key = "50:0:100:100", hit = { 120, 40, 140, 60 }, tiles = { 72 } }
local wide = { name = "Wide", key = "413:476:549:241", tiles = { 81, 82, 83 } }
local untiled = { name = "Untiled", key = "300:300:10:10" }
local ns = {
	Data = {
		rewards = { [100] = true },
		feeds = { [500] = { 100 } },
		zones = {
			[ZONE] = {
				{ achievement = 500, criteria = 1, kind = "explore", key = areaA.key, x = 0.1, y = 0.1 },
				{ achievement = 500, criteria = 2, kind = "explore", key = areaB.key },
				{ achievement = 100, criteria = 3, kind = "kill", x = 0.4, y = 0.6 },
				{ achievement = 100, criteria = 4, kind = "quest" },
				{ achievement = 100, criteria = 5, kind = "instance", x = 0.7, y = 0.2 },
			},
			[EXPLORE_ONLY] = { { achievement = 500, criteria = 6, kind = "explore", key = "0:0:10:10" } },
			[OFF_MAP] = { { achievement = 100, criteria = 7, kind = "kill", x = 0.5, y = 0.5 } },
			[ELSEWHERE] = { { achievement = 100, criteria = 8, kind = "kill", x = 0.5, y = 0.5 } },
			[UNKNOWN] = { { achievement = 100, criteria = 9, kind = "kill", x = 0.5, y = 0.5 } },
			[PLAIN] = { { achievement = 100, criteria = 10, kind = "kill", x = 0.5, y = 0.5 } },
		},
		completion = {
			[ZONE] = { areas = { areaA, areaB, wide, untiled }, tileWidth = 256, tileHeight = 256 },
			[PLAIN] = { areas = { areaA } },
		},
	},
}

local live = { [500] = {}, [100] = {} }
for id = 1, 10 do
	live[id <= 2 and 500 or id == 6 and 500 or 100][id] = { text = "Step " .. id, completed = false, index = id }
end
live[100][5].completed = true

local settings = { showAreas = true, showEntrances = true }
local shownOnMap = true
local explored = {}
ns.Saved = {
	Get = function(key)
		return settings[key]
	end,
}
ns.ZoneCompletion = {
	IsShown = function(surface)
		return surface == "map" and shownOnMap
	end,
}
local parents =
	{ [ZONE] = CONTINENT, [EXPLORE_ONLY] = CONTINENT, [OFF_MAP] = CONTINENT, [PLAIN] = CONTINENT, [ELSEWHERE] = 2 }
ns.Live = {
	Visible = function()
		return { [100] = true }
	end,
	Criteria = function(id)
		return live[id]
	end,
	ContinentOf = function(uiMapID)
		return parents[uiMapID]
	end,
	ZoneSnapshot = function(uiMapID)
		assert(uiMapID == ZONE, "only a zone with tile data is asked what is explored")
		return { explored = explored }
	end,
}

Enum = { UIMapType = { Continent = 2 } }
C_Map = {
	GetMapInfo = function(uiMapID)
		if uiMapID == CONTINENT or uiMapID == 2 then
			return { mapID = uiMapID, mapType = 2, name = "Continent" }
		elseif uiMapID ~= UNKNOWN then
			return { mapID = uiMapID, mapType = 3, name = "Zone " .. uiMapID, parentMapID = parents[uiMapID] }
		end
	end,
	GetMapRectOnMap = function(uiMapID, onMap)
		assert(onMap == CONTINENT, "badges are placed on the continent being viewed")
		if uiMapID ~= OFF_MAP then
			return 0.25, 0.5, 0.5, 1
		end
	end,
}

assert(loadfile("Core/Model.lua"))("LegacyForever", ns)
assert(loadfile("UI/MapContents.lua"))("LegacyForever", ns)
local MapContents = ns.MapContents
local checks = 0

local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- The button's count and the menu's entries: every unfinished objective placed on the map, pinned or not.
local groups, count = MapContents.Objectives(ZONE)
equal(#groups, 2, "one menu entry per holding achievement")
equal(count, 4, "the count includes exploration and steps without coordinates, not finished ones")
equal(MapContents.IsExploration(groups[1]), true, "an exploration achievement's entry")
equal(MapContents.IsExploration(groups[2]), false, "a challenge's own steps")
groups, count = MapContents.Objectives(nil)
equal(#groups + count, 0, "no map, nothing listed")
equal(
	(select(2, MapContents.Objectives(CONTINENT))),
	0,
	"a continent's own count is zero: its zones hold the objectives"
)

-- A continent: one badge per zone with place-bound objectives left, and nothing else.
local drawn = MapContents.Drawn(CONTINENT)
equal(#drawn.badges, 2, "zones on this continent with a place-bound step and a rectangle on it")
table.sort(drawn.badges, function(a, b)
	return a.uiMapID < b.uiMapID
end)
local badge = drawn.badges[1]
equal(badge.uiMapID, ZONE, "badge names its zone")
equal(badge.name, "Zone 10", "badge carries the zone's name")
equal(badge.count, 2, "a badge counts place-bound objectives only, not exploration")
equal(#badge.groups, 1, "exploration groups are left to the zone map's shading")
equal(badge.x, 0.375, "badge sits at the centre of the zone's rectangle: x")
equal(badge.y, 0.75, "badge sits at the centre of the zone's rectangle: y")
equal(drawn.badges[2].uiMapID, PLAIN, "a zone without shading data still gets its badge")
equal(#drawn.pins, 0, "a continent draws no objective pins")
equal(drawn.shade, nil, "a continent shades nothing")
shownOnMap = false
equal(#MapContents.Drawn(CONTINENT).badges, 0, "badges follow zone completion's On the world map switch")
shownOnMap = true

-- A zone: pins for place-bound objectives with coordinates; exploration is shaded, never pinned.
drawn = MapContents.Drawn(ZONE)
equal(#drawn.badges, 0, "a zone draws no badges")
equal(#drawn.pins, 1, "one pin: not the step without coordinates, the finished one or the exploration")
equal(drawn.pins[1].objective.entry.criteria, 3, "the pinned objective")
equal(drawn.pins[1].group.challenge, 100, "a pin carries its group for the tooltip")
local shade = assert(drawn.shade, "undiscovered areas are shaded")
equal(#shade.areas, 3, "every undiscovered area with tiles, a Legacy step or not")
equal(shade.areas[1].area, areaA, "shaded in data order")
equal(shade.areas[1].objective.objective.text, "Step 1", "a shaded Legacy area carries its step for the hover")
equal(shade.areas[1].objective.group.achievement, 500, "and the exploration achievement it belongs to")
equal(shade.areas[3].objective, nil, "an area that is no Legacy step is still shaded")

-- Tiles laid out like Blizzard's exploration overlays, in canvas pixels.
local tiles = shade.areas[3].tiles
equal(#tiles, 3, "549x241 needs three 256px tiles in one row")
equal(tiles[1].x, 413, "first tile at the overlay's offset: x")
equal(tiles[1].y, 476, "first tile at the overlay's offset: y")
equal(tiles[1].file, 81, "tiles take the overlay's files in order")
equal(tiles[1].u, 1, "full tile samples the whole file")
equal(tiles[3].file, 83, "third tile's file")
equal(tiles[3].x, 413 + 512, "third tile offset")
equal(tiles[3].width, 37, "last tile keeps the remainder")
equal(tiles[3].height, 241, "a single row keeps the overlay's height")
equal(tiles[3].u, 37 / 64, "partial tile samples its power-of-two file")
equal(tiles[3].v, 241 / 256, "partial row samples its power-of-two file")
equal(#shade.areas[1].tiles, 1, "an overlay smaller than a tile is one tile")

-- Hover: the area whose centre is nearest among those whose texture holds the point.
equal(MapContents.AreaAt(shade, 10, 50), shade.areas[1], "only one texture holds the point")
equal(MapContents.AreaAt(shade, 70, 50), shade.areas[1], "nearer the first area's centre")
equal(MapContents.AreaAt(shade, 95, 50), shade.areas[2], "nearer the second area's hit rectangle")
equal(MapContents.AreaAt(shade, 200, 50), nil, "outside every texture")
equal(MapContents.AreaAt(shade, 305, 305), nil, "an area with no tiles is not shaded, so not hovered")

-- Discovering an area takes its shade away, and it no longer lights up its overlapping neighbour.
explored = { [areaA.key] = true }
shade = assert(MapContents.Drawn(ZONE).shade)
equal(#shade.areas, 2, "an explored area is not shaded")
equal(MapContents.AreaAt(shade, 70, 50), nil, "an explored area under the cursor does not light its neighbour")
equal(MapContents.AreaAt(shade, 95, 50), shade.areas[1], "the unexplored neighbour still answers where it is nearest")
explored = { [areaA.key] = true, [areaB.key] = true, [wide.key] = true }
equal(MapContents.Drawn(ZONE).shade, nil, "nothing left to discover, nothing to shade")
explored = {}

-- The "Show undiscovered areas" switch removes the shade; exploration still gets no pins.
settings.showAreas = false
drawn = MapContents.Drawn(ZONE)
equal(drawn.shade, nil, "shading switched off")
equal(#drawn.pins, 1, "exploration is not pinned even with shading off")
settings.showAreas = true

-- "Show dungeon and raid entrances" off takes only the entrance pins away: the other pins, the shade, the
-- continent badges, the button's count and the menu's entries stay.
live[100][5].completed = false
drawn = MapContents.Drawn(ZONE)
equal(#drawn.pins, 2, "an unfinished entrance is pinned")
equal(drawn.pins[2].objective.entry.kind, "instance", "the entrance pin")
settings.showEntrances = false
drawn = MapContents.Drawn(ZONE)
equal(#drawn.pins, 1, "entrances switched off: only the entrance pin goes")
equal(drawn.pins[1].objective.entry.criteria, 3, "the boss pin stays")
equal(#assert(drawn.shade, "the shade stays").areas, 3, "every undiscovered area is still shaded")
groups, count = MapContents.Objectives(ZONE)
equal(count, 5, "the button still counts the entrance")
equal(#groups[2].objectives, 3, "and the menu still lists it")
for _, zone in ipairs(MapContents.Drawn(CONTINENT).badges) do
	if zone.uiMapID == ZONE then
		badge = zone
	end
end
equal(badge.count, 3, "a continent badge still counts the entrance")
settings.showEntrances = true
live[100][5].completed = true

drawn = MapContents.Drawn(PLAIN)
equal(drawn.shade, nil, "a zone without tile data has no shade")
equal(#drawn.pins, 1, "but keeps its pins")
drawn = MapContents.Drawn(nil)
equal(#drawn.pins + #drawn.badges, 0, "no map, nothing drawn")

print(("map_contents_spec: %d checks passed"):format(checks))
