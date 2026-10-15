std = "lua51"
max_line_length = 120
exclude_files = { "tools/.cache/**", ".release/**", ".types/**", "types/**", ".claude/**" }
ignore = { "212/_.*", "212/self" } -- unused args prefixed with _, and self on mixin handlers

globals = { "ForeverTrackerHost",
	"LegacyForeverAreaPinMixin",
	"LegacyForeverMapButtonMixin",
	"LegacyForeverZoneOverlayMixin",
	"LegacyForever",
	"LegacyForeverDB",
	"LegacyForeverPinMixin",
	"LegacyForever_OnAddonCompartmentClick",
	"SLASH_LEGACYFOREVER1",
	"SLASH_LEGACYFOREVER2",
	"SlashCmdList",
}

read_globals = { "CreateFramePoolCollection", "C_XMLUtil", "CreateSettingsButtonInitializer", "Settings",
	"AchievementFrame_SelectAchievement", "AlertFrame", "C_AddOns", "AlertFrame_OnClick", "C_Map", "C_MapExplorationInfo", "C_QuestLog", "C_Reputation", "C_SuperTrack", "C_TaxiMap", "C_Timer", "C_Texture", "C_Traits", "CreateAtlasMarkup",
	"CreateFrame", "CreateFromMixins", "CreateTexturePool", "DEFAULT_CHAT_FRAME", "Enum", "EventRegistry", "EventUtil", "GameTooltip",
	"GameFontNormal", "GameFontNormalSmall", "GameFontNormalTiny", "GameTooltip_AddBlankLineToTooltip", "GameTooltip_AddColoredLine", "GameTooltip_AddDisabledLine", "GetCursorPosition", "GRAY_FONT_COLOR", "GREEN_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "NORMAL_FONT_COLOR", "GameTooltip_AddHighlightLine", "GameTooltip_AddInstructionLine",
	"GameTooltip_AddNormalLine", "GameTooltip_SetTitle", "GetAchievementCategory", "GetAchievementCriteriaInfo", "GetAchievementInfo",
	"GetAchievementNumCriteria", "GetBuildInfo", "GetLocale", "geterrorhandler", "InCombatLockdown", "GetTime", "PlaySound", "SOUNDKIT", "GetCategoryInfo", "GetCategoryList", "GetCategoryNumAchievements", "hooksecurefunc",
	"DUNGEONS", "LegacySystemFrame", "MenuUtil", "OTHER", "QUESTS_LABEL", "RAIDS", "REPUTATION", "Mixin", "OBJECTIVE_DASH_STYLE_HIDE", "ObjectiveTrackerFrame",
	"ObjectiveTrackerManager", "ShortestPathForever", "MapCanvasDataProviderMixin", "MapCanvasPinMixin", "LibQuestieDB", "Questie", "QuestieLoader", "strtrim",
	"C_MajorFactions", "Constants", "GameTooltip_AddErrorLine", "LEGACY_MICRO_BUTTON_LOCKED_TOOLTIP", "RED_FONT_COLOR", "UIErrorsFrame",
	"tContains", "ToggleLegacySystemUI", "UnitClass", "UnitLevel", "debugstack", "UISpecialFrames", "UnitFactionGroup", "UnitGUID", "UnitRace", "UIParent", "UiMapPoint", "WHITE_FONT_COLOR", "WorldMapFrame",
}

files["Data/Legacy.lua"] = { max_line_length = false }
files["tests/"] = { std = "+luajit" }

-- Each spec may write only the client APIs it stubs.
files["tests/live_spec.lua"] = {
	globals = { "UnitGUID", "UnitFactionGroup", "Enum", "C_Map", "C_MapExplorationInfo", "C_TaxiMap", "C_QuestLog", "C_Reputation", "C_Timer", "tContains", "CreateFrame",
		"GetCategoryList", "GetCategoryNumAchievements", "GetAchievementInfo", "GetAchievementNumCriteria", "GetAchievementCriteriaInfo" },
}
files["tests/quests_spec.lua"] = {
	globals = { "LibQuestieDB", "Questie", "QuestieLoader", "UnitClass", "UnitFactionGroup", "UnitRace" },
}
files["tests/map_contents_spec.lua"] = { globals = { "C_Map", "Enum" } }
files["tests/navigate_spec.lua"] = {
	globals = { "C_AddOns", "C_Map", "C_SuperTrack", "UiMapPoint", "ShortestPathForever" },
}
files["tests/whatsnew_spec.lua"] = { globals = { "C_AddOns", "CreateFrame" } }
files["tests/settings_spec.lua"] = { globals = { "Settings", "CreateSettingsButtonInitializer", "strtrim", "C_Map", "WorldMapFrame" } }
files["tests/api_spec.lua"] = {
	globals = {
		"AlertFrame", "C_Map", "C_SuperTrack", "C_Texture", "C_Timer", "CreateAtlasMarkup", "DUNGEONS", "EventUtil", "GetTime", "geterrorhandler",
		"InCombatLockdown", "LibQuestieDB", "QUESTS_LABEL", "RAIDS", "ShortestPathForever", "UiMapPoint", "UnitClass", "UnitFactionGroup", "UnitRace",
		"GameTooltip_AddBlankLineToTooltip", "GameTooltip_AddHighlightLine", "GameTooltip_AddNormalLine", "GRAY_FONT_COLOR", "GREEN_FONT_COLOR",
		"HIGHLIGHT_FONT_COLOR", "NORMAL_FONT_COLOR",
	},
}
files["tests/report_spec.lua"] = {
	globals = { "C_AddOns", "C_Map", "C_Texture", "CreateFrame", "DEFAULT_CHAT_FRAME", "GetBuildInfo", "GetLocale", "GetTime", "geterrorhandler",
		"strtrim", "UIParent", "UISpecialFrames", "UnitClass", "UnitFactionGroup", "UnitLevel", "UnitRace" },
}
files["tests/zone_completion_spec.lua"] = { globals = { "C_Map", "GetTime" } }
read_globals[#read_globals + 1] = "EditModeManagerFrame"
