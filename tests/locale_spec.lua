-- Run from the repository root: luajit tests/locale_spec.lua
-- Every phrase a player reads goes through L, so a Locales/<locale>.lua file can translate it: a text sink in the
-- shipped Lua (outside Locales/) never gets a bare English literal, Locales/phrases.txt, the template translators
-- copy, is what tools/phrases.py prints today, and every translation file is in the TOC.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

-- The argument positions that reach the screen, by call name.
local SINKS = {
	Print = { 1 },
	SetText = { 1 },
	SetHeader = { 1 },
	AddLine = { 1 },
	AddDoubleLine = { 1, 2 },
	AddObjective = { 2 },
	CreateTitle = { 1 },
	CreateButton = { 1 },
	CreateCheckbox = { 1 },
	GameTooltip_SetTitle = { 2 },
	GameTooltip_AddNormalLine = { 2 },
	GameTooltip_AddHighlightLine = { 2 },
	GameTooltip_AddInstructionLine = { 2 },
	GameTooltip_AddDisabledLine = { 2 },
	GameTooltip_AddColoredLine = { 2 },
	GameTooltip_AddErrorLine = { 2 },
}

-- /lf audit and /lf criteria: output for reporting a data problem, left in English on purpose.
local DEBUG = {
	["%d unfinished Legacy challenges listed for this character"] = true,
	["the game listed none unfinished; if you're below level 25 or just logged in, try again shortly."] = true,
	["%d located objectives checked, %d unknown to the game"] = true,
	["  unknown criteria "] = true,
	["%d challenges have objectives with no fixed location"] = true,
	["tracker: %d tracked, Legacy section %s"] = true,
	["data from build %s, client build %s.%s"] = true,
	["achievement %d (%s): %d criteria"] = true,
	["  %d: id %s type %s asset %s %s%s"] = true,
	["usage: /lf criteria 684"] = true,
	["zone completion: no data for the zone you're in."] = true,
	["quests from QuestieDB: %s"] = true,
	["zone completion for %s (map %d): %s"] = true,
	["  explored area not in the data: "] = true,
	["  the game reports nothing explored in this zone"] = true,
	["  flight path %d (%s): %s"] = true,
}

-- Names, strings (with their quotes kept off) and single punctuation; comments dropped.
local function Tokens(source)
	local tokens, i = {}, 1
	while i <= #source do
		local c = source:sub(i, i)
		if source:find("^%-%-%[(=*)%[", i) then
			local equals = source:match("^%-%-%[(=*)%[", i)
			i = select(2, source:find("]" .. equals .. "]", i, true)) + 1
		elseif source:find("^%-%-", i) then
			i = (source:find("\n", i) or #source) + 1
		elseif c == '"' or c == "'" then
			local j = i + 1
			while source:sub(j, j) ~= c do
				j = j + (source:sub(j, j) == "\\" and 2 or 1)
			end
			tokens[#tokens + 1] = { kind = "string", value = source:sub(i + 1, j - 1) }
			i = j + 1
		elseif c:find("[%a_]") then
			local name = source:match("^[%w_]+", i)
			tokens[#tokens + 1] = { kind = "name", value = name }
			i = i + #name
		elseif c:find("%s") then
			i = i + 1
		else
			tokens[#tokens + 1] = { kind = "punct", value = c }
			i = i + 1
		end
	end
	return tokens
end

-- A literal a player would read: letters left once colour codes and format specifiers are gone.
local function IsWords(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%%[-%d%.]*[sdfgx%%]", "")
	return text:find("%a") ~= nil
end

-- The bare literals in a call's text arguments, or in `headerText = "..."`.
local function BareLiterals(tokens)
	local found = {}
	-- Only the argument's own literals: one passed to another call ("mapCollapsed") is a key, but a
	-- parenthesised format string, ("%s left"):format(n), is the text.
	local function Scan(from, to)
		local depth = 0
		for k = from, to do
			local token = tokens[k]
			local value = token.kind == "punct" and token.value
			if value == "(" or value == "{" or value == "[" then
				depth = depth + 1
			elseif value == ")" or value == "}" or value == "]" then
				depth = depth - 1
			end
			local translated = tokens[k - 1].value == "[" and tokens[k - 2].value == "L"
			local before = tokens[k - 2]
			local keyword = before.value == "and"
				or before.value == "or"
				or before.value == "not"
				or before.value == "return"
			local call = (before.kind == "name" and not keyword) or before.value == ")" or before.value == "]"
			local wrapped = tokens[k - 1].value == "(" and tokens[k + 1].value == ")" and depth == 1 and not call
			local shown = token.kind == "string" and (depth == 0 or wrapped) and not translated
			if shown and IsWords(token.value) and not DEBUG[token.value] then
				found[#found + 1] = token.value
			end
		end
	end
	for k, token in ipairs(tokens) do
		local positions = token.kind == "name" and SINKS[token.value]
		if positions and tokens[k + 1] and tokens[k + 1].value == "(" then
			local depth, argument, start = 0, 1, k + 2
			local wanted = {}
			for _, position in ipairs(positions) do
				wanted[position] = true
			end
			for j = k + 1, #tokens do
				local value = tokens[j].kind == "punct" and tokens[j].value
				if value == "(" or value == "{" or value == "[" then
					depth = depth + 1
				elseif value == ")" or value == "}" or value == "]" then
					depth = depth - 1
				end
				local ends = depth == 0 or (depth == 1 and value == ",")
				if ends then
					if wanted[argument] then
						Scan(start, j - 1)
					end
					argument, start = argument + 1, j + 1
					if depth == 0 then
						break
					end
				end
			end
		elseif token.value == "headerText" and tokens[k + 1].value == "=" then
			Scan(k + 2, k + 2)
		end
	end
	return found
end

-- The guard itself: a bare phrase in each kind of sink is caught, a translated one or a colour code is not.
local caught = BareLiterals(Tokens([[
ns.Print(("Hello %s"):format(name))
GameTooltip_AddInstructionLine(tooltip, Setting("key") and "Click me" or L["Click"])
root:CreateCheckbox(L["Shown"], IsShown, Toggle, "tracker")
block:AddObjective("Extra", "...")
root:CreateTitle("|cff808080" .. L["Nothing"] .. "|r") -- "a comment" is not a literal
local Mixin = { headerText = "Section" }
]]))
check(#caught == 3, "three bare phrases caught, not " .. #caught)
check(caught[1] == "Hello %s" and caught[2] == "Click me" and caught[3] == "Section", "the right three")

local shipped, listed = {}, {}
for line in io.lines("LegacyForever.toc") do
	local file = line:match("^([^#].-%.lua)%s*$")
	if file then
		file = file:gsub("\\", "/")
		listed[file] = true
		if not file:find("^Locales/") then
			shipped[#shipped + 1] = file
		end
	end
end
check(#shipped > 5, "the TOC lists the shipped Lua")
for _, file in ipairs(shipped) do
	local handle = assert(io.open(file))
	local bare = BareLiterals(Tokens(handle:read("*a")))
	handle:close()
	check(#bare == 0, ("%s shows without L[]: %s"):format(file, table.concat(bare, " | ")))
end

local handle = assert(io.open("Locales/phrases.txt"))
local committed = handle:read("*a")
handle:close()
local pipe = assert(io.popen("python3 tools/phrases.py"))
local printed = pipe:read("*a")
pipe:close()
check(printed ~= "", "tools/phrases.py prints the phrases")
check(committed == printed, "Locales/phrases.txt is stale: python3 tools/phrases.py > Locales/phrases.txt")

-- A translation the client never loads is no translation.
local files = assert(io.popen("git ls-files Locales"))
for file in files:lines() do
	check(not file:find("%.lua$") or listed[file], file .. " is not in LegacyForever.toc")
end
files:close()

-- The BigWigs packager's localization keyword fetches from CurseForge, whose localization export is gone: the 404
-- page would fail the release. Built in two parts so this file doesn't match itself.
local keyword = assert(io.popen("git grep -l -F '@" .. "localization' -- ."))
local users = keyword:read("*a")
keyword:close()
check(users == "", "the packager's localization keyword would fail the release: " .. users)

-- The English fallback: a phrase no locale translates reads as itself.
local ns = {}
assert(loadfile("Locales/enUS.lua"))("LegacyForever", ns)
check(ns.L["Stop tracking"] == "Stop tracking", "an untranslated phrase is its English key")

-- The template, copied as it stands, is a working translation file: it fills L only on its own locale.
local locale = "enUS"
local template = assert(loadstring(committed, "Locales/phrases.txt"))
setfenv(template, {
	GetLocale = function()
		return locale
	end,
})
template("LegacyForever", ns)
check(rawget(ns.L, "Stop tracking") == nil, "another locale's file leaves L alone")
locale = "deDE"
template("LegacyForever", ns)
check(rawget(ns.L, "Stop tracking") == "Stop tracking", "the template fills L on its own locale")

-- Every translation the TOC loads fills L only on its own client, with keys the template has. Each line formats
-- with the arguments its English line takes, in the same conversions and order, and keeps every argument: each
-- sample is distinct, so a dropped or swapped one shows. (tools/check_locales.py checks escapes and the rest.)
local english = { L = {} }
local load = assert(loadstring(committed, "Locales/phrases.txt"))
setfenv(load, {
	GetLocale = function()
		return "deDE"
	end,
})
load("LegacyForever", english)
english = english.L
check(english["Stop tracking"] == "Stop tracking", "the template's English loads")

local function Conversions(text)
	local found = {}
	for conversion in text:gsub("%%%%", ""):gmatch("%%[-+#0]*%d*%.?%d*(%a)") do
		found[#found + 1] = conversion
	end
	return found
end
local function Samples(conversions)
	local args, shown = {}, {}
	for n, conversion in ipairs(conversions) do
		if conversion == "s" or conversion == "q" then
			args[n] = "<" .. n .. ">"
			shown[#shown + 1] = args[n]
		elseif conversion:find("[eEfgG]") then
			args[n] = n + 0.5
		else
			args[n] = 40 + n
			shown[#shown + 1] = tostring(args[n])
		end
	end
	return args, shown
end

local translations, expected = 0, 0
local tracked = assert(io.popen("git ls-files Locales"))
for file in tracked:lines() do
	if file:find("^Locales/%a%a%u%u%.lua$") and file ~= "Locales/enUS.lua" then
		expected = expected + 1
	end
end
tracked:close()
for line in io.lines("LegacyForever.toc") do
	local code = line:match("^Locales\\(%a%a%u%u)%.lua%s*$")
	if code and code ~= "enUS" then
		translations = translations + 1
		local chunk = assert(loadfile("Locales/" .. code .. ".lua"))
		local current = "enUS"
		setfenv(chunk, {
			GetLocale = function()
				return current
			end,
		})
		local other = { L = {} }
		chunk("LegacyForever", other)
		check(next(other.L) == nil, code .. " leaves L alone on another client")
		current = code
		local translated = { L = {} }
		chunk("LegacyForever", translated)
		check(next(translated.L) ~= nil, code .. " fills L on its own client")
		for key, text in pairs(translated.L) do
			local source = english[key]
			check(type(source) == "string", ("%s: %q is not in Locales/phrases.txt"):format(code, key))
			check(type(text) == "string" and text ~= "", ("%s: %q is empty"):format(code, key))
			local want, got = Conversions(source), Conversions(text)
			check(
				table.concat(want, " ") == table.concat(got, " "),
				("%s: %q takes %s, not %s"):format(code, key, table.concat(want, " "), table.concat(got, " "))
			)
			local args, shown = Samples(want)
			local ok, result = pcall(string.format, text, unpack(args, 1, #want))
			check(ok and result ~= "", ("%s: %q doesn't format: %s"):format(code, key, tostring(result)))
			for _, sample in ipairs(shown) do
				check(result:find(sample, 1, true), ("%s: %q drops an argument"):format(code, key))
			end
		end
	end
end
check(
	translations == expected and translations > 0,
	("the TOC loads %d of %d translations"):format(translations, expected)
)

print(("locale_spec: %d checks passed"):format(checks))
