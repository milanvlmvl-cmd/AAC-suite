-- GLOBALS
-- These are all provided in the environment you'll be using.
ADDON = {
    -- Use this to get any of the windows defined in UIC below!
    -- GetContent(UIC)
    GetContent = {},
    -- RegisterContentWidget(UIC, widget)
    RegisterContentWidget = {},
    -- ShowContent(UIC, show (boolean))
    ShowContent = {},
    -- RegisterContentTriggerFunc(UIC, ToggleFunction)
    -- Calls ToggleFunction with true/false when ShowContent is called.
    RegisterContentTriggerFunc = {}
}
UIC = {
    DEV_WINDOW = 0,
    ABILITY_CHANGE = 0,
    CHARACTER_INFO = 0,
    AUTH_MSG_WND = 0,
    BUBBLE_ACTION_BAR = 0,
    BAG = 0,
    DEATH_AND_RESURRECTION_WND = 0,
    OPTION_FRAME = 0,
    SYSTEM_CONFIG_FRAME = 0,
    GAME_EXIT_FRAME = 0,
    SLAVE_EQUIPMENT = 0,
    PLAYER_UNITFRAME = 0,
    TARGET_UNITFRAME = 0,
    RAID_COMMAND_MESSAGE = 0,
    COMBAT_TEXT_FRAME = 0,
    TARGET_OF_TARGET_FRAME = 0,
    WATCH_TARGET_FRAME = 0,
    RAID_MANAGER = 0,
    COMMUNITY_WINDOW = 0,
        ENCHANT_WINDOW = 0,
        ADVENTURE_GUIDE = 0,
        RESIDENT_GLOBAL_TRADE = 0
  }
BUTTON_BASIC = BUTTON_BASIC
CURSOR_PATH = CURSOR_PATH
FONT_COLOR = FONT_COLOR
FONT_SIZE = FONT_SIZE
TEXTURE_PATH = TEXTURE_PATH
F_SLOT = F_SLOT
SLOT_STYLE = {
  DEFAULT = {},
  BAG_DEFAULT = {},
  SOCKET = {},
  BAG_NOT_ALL_TAB = {},
  BUFF = {},
  EQUIP_ITEM = {},
  PET_ITEM = {},
  SLAVE_EQUIP = {
    FIGUREHEAD = {},
    STAY_SAIL = {},
    SQUARE_SAIL = {},
    FRONT_MAST = {},
    REAR_MAST = {},
    CANNON = {},
    BACKPACK = {},
    BOARD = {},
    HANDLE = {},
    RUDDER = {},
    LAMP = {},
    BELL = {},
    ORGAN = {},
    CARRIED_HARPOON = {},
    HARPOON = {},
    TELESCOPE = {},
    SCUBA = {},
    ENGINE = {},
    DECORATION = {},
    WATERWHEEL = {}
  }
}
COMBAT_TEXT_COLOR = {}
ConvertColor = {}
ApplyTextColor = {}
ApplyButtonSkin = {}
X2Util = {
    GetMyMoneyString = {},
    -- Takes x,y,z and returns screenX, screenY and distance
    -- Negative distance means the coordinate is off screen
    ConvertWorldToScreen = {}
}
CreateItemIconButton = {}
combatTextLocale = {}
ParseCombatMessage = {}
GetTextureInfo = {}
ALIGN = {
  LEFT = 0,
  RIGHT = 0,
  CENTER = 0,
  TOP = 0,
  BOTTOM = 0,
  BOTTOM_RIGHT = 0,
  BOTTOM_LEFT = 0,
  TOP_LEFT = 0,
  TOP_RIGHT = 0
}
W_MONEY = {
    -- CreateMoneyEditsWindow(id, parent, titleText)
    CreateMoneyEditsWindow = {},
    -- CreateTwoLineMoneyWindow(id, parent)
    CreateTwoLineMoneyWindow = {},
    -- CreateDefaultMoneyWindow(id, parent, width, height)
    CreateDefaultMoneyWindow = {},
    -- CreateTitleMoneyWindow(id, parent, titleText, direction, layoutType)
    CreateTitleMoneyWindow = {},
}
W_CTRL = {
    -- CreateComboBox(parent)
    CreateComboBox = {},
    -- CreateEdit(id, parent)
    CreateEdit = {},
    -- CreditMultiLineEdit(id, parent)
    CreditMultiLineEdit = {},
    -- CreateLabel(id, parent)
    CreateLabel = {},
    -- CreateList(id, parent) 
    CreateList = {},
    -- CreateListCtrl(id, parent)
    CreateListCtrl = {},
    -- CreatePageControl(id, parent, style)
    CreatePageControl = {},
    -- CreatePageScrollListCtrl(id, parent)
    CreatePageScrollListCtrl = {},
    -- CreateScroll(id, parent)
    CreateScroll = {},
    -- CreateScrollListBox(id, parent, bgType)
    CreateScrollListBox = {},
    -- CreateScrollListCtrl(id, parent, index)
    CreateScrollListCtrl = {},
}
W_UNIT = {
    -- CreateBuffWindow(id, parent, maxCount, isBuff, isRaidMember)
    CreateBuffWindow = {},
    -- CreateLevelLabel(id, parent, useLevelTexture)
    CreateLevelLabel = {},
}
W_BAR = {
    --CreateCastingBar(id, parent, unit)
    CreateCastingBar = {},
    --CreateDoubleGauge(id, parent)
    CreateDoubleGauge = {},
    --CreateExpBar(id, parent)
    CreateExpBar = {},
    --CreateLaborPowerBar(id, parent)
    CreateLaborPowerBar = {},
    --CreateHpBar(id, parent)
    CreateHpBar = {},
    --CreateSkillBar(id, parent)
    CreateSkillBar = {},
    --CreateStatusBarOfUnitFrame(id, parent, barType)
    CreateStatusBarOfUnitFrame = {},
    --CreateStatusBarOfRaidFrame(id, parent, barType)
    CreateStatusBarOfRaidFrame = {},
    --CreateStatusBar(id, parent, style)
    CreateStatusBar = {},
}
W_ICON = {
    -- CreateDestroyIcon(widget, layer)
    CreateDestroyIcon = {},
    -- CreatePackIcon(widget, layer)
    CreatePackIcon = {},
    -- CreateLifeTimeIcon(widget, layer)
    CreateLifeTimeIcon = {},
    -- CreateLookIcon(widget, layer)
    CreateLookIcon = {},
    -- CreateLockIcon(widget, layer)
    CreateLockIcon = {},
    -- CreateDyeingIcon(widget, layer)
    CreateDyeingIcon = {},
    -- CreateStack(widget)
    CreateStack = {},
    -- CreateLimitLevel(widget)
    CreateLimitLevel = {},
    -- CreateOverlayStateImg(widget, layer)
    CreateOverlayStateImg = {},
    -- CreateOpenPaperItemIcon(widget, layer)
    CreateOpenPaperItemIcon = {},
    -- CreatePartyIconWidget(widget)
    CreatePartyIconWidget = {},
    -- CreateLootIconWidget(widget)
    CreateLootIconWidget = {},
    -- CreateGuideIconWidget(widget)
    CreateGuideIconWidget = {},
    -- CreateItemIconImage(id, parent)
    CreateItemIconImage = {},
    -- CreateAchievementGradeIcon(widget)
    CreateAchievementGradeIcon = {},
    -- CreateQuestGradeMarker(parent)
    CreateQuestGradeMarker = {},
    -- DrawRoundDingbat(widget)
    DrawRoundDingbat = {},
    -- DrawMoneyIcon(parent, arg)
    DrawMoneyIcon = {},
    -- DrawSkillFlameIcon(widget, layer)
    DrawSkillFlameIcon = {},
    -- DrawItemSideEffectBackground(widget)
    DrawItemSideEffectBackground = {},
    -- CreateArrowIcon(widget, layer)
    CreateArrowIcon = {},
    -- DrawMinusDingbat(money_window_widget)
    DrawMinusDingbat = {},
    -- CreateLeaderMark(id, parent)
    CreateLeaderMark = {}
}
EQUIP_SLOT = {
    HEAD = 0,
    NECK = 0,
    CHEST = 0,
    WAIST = 0,
    LEGS = 0,
    HANDS = 0,
    FEET = 0,
    ARMS = 0,
    BACK = 0,
    EAR_1 = 0,
    EAR_2 = 0,
    FINGER_1 = 0,
    FINGER_2 = 0,
    UNDERSHIRT = 0,
    UNDERPANTS = 0,
    MAINHAND = 0,
    OFFHAND = 0,
    RANGED = 0,
    MUSICAL = 0,
    BACKPACK = 0,
    COSPLAY = 0,
}
CHAT_MESSAGE_FILTERS = {
    CHANNEL_INFO = 0,
    WHISPER = 0,
    SYSTEM = 0,
    NOTICE = 0,
    SAY = 0,
    PARTY = 0,
    RAID = 0,
    RAID_COMMAND = 0,
    EXPEDITION = 0,
    FAMILY = 0,
    FACTION = 0,
    ZONE = 0,
    TRADE = 0,
    FIND_PARTY = 0,
    TRIAL = 0,
    RACE = 0,
    MSG_QUEST = 0,
    ETC_GROUP = 0,
    LOOT_METHOD_CHANGED = 0,
    ADDED_ITEM_SELF = 0,
    ADDED_ITEM_TEAM = 0,
    SELF_SKILL_INFO = 0,
    SELF_STATUS_INFO = 0,
    SELF_MONEY_CHANGED = 0,
    SELF_HONOR_POINT_CHANGED = 0,
    SELF_LIVING_POINT_CHANGED = 0,
    SELF_CONTRIBUTION_POINT_CHANGED = 0,
    SELF_LEADERSHIP_POINT_CHANGED = 0,
    TRADE_STORE_MSG = 0,
    HERO_SEASON_UPDATED = 0,
    WEB_CAST_INFO = 0,
    DOMINION_AND_SIEGE_INFO = 0,
    COMMUNITY = 0,
    BLOCK_INFO = 0,
    FRIEND_INFO = 0,
    FAMILY_INFO = 0,
    COMBAT_MELEE_DAMAGE = 0,
    COMBAT_MELEE_MISSED = 0,
    COMBAT_SPELL_DAMAGE = 0,
    COMBAT_SPELL_MISSED = 0,
    COMBAT_SPELL_HEALED = 0,
    COMBAT_SPELL_ENERGIZE = 0,
    COMBAT_SPELL_CAST = 0,
    COMBAT_SPELL_AURA = 0,
    COMBAT_ENVIRONMENTAL_DMANAGE = 0,
    COMBAT_SRC_GROUP = 0,
    COMBAT_DST_GROUP = 0
}
UI_EVENTS = {
    CHAT_MESSAGE = "CHAT_MESSAGE",
    LOOT_DICE = "LOOT_DICE",
    LOOTING_RULE_METHOD_CHANGED = "LOOTING_RULE_METHOD_CHANGED",
    LOOTING_RULE_MASTER_CHANGED = "LOOTING_RULE_MASTER_CHANGED",
    LOOTING_RULE_GRADE_CHANGED = "LOOTING_RULE_GRADE_CHANGED",
    APPELLATION_GAINED = "APPELLATION_GAINED",
    LOOTING_RULE_BOP_CHANGED = "LOOTING_RULE_BOP_CHANGED",
    TOGGLE_WALK = "TOGGLE_WALK",
    TOGGLE_FOLLOW = "TOGGLE_FOLLOW",
    CHAT_JOINED_CHANNEL = "CHAT_JOINED_CHANNEL",
    CHAT_LEAVED_CHANNEL = "CHAT_LEAVED_CHANNEL",
    NOTICE_MESSAGE = "NOTICE_MESSAGE",
    CHAT_FAILED = "CHAT_FAILED",
    REQUIRE_ITEM_TO_CHAT = "REQUIRE_ITEM_TO_CHAT",
    REQUIRE_DELAY_TO_CHAT = "REQUIRE_DELAY_TO_CHAT",
    CHAT_MSG_QUEST = "CHAT_MSG_QUEST",
    CHAT_MSG_DOODAD = "CHAT_MSG_DOODAD",
    EXPIRED_ITEM = "EXPIRED_ITEM",
    ADDED_ITEM = "ADDED_ITEM",
    REMOVED_ITEM = "REMOVED_ITEM",
    CRAFT_FAILED = "CRAFT_FAILED",
    GLIDER_MOVED_INTO_BAG = "GLIDER_MOVED_INTO_BAG",
    ITEM_ACQUISITION_BY_LOOT = "ITEM_ACQUISITION_BY_LOOT",
    MONEY_ACQUISITION_BY_LOOT = "MONEY_ACQUISITION_BY_LOOT",
    SKILL_LEARNED = "SKILL_LEARNED",
    MATE_SKILL_LEARNED = "MATE_SKILL_LEARNED",
    SKILL_CHANGED = "SKILL_CHANGED",
    SKILLS_RESET = "SKILLS_RESET",
    ABILITY_CHANGED = "ABILITY_CHANGED",
    PREMIUM_LABORPOWER_CHANGED = "PREMIUM_LABORPOWER_CHANGED",
    LABORPOWER_CHANGED = "LABORPOWER_CHANGED",
    ACTABILITY_EXPERT_CHANGED = "ACTABILITY_EXPERT_CHANGED",
    ACTABILITY_EXPERT_GRADE_CHANGED = "ACTABILITY_EXPERT_GRADE_CHANGED",
    DOODAD_PHASE_MSG = "DOODAD_PHASE_MSG",
    HOUSE_FARM_MSG = "HOUSE_FARM_MSG",
    UCC_IMPRINT_SUCCEEDED = "UCC_IMPRINT_SUCCEEDED",
    BUILD_AREA_MSG = "BUILD_AREA_MSG",
    PLAYER_MONEY = "PLAYER_MONEY",
    PLAYER_HONOR_POINT = "PLAYER_HONOR_POINT",
    PLAYER_LIVING_POINT = "PLAYER_LIVING_POINT",
    PLAYER_CONTRIBUTION_POINT = "PLAYER_CONTRIBUTION_POINT",
    PLAYER_LEADERSHIP_POINT = "PLAYER_LEADERSHIP_POINT",
    PLAYER_AA_POINT = "PLAYER_AA_POINT",
    GRADE_ENCHANT_RESULT = "GRADE_ENCHANT_RESULT",
    ITEM_SOCKETING_RESULT = "ITEM_SOCKETING_RESULT",
    ITEM_ENCHANT_MAGICAL_RESULT = "ITEM_ENCHANT_MAGICAL_RESULT",
    ITEM_SMELTING_RESULT = "ITEM_SMELTING_RESULT",
    GRADE_ENCHANT_BROADCAST = "GRADE_ENCHANT_BROADCAST",
    NOTIFY_WEB_TRANSFER_STATE = "NOTIFY_WEB_TRANSFER_STATE",
    DOMINION = "DOMINION",
    COMMUNITY_ERROR = "COMMUNITY_ERROR",
    BLOCKED_USER_LIST = "BLOCKED_USER_LIST",
    FRIENDLIST = "FRIENDLIST",
    FAMILY_ERROR = "FAMILY_ERROR",
    FAMILY_MEMBER_ADDED = "FAMILY_MEMBER_ADDED",
    FAMILY_MEMBER_LEFT = "FAMILY_MEMBER_LEFT",
    FAMILY_MEMBER_KICKED = "FAMILY_MEMBER_KICKED",
    FAMILY_MEMBER = "FAMILY_MEMBER",
    FAMILY_OWNER_CHANGED = "FAMILY_OWNER_CHANGED",
    FAMILY_REMOVED = "FAMILY_REMOVED",
    EXPEDITION_EXP = "EXPEDITION_EXP",
    FAMILY_EXP_ADD = "FAMILY_EXP_ADD",
    FAMILY_NAME_CHANGED = "FAMILY_NAME_CHANGED",
    RESIDENT_SERVICE_POINT_CHANGED = "RESIDENT_SERVICE_POINT_CHANGED",
    CHAT_DICE_VALUE = "CHAT_DICE_VALUE",
    CRIME_REPORTED = "CRIME_REPORTED",
    TOWER_DEF_MSG = "TOWER_DEF_MSG",
    SAVE_SCREEN_SHOT = "SAVE_SCREEN_SHOT",
    TRIAL_MESSAGE = "TRIAL_MESSAGE",
    AUCTION_BIDDEN = "AUCTION_BIDDEN",
    AUCTION_BOUGHT_BY_SOMEONE = "AUCTION_BOUGHT_BY_SOMEONE",
    SELL_SPECIALTY = "SELL_SPECIALTY",
    SHOW_SEXTANT_POS = "SHOW_SEXTANT_POS",
    EXP_CHANGED = "EXP_CHANGED",
    ABILITY_EXP_CHANGED = "ABILITY_EXP_CHANGED",
    ACQUAINTANCE_LOGIN = "ACQUAINTANCE_LOGIN",
    HPW_ZONE_STATE_CHANGE = "HPW_ZONE_STATE_CHANGE",
    SHOW_ACCUMULATE_HONOR_POINT_DURING_HPW = "SHOW_ACCUMULATE_HONOR_POINT_DURING_HPW",
    ITEM_EQUIP_RESULT = "ITEM_EQUIP_RESULT",
    INSTANT_GAME_KILL = "INSTANT_GAME_KILL",
    INSTANT_GAME_UNEARNED_WIN_REMAIN_TIME = "INSTANT_GAME_UNEARNED_WIN_REMAIN_TIME",
    CHAT_MSG_ALARM = "CHAT_MSG_ALARM",
    HOUSE_CANCEL_SELL_SUCCESS = "HOUSE_CANCEL_SELL_SUCCESS",
    HOUSE_CANCEL_SELL_FAIL = "HOUSE_CANCEL_SELL_FAIL",
    HOUSE_SET_SELL_SUCCESS = "HOUSE_SET_SELL_SUCCESS",
    HOUSE_SET_SELL_FAIL = "HOUSE_SET_SELL_FAIL",
    HOUSE_BUY_SUCCESS = "HOUSE_BUY_SUCCESS",
    HOUSE_BUY_FAIL = "HOUSE_BUY_FAIL",
    HOUSE_SALE_SUCCESS = "HOUSE_SALE_SUCCESS",
    BOT_SUSPECT_REPORTED = "BOT_SUSPECT_REPORTED",
    NATION_INDEPENDENCE = "NATION_INDEPENDENCE",
    NATION_TAXRATE = "NATION_TAXRATE",
    ITEM_LOOK_CONVERTED = "ITEM_LOOK_CONVERTED",
    AUDIENCE_JOINED = "AUDIENCE_JOINED",
    AUDIENCE_LEFT = "AUDIENCE_LEFT",
    ACTABILITY_EXPERT_EXPANDED = "ACTABILITY_EXPERT_EXPANDED",
    INVALID_NAME_POLICY = "INVALID_NAME_POLICY",
    HERO_SEASON_UPDATED = "HERO_SEASON_UPDATED",
    LOOT_PACK_ITEM_BROADCAST = "LOOT_PACK_ITEM_BROADCAST",
    DICE_BID_RULE_CHANGED = "DICE_BID_RULE_CHANGED",
    BADWORD_USER_REPORED_RESPONE_MSG = "BADWORD_USER_REPORED_RESPONE_MSG",
    HEIR_SKILL_LEARN = "HEIR_SKILL_LEARN",
    HEIR_SKILL_RESET = "HEIR_SKILL_RESET",
    TEAM_MEMBERS_CHANGED = "TEAM_MEMBERS_CHANGED",
    UI_RELOADED = "UI_RELOADED",
    UPDATE_PING_INFO = "UPDATE_PING_INFO",
    MOUSE_DOWN = "MOUSE_DOWN",
    LEFT_LOADING = "LEFT_LOADING",
    HERO_SCORE_UPDATED = "HERO_SCORE_UPDATED",
    START_HERO_ELECTION_PERIOD = "START_HERO_ELECTION_PERIOD",
    UPDATE_HERO_ELECTION_CONDITION = "UPDATE_HERO_ELECTION_CONDITION",
    END_HERO_ELECTION_PERIOD = "END_HERO_ELECTION_PERIOD",
    NATION_INVITE = "NATION_INVITE",
    NATION_KICK = "NATION_KICK",
    PLAYER_JURY_POINT = "PLAYER_JURY_POINT",
    JURY_WAITING_NUMBER = "JURY_WAITING_NUMBER",
    CHAT_EMOTION = "CHAT_EMOTION",
    IME_STATUS_CHANGED = "IME_STATUS_CHANGED",
    OPEN_COMMON_FARM_INFO = "OPEN_COMMON_FARM_INFO",
    INTERACTION_END = "INTERACTION_END",
    WEB_BROWSER_ESC_EVENT = "WEB_BROWSER_ESC_EVENT",
    BLOCKED_USER_UPDATE = "BLOCKED_USER_UPDATE",
    UNIT_COMBAT_STATE_CHANGED = "UNIT_COMBAT_STATE_CHANGED",
    ENTERED_WORLD = "ENTERED_WORLD",
    TARGET_OVER = "TARGET_OVER",
    RELOAD_COSMETIC_WINDOW = "RELOAD_COSMETIC_WINDOW",
    DEMO_MODE = "DEMO_MODE",
    DEMO_CHAR_RESET = "DEMO_CHAR_RESET",
    AGGRO_METER_UPDATED = "AGGRO_METER_UPDATED",
    AGGRO_METER_CLEARED = "AGGRO_METER_CLEARED",
    DYNAMIC_ACTION_BAR_SHOW = "DYNAMIC_ACTION_BAR_SHOW",
    DYNAMIC_ACTION_BAR_HIDE = "DYNAMIC_ACTION_BAR_HIDE",
    DYNAMIC_ACTION_EXECUTE = "DYNAMIC_ACTION_EXECUTE",
    UPDATE_BINDINGS = "UPDATE_BINDINGS",
    GOODS_MAIL_INBOX_UPDATE = "GOODS_MAIL_INBOX_UPDATE",
    UNIT_NPC_EQUIPMENT_CHANGED = "UNIT_NPC_EQUIPMENT_CHANGED",
    UPDATE_INGAME_SHOP = "UPDATE_INGAME_SHOP",
    PLAYER_BM_POINT = "PLAYER_BM_POINT",
    INTERACTION_START = "INTERACTION_START",
    INTERACTION_LIST = "INTERACTION_LIST",
    DRAW_DOODAD_SIGN_TAG = "DRAW_DOODAD_SIGN_TAG",
    DRAW_DOODAD_TOOLTIP = "DRAW_DOODAD_TOOLTIP",
    SIM_DOODAD_MSG = "SIM_DOODAD_MSG",
    BAG_UPDATE = "BAG_UPDATE",
    BAG_EXPANDED = "BAG_EXPANDED",
    CHANGED_AUTO_USE_AAPOINT = "CHANGED_AUTO_USE_AAPOINT",
    BANK_UPDATE = "BANK_UPDATE",
    BANK_EXPANDED = "BANK_EXPANDED",
    PLAYER_BANK_MONEY = "PLAYER_BANK_MONEY",
    PLAYER_BANK_AA_POINT = "PLAYER_BANK_AA_POINT",
    COFFER_UPDATE = "COFFER_UPDATE",
    CREATE_CHARACTER_FAILED = "CREATE_CHARACTER_FAILED",
    FADE_INOUT_DONE = "FADE_INOUT_DONE",
    OPEN_WORLD_QUEUE = "OPEN_WORLD_QUEUE",
    REFRESH_WORLD_QUEUE = "REFRESH_WORLD_QUEUE",
    SHOW_CHARACTER_CREATE_WINDOW = "SHOW_CHARACTER_CREATE_WINDOW",
    SHOW_CHARACTER_CUSTOMIZE_WINDOW = "SHOW_CHARACTER_CUSTOMIZE_WINDOW",
    SHOW_CHARACTER_ABILITY_WINDOW = "SHOW_CHARACTER_ABILITY_WINDOW",
    USE_ALL_ASSETS = "USE_ALL_ASSETS",
    ENTERED_LOGIN = "ENTERED_LOGIN",
    LEFT_LOGIN = "LEFT_LOGIN",
    LOOT_BAG_CLOSE = "LOOT_BAG_CLOSE",
    MAIL_INBOX_UPDATE = "MAIL_INBOX_UPDATE",
    MAIL_SENTBOX_UPDATE = "MAIL_SENTBOX_UPDATE",
    MAIL_RETURNED = "MAIL_RETURNED",
    MAIL_SENT_SUCCESS = "MAIL_SENT_SUCCESS",
    MAIL_INBOX_ITEM_TAKEN = "MAIL_INBOX_ITEM_TAKEN",
    MAIL_INBOX_MONEY_TAKEN = "MAIL_INBOX_MONEY_TAKEN",
    MAIL_INBOX_ATTACHMENT_TAKEN_ALL = "MAIL_INBOX_ATTACHMENT_TAKEN_ALL",
    MAIL_INBOX_TAX_PAID = "MAIL_INBOX_TAX_PAID",
    MAIL_WRITE_ITEM_UPDATE = "MAIL_WRITE_ITEM_UPDATE",
    UPDATE_OPTION_BINDINGS = "UPDATE_OPTION_BINDINGS",
    OPEN_CONFIG = "OPEN_CONFIG",
    LEAVING_WORLD_STARTED = "LEAVING_WORLD_STARTED",
    LEAVING_WORLD_CANCELED = "LEAVING_WORLD_CANCELED",
    SAVE_PORTAL = "SAVE_PORTAL",
    DELETE_PORTAL = "DELETE_PORTAL",
    RENAME_PORTAL = "RENAME_PORTAL",
    QUEST_LEFT_TIME_UPDATED = "QUEST_LEFT_TIME_UPDATED",
    FOLDER_STATE_CHANGED = "FOLDER_STATE_CHANGED",
    END_QUEST_CHAT_BUBBLE = "END_QUEST_CHAT_BUBBLE",
    QUEST_HIDDEN_READY = "QUEST_HIDDEN_READY",
    QUEST_HIDDEN_COMPLETE = "QUEST_HIDDEN_COMPLETE",
    QUEST_ERROR_INFO = "QUEST_ERROR_INFO",
    QUEST_TASK_READY = "QUEST_TASK_READY",
    TEAM_MEMBER_DISCONNECTED = "TEAM_MEMBER_DISCONNECTED",
    SET_OVERHEAD_MARK = "SET_OVERHEAD_MARK",
    TEAM_ROLE_CHANGED = "TEAM_ROLE_CHANGED",
    TEAM_HEALTH_CHANGED = "TEAM_HEALTH_CHANGED",
    TEAM_MANA_CHANGED = "TEAM_MANA_CHANGED",
    TOGGLE_RAID_FRAME_PARTY = "TOGGLE_RAID_FRAME_PARTY",
    TOGGLE_PARTY_FRAME = "TOGGLE_PARTY_FRAME",
    RAID_FRAME_SIMPLE_VIEW = "RAID_FRAME_SIMPLE_VIEW",
    UPDATE_DURABILITY_STATUS = "UPDATE_DURABILITY_STATUS",
    UNIT_EQUIPMENT_CHANGED = "UNIT_EQUIPMENT_CHANGED",
    NPC_INTERACTION_END = "NPC_INTERACTION_END",
    OPEN_EMBLEM_IMPRINT_UI = "OPEN_EMBLEM_IMPRINT_UI",
    DIVE_START = "DIVE_START",
    DIVE_END = "DIVE_END",
    SPELLCAST_START = "SPELLCAST_START",
    SPELLCAST_STOP = "SPELLCAST_STOP",
    SPELLCAST_SUCCEEDED = "SPELLCAST_SUCCEEDED",
    TARGET_CHANGED = "TARGET_CHANGED",
    TARGET_TO_TARGET_CHANGED = "TARGET_TO_TARGET_CHANGED",
    BAD_USER_LIST_UPDATE = "BAD_USER_LIST_UPDATE",
    SET_UI_MESSAGE = "SET_UI_MESSAGE"
}

-- API
ADDON_API = {
	File = {},
	Unit = {},
	Team = {},
	Log = {},
	Interface = {},
	Cursor = {},
	Input = {},
	Time = {},
	Player = {},
    Bag = {},
    Ability = {},
    Item = {},
    Skill = {},
    Store = {},
    Bank = {},
    Equipment = {},
    SiegeWeapon = {},
    ItemEnchant = {},
    Map = {},
    Quest = {},
    Zone = {},
    Craft = {},
    Option = {},
    Chat = {},
    Nametag = {},
    Voice = {},
	-- This is the 'addons' directory at runtime
	baseDir = "",
	rootWindow = {},
    timers = {}
}


-- ======
-- Logging
-- ======

--[[ 
    Logs a message to chat in YELLOW
    @param message (string) The message to log
    @returns (nil)
]]
function ADDON_API.Log:Info(message)
end

--[[ 
    Logs a message to chat in RED
    @param message (string) The message to log
    @returns (nil)
]]
function ADDON_API.Log:Err(message)
end

--[[ 
    Logs an event and its parameters to chat. Useful for debugging events.
    Example usage in code:
    	function events:OnEvent(event, ...)
		if event == "COMBAT_MSG" then 
			api.Log:WriteEventParameters(event, ...)
		end 
    @param event (string) The event name
    @param ... The event parameters
    @returns (nil)
]]
function ADDON_API.Log:WriteEventParameters(event, ...)
end

-- ======
-- File Handling
-- ======

--[[ 
    Serializes a table and writes it to the desired path.
    Paths are relative to the addons folder
    @param path (string) The file path
    @param tbl (table) The table to serialize
    @returns (nil)
]]
function ADDON_API.File:Write(path, tbl)
end

--[[ 
    Reads the file located at path and deserializes it into a table.
    Paths are relative to the addons folder
    @param path (string) The file path
    @returns (table) The deserialized table
]]
function ADDON_API.File:Read(path)
end

--[[ 
    Get the settings for the desired addonId
    @param addonId (string) The name of the addon folder. For example, `example_addon`
    @returns (table) The settings table
]]
function ADDON_API.GetSettings(addonId)
end

--[[ 
    Saves all addon settings. Do not call too often.
    @returns (nil)
]]
function ADDON_API.SaveSettings()
end

--[[ 
    Gets current UI memory usage in MB
    @returns (number|nil) Memory usage in MB, or nil if unavailable
]]
function ADDON_API.GetMemoryUsage()
end

-- ======
-- Interface
-- ======

--[[ 
    Creates a standard looking window. If size is not specified, it will default to 680x615
    Tabs can be used to define tabs on the window by default.
    @param id (string) The window ID
    @param title (string) The window title
    @param x (number) X position
    @param y (number) Y position
    @param tabs (table) Tabs configuration
    @returns (table) The created window
]]
function ADDON_API.Interface:CreateWindow(id, title, x, y, tabs)
end

--[[ 
    Creates an empty window, that does not render anything.
    Particularly useful to draw things on the HUD
    @param id (string) The window ID
    @returns (table) The created window
]]
function ADDON_API.Interface:CreateEmptyWindow(id)
end

--[[ 
    Creates a Widget bound to parent.
    Types: button, label, window, slot, checkbutton, window, textbox, message, gametooltip
    @param type (string) The widget type
    @param id (string) The widget ID
    @param parent (table) The parent widget
    @returns (table) The created widget
]]
function ADDON_API.Interface:CreateWidget(type, id, parent)
end

--[[ 
    Creates a status bar
    @param name (string) The name of the status bar
    @param parent (table) The parent widget
    @param type (string) The type of the status bar
    @returns (table) The created status bar
]]
function ADDON_API.Interface:CreateStatusBar(name, parent, type)
end

--[[ 
    Creates a Combo Box (like the grade selector in the equipment folio)
    Use the dropdownItem member to set the contents
    @param window (table) The parent window
    @returns (table) The created combo box
]]
function ADDON_API.Interface:CreateComboBox(window)
end

--[[ 
    Applies a skin to a button 
    Possible values are BUTTON_BASIC.{DEFAULT, RESET, BASIC} and more
    @param btn (table) The button widget
    @param skin (string) The skin to apply
    @returns (nil)
]]
function ADDON_API.Interface:ApplyButtonSkin(btn, skin)
end

--[[ 
    Sets tooltip at coordinates
    @param text (string) The tooltip text
    @param target (table) The target widget
    @param posX (number) X position
    @param posY (number) Y position
    @returns (nil)
]]
function ADDON_API.Interface:SetTooltipOnPos(text, target, posX, posY)
end

--[[ 
    Frees the specified window's reference, removing it from the UI
    Useful for cleaning up windows in the OnUnload function of addons
    @param wnd (table) The window to free
    @returns (nil)
]]
function ADDON_API.Interface:Free(wnd)
end

--[[ 
    Gets the screen width
    @returns (number) The screen width
]]
function ADDON_API.Interface:GetScreenWidth()
end

--[[ 
    Gets the screen height
    @returns (number) The screen height
]]
function ADDON_API.Interface:GetScreenHeight()
end

--[[ 
    Gets the UI scale
    @returns (number) The UI scale
]]
function ADDON_API.Interface:GetUIScale()
end

-- ======
-- Unit
-- ======

--[[
    Note: The "unit" parameter or identifier in the below functions can be: 
    - player
    - target
    - targettarget
    - team1 through team50
    - playerpet1 or playerpet2
]]


--[[ 
    Returns a unit's (player, npc, pet..) name by its ID
    @param id (number) The unit ID
    @returns (string) The unit name
]]
function ADDON_API.Unit:GetUnitNameById(id)
end

--[[ 
    Returns a unit's information by its ID
    @param id (number) The unit ID
    @returns (table) The unit information
]]
function ADDON_API.Unit:GetUnitInfoById(id)
end

--[[ 
    Get the screen coordinates of the desired unit. This can be used to overlay UI elements and "track" units.
    @param unit (string) The unit identifier
    @returns (number, number) The screen X and Y coordinates
]]
function ADDON_API.Unit:GetUnitScreenPosition(unit)
end

--[[ 
    Returns the distance between the desired unit and the player, in meters
    @param unit (string) The unit identifier
    @returns (number) The distance in meters
]]
function ADDON_API.Unit:UnitDistance(unit)
end

--[[ 
    Returns the unit ID for the desired unit. The ID can then be passed to GetUnitNameById and GetUnitInfoById
    @param unit (string) The unit identifier
    @returns (number) The unit ID
]]
function ADDON_API.Unit:GetUnitId(unit)
end

--[[ 
    Returns the number of buffs a unit has
    @param unit (string) The unit identifier
    @returns (number) The number of buffs
]]
function ADDON_API.Unit:UnitBuffCount(unit)
end

--[[ 
    Returns the name of a unit
    @param unit (string) The unit identifier
    @returns (string) The unit name
]]
function ADDON_API.Unit:UnitName(unit)
end

--[[ 
    Returns the buff at index for a unit. Nil if no buff is found
    @param unit (string) The unit identifier
    @param index (number) The buff index
    @returns (table) The buff information
]]
function ADDON_API.Unit:UnitBuff(unit, index)
end

--[[ 
    Returns the unit world coordinates of the desired unit as x,y,z
    @param unit (string) The unit identifier
    @returns (number, number, number) The world X, Y, Z coordinates
]]
function ADDON_API.Unit:UnitWorldPosition(unit)
end

--[[ 
    Returns the number of debuffs a unit has
    @param unit (string) The unit identifier
    @returns (number) The number of debuffs
]]
function ADDON_API.Unit:UnitDeBuffCount(unit)
end

--[[ 
    Returns the debuff at index for a unit. Nil if no debuff is found
    @param unit (string) The unit identifier
    @param index (number) The debuff index
    @returns (table) The debuff information
]]
function ADDON_API.Unit:UnitDeBuff(unit, index)
end

--[[ 
    Gets the health of a unit
    @param unit (string) The unit identifier
    @returns (number) The current health
]]
function ADDON_API.Unit:UnitHealth(unit)
end

--[[ 
    Gets the maximum health of a unit
    @param unit (string) The unit identifier
    @returns (number) The maximum health
]]
function ADDON_API.Unit:UnitMaxHealth(unit)
end

--[[ 
    Gets the mana of a unit
    @param unit (string) The unit identifier
    @returns (number) The current mana
]]
function ADDON_API.Unit:UnitMana(unit)
end

--[[ 
    Gets the maximum mana of a unit
    @param unit (string) The unit identifier
    @returns (number) The maximum mana
]]
function ADDON_API.Unit:UnitMaxMana(unit)
end

--[[ 
    Gets information about a unit
    @param unit (string) The unit identifier
    @returns (table) The unit information
]]
function ADDON_API.Unit:UnitInfo(unit)
end

--[[ 
    Gets modifier information about a unit
    @param unit (string) The unit identifier
    @returns (table) The modifier information
]]
function ADDON_API.Unit:UnitModifierInfo(unit)
end

--[[ 
    Gets the class of a unit
    @param unit (string) The unit identifier
    @returns (string) The unit class
]]
function ADDON_API.Unit:UnitClass(unit)
end

--[[ 
    Gets the gear score of a unit
    @param unit (string) The unit identifier
    @returns (number) The gear score
]]
function ADDON_API.Unit:UnitGearScore(unit)
end

--[[ 
    Gets the team authority of a unit
    @param unit (string) The unit identifier
    @returns (number) The team authority
]]
function ADDON_API.Unit:UnitTeamAuthority(unit)
end

--[[ 
    Checks if a unit is a team member
    @param unit (string) The unit identifier
    @returns (boolean) True if the unit is a team member, false otherwise
]]
function ADDON_API.Unit:UnitIsTeamMember(unit)
end

--[[ 
    Checks if a unit is currently flagged.
    @param unit (string) The unit identifier
    @returns (boolean) True if the unit is flagged for forced PvP, false otherwise
]]
function ADDON_API.Unit:UnitIsForceAttack(unit)
end

--[[ 
    Gets the faction name of a unit
    @param unit (string) The unit identifier
    @returns (string) The faction name
]]
function ADDON_API.Unit:GetFactionName(unit)
end

--[[ 
    Gets the screen name tag offset of a unit
    @param unit (string) The unit identifier
    @returns (number) The offset
]]
function ADDON_API.Unit:GetUnitScreenNameTagOffset(unit)
end

--[[ 
    Gets high ability (Abyssal Charges) resource information
    @returns (table) The resource information
]]
function ADDON_API.Unit:GetHighAbilityRscInfo()
end

--[[ 
    Checks if a unit is offline
    @param unit (string) The unit identifier
    @returns (boolean) True if the unit is offline, false otherwise
]]
function ADDON_API.Unit:UnitIsOffline(unit)
end

--[[ 
    Gets the overhead marker unit ID
    @param markerIndex (number) The marker index, any nubmer between 1 and 12
    @returns (number) The unit ID
]]
function ADDON_API.Unit:GetOverHeadMarkerUnitId(markerIndex)
end

--[[ 
    Gets the current zone group of the player
    @returns (number) The current zone group ID
]]
function ADDON_API.Unit:GetCurrentZoneGroup()
end

--[[ 
    Registers a raw unit ID received from a game event into the known store.
    Returns the ID so it can be passed to GetUnitInfoById for safe-subset info.
    @param unitId (number) The unit ID from an event
    @returns (number) The registered unit ID
]]
function ADDON_API.Unit:RememberEventUnitId(unitId)
end

--[[ 
    Gets the current target unit
    @param unit (string) The unit identifier
    @returns (string) The current target unit identifier
]]
function ADDON_API.Unit:TargetUnit(unit)
end

-- ======
-- Team
-- ======

--[[ 
    Invites the desired player to raid/party
    If party is true and the player is not in party/raid, a party will be created. Otherwise, a raid
    @param name (string) The player name
    @param party (boolean) True for party, false for raid
    @returns (nil)
]]
function ADDON_API.Team:InviteToTeam(name, party)
end

--[[ 
    Sets the player's role within the party
    0 = Blue
    @param role (number) The role ID
    @returns (nil)
]]
function ADDON_API.Team:SetRole(role)
end

--[[ 
    Checks if the team is a party
    @returns (boolean) True if the team is a party, false otherwise
]]
function ADDON_API.Team:IsPartyTeam()
end

--[[ 
    Checks if the team is a raid
    @returns (boolean) True if the team is a raid, false otherwise
]]
function ADDON_API.Team:IsPartyRaid()
end

--[[ 
    Gets the member index by name
    @param playerName (string) The player name
    @returns (number) The member index
]]
function ADDON_API.Team:GetMemberIndexByName(playerName)
end

--[[ 
    Gets the team distributor name
    @returns (string) The distributor name
]]
function ADDON_API.Team:GetTeamDistributorName()
end

--[[ 
    Gets the team player index
    @returns (number) The player index
]]
function ADDON_API.Team:GetTeamPlayerIndex()
end

--[[ 
    Gets the role of a team member
    @param memberIndex (number) The member index
    @returns (number) The role ID
]]
function ADDON_API.Team:GetRole(memberIndex)
end

--[[ 
    Promotes a player to team owner
    @param target (string) The player name to promote
    @returns (nil)
]]
function ADDON_API.Team:MakeTeamOwner(target)
end

--[[ 
    Moves a team member from one position to another
    @param fromIndex (number) The current member index
    @param toIndex (number) The new member index
    @returns (nil)
]]
function ADDON_API.Team:MoveTeamMember(fromIndex, toIndex)
end

-- ======
-- Bag
-- ======

--[[ 
    Equips the item at the bag slot specified
    @param bagSlot (number) The bag slot index
    @param isAux (boolean) True for auxiliary slot, false otherwise
    @returns (nil)
]]
function ADDON_API.Bag:EquipBagItem(bagSlot, isAux)
end

--[[ 
    Get item information at the index, in the bag specified. 1 = Inventory 
    @param bagType (number) The bag type
    @param index (number) The item index
    @returns (table) The item information
]]
function ADDON_API.Bag:GetBagItemInfo(bagType, index)
end

--[[ 
    Counts the items in the bag
    @returns (number) The item count
]]
function ADDON_API.Bag:CountItems()
end

--[[ 
    Gets the bag capacity
    @returns (number) The bag capacity
]]
function ADDON_API.Bag:Capacity()
end

--[[ 
    Counts the items in the bag by item type
    @param type (number) The item type
    @returns (number) The item count
]]
function ADDON_API.Bag:CountBagItemByItemType(type)
end

--[[ 
    Gets the amount of gold in the player's bag.
    @returns (number) The currency amount
]]
function ADDON_API.Bag:GetCurrency()
end

-- ======
-- Cursor
-- ======

--[[ 
    Clears the cursor
    @returns (nil)
]]
function ADDON_API.Cursor:ClearCursor()
end

--[[ 
    Sets the cursor image
    @param image (string) The image path
    @param x (number) X position
    @param y (number) Y position
    @returns (nil)
]]
function ADDON_API.Cursor:SetCursorImage(image, x, y)
end

--[[ 
    Gets the picked bag item index from the cursor
    @returns (number) The bag item index
]]
function ADDON_API.Cursor:GetCursorPickedBagItemIndex()
end

--[[ 
    Gets the picked bag item amount from the cursor
    @returns (number) The bag item amount
]]
function ADDON_API.Cursor:GetCursorPickedBagItemAmount()
end

--[[ 
    Gets the item information that is currently on the cursor
    @returns (table) The cursor information
]]
function ADDON_API.Cursor:GetCursorInfo()
end

-- ======
-- Time
-- ======

--[[ 
    Returns milliseconds since the game's UI scripts have started running
    @returns (number) The milliseconds since the game started
]]
function ADDON_API.Time:GetUiMsec()
end

--[[ 
    Gets the local time of the player's computer
    @returns (table) The local time
]]
function ADDON_API.Time:GetLocalTime()
end

--[[ 
    The amount of time until a date period
    @param localTime (table) The local time
    @param period (number) The period time
    @returns (table) The time difference between the local time and the period
]]
function ADDON_API.Time:PeriodTimeToDate(localTime, period)
end

--[[ 
    Converts an epoch timestamp to a date
    @param epochTimestamp (number) The epoch timestamp
    @returns (table) The date
]]
function ADDON_API.Time:TimeToDate(epochTimestamp)
end

--[[ 
    Gets the game time
    @returns (table) The in-game time
]]
function ADDON_API.Time:GetGameTime()
end

-- ======
-- Quest
-- ======

--[[ 
    Checks if a quest is completed
    @param questTypeId (number) The quest type ID
    @returns (boolean) True if the quest is completed, false otherwise
]]
function ADDON_API.Quest:IsCompleted(questTypeId)
end

--[[ 
    Gets the active quest title
    @param questTypeId (number) The quest type ID
    @returns (string) The quest title
]]
function ADDON_API.Quest:GetActiveQuestTitle(questTypeId)
end

--[[ 
    Gets the main title of the quest context
    @param questTypeId (number) The quest type ID
    @returns (string) The main title
]]
function ADDON_API.Quest:GetQuestContextMainTitle(questTypeId)
end

--[[ 
    Gets the body of the quest context
    @param questTypeId (number) The quest type ID
    @returns (string) The body text
]]
function ADDON_API.Quest:GetQuestContextBody(questTypeId)
end

-- ======
-- Input
-- ======

--[[ 
    Checks if the Shift key is pressed
    @returns (boolean) True if the Shift key is pressed, false otherwise
]]
function ADDON_API.Input:IsShiftKeyDown()
end

--[[ 
    Checks if the Control key is pressed
    @returns (boolean) True if the Control key is pressed, false otherwise
]]
function ADDON_API.Input:IsControlKeyDown()
end

--[[ 
    Checks if the Alt key is pressed
    @returns (boolean) True if the Alt key is pressed, false otherwise
]]
function ADDON_API.Input:IsAltKeyDown()
end

--[[ 
    Gets the mouse position
    @returns (number, number) The X and Y coordinates of the mouse
]]
function ADDON_API.Input:GetMousePos()
end

-- ======
-- Player
-- ======

--[[ 
    Changes the player's title
    @param type (number) The ID of the title to set
    @returns (nil|true) True if the title was changed, nil otherwise
]]
function ADDON_API.Player:ChangeAppellation(type)
end

--[[ 
    Gets the currently showing player title
    @returns (string) The title
]]
function ADDON_API.Player:GetShowingAppellation()
end

--[[ 
    Gets the player's game points
    @returns (number) The game points
]]
function ADDON_API.Player:GetGamePoints()
end

--[[ 
    Gets the player's crime information
    @returns (table) The crime information
]]
function ADDON_API.Player:GetCrimeInfo()
end

-- ======
-- Events & Timers
-- ======

--[[ 
    Binds callback to the desired event
    Current events:
    - UPDATE (dt) - Called every frame, with dt = time in msec since last frame
    - CHAT_MESSAGE
    - TEAM_MEMBERS_CHANGED
    - UI_RELOADED
    - UPDATE_PING_INFO - Called when the map ping is moved
    @param event (string) The event name
    @param callback (function) The callback function
    @returns (nil)
]]
function ADDON_API.On(event, callback)
end

--[[ 
    Registers a callback to be executed in a certain duration (in msec)
    If you need to call this often, consider using On("UPDATE") instead
    @param msec (number) The duration in milliseconds
    @param callback (function) The callback function
    @param ... (any) Additional arguments
    @returns (nil)
]]
function ADDON_API:DoIn(msec, callback, ...)
end

--[[ 
    Emits an event. We recommend using event names like "ADDON_MY_EVENT" so that other addons don't get tripped.
    @param event (string) The event name
    @param ... (any) Additional arguments
    @returns (nil)
]]
function ADDON_API:Emit(event, ...)
end

-- ======
-- Ability
-- ======

--[[ 
    Gets the tooltip for a buff
    @param buffId (number) The buff ID
    @param itemLevel (number) The item level
    @returns (string) The tooltip text
]]
function ADDON_API.Ability:GetBuffTooltip(buffId, itemLevel)
end

--[[ 
    Gets the ability from the view
    @param index (number) The view index
    @returns (table) The ability information
]]
function ADDON_API.Ability:GetAbilityFromView(index)
end

--[[ 
    Checks if an ability is active
    @param ability (table) The ability information
    @returns (boolean) True if the ability is active, false otherwise
]]
function ADDON_API.Ability:IsActiveAbility(ability)
end

--[[ 
    Gets the skillset name by ID
    @param skillsetId (number) The skillset ID
    @returns (string) The skillset name
]]
function ADDON_API.Ability:GetSkillsetNameById(skillsetId)
end

--[[ 
    Gets the unit class name
    @param unit (string) The unit identifier
    @returns (string) The class name
]]
function ADDON_API.Ability:GetUnitClassName(unit)
end

--[[ 
    Gets the class name from skillset IDs
    @param skillset1 (number) The first skillset ID
    @param skillset2 (number) The second skillset ID
    @param skillset3 (number) The third skillset ID
    @returns (string) The class name
]]
function ADDON_API.Ability:GetClassNameFromSkillsetIds(skillset1, skillset2, skillset3)
end

-- ======
-- Item
-- ======

--[[ 
    Gets item information by its type
    @param itemId (number) The item ID
    @returns (table) The item information
]]
function ADDON_API.Item:GetItemInfoByType(itemId)
end

-- ======
-- Skill
-- ======

--[[ 
    Gets the tooltip for a skill
    @param skillId (number) The skill ID
    @returns (string) The tooltip text
]]
function ADDON_API.Skill:GetSkillTooltip(skillId)
end

-- ======
-- Store
-- ======

--[[ 
    Returns the Seller % on packs. Usually 80%, it futureproofs your addon if it changes.
    @returns (number) The seller share ratio
]]
function ADDON_API.Store:GetSellerShareRatio()
end

--[[ 
    Gets the specialty ratio
    @returns (number) The specialty ratio
]]
function ADDON_API.Store:GetSpecialtyRatio()
end

--[[ 
    Gets the production zone groups
    @returns (table) The production zone groups
]]
function ADDON_API.Store:GetProductionZoneGroups()
end

--[[ 
    Gets the sellable zone groups starting from a zone ID
    @param startZoneId (number) The starting zone ID
    @returns (table) The sellable zone groups
]]
function ADDON_API.Store:GetSellableZoneGroups(startZoneId)
end

--[[ 
    Gets the specialty ratio between two zones
    @param startZoneId (number) The starting zone ID
    @param finishZoneId (number) The finishing zone ID
    @returns (number) The specialty ratio
]]
function ADDON_API.Store:GetSpecialtyRatioBetween(startZoneId, finishZoneId)
end

-- ======
-- Bank
-- ======

--[[ 
    Counts the items in the bank
    @returns (number) The item count
]]
function ADDON_API.Bank:CountItems()
end

--[[ 
    Gets the bank's item capacity
    @returns (number) The bank capacity
]]
function ADDON_API.Bank:Capacity()
end

--[[ 
    Gets the amount of gold in the player's bank.
    @returns (number) The currency amount
]]
function ADDON_API.Bank:GetCurrency()
end

--[[ 
    Gets the link text for a slot in the bank
    @param inventorySlotId (number) The bank slot ID
    @returns (string) The link text
]]
function ADDON_API.Bank:GetLinkText(inventorySlotId)
end

-- ======
-- Equipment
-- ======

--[[ 
    Gets the tooltip information for an equipped item
    @param slotIdx (number) The slot index
    @returns (table) The tooltip information
]]
function ADDON_API.Equipment:GetEquippedItemTooltipInfo(slotIdx)
end

--[[ 
    Gets the tooltip text for an equipped item
    @param unit (string) The unit identifier
    @param slotIdx (number) The slot index
    @returns (string) The tooltip text
]]
function ADDON_API.Equipment:GetEquippedItemTooltipText(unit, slotIdx)
end

--[[ 
    Gets the equipped skillset lunagems for a unit
    @param unit (string) The unit identifier
    @returns (table) The lunagems information
]]
function ADDON_API.Equipment:GetEquippedSkillsetLunagems(unit)
end

-- ======
-- SiegeWeapon
-- ======

--[[ 
    Gets the siege weapon speed
    @returns (number) The speed
]]
function ADDON_API.SiegeWeapon:GetSiegeWeaponSpeed()
end

--[[ 
    Gets the siege weapon's turn speed
    @returns (number) The turn speed
]]
function ADDON_API.SiegeWeapon:GetSiegeWeaponTurnSpeed()
end

-- ======
-- ItemEnchant
-- ======

--[[ 
    Gets the ratio information for item enchantment
    @returns (table) The ratio information
]]
function ADDON_API.ItemEnchant:GetRatioInfos()
end

--[[ 
    Gets the enchant item information
    @returns (table) The enchant item information
]]
function ADDON_API.ItemEnchant:GetEnchantItemInfo()
end

--[[ 
    Gets the support item information
    @returns (table) The support item information
]]
function ADDON_API.ItemEnchant:GetSupportItemInfo()
end

--[[ 
    Gets the target item information
    @returns (table) The target item information
]]
function ADDON_API.ItemEnchant:GetTargetItemInfo()
end

-- ======
-- Map
-- ======

--[[ 
    Toggles the map with a portal
    @param portal_zone_id (number) The portal zone ID
    @param x (number) X position
    @param y (number) Y position
    @param z (number) Z position
    @returns (nil)
]]
function ADDON_API.Map:ToggleMapWithPortal(portal_zone_id, x, y, z)
end

--[[ 
    Gets the player's coordinates in sextant format
    @returns (table) The sextants information
]]
function ADDON_API.Map:GetPlayerSextants()
end

-- ======
-- Zone
-- ======

--[[ 
    Gets the zone state information by zone ID
    @param zoneId (number) The zone ID
    @returns (table) The zone state information
]]
function ADDON_API.Zone:GetZoneStateInfoByZoneId(zoneId)
end

-- ======
-- Craft
-- ======

--[[ 
    Gets the base information for a craft
    @param craftId (number) The craft ID
    @returns (table) The base information
]]
function ADDON_API.Craft:GetCraftBaseInfo(craftId)
end

--[[ 
    Gets the material information for a craft
    @param craftId (number) The craft ID
    @returns (table) The material information
]]
function ADDON_API.Craft:GetCraftMaterialInfo(craftId)
end

--[[ 
    Gets the product information for a craft
    @param craftId (number) The craft ID
    @returns (table) The product information
]]
function ADDON_API.Craft:GetCraftProductInfo(craftId)
end

--[[ 
    Gets the craft type information for a craft from an item type ID
    @param itemType (string) The item type ID
    @returns (table) The craft type information
]]
function ADDON_API.Craft:GetCraftTypeByItemType(itemType)
end

--[[
    Gets the craft type information for a craft by it's name and category
    @param actAbilityGroupType (number) The ability group type
    @param actAbilityCategoryType (number) The ability category type
    @param keyword (string) The keyword for craft searching, can be empty for all crafts in the category
    @returns (table) The craft type information
]]
function ADDON_API.Craft:GetCraftTypesByName(actAbilityGroupType, actAbilityCategoryType, keyword)
end

-- ======
-- Option
-- ======

--[[ 
    Gets the "only use my portal" setting.
    @returns (boolean) True if the setting is enabled, false otherwise
]]
function ADDON_API.Option:GetOnlyUseMyPortalSetting()
end

--[[
    Sets the "only use my portal" setting.
    @param value (boolean) The value to set
    @returns (nil)
]]
function ADDON_API.Option:SetOnlyUseMyPortalSetting(value)
end

--[[ 
    Gets the "custom clone model count" setting.
    @returns (number) The custom clone model count
]]
function ADDON_API.Option:GetCustomCloneModelCountSetting()
end

--[[
    Sets the "custom clone model count" setting.
    @param value (number) The custom clone model count to set
    @returns (nil)
]]
function ADDON_API.Option:SetCustomCloneModelCountSetting(value)
end

--[[ 
    Gets the "custom clone mode" setting.
    @returns (number) The custom clone mode
]]
function ADDON_API.Option:GetCustomCloneModeSetting()
end
--[[
    Sets the "custom clone mode" setting.
    @param value (number) The custom clone mode to set
    @returns (nil)
]]
function ADDON_API.Option:SetCustomCloneModeSetting(value)
end

-- ======
-- Chat
-- ======

--[[ 
    Dispatches a chat message with the desired filter
    @param chatMessageFilter (number) The chat message filter ID, use CHAT_MESSAGE_FILTER
    @param message (string) The message to dispatch
    @returns (nil)
]]
function ADDON_API.Chat:DispatchChatMessage(chatMessageFilter, message)
end
--[[ 
    Expresses an emotion in chat
    @param emotion (string) the emotion.
    @returns (nil)
]]
function ADDON_API.Chat:ExpressEmotion(emotion)
end

-- ======
-- Nametag
-- ======

--[[ 
    Sets the nameplate color for friendly players
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorFriendly(color)
end

--[[ 
    Sets the nameplate color for friendly NPCs
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorFriendlyNPC(color)
end

--[[ 
    Sets the nameplate color for neutral units
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorNeutral(color)
end

--[[ 
    Sets the nameplate color for party members
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorParty(color)
end

--[[ 
    Sets the nameplate color for raid members
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorRaid(color)
end

--[[ 
    Sets the nameplate color for flagged raid members (PK)
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorRaidPK(color)
end

--[[ 
    Sets the nameplate color for flagged players
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorPK(color)
end

--[[ 
    Sets the nameplate color for enemy players
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorEnemy(color)
end

--[[ 
    Sets the nameplate color for monsters
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorMonster(color)
end

--[[ 
    Sets the nameplate color for pirates
    @param color (number|string) The color value (can be integer or numeric string)
    @returns (nil)
]]
function ADDON_API.Nametag:SetColorPirate(color)
end

-- ======
-- Voice
-- ======

--[[ 
    Gets current voice connection status
    @returns (string) Voice status (for example: Disconnected, Connected, Unavailable)
]]
function ADDON_API.Voice:GetVoiceStatus()
end

--[[ 
    Gets the current list of active voice talkers
    @returns (table) A list of talkers: { { charId = number, name = string }, ... }
]]
function ADDON_API.Voice:GetTalkerList()
end

return ADDON_API