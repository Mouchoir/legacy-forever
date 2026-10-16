---@type string, LegacyForeverNamespace
local _, ns = ...
local L = ns.L

-- Passed to Shortest Path Forever so it can tell our journeys apart from the player's own.
local OWNER = "LegacyForever"

-- Only the one function called is checked, so a newer Shortest Path that keeps version 1 still counts.
---@return (fun(owner: string, map: integer, x: number, y: number, title?: string): boolean)?
local function ShortestPath()
	local addon = ShortestPathForever
	local api = type(addon) == "table" and addon.API
	if type(api) == "table" and api.version == 1 and type(api.Navigate) == "function" then
		return api.Navigate
	end
end

-- The addon folder the TOC's OptionalDeps names.
local SHORTEST_PATH = "ShortestPathForever"

-- A grey suggestion under a pin's click hint: Shortest Path Forever plots the whole route, flights and boats
-- included, where the game's waypoint is a straight line. Only while it isn't installed and the shared
-- "Suggest my other Forever addons" switch is on (UI/ForeverFamily.lua); one installed but turned off was the
-- player's choice.
---@return string?
function ns.CompanionHint()
	if ns.Family.Hint(ns.FamilyDB(), "LegacyForever.pinShortestPath", SHORTEST_PATH) then
		return L["Install Shortest Path Forever to have the route plotted for you."]
	end
	return nil
end

-- Names what a click tries first; Navigate still falls back when Shortest Path declines.
---@return string
function ns.NavigateHint()
	return ShortestPath() and L["Click to travel here with Shortest Path Forever."]
		or L["Click to set a waypoint here."]
end

-- Shortest Path's journey when it takes one (it declines in combat, with journeys switched off or with no player
-- position), else the game's own waypoint. False, with why, when neither takes the place.
---@param uiMapID number
---@param x number
---@param y number
---@param title string
---@return boolean
---@return "combat"|"unavailable"|nil
function ns.Guide(uiMapID, x, y, title)
	local navigate = ShortestPath()
	if navigate and navigate(OWNER, uiMapID, x, y, title) then
		return true
	end
	if C_Map.CanSetUserWaypointOnMap(uiMapID) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(uiMapID, x, y))
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
		return true
	end
	return false, navigate and InCombatLockdown() and "combat" or "unavailable"
end

-- A journey or waypoint, else the place in chat, so a click always leaves the player a pointer.
---@param uiMapID number
---@param x number
---@param y number
---@param title string
function ns.Navigate(uiMapID, x, y, title)
	if ns.Guide(uiMapID, x, y, title) then
		return
	end
	local info = C_Map.GetMapInfo(uiMapID)
	local place = ("%.1f, %.1f"):format(x * 100, y * 100)
	if info then
		ns.Print(L["%s is at %s in %s."]:format(title, place, info.name))
	else
		ns.Print(L["%s is at %s."]:format(title, place))
	end
end
