#!/usr/bin/env python3
"""Print a translation template: every phrase the shipped Lua translates, as a Locales/<locale>.lua file (stdlib only).

A phrase is the English text in `L["..."]`; the addon uses it as the key and falls back to it. The output is
committed as Locales/phrases.txt for translators to copy, and tests/locale_spec.lua fails when the two disagree.
Translation files themselves (Locales/) are not read, so a phrase the code no longer uses drops out.

    python3 tools/phrases.py > Locales/phrases.txt
"""

import re
from pathlib import Path

try:
    from tools.typecheck_coverage import runtime_files
except ModuleNotFoundError:  # Direct invocation from the tools directory.
    from typecheck_coverage import runtime_files

ROOT = Path(__file__).resolve().parent.parent
PHRASE = re.compile(r'\bL\["((?:\\.|[^"\\])*)"\]')
HEADER = """\
-- A translation template for Legacy Forever. To correct a language that ships, edit its Locales/<locale>.lua instead.
-- For a new one, save a copy as Locales/<locale>.lua, change "deDE" below to that locale, translate the right-hand
-- side of each line and delete the lines you leave in English. Keep %s, %d and |4...; as they are. Then add
-- Locales\\<locale>.lua to LegacyForever.toc, right after Locales\\enUS.lua.
local _, ns = ...
if GetLocale() ~= "deDE" then
\treturn
end
local L = ns.L
"""


def shipped(root=ROOT):
    """The Lua files in the TOC/XML runtime graph, outside Locales/."""
    return (path for path in runtime_files(root) if "Locales" not in path.relative_to(root).parts)


def phrases(root=ROOT):
    found = set()
    for path in shipped(root):
        found.update(PHRASE.findall(path.read_text()))
    return sorted(found)


if __name__ == "__main__":
    print(HEADER)
    for phrase in phrases():
        line = f'L["{phrase}"] = "{phrase}"'
        # StyLua's wrap at 120 columns, so a copy passes `stylua --check` before it is translated.
        print(line if len(line) <= 120 else f'L["{phrase}"] =\n\t"{phrase}"')
