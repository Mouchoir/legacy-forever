---@type string, LegacyForeverNamespace
local _, ns = ...

-- Art at its native aspect (AGENTS.md: never stretch art): every atlas is sized from C_Texture.GetAtlasInfo, on a
-- texture or inline in text. tools/lint_art.py refuses a raw art setter in any other file unless its line says why
-- its shape is right.

---@class LegacyArt
local Art = {}
ns.Art = Art

-- `atlas` at its native shape, as large as fits in maxWidth by maxHeight. The caller anchors the texture by one
-- point, so it stays centred in its box.
---@param texture Texture
---@param atlas string
---@param maxWidth number
---@param maxHeight number
function Art.Fit(texture, atlas, maxWidth, maxHeight)
	texture:SetAtlas(atlas)
	local info = C_Texture.GetAtlasInfo(atlas)
	if info then
		local scale = math.min(maxWidth / info.width, maxHeight / info.height)
		texture:SetSize(info.width * scale, info.height * scale)
	end
end

-- The same inline in text, which draws whole pixels: the longest side at most `size` whose rounded short side keeps
-- the atlas's shape within 2%, trying up to two pixels smaller before settling for the closest.
---@param atlas string
---@param size integer
---@return string
function Art.Markup(atlas, size)
	local info = C_Texture.GetAtlasInfo(atlas)
	local aspect = info and info.width / info.height or 1
	local shape = math.min(aspect, 1 / aspect)
	local long, short, best = size, size, math.huge
	for side = size, math.max(1, size - 2), -1 do
		local other = math.max(1, math.floor(side * shape + 0.5))
		local off = math.abs(other / side / shape - 1)
		if off < best then
			long, short, best = side, other, off
		end
		if off <= 0.02 then
			break
		end
	end
	if aspect < 1 then
		return CreateAtlasMarkup(atlas, short, long)
	end
	return CreateAtlasMarkup(atlas, long, short)
end

-- A file icon, square as every one is, `size` across and whole: a texture that drew an atlas before keeps that
-- atlas's crop until it is reset.
---@param texture Texture
---@param file string|integer
---@param size number
function Art.Icon(texture, file, size)
	texture:SetTexCoord(0, 1, 0, 1)
	texture:SetTexture(file)
	texture:SetSize(size, size)
end
