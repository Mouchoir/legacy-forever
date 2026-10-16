---@meta

-- The TOC supplies one shared namespace to every chunk; none of these declarations run in game.
---@alias LegacySet table<number, boolean>
---@alias LegacyCategoryKey 'areas'|'taxis'|'dungeons'|'raids'|'legacy'|'reputations'|'quests'
---@alias LegacySurface 'map'|'tracker'
---@alias LegacyRefs number[][]
---@alias LegacyCriteria table<number, LegacyProgress>
---@alias LegacyCriteriaReader fun(achievementID: number): LegacyCriteria?
---@alias LegacyTrackingKey number|string

---@class LegacyData
---@field build string
---@field rewards LegacySet
---@field feeds table<number, number[]>
---@field zones table<number, LegacyEntry[]>
---@field completion table<number, LegacyZone>

---@class LegacyEntry
---@field achievement number
---@field criteria number
---@field kind 'explore'|'instance'|'kill'|'quest'|'reputation'
---@field key? string
---@field x? number
---@field y? number
---@field instance? number
---@field raid? boolean

---@class LegacyProgress
---@field text string
---@field completed boolean
---@field index number
---@field type? number
---@field asset? number
---@field quantity? number
---@field required? number

---@class LegacyObjective
---@field entry LegacyEntry
---@field text string

---@class LegacyGroup
---@field achievement number
---@field challenge number
---@field uiMapID number
---@field objectives LegacyObjective[]

---@class LegacyUnlocated
---@field challenge number
---@field open number

---@class LegacyTrackerLine
---@field text? string the step or challenge name; nil while the client has not loaded it
---@field detail? string
---@field seen string

---@class LegacyTrackedBlock
---@field challenge number
---@field lines LegacyTrackerLine[]
---@field seen table<string, boolean>
---@field whole? boolean

---@class LegacyArea
---@field name string
---@field key string
---@field hit? number[]
---@field tiles? number[]

---@class LegacyTaxi
---@field name string
---@field node number
---@field faction string

---@class LegacyReferencedObjective
---@field name string
---@field refs LegacyRefs

---@class LegacyRaid
---@field name string
---@field bosses LegacyReferencedObjective[]

---@class LegacyReputation
---@field name string
---@field faction number
---@field side? string

-- One of a zone's quests: a quest, or mutually exclusive ones counted once. `ids` also holds the
-- quests that close it, so it is done once any of them is turned in.
---@class LegacyQuestItem
---@field name string
---@field ids number[]
---@field uiMapID number

-- QuestieDB's quest data for this character, with Questie's blacklist when it is loaded.
---@class LegacyQuestSource
---@field ids number[]
---@field get fun(questID: number, key: string): any
---@field hidden fun(questID: number): boolean
---@field zone fun(areaID: number): number?
---@field race fun(mask: number): boolean
---@field class fun(mask: number): boolean

---@class LegacyZone
---@field areas LegacyArea[]
---@field taxis LegacyTaxi[]
---@field dungeons LegacyReferencedObjective[]
---@field raids LegacyRaid[]
---@field legacy LegacyReferencedObjective[]
---@field reputations LegacyReputation[]
---@field tileWidth? number
---@field tileHeight? number

---@class LegacySnapshot
---@field explored table<string, boolean>
---@field taxis table<number, boolean>
---@field faction string
---@field criteria LegacyCriteriaReader
---@field reaction fun(factionID: number): number
---@field quests? fun(): LegacyQuestItem[]|false|nil
---@field completed? LegacySet

---@class LegacyCategory
---@field done number
---@field total number
---@field pending number
---@field left string[]
---@field complete boolean

---@class LegacyZoneResult
---@field areas? LegacyCategory
---@field taxis? LegacyCategory
---@field dungeons? LegacyCategory
---@field raids? LegacyCategory
---@field legacy? LegacyCategory
---@field reputations? LegacyCategory
---@field quests? LegacyCategory
---@field done number
---@field total number
---@field pending number
---@field complete boolean
---@field percent? number

---@class LegacyContinentResult
---@field complete number
---@field zones number
---@field percent number

---@class LegacyFlightRecord
---@field known LegacySet
---@field continents LegacySet

---@alias LegacySettings table<string, boolean>

---@class LegacyDefaults
---@field showAreas boolean
---@field whatsNew boolean
---@field suggestFamily boolean
---@field zoneCompletion LegacySettings

---@class LegacySavedVariables : ForeverFamilyDB
---@field trackerHost? ForeverTrackerSettings
---@field tracked? LegacyTrackingKey[]
---@field zoneCompletion? LegacySettings
---@field flightPaths? table<string, LegacyFlightRecord>
---@field showAreas? boolean
---@field whatsNew? boolean
---@field suggestFamily? boolean
---@field companions? boolean Before 0.8; Saved migrates it to suggestFamily.
---@field lastVersion? string

---@type LegacySavedVariables?
LegacyForeverDB = nil

-- The addon's one public global, set by API.lua.
---@class LegacyForeverGlobal
---@field API LFAPI

---@type LegacyForeverGlobal
LegacyForever = nil

---@class ForeverTrackerHostAPI
---@field GetSettings fun(): ForeverTrackerSettings
---@field GetScale fun(): number
---@field SetScale fun(scale: number)
---@field IsAttachedToQuestTracker fun(): boolean
---@field SetAttached fun(attached: boolean)
---@field OnAttachmentChanged fun(callback: fun(attached: boolean))
---@field SavePosition fun(x: number, y: number)
---@field Attach fun(module: Frame)
---@field IsAttached fun(module: Frame?): boolean
---@type ForeverTrackerHostAPI?
ForeverTrackerHost = nil

---@class LegacyContinentZone
---@field uiMapID number
---@field name string
---@field groups LegacyGroup[]
---@field count number
---@field x number
---@field y number

---@class LegacyMenuGroup
---@field name string
---@field items LegacyUnlocated[]
---@field subs LegacyMenuGroup[]
---@field subsByName table<string, LegacyMenuGroup>

---@class LegacyAreaObjective
---@field group LegacyGroup
---@field objective LegacyObjective

-- Completion adds these fields to its tracker header before layout runs.
---@class LegacyTrackerHeader : ObjectiveTrackerModuleHeaderTemplate
---@field Percent FontString
---@field Progress StatusBar

-- The tracker template supplies a frame and the manager assigns its numeric block ID.
---@class LegacyTrackerBlock : Frame, ObjectiveTrackerBlockMixin
---@field id number

---@class LegacyToast : Frame
---@field uiMapID number
---@field Unlocked FontString
---@field Name FontString
---@field Icon { Texture: Texture }

-- The pool proxy's generic object return is specialized to this pin's texture pool.
---@class LegacyTexturePool
---@field Acquire fun(self: LegacyTexturePool): Texture, boolean
---@field ReleaseAll fun(self: LegacyTexturePool)

---@class ForeverTrackerSettings
---@field attached boolean
---@field scale? number tracker size, 1 is the stock size
---@field x? number
---@field y? number

---@class ForeverTrackerNamespace
---@field TrackerHost? ForeverTrackerHostAPI
---@field TrackerHostSettings? fun(): ForeverTrackerSettings
---@field L table<string, string>
