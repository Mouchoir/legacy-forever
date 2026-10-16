Legacy Forever shows unfinished challenges on the world map and tracks the ones you choose.

![Ashenvale on the world map as two areas are found, the completion corner folding away, then the Legacy menu](https://raw.githubusercontent.com/cjber/legacy-forever/main/docs/screenshots/demo.gif)

Discover an area and its shading lifts as the corner's percentage goes up. Click the corner to fold it away.

![Ashenvale on the world map with undiscovered areas shaded, the zone completion corner and the Legacy menu open](https://raw.githubusercontent.com/cjber/legacy-forever/main/docs/screenshots/map.png)

Half of Ashenvale explored: the shield's number is what's left on this map, and its menu lists it by challenge.

![Kalimdor on the world map with a Legacy badge on each zone that still has dungeon objectives](https://raw.githubusercontent.com/cjber/legacy-forever/main/docs/screenshots/continent.png)

Zoom out and each zone with dungeon objectives left gets a badge.

![The objective tracker with the game's All Objectives header over Ashenvale's completion and the tracked Legacy challenges](https://raw.githubusercontent.com/cjber/legacy-forever/main/docs/screenshots/tracker.png)

Challenges you track sit in the objective tracker under the game's own header, with live progress.

![The Legacy map menu with tick boxes to track challenges, grouped by type](https://raw.githubusercontent.com/cjber/legacy-forever/main/docs/screenshots/menu.png)

Tick a challenge in the menu to track it.

## Features

- **Map button** in the world map's button column: a Legacy shield with a number inside, the unfinished objectives on the map you're viewing. Its menu lists them by challenge, with a tick box to track each one.
- **Tracker**: a Legacy section in the objective tracker lists what you track, with live progress. A zone ticked in the map menu tracks just that zone, such as "0/12 Explore Felwood". Click a challenge to open it in the Legacy panel, or right-click to stop tracking it.
- **Map pins** on dungeon and raid entrances, with the challenge each counts toward and its Legacy points. Click one to travel there with Shortest Path Forever, or the game's own waypoint.
- **Undiscovered areas** are shaded in their real shape on the zone map. Hover one to see which challenge counts it, its points and how many of the zone's areas are left. The map menu turns the shading off.
- **Zone completion**, Guild Wars 2 style: how much of a zone's areas, dungeons, raids and Legacy objectives you've done, as a percentage in the map's corner, a badge on each zone of a continent map and, if you tick it, the tracker. Flight paths, local reputations and, with Questie, quests can be added under "What counts". A finished zone gets a toast and a sound.
- **No fixed location** lists challenges whose remaining work isn't tied to a place, such as levels, skills and ranks.

Progress comes from the game each time, so it always matches the Legacy panel.

## Usage

Open the world map, or click the addon's icon in the addon compartment: the Legacy button sits below the map's own tracking buttons. Tick a challenge in its menu to track it. Every option also lives under Options > AddOns > Legacy Forever.

- `/lf` opens the world map with the Legacy menu showing; `/lf help` lists the commands.
- `/lf report` shows a report to copy into a bug report. For a wrong or missing objective, paste it into a [wrong objective issue](https://github.com/cjber/legacy-forever/issues/new?template=wrong_objective.yml).
- `/lf audit` compares the bundled data with what the game reports.
- `/lf criteria 684` lists what the game reports for one achievement.

It's in English and French. More translations are welcome as a pull request or a [translation issue](https://github.com/cjber/legacy-forever/issues/new?template=translation.yml): [Locales](https://github.com/cjber/legacy-forever/tree/main/Locales) has a template.

Locations are generated from the Forever client's own data and joined by ID (flight paths by the zone in their name); nothing is scraped from a database site.

It only shows what the game already tracks; it doesn't add challenges or change how they count.

<!-- forever-family:start -->

## The Forever addons

Each one works on its own, and they work together when you install more than one.

| Addon | What it does |
|---|---|
| [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) | Plans journeys on foot, by air, by sea and through portals, with directions in the tracker. |
| [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) | Suggests quests for your level and routes you from one to the next. |
| [SkillUp Forever](https://www.curseforge.com/wow/addons/skillup-forever) | Shows skill-up chances, recipe costs and levelling routes in the Professions window. |
| [Legacy Forever](https://www.curseforge.com/wow/addons/legacy-forever) | Shows your unfinished Legacy challenges on the world map and tracks the ones you choose. |
| [Tweaks Forever](https://www.curseforge.com/wow/addons/tweaks-forever) | Adds quest automation, rare alerts and merchant options to the game's settings. |

<!-- forever-family:end -->

With Shortest Path Forever, clicking a dungeon or raid pin plans the trip there. Adventure Guide Forever shows your zone completion in its guide. Tweaks Forever's dungeon entrance icons and unexplored-area tint step aside where Legacy already marks the map.

Tracked challenges share one tracker column with the other addons' tracker sections, above your quests.

Source code: [github.com/cjber/legacy-forever](https://github.com/cjber/legacy-forever). Licence: GPL-3.0-or-later.

Built with AI assistance.
