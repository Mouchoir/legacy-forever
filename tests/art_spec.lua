-- Run from the repository root: luajit tests/art_spec.lua
-- Core/Art.lua on its own, with a stub C_Texture.GetAtlasInfo: an atlas fits its box at its own shape, on a texture
-- and inline in text.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

-- The escape stores height first (Blizzard's CreateAtlasMarkup); sizes from UiTextureAtlasMember, 1.60.1.70124.
local function CreateAtlasMarkup(atlas, width, height)
	return ("|A:%s:%d:%d|a"):format(atlas, height, width)
end
local atlases = {
	["UI-Legacy-Points-icon-c60"] = { width = 50, height = 73 },
	["islands-queue-prop-compass"] = { width = 300, height = 297 },
	wide = { width = 209, height = 46 },
}
local C_Texture = {
	GetAtlasInfo = function(atlas)
		return atlases[atlas]
	end,
}

local ns = {}
local chunk = assert(loadfile("Core/Art.lua"))
setfenv(chunk, setmetatable({ C_Texture = C_Texture, CreateAtlasMarkup = CreateAtlasMarkup }, { __index = _G }))
chunk("LegacyForever", ns)
local Art = ns.Art

local texture = {
	SetAtlas = function(self, atlas)
		self.atlas = atlas
	end,
	SetSize = function(self, width, height)
		self.width, self.height = width, height
	end,
}
Art.Fit(texture, "UI-Legacy-Points-icon-c60", 14, 20)
check(texture.atlas == "UI-Legacy-Points-icon-c60", "fit: the atlas")
check(
	texture.height == 20 and math.abs(texture.width / texture.height - 50 / 73) < 1e-9,
	"fit: a pin's shield fills the height, not 14x20"
)
Art.Fit(texture, "wide", 22, 25)
check(
	texture.width == 22 and math.abs(texture.width / texture.height - 209 / 46) < 1e-9,
	"fit: a wide atlas fills the width"
)
Art.Fit(texture, "unknown", 40, 40)
check(
	texture.atlas == "unknown" and texture.width == 22,
	"fit: an atlas the client can't size keeps the texture's size"
)

check(
	Art.Markup("UI-Legacy-Points-icon-c60", 14) == "|A:UI-Legacy-Points-icon-c60:13:9|a",
	"markup: 9 by 13, not 10 by 14"
)
check(Art.Markup("islands-queue-prop-compass", 14) == "|A:islands-queue-prop-compass:14:14|a", "markup: near-square")
check(Art.Markup("wide", 22) == "|A:wide:5:22|a", "markup: a wide atlas keeps its width")
check(Art.Markup("unknown", 12) == "|A:unknown:12:12|a", "markup: an unknown atlas is square")

-- A file icon: square, with any crop an atlas left reset.
texture.SetTexCoord = function(self, ...)
	self.coords = { ... }
end
texture.SetTexture = function(self, file)
	self.file = file
end
Art.Icon(texture, "Interface\\AddOns\\LegacyForever\\media\\Icon", 62)
check(texture.file == "Interface\\AddOns\\LegacyForever\\media\\Icon", "icon: the file")
check(texture.width == 62 and texture.height == 62, "icon: square")
check(table.concat(texture.coords, ",") == "0,1,0,1", "icon: the whole file, not an atlas's crop")

print(("art_spec: %d checks passed"):format(checks))
