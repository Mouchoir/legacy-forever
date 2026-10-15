-- Run from the repository root: luajit tests/whatsnew_spec.lua
-- The chat line after an update: once per new version, never on a first install, in a checkout or when switched off.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local version, onLogin
local printed = {}
C_AddOns = {
	GetAddOnMetadata = function(name, field)
		assert(name == "LegacyForever" and field == "Version", "reads its own version")
		return version
	end,
}
CreateFrame = function()
	return {
		RegisterEvent = function(_, event)
			assert(event == "PLAYER_LOGIN", "waits for login")
		end,
		SetScript = function(_, _, handler)
			onLogin = handler
		end,
	}
end
SlashCmdList = {}
local ns = {}
assert(loadfile("Locales/enUS.lua"))("LegacyForever", ns)
assert(loadfile("Core/SafeCall.lua"))("LegacyForever", ns)
assert(loadfile("Core/Core.lua"))("LegacyForever", ns)
assert(loadfile("Core/Saved.lua"))("LegacyForever", ns)
function ns.Print(msg)
	printed[#printed + 1] = msg
end
assert(loadfile("UI/WhatsNew.lua"))("LegacyForever", ns)
check(onLogin == ns.WhatsNew, "runs at login")

-- A first install, even with no saved variables loaded at all: silent, and the version is remembered.
LegacyForeverDB, version = nil, "0.6.0"
ns.WhatsNew()
check(#printed == 0, "a first install says nothing")
check(LegacyForeverDB and LegacyForeverDB.lastVersion == "0.6.0", "the version is remembered")

-- The same version again: silent.
ns.WhatsNew()
check(#printed == 0, "the same version says nothing")

-- A new version: one line, then remembered.
version = "0.7.0"
ns.WhatsNew()
check(#printed == 1 and printed[1] == "updated to 0.7.0. " .. ns.WHATS_NEW, "an update says what's new once")
ns.WhatsNew()
check(#printed == 1 and LegacyForeverDB.lastVersion == "0.7.0", "and not again")

-- Switched off: silent, but still remembered.
LegacyForeverDB.whatsNew, version = false, "0.8.0"
ns.WhatsNew()
check(#printed == 1 and LegacyForeverDB.lastVersion == "0.8.0", "switched off says nothing")

-- A checkout: the packager's keyword is still there, so nothing is said or stored.
LegacyForeverDB, version = { lastVersion = "0.8.0" }, "@project-version@"
ns.WhatsNew()
check(#printed == 1 and LegacyForeverDB.lastVersion == "0.8.0", "a checkout says and stores nothing")
version = nil
ns.WhatsNew()
check(#printed == 1, "no version says nothing")

print(("whatsnew_spec: %d checks passed"):format(checks))
