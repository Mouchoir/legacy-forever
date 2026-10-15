---@type string, LegacyForeverNamespace
local _, ns = ...

-- Legacy Forever's own lines in /lf report, which are the /lf audit lines: the bundled data against what the game
-- reports, so a data problem shows up as a count and a list of IDs rather than as a silently missing pin, then the
-- tracker and the current zone's completion. English throughout, so a report reads the same in every locale.

local MISSING_SHOWN = 10

---@param data LegacyData
---@param lines string[]
local function AuditChallenges(data, lines)
	local visible = ns.Live.Visible()
	local numVisible = 0
	for _ in pairs(visible) do
		numVisible = numVisible + 1
	end
	lines[#lines + 1] = ("%d unfinished Legacy challenges listed for this character"):format(numVisible)
	if numVisible == 0 then
		lines[#lines + 1] =
			"the game listed none unfinished; if you're below level 25 or just logged in, try again shortly."
		return
	end

	local checked, missing = 0, {}
	for uiMapID, entries in pairs(data.zones) do
		for _, entry in ipairs(entries) do
			if ns.Model.OwningChallenge(data, entry.achievement, visible) then
				checked = checked + 1
				local live = ns.Live.Criteria(entry.achievement)
				if not (live and live[entry.criteria]) then
					missing[#missing + 1] = ("%d:%d (map %d)"):format(entry.achievement, entry.criteria, uiMapID)
				end
			end
		end
	end
	table.sort(missing)
	lines[#lines + 1] = ("%d located objectives checked, %d unknown to the game"):format(checked, #missing)
	for i = 1, math.min(#missing, MISSING_SHOWN) do
		lines[#lines + 1] = "  unknown criteria " .. missing[i]
	end

	local unlocated = ns.Model.Unlocated(data, visible, ns.Live.Criteria)
	lines[#lines + 1] = ("%d challenges have objectives with no fixed location"):format(#unlocated)
	lines[#lines + 1] = ("tracker: %d tracked, Legacy section %s"):format(
		ns.Tracker.Count(),
		ns.Tracker.IsAttached() and "in the objective tracker" or "NOT in the objective tracker"
	)
end

-- What /lf audit prints.
---@return string[]
function ns.AuditLines()
	local data = ns.Data
	local version, build = GetBuildInfo()
	local lines = { ("data from build %s, client build %s.%s"):format(data.build, version, build) }
	AuditChallenges(data, lines)
	ns.ZoneCompletion.AuditLines(lines)
	return lines
end

-- The report's Legacy Forever lines: the audit's. UI/Report.lua caps them, so they never crowd out the errors.
---@return string[]
function ns.ReportLines()
	return ns.AuditLines()
end
