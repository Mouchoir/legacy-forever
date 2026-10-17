# Third-party inputs

Everything Legacy Forever is built from that it did not write itself: where each comes from, where its pin lives, its
licence, and whether any of it reaches the zip players install. A pin is named by the constant that holds it, so a data
refresh that moves the pin never leaves this file behind. The addon itself is GPL-3.0-or-later ([LICENSE](LICENSE)).

## Ships in the zip

| Input | Used for | Pin | Licence |
|---|---|---|---|
| WoW: Forever client tables, via [wago.tools](https://wago.tools) | Achievements, criteria, zones and instances in `Data/Legacy.lua` | `BUILD` in `tools/gen_legacy.py` | Blizzard Entertainment's game data |
| `tools/locations.json` | Reviewed facts the client data cannot give (where a criterion happens), each with its evidence | Committed; `tools/locations.py` checks it against the pinned rows | This addon's own |

No embedded libraries ship. `media/` is this addon's own: the icon is drawn in `media/icon.svg`, and `Shade.tga`
is a plain black alpha gradient. `Locales/frFR.lua` is the French translation Brainc3ll wrote (#99), since extended with
machine-translated lines (marked `-- mt`) for new strings, under this addon's licence.

## Read in game, never bundled

| Input | Used for | Licence |
|---|---|---|
| Questie and QuestieDB, if installed | A zone's quests for the Quests category | QuestieDB carries no licence; nothing is copied |
| Shortest Path Forever, if installed | Routes to a zone or objective, through its public API | GPL-3.0-or-later |

## Build and test only

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [Blizzard UI source](https://github.com/Gethe/wow-ui-source) | The native tracker integration spec, fetched into `tools/.cache/` | `REVISION` in `tools/fetch_tracker_ui.py` | Blizzard Entertainment's; fetched, never committed |
| [Ketho's WoW API annotations](https://github.com/Ketho/vscode-wow-api) | lua-language-server types in `tools/typecheck.sh` | `revision` in `tools/typecheck.sh` | MIT |
| [FrameXML annotations](https://github.com/NumyAddon/FramexmlAnnotations) | FrameXML types, the Ketho checkout's `Annotations/FrameXML` submodule | The gitlink in that Ketho revision | MIT |
| [forever_tools](https://github.com/cjber/skills/tree/main/wow-forever-addon/tooling/forever_tools) | Shared lints, release checks and the generated-data gate, vendored in `tools/forever_tools/` | `revision` in `tools/forever_tools/MANIFEST.json` | MIT |
| [wow-mock-screenshots](https://github.com/cjber/skills/tree/main/wow-mock-screenshots) and the client art it fetches | `tools/screenshots.py` | `WOWMOCK` (a local checkout); the art at `BUILD` in `tools/gen_legacy.py` | MIT; the art is Blizzard Entertainment's, fetched at build time and committed only as it appears in `docs/screenshots/` |
| sift gate | `.sift/gate.py` and `.sift/agents.py` in CI | Vendored by `sift setup` | MIT (`.sift/LICENSE`) |

CI tools (StyLua, ruff, luacheck, lua-language-server, actionlint, zizmor, gitleaks, the BigWigs packager) are pinned in `.github/workflows/` and `tools/typecheck.sh`, except luajit and luacheck, which come from the runner's apt; they build and check the addon and are never part of it.

## Ideas and contributors

Credit for the ideas, translations and reports behind the addon.

| Who | What | Notes |
|---|---|---|
| [Polestar](https://github.com/fitzforge/polestar) by Fitz | From cjber/adventure-guide-forever's issues: `/lf report` with its copy box and caught errors (#156), the issue forms (#157), the zip check (#158), `tools/doctor.py` (#160), the stale-screenshot check (#161), this file (#162), the "For addon authors" changelog subsection (#163) and `.editorconfig` (#165). | GPL-3.0. Inspired only; no code was copied. Fitz is welcome to use our code. |
| Brainc3ll | The French translation (#99) | |
| Bigabyte | Found the quest tracker shifting when moved in Edit Mode (#103) | |
| overspark | Asked on CurseForge for a way to hide the dungeon and raid entrance pins, which became *Show dungeon and raid entrances* (#139) | |
| deathmvp1 and berserkerlxl, on CurseForge | Found Questie's quest list covering the Forever tracker sections, which now move clear of it (cjber/shortest-path-forever#214) | |

Thanks also to everyone else who reported a bug, here or on CurseForge.
