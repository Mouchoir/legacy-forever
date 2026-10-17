-- Load UI/Map.lua through its normal addon-loaded callback and exercise the real provider.
-- This catches protected MapCanvas calls without copying the implementation into the test.
local combat, removed, acquired, hidden = false, 0, 0, 0
local regenCallback, provider, eventCallback, savedListener

local function text(value)
	return setmetatable({ value = value }, {
		__index = function(self, key)
			if key == "format" then
				return function()
					return self.value
				end
			end
		end,
	})
end

local env = setmetatable({
	REPUTATION = "Reputation",
	MapCanvasPinMixin = {},
	MapCanvasDataProviderMixin = {
		GetMap = function(self)
			return self.map
		end,
	},
	CreateFromMixins = function(base)
		local value = {}
		for key, method in pairs(base or {}) do
			value[key] = method
		end
		return value
	end,
	EventUtil = {
		ContinueOnAddOnLoaded = function(_, callback)
			regenCallback = callback
		end,
	},
	InCombatLockdown = function()
		return combat
	end,
	CreateFrame = function()
		return {
			RegisterEvent = function() end,
			SetScript = function(_, _, callback)
				eventCallback = callback
			end,
		}
	end,
	Enum = { UIMapType = { Continent = 2 } },
	C_Map = {
		GetMapInfo = function()
			return { mapType = 1 }
		end,
	},
}, { __index = _G })

env.WorldMapFrame = {
	IsShown = function()
		return true
	end,
	GetMapID = function()
		return 1
	end,
	AddDataProvider = function(_, value)
		provider = value
	end,
	AddOverlayFrame = function()
		return {
			IsMenuOpen = function()
				return false
			end,
			OpenMenu = function() end,
			Refresh = function() end,
		}
	end,
	EnumeratePinsByTemplate = function()
		local yielded = false
		return function()
			if yielded then
				return nil
			end
			yielded = true
			return {
				SetShown = function(_, shown)
					if not shown then
						hidden = hidden + 1
					end
				end,
			}
		end
	end,
	RemoveAllPinsByTemplate = function(_, template)
		assert(not combat, "RemoveAllPinsByTemplate is protected in combat: " .. template)
		removed = removed + 1
	end,
	AcquirePin = function()
		assert(not combat, "AcquirePin is protected in combat")
		acquired = acquired + 1
	end,
}

local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return text(key)
		end,
	}),
	POINTS_ICON = "icon",
	Data = { zones = {} },
	ZoneCompletion = {
		IsShown = function()
			return false
		end,
		OnChange = function() end,
	},
	Saved = {
		Get = function()
			return false
		end,
		OnChange = function(callback)
			savedListener = callback
		end,
	},
	Live = {
		Visible = function()
			return false
		end,
	},
	Model = {
		ZoneObjectives = function()
			return { { objectives = { { entry = { kind = "kill", x = 0.5, y = 0.5 } } } } }
		end,
		CountObjectives = function()
			return 1
		end,
	},
}
for _, file in ipairs({ "UI/MapContents.lua", "UI/Map.lua" }) do
	local chunk = assert(loadfile(file))
	setfenv(chunk, env)
	chunk("LegacyForever", ns)
end
assert(regenCallback, "UI/Map.lua did not register its normal load callback")
regenCallback()
assert(provider and eventCallback, "normal map attachment did not install provider/events")
provider.map = env.WorldMapFrame

combat = true
provider:RefreshAllData()
provider:RefreshAllData()
assert(removed == 0 and acquired == 0 and hidden == 4, "combat refresh touched protected pins")

combat = false
eventCallback(nil, "PLAYER_REGEN_ENABLED")
assert(removed == 2 and acquired == 1, "regen event did not rebuild and acquire pins exactly once")
-- The map switches redraw the pins at once; any other switch leaves them alone.
assert(savedListener, "UI/Map.lua did not listen for switches")
savedListener("whatsNew", false)
assert(removed == 2 and acquired == 1, "a switch the map does not draw from redrew it")
savedListener("showEntrances", false)
assert(removed == 4 and acquired == 2, "turning entrances off did not redraw the pins")
savedListener("showAreas", true)
assert(removed == 6 and acquired == 3, "turning the shading on did not redraw the pins")
print("map_combat: real UI/Map.lua attachment protected-refresh contract passed")
