-- Run from the repository root: luajit tests/tracker_layout_spec.lua
-- The Legacy tracker section's lines, including a step or name the client has not loaded yet.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end
local function noop() end

local modules = {}
local env = setmetatable({
	ObjectiveTrackerFrame = {},
	ObjectiveTrackerManager = {},
	CreateFrame = function(_, name)
		local frame = { SetHeader = noop }
		if name then
			modules[#modules + 1] = frame
		end
		return frame
	end,
	Mixin = function(target, source)
		for key, value in pairs(source) do
			target[key] = value
		end
	end,
	EventUtil = { ContinueAfterAllEvents = noop },
	C_Timer = { After = noop },
	hooksecurefunc = function()
		error("native methods must stay unhooked")
	end,
}, { __index = _G })

local lines = {}
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Data = {},
	SavedTable = function()
		return { 1 }
	end,
	Model = {
		TrackedBlocks = function()
			return { { challenge = 1, lines = lines } }
		end,
	},
	Live = {
		OnChange = noop,
		Visible = noop,
		Criteria = noop,
		Name = function()
			return "Challenge"
		end,
	},
}
setfenv(assert(loadfile("UI/Tracker.lua")), env)("LegacyForever", ns)
local module = assert(modules[1], "the section is created at load")

local objectives
local block = {
	SetHeader = noop,
	AddObjective = function(_, key, text)
		objectives[#objectives + 1] = { key = key, text = text }
	end,
}
function module.GetBlock()
	return block
end
function module.LayoutBlock()
	return true
end

---@param given table[]
local function Layout(given)
	lines, objectives = given, {}
	module:LayoutContents()
	return objectives
end

local shown = Layout({
	{ text = "Reach level 20", detail = "12/20", seen = "c1" },
	{ text = "Explore Felwood", seen = "c2" },
})
check(#shown == 2, "one objective per line")
check(shown[1].text == "12/20 Reach level 20", "a counted step leads with its progress")
check(shown[2].text == "Explore Felwood", "an uncounted step is its text")

shown = Layout({
	{ detail = "3/10", seen = "a1" },
	{ text = "Explore Felwood", seen = "c2" },
	{ seen = "c3" },
})
check(#shown == 2, "a line with nothing to show is skipped, not an error")
check(shown[1].key == 1 and shown[1].text == "3/10", "a name the client has not loaded shows its progress alone")
check(shown[2].key == 2 and shown[2].text == "Explore Felwood", "the next line is unaffected")

print(("tracker_layout_spec: %d checks passed"):format(checks))
