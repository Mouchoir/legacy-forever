# Changelog

What changed in each release, in the terms someone chasing Legacy points would notice. Dates are UTC.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The entries are prose rather than bare
Added/Fixed lists: what matters about a release is why the map or tracker now shows something different.

Each version's entry is also its release notes on GitHub, CurseForge and Wago. Older entries are kept
verbatim rather than rewritten as the addon moves. API changes other addons' authors need go under an
optional `### For addon authors` subsection after a version's player bullets.

## [Unreleased]

- **Legacy Forever lets go of the quest tracker when it has nothing to show.** To fit the Forever sections above your quests, the addon moves the game's quest tracker. It kept holding it there when no section had anything to show or All Objectives was collapsed, which could leave the tracker mid-screen or over the minimap. Now the tracker goes straight back to where the game, Edit Mode or your UI addon put it, and Legacy Forever moves it again only once a section has something to show. The Forever addons share this tracker code and only the first one loaded runs it, so the fix applies once every Forever addon you use has it.

- **Collapsing All Objectives in combat hides the Forever sections at once.** During a fight they stayed on screen until combat ended. A Forever section that changes in combat now redraws in the space it already has, instead of keeping its old text. The game's quest tracker still isn't moved until combat ends.

## [0.7.0] - 2026-10-15

- **`/lf report` gives you something to paste into a bug report.** It opens a small window with the text already selected: your addon and game versions, your character and where you are, the `/lf audit` lines, your other addons, and any errors Legacy Forever caught this session. Press Ctrl+C and paste it. It fits in one message, and you don't need a /reload or a saved-variables file. The wrong objective form on GitHub asks for it.

- **One error no longer stops the rest of an update.** When a setting, your progress or a zone's completion changes, the map, the tracker and the settings page update in turn. If one of them hits a Lua error, the rest still update. The error still reaches the game's error frame or BugSack, and `/lf report` lists it.

- **No hitch when you open the map or the tracker draws straight after logging in with Quests counted.** The map's corner, its continent badges and the tracker's zone section no longer read every quest in Questie's database in one go on their first draw. Quests show as not known yet for a moment and fill in on the next frame, as the zone completion check at login already did.

- **`/lf audit` lists unknown objectives in the same order each time**, so two audits are easy to compare.

## [0.6.21] - 2026-10-15

- **Data checked against Forever 1.60.1.70374.** The bundled data is unchanged apart from its build pin.

- **Your quests stay below the Forever tracker with EllesmereUI and other UI suites.** When the game, Edit Mode or a UI addon put the quest tracker back in its saved spot, the Forever sections waited for the next quest event to restack, so your quests sat over them until then. The column now follows the quest tracker as soon as it moves, still without touching the game's own tracker code.

## [0.6.20] - 2026-10-13

- **No hitch on login from zone completion news.** Checking which zones you have just completed no longer builds QuestieDB's quest index the moment you enter the world; the check waits for the next frame and runs again once the quests are ready.

- **Tracker lines while the game is still loading a name.** A challenge whose step or name the client has not loaded yet shows what is known, or is left out until it loads, instead of raising a Lua error.

- **A detached tracker with nothing to show leaves the screen.** Its "Forever tracker" title hides with the empty column and comes back, where you left it, as soon as a section has something to show.

## [0.6.19] - 2026-10-13

- **Data checked against Forever 1.60.1.70338.** The bundled data is unchanged apart from its build pin.

- **Tracker stays put when Edit Mode places it by its centre or bottom.** Attaching to the quest tracker no longer pushes it down the screen when it has been moved away from the default top-anchored spot.

## [0.6.18] - 2026-10-09

- **French translation.** Legacy Forever is available in French, contributed by Brainc3ll.

- **How the Forever addons work together.** The README and store page list each of the other Forever addons and what it adds when installed alongside this one.

## [0.6.17] - 2026-10-09

- **Keep Blizzard's tracker methods intact.** The shared Forever tracker responds to objective and player events without wrapping native layout methods.

- **Current completion data.** Legacy uses the latest Forever client data for newly added achievements and map areas.
## [0.6.16] - 2026-10-08

- **Shorter addon descriptions.** The README and store pages explain the features directly and keep the author and licence credits.

- **Quest text stays on screen when the Forever tracker is smaller.** The native quest column and its header keep their full width at the edge of the screen.

- **Shared tracker scaling.** Legacy follows the tracker scale selected in Shortest Path Forever.

## [0.6.15] - 2026-10-07

- **Quest objectives stay below the Forever tracker after reload.** The shared tracker no longer resizes Blizzard's quest container, which could move it over the addon sections.

## [0.6.14] - 2026-10-07

- **Data checked against Forever 1.60.1.70245.** The bundled game data is unchanged.

## [0.6.13] - 2026-10-06

- **Current game data.** Legacy objectives use the latest selected Forever client data, build 1.60.1.70235.

## [0.6.12] - 2026-10-05

- **Updated help text.** The description explains the current tracker controls and how the addon works alongside the other Forever addons.

## [0.6.11] - 2026-10-05

- **The tracker returns after Edit Mode is locked.** Hiding and locking Edit Mode without leaving it no longer keeps the Forever sections hidden.
- **The tracker reads in game order.** The game's All Objectives header leads the shared column, the Forever sections follow it, and your quests stay below them. In combat the game keeps its quest list in its own slot, so the header and quests stay together and the Forever sections sit directly below them, keeping the tracker to one column.
- **Progress updates read less from the game.** Killing something or discovering an area used to re-read every Legacy challenge and every zone's explored overlay; those are kept now, so the tracker and map redraw without the extra work.
- **The data matches the current client build.** Dire Maul and Zul'Farrak are spelled as the game now spells them in a zone's dungeon list, and Coldridge Valley has its pin on the Dun Morogh map.

## [0.6.10] - 2026-10-03

- **A detached tracker keeps clear of your quests.** With Attach to quest tracker off, the Forever column could open on top of the quest list. Until you drag it, it now sits beside the quest tracker, level with its top; once dragged, it stays where you put it.
- **The tracker setting says what it switches.** On the settings page, *In the objective tracker* read as if it hid everything Legacy puts in the tracker, but it only shows or hides the zone you're in. It is now *Zone completion in the tracker*, and its tooltip says the challenges you track keep their own Legacy section.

## [0.6.9] - 2026-10-02

- **The guides stay put in a fight.** In combat the game stretches its quest tracker and nudges it back on screen, which shoved the Forever sections sideways across the screen until the fight ended. They now stay stacked above the quest list.
- **Opening the map no longer breaks it in a fight.** After `/lf`, a zone's tracker header or a completion toast had opened the world map, every later look at the map in combat raised a blocked-action warning and lost its quest markers until a reload. The map now opens cleanly and keeps its markers in combat.
- **Say why the Legacy panel will not open.** Until the game unlocks its Legacy panel, the entries that open it are greyed out and show the game's own reason, in place of a button that did nothing.
- **The map button clears Questie's.** With Questie installed, the Legacy button sat on top of its button in the map's top-right corner. It now takes the next place down.
- **The what's-new setting fits the settings panel.** Its name was cut off with an ellipsis; it now reads *What's new after an update*.

## [0.6.8] - 2026-10-01

- **Keep guides clear of quests in combat.** Companion sections stay clear when the quest list grows during a fight. Detaching restores the quest tracker’s original Edit Mode position.

## [0.6.7] - 2026-09-30

- **Move the shared tracker.** Turn off Attach to quest tracker in Settings to drag all Forever sections together. The position survives `/reload`.

- **Organise the source.** Group runtime modules by responsibility and update the manifest, tests and developer tools without changing client load order or behaviour.

## [0.6.6] - 2026-09-30

- **Development disclosure.** This release was developed with AI assistance. Changes were reviewed and checked with automated tests, linting and type checks; live verification remains ongoing.

- **Find every option on the game's Options page.** Options > AddOns > Legacy Forever groups the map shading, zone completion and its "What counts" list into short pages behind an index, so nothing needs scrolling; the Legacy menu's quick toggles stay where they are.

- **Keep tracker sections apart in combat.** Companion sections move above the protected quest tracker while fighting, then return to one column afterward, regardless of which addon loads first.

## [0.6.5] - 2026-09-29

- **Keep one tracker column.** Addon sections stack above the quest tracker regardless of which companion addon loads first, while keeping their frame pools separate from Blizzard's tracker.

## [0.6.4] - 2026-09-28

- **Map pins wait for combat to end.** Refreshing Legacy pins during combat no longer touches the protected map pin manager; stale pins hide and rebuild safely after combat.

## [0.6.3] - 2026-09-28

- **Separate addon tracking from Blizzard’s layout.** Addon sections now use their own frame pools and sit beside the quest tracker, avoiding the shared tracker registration implicated in Edit Mode aura errors.
- **Check the client integration in CI.** Regression checks run against pinned Forever tracker source and reject native tracker registration.

## [0.6.2] - 2026-09-27

- **Tracker and map overlays avoid shared UI hooks.** Tracker registration waits for the game to finish loading, and area textures manage their own masks.

## [0.6.1] - 2026-09-27

- **`/lf` opens the world map with the Legacy menu showing**, where every option lives, and so does the addon compartment entry. `/lf help` lists the other commands.
- **A new icon in the addon list and the compartment**: a gold trophy on the same frame as the other WoW: Forever addons, in place of the folded map.

## [0.6.0] - 2026-09-25

- **Ready for translation.** Every menu, tooltip and chat message the addon writes, apart from `/lf audit`, can now be translated, one file per language in the addon's `Locales` folder; translations are welcome on GitHub. Zone, achievement and objective names already came from the game in your language. Until a translation arrives, the rest reads in English as before.
- **A pin's tooltip suggests Shortest Path Forever when you don't have it.** Under "Click to set a waypoint here." a grey line says installing it (or enabling it, if it is switched off in the addon list) would plot the whole route for you. Once it is loaded the line goes. Untick "Suggest companion addons" in the Legacy menu to hide it.
- **One chat line after an update** says which version you now have and the main change. It stays quiet on a first install; untick "Tell me what's new after an update" in the Legacy menu to turn it off.

## [0.5.0] - 2026-09-25

- **Legacy tooltips go when the world map closes.** Closing the map while hovering an undiscovered area, a Legacy pin, the Legacy button or the zone completion corner used to leave its tooltip on screen, and an area could stay shaded as if still hovered. Each now clears when the map hides.
- **Other addons can read Legacy Forever.** `LegacyForever.API` gives a zone's completion as you count it, its unfinished Legacy objectives, and a way to send you to one with Shortest Path Forever or the game's waypoint; [docs/api.md](docs/api.md) has the details.

## [0.4.1] - 2026-09-25

- **Coldridge Valley has its new name.** Forever renamed the Dun Morogh area Anvilmar to Coldridge Valley, and the map and tracker now use the new name when it is left to explore.
- **Updated for Forever build 1.60.1.70009.** Nothing else moved.

## [0.4.0] - 2026-09-25

- **Left-click a Legacy pin to travel there.** With Shortest Path Forever installed and its journeys switched on, the click starts a journey to the pin, flights and boats included. Without it, or in combat, the click sets the game's own map waypoint instead. The pin's tooltip now ends with the click hint. Zone badges on continent maps still open the zone.
- **Legacy Here is now Legacy Forever**, matching the other WoW: Forever addons. The addon folder is `LegacyForever`, the slash command is `/lf`, and settings start fresh under the new name.
- **Dungeon and raid entrances keep their portal.** A Legacy step at an entrance used to replace the map's dungeon or raid icon with the Legacy shield. It now shows the portal with a small shield on its corner, so you can still see the entrance.
- **The zone section in the objective tracker names what is left**, not just the counts. Under "Darkshore 77%" you now see the unexplored areas, missing dungeons and remaining Legacy steps by name, each with its icon, five at most with "..." after; the map tooltip still lists them all.
- **The map button's count sits inside its Legacy shield**, in the game's gold lettering, and the shield is a little bigger so the number reads at a glance. Three-digit counts use a smaller size so they stay inside the shield.
- **Ticking a zone's objective in the map menu tracks just that zone**, not the whole challenge. Ticking "Explore Felwood" adds Explorer to the tracker with one line under it, "0/12 Explore Felwood", counting up as you discover its areas; tick more zones and each gets its own line under the same challenge. A dungeon ticked from its zone's map shows that dungeon under its Spelunker challenge in the same way. Unticking a zone removes its line, and the challenge goes once nothing under it is tracked. Challenges ticked under "No fixed location", and anything you tracked before this version, still show every unfinished step.
- **Zone completion counts only Legacy objectives out of the box**: areas explored, dungeons, raids and the zone's other Legacy objectives. Flight paths and local reputations at Friendly aren't part of any Legacy challenge, so they are now off until you tick them under "What counts"; if you already ticked or unticked either one, your choice stays. The toast for a zone reaching 100% now follows "What counts" as the percentage does, so the 100% you see is the one that earns it, and changing what counts never sets one off.
- **Unticking "On the world map" under Zone completion now also hides the zone badges on continent maps**, straight away, and ticking it brings them back. Pins on a zone's own map, such as dungeon entrances, stay.
- **Zone badges on continent maps are just the Legacy icon now**, with no number beside it, so the continent stays readable. Hover a badge for the count: its tooltip opens with how many Legacy objectives the zone has left, such as "3 Legacy objectives left", then the share of each challenge as before.
- **Zone completion can count quests, with Questie installed.** Tick "Quests" under "What counts" and each zone counts the quests your character can take there, read from Questie's database, and lists the ones still to do when you hover. Repeatable, holiday, profession and dungeon quests are left out. It is off by default, and greyed out without Questie.

## [0.3.0] - 2026-09-23

- **Right-click a zone in the completion tracker for a menu**: open the map or hide the section, as on the Legacy section. A left click still opens the map.
- **The collapsed zone box on the world map is only as wide as what it shows.** It used to keep the width of the counts it hides.
- **No more "couldn't add a section to the objective tracker" warning after a slow login.** The section attached a moment later anyway; the check now waits until the game has built the tracker.
- **A new icon in the addon list**, drawn to match the other WoW: Forever addons, so it is easy to spot beside them.

## [0.2.0] - 2026-09-21

- **Each zone shows how much of it you've done**, Guild Wars 2 style, as areas explored, flight paths learned, dungeons cleared for Legacy, the zone's other Legacy objectives and its local reputations at Friendly, with the rest listed on hover. It sits in the world map's corner for the zone you're viewing, and on continent maps it is in each zone badge's tooltip. Tick it in the map menu to also add the zone you're in to the objective tracker. Each collapses to just the zone and its percentage, and the map menu turns either off. "What counts" in the map menu drops any category from the count and the percentage. Flight paths count once you've opened a flight master on that continent, since that is the only place the game says which ones you know; until then they show as "?" with a note to visit one.
- **Raids count toward zone completion**, once every boss is down, on any character. Onyxia's Lair counts in Dustwallow Marsh.
- **A zone reaching 100% gets a toast and a sound**, in the game's own achievement style, with your continent's progress in chat. Click the toast to open that zone's map. Zones already complete when you log in stay quiet, and every category counts toward the toast whatever "What counts" shows.
- **Continent progress** sits under each zone badge's summary on continent maps, as in "Kalimdor: 3 of 20 zones complete (15%)".
- **The map menu shows each challenge with its map icon**: the Legacy icon for objectives pinned on the map, the compass for exploration, which the map shades rather than pins.
- **Undiscovered areas are shaded instead of pinned.** Each area you haven't found is now shaded darker, in the area's own shape, the way unseen ground reads on a map, rather than having a Legacy icon dropped in its middle. Areas are big, and the shading shows where they start and end. It's on by default; "Show undiscovered areas" in the map menu turns it off. Exploration is never pinned now, and continent badges count only objectives with a place, such as bosses and dungeons. Map pin icons are a little larger.
- **More dungeon objectives have a place.** 56 objectives that sat under "No fixed location" are now pinned at their dungeon's entrance, including Lord Valthalak Laid to Rest at Upper Blackrock Spire. The Novice Spelunker step "Ragefire Chasm or Hall of Thanes" is now pinned at Ragefire Chasm in Orgrimmar. Hall of Thanes, the Hyjal Summit and Barrow Deeps raid bosses, and Forever's other new dungeons stay under "No fixed location": the client data doesn't give their entrances yet, and no addon or database has them either.
- **Counts on the map read more cleanly**, in the game's regular small font with a soft shadow instead of the heavy outlined numbers.
- **`/lh audit`** now also checks the zone you're in against what the game reports for areas and flight paths, and runs even when no Legacy challenges are listed yet.

## [0.1.0] - 2026-09-21

First release.

- **A Legacy button on the world map counts what is left.** It shows the unfinished Legacy objectives on the map you're viewing.
- **Pins mark 493 undiscovered areas and dungeon entrances.** Area pins show how much of the zone is left and are off until turned on in the map menu.
- **Challenges with no fixed location are listed separately**, since there is nowhere on the map to pin them.
- **Tick a challenge in the map menu to track it.** It goes in a Legacy section of the objective tracker, with each unfinished step and its live progress.
- **`/lh audit` checks the bundled data against the game.** The data is from Forever build 1.60.1.69913.
