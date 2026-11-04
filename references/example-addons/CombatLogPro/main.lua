local api = require("api")

-- [[ LOAD STATIC DATA ]] --
local buffDB = {}
local buffNameToId = {}  -- reverse of buffDB (name -> id) for safe GetBuffTooltip icon lookup
local dbLoaded, staticData = pcall(require, "/CombatLogPro/static_buff_list")
if dbLoaded and staticData then
    local allBuffs = staticData.ALL_BUFFS or staticData
    if type(allBuffs) == "table" then
        for _, entry in ipairs(allBuffs) do
            if entry.id and entry.name then
                buffDB[entry.id] = entry.name
            end
        end
    end
    api.Log:Info("[CLP] Static Buff Database Loaded.")
end

local skillTypesLoaded, skillTypesData = pcall(require, "/CombatLogPro/skill_damage_types")
if skillTypesLoaded and skillTypesData then
    api.Log:Info("[CLP] Skill damage type database loaded.")
else
    api.Log:Info("[CLP] WARNING: skill_damage_types.lua failed to load. Using fallback table.")
end

local skillDataLoaded, SKILL_DATA = pcall(require, "/CombatLogPro/skill_data")
if skillDataLoaded and SKILL_DATA then
    api.Log:Info("[CLP] Skill data database loaded.")
else
    SKILL_DATA = {}
    api.Log:Info("[CLP] WARNING: skill_data.lua failed to load.")
end

local combosLoaded, SKILL_COMBOS = pcall(require, "/CombatLogPro/skill_combos")
if combosLoaded and SKILL_COMBOS then
    api.Log:Info("[CLP] Skill combos database loaded.")
else
    SKILL_COMBOS = {}
    api.Log:Info("[CLP] WARNING: skill_combos.lua failed to load.")
end

local roleDataLoaded, ROLE_DATA = pcall(require, "/CombatLogPro/role_data")
if roleDataLoaded and ROLE_DATA then
    api.Log:Info("[CLP] Role data loaded.")
else
    ROLE_DATA = { GetRoleFromClass = function() return nil end, GetRoleFromClassTable = function() return nil end }
    api.Log:Info("[CLP] WARNING: role_data.lua failed to load.")
end

local skillIconsLoaded, SKILL_ICONS = pcall(require, "/CombatLogPro/skill_icons")
if skillIconsLoaded and type(SKILL_ICONS) == "table" then
    api.Log:Info("[CLP] Skill icons loaded.")
else
    SKILL_ICONS = {}
    api.Log:Info("[CLP] WARNING: skill_icons.lua failed to load.")
end

-- Ancestral-variant signatures (same-named skills with distinct icons -> detect the equipped
-- variant from combat behaviour and stamp its icon). See skill_variants.lua for the model.
local skillVariantsLoaded, SKILL_VARIANTS = pcall(require, "/CombatLogPro/skill_variants")
if skillVariantsLoaded and type(SKILL_VARIANTS) == "table" then
    api.Log:Info("[CLP] Skill variants loaded.")
else
    SKILL_VARIANTS = {}
    api.Log:Info("[CLP] WARNING: skill_variants.lua failed to load.")
end

local addon = {
    name = "CombatLogPro",
    author = "Cydaphex",
    desc = "Combat Log with separated heal tracking and debuff scanner",
    version = "2.0.0" -- 2.0 public release (== tested 1.0.214). Huge jump from public v1.0.5: history/archive redesign, Raid Meter, fight browser (PvE/PvP/Duel + filters + search), same-named-enemy drill-down, ancestral-variant icons, faction-relative name colours, overheal, scrollbars, environmental damage. Mitigation breakdown + untargeted HP% disabled by the 2026-06-18 game API lockdown.
}

-- [[ COMPATIBILITY PATCH ]] --
if LINE_HEIGHT == nil then LINE_HEIGHT = 16 end

-- ============================================================================
--  CC DATABASE & CONFIGURATION
-- ============================================================================

local ccList = {
    'Snare', 'Tripped', 'Stun', 'Impaled', 'Sleep', 'Sleeping', 'Fear', 'Petrification',
    'Poison Stun', 'Deep Freeze', 'Tripped (Strong)', 'Deep Sleep', 'Slow',
    'Freeze Up', "Alliance Soldier's Pull", 'Freeze of Evil Spirit', 'Freeze',
    'Bubble Trap', 'Wave Meteor Strike Hit', "Red Dragon's Wind Gust",
    'Hell Spear', 'Petrified', 'Dazed', 'Splashdown Bubble',
    'Strong Telekinesis', 'Telekinesis', 'Silence', "Alkaran's Curse",
    'Meteor Impact', 'Pulled', 'Disarmed', 'Horrorshow', 'Petrified Taunt',
    "Karim's Shackle", 'Shockstep Effect', "Agrax's Snare", 'Steel Trap',
    'Hammer Smash', 'Ice Wall', 'Earthen Grip', "Phantasm's Wail",
    "Ecktom's Shackle", 'Ice Shard', 'Bestial Leap', 'Explosive Ice',
    'Dizziness', 'Unconscious', 'Ice Shock', "Alexander's Powerful Freeze",
    "Trap!", 'Ice', 'Lava Trap Explosion', 'Howl of Terror', 'Eternal Silence',
    'Mana Force', 'Shock', 'Poor Landing', 'Paralyzed', 'Wraith Rooted',
    "Lost Tribe's Shockwave", 'Control', 'Lassitude', 'Shackle', 'Charm', 'Charmed',
    'Alarm Call', 'Distressed', 'Dissonance', 'Startling Strain'
}

local CC_DB = {}
for _, name in ipairs(ccList) do CC_DB[name] = true end

-- Non-combat buff/debuff filter (scanner + combat log ignores these)
-- Exact names (case-insensitive)
local IGNORE_BUFFS_RAW = {
    -- Rest / death
    "Clear Mind", "Rebirth Trauma", "Nui's Consolation", "Returning", "Regeneration",
    -- Food/drink (overflow from pattern misses)
    "Ouch, Hot!", "Ouch! Hot!", "Ouch!", "Hot!", "Well Fed", "Overfed",
    "Indigestion", "Rested", "Honey Mead", "Bubble Tea",
    "Hearty Meat", "Hearty Breakfast", "Hearty Soup", "Hearty Seed Soup",
    "Tangy Soda", "Tangy Liquor", "Refreshment", "Satiated", "Satiety",
    "Imperial Sausage", "Meatball Kebab", "Rib Kebab", "Sirloin Kebab",
    "Roast Meatballs", "Roast Ribs", "Roast Sirloin", "Sweet Golden Soup",
    "Smoked Ribs", "Golden Bacon", "Royal Ham", "Porcine Delight",
    "Jujube Juice", "Jujube Sparkling Wine", "Mysterious Wine", "Rum Runner",
    "Red Wine Vinegar", "Fruit Punch", "Milk Chocolate", "Milked Up",
    "Feast of Arcane Grace", "Feast of Noble Blessings",
    -- Movement / utility cooldowns
    "Dash", "Power Dash", "Double-Time", "Run!",
    "Glider Cooldown", "Glider CD", "Dash Cooldown",
    "Overachieving", "Portal Cooldown", "Recalled",
    "Pack Carrier", "Carrying a Trade Pack", "Overburdened",
    "Dawdling", "Meditation", "Play Dead",
    -- Equip passives
    "Equip Shield", "Equip Dual Weapons", "Equip Two-Handed Weapon",
    "Equip Dive Helmet", "Equip Swimfins",
    -- Vocation / profession
    "Good Day to Work", "Vocation Hastener Scroll", "Vocational Tonic",
    "Fishing for a Compliment", "Anyfin is Possible", "Barter $auce",
    "So Basalty", "Stainless Steal", "Martial Arts and Crafts",
    "Grain Reaper", "Transformative Farmer", "Foremost Forager",
    "Pickaxe Percussionist", "Wild Trout Clout", "Darns It All",
    "Krilling It", "Can Be Abrasive", "Truly Cathletic",
    "Needs Calf-eine", "Wool Sheared", "Bored Sheep", "Hungry Sheep",
    -- XP / loot / misc passive
    "Wayfarer", "XP Boost Potion", "Elixir of Greed", "Mischievous",
    "Luke's Helping Hand", "Daru Blessing", "Grand Loot Macaron",
    -- Swimming / diving / exploration
    "Desert Fox's Gaze", "Abyssal Archaeologist",
    "Increases Continental Dialect Proficiency",
    -- Ship / vehicle
    "Rowing", "Lowering Anchor",
    -- Honor / titles
    "ArcheMaster", "Enlightened ArcheMaster", "Grand Master",
    "The Professional", "Expert Cutpurse", "Victory Delegate",
    -- Territory blessings (specific)
    "Andrion II's Blessing", "Andrion II's Protection",
    "Amarendra IV's Blessing", "Amarendra IV's Protection",
    "Morpheus's Blessing", "Morpheus's Protection",
    -- Non-combat debuffs
    "Hangover", "Headache", "Preparing Glider",
    "Flight Speed Boost Cooldown", "Twilight Stealth Cooldown",
    "Wind Winner Disabled", "All Spooked Out",
    "Rough Sea Winds", "Unable to Shear",
    -- Tester-reported log spam (status flags + mana-restore proc trinkets)
    "Wanted", "Heroic Grandeur", "Calleil's Memory",
    -- Fishing minigame: the action "skills" log as Magic damage vs the hooked fish,
    -- which spawns a fake fight (Pink Pufferfish etc). Filtered here so fishing never
    -- creates a combat log. Re-enable via the Filter Manager's "Show Defaults" if wanted.
    "Stand Firm Left", "Stand Firm Right", "Give Slack", "Reel In", "Big Reel In",
    "Strength Contest", "Suspended",
}
local IGNORE_LOOKUP = {}
for _, name in ipairs(IGNORE_BUFFS_RAW) do
    IGNORE_LOOKUP[string.lower(name)] = true
end

-- Patterns that catch broad categories by keyword (lowercase)
local IGNORE_PATTERNS = {
    -- Food / drink / regen
    "food buff", "cuisine", "stew", "soup", "kebab",
    "rank %d+ food", "level %d+ effect",
    "hp recovery", "mp recovery", "mana recovery",
    "health regen", "mana regen", "hp regen", "mp regen",
    -- Gear set bonuses (Celestial/Epic/Divine/etc. Cloth/Leather/Plate Armor)
    "cloth armor", "leather armor", "plate armor",
    "cloth set", "leather set", "plate set",
    -- God/faction energy buffs (Kyprosa's Energy, Eanna's Incarnation, etc.)
    "'s energy", "'s incarnation",
    -- Mana-restore proc trinkets (Calleil's Memory, Anthalon's Memory, etc.)
    "'s memory",
    -- Zone/territory blessings
    "hero's blessing", "work permit",
    -- Equip passives
    "equip ",
    -- Glider / flight
    "glider", "fuel injection", "crystal wings", "dragon wings",
    "flaming pinion", "pinion",
    -- Costumes / merchant
    "dawnsdrop costume", "merchant's costume",
    -- Honor / military ranks
    "goblet of honor", "rank %d+ soldier", "rank %d+ knight",
    -- Spellbooks / runes
    "spellbook:", "blessed rune:", "combined rune",
    -- Ship / sailing
    "unfurl", "forewind", "mainsail", "foresail",
    -- Vocation
    "vocational", "vocation ",
    -- Potions (minor)
    "minor healing potion", "minor mana potion",
}

-- Player-extensible filter: anyone can add their own buff/skill names in
-- user_filters.lua (no editing of main.lua) -- merged into the lookups above.
-- Accepts either a plain array of names, or { names = {...}, patterns = {...} }.
-- Wrapped in a do-block so its locals free their slots immediately (the main chunk
-- runs near Lua 5.1's 200-active-locals limit, so we don't leave these lingering).
do
    local userFiltersLoaded, USER_FILTERS = pcall(require, "/CombatLogPro/user_filters")
    if userFiltersLoaded and type(USER_FILTERS) == "table" then
        local names = USER_FILTERS.names or USER_FILTERS
        if type(names) == "table" then
            for _, name in ipairs(names) do
                if type(name) == "string" and name ~= "" then
                    IGNORE_LOOKUP[string.lower(name)] = true
                end
            end
        end
        if type(USER_FILTERS.patterns) == "table" then
            for _, pat in ipairs(USER_FILTERS.patterns) do
                if type(pat) == "string" and pat ~= "" then
                    IGNORE_PATTERNS[#IGNORE_PATTERNS + 1] = string.lower(pat)
                end
            end
        end
    end
end

local isIgnoredCache = {}
local function IsIgnoredBuff(name)
    local cached = isIgnoredCache[name]
    if cached ~= nil then return cached end
    local lower = string.lower(name)
    local result = false
    -- IGNORE_LOOKUP is tri-state: true = filtered (built-in or custom), false = a default
    -- the player explicitly DISABLED in the Filter Manager (force-allow, overrides patterns
    -- too), nil = not a known name (fall through to keyword patterns).
    local v = IGNORE_LOOKUP[lower]
    if v == false then
        result = false
    elseif v then
        result = true
    else
        for _, pat in ipairs(IGNORE_PATTERNS) do
            if string.find(lower, pat) then result = true; break end
        end
    end
    isIgnoredCache[name] = result
    return result
end

local CONFIG = {
    LIVE_WIDTH = 400,
    LIVE_HEIGHT = 480,
    HIST_WIDTH = 850,
    HIST_HEIGHT = 500,
    SIDEBAR_WIDTH = 230,
    BUTTON_WIDTH = 180,
    VISIBLE_ROWS_HIST = 16, -- 16 rows fit below the header(30) + toggle bar(28) in a 500px window
    VISIBLE_ROWS_LIVE = 24,
    SESSIONS_VISIBLE = 12,
    LINE_HEIGHT = 18,
    HIST_ROW_H = 26,
    RECAP_ICON_X = 185,  -- x of the inline icon on recap rows: "[time] Source —> [icon] Skill ±N" (wide enough for full names)
    COMBAT_WAIT = 4000,
    DOT_WAIT = 3000,
    COL_OUT_NRM    = {1, 0.5, 0},     -- Orange
    COL_OUT_CRIT   = {1, 0, 0},       -- Red
    COL_INCOMING   = {1, 0.5, 0},     -- Orange
    COL_HEAL       = {0, 1, 0},       -- Green
    COL_CC         = {0.8, 0.3, 1},   -- Purple
    COL_ZEAL_CRIT  = {1, 0.3, 1},     -- Bright purple for Zeal crit damage line
    COL_SKILL_LABEL= {0, 1, 1},       -- Cyan for skill/ability name lines
    SCAN_FREQ = 200,        -- debuff/buff scanner interval in ms (100=fast, 200=default, 500=low)
    ENABLE_SCANNER = true,
    SHOW_TIMESTAMP = true,
    TIME_OFFSET = -6,
    DEBUG_UNITINFO  = false, -- set true once to probe UnitInfo magic field names
    DEBUG_EVENTS    = false, -- set true once to discover chat debuff event name
    DEBUG_HITTYPE   = false, -- set true to log raw args for negated hit events (DODGE/BLOCK/MISS/PARRY)
    DUMP_BUFFS      = false, -- set true once to dump all player buffs to file (activate while chanty is up)
    RAID_METER      = true,  -- per-fight Raid Meter: a leaderboard of your RAID's dmg/heal in the history fight-detail. ALWAYS ON (no toggle). Needs the client's "Damage/Heal Info: Target = Raid" or higher to include teammates.
    LOG_UNKNOWN_INCOMING = false, -- log first occurrence of each incoming ability to incoming_abilities.txt; notify in live log if unclassified
    SHOW_HEALS          = true, -- ALWAYS ON (no toggle): heals always logged. Hide them per-fight via the history window's TYPE: Healing filter. (Gates kept for safety; flag never flips now.)
    SHOW_ICONS          = true, -- show skill icons in the live feed (and history rows)
    MIT_BREAKDOWN       = false, -- outgoing per-type Mitigation & pen breakdown (def/resist/toughness/avoidance/pen/hit/modifiers). API-DEAD since 2026-06-18 (needs enemy UnitInfo/UnitModifierInfo, blocked) -> OFF. Flip true if Aguru re-allows enemy stats for the "target" token. Code preserved, gated.
    LIVE_OPEN           = true, -- remember if the live window was open/closed last session; restored on login
    -- Fight-view three-axis filter (WHO x WHAT x DIR). Default all on. A line shows when its WHAT
    -- is on AND (source side: sw + Dealt) OR (target side: tw + Taken) is enabled.
    F_WHO_ME            = true,
    F_WHO_ALLY          = true,
    F_WHO_ENEMY         = true,
    F_WHO_MOB           = true,
    F_WHAT_DMG          = true,
    F_WHAT_HEAL         = true,
    F_DIR_DEALT         = true,
    F_DIR_TAKEN         = true,
    DEBUG_ZERO_HITS     = false, -- set true to dump target buff names on unexplained 0-damage hits (find mount/glider buff names)
    DUMP_RHYTHM         = false, -- auto-captures UnitInfo stats at each new Rhythm stack count; set false when done
    LOG_ALLY_RECAP      = true,  -- master gate for recording OTHER units' combat (per-class via REC_ALLY/ENEMY/MOB)
    REC_ALLY            = true,  -- capture toggle: record allies' combat (floodgates)
    REC_ENEMY           = true,  -- capture toggle: record enemy players' combat
    REC_MOB             = true,  -- capture toggle: record mobs' combat
    SPECTATE            = true,  -- ALWAYS ON (no toggle): sessions bracket off OTHERS' combat even when you don't participate (raid-logging). Only has data when the feed carries others' combat -- Damage/Heal Info: Target = Raid+ (Game Settings > Game Info).
}

local PALETTE = {
    Yellow = {1, 1, 0, 1}, Red = {1, 0, 0, 1}, Green = {0, 1, 0, 1},
    Cyan = {0, 1, 1, 1}, Blue = {0.3, 0.3, 1, 1}, White = {1, 1, 1, 1},
    Orange = {1, 0.5, 0, 1}, Purple = {0.8, 0.3, 1, 1}, Black = {0, 0, 0, 1},
    WarmRed = {1, 0.65, 0, 1},      -- normal outgoing hit (neon amber-orange)
    SkyBlue = {0, 1, 1, 1},           -- skill/ability name lines (pure cyan/neon)
}

-- Layered grayscale: header lightest (top bar), sidebar mid, body/log soft near-black.
-- Intentional stepped shades give depth without leaving the black/gray theme.
local COL_HEADER  = {0.14, 0.14, 0.14, 1.0}
local COL_SIDEBAR = {0.10, 0.10, 0.10, 0.97}
local COL_BODY    = {0.05, 0.05, 0.05, 0.92}
local COL_LOG_BG  = {0.05, 0.05, 0.05, 1.0}
local COL_BTN_RED = {0.55, 0.20, 0.20, 1.0}

-- ============================================================================
--  VARIABLES & STATE
-- ============================================================================

local wLive, wHistory, wOptions, wButton
local liveLabels, historyLabels, liveIcons = {}, {}, {}
local historyIcons = {}  -- parallel icon pool for the ARCHIVE rich-row render
local sessionButtons = {}
local lblSessionCount, liveTitleLabel, liveBodyWidget
local isMinimized = false

local liveBuffer, displayBuffer, masterBuffer, allSessions = {}, {}, {}, {}
local currentSessionLogs, sessionByTarget = {}, {}
local logScrollOffset, sessionScrollOffset = 0, 0
local scrollTrack, scrollThumb  -- history-log scrollbar (track + draggable thumb)
local sessTrack, sessThumb      -- session-list (sidebar) scrollbar
local viewingMode = "LIVE"
local liveLayoutDirty = true  -- set true when window dimensions change; RebuildLiveLabels skips layout when false

local activeDots = {} 
local fightData = { outgoing = {}, incoming = {} }
local healData = { done = {}, received = {} }
local healSessionByTarget = {}
local timeSinceLastAction = 0 
local inCombat = false
local PLAYER_NAME = "Unknown"
local PLAYER_UNIT_ID = ""
local lastIncomingSourceId = nil  -- set by COMBAT_TEXT, consumed by next COMBAT_MSG incoming hit
local nameCheckTimer = 0 

local activeDebuffsCache = {}
local activeCCSessions = {}
local buffNameCache = {}
local buffEffectCache = {}      -- buff_id -> parsed effect flags (invincible, spellShield, etc.)
local playerBuffStackCache = {} -- buffName -> stack count, refreshed each scanner tick

-- Buff names (exact, case-insensitive) that grant invincibility from mount/glider abilities.
-- Tooltip text matching often misses these since their descriptions vary.
-- Add more here after inspecting buffs in-game.
local KNOWN_INVINCIBLE_BUFF_NAMES = {
    ["dash"]              = true,  -- mount Dash ability (most mounts)
    ["gliding"]           = true,  -- glider deployment / glider flight state
    ["aerial evasion"]    = true,  -- glider evasion skill
    ["glider deployment"] = true,  -- glider launch animation window
    ["launch"]            = true,  -- glider launch
    ["takeoff"]           = true,  -- some glider launch variants
}

-- Buff names applied by the game when a mock duel (mock fight) concludes.
local DUEL_END_BUFF_NAMES = {
    ["mock fight win"] = true,
    ["mock fight end"] = true,
}
local lastTargetID = nil
local scannerTimer = 0
-- Ally Damage Recap state
local recapData = {}        -- allyName -> { name = allyName, logs = { {text,r,g,b,time,hpPct,dead}, ... } }
local allyRoster = {}       -- lowercased member name -> team tag ("team1".."team50")
local allyRosterTimer = 0   -- ms accumulator for periodic roster rebuilds
local lastTargetBuffCount = -1  -- used to skip re-scan when buff count unchanged

-- Incoming ability logger state (LOG_UNKNOWN_INCOMING)
local seenIncomingSkills = {}
local incomingSkillLoaded = false
local incomingSkillFile = "CombatLogPro/incoming_abilities.txt"

-- Last cast skill from SPELLCAST_SUCCEEDED (patch 243+) for pre-classification
local lastPlayerCast = nil

-- Skill currently being cast (set on SPELLCAST_START, cleared on SPELLCAST_SUCCEEDED/STOP)
local currentCast = nil
-- Whether the target is currently targeting the player (updated by TARGET_TO_TARGET_CHANGED)
local targetIsTargetingPlayerLive = false

-- Target buff effect cache (updated by scanner, read by combat handler)
local targetBuffEffects = {
    invincible = false,
    spellShieldPct = 0,   -- e.g. 200 for Glenn's Spell Shield
    runeConvertPct = 0,   -- e.g. 3.5 for Zena Basta
    runeConvertName = nil, -- buff name for display
    dmgShield = false,     -- damage absorb shield active
    dmgShieldMax = 0,      -- max absorb amount
    dmgShieldName = nil,   -- buff name
}

-- Zeal tracking (buff_id 495)
local zealActive    = false
local rhythmDumpLastStacks = -1  -- tracks last seen Rhythm stack count for DUMP_RHYTHM
local zealStartTime = nil
local fightZealTime = 0

local chantyActive          = false
local currentSpellDmgMul    = 0     -- spell_damage_mul from last scanner tick
local baselineSpellDmgMul   = nil   -- spell_damage_mul when chanty is not active
local chantySpellBonus       = 0    -- current chanty contribution (current - baseline)

local bulwarkActive         = false
local currentArmor          = 0
local currentMagicResist    = 0
local baselineArmor         = nil
local baselineMagicResist   = nil
local bulwarkArmorBonus     = 0
local bulwarkResistBonus    = 0

local currentSpellDps     = 0
local currentBattleResist = 0
local incDmgStats = { spellMul=0, meleeMul=0, rangedMul=0, spellVal=0, meleeVal=0, rangedVal=0 }
local rhythmStacks          = 0     -- current Rhythm buff stack count
local RHYTHM_DPS_PER_STACK  = 7.0  -- confirmed from dump: spell_dps rises exactly +7 per stack

-- Grouped skill-bonus tracking table (1 upvalue instead of many separate locals)
-- All per-scan state for stacking/active mechanics lives here.
local bonuses = {
    -- Magic Circle (Sorcery): boosts spell_dps; contribution isolated from Rhythm via baseline
    magicCircleActive    = false,
    magicCircleDpsBonus  = 0,
    baseSpellDps         = nil,   -- set when neither Rhythm nor Magic Circle is active
    -- Delirium (Battlerage): +2%/stack melee & ranged dmg
    deliriumStacks       = 0,
    -- Burning Brand (Occultism): +2%/stack magic dmg
    burningBrandStacks   = 0,
    -- Overpowered Spell Locus (Occultism): fixed +15% all skill dmg
    overpoweredActive    = false,
    -- Assassination (Shadowplay): fixed +12% all skill dmg
    assassinationActive  = false,
    -- Battle Focus (Battlerage): +20% melee crit dmg (baked into critExtra via stat snapshot)
    battleFocusActive    = false,
    -- Intensified Harm (Occultism): +25% all crit dmg (baked into critExtra via stat snapshot)
    intensifiedHarmActive = false,
    -- Inspired (Auramancy): +52%/stack bonus to Vicious Implosion
    inspiredStacks       = 0,
}

-- ParseCombatMessage availability check (done once at load, not per event)
local _parseCombatMessage = ParseCombatMessage
local _parseAvailable = (type(_parseCombatMessage) == "function")

-- Timer State
local BASE_SECONDS_OF_DAY = 0
local BASE_APP_MSEC = 0
local TIME_INITIALIZED = false
local cachedTimestamp = "[..:..:..] "  -- updated once per OnUpdate tick
local frameNow = 0                     -- api.Time:GetUiMsec() cached per frame

-- Settings & Position Persistence
local SETTINGS_FILE = "CombatLogPro/settings.txt"
local savedSettings = {}

-- Single source of truth for persisted CONFIG options: saveKey -> CONFIG field.
-- Both LoadSavedSettings and SaveSettings iterate this list, so an option can
-- never again be saved-but-not-loaded (or vice versa) due to the two lists drifting.
-- Window positions are handled separately (they read from widgets, not CONFIG).
local SETTINGS_SCHEMA = {
    { key = "liveW",             field = "LIVE_WIDTH"          },
    { key = "liveH",             field = "LIVE_HEIGHT"         },
    { key = "scanFreq",          field = "SCAN_FREQ"           },
    { key = "showIcons",         field = "SHOW_ICONS"          },
    { key = "liveOpen",          field = "LIVE_OPEN"           },
    { key = "enableScanner",     field = "ENABLE_SCANNER"      },
    { key = "showTimestamp",     field = "SHOW_TIMESTAMP"      },
    { key = "timeOffset",        field = "TIME_OFFSET"         },
    { key = "logAllyRecap",      field = "LOG_ALLY_RECAP"      },
    { key = "recAlly",           field = "REC_ALLY"            },
    { key = "recEnemy",          field = "REC_ENEMY"           },
    { key = "recMob",            field = "REC_MOB"             },
    { key = "fWhoMe",            field = "F_WHO_ME"            },
    { key = "fWhoAlly",          field = "F_WHO_ALLY"          },
    { key = "fWhoEnemy",         field = "F_WHO_ENEMY"         },
    { key = "fWhoMob",           field = "F_WHO_MOB"           },
    { key = "fWhatDmg",          field = "F_WHAT_DMG"          },
    { key = "fWhatHeal",         field = "F_WHAT_HEAL"         },
    { key = "fDirDealt",         field = "F_DIR_DEALT"         },
    { key = "fDirTaken",         field = "F_DIR_TAKEN"         },
    { key = "colOutNrm",         field = "COL_OUT_NRM"         },
    { key = "colOutCrit",        field = "COL_OUT_CRIT"        },
    { key = "colInc",            field = "COL_INCOMING"        },
    { key = "colHeal",           field = "COL_HEAL"            },
    { key = "colCC",             field = "COL_CC"              },
    { key = "colZealCrit",       field = "COL_ZEAL_CRIT"       },
    { key = "colSkillLbl",       field = "COL_SKILL_LABEL"     },
}

local function LoadSavedSettings()
    -- Stored on CONFIG (not a new file-scope local) to respect Lua's 200-locals limit.
    CONFIG._customFilters = {}
    local data = api.File:Read(SETTINGS_FILE)
    if data and type(data) == "table" then
        savedSettings = data
        -- ~= nil (not truthiness) so saved `false` booleans still apply
        for _, e in ipairs(SETTINGS_SCHEMA) do
            if data[e.key] ~= nil then CONFIG[e.field] = data[e.key] end
        end
        -- Restore the player's in-game custom log filters: merge into IGNORE_LOOKUP
        -- (the single source IsIgnoredBuff checks) and keep an ordered display list.
        if type(data.customFilters) == "table" then
            for _, nm in ipairs(data.customFilters) do
                local ln = (type(nm) == "string" and nm ~= "") and string.lower(nm) or nil
                if ln and not IGNORE_LOOKUP[ln] then
                    IGNORE_LOOKUP[ln] = true
                    CONFIG._customFilters[#CONFIG._customFilters + 1] = nm
                end
            end
        end
        -- Restore defaults the player DISABLED (tri-state false = force-allow). These live
        -- here in settings.txt, not main.lua, so they persist across addon updates.
        if type(data.disabledDefaults) == "table" then
            for _, nm in ipairs(data.disabledDefaults) do
                if type(nm) == "string" and nm ~= "" then IGNORE_LOOKUP[string.lower(nm)] = false end
            end
        end
        if data.showDefaults ~= nil then CONFIG._showDefaults = data.showDefaults end
    end
end

local function SaveSettings()
    local s = {}
    -- Window positions read live from the widgets
    if wButton  then s.btnX,  s.btnY  = wButton:GetOffset()  end
    if wLive    then s.liveX, s.liveY = wLive:GetOffset()    end
    if wHistory then s.histX, s.histY = wHistory:GetOffset() end
    -- CONFIG-backed options
    for _, e in ipairs(SETTINGS_SCHEMA) do
        s[e.key] = CONFIG[e.field]
    end
    s.customFilters = CONFIG._customFilters   -- player's in-game custom log filters
    -- Defaults the player disabled = IGNORE_LOOKUP entries flagged false.
    local dis = {}
    for k, v in pairs(IGNORE_LOOKUP) do if v == false then dis[#dis + 1] = k end end
    s.disabledDefaults = dis
    s.showDefaults = CONFIG._showDefaults
    pcall(function() api.File:Write(SETTINGS_FILE, s) end)
end

local dotSkills = {
    -- Actual DoT debuffs that tick over time
    ["Electric Shock"] = true, ["Conflagration"] = true, ["Burning"] = true,
    ["Poison"] = true, ["Bleed"] = true, ["Bleeding"] = true,
    ["Deep Wound"] = true, ["Venom"] = true, ["Curse"] = true,
    -- Removed: Meteor Strike (AoE hit), Toxic Shot (direct), Piercing Shot (direct),
    -- Stalker's Mark (debuff), Summon Crows (channeled AoE), Flame Barrier (reactive)
}

-- Skill damage type table: authoritative data from game JSON (skill_damage_types.lua),
-- merged with supplemental entries for custom content, procs, and DoT debuff names.
local SKILL_DAMAGE_TYPES = skillTypesLoaded and skillTypesData or {}
-- Basic Combat attacks aren't in the skillcalc data and arrive as SPELL_DAMAGE, so without an
-- explicit type they fall through to the "SPELL -> Magic" guess (e.g. Shoot Arrow tagged Magic).
-- They're physical; pin them. (Override table is checked before the auto-learned cache.)
SKILL_DAMAGE_TYPES["Shoot Arrow"]   = "Ranged"
SKILL_DAMAGE_TYPES["Ranged Attack"] = "Ranged"
SKILL_DAMAGE_TYPES["Kick"]          = "Melee"
SKILL_DAMAGE_TYPES["Melee Attack"]  = "Melee"
SKILL_DAMAGE_TYPES["Auto Attack"]   = "Melee"

-- Maps skill name -> skill tree name, used to infer observed trees from combat log.
local SKILL_TO_TREE = {
    -- Battlerage
    ["Triple Slash"]       = "Battlerage", ["Charge"]             = "Battlerage",
    ["Whirlwind Slash"]    = "Battlerage", ["Sunder Earth"]       = "Battlerage",
    ["Precision Strike"]   = "Battlerage", ["Tiger Strike"]       = "Battlerage",
    ["Behind Enemy Lines"] = "Battlerage", ["Swordfall"]          = "Battlerage",
    ["Shadowsmite"]        = "Battlerage",
    -- Witchcraft
    ["Earthen Grip"]       = "Witchcraft", ["Enervate"]           = "Witchcraft",
    ["Focal Concussion"]   = "Witchcraft", ["Dahuta's Breath"]    = "Witchcraft",
    -- Defense
    ["Shield Slam"]        = "Defense",    ["Bull Rush"]          = "Defense",
    ["Ollo's Hammer"]      = "Defense",    ["Shield Throw"]       = "Defense",
    -- Auramancy
    ["Comet's Boon"]       = "Auramancy",  ["Vicious Implosion"]  = "Auramancy",
    ["Crushing Grasp"]     = "Auramancy",  ["Abyssal Wave"]       = "Auramancy",
    -- Shadowplay
    ["Rapid Strike"]       = "Shadowplay", ["Overwhelm"]          = "Shadowplay",
    ["Wallop"]             = "Shadowplay", ["Stalker's Mark"]     = "Shadowplay",
    ["Toxic Shot"]         = "Shadowplay", ["Pin Down"]           = "Shadowplay",
    ["Throw Dagger"]       = "Shadowplay", ["Venom Blades"]       = "Shadowplay",
    -- Archery
    ["Charged Bolt"]       = "Archery",    ["Piercing Shot"]      = "Archery",
    ["Endless Arrows"]     = "Archery",    ["Boneyard"]           = "Archery",
    ["Concussive Arrow"]   = "Archery",    ["Missile Rain"]       = "Archery",
    ["Snipe"]              = "Archery",    ["Hunting Pack"]       = "Archery",
    ["Blazing Arrow"]      = "Archery",    ["Double Recurve"]     = "Archery",
    -- Sorcery
    ["Flamebolt"]          = "Sorcery",    ["Freezing Arrow"]     = "Sorcery",
    ["Arc Lightning"]      = "Sorcery",    ["Freezing Earth"]     = "Sorcery",
    ["Searing Rain"]       = "Sorcery",    ["Chain Lightning"]    = "Sorcery",
    ["Flame Barrier"]      = "Sorcery",    ["Meteor Strike"]      = "Sorcery",
    ["Gods' Whip"]         = "Sorcery",    ["Serpent Strike"]     = "Sorcery",
    -- Occultism
    ["Mana Stars"]         = "Occultism",  ["Mana Force"]         = "Occultism",
    ["Hell Spear"]         = "Occultism",  ["Hell Spears"]        = "Occultism",
    ["Absorb Lifeforce"]   = "Occultism",  ["Summon Crows"]       = "Occultism",
    ["Crippling Mire"]     = "Occultism",  ["Summon Wraith"]      = "Occultism",
    ["Death's Vengeance"]  = "Occultism",  ["Cursed Thorns"]      = "Occultism",
    -- Songcraft
    ["Critical Discord"]   = "Songcraft",  ["Dissonance"]         = "Songcraft",
    -- Vitalism
    ["Holy Bolt"]          = "Vitalism",   ["Antithesis"]         = "Vitalism",
    ["Skewer"]             = "Vitalism",
    -- Malediction (custom server)
    ["Malicious Binding"]  = "Malediction", ["Crashing Waves"]   = "Malediction",
    ["Serpent Glare"]      = "Malediction", ["Blazing Ward"]      = "Malediction",
}

-- SKILL_COMBOS loaded from skill_combos.lua at the top of this file.


-- Skills with their own backstab bonus (on top of the player's passive backattack stat).
-- Auto-populated from SKILL_DATA (skill_data.lua, generated from aa-classic.com JSON).
-- formula: the "Backstabbing..." sentence from the skill description.
-- stealth: additional % damage bonus when caster is Stealthed (from in-game observation, not in JSON).
local SKILL_BACKSTAB_BONUSES = {}
do
    local STEALTH_OVERRIDES = {
        ["Shadowsmite"] = 98,  -- observed in-game: +98% when Stealthed
    }
    for name, info in pairs(SKILL_DATA) do
        if info.backstab then
            SKILL_BACKSTAB_BONUSES[name] = { formula = info.backstab, stealth = STEALTH_OVERRIDES[name] }
        end
    end
    -- Fallback if skill_data.lua failed to load
    if not skillDataLoaded then
        SKILL_BACKSTAB_BONUSES["Shadowsmite"]  = { formula = "Backstabbing adds Physical Damage equal to 400% of Melee Attack.", stealth = 98 }
        SKILL_BACKSTAB_BONUSES["Rapid Strike"] = { formula = "Backstabbing increases Melee Critical Rate +50%." }
        SKILL_BACKSTAB_BONUSES["Pin Down"]     = { formula = "Backstabbing inflicts Bleeding on the target." }
    end
end

-- Supplemental entries are now included directly in skill_damage_types.lua (SUPPLEMENTAL section).

-- Auto-learned cache: when a skill not in the table is inferred from mitigation,
-- the result is cached here so subsequent hits are consistent.
local skillTypeCache = {}

-- Short display labels for damage type tags in log lines
local TYPE_SHORT = { Magic="Magic", Physical="Phys", Melee="Melee", Ranged="Ranged", Spell="Magic" }

-- ============================================================================
--  HELPER FUNCTIONS
-- ============================================================================

-- Rebuilds the lowercased name -> "teamN" map for the current party/raid.
-- team1..team50 are valid unit tags (api-docs-patch243.lua:700-705); pcall-guarded
-- because tags for empty slots / when solo return nothing.
-- name(lower) -> role, used for the sessions-list role icon. On CONFIG (no new local;
-- the main chunk is at Lua's 200-local cap). Resolves role the robust way -- from the
-- unit's skillset table (GetUnitInfoById().class) like Enhanced_X_UP_Plus does -- and
-- falls back to the class-name lookup. roleOf is a local of this function, so it costs
-- no main-chunk local. Cache-once per name; nil results retry on a later refresh.
local function RefreshAllyRoster()
    local newRoster = {}
    local n = 0
    CONFIG._nameRole = CONFIG._nameRole or {}
    CONFIG._nameClassTbl = CONFIG._nameClassTbl or {}   -- name -> {skillsetId,...} for class icons
    -- Resolve+cache a unit's skillset table (for the 3 class icons) and role (fallback
    -- glyph). Local to this function, so it costs no main-chunk local. Cache-once.
    local function capture(tag, lname)
        if CONFIG._nameClassTbl[lname] then return end  -- have icons; keep retrying until we do
        local okId, uid = pcall(function() return api.Unit:GetUnitId(tag) end)
        if okId and uid then
            local okI, info = pcall(function() return api.Unit:GetUnitInfoById(uid) end)
            if okI and type(info) == "table" and type(info.class) == "table" then
                local ids = {}
                for _, v in pairs(info.class) do
                    local id = tonumber(v); if id and id >= 1 and id <= 10 then ids[#ids + 1] = id end
                end
                if #ids > 0 then
                    CONFIG._nameClassTbl[lname] = ids
                    CONFIG._nameRole[lname] = ROLE_DATA.GetRoleFromClassTable(ids)
                    return
                end
            end
        end
        -- Fallback: class-name lookup gives a role (named tanks/healers, else dps), no icons.
        local okC, cls = pcall(function() return api.Ability:GetUnitClassName(tag) end)
        if okC and cls and cls ~= "" and tostring(cls):lower() ~= "pending" then
            CONFIG._nameRole[lname] = ROLE_DATA.GetRoleFromClass(tostring(cls))
        end
    end
    for i = 1, 50 do
        local tag = "team" .. i
        local ok, nm = pcall(function() return api.Unit:UnitName(tag) end)
        if ok and nm and nm ~= "" then
            newRoster[string.lower(nm)] = tag
            n = n + 1
            capture(tag, string.lower(nm))
        end
    end
    -- Your own build too (for self-heal sessions listed under your name)
    local okP, pn = pcall(function() return api.Unit:UnitName("player") end)
    if okP and pn and pn ~= "" then capture("player", string.lower(pn)) end
    allyRoster = newRoster
    return n
end

-- Returns the "teamN" tag for a party/raid member name, or nil if not grouped with them.
local function GetAllyTag(name)
    if not name then return nil end
    return allyRoster[string.lower(name)]
end

-- Classify a unit by name (cached on CONFIG._nameType): "ally" (your party/raid roster),
-- "enemy" (a hostile PLAYER) or "mob" (non-player). Ally is exact. Enemy-vs-mob is best-effort:
-- when we have the unit's id we read its class table (players carry skillset ids, mobs don't);
-- without an id we fall back to a name heuristic and DON'T cache, so it upgrades once the id is seen.
CONFIG._classifyUnit = function(name, unitId)
    if not name or name == "" or name == "Unknown" then return "mob" end
    local ln = string.lower(name)
    CONFIG._nameType = CONFIG._nameType or {}
    local cached = CONFIG._nameType[ln]
    if cached then return cached end
    if GetAllyTag(name) then CONFIG._nameType[ln] = "ally"; return "ally" end
    if unitId and unitId ~= "0" and unitId ~= "" then
        local okI, info = pcall(function() return api.Unit:GetUnitInfoById(unitId) end)
        if okI and type(info) == "table" then
            local ut = string.lower(tostring(info.type or ""))
            -- Mount/pet detection off the unit's TYPE (same id table). CONFIRMED via type_probe: a
            -- mount/battle-pet reports type=="mate" by id (e.g. "Stormwraith Kirin"). It's buff-immune
            -- and readable for ANY feed unit -- unlike move_speed, which came back nil by id (and
            -- varies per mount + with buffs anyway). mount/slave/vehicle kept as defensive extras.
            if ut == "mate" or ut:find("mount", 1, true) or ut:find("slave", 1, true) or ut:find("vehicle", 1, true) then
                CONFIG._nameMount = CONFIG._nameMount or {}; CONFIG._nameMount[ln] = true
            end
            -- type "character" = a real player; faction "friendly"/"hostile" splits ally vs enemy.
            -- Anything else with a unit table (npc/monster) is a mob. Proven reliable via the probe.
            if ut == "character" then
                local who = (tostring(info.faction) == "hostile") and "enemy" or "ally"
                CONFIG._nameType[ln] = who; return who
            elseif info.type ~= nil then
                CONFIG._nameType[ln] = "mob"; return "mob"
            end
        end
    end
    return (string.find(name, " ") and "mob") or "enemy"  -- heuristic; uncached so it can upgrade
end

-- Faction -> "side" map for RELATIVE enemy colouring (pink vs red). The game colours nameplates
-- relative to YOU, so we mirror it: same side = green, then pink/red depends on both your faction
-- and theirs. EDIT THIS to add player-nations; anything unmapped falls back to red. Keys lowercase.
CONFIG._factionSide = {
    ["pirate"]            = "pirate",
    ["nuia"]              = "west",
    ["haranya"]           = "east",
    ["dreamwaker exiles"] = "west",   -- confirmed (your nation)
    ["crescent throne"]   = "east",   -- Haranya capital (best guess -- correct if wrong)
    -- ["andelph"]        = "west/east",   -- add the rest as you confirm them
}
-- Resolve the player's own side once (GetFactionName("player") works for the local player). Retries
-- until it returns a value, so a not-yet-loaded read doesn't lock in a wrong answer.
CONFIG._resolvePlayerSide = function()
    if CONFIG._playerSide then return end
    local okPF, pf = pcall(function() return api.Unit:GetFactionName("player") end)
    if okPF and pf and pf ~= "" then
        CONFIG._playerFaction = tostring(pf)
        CONFIG._playerSide = CONFIG._factionSide[string.lower(CONFIG._playerFaction)] or "nation"
    end
end
-- Colour for a HOSTILE unit, relative to your faction. Pirate viewer: East=pink, West=red.
-- Nation viewer: enemy Pirate=pink, everyone else=red. Unknown faction -> red. Returns r,g,b.
CONFIG._enemyColor = function(fac)
    CONFIG._resolvePlayerSide()
    local side = fac and CONFIG._factionSide[string.lower(tostring(fac))] or nil
    if CONFIG._playerSide == "pirate" then
        if side == "east" then return 0.945, 0.482, 0.722 end   -- pink #F17BB8
        return 1.000, 0.275, 0.275                              -- red  #FF4646 (west / unknown)
    else
        if side == "pirate" then return 0.945, 0.482, 0.722 end -- pink #F17BB8
        return 1.000, 0.275, 0.275                              -- red  #FF4646
    end
end

local function GetTimestamp()
    return cachedTimestamp
end

local function RefreshTimestamp(nowMsec)
    frameNow = nowMsec
    if not TIME_INITIALIZED then cachedTimestamp = "[..:..:..] "; return end
    local elapsedSec = (nowMsec - BASE_APP_MSEC) / 1000
    local totalSec = (BASE_SECONDS_OF_DAY + elapsedSec + (CONFIG.TIME_OFFSET * 3600)) % 86400
    if totalSec < 0 then totalSec = totalSec + 86400 end
    local h = math.floor(totalSec / 3600)
    local m = math.floor((totalSec % 3600) / 60)
    local s = math.floor(totalSec % 60)
    cachedTimestamp = string.format("[%02d:%02d:%02d] ", h, m, s)
end

local function GetSafeColor(colorName)
    if type(colorName) == "table" then return colorName end
    if colorName and PALETTE[colorName] then return PALETTE[colorName] end
    return PALETTE["White"]
end

local function CreateBackdrop(parent, color, layer)
    if not color or type(color) ~= "table" then color = {0, 0, 0, 1} end
    local bg = parent:CreateColorDrawable(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1, layer or "background")
    bg:AddAnchor("TOPLEFT", parent, 0, 0)
    bg:AddAnchor("BOTTOMRIGHT", parent, 0, 0)
    return bg
end

local function Truncate(str, limit)
    if #str > limit then return string.sub(str, 1, limit) .. ".." end
    return str
end

local function MakeDraggable(dragHandle, parentWindow, onDragStop)
    dragHandle:EnableDrag(true)
    dragHandle:SetHandler("OnDragStart", function(self)
        if api.Input:IsShiftKeyDown() then
            parentWindow:StartMoving()
            api.Cursor:ClearCursor()
            if CURSOR_PATH and CURSOR_PATH.MOVE then
                api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
            end
        end
    end)
    dragHandle:SetHandler("OnDragStop", function(self)
        parentWindow:StopMovingOrSizing()
        api.Cursor:ClearCursor()
        if onDragStop then onDragStop() end
    end)
end

-- Fills target-side snapshot fields from a UnitInfo table + ModifierInfo table
local function ApplyTargetSnapshot(snap, tInfo, tModInfo)
    tInfo    = tInfo    or {}
    tModInfo = tModInfo or {}
    snap.targetDefense   = tonumber(tInfo.armor                       or 0)
    snap.targetResist    = tonumber(tInfo.magic_resist                or 0)
    snap.targetArmorPct  = tonumber(tInfo.armor_percentage            or 0)
    snap.targetResistPct = tonumber(tInfo.magic_resist_percentage     or 0)
    snap.targetDodge     = tonumber(tInfo.dodge_rate                  or 0)
    snap.targetBlock     = tonumber(tInfo.block_rate                  or 0)
    snap.targetParry     = tonumber(tInfo.melee_parry_rate            or 0)
    snap.targetToughness = tonumber(tInfo.battle_resist               or 0)
    snap.targetIncomingMeleeMul  = tonumber(tInfo.incoming_melee_damage_mul   or 0)
    snap.targetIncomingSpellMul  = tonumber(tInfo.incoming_spell_damage_mul   or 0)
    snap.targetIncomingRangedMul = tonumber(tInfo.incoming_ranged_damage_mul  or 0)
    snap.targetIncomingMeleeVal  = tonumber(tInfo.incoming_melee_damage_val   or 0)
    snap.targetIncomingSpellVal  = tonumber(tInfo.incoming_spell_damage_val   or 0)
    snap.targetIncomingRangedVal = tonumber(tInfo.incoming_ranged_damage_val  or 0)
end

-- Attempts to get target UnitInfo: tries GetUnitInfoById first (works off-target),
-- falls back to UnitInfo("target") if the ID-based call returns no useful data.
local function GetTargetInfo(unitID)
    local numID = tonumber(unitID)
    local ok, tInfo = pcall(function() return api.Unit:GetUnitInfoById(numID) end)
    if ok and tInfo and (tonumber(tInfo.armor_percentage or 0) > 0 or tonumber(tInfo.magic_resist_percentage or 0) > 0) then
        return tInfo
    end
    local ok2, tInfo2 = pcall(function() return api.Unit:UnitInfo("target") end)
    if ok2 then return tInfo2 end
    return {}
end

local function GetOrCreateOutgoing(unitID, targetName, now)
    local existing = fightData.outgoing[unitID]
    if existing then
        -- If snapshot was empty on creation (target not selected at fight start), retry now
        if not existing.snapshotComplete then
            local tInfo = GetTargetInfo(unitID)
            tInfo = tInfo or {}
            if tonumber(tInfo.armor_percentage or 0) > 0 or tonumber(tInfo.magic_resist_percentage or 0) > 0 then
                local okM, tModInfo = pcall(function() return api.Unit:UnitModifierInfo("target") end)
                if not okM then tModInfo = {} end
                ApplyTargetSnapshot(existing.statSnapshot, tInfo, tModInfo)
                if not existing.targetGS then existing.targetGS = tonumber(tInfo.gear_score) or nil end
                if not existing.targetClass then
                    -- ONLY GetUnitClassName gives a real class (and only for actual PLAYERS); it
                    -- returns "Pending" for mobs/mounts/NPCs. UnitClass lies ("mage" for everything),
                    -- so we never fall back to it -- that was tagging mounts/mobs as players.
                    local okC, cls = pcall(function() return api.Ability:GetUnitClassName("target") end)
                    if okC and cls and cls ~= "" and cls:lower() ~= "pending" then existing.targetClass = tostring(cls) end
                end
                -- Weak fallback mount tag for the unit you're TARGETING: fast move_speed AND not a
                -- confirmed player (GetUnitClassName gave no real class). Speed is unreliable (varies
                -- by mount + buffs), so it only applies when type-based detection hasn't already
                -- flagged it, and never to a real player -- avoids tagging a speed-buffed ally/enemy.
                if not existing.targetClass and (tonumber(tInfo.move_speed) or 0) >= 9 then
                    CONFIG._nameMount = CONFIG._nameMount or {}; CONFIG._nameMount[string.lower(existing.name or "")] = true
                end
                if not existing.targetMaxHp then
                    local okH, mhp = pcall(function() return api.Unit:UnitMaxHealth("target") end)
                    if okH and mhp then existing.targetMaxHp = tonumber(mhp) or nil end
                end
                existing.snapshotComplete = true
            end
        end
        return existing
    end

    local ok1, playerInfo = pcall(function() return api.Unit:UnitInfo("player") end)
    if not ok1 then playerInfo = {} end
    playerInfo = playerInfo or {}

    local targetInfo = GetTargetInfo(unitID)
    targetInfo = targetInfo or {}
    local ok2b, targetModInfo = pcall(function() return api.Unit:UnitModifierInfo("target") end)
    if not ok2b then targetModInfo = {} end
    targetModInfo = targetModInfo or {}

    local ok3, tHp    = pcall(function() return api.Unit:UnitHealth("target") end)
    if not ok3 then tHp = nil end
    local ok4, tMaxHp = pcall(function() return api.Unit:UnitMaxHealth("target") end)
    if not ok4 then tMaxHp = nil end
    -- Real class only from GetUnitClassName (players); "Pending" => mob/mount/NPC. No UnitClass
    -- fallback -- it returns "mage" for everything, which mis-tagged mounts/mobs as players.
    local ok5, tClass = pcall(function() return api.Ability:GetUnitClassName("target") end)
    if not ok5 or not tClass or tClass == "" or tostring(tClass):lower() == "pending" then tClass = nil end
    -- Weak fallback mount tag for your target: fast move_speed AND not a confirmed player. Speed
    -- is unreliable (mount + player speeds both vary with buffs), so it never overrides a real
    -- class and never tags a speed-buffed player. Type-based detection (in _classifyUnit) is primary.
    if not tClass and (tonumber(targetInfo.move_speed) or 0) >= 9 then
        CONFIG._nameMount = CONFIG._nameMount or {}; CONFIG._nameMount[string.lower(targetName or "")] = true
    end

    -- patch 243+: zone group and targeting info
    local okZ, zoneGroup = pcall(function() return api.Unit:GetCurrentZoneGroup() end)
    if not okZ then zoneGroup = nil end
    local okTU, targetIsTargetingPlayer = pcall(function()
        return api.Unit:TargetUnit("target") == "player"
    end)
    if not okTU then targetIsTargetingPlayer = false end

    local snap = {
        playerPhysPen        = tonumber(playerInfo.ignore_armor      or 0),
        playerMagicPen       = tonumber(playerInfo.magic_penetration  or 0),
        playerMeleeHit       = tonumber(playerInfo.melee_success_rate or 100),
        playerSpellHit       = tonumber(playerInfo.spell_success_rate or 100),
        playerMeleeCritRate  = tonumber(playerInfo.melee_critical_rate  or 0),
        playerSpellCritRate  = tonumber(playerInfo.spell_critical_rate  or 0),
        playerMeleeCritBonus = tonumber(playerInfo.melee_critical_bonus or 50),
        playerSpellCritBonus = tonumber(playerInfo.spell_critical_bonus or 50),
        playerBackstabMelee  = tonumber(playerInfo.backattack_melee_damage_mul  or 0),
        playerBackstabRanged = tonumber(playerInfo.backattack_ranged_damage_mul or 0),
        playerBackstabSpell  = tonumber(playerInfo.backattack_spell_damage_mul  or 0),
        zoneGroup            = zoneGroup,                -- zone group at fight start (patch 243+)
        targetIsTargetingPlayer = targetIsTargetingPlayer, -- was target targeting player? (patch 243+)
        -- target fields filled by helper below
    }
    ApplyTargetSnapshot(snap, targetInfo, targetModInfo)

    if CONFIG.DEBUG_UNITINFO then
        -- Probe every numeric UnitInfo field through GetSkillsetNameById to find
        -- which fields hold the three skillset IDs (check both player and target).
        local function probeSkillsets(info)
            local found = {}
            for k, v in pairs(info or {}) do
                local n = tonumber(v)
                if n and n > 0 and n < 100 then
                    local ok, name = pcall(function() return api.Ability:GetSkillsetNameById(n) end)
                    if ok and name and name ~= "" then
                        found[k] = tostring(n) .. " -> " .. tostring(name)
                    end
                end
            end
            return found
        end
        local lines = {}
        local function dump(label, tbl)
            table.insert(lines, "=== " .. label .. " ===")
            for k, v in pairs(tbl or {}) do
                table.insert(lines, "  " .. tostring(k) .. " = " .. tostring(v))
            end
        end
        dump("player_UnitInfo",          playerInfo)
        dump("player_skillset_probe",    probeSkillsets(playerInfo))
        dump("target_UnitInfo",          targetInfo)
        dump("target_skillset_probe",    probeSkillsets(targetInfo))
        dump("target_UnitModInfo",       targetModInfo)
        pcall(function() api.File:Write("CombatLogPro/unitinfo_dump.txt", table.concat(lines, "\n")) end)
        api.Log:Info("[CLP] DEBUG_UNITINFO dump written to CombatLogPro/unitinfo_dump.txt")
        CONFIG.DEBUG_UNITINFO = false  -- dump once per reload
    end

    local hasData = (snap.targetArmorPct > 0 or snap.targetResistPct > 0)

    fightData.outgoing[unitID] = {
        name             = targetName,
        targetClass      = (tClass and tClass ~= "") and tostring(tClass) or nil,
        targetGS         = tonumber(targetInfo.gear_score) or nil,
        targetMaxHp      = tonumber(tMaxHp) or nil,
        skills           = {},
        skillTypes       = {},  -- skill -> "Melee"/"Ranged"/"Magic"
        hitCounts        = {},
        defends          = {},
        misses           = {},
        physDmg          = 0,
        magicDmg         = 0,
        rangedDmg        = 0,
        physAbsorbed     = 0,
        magicAbsorbed    = 0,
        rangedAbsorbed   = 0,
        physHits         = 0,
        magicHits        = 0,
        rangedHits       = 0,
        -- Raw pre-mitigation damage from COMBAT_MSG arg[11] (exact, no estimation)
        rawPhysDmg       = 0,
        rawMagicDmg      = 0,
        rawRangedDmg     = 0,
        startTime        = now,
        lastUpdate       = now,
        snapshotComplete = hasData,
        statSnapshot     = snap,
        -- Observed skill trees (inferred from skills used during combat)
        observedTrees    = {},  -- tree name -> true
        -- Buff effect tracking
        appliedDebuffs   = {},  -- skill -> true, for all 0-damage actions on this target
        invincibleSkills = {},  -- skill -> count
        spellShieldDmg   = 0,  -- magic dmg dealt into spell shield
        spellShieldHealed = 0, -- HP healed to target via spell shield
        runeConvertDmg   = 0,  -- dmg that healed target via rune
        runeConvertPct   = 0,  -- rune % (for summary display)
        runeConvertName  = nil,
        dmgShields       = {},    -- { name -> { max, rawDmg } }
        backstabHits     = 0,
        backstabDmg      = 0,
        backstabSkillHits = {},  -- { skillName -> count } for skills with their own BS bonus
        comboHits        = 0,
        comboBonusDmg    = 0,
        comboSkills      = {},   -- { skillName -> { hits, bonusDmg } }
    }
    return fightData.outgoing[unitID]
end

-- ============================================================================
--  UI UPDATE & RENDER
-- ============================================================================

local function RebuildLiveLabels()
    if not wLive or not liveBodyWidget then return end
    local icons = CONFIG.SHOW_ICONS ~= false   -- show skill icons in the live feed?
    local tx = icons and 30 or 10               -- text x-offset: leave room for the icon when on
    -- Layout pass: only runs when dimensions changed (resize, or SHOW_ICONS toggled -> dirty).
    if liveLayoutDirty then
        liveLayoutDirty = false
        wLive:SetExtent(CONFIG.LIVE_WIDTH, CONFIG.LIVE_HEIGHT)
        -- History/Options now live in the footer, so the IDLE/IN COMBAT badge always has room up top
        -- (it no longer overlaps right-side buttons) -- show it at every width.
        do
            local sl = liveTitleLabel and liveTitleLabel.statusLabel
            if sl then sl:Show(true) end
        end
        local bodyHeight = CONFIG.LIVE_HEIGHT - 30 - 26   -- minus header (30) + footer (26)
        CONFIG.VISIBLE_ROWS_LIVE = math.floor((bodyHeight - 20) / CONFIG.LINE_HEIGHT)
        for i = 1, 50 do
            if i <= CONFIG.VISIBLE_ROWS_LIVE then
                local rowY = 10 + ((i-1) * CONFIG.LINE_HEIGHT)
                local lbl = liveLabels[i]
                if not lbl then
                    lbl = liveBodyWidget:CreateChildWidget("label", "LiveLbl"..i, 0, true)
                    lbl:SetLimitWidth(true)
                    if lbl.style then
                        lbl.style:SetAlign(ALIGN.LEFT)
                        lbl.style:SetShadow(true)
                        lbl.style:SetEllipsis(true)
                    end
                    liveLabels[i] = lbl
                end
                lbl:RemoveAllAnchors()
                lbl:AddAnchor("TOPLEFT", liveBodyWidget, tx, rowY)
                lbl:SetExtent(CONFIG.LIVE_WIDTH - tx - 10, CONFIG.LINE_HEIGHT)
                lbl:Show(true)
                -- Per-row skill icon at the left (shown/hidden + textured in the text pass).
                if icons and CONFIG._clpMakeIcon then
                    local ic = liveIcons[i] or CONFIG._clpMakeIcon(liveBodyWidget, 16)
                    liveIcons[i] = ic
                    if ic then ic:RemoveAllAnchors(); ic:AddAnchor("TOPLEFT", liveBodyWidget, 8, rowY + 1); ic:Show(false) end
                elseif liveIcons[i] then
                    liveIcons[i]:Show(false)
                end
            else
                if liveLabels[i] then liveLabels[i]:Show(false) end
                if liveIcons[i] then liveIcons[i]:Show(false) end
            end
        end
    end
    -- Text pass: always runs, updates visible label text + color + per-line icon.
    local startIdx = #liveBuffer - CONFIG.VISIBLE_ROWS_LIVE + 1
    if startIdx < 1 then startIdx = 1 end
    local lblIdx = 1
    for i = startIdx, #liveBuffer do
        local e = liveBuffer[i]
        if liveLabels[lblIdx] and liveLabels[lblIdx]:IsVisible() then
            local timeStr = ""
            if CONFIG.SHOW_TIMESTAMP and e.time then
                timeStr = e.time
            end
            liveLabels[lblIdx]:SetText(timeStr .. e.text)
            if liveLabels[lblIdx].style then liveLabels[lblIdx].style:SetColor(e.r, e.g, e.b, 1) end
            local ic = liveIcons[lblIdx]
            if ic then
                local p
                if icons then
                    if e.death then p = CONFIG._ovIcon("__death__")        -- skull on death lines
                    elseif e.skill and CONFIG._resolveSkillIcon then p = CONFIG._resolveSkillIcon(e.skill, e.dmgTag, e.varIcon) end
                end
                if p and p ~= "" then CONFIG._clpSetIcon(ic, p) else ic:Show(false) end
            end
        end
        lblIdx = lblIdx + 1
    end
end

-- ============================================================================
--  ICON INFRASTRUCTURE (history rows + the live feed, gated by CONFIG.SHOW_ICONS)
-- ============================================================================
-- Stat-line icons (armor/crit/etc.) -- loaded via a do-block onto CONFIG (no new top-level
-- local; the main chunk is at Lua's 200-local cap). User-editable in stat_icons.lua.
do
    local ok, t = pcall(require, "/CombatLogPro/stat_icons")
    if ok and type(t) == "table" then CONFIG.STAT_ICONS = t end
end

-- Per-player icon overrides written by the in-game icon picker (skill name -> icon base).
-- Highest priority in ResolveSkillIcon. This is the file testers send back to the maintainer.
do
    local d = api.File:Read("CombatLogPro/icon_overrides.txt")
    CONFIG._iconOverrides = (type(d) == "table") and d or {}
end

local ICON_ROLE = {
    tank   = "../Addon/CombatLogPro/icons/RoleTank.png",
    healer = "../Addon/CombatLogPro/icons/RoleHealer.png",
    dps    = "../Addon/CombatLogPro/icons/RoleDPS.png",
}
-- Type glyphs + damage-type fallbacks: known-valid game .dds icons (easy to refine).
local ICON_TYPE = {
    enemy    = "Game\\ui\\icon\\icon_skill_wild03.dds",
    incoming = "Game\\ui\\icon\\icon_skill_karon01.dds",
    heal     = "Game\\ui\\icon\\icon_skill_tare01.dds",
    recap    = "Game\\ui\\icon\\icon_skill_glider_snowflake02.dds",
}
local ICON_DMGTYPE = {
    Magic    = "Game\\ui\\icon\\icon_skill_wild03.dds",
    Spell    = "Game\\ui\\icon\\icon_skill_wild03.dds",
    Ranged   = "Game\\ui\\icon\\icon_skill_karon01.dds",
    Melee    = "Game\\ui\\icon\\icon_skill_tare01.dds",
    Physical = "Game\\ui\\icon\\icon_skill_tare01.dds",
    Heal     = "Game\\ui\\icon\\icon_skill_buff304.dds",
}
-- Bonus-breakdown source label -> the skill whose icon represents it (resolved via SKILL_ICONS).
local BONUS_ICON = {
    Zeal         = "Zeal",
    Chanty       = "Bloody Chantey",
    Rhythm       = "Rhythmic Renewal",
    ["M.Circle"] = "Magic Circle",
    HealPwr      = "Ode to Recovery",
    Inspired     = "Inspiration Cloak",
}

local iconPathCache      = {}   -- skill name -> path or false
local playerSkillIconMap = {}   -- your skill name -> icon path (built on Load)
local SKILL_ICON_CATALOG = {}   -- curated name -> path (extend over time)
local clpIconSeq         = 0    -- unique-name counter for CreateItemIconButton

-- Create a small icon widget. Native icon button when available; pcall-guarded
-- so a failure never breaks the row (the text still renders).
local function ClpMakeIcon(parent, size)
    if not parent then return nil end
    clpIconSeq = clpIconSeq + 1
    local icon
    if CreateItemIconButton then
        local ok, made = pcall(function() return CreateItemIconButton("ClpIcon" .. clpIconSeq, parent) end)
        if ok then icon = made end
    end
    if not icon then
        local ok, made = pcall(function() return parent:CreateImageDrawable(ICON_ROLE.dps, "overlay") end)
        if ok then icon = made end
    end
    if not icon then return nil end
    pcall(function() icon:SetExtent(size, size) end)
    return icon
end

-- Point an icon at a texture path. nil hides it entirely; "" (unmapped skill) keeps the slot present
-- and CLICKABLE (so you can still click it to assign an icon) but transparent via alpha 0 -- so the
-- default white item-slot frame disappears into the background instead of showing an empty box.
local function ClpSetIcon(icon, path)
    if not icon then return end
    if not path then pcall(function() icon:Show(false) end); return end
    if path == "" then
        if F_SLOT and F_SLOT.SetIconBackGround then pcall(function() F_SLOT.SetIconBackGround(icon, "") end) end
        pcall(function() icon:SetAlpha(0) end)        -- invisible but still receives clicks
        pcall(function() icon:Show(true) end)
        return
    end
    local ok = false
    if F_SLOT and F_SLOT.SetIconBackGround then
        ok = pcall(function() F_SLOT.SetIconBackGround(icon, tostring(path)) end)
    end
    if not ok and icon.SetTgaTexture then
        ok = pcall(function() icon:SetTgaTexture(tostring(path)) end)
    end
    if not ok then pcall(function() icon:SetTextureInfo(tostring(path)) end) end
    pcall(function() icon:SetAlpha(1) end)            -- restore in case the slot was previously empty
    pcall(function() icon:Show(true) end)
end

-- Name-list icon: role for known players, type glyph otherwise.
-- Resolve a universal icon-override key (e.g. "__mob__", "__kill__", "__died__") to a game icon
-- path, or "" (a blank-but-clickable slot). One picker assignment then applies to ALL of that
-- kind -- every mob shares "__mob__", every kill marker shares "__kill__". Stored on CONFIG.
-- Official baked-in defaults for the universal keys (maintainer's chosen icons). icon_overrides.txt
-- still overrides per-tester; keys with no default and no override resolve to "" (blank slot).
CONFIG._iconDefaults = {
    ["__mob__"]   = "icon_skill_buff265",  -- shared mob icon
    ["__death__"] = "icon_skill_buff96",   -- session-death/skull marker (maintainer's chosen icon, baked in)
    ["__bloodlust__"] = "icon_skill_buff97", -- the actual "Bloodlust Mode" buff icon (id 1482, from tester scan); override in icon_overrides.txt
    ["__player__"] = "icon_skill_buff300", -- player-contributor icon (baked in)
    -- Fight-list category icons (sidebar Fight rows). Baked-in defaults; the in-game "Fight Icons"
    -- picker was removed. __duel__ is replaced at runtime by the real Duel buff icon (_resolveDuelIcon).
    ["__pve__"]   = "icon_skill_buff121",  -- PvE / mob fight (baked)
    ["__pvp__"]   = "icon_skill_buff319",  -- PvP / enemy-player fight (baked)
    ["__duel__"]  = "icon_skill_hatred25", -- duel / "mock fight" (placeholder; replaced by _resolveDuelIcon)
}
CONFIG._ovIcon = function(key, default)
    local ov = CONFIG._iconOverrides and CONFIG._iconOverrides[key]
    if ov then return "Game\\ui\\icon\\" .. ov .. ".dds" end
    if default then return default end
    local d = CONFIG._iconDefaults and CONFIG._iconDefaults[key]
    return d and ("Game\\ui\\icon\\" .. d .. ".dds") or ""
end

-- Use the actual "Duel" buff icon (id 1834/3649) as the __duel__ category default -- the real game
-- icon beats a placeholder. Lazy + cached: runs on the first duel-row render (GetBuffTooltip is
-- reliable in-game). The picker override still wins; falls back to the placeholder if never resolved.
CONFIG._resolveDuelIcon = function()
    if CONFIG._duelIconDone then return end
    CONFIG._duelIconTries = (CONFIG._duelIconTries or 0) + 1
    for _, id in ipairs({ 1834, 3649 }) do
        local okT, t = pcall(function() return api.Ability:GetBuffTooltip(id) end)
        if okT and type(t) == "table" and t.path then
            local base = tostring(t.path):match("([^\\/]+)%.dds$")
            if base and base ~= "" then CONFIG._iconDefaults["__duel__"] = base; CONFIG._duelIconDone = true; return end
        end
    end
    if CONFIG._duelIconTries >= 5 then CONFIG._duelIconDone = true end  -- give up, keep the placeholder
end

-- Quick mob/player reference: which shared, assignable icon a name uses. Player = a detected
-- role/build, OR an ally you healed/tracked (Heal/Recap); everything else is a mob/enemy. Both
-- "__player__" and "__mob__" are single icons assignable via the picker (blank by default).
local function ResolveNameKey(group)
    local ln = string.lower(group.name or "")
    if CONFIG._nameMount and CONFIG._nameMount[ln] then return "__mount__" end  -- fast unit = mount
    -- Floodgates: recaps now cover enemies/mobs too, so trust the classified `who` first.
    if group.who == "mob" then return "__mob__" end
    if group.who == "ally" or group.who == "enemy" then return "__player__" end
    local ct = CONFIG._nameClassTbl and CONFIG._nameClassTbl[ln]
    if group.role or ct or group.kind == "Heal" then return "__player__" end
    return "__mob__"
end

-- Per-row skill icon: your skills -> curated catalog -> damage-type fallback.
local function ResolveSkillIcon(skill, dmgTag, variantIcon)
    if not skill then return nil end
    -- Ancestral-variant icon: passed IN per-line (frozen at log time, only for YOUR own casts -- so
    -- an enemy's same-named cast keeps the base icon, and switching variants doesn't re-skin old
    -- lines). Beats the base skillcalc icon, but still yields to an explicit user override. Not
    -- cached -- the same skill resolves differently for your line vs an incoming one.
    if variantIcon then
        if CONFIG._iconOverrides and CONFIG._iconOverrides[skill] then
            return "Game\\ui\\icon\\" .. CONFIG._iconOverrides[skill] .. ".dds"
        end
        return "Game\\ui\\icon\\" .. variantIcon .. ".dds"
    end
    local cached = iconPathCache[skill]
    if cached ~= nil then return cached or nil end
    local path
    -- 0. User/tester override from the in-game icon picker (icon_overrides.txt) -- wins.
    if CONFIG._iconOverrides and CONFIG._iconOverrides[skill] then
        path = "Game\\ui\\icon\\" .. CONFIG._iconOverrides[skill] .. ".dds"
    end
    -- 1. Authoritative: the skillcalc-sourced icon name for this skill.
    if not path then
        local base = SKILL_ICONS[skill]
        if base then path = "Game\\ui\\icon\\" .. base .. ".dds" end
    end
    -- 2. Real icon via the skill's known buff/debuff entry. buffNameToId only holds VALID
    -- ids (from the static buff DB), so this native call is safe -- never garbage input.
    if not path then
        local bid = buffNameToId[skill]
        if bid then
            local okT, tip = pcall(function() return api.Ability:GetBuffTooltip(bid) end)
            if okT and type(tip) == "table" and tip.path and tip.path ~= "" then path = tip.path end
        end
    end
    -- 3. BLANK by default: no glyph fallback. Unmapped skills render empty -- click the slot
    -- to assign one via the icon picker (writes icon_overrides.txt for the maintainer).
    iconPathCache[skill] = path or false
    return path
end

-- Expose the icon helpers on CONFIG so RebuildLiveLabels (defined earlier in the file than these
-- locals, so it can't capture them as upvalues) can use them. Set at load, before any render.
CONFIG._resolveSkillIcon = ResolveSkillIcon
CONFIG._clpMakeIcon = ClpMakeIcon
CONFIG._clpSetIcon = ClpSetIcon

-- Build name->icon for your own skills from the skill bar. The id field name is
-- confirmed in-game (id / skillId / buff_id); all candidates are tried.
local function BuildPlayerSkillIcons()
    -- Reverse the scanner's buffDB (id->name) into a name->buff_id map, so a combat-log
    -- skill name that exists as a known buff/debuff can resolve its REAL icon safely via
    -- GetBuffTooltip(valid id). Only valid ids are ever passed to the native call.
    for id, name in pairs(buffDB) do
        if name and name ~= "" and not buffNameToId[name] then buffNameToId[name] = id end
    end
end

-- Split a session's bonus-breakdown lines ("A +N | B +N") into one entry per source,
-- tagged with bonusLabel so the archive render can show each source's icon. Render-only;
-- the stored logs and the live feed are untouched.
local function ExpandArchive(logs)
    -- Drop the hidden duplicate damage line for the session view; keep the bonus breakdown
    -- inline on one line (no per-source split). The live feed / stored logs are untouched.
    local out = {}
    for _, e in ipairs(logs or {}) do
        if not e.archiveHide then out[#out + 1] = e end
    end
    return out
end

-- Size + position the history scrollbar thumb from the current scroll offset. The track spans
-- between the up/down arrows; histBody is HIST_HEIGHT-58 tall (below the category bar), and the
-- two 40px arrow buttons (+5 margins +4 gaps) leave HIST_HEIGHT-156 for the track.
local function UpdateScrollThumb()
    if not scrollTrack or not scrollThumb then return end
    local total   = #displayBuffer
    local visible = CONFIG.VISIBLE_ROWS_HIST
    local trackH  = CONFIG.HIST_HEIGHT - 156
    if total <= visible or trackH <= 24 then
        scrollThumb:Show(false)         -- everything fits: no thumb
        CONFIG._scrollRange = 0
        return
    end
    scrollThumb:Show(true)
    local thumbH = math.max(24, math.floor(trackH * visible / total))
    if thumbH > trackH then thumbH = trackH end
    local range     = trackH - thumbH
    local maxOffset = total - visible
    local y = (maxOffset > 0) and math.floor((logScrollOffset / maxOffset) * range + 0.5) or 0
    if y < 0 then y = 0 elseif y > range then y = range end
    scrollThumb:SetExtent(8, thumbH)
    scrollThumb:RemoveAllAnchors()
    scrollThumb:AddAnchor("TOP", scrollTrack, 0, y)
    CONFIG._scrollRange = range          -- cached for the drag handler
end

local function UpdateHistoryDisplay()
    if not wHistory or not wHistory:IsVisible() then return end
    local totalLines = #displayBuffer
    local maxOffset = totalLines - CONFIG.VISIBLE_ROWS_HIST
    if maxOffset < 0 then maxOffset = 0 end
    if logScrollOffset > maxOffset then logScrollOffset = maxOffset end
    if logScrollOffset < 0 then logScrollOffset = 0 end
    UpdateScrollThumb()
    -- Every ARCHIVE line gets a clickable icon slot. Tester override (icon_overrides.txt,
    -- keyed by this string) wins; else the resolved skill/stat icon; else "" = a blank but
    -- still-clickable empty frame -- so EVERY row has an icon space you can assign later.
    local function setLineIcon(icon, key, defaultPath)
        if not icon then return end
        icon.clpSkill = key
        local path = defaultPath
        if key and CONFIG._iconOverrides and CONFIG._iconOverrides[key] then
            path = "Game\\ui\\icon\\" .. CONFIG._iconOverrides[key] .. ".dds"
        end
        ClpSetIcon(icon, path or "")
    end
    -- Move a row's icon between the normal left column (x=5) and the inline recap column.
    -- Re-anchors only on change (no churn while scrolling same-type rows).
    local function setIconColumn(icon, i, recap)
        if not icon or not CONFIG._histBody then return end
        local wantX = recap and CONFIG.RECAP_ICON_X or 5
        if icon.clpIconX ~= wantX then
            icon:RemoveAllAnchors()
            icon:AddAnchor("TOPLEFT", CONFIG._histBody, wantX, 9 + ((i-1) * CONFIG.HIST_ROW_H))
            icon.clpIconX = wantX
        end
    end
    for i = 1, CONFIG.VISIBLE_ROWS_HIST do
        local dataIndex = logScrollOffset + i
        local entry = displayBuffer[dataIndex]
        local lbl = historyLabels[i]
        local icon = historyIcons[i]
        -- Raid Meter bar: width = entry.barPct of the row area (set only on meter rows); 0 = hidden.
        do
            local bar = CONFIG._histBars and CONFIG._histBars[i]
            if bar then
                local bp = entry and entry.barPct
                local wantW = bp and math.floor(bp * (CONFIG.HIST_WIDTH - CONFIG.SIDEBAR_WIDTH - 64)) or 0  -- -64 leaves room for the scrollbar
                if bar.clpBarW ~= wantW then
                    bar.clpBarW = wantW
                    local y0 = 8 + ((i - 1) * CONFIG.HIST_ROW_H)
                    pcall(function()
                        bar:RemoveAllAnchors()
                        bar:AddAnchor("TOPLEFT", CONFIG._histBody, 32, y0 + 2)
                        bar:AddAnchor("BOTTOMRIGHT", CONFIG._histBody, "TOPLEFT", 32 + wantW, y0 + CONFIG.HIST_ROW_H - 2)
                    end)
                end
            end
        end
        -- Default each row to the normal single-label layout; the recap branch opts in.
        -- (Icon column is set per-branch so the re-anchor guard avoids churn on stable rows.)
        if CONFIG._recapL and CONFIG._recapL[i] then CONFIG._recapL[i]:Show(false) end
        if CONFIG._recapR and CONFIG._recapR[i] then CONFIG._recapR[i]:Show(false) end
        if entry then
            -- Timestamp shown once per event block: a line whose second matches the line above blanks
            -- "[HH:MM:SS]" to aligned spaces, so the hit detail + breakdown sit under their header
            -- instead of repeating it. Computed here so EVERY branch -- including the columnar
            -- session/skill-row drill-down -- renders it the same way the Live Log does.
            local timeStr = ""
            if CONFIG.SHOW_TIMESTAMP and entry.time and entry.time ~= "" then
                local prevEntry = displayBuffer[dataIndex - 1]
                if prevEntry and prevEntry.time and tostring(prevEntry.time) == tostring(entry.time) then
                    timeStr = string.rep(" ", #tostring(entry.time))
                else
                    timeStr = tostring(entry.time)
                end
            end
            if viewingMode == "ARCHIVE" and entry.skill and not entry.detailOnly then
                -- Skill row: icon + hit columns (damage hit) OR the original text (cc/debuff/miss).
                setLineIcon(icon, entry.skill, ResolveSkillIcon(entry.skill, entry.dmgTag, entry.varIcon)); setIconColumn(icon, i, false)
                if entry.damage then
                    local hitStr = "Hit"
                    if (entry.hitType and string.find(string.upper(tostring(entry.hitType)), "CRIT"))
                       or string.find(tostring(entry.text), "Crit") then hitStr = "Crit" end
                    local hpStr = tostring(entry.text):match("%[(%d+)%%%]")
                    hpStr = hpStr and (hpStr .. "%") or ""
                    lbl:SetText(timeStr .. string.format("%-16s %7d  %-4s %5s",
                        Truncate(entry.skill, 16), entry.damage or 0, hitStr, hpStr))
                else
                    lbl:SetText(timeStr .. tostring(entry.text))
                end
                if lbl.style then lbl.style:SetColor(entry.r, entry.g, entry.b, 1) end
            elseif viewingMode == "ARCHIVE" and entry.detailOnly then
                -- Bonus sub-line: the source's icon when it maps to a known skill (Zeal, etc.),
                -- otherwise a blank clickable slot keyed by the source label.
                local bskill = entry.bonusLabel and BONUS_ICON[entry.bonusLabel]
                setLineIcon(icon, entry.bonusLabel, bskill and ResolveSkillIcon(bskill) or ""); setIconColumn(icon, i, false)
                lbl:SetText(timeStr .. (tostring(entry.text):gsub("^%s+", "")))
                if lbl.style then lbl.style:SetColor((entry.r or 1)*0.6, (entry.g or 1)*0.6, (entry.b or 1)*0.6, 1) end
            elseif viewingMode == "ARCHIVE" and entry.logType == "summary" then
                -- Summary line: EVERY line gets a clickable icon slot (blank if none resolves).
                -- "> Skill" / "< Skill" / "+ Skill" -> skill icon; "[C] Chanty: +N" -> bonus icon;
                -- stat lines (armor / crit / modifiers / ...) -> keyword icon; anything else (Total
                -- DMG, Shields absorbed, dividers) -> blank slot keyed by the text before the colon.
                local txt = tostring(entry.text)
                setIconColumn(icon, i, false)
                local dir, iconSkill = txt:match("^%s*([><+]) (.-):")
                if not iconSkill then
                    local blab = txt:match("^%s*%[.-%]%s+([%w%.']+)")
                    if blab then iconSkill = BONUS_ICON[blab] end
                end
                if iconSkill then
                    -- YOUR outgoing summary skills ("> " / "+ ") get your equipped variant icon;
                    -- incoming ("< ") stays base. Uses the CURRENT variant (the aggregate isn't frozen).
                    local vIcon = (dir ~= "<" and CONFIG._detectedVariant) and CONFIG._detectedVariant[iconSkill] or nil
                    setLineIcon(icon, iconSkill, ResolveSkillIcon(iconSkill, nil, vIcon) or "")
                else
                    -- Stable per-line key: strip leading markers ( - + > < [ ] ) and take the
                    -- text up to the first colon, e.g. "Total DMG", "Shields absorbed", "Modifiers".
                    local key = txt:gsub("^[%s%-%+%>%<%[%]]*", ""):match("^[^:]*") or ""
                    key = key:gsub("%s+$", "")
                    if key == "" then key = nil end
                    local statPath
                    if CONFIG.STAT_ICONS then
                        local lower = string.lower(txt)
                        for _, pair in ipairs(CONFIG.STAT_ICONS) do
                            if string.find(lower, pair[1], 1, true) then
                                statPath = "Game\\ui\\icon\\" .. pair[2] .. ".dds"; break
                            end
                        end
                    end
                    setLineIcon(icon, key, statPath or "")
                end
                lbl:SetText(txt)
                if lbl.style then lbl.style:SetColor(entry.r, entry.g, entry.b, 1) end
            else
                -- ARCHIVE recap line ("Source -> Target — skill ±N [HP%]"): render like a player line
                -- -- skill icon on the LEFT, the FULL text in the wide single label -- so long
                -- "Source -> Target" combos are never clipped by a narrow middle column.
                local rsrc, rrest = nil, nil
                if viewingMode == "ARCHIVE" then
                    rsrc, rrest = tostring(entry.text):match("^(.-) — (.+)$")
                end
                -- (timeStr computed once at the top of the row handler.)
                if rsrc and rrest then
                    local rskill = rrest:match("^(.-) [%+%-]%d") or rrest
                    rskill = rskill:gsub("%s*%(Rank %d+%)$", "")  -- drop rank suffix for icon lookup
                    setLineIcon(icon, rskill, ResolveSkillIcon(rskill) or "")
                    setIconColumn(icon, i, false)
                    lbl:SetText("  " .. timeStr .. rsrc .. "   " .. rrest)
                else
                    -- LIVE mirror (and plain ARCHIVE text): render the skill/death icon into the left
                    -- gutter. The text label is anchored at x=32, so the icon sits in front with no
                    -- reflow. Skill lines get a clickable slot (blank-but-assignable if unmapped),
                    -- death lines get the skull; headers / dividers / banner / breakdown stay blank.
                    local liveKey, livePath
                    if CONFIG.SHOW_ICONS ~= false then
                        if entry.death then
                            liveKey, livePath = "__death__", CONFIG._ovIcon("__death__")
                        elseif entry.skill and entry.skill ~= "" then
                            liveKey, livePath = entry.skill, (ResolveSkillIcon(entry.skill, entry.dmgTag, entry.varIcon) or "")
                        end
                    end
                    if liveKey then
                        setLineIcon(icon, liveKey, livePath); setIconColumn(icon, i, false)
                    elseif icon then
                        icon:Show(false)
                    end
                    lbl:SetText(timeStr .. tostring(entry.text))
                end
                if lbl.style then lbl.style:SetColor(entry.r, entry.g, entry.b, 1) end
            end
        else
            if icon then icon:Show(false) end
            lbl:SetText("")
        end
    end
end

-- ============================================================================
--  LOGGING ENGINE
-- ============================================================================

local liveRebuildDirty = false
local histDisplayDirty = false
local lastLiveRebuildTime = 0

local function TrimBuffer(buf, maxSize)
    -- Batch trim: only fires when 50% over limit, so a 1000-entry buffer trims once
    -- per 500 inserts instead of every 200. Keeps the newest maxSize entries.
    if #buf > maxSize + math.floor(maxSize * 0.5) then
        local start = #buf - maxSize + 1
        local trimmed = {}
        for i = start, #buf do trimmed[#trimmed + 1] = buf[i] end
        return trimmed
    end
    return buf
end

local function LogEntry(text, r, g, b, meta)
    local entry = { text = text, r = r, g = g, b = b, time = GetTimestamp() }
    if meta then for k, v in pairs(meta) do entry[k] = v end end
    -- Freeze the variant icon: your own casts use your equipped variant, incoming uses the caller's
    -- pre-detected meta.varIcon (see RecordLogForTarget).
    entry.varIcon = (meta and meta.varIcon)
                    or ((meta and meta.skill and meta.source == PLAYER_NAME and CONFIG._detectedVariant)
                        and CONFIG._detectedVariant[meta.skill]) or nil
    liveBuffer[#liveBuffer + 1] = entry
    liveBuffer = TrimBuffer(liveBuffer, 50)
    masterBuffer[#masterBuffer + 1] = entry
    masterBuffer = TrimBuffer(masterBuffer, 1000)
    if viewingMode == "LIVE" then
        displayBuffer[#displayBuffer + 1] = entry
        displayBuffer = TrimBuffer(displayBuffer, 1000)
        local maxOffset = #displayBuffer - CONFIG.VISIBLE_ROWS_HIST
        if logScrollOffset >= (maxOffset - 5) or logScrollOffset < 0 then logScrollOffset = maxOffset end
        histDisplayDirty = true
    end
    -- Throttle live label rebuild: mark dirty, rebuild at most every 50ms
    liveRebuildDirty = true
    local nowMs = api.Time:GetUiMsec()
    if nowMs - lastLiveRebuildTime >= 50 then
        lastLiveRebuildTime = nowMs
        liveRebuildDirty = false
        RebuildLiveLabels()
    end
end

-- ============================================================================
--  RAID METER (feature; gated by CONFIG.RAID_METER). Per-fight aggregate of every
--  combatant's damage/healing, keyed by source name, classified you/team/other via
--  allyRoster. Captured during YOUR fight (inCombat) at the COMBAT_MSG tap, reset
--  with fightData, snapshotted into CONFIG._fightMeters[fightId] at FinishFight, and
--  surfaced in the history fight-detail as two pseudo-contributors (My Raid / Everyone)
--  whose leaderboard reuses the existing Damage/Healing filter. Names + numbers only
--  (the API lockdown blocks enrichment of non-target units). See raid-meter spec.
-- ============================================================================
CONFIG._meterAgg = CONFIG._meterAgg or {}   -- key -> { name, dmg, heal, hits, cls }
CONFIG._meterN = CONFIG._meterN or 0

CONFIG._meterReset = function()
    CONFIG._meterAgg = {}
    CONFIG._meterN = 0
    CONFIG._ctQ = {}
end

CONFIG._meterClass = function(name)
    if not name or name == "" then return "other" end
    if name == PLAYER_NAME then return "you" end
    if allyRoster[string.lower(name)] then return "team" end
    return "other"
end

-- Effect-tick (HoT/DoT) caster attribution. A tick's COMBAT_MSG reports the EFFECT as the source
-- (source == skill, e.g. "Rhythmic Renewal"), but the paired COMBAT_TEXT carries the caster's
-- entity id. We keep a short ring of recent COMBAT_TEXTs and match a tick to its CT by TARGET +
-- AMOUNT -- "last CT" is unreliable because dozens of HoTs interleave under raid load (proven by
-- the DoT probe). Each match is consumed so two ticks can't claim one CT.
CONFIG._ctQ = CONFIG._ctQ or {}
CONFIG._ctPush = function(src, tgt, amt)
    local q = CONFIG._ctQ
    q[#q + 1] = { src = src, tgt = tgt, amt = amt }
    if #q > 40 then table.remove(q, 1) end
end
CONFIG._resolveTickCaster = function(targetId, amount)
    local q = CONFIG._ctQ
    for i = #q, 1, -1 do
        local e = q[i]
        if e and not e.used and e.tgt == targetId and e.amt == amount
           and e.src and e.src ~= "" and e.src ~= "0" then
            e.used = true   -- consume the match either way
            local okN, n = pcall(function() return api.Unit:GetUnitNameById(e.src) end)
            return (okN and n and n ~= "") and tostring(n) or nil
        end
    end
    return nil
end

CONFIG._meterTap = function(sourceName, amount, isHeal)
    local nm = sourceName
    if nm == "" or nm == "Unknown" or nm == "unknown" then nm = nil end
    -- Raid-only: classify first and skip anyone who isn't you or your raid. Keeps the aggregate
    -- tiny (your raid is <50), so there's no cap and raid members can never be evicted by a flood
    -- of nearby strangers in a siege.
    local cls = nm and CONFIG._meterClass(nm) or "other"
    if cls == "other" then return end
    local key = string.lower(nm)
    local a = CONFIG._meterAgg[key]
    if not a then
        a = { name = nm, dmg = 0, heal = 0, hits = 0, cls = cls }
        CONFIG._meterAgg[key] = a
        CONFIG._meterN = (CONFIG._meterN or 0) + 1
    end
    local amt = tonumber(amount) or 0
    if isHeal then a.heal = a.heal + amt else a.dmg = a.dmg + amt end
    a.hits = a.hits + 1
end

-- Scope-filtered, metric-sorted rows from a stored fight meter. scope: "raid"|"all".
CONFIG._meterRows = function(fm, scope, metric)
    if not fm or not fm.rows then return {}, 0 end
    local list, total = {}, 0
    for _, a in ipairs(fm.rows) do
        local inScope = (scope == "all") or (a.cls == "you" or a.cls == "team")
        local v = (metric == "heal") and a.heal or a.dmg
        if inScope and v > 0 then list[#list + 1] = a; total = total + v end
    end
    table.sort(list, function(x, y)
        local xv = (metric == "heal") and x.heal or x.dmg
        local yv = (metric == "heal") and y.heal or y.dmg
        return xv > yv
    end)
    return list, total
end

-- Build the right-pane line items for a fight's meter. Sections follow the existing
-- Damage/Healing (F_WHAT_*) filter, so that toggle doubles as the metric selector.
CONFIG._buildMeterView = function(fightId, scope)
    local fm = CONFIG._fightMeters and CONFIG._fightMeters[fightId]
    local out = {}
    if not fm then return out end
    local dur = math.max(1, fm.durSec or 1)
    out[#out + 1] = { text = string.format("=====  Raid Meter  (%.0fs)  =====", dur), r = 0.55, g = 0.7, b = 1 }
    local hasTeam = false
    if fm.rows then for _, a in ipairs(fm.rows) do if a.cls == "team" then hasTeam = true; break end end end
    local function abbr(n)
        n = n or 0
        if n >= 1000000 then return string.format("%.2fm", n / 1000000)
        elseif n >= 1000 then return string.format("%.1fk", n / 1000)
        else return string.format("%d", n) end
    end
    local function rowColor(cls)
        if cls == "you" then return 0.451, 0.824, 0.200 end  -- you (green)
        return 0.310, 0.800, 0.922                           -- raid (cyan)
    end
    local function section(metric, title)
        local list, total = CONFIG._meterRows(fm, "raid", metric)
        out[#out + 1] = { text = "  " .. title, r = 1, g = 0.85, b = 0.3 }
        if #list == 0 then
            out[#out + 1] = { text = "    (none)", r = 0.6, g = 0.6, b = 0.6 }
            return
        end
        local topV = (metric == "heal") and list[1].heal or list[1].dmg
        if topV <= 0 then topV = 1 end
        for i = 1, math.min(40, #list) do
            local a = list[i]
            local v = (metric == "heal") and a.heal or a.dmg
            local pct = total > 0 and (v / total * 100) or 0
            local r, g, b = rowColor(a.cls)
            out[#out + 1] = {
                text = string.format("%2d  %-16s %9s  %5.1f%%", i, Truncate(a.name, 16), abbr(v), pct),
                r = r, g = g, b = b, barPct = v / topV,
            }
        end
    end
    if CONFIG.F_WHAT_DMG ~= false then section("dmg", "TOP DAMAGE") end
    if CONFIG.F_WHAT_HEAL ~= false then
        if CONFIG.F_WHAT_DMG ~= false then out[#out + 1] = { text = "", r = 0.4, g = 0.4, b = 0.4 } end
        section("heal", "TOP HEALING")
    end
    if not hasTeam then
        out[#out + 1] = { text = "", r = 0.4, g = 0.4, b = 0.4 }
        out[#out + 1] = { text = "  Only you showing? Set the game's Damage/Heal Info to Raid (or higher) to include teammates.", r = 0.62, g = 0.62, b = 0.55 }
    end
    return out
end

local function RecordLogForTarget(unitID, unitName, text, r, g, b, meta)
    if not text then return end
    timeSinceLastAction = 0
    local ts = GetTimestamp()
    local isSummary = meta and meta.logType == "summary"
    local histEntry = { text = text, r = r, g = g, b = b, time = ts }
    if meta then for k, v in pairs(meta) do histEntry[k] = v end end
    -- Freeze the ancestral-variant icon. For YOUR own casts (source == you) it's your equipped
    -- variant; for an INCOMING cast at you the caller pre-detects it from the debuff (meta.varIcon).
    -- nil for everything else -> base. Frozen here so a later switch never re-skins this line.
    local varIcon = (meta and meta.varIcon)
                    or ((meta and meta.skill and meta.source == PLAYER_NAME and CONFIG._detectedVariant)
                        and CONFIG._detectedVariant[meta.skill]) or nil
    histEntry.varIcon = varIcon
    -- Summary lines go to session logs only — not the main live log or history stream
    if not isSummary then
        masterBuffer[#masterBuffer + 1] = histEntry
        masterBuffer = TrimBuffer(masterBuffer, 1000)
        if viewingMode == "LIVE" then
            displayBuffer[#displayBuffer + 1] = histEntry
            displayBuffer = TrimBuffer(displayBuffer, 1000)
            local maxOffset = #displayBuffer - CONFIG.VISIBLE_ROWS_HIST
            if logScrollOffset >= (maxOffset - 5) or logScrollOffset < 0 then logScrollOffset = maxOffset end
            histDisplayDirty = true
        end
        if not (meta and meta.detailOnly) then
            local liveTxt = (meta and meta.liveText) or text
            liveBuffer[#liveBuffer + 1] = { text = liveTxt, r = r, g = g, b = b, time = ts, skill = meta and meta.skill, dmgTag = meta and meta.dmgTag, varIcon = varIcon }
            liveBuffer = TrimBuffer(liveBuffer, 50)
            CONFIG._liveSinceDiv = true  -- this fight put a line in the live feed -> divider warranted
            liveRebuildDirty = true
            local nowMs = api.Time:GetUiMsec()
            if nowMs - lastLiveRebuildTime >= 50 then
                lastLiveRebuildTime = nowMs
                liveRebuildDirty = false
                RebuildLiveLabels()
            end
        end
    end
    table.insert(currentSessionLogs, histEntry)
    if not sessionByTarget[unitID] then
        sessionByTarget[unitID] = { name = unitName, logs = {} }
    end
    table.insert(sessionByTarget[unitID].logs, histEntry)
end

local function RecordHealLog(key, displayName, text, r, g, b, meta)
    if not text then return end
    local ts = GetTimestamp()
    local isSummary = meta and meta.logType == "summary"
    -- History and session: store original unwrapped text
    local histEntry = { text = text, r = r, g = g, b = b, time = ts }
    if meta then for k, v in pairs(meta) do histEntry[k] = v end end
    local varIcon = (meta and meta.varIcon)
                    or ((meta and meta.skill and meta.source == PLAYER_NAME and CONFIG._detectedVariant)
                        and CONFIG._detectedVariant[meta.skill]) or nil  -- frozen variant icon
    histEntry.varIcon = varIcon
    -- End-of-fight summary lines (totals / Heal Stats / per-skill breakdowns) go to the per-fight
    -- heal session ONLY -- not the live feed, master log, or LIVE history stream. The live feed is
    -- real-time events only (matches RecordLogForTarget; tester feedback: totals aren't wanted live).
    if not isSummary then
        masterBuffer[#masterBuffer + 1] = histEntry
        masterBuffer = TrimBuffer(masterBuffer, 1000)
        if viewingMode == "LIVE" then
            displayBuffer[#displayBuffer + 1] = histEntry
            displayBuffer = TrimBuffer(displayBuffer, 1000)
            local maxOffset = #displayBuffer - CONFIG.VISIBLE_ROWS_HIST
            if logScrollOffset >= (maxOffset - 5) or logScrollOffset < 0 then logScrollOffset = maxOffset end
            histDisplayDirty = true
        end
    end
    if not healSessionByTarget[key] then
        healSessionByTarget[key] = { name = displayName, logs = {} }
    end
    table.insert(healSessionByTarget[key].logs, histEntry)
    -- Live display: real-time heal events only (skip end-of-fight summary lines).
    if not isSummary then
        liveBuffer[#liveBuffer + 1] = { text = text, r = r, g = g, b = b, time = ts, skill = meta and meta.skill, varIcon = varIcon }
        liveBuffer = TrimBuffer(liveBuffer, 50)
        CONFIG._liveSinceDiv = true  -- live heal content this fight -> divider warranted
        liveRebuildDirty = true
        local nowMs = api.Time:GetUiMsec()
        if nowMs - lastLiveRebuildTime >= 50 then
            lastLiveRebuildTime = nowMs
            liveRebuildDirty = false
            RebuildLiveLabels()
        end
    end
end

-- Records one damage/heal event against a tracked party/raid ally into their recap
-- timeline. Display/record only: does NOT touch combat state or other sessions.
-- amount is the absolute value; isHeal distinguishes a heal (+) from damage (-).
local RECAP_MAX_ENTRIES = 150
local RECAP_MIN_DMG = 1000  -- skip an ally's recap session if they took less than this total damage (unless they died)
local function RecordAllyRecap(sourceName, targetName, skill, amount, isHeal, isCrit, unitId)
    -- Reset the per-heal overheal stash; set below once we have the target's HP. The
    -- heal-done block reads CONFIG._healOverheal right after this call, same event.
    if isHeal and sourceName == PLAYER_NAME then CONFIG._healOverheal = nil end
    if amount <= 0 then return end
    -- Refresh the roster at most every 3s here (instead of a per-frame timer in
    -- OnLiveUpdate) to keep that function under Lua's 60-upvalue limit.
    -- allyRosterTimer is reused as a "last refresh" timestamp; frameNow is per-frame.
    if frameNow - allyRosterTimer > 3000 then
        allyRosterTimer = frameNow
        RefreshAllyRoster()
    end
    -- Floodgates: record EVERY unit's combat (ally, enemy or mob), from both sides.
    local tag = GetAllyTag(targetName)   -- target's team tag (nil unless the target is a teammate)

    -- HP% of the line's target. PRIMARY: read live HP straight off the target's id -- this works for
    -- ANY unit (enemy, mob, boss), not just teammates/your target (proven via the COMBAT_TEXT probe).
    local hpPct = nil
    if unitId and unitId ~= "" and unitId ~= "0" then
        local okI, info = pcall(function() return api.Unit:GetUnitInfoById(unitId) end)
        if okI and type(info) == "table" then
            local ch = tonumber(info.hp or info.health or info.current_health)
            local mh = tonumber(info.max_health or info.max_hp or info.maxHealth)
            if ch and mh and mh > 0 then
                hpPct = math.floor(ch / mh * 100)
                if hpPct < 0 then hpPct = 0 elseif hpPct > 100 then hpPct = 100 end
            end
        end
    end
    -- Team-tag / target-handle read: still needed for the player's overheal math (pre-heal HP of a
    -- party member), and as the hpPct fallback if the id table lacks HP for this unit.
    local okH, hp, okM, mhp = false, nil, false, nil
    local hpHandle = tag or ((CONFIG._curTargetName and targetName == CONFIG._curTargetName) and "target" or nil)
    if hpHandle then
        okH, hp  = pcall(function() return api.Unit:UnitHealth(hpHandle) end)
        okM, mhp = pcall(function() return api.Unit:UnitMaxHealth(hpHandle) end)
        if okH and okM and hp and mhp and mhp > 0 and not hpPct then
            hpPct = math.floor(hp / mhp * 100)
            if hpPct < 0 then hpPct = 0 end
        end
    end

    -- Overheal for the heal DISPLAY (always, not just under the capture toggle): the HP
    -- read here is pre-heal (validated), so overheal = max(0, curhp + heal - maxHP).
    -- Stashed on CONFIG for the heal-done block (no new upvalue in that tight handler).
    if isHeal and sourceName == PLAYER_NAME and okH and okM and hp and mhp and mhp > 0 then
        local over = (hp + amount) - mhp
        if over < 0 then over = 0 end
        CONFIG._healOverheal = { name = targetName, over = over }
    end

    -- Everything below is the Ally Recap timeline; skip when recap isn't enabled.
    if not CONFIG.LOG_ALLY_RECAP then return end

    local hpStr   = hpPct and string.format(" [%d%%]", hpPct) or ""
    local critStr = isCrit and " (Crit)" or ""
    local sign    = isHeal and "+" or "-"
    local timeNow = GetTimestamp()

    -- Append one line to ONE unit's recap. The line shows the WHOLE event ("Source -> Target") so it
    -- reads correctly in the merged Overall/fight views; `ek` lets those views dedup the two records
    -- (one under the source, one under the target) of the same event. `who` = the recap subject's
    -- class (name icon + WHO filter). Direction lives in the arrow, so colour is just dmg vs heal.
    local function addLine(recapName, who, srcName, tgtName, dealt, sw, tw)
        local rec = recapData[recapName]
        if not rec then rec = { name = recapName, logs = {}, dmgTaken = 0, died = false }; recapData[recapName] = rec end
        rec.who = who
        local r, g, b
        if isHeal then r, g, b = 0.4, 1, 0.4 else r, g, b = 1, 0.55, 0.3 end
        if (not dealt) and not isHeal then rec.dmgTaken = rec.dmgTaken + amount end
        rec.keep = true   -- floodgates: keep any recap with content; the top toggles filter the view
        rec.logs[#rec.logs + 1] = {
            text = string.format("%s -> %s — %s %s%d%s%s", srcName, tgtName, skill, sign, amount, critStr, hpStr),
            r = r, g = g, b = b, time = timeNow, hpPct = hpPct, dead = false,
            isHeal = isHeal, dir = dealt and "dealt" or "taken",
            sw = sw, tw = tw, what = isHeal and "heal" or "dmg",
            ek = timeNow .. "|" .. srcName .. "|" .. tgtName .. "|" .. skill .. "|" .. amount,
        }
        if #rec.logs > RECAP_MAX_ENTRIES + 50 then
            local trimmed = {}
            for i = #rec.logs - RECAP_MAX_ENTRIES + 1, #rec.logs do trimmed[#trimmed + 1] = rec.logs[i] end
            rec.logs = trimmed
        end
    end

    -- Recaps capture OTHERS' combat only: anything involving you already lives in your own
    -- Outgoing/Incoming/Heal sessions, so excluding you keeps each unit's "Overall" view free of
    -- duplicates. Solo => no recap at all; group/raid/PvP => purely what other people did.
    local youInvolved = (sourceName == PLAYER_NAME) or (targetName == PLAYER_NAME)
    if not youInvolved
       and sourceName ~= "Unknown" and sourceName ~= ""
       and targetName ~= "Unknown" and targetName ~= "" then
        -- Spectator mode: each nearby combat event keeps the bracketed fight alive.
        if CONFIG.SPECTATE then timeSinceLastAction = 0 end
        -- classify both ends once (target has an id => reliable; source leans on the cache). sw/tw
        -- describe the EVENT, so both lines carry the same pair; `dir` distinguishes the perspective.
        local srcClass = CONFIG._classifyUnit(sourceName, nil)
        local tgtClass = CONFIG._classifyUnit(targetName, unitId)
        -- capture toggles: skip a subject whose class isn't being recorded.
        local recOK = { ally = CONFIG.REC_ALLY ~= false, enemy = CONFIG.REC_ENEMY ~= false, mob = CONFIG.REC_MOB ~= false }
        -- Both records describe the same event (sourceName -> targetName); merged views dedup by ek.
        -- recorded under the TARGET (their incoming)
        if recOK[tgtClass] then addLine(targetName, tgtClass, sourceName, targetName, false, srcClass, tgtClass) end
        -- recorded under the SOURCE (their outgoing). Skip self-procs AND effect-ticks: a HoT/DoT
        -- reports the EFFECT name as the source (source == skill, e.g. "Rhythmic Renewal"), which is
        -- not a real unit -- recording it would make the spell show up as its own contributor.
        if sourceName ~= targetName and sourceName ~= skill and recOK[srcClass] then
            addLine(sourceName, srcClass, sourceName, targetName, true, srcClass, tgtClass)
        end
    end
end

-- ============================================================================
--  SCROLLING & SESSION LIST
-- ============================================================================

local function ScrollLogUp() logScrollOffset = logScrollOffset - 5; if logScrollOffset < 0 then logScrollOffset = 0 end; UpdateHistoryDisplay() end
local function ScrollLogDown() 
    local totalLines = #displayBuffer; local maxOffset = totalLines - CONFIG.VISIBLE_ROWS_HIST; if maxOffset < 0 then maxOffset = 0 end
    logScrollOffset = logScrollOffset + 5; if logScrollOffset > maxOffset then logScrollOffset = maxOffset end; UpdateHistoryDisplay() 
end
-- Grouped session list: one entry per name, each holding all that name's sessions
-- (Heal/Recap/In/Out) concatenated under per-session headers. Rebuilt only when
-- allSessions changes (not on scroll).
local sessionGroups = {}   -- ordered array of { name, sessions = {..}, count, latest }
local sessionFilter = ""    -- name filter from the history search box ("" = show all)
local sidebarMode  = "NAMES" -- "NAMES" (list of names) or "SESSIONS" (one name's sessions)
local selectedGroup = nil    -- the group drilled into while in SESSIONS mode
local selectedContributor = nil  -- Level 3: a multi-instance contributor drilled into (its same-named units)
local sidebarBackBtn = nil    -- back button widget (shown only in SESSIONS mode)

local function RebuildSessionGroups()
    -- Group sessions by FIGHT (fightId). One group per fight, plus a synthetic "Overall" group
    -- spanning every fight, pinned at the top. Each group keeps its session entries so
    -- CONFIG._buildOverall can stream them. (Per-name browsing now lives inside a fight's
    -- contributor bar, not the sidebar.)
    local byFight = {}
    local order = {}
    local overall = { name = "Overall", isOverall = true, sessions = {}, count = 0, latest = 0 }
    for i = 1, #allSessions do
        local s = allSessions[i]
        local fid = s.fightId or 0
        local grp = byFight[fid]
        if not grp then
            grp = { fightId = fid, isFight = true, time = s.time or "", sessions = {}, count = 0, latest = i }
            byFight[fid] = grp
            order[#order + 1] = grp
        end
        local typeLabel = s.isHeal and "Heal"
                       or (s.isRecap and "Recap"
                       or (s.isIncoming and "Incoming" or "Outgoing"))
        local scat
        if s.isHeal then scat = s.isHealDone and "myHeal" or "healRcv"
        elseif s.isRecap then scat = "oth"
        elseif s.isIncoming then scat = "inc"
        else scat = "myDmg" end
        local entry = { time = s.time or "", typeLabel = typeLabel, scat = scat, who = s.who,
                        name = s.targetName, targetId = s.targetId, logs = s.logs,
                        endedInDeath = s.endedInDeath, endedInKill = s.endedInKill }
        grp.sessions[#grp.sessions + 1] = entry
        overall.sessions[#overall.sessions + 1] = entry
        grp.count = grp.count + 1
        grp.latest = i
        if s.endedInDeath then grp.hasDeath = true; overall.hasDeath = true end
        if s.endedInKill then grp.hasKill = true; overall.hasKill = true end
        -- Sidebar fight categorisation: PvE = any mob opponent, PvP = any enemy player (s.who was
        -- classified WITH the unit id at save time; fall back to a name classify). Duel propagated from
        -- the record. deathCount = distinct units that died (deduped by name).
        local oc = s.who or CONFIG._classifyUnit(s.targetName, nil)
        if oc == "mob" then grp.hasPvE = true elseif oc == "enemy" then grp.hasPvP = true end
        if s.wasDuel then grp.wasDuel = true end
        if s.endedInDeath or s.endedInKill then
            -- count DISTINCT dead units: by unit id when we have it (so 3 same-named kills read 3),
            -- else by name (others'-combat recaps are name-merged).
            local dk = s.targetId or s.targetName
            if dk then
                grp.deaths = grp.deaths or {}
                if not grp.deaths[dk] then grp.deaths[dk] = true; grp.deathCount = (grp.deathCount or 0) + 1 end
            end
        end
    end
    table.sort(order, function(a, b) return a.latest > b.latest end)  -- newest fight first
    overall.count = #order                                            -- number of fights
    for _, g in ipairs(order) do                                      -- attach fight duration from the meter snapshot
        local fm = CONFIG._fightMeters and CONFIG._fightMeters[g.fightId]
        if fm then g.durSec = fm.durSec end
    end
    table.insert(order, 1, overall)                                   -- Overall pinned on top
    sessionGroups = order
    -- Preserve a drilled-in selection across rebuilds: a new fight saving mid-browse must NOT kick
    -- you back to the fight list. Re-point selectedGroup to the equivalent freshly-built group.
    if selectedGroup then
        local wantOverall, wantFid = selectedGroup.isOverall, selectedGroup.fightId
        local found = nil
        for _, g in ipairs(order) do
            if (wantOverall and g.isOverall) or (not wantOverall and wantFid and g.fightId == wantFid) then found = g; break end
        end
        selectedGroup = found
        if not found then sidebarMode = "NAMES"; selectedContributor = nil end   -- the viewed fight was trimmed away
    else
        sidebarMode = "NAMES"
    end
end

-- Three-axis filter helpers (WHO x WHAT x DIR). A line is visible when its WHAT is enabled AND
-- either its source side (source class + Dealt) or its target side (target class + Taken) is on.
-- sw/tw are unit classes: "me"/"ally"/"enemy"/"mob". Player sessions are uniform, so they filter
-- as a whole via _sessionVisible (which keeps their summary block tied to the same decision).
CONFIG._whoOn = function(w)
    if w == "me"    then return CONFIG.F_WHO_ME    ~= false end
    if w == "ally"  then return CONFIG.F_WHO_ALLY  ~= false end
    if w == "enemy" then return CONFIG.F_WHO_ENEMY ~= false end
    if w == "mob"   then return CONFIG.F_WHO_MOB   ~= false end
    return true
end
CONFIG._lineVisible = function(sw, tw, what)
    if what == "heal" then if CONFIG.F_WHAT_HEAL == false then return false end
    elseif CONFIG.F_WHAT_DMG == false then return false end
    local dealt = (CONFIG.F_DIR_DEALT ~= false) and CONFIG._whoOn(sw)
    local taken = (CONFIG.F_DIR_TAKEN ~= false) and CONFIG._whoOn(tw)
    return dealt or taken
end
CONFIG._sessionVisible = function(s)
    -- Your OWN sessions are gated on "Me": with Me off, none of your combat shows -- even though the
    -- opponent's side would otherwise match (your hit on a mob IS "the mob took damage"). WHAT and
    -- your direction (you dealt vs. you took) still apply on top of that.
    if CONFIG.F_WHO_ME == false then return false end
    local heal = (s.scat == "myHeal" or s.scat == "healRcv")
    if heal then if CONFIG.F_WHAT_HEAL == false then return false end
    elseif CONFIG.F_WHAT_DMG == false then return false end
    local youDealt = (s.scat == "myDmg" or s.scat == "myHeal")  -- you are the actor
    if youDealt then return CONFIG.F_DIR_DEALT ~= false else return CONFIG.F_DIR_TAKEN ~= false end
end

-- Build a group's combined stream, honouring the three-axis filter. Player sessions are kept or
-- dropped whole (lines + their summary); recap "oth" sessions keep only the lines that pass the
-- per-line WHO/WHAT/DIR test. Stored on CONFIG. The caller runs it through ExpandArchive.
CONFIG._buildOverall = function(grp)
    local out, seen = {}, {}
    for _, s in ipairs((grp and grp.sessions) or {}) do
        local ct = tostring(s.time or ""):gsub("[%[%]]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        local dk = s.endedInDeath and " [DIED]" or (s.endedInKill and " [KILL]" or "")
        local header = { text = "=====  " .. (s.typeLabel or "?") .. "  " .. ct .. dk .. "  =====", r = 0.55, g = 0.7, b = 1 }
        if s.scat == "oth" then
            -- Recap (others-only): keep lines that pass WHO/WHAT/DIR, deduped by event (the same hit
            -- is recorded under both the source's and the target's recap).
            local kept = {}
            for _, ln in ipairs(s.logs or {}) do
                local what = ln.what or (ln.isHeal and "heal" or "dmg")
                if CONFIG._lineVisible(ln.sw, ln.tw, what) and not (ln.ek and seen[ln.ek]) then
                    if ln.ek then seen[ln.ek] = true end
                    kept[#kept + 1] = ln
                end
            end
            if #kept > 0 then
                out[#out + 1] = header
                for _, ln in ipairs(kept) do out[#out + 1] = ln end
            end
        elseif CONFIG._sessionVisible(s) then
            -- Player session: kept whole, so its summary block follows the same decision.
            out[#out + 1] = header
            for _, ln in ipairs(s.logs or {}) do out[#out + 1] = ln end
        end
    end
    return out
end

-- A single unit's view: one chronological timeline (all its lines, filtered, merged + sorted by
-- time), a "*** DIED ***" marker per fight in which it died (deduped by fight time), and its
-- summary block(s) collected at the bottom. Used for contributor drill-downs.
CONFIG._unitTimeline = function(grp)
    local items, summary, deathAt, seen = {}, {}, {}, {}
    for _, s in ipairs((grp and grp.sessions) or {}) do
        if s.scat == "oth" then
            for _, ln in ipairs(s.logs or {}) do
                local what = ln.what or (ln.isHeal and "heal" or "dmg")
                if CONFIG._lineVisible(ln.sw, ln.tw, what) and not (ln.ek and seen[ln.ek]) then
                    if ln.ek then seen[ln.ek] = true end
                    items[#items + 1] = ln
                end
            end
        elseif CONFIG._sessionVisible(s) then
            for _, ln in ipairs(s.logs or {}) do
                if ln.logType == "summary" then summary[#summary + 1] = ln else items[#items + 1] = ln end
            end
        end
        -- Death markers. A unit's death (recap endedInDeath, or you got the kill) is deduped per
        -- fight+name so multi-unit fights still show each death; your own death is deduped per fight.
        local nm = s.name or "?"
        local dt = s.time or "~~"
        if ((s.scat == "oth" and s.endedInDeath) or (s.scat ~= "oth" and s.endedInKill)) and not deathAt[dt .. "|" .. nm] then
            deathAt[dt .. "|" .. nm] = true
            items[#items + 1] = { text = "      *** " .. nm .. " DIED ***", r = 1, g = 0.35, b = 0.35, time = dt }
        end
        if s.scat ~= "oth" and s.endedInDeath and not deathAt["you|" .. dt] then
            deathAt["you|" .. dt] = true
            items[#items + 1] = { text = "      *** YOU DIED ***", r = 1, g = 0.3, b = 0.3, time = dt }
        end
    end
    -- STABLE sort. Timestamps are 1-second strings and Lua's table.sort is unstable, so same-second
    -- lines -- a skill header, its damage/heal detail, and its mitigation breakdown (all logged under
    -- one key, in order) -- were getting scrambled in the archive while the live log (which never
    -- sorts) stayed correct. Tag each item with its collection order and tiebreak on it so the
    -- archive replays the exact logged order.
    for idx = 1, #items do items[idx]._si = idx end
    table.sort(items, function(a, b)
        local ta, tb = tostring(a.time or ""), tostring(b.time or "")
        if ta ~= tb then return ta < tb end
        return (a._si or 0) < (b._si or 0)
    end)
    -- Contributor view: if this unit's gear score was cached (from a time you targeted them), pin it
    -- at the top. Only players ever have one (mobs read 0 and are never stored).
    if grp and grp.isContributor and grp.name and CONFIG._nameGS then
        local gs = CONFIG._nameGS[string.lower(grp.name)]
        if gs then table.insert(items, 1, { text = "  Gear Score: " .. gs, r = 0.85, g = 0.8, b = 0.45 }) end
    end
    if #summary > 0 then
        items[#items + 1] = { text = "=====  Summary  =====", r = 0.55, g = 0.7, b = 1 }
        for _, ln in ipairs(summary) do items[#items + 1] = ln end
    end
    return items
end

-- Every scope (Overall / fight / contributor) renders as one merged, deduped, chronological
-- timeline of "Source -> Target" lines.
CONFIG._buildView = function(grp)
    if grp and grp.isMeter and CONFIG._fightMeters and CONFIG._fightMeters[grp.fightId] then
        return CONFIG._buildMeterView(grp.fightId, grp.meterScope)
    end
    return CONFIG._unitTimeline(grp)
end

-- Distinct contributors (units) in a group, each returned as a mini-group with its own sessions,
-- for the Level-2 sidebar drill. ResolveNameKey reads .who for the icon; .hasDeath flags a death.
CONFIG._contributorsOf = function(group)
    local byName, order, me = {}, {}, nil
    for _, s in ipairs((group and group.sessions) or {}) do
        local nm = s.name or "?"
        local c = byName[nm]
        if not c then c = { name = nm, sessions = {}, who = s.who, count = 0, isContributor = true }; byName[nm] = c; order[#order + 1] = c end
        c.sessions[#c.sessions + 1] = s
        c.count = c.count + 1
        if s.targetId then c._ids = c._ids or {}; c._ids[s.targetId] = true end  -- distinct unit instances
        if s.who then c.who = s.who end
        -- A unit "died" if its recap ended in death (ally/enemy) OR you killed it (mob -> endedInKill).
        if s.endedInDeath or s.endedInKill then c.hasDeath = true end
        -- YOUR own combat (any non-recap session: scat ~= "oth") ALSO rolls up under a synthetic
        -- "Me" contributor, pinned first -- so you can click yourself, while still appearing under
        -- each opponent too. (Grouped sessions carry `scat`, not `isRecap`.)
        if s.scat ~= "oth" then
            if not me then me = { name = PLAYER_NAME, sessions = {}, who = "ally", count = 0, isContributor = true, isMe = true } end
            me.sessions[#me.sessions + 1] = s
            me.count = me.count + 1
            if s.endedInDeath then me.hasDeath = true end
        end
    end
    if me then table.insert(order, 1, me) end   -- pin "Me" at the top of the contributor list
    -- Raid Meter: surface the fight's raid leaderboard as one clickable pseudo-contributor that
    -- rides the existing view rails; the Damage/Healing filter picks which sections (dmg/heal) show.
    if CONFIG.RAID_METER and group and group.fightId and CONFIG._fightMeters and CONFIG._fightMeters[group.fightId] then
        table.insert(order, 1, { name = "Raid Meter", who = "ally", sessions = {}, isContributor = true, isMeter = true, meterScope = "raid", fightId = group.fightId })
    end
    -- Mark contributors that are several same-named units (distinct ids) so they drill to Level 3.
    for _, c in ipairs(order) do
        if c._ids then
            local n = 0; for _ in pairs(c._ids) do n = n + 1 end
            if n > 1 then c.multiInstance = true; c.instanceCount = n end
        end
    end
    return order
end

-- Same-named units (instances) inside one contributor, split by unit id, for the Level-3 drill.
-- Each instance = that one mob (your combat with it + per-id kill), numbered by order of appearance.
-- Sessions without a targetId (others'-combat recaps, which are name-merged) are skipped -- the
-- per-instance split only covers your OWN combat with each unit.
CONFIG._instancesOf = function(c)
    local byId, order = {}, {}
    for _, s in ipairs((c and c.sessions) or {}) do
        if s.targetId then
            local inst = byId[s.targetId]
            if not inst then
                inst = { name = c.name, sessions = {}, who = c.who, count = 0, isContributor = true, isInstance = true, targetId = s.targetId }
                byId[s.targetId] = inst; order[#order + 1] = inst
            end
            inst.sessions[#inst.sessions + 1] = s
            inst.count = inst.count + 1
            if s.endedInDeath or s.endedInKill then inst.hasDeath = true end
        end
    end
    for i, inst in ipairs(order) do inst.name = c.name .. " #" .. i end
    return order
end

-- Size + position the session-list scrollbar thumb (mirrors UpdateScrollThumb for the sidebar).
-- The sidebar is HIST_HEIGHT-58 tall; its up/down arrows (40px + margins/gaps) leave HIST_HEIGHT-256
-- for the track. Called from UpdateSessionList with the current total + visible counts.
local function UpdateSessionThumb(total, vis)
    if not sessTrack or not sessThumb then return end
    local trackH = CONFIG.HIST_HEIGHT - 256
    if (total or 0) <= (vis or 0) or trackH <= 24 then
        sessThumb:Show(false)
        CONFIG._sessRange, CONFIG._sessMaxScroll = 0, 0
        return
    end
    sessThumb:Show(true)
    local thumbH = math.max(24, math.floor(trackH * vis / total))
    if thumbH > trackH then thumbH = trackH end
    local range     = trackH - thumbH
    local maxScroll = total - vis
    local y = (maxScroll > 0) and math.floor((sessionScrollOffset / maxScroll) * range + 0.5) or 0
    if y < 0 then y = 0 elseif y > range then y = range end
    sessThumb:SetExtent(8, thumbH)
    sessThumb:RemoveAllAnchors()
    sessThumb:AddAnchor("TOP", sessTrack, 0, y)
    CONFIG._sessRange, CONFIG._sessMaxScroll = range, maxScroll
end

local function UpdateSessionList(rebuild)
    if rebuild then RebuildSessionGroups() end
    if not wHistory:IsVisible() then
        if lblSessionCount then lblSessionCount:SetText("Saved: " .. #allSessions) end
        return
    end

    -- Two levels:
    --   Level 1 (FIGHTS): Overall + one row per fight. Clicking a row DRILLS in.
    --   Level 2 (CONTRIBUTORS): the drilled group's Overall (pinned) + its units. Clicking VIEWS.
    local level2 = (sidebarMode == "SESSIONS" and selectedGroup) and true or false
    local level3 = (level2 and selectedContributor) and true or false
    local entries
    if level3 then
        entries = CONFIG._instancesOf(selectedContributor)
        if sidebarBackBtn then sidebarBackBtn:Show(true) end
        if lblSessionCount then lblSessionCount:SetText(Truncate(selectedContributor.name, 24) .. "  (" .. #entries .. ")") end
    elseif level2 then
        entries = CONFIG._contributorsOf(selectedGroup)
        if sessionFilter ~= "" then   -- name search: keep only contributors whose name matches
            local f = string.lower(sessionFilter)
            local filtered = {}
            for _, e in ipairs(entries) do
                if e.name and string.find(string.lower(e.name), f, 1, true) then filtered[#filtered + 1] = e end
            end
            entries = filtered
        end
        if sidebarBackBtn then sidebarBackBtn:Show(true) end
        if lblSessionCount then
            if sessionFilter ~= "" then
                lblSessionCount:SetText('Search: "' .. sessionFilter .. '"  (' .. #entries .. ')')
            else
                local t = tostring(selectedGroup.time or ""):gsub("[%[%]]", ""):gsub("^%s+", ""):gsub("%s+$", "")
                lblSessionCount:SetText(selectedGroup.isOverall and "Overall" or ("Fight " .. t))
            end
        end
    else
        entries = sessionGroups
        if sessionFilter ~= "" then  -- name search: keep Overall + fights that include a matching unit
            local f = string.lower(sessionFilter)
            entries = {}
            for _, g in ipairs(sessionGroups) do
                local keep = g.isOverall
                if not keep then
                    for _, s in ipairs(g.sessions) do
                        if s.name and string.find(string.lower(s.name), f, 1, true) then keep = true; break end
                    end
                end
                if keep then entries[#entries + 1] = g end
            end
        end
        if sidebarBackBtn then sidebarBackBtn:Show(false) end
        if lblSessionCount then lblSessionCount:SetText("Saved: " .. #allSessions) end
    end

    local reserve = (level2 and sessionFilter == "") and 1 or 0   -- pin the scope's Overall (but not while name-searching)
    local vis = CONFIG.SESSIONS_VISIBLE - reserve
    local total = #entries
    local maxScroll = total - vis
    if maxScroll < 0 then maxScroll = 0 end
    if sessionScrollOffset > maxScroll then sessionScrollOffset = maxScroll end
    if sessionScrollOffset < 0 then sessionScrollOffset = 0 end
    UpdateSessionThumb(total, vis)
    local startIdx = 1 + sessionScrollOffset   -- top-anchored

    if reserve == 1 then
        local ob = sessionButtons[1]
        if ob then
            if ob.clpIcon then ob.clpIcon:Show(false) end
            if ob.clpMarkIcon then ob.clpMarkIcon:Show(false) end
            ob.clpIconKey = nil; ob.clpMarkKey = nil
            if ob.clpSkill then for j = 1, 3 do if ob.clpSkill[j] then ob.clpSkill[j]:SetVisible(false) end end end
            if ob.durLabel then ob.durLabel:Show(false) end
            if ob.timeLabel then ob.timeLabel:Show(false) end
            if ob.deathLabel then ob.deathLabel:Show(false) end
            local pinned = (level3 and selectedContributor) or selectedGroup
            if level3 then ob:SetText("  " .. Truncate(selectedContributor.name, 18) .. "  (all)")
            else ob:SetText("  Overall  (" .. #selectedGroup.sessions .. ")") end
            if pinned.hasDeath then ob:SetTextColor(1, 0.5, 0.4, 1) else ob:SetTextColor(1, 0.85, 0.3, 1) end
            ob.drillGroup = nil; ob.viewGroup = pinned; ob.drillContributor = nil
            ob:Show(true); ob:Raise()
        end
    end

    local btnIdx = 1 + reserve
    for i = startIdx, startIdx + vis - 1 do
        local e = entries[i]
        local btn = sessionButtons[btnIdx]
        if btn then
            if e then
                btn.clpIconKey = nil; btn.clpMarkKey = nil; btn.drillContributor = nil
                if btn.clpMarkIcon then btn.clpMarkIcon:Show(false) end
                if btn.clpSkill then for j = 1, 3 do if btn.clpSkill[j] then btn.clpSkill[j]:SetVisible(false) end end end
                if btn.durLabel then btn.durLabel:Show(false) end
                if btn.timeLabel then btn.timeLabel:Show(false) end
                if btn.deathLabel then btn.deathLabel:Show(false) end
                if level2 then
                    -- contributor row: unit name + role/class icon; clicking VIEWS that unit's combat
                    -- Contributor rows no longer show the left unit-type icon -- the generic
                    -- player/mount/mob glyphs were clutter and can't resolve real class/role for
                    -- most units post-lockdown anyway. The death/bloodlust marker (right) stays.
                    btn.clpIconKey = nil
                    if btn.clpIcon then btn.clpIcon:Show(false) end
                    -- 180px button: ~22 chars fit; leave room for the skull (~26px) on death rows.
                    btn:SetText(Truncate(e.name, e.multiInstance and 13 or (e.hasDeath and 18 or 22)) .. (e.multiInstance and ("  \195\151" .. e.instanceCount) or ""))
                    if btn.style then btn.style:SetAlign(ALIGN.CENTER) end   -- contributor names centered
                    -- Name colour by faction / PvP status (the skull marks death, so no death-red).
                    -- Pirate (faction name) and bloodlust (forced-PvP) are only known for units you've
                    -- targeted (cached); opposite-faction (enemy player) is known by id for everyone.
                    do
                        -- RELATIVE AA nameplate colours (palette from "Old Colors" by Shinimi). byid
                        -- friendly/hostile is already relative to YOU (a pirate's own pirates read
                        -- friendly), so we key off it. Priority: you > party/raid > bloodlust >
                        -- same-side > hostile(pink/red by bloc) > mob.
                        local fln   = string.lower(e.name or "")
                        local fac   = CONFIG._nameFaction and CONFIG._nameFaction[fln]   -- faction NAME (target-cached)
                        local force = CONFIG._nameForce and CONFIG._nameForce[fln]       -- bloodlust/criminal (target-cached)
                        local team  = GetAllyTag(e.name) ~= nil                          -- party/raid member
                        local cr, cg, cb
                        if e.isMe then                cr, cg, cb = 0.451, 0.824, 0.200    -- you        #73D233
                        elseif team then              cr, cg, cb = 0.310, 0.800, 0.922    -- party/raid #4FCCEB (stays ally even if bloodlusted)
                        elseif force then             cr, cg, cb = 0.604, 0.451, 0.835    -- bloodlust  #9A73D5 (incl your own faction)
                        elseif e.who == "ally" then   cr, cg, cb = 0.451, 0.824, 0.200    -- same side  #73D233 (friendly faction, non-party)
                        elseif e.who == "enemy" then  cr, cg, cb = CONFIG._enemyColor(fac) -- pink/red by the bloc model
                        else                          cr, cg, cb = 0.584, 0.584, 0.584 end -- mob/NPC    #959595
                        btn:SetTextColor(cr, cg, cb, 1)
                    end
                    if e.hasDeath and btn.clpMarkIcon then
                        btn.clpMarkKey = "__death__"
                        ClpSetIcon(btn.clpMarkIcon, CONFIG._ovIcon("__death__"))
                        btn.clpMarkIcon:Show(true)   -- raised AFTER the button (below) so it isn't covered
                    elseif btn.clpMarkIcon and CONFIG._nameForce and CONFIG._nameForce[string.lower(e.name or "")] then
                        btn.clpMarkKey = "__bloodlust__"   -- bloodlusted/criminal marker (skull's sibling)
                        ClpSetIcon(btn.clpMarkIcon, CONFIG._ovIcon("__bloodlust__"))
                        btn.clpMarkIcon:Show(true)
                    end
                    if e.multiInstance then btn.drillGroup = nil; btn.viewGroup = nil; btn.drillContributor = e   -- DRILL to Level 3
                    else btn.drillGroup = nil; btn.viewGroup = e; btn.drillContributor = nil end
                else
                    -- Level 1: Overall or Fight row; clicking DRILLS in
                    if btn.clpIcon then btn.clpIcon:Show(false) end; btn.clpIconKey = nil
                    local died = (not e.isOverall) and (e.hasDeath or e.hasKill)
                    local label, cr, cg, cb
                    if e.isOverall then
                        label = "Overall  (" .. (e.count or 0) .. " fights)"; cr, cg, cb = 1, 0.85, 0.3
                    else
                        -- Fight row: bright duration (left) + faint time (right) + death count anchored
                        -- to the skull ("N [skull]" = N deaths). The button's own text is empty; the
                        -- three sub-labels carry it (one label can't be part-bright/part-faint).
                        label = ""
                        if died then cr, cg, cb = 1, 0.4, 0.4 else cr, cg, cb = 0.7, 0.78, 0.9 end
                        local secs = math.floor(e.durSec or 0)
                        local durStr = e.durSec and ((secs >= 60) and string.format("%dm%02ds", math.floor(secs / 60), secs % 60) or (secs .. "s")) or ""
                        local t = tostring(e.time):gsub("[%[%]]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub(":%d%d$", "")  -- HH:MM
                        if btn.durLabel then
                            btn.durLabel:SetText(durStr)
                            if btn.durLabel.style then btn.durLabel.style:SetColor(cr, cg, cb, 1) end
                            btn.durLabel:Show(true)
                        end
                        if btn.timeLabel then btn.timeLabel:SetText(t); btn.timeLabel:Show(true) end
                        if btn.deathLabel and (e.deathCount or 0) > 0 then
                            btn.deathLabel:SetText(tostring(e.deathCount))
                            if btn.deathLabel.style then btn.deathLabel.style:SetColor(cr, cg, cb, 1) end
                            btn.deathLabel:Show(true)
                        end
                        -- Category icon (pickable display): duel > pvp > pve.
                        local cat = e.wasDuel and "duel" or (e.hasPvP and "pvp" or (e.hasPvE and "pve" or nil))
                        if cat and btn.clpIcon then
                            if cat == "duel" then CONFIG._resolveDuelIcon() end  -- use the real Duel buff icon
                            btn.clpIconKey = "__" .. cat .. "__"
                            ClpSetIcon(btn.clpIcon, CONFIG._ovIcon("__" .. cat .. "__"))
                            btn.clpIcon:Show(true)
                        end
                    end
                    if btn.style then btn.style:SetAlign(ALIGN.CENTER) end
                    btn:SetText(label)
                    btn:SetTextColor(cr, cg, cb, 1)
                    btn.drillGroup = e; btn.viewGroup = nil
                    if died and btn.clpMarkIcon then
                        btn.clpMarkKey = "__death__"
                        ClpSetIcon(btn.clpMarkIcon, CONFIG._ovIcon("__death__"))
                        btn.clpMarkIcon:Show(true)   -- raised AFTER the button (below) so it isn't covered
                    end
                end
                btn:Show(true); btn:Raise()
                if btn.clpIcon then btn.clpIcon:Raise() end
                if btn.clpMarkIcon and btn.clpMarkKey then btn.clpMarkIcon:Raise() end  -- on top of the button
            else
                btn:Show(false)
                if btn.clpIcon then btn.clpIcon:Show(false) end
                if btn.clpMarkIcon then btn.clpMarkIcon:Show(false) end
            end
        end
        btnIdx = btnIdx + 1
    end
end
-- Top-anchored list (Overall first): up/wheel-up decrease the offset toward the top.
local function ScrollSession(delta) if delta > 0 then sessionScrollOffset = sessionScrollOffset - 1 else sessionScrollOffset = sessionScrollOffset + 1 end; UpdateSessionList() end
local function ClearAll()
    liveBuffer = {}; masterBuffer = {}; displayBuffer = {}; allSessions = {}
    currentSessionLogs = {}; sessionByTarget = {}; healSessionByTarget = {}; recapData = {}
    fightData = { outgoing = {}, incoming = {} }; healData = { done = {}, received = {} }; CONFIG._shieldAbsorb = nil; CONFIG._fightWasDuel = nil
    if CONFIG._meterReset then CONFIG._meterReset() end
    activeDots = {}; activeCCSessions = {}; sessionScrollOffset = 0; logScrollOffset = 0
    for i = 1, #liveLabels do liveLabels[i]:SetText("") end
    UpdateHistoryDisplay(); UpdateSessionList(true); LogEntry("--- History Cleared ---", 1, 1, 0)
end

-- ============================================================================
--  COMBAT & SCANNER LOGIC
-- ============================================================================

-- Infer damage type from skill table, cache, or mitigation ratio
-- Returns "Melee", "Ranged", "Magic", "Physical", or "Spell"
local function InferDamageType(upAct, skill, absDmg, absorbed, snap)
    -- 1. Manual override table (highest priority).
    --    Normalize smart-apostrophes (U+2019) to ASCII in case game sends them.
    local lookup = skill:gsub("\xe2\x80\x99", "'")
    if SKILL_DAMAGE_TYPES[lookup] then return SKILL_DAMAGE_TYPES[lookup] end

    -- 2. Auto-learned cache from previous hits
    if skillTypeCache[skill] then return skillTypeCache[skill] end

    -- 3. Auto-attacks: actionType is reliable for these
    if string.find(upAct, "MELEE") then return "Melee" end
    if string.find(upAct, "RANGED") then return "Ranged" end

    -- 4. SPELL_DAMAGE / SPELL_DOT_DAMAGE: compare actual mitigation to pen-adjusted armor% vs resist%.
    --    Guard: only infer if we have real stat data for the target — if both are 0 the
    --    comparison is always a tie and would wrongly return "Physical" for magic skills.
    if snap and absorbed > 0 and absDmg > 0 then
        local armorPct  = (snap.targetArmorPct  or 0) / 100
        local resistPct = (snap.targetResistPct or 0) / 100

        if armorPct > 0 or resistPct > 0 then
            local raw    = absDmg + absorbed
            local mitPct = absorbed / raw
            local tDef   = snap.targetDefense or 0
            local tRes   = snap.targetResist  or 0
            local pPen   = snap.playerPhysPen  or 0
            local mPen   = snap.playerMagicPen or 0

            -- Pen-adjusted armor %
            local penAdjArmor = armorPct
            if tDef > 0 and armorPct > 0 and armorPct < 1 then
                local C = tDef * (1 - armorPct) / armorPct
                if pPen >= tDef then penAdjArmor = 0
                elseif pPen > 0 then
                    local effDef = tDef - pPen
                    penAdjArmor = effDef / (effDef + C)
                end
            end

            -- Pen-adjusted resist %
            local penAdjResist = resistPct
            if tRes > 0 and resistPct > 0 and resistPct < 1 then
                local C = tRes * (1 - resistPct) / resistPct
                if mPen >= tRes then penAdjResist = 0
                elseif mPen > 0 then
                    local effRes = tRes - mPen
                    penAdjResist = effRes / (effRes + C)
                end
            end

            local result = (math.abs(mitPct - penAdjArmor) <= math.abs(mitPct - penAdjResist))
                and "Physical" or "Magic"
            skillTypeCache[skill] = result
            return result
        end
    end

    -- No usable mitigation data — fall back to actionType keyword
    if string.find(upAct, "SPELL") then return "Magic" end
    if string.find(upAct, "MELEE") then return "Melee" end
    return "Physical"
end

-- Return the current stack count of a named buff on the player.
-- Reads from playerBuffStackCache, which is refreshed every scanner tick.
-- Returns 0 if the buff is not active, 1+ for the actual stack count.
local function GetPlayerBuffStacks(buffName)
    return playerBuffStackCache[buffName] or 0
end

-- Updates the live-window status badge (kept separate from the static title).
-- Routed through one helper so the big handlers swap a reference instead of
-- each gaining a liveTitleLabel/liveStatusLabel upvalue.
local function SetCombatStatus(inCombatNow)
    local sl = liveTitleLabel and liveTitleLabel.statusLabel
    if not sl then return end
    if inCombatNow then
        sl:SetText("IN COMBAT")
        if sl.style then sl.style:SetColor(1, 0.35, 0.35, 1) end
    else
        sl:SetText("IDLE")
        if sl.style then sl.style:SetColor(0.45, 0.45, 0.45, 1) end
    end
end

local function FinishFight()
    if not inCombat then return end
    inCombat = false
    CONFIG._gameInCombat = false  -- clear in case we closed via the safety net
    CONFIG._diedThisFight = CONFIG._playerDied  -- snapshot before reset; tags this fight's saved sessions
    CONFIG._playerDied = false; CONFIG._targetDeadLogged = false  -- reset death markers for next fight
    CONFIG._lastDmgSrc = nil; CONFIG._deathLogged = nil           -- reset killer-attribution + dedup
    CONFIG._killGrace = nil                                       -- reset deferred-kill queue (mob death lines)
    SetCombatStatus(false)

    -- Print Outgoing Damage Stats
    for id, data in pairs(fightData.outgoing) do
        do
        local tName = data.name or "Target"
        local snap = data.statSnapshot or {}
        local targetingStr = snap.targetIsTargetingPlayer and " [↔]" or ""
        RecordLogForTarget(id, tName, "--- OUTGOING: " .. tName .. targetingStr .. " ---", 0, 1, 1, { logType = "summary" })
        local infoParts = {}
        -- Only show class for player targets (GS > 0); mobs always return generic
        -- archetypes ("mage", "warrior") which are meaningless for NPCs.
        if data.targetClass and data.targetGS and data.targetGS > 0 then
            table.insert(infoParts, "Class: " .. data.targetClass)
        end
        if data.targetGS    then table.insert(infoParts, "GS: " .. data.targetGS) end
        if data.targetMaxHp then table.insert(infoParts, "HP: " .. data.targetMaxHp) end
        if #infoParts > 0 then
            RecordLogForTarget(id, tName, "  " .. table.concat(infoParts, " | "), 0.7, 0.7, 0.7, { logType = "summary" })
        end

        local totalDmg = 0
        for skill, dmg in pairs(data.skills or {}) do
            local sType = (data.skillTypes or {})[skill]
            local typeTag = sType and (" [" .. (TYPE_SHORT[sType] or sType) .. "]") or ""
            RecordLogForTarget(id, tName, "  > " .. skill .. ": " .. dmg .. typeTag, 1, 1, 1, { logType = "summary" })
            totalDmg = totalDmg + dmg
        end

        local duration = 1
        if data.startTime and data.lastUpdate then
            duration = (data.lastUpdate - data.startTime) / 1000
            if duration < 1 then duration = 1 end
        end

        -- Raw totals needed by both the totalDmg block and the snap/mitigation block below
        local meleeDmg  = data.physDmg   or 0
        local meleeAbs  = data.physAbsorbed or 0
        local rangedDmg = data.rangedDmg or 0
        local rangedAbs = data.rangedAbsorbed or 0
        local magicDmg  = data.magicDmg  or 0
        local magicAbs  = data.magicAbsorbed or 0
        local rawPhys   = (data.rawPhysDmg   or 0) > 0 and (data.rawPhysDmg   or 0) or meleeDmg  + meleeAbs
        local rawRanged = (data.rawRangedDmg  or 0) > 0 and (data.rawRangedDmg or 0) or rangedDmg + rangedAbs
        local rawMagic  = (data.rawMagicDmg   or 0) > 0 and (data.rawMagicDmg  or 0) or magicDmg  + magicAbs
        local hasExactRaw = (data.rawPhysDmg or 0) + (data.rawRangedDmg or 0) + (data.rawMagicDmg or 0) > 0
        local rawGrandTotal = rawPhys + rawRanged + rawMagic

        if totalDmg > 0 then
            local dps = totalDmg / duration
            local totalAbs = data.totalAbsorbed or 0

            local typeCount = 0
            if meleeDmg  > 0 then typeCount = typeCount + 1 end
            if rangedDmg > 0 then typeCount = typeCount + 1 end
            if magicDmg  > 0 then typeCount = typeCount + 1 end

            -- Only show per-type lines when more than one type was used
            if typeCount > 1 then
                if meleeDmg > 0 then
                    local mitigated = rawPhys - meleeDmg
                    local mitPct = rawPhys > 0 and (mitigated / rawPhys * 100) or 0
                    RecordLogForTarget(id, tName,
                        string.format("  Melee: %d dealt | %d mitigated (%.1f%%) | %d raw", meleeDmg, mitigated, mitPct, rawPhys),
                        0.9, 0.7, 0.5, { logType = "summary" })
                end
                if rangedDmg > 0 then
                    local mitigated = rawRanged - rangedDmg
                    local mitPct = rawRanged > 0 and (mitigated / rawRanged * 100) or 0
                    RecordLogForTarget(id, tName,
                        string.format("  Ranged: %d dealt | %d mitigated (%.1f%%) | %d raw", rangedDmg, mitigated, mitPct, rawRanged),
                        0.9, 0.7, 0.5, { logType = "summary" })
                end
                if magicDmg > 0 then
                    local mitigated = rawMagic - magicDmg
                    local mitPct = rawMagic > 0 and (mitigated / rawMagic * 100) or 0
                    RecordLogForTarget(id, tName,
                        string.format("  Magic: %d dealt | %d mitigated (%.1f%%) | %d raw", magicDmg, mitigated, mitPct, rawMagic),
                        0.9, 0.7, 0.5, { logType = "summary" })
                end
            end

            local totalMitigated = rawGrandTotal - totalDmg
            local exactTag = hasExactRaw and "" or " (est)"
            local totalLine
            if rawGrandTotal > totalDmg then
                local mitPct = rawGrandTotal > 0 and (totalMitigated / rawGrandTotal * 100) or 0
                totalLine = string.format("  Total DMG: %d raw%s | %d mitigated (%.1f%%) | %d dealt (%.0f DPS | %.1fs)",
                    rawGrandTotal, exactTag, totalMitigated, mitPct, totalDmg, dps, duration)
            else
                totalLine = string.format("  Total DMG: %d dealt (%.0f DPS | %.1fs)", totalDmg, dps, duration)
            end
            RecordLogForTarget(id, tName, totalLine, 0.7, 0.7, 0.7, { logType = "summary" })
            if sessionByTarget[id] then
                sessionByTarget[id].isOutgoing = true
                sessionByTarget[id].dps = dps
                sessionByTarget[id].totalDmg = totalDmg
                sessionByTarget[id].duration = duration
                sessionByTarget[id].totalAbsorbed = totalAbs
            end
        end

        -- Defend / Miss summary
        local defendList, missList = {}, {}
        local totalMissedDmg = 0
        local skills_dm = data.skills or {}
        local hitCounts_dm = data.hitCounts or {}

        for sk, cnt in pairs(data.defends or {}) do
            local avg = (skills_dm[sk] and hitCounts_dm[sk] and hitCounts_dm[sk] > 0)
                        and (skills_dm[sk] / hitCounts_dm[sk]) or 0
            totalMissedDmg = totalMissedDmg + avg * cnt
            table.insert(defendList, cnt .. "x " .. sk)
        end
        for sk, cnt in pairs(data.misses or {}) do
            local avg = (skills_dm[sk] and hitCounts_dm[sk] and hitCounts_dm[sk] > 0)
                        and (skills_dm[sk] / hitCounts_dm[sk]) or 0
            totalMissedDmg = totalMissedDmg + avg * cnt
            table.insert(missList, cnt .. "x " .. sk)
        end
        if #defendList > 0 then
            RecordLogForTarget(id, tName, "  Defended: " .. table.concat(defendList, ", "), 0.55, 0.55, 0.55, { logType = "summary" })
        end
        if #missList > 0 then
            RecordLogForTarget(id, tName, "  Missed:   " .. table.concat(missList, ", "), 0.55, 0.55, 0.55, { logType = "summary" })
        end
        if totalMissedDmg > 0 then
            local missedDps = duration > 0 and (totalMissedDmg / duration) or 0
            RecordLogForTarget(id, tName,
                string.format("  Lost to defend/miss: %d dmg (%.0f DPS)", math.floor(totalMissedDmg), missedDps),
                0.55, 0.55, 0.55, { logType = "summary" })
        end

        -- API-DEAD, PRESERVED FOR RESTORE (not deleted): the per-damage-type Mitigation & pen breakdown
        -- needs the enemy's UnitInfo/UnitModifierInfo (armor%/resist%/toughness/avoidance/incoming-mods),
        -- which the 2026-06-18 lockdown blocks for non-team units -> every enemy line reads 0 and the
        -- pen/hit lines have nothing to apply against. GATED OFF behind CONFIG.MIT_BREAKDOWN (default
        -- false). If Aguru re-allows enemy UnitInfo for the "target" token, flip that flag true and this
        -- whole block lights back up with real data. (The event-sourced per-type "X mitigated (Y%)"
        -- lines above are NOT here -- they always work.)
        local snap = data.statSnapshot
        if CONFIG.MIT_BREAKDOWN and snap then
            local physPct  = (snap.targetArmorPct  or 0) / 100
            local magicPct = (snap.targetResistPct or 0) / 100
            local mitColor = { 0.5, 0.8, 1 }
            local hasTargetStats = (snap.targetArmorPct or 0) > 0 or (snap.targetResistPct or 0) > 0

            -- Toughness (PvP only — applied first, before armor/resist)
            local toughness = snap.targetToughness or 0
            if toughness > 0 and data.targetGS then
                local toughPct = toughness / (toughness + 8000) * 100
                local toughLost = math.floor(rawGrandTotal * toughPct / 100)
                RecordLogForTarget(id, tName,
                    string.format("  Toughness: %d (%.1f%% reduction) | Lost ~%d dmg before armor/resist",
                        toughness, toughPct, toughLost),
                    mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
            end
            local penColor = { 0.4, 1, 0.4 }

            -- rawPhys/rawRanged/rawMagic/hasExactRaw already defined above in totalDmg block
            local rawMeleeRanged = rawPhys + rawRanged

            local tDef = snap.targetDefense  or 0
            local tRes = snap.targetResist   or 0
            local pPen = snap.playerPhysPen  or 0
            local mPen = snap.playerMagicPen or 0

            -- Toughness applies first (PvP only), so armor/resist only sees the post-toughness portion
            local toughFrac = toughness > 0 and data.targetGS and (toughness / (toughness + 8000)) or 0
            local postToughMeleeRanged = rawMeleeRanged * (1 - toughFrac)
            local postToughMagic       = rawMagic       * (1 - toughFrac)

            -- Pen-adjusted armor %
            local penAdjPhysPct = physPct
            local physPenBonus = 0
            if tDef > 0 and physPct > 0 and physPct < 1 then
                local C = tDef * (1 - physPct) / physPct
                if pPen >= tDef then penAdjPhysPct = 0
                elseif pPen > 0 then
                    local effDef = tDef - pPen
                    penAdjPhysPct = effDef / (effDef + C)
                end
                if postToughMeleeRanged > 0 and penAdjPhysPct < physPct then
                    physPenBonus = postToughMeleeRanged * (physPct - penAdjPhysPct)
                end
            end

            -- Pen-adjusted resist %
            local penAdjMagicPct = magicPct
            local magicPenBonus = 0
            if tRes > 0 and magicPct > 0 and magicPct < 1 then
                local C = tRes * (1 - magicPct) / magicPct
                if mPen >= tRes then penAdjMagicPct = 0
                elseif mPen > 0 then
                    local effRes = tRes - mPen
                    penAdjMagicPct = effRes / (effRes + C)
                end
                if postToughMagic > 0 and penAdjMagicPct < magicPct then
                    magicPenBonus = postToughMagic * (magicPct - penAdjMagicPct)
                end
            end

            -- With exact raw data: mitigated = raw - dealt (no estimation needed for total)
            local estArmorLost = hasExactRaw
                and math.max(0, postToughMeleeRanged - (data.physDmg or 0) - (data.rangedDmg or 0))
                or  (postToughMeleeRanged > 0 and (postToughMeleeRanged * penAdjPhysPct) or 0)
            local estMagicLost = hasExactRaw
                and math.max(0, postToughMagic - (data.magicDmg or 0))
                or  (postToughMagic > 0 and (postToughMagic * penAdjMagicPct) or 0)

            -- Physical block: defense + pen + avoidance (melee & ranged share armor)
            if rawMeleeRanged > 0 then
                local physLabel = (rawPhys > 0 and rawRanged > 0) and "Phys/Ranged"
                               or (rawRanged > 0)                  and "Ranged"
                               or                                      "Phys"
                local armorMitStr = estArmorLost > 0
                    and string.format(" | Lost %d dmg", math.floor(estArmorLost)) or ""
                if hasTargetStats then
                    RecordLogForTarget(id, tName,
                        string.format("  %s def: %d (%.1f%% base | %.1f%% eff)%s",
                            physLabel, tDef, snap.targetArmorPct or 0, penAdjPhysPct * 100, armorMitStr),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
                -- Phys pen + bonus
                local physPenStr = string.format("  %s pen: %d", physLabel, pPen)
                if physPenBonus > 0 then
                    local physPenDps = duration > 0 and (physPenBonus / duration) or 0
                    physPenStr = physPenStr .. string.format(" | Gained +%d dmg (+%.0f DPS)", math.floor(physPenBonus), physPenDps)
                end
                RecordLogForTarget(id, tName, physPenStr, penColor[1], penColor[2], penColor[3], { logType = "summary" })
                -- Avoidance
                local dodge = snap.targetDodge or 0
                local block = snap.targetBlock or 0
                local parry = snap.targetParry or 0
                if dodge > 0 or block > 0 or parry > 0 then
                    RecordLogForTarget(id, tName,
                        string.format("  Dodge: %.1f%% | Block: %.1f%% | Parry: %.1f%%", dodge, block, parry),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
                -- Hit rate (melee and ranged share the same stat)
                local meleeHit = snap.playerMeleeHit or 100
                if meleeHit < 99.9 then
                    local hitLabel = (rawPhys > 0 and rawRanged > 0) and "Melee/Ranged"
                                  or (rawRanged > 0)                  and "Ranged"
                                  or                                      "Melee"
                    RecordLogForTarget(id, tName,
                        string.format("  %s hit rate: %.1f%%", hitLabel, meleeHit),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
            end

            -- Magic block: resist + pen
            if rawMagic > 0 then
                local magicMitStr = estMagicLost > 0
                    and string.format(" | Lost %d dmg", math.floor(estMagicLost)) or ""
                if hasTargetStats then
                    RecordLogForTarget(id, tName,
                        string.format("  Magic res: %d (%.1f%% base | %.1f%% eff)%s",
                            tRes, snap.targetResistPct or 0, penAdjMagicPct * 100, magicMitStr),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
                -- Magic pen + bonus
                local magicPenStr = string.format("  Magic pen: %d", mPen)
                if magicPenBonus > 0 then
                    local magicPenDps = duration > 0 and (magicPenBonus / duration) or 0
                    magicPenStr = magicPenStr .. string.format(" | Gained +%d dmg (+%.0f DPS)", math.floor(magicPenBonus), magicPenDps)
                end
                RecordLogForTarget(id, tName, magicPenStr, penColor[1], penColor[2], penColor[3], { logType = "summary" })
                -- Magic hit rate
                local spellHit = snap.playerSpellHit or 100
                if spellHit < 99.9 then
                    RecordLogForTarget(id, tName,
                        string.format("  Magic hit rate: %.1f%%", spellHit),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
            end

            -- Incoming damage modifiers — zero out types not actually used so unused types are silently skipped
            local imm = rawPhys   > 0 and (snap.targetIncomingMeleeMul  or 0) or 0
            local imr = rawRanged > 0 and (snap.targetIncomingRangedMul or 0) or 0
            local ims = rawMagic  > 0 and (snap.targetIncomingSpellMul  or 0) or 0
            local imv = rawPhys   > 0 and (snap.targetIncomingMeleeVal  or 0) or 0
            local irv = rawRanged > 0 and (snap.targetIncomingRangedVal or 0) or 0
            local isv = rawMagic  > 0 and (snap.targetIncomingSpellVal  or 0) or 0
            local modParts = {}
            if imm ~= 0 then table.insert(modParts, string.format("Melee %+.1f%%", imm)) end
            if imr ~= 0 then table.insert(modParts, string.format("Ranged %+.1f%%", imr)) end
            if ims ~= 0 then table.insert(modParts, string.format("Magic %+.1f%%", ims)) end
            if imv ~= 0 then table.insert(modParts, string.format("Melee %+d/hit", imv)) end
            if irv ~= 0 then table.insert(modParts, string.format("Ranged %+d/hit", irv)) end
            if isv ~= 0 then table.insert(modParts, string.format("Magic %+d/hit", isv)) end
            local modParts2 = {}
            for _, p in ipairs(modParts) do modParts2[#modParts2 + 1] = p end
            if #modParts2 > 0 then
                RecordLogForTarget(id, tName,
                    "  Modifiers: " .. table.concat(modParts2, " | "),
                    mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
            end
        end

        if data.ccDurations then
            for ccName, dur in pairs(data.ccDurations) do
                local c = GetSafeColor(CONFIG.COL_CC)
                RecordLogForTarget(id, tName, string.format("  > %s: %.1fs", ccName, dur), c[1], c[2], c[3], { logType = "summary" })
            end
        end

        -- Zeal summary
        local finalZealTime = fightZealTime
        if zealActive and zealStartTime then
            finalZealTime = finalZealTime + (api.Time:GetUiMsec() - zealStartTime)
        end
        -- Damage breakdown: Base + Crit + Zeal + Chanty + Rhythm + new mechanics = Total
        local critBonusDmg       = data.critBonusDmg          or 0
        local chantyBonusDmg2    = data.chantyBonusDmg        or 0
        local zealExtraDmg2      = data.zealExtraDmg          or 0
        local rhythmBonusDmg     = data.rhythmBonusDmg        or 0
        local mcBonusDmg         = data.magicCircleBonusDmg   or 0
        local deliriumBonusDmg   = data.deliriumBonusDmg      or 0
        local bbBonusDmg         = data.burningBrandBonusDmg  or 0
        local opBonusDmg         = data.overpoweredBonusDmg   or 0
        local assassinBonusDmg   = data.assassinationBonusDmg or 0
        local inspiredBonusDmg   = data.inspiredBonusDmg      or 0
        local totalDealt = (data.magicDmg or 0) + (data.physDmg or 0) + (data.rangedDmg or 0)
        local baseDmg = math.max(0, totalDealt - critBonusDmg - zealExtraDmg2 - chantyBonusDmg2 - rhythmBonusDmg
            - mcBonusDmg - deliriumBonusDmg - bbBonusDmg - opBonusDmg - assassinBonusDmg - inspiredBonusDmg)
        if (critBonusDmg > 0 or chantyBonusDmg2 > 0 or zealExtraDmg2 > 0 or rhythmBonusDmg > 0
        or mcBonusDmg > 0 or deliriumBonusDmg > 0 or bbBonusDmg > 0 or opBonusDmg > 0
        or assassinBonusDmg > 0 or inspiredBonusDmg > 0) and duration > 0 then
            local baseDps = baseDmg / duration
            local baseColor = { 0.75, 0.75, 0.75 }
            RecordLogForTarget(id, tName,
                string.format("  Base: %d dmg (%.0f DPS)", baseDmg, baseDps),
                baseColor[1], baseColor[2], baseColor[3], { logType = "summary" })
        end
        if critBonusDmg > 0 and duration > 0 then
            local critDps = critBonusDmg / duration
            local critColor = { 1, 0.85, 0.2 }
            RecordLogForTarget(id, tName,
                string.format("  [*] Crit bonus: +%d dmg (+%.0f DPS)",
                    critBonusDmg, critDps),
                critColor[1], critColor[2], critColor[3], { logType = "summary" })
        end

        local zealDmg  = data.zealDmg  or 0
        local zealHits = data.zealHits or 0
        local zealExtraDmg = data.zealExtraDmg or 0
        if zealExtraDmg > 0 and duration > 0 then
            local zealExtraDps = zealExtraDmg / duration
            local zealColor = { 0.85, 0.4, 1 }
            RecordLogForTarget(id, tName,
                string.format("  [Z] Zeal crits: +%d bonus dmg (+%.0f DPS)",
                    zealExtraDmg, zealExtraDps),
                zealColor[1], zealColor[2], zealColor[3], { logType = "summary" })
        end

        -- Chanty summary
        local chantyBonusDmg = data.chantyBonusDmg or 0
        if chantyBonusDmg > 0 and duration > 0 then
            local chantyDps = chantyBonusDmg / duration
            local chantyColor = { 0.4, 0.85, 1 }
            RecordLogForTarget(id, tName,
                string.format("  [C] Chanty: +%d bonus dmg (+%.0f DPS)",
                    chantyBonusDmg, chantyDps),
                chantyColor[1], chantyColor[2], chantyColor[3], { logType = "summary" })
        end

        -- Rhythm summary
        local rhythmBonusDmg = data.rhythmBonusDmg or 0
        if rhythmBonusDmg > 0 and duration > 0 then
            local rhythmDps = rhythmBonusDmg / duration
            local rhythmColor = { 0.6, 1, 0.6 }
            RecordLogForTarget(id, tName,
                string.format("  [R] Rhythm: +%d bonus dmg (+%.0f DPS)",
                    rhythmBonusDmg, rhythmDps),
                rhythmColor[1], rhythmColor[2], rhythmColor[3], { logType = "summary" })
        end

        -- Magic Circle summary (Sorcery)
        if mcBonusDmg > 0 and duration > 0 then
            RecordLogForTarget(id, tName,
                string.format("  [MC] Magic Circle: +%d bonus dmg (+%.0f DPS)",
                    mcBonusDmg, mcBonusDmg / duration),
                0.4, 0.7, 1, { logType = "summary" })
        end

        -- Delirium summary (Battlerage)
        if deliriumBonusDmg > 0 and duration > 0 then
            RecordLogForTarget(id, tName,
                string.format("  [D] Delirium: +%d bonus dmg (+%.0f DPS)",
                    deliriumBonusDmg, deliriumBonusDmg / duration),
                1, 0.55, 0.2, { logType = "summary" })
        end

        -- Burning Brand summary (Occultism)
        if bbBonusDmg > 0 and duration > 0 then
            RecordLogForTarget(id, tName,
                string.format("  [BB] Burning Brand: +%d bonus dmg (+%.0f DPS)",
                    bbBonusDmg, bbBonusDmg / duration),
                1, 0.35, 0.35, { logType = "summary" })
        end

        -- Overpowered Spell Locus summary (Occultism)
        if opBonusDmg > 0 and duration > 0 then
            RecordLogForTarget(id, tName,
                string.format("  [OS] Op. Spell Locus: +%d bonus dmg (+%.0f DPS)",
                    opBonusDmg, opBonusDmg / duration),
                0.85, 0.55, 1, { logType = "summary" })
        end

        -- Assassination summary (Shadowplay)
        if assassinBonusDmg > 0 and duration > 0 then
            RecordLogForTarget(id, tName,
                string.format("  [AS] Assassination: +%d bonus dmg (+%.0f DPS)",
                    assassinBonusDmg, assassinBonusDmg / duration),
                0.8, 0.8, 0.25, { logType = "summary" })
        end

        -- Inspired summary (Auramancy — Vicious Implosion only)
        if inspiredBonusDmg > 0 and duration > 0 then
            RecordLogForTarget(id, tName,
                string.format("  [IN] Inspired: +%d bonus dmg (+%.0f DPS)",
                    inspiredBonusDmg, inspiredBonusDmg / duration),
                0.65, 0.95, 0.65, { logType = "summary" })
        end

        -- Battle Focus note: boosts melee_critical_bonus stat (captured in critExtra via snapshot)
        if data.battleFocusWasActive then
            RecordLogForTarget(id, tName,
                "  [BF] Battle Focus: active (+20% melee crit dmg, included in crit total)",
                0.95, 0.55, 0.2, { logType = "summary" })
        end

        -- Intensified Harm note: boosts all crit via stat (captured in critExtra via snapshot)
        if data.intensifiedHarmWasActive then
            RecordLogForTarget(id, tName,
                "  [IH] Intensified Harm: active (+25% all crit dmg, included in crit total)",
                1, 0.3, 0.55, { logType = "summary" })
        end

        -- Combo summary
        local comboHits     = data.comboHits or 0
        local comboBonusDmg = data.comboBonusDmg or 0
        if comboHits > 0 then
            local comboDps = duration > 0 and (comboBonusDmg / duration) or 0
            local comboSkills = data.comboSkills or {}
            local skillList = {}
            for sName, info in pairs(comboSkills) do
                skillList[#skillList+1] = { name=sName, info=info }
            end
            table.sort(skillList, function(a, b) return a.info.bonusDmg > b.info.bonusDmg end)
            local numSkills = #skillList
            local header = numSkills == 1
                and "  Skill Comboed:"
                or  string.format("  Skills Comboed x%d:", numSkills)
            RecordLogForTarget(id, tName,
                string.format("%s ~%d bonus dmg (%.0f DPS)",
                    header, math.floor(comboBonusDmg), comboDps),
                1, 0.8, 0.2, { logType = "summary" })
            for _, entry in ipairs(skillList) do
                local info = entry.info
                local skillDps = duration > 0 and (info.bonusDmg / duration) or 0
                local condTag = info.cond and (" [" .. info.cond .. (info.pct and (" +" .. info.pct .. "%") or "") .. "]") or ""
                local hitStr = info.hits > 1 and (" x" .. info.hits) or ""
                local bonusStr = info.bonusDmg > 0
                    and string.format(" | ~%d bonus (+%d DPS)", math.floor(info.bonusDmg), math.floor(skillDps))
                    or ""
                RecordLogForTarget(id, tName,
                    string.format("    %s%s%s%s",
                        info.skillName, condTag, hitStr, bonusStr),
                    1, 0.8, 0.2, { logType = "summary" })
            end
        end

        -- Backstab summary
        local snap = data.statSnapshot
        local bsMelee  = snap and ((snap.playerBackstabMelee  or 0) / 10) or 0
        local bsRanged = snap and ((snap.playerBackstabRanged or 0) / 10) or 0
        local bsSpell  = snap and ((snap.playerBackstabSpell  or 0) / 10) or 0
        local bsHits = data.backstabHits or 0
        if bsHits > 0 then
            local bsDmg = data.backstabDmg or 0
            local bsDps = duration > 0 and (bsDmg / duration) or 0
            local totalHits = 0
            for _, cnt in pairs(data.hitCounts or {}) do totalHits = totalHits + cnt end
            local bsPct = totalHits > 0 and (bsHits / totalHits * 100) or 0
            RecordLogForTarget(id, tName,
                string.format("  Backstab: %d hits (%.0f%%) | %d dmg (%.0f DPS)",
                    bsHits, bsPct, math.floor(bsDmg), bsDps),
                0.8, 0.5, 1, { logType = "summary" })
        end
        if bsMelee > 0 or bsRanged > 0 or bsSpell > 0 then
            local parts = {}
            if bsMelee  > 0 then parts[#parts+1] = string.format("Melee +%.1f%%",  bsMelee)  end
            if bsRanged > 0 then parts[#parts+1] = string.format("Ranged +%.1f%%", bsRanged) end
            if bsSpell  > 0 then parts[#parts+1] = string.format("Spell +%.1f%%",  bsSpell)  end
            RecordLogForTarget(id, tName,
                "  Backstab passive: " .. table.concat(parts, " | "),
                0.8, 0.5, 1, { logType = "summary" })
        end
        local bsSkillHits = data.backstabSkillHits
        if bsSkillHits then
            local parts = {}
            for sName, cnt in pairs(bsSkillHits) do
                local info = SKILL_BACKSTAB_BONUSES[sName]
                local label = info and info.formula or "?"
                if info and info.stealth then
                    label = label .. string.format(" +%d%% stealth", info.stealth)
                end
                parts[#parts+1] = string.format("%s x%d (%s)", sName, cnt, label)
            end
            if #parts > 0 then
                RecordLogForTarget(id, tName,
                    "  Backstab skill bonus: " .. table.concat(parts, ", "),
                    0.8, 0.5, 1, { logType = "summary" })
            end
        end

        -- Invincibility summary
        local invSkills = data.invincibleSkills or {}
        local invList = {}
        for sk, cnt in pairs(invSkills) do
            table.insert(invList, cnt .. "x " .. sk)
        end
        if #invList > 0 then
            RecordLogForTarget(id, tName,
                "  [Invincible] Eaten: " .. table.concat(invList, ", "),
                0.6, 0.2, 0.2, { logType = "summary" })
        end

        -- Spell Shield summary
        local ssDmg = data.spellShieldDmg or 0
        local ssHealed = data.spellShieldHealed or 0
        if ssHealed > 0 then
            RecordLogForTarget(id, tName,
                string.format("  [Spell Shield] %d magic dmg healed target for %d HP", ssDmg, ssHealed),
                1, 0.3, 0.3, { logType = "summary" })
        end

        -- Rune conversion summary
        local runeHealed = data.runeConvertDmg or 0
        if runeHealed > 0 then
            local runeName = data.runeConvertName or "Rune"
            local runePct = data.runeConvertPct or 0
            RecordLogForTarget(id, tName,
                string.format("  [%s] %.1f%% conversion healed target for %d HP", runeName, runePct, runeHealed),
                1, 0.5, 0.3, { logType = "summary" })
        end

        -- Damage shield summary
        for shName, shData in pairs(data.dmgShields or {}) do
            local shStr
            if shData.max > 0 then
                shStr = string.format("  [%s] Absorbed up to %d | %d raw dmg hit while active", shName, shData.max, shData.rawDmg)
            else
                shStr = string.format("  [%s] Active | %d raw dmg hit while active", shName, shData.rawDmg)
            end
            RecordLogForTarget(id, tName, shStr, 0.5, 0.8, 1, { logType = "summary" })
        end

        end -- per-target outgoing summary
    end

    -- Reset Zeal state for next fight
    -- Don't reset zealActive/chantyActive/bulwarkActive — scanner updates them every tick.
    -- Resetting here causes missed detection on the first hit of the next fight.
    zealStartTime = nil
    fightZealTime = 0

    -- Print Incoming Damage Stats (no heals mixed in)
    -- Pre-pass: count how many entries share the same display name (same-named PvE mobs)
    local incomingNameCount = {}
    local incomingNameIndex = {}
    for key, data in pairs(fightData.incoming) do
        local baseName = data.displayName or key
        incomingNameCount[baseName] = (incomingNameCount[baseName] or 0) + 1
        incomingNameIndex[baseName] = 0
    end

    for name, data in pairs(fightData.incoming) do
        local baseName = data.displayName or name
        local displayName
        if incomingNameCount[baseName] > 1 then
            incomingNameIndex[baseName] = incomingNameIndex[baseName] + 1
            displayName = baseName .. " #" .. incomingNameIndex[baseName]
        else
            displayName = baseName
        end
        RecordLogForTarget(name, displayName, "--- INCOMING: " .. displayName .. " ---", 1, 0, 0, { logType = "summary" })

        local totalDmg = 0
        for skill, dmg in pairs(data.skills or {}) do
            RecordLogForTarget(name, displayName, "  < " .. skill .. ": " .. dmg, 1, 0.5, 0.5, { logType = "summary" })
            totalDmg = totalDmg + dmg
        end
        if totalDmg > 0 then
            local duration = 1
            if data.startTime and data.lastUpdate then
                duration = (data.lastUpdate - data.startTime) / 1000
                if duration < 1 then duration = 1 end
            end
            local totalAbs = data.totalAbsorbed or 0
            local totalLine
            if totalAbs > 0 then
                local rawTotal = totalDmg + totalAbs
                local absPct = rawTotal > 0 and (totalAbs / rawTotal * 100) or 0
                totalLine = string.format("  Total DMG: %d raw | %d absorbed (%.1f%%) | %d taken (%.1fs)",
                    rawTotal, totalAbs, absPct, totalDmg, duration)
            else
                totalLine = string.format("  Total DMG: %d taken (%.1fs)", totalDmg, duration)
            end
            RecordLogForTarget(name, displayName, totalLine, 1, 0.3, 0.3, { logType = "summary" })
            if sessionByTarget[name] then
                sessionByTarget[name].totalDmg = totalDmg
                sessionByTarget[name].duration = duration
                sessionByTarget[name].totalAbsorbed = totalAbs
            end

            -- Shield/conversion absorbs (Absorb Damage, runes, Insulating Lens) -- player-level
            -- mitigation surfaced here for the tanking view. Header total + one line per source
            -- (sorted big->small). Each source line uses the "+ Skill: N" shape so the summary
            -- render attaches that skill's icon; the "(Rank N)" suffix is stripped so it resolves.
            if CONFIG._shieldAbsorb then
                local order, sTot = {}, 0
                for sk, amt in pairs(CONFIG._shieldAbsorb) do order[#order + 1] = sk; sTot = sTot + amt end
                if sTot > 0 then
                    RecordLogForTarget(name, displayName, "  Shields absorbed: " .. sTot,
                        0.5, 0.85, 1, { logType = "summary" })
                    table.sort(order, function(a, b) return CONFIG._shieldAbsorb[a] > CONFIG._shieldAbsorb[b] end)
                    for _, sk in ipairs(order) do
                        local disp = (sk:gsub("%s*%(Rank%s*%d+%)", ""))
                        RecordLogForTarget(name, displayName,
                            "  + " .. disp .. ": " .. CONFIG._shieldAbsorb[sk],
                            0.4, 0.75, 0.95, { logType = "summary" })
                    end
                end
            end

            local defSnap = data.defSnap
            if defSnap then
                local rawPhys        = (data.physDmg   or 0) + (data.physAbsorbed   or 0)
                local rawRanged      = (data.rangedDmg  or 0) + (data.rangedAbsorbed or 0)
                local rawMagic       = (data.magicDmg  or 0) + (data.magicAbsorbed  or 0)
                local rawMeleeRanged = rawPhys + rawRanged
                local mitColor       = { 0.5, 0.8, 1 }

                if rawMeleeRanged > 0 then
                    RecordLogForTarget(name, displayName,
                        string.format("  Your armor: %d (%.1f%% base)", defSnap.armor, defSnap.armorPct),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
                if rawMagic > 0 then
                    RecordLogForTarget(name, displayName,
                        string.format("  Your magic res: %d (%.1f%% base)", defSnap.resist, defSnap.resistPct),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
                if defSnap.toughness > 0 and data.isPvP then  -- toughness is PvP-only
                    RecordLogForTarget(name, displayName,
                        string.format("  Your Toughness: %d", defSnap.toughness),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end

                if rawMeleeRanged > 0 then
                    local dodge = defSnap.dodge or 0
                    local block = defSnap.block or 0
                    local parry = defSnap.parry or 0
                    if dodge > 0 or block > 0 or parry > 0 then
                        RecordLogForTarget(name, displayName,
                            string.format("  Your dodge: %.1f%% | Block: %.1f%% | Parry: %.1f%%", dodge, block, parry),
                            mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                    end
                end

                -- Incoming damage mods (condensed)
                local imm = rawPhys   > 0 and (defSnap.incomingMeleeMul  or 0) or 0
                local imr = rawRanged > 0 and (defSnap.incomingRangedMul or 0) or 0
                local ims = rawMagic  > 0 and (defSnap.incomingSpellMul  or 0) or 0
                local imv = rawPhys   > 0 and (defSnap.incomingMeleeVal  or 0) or 0
                local irv = rawRanged > 0 and (defSnap.incomingRangedVal or 0) or 0
                local isv = rawMagic  > 0 and (defSnap.incomingSpellVal  or 0) or 0
                local modParts = {}
                if imm ~= 0 then table.insert(modParts, string.format("Melee %+.1f%%", imm)) end
                if imr ~= 0 then table.insert(modParts, string.format("Ranged %+.1f%%", imr)) end
                if ims ~= 0 then table.insert(modParts, string.format("Magic %+.1f%%", ims)) end
                if imv ~= 0 then table.insert(modParts, string.format("Melee %+d/hit", imv)) end
                if irv ~= 0 then table.insert(modParts, string.format("Ranged %+d/hit", irv)) end
                if isv ~= 0 then table.insert(modParts, string.format("Magic %+d/hit", isv)) end
                if #modParts > 0 then
                    RecordLogForTarget(name, displayName,
                        "  Modifiers: " .. table.concat(modParts, " | "),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
            end

            -- Bulwark Ballad summary
            local bulwarkPrevented = data.bulwarkPrevented or 0
            if bulwarkPrevented > 0 and duration > 0 then
                local bulwarkDps = bulwarkPrevented / duration
                local bulwarkColor = { 0.4, 1, 0.6 }
                RecordLogForTarget(name, displayName,
                    string.format("  [B] Ballad prevented: +%d dmg (+%.0f DPS)",
                        bulwarkPrevented, bulwarkDps),
                    bulwarkColor[1], bulwarkColor[2], bulwarkColor[3], { logType = "summary" })
            end

            -- Shield absorb summary (per player-cast shield active during this fight)
            if data.shieldAbsorbed then
                local shieldColor = { 0.5, 0.8, 1 }
                for sname, samt in pairs(data.shieldAbsorbed) do
                    if samt > 0 then
                        RecordLogForTarget(name, displayName,
                            string.format("  [S] %s absorbed: %d dmg", sname, samt),
                            shieldColor[1], shieldColor[2], shieldColor[3], { logType = "summary" })
                    end
                end
            end
        end

        if sessionByTarget[name] then sessionByTarget[name].isIncoming = true end
    end

    -- Healing Done Summary (separate green sessions)
    if CONFIG.SHOW_HEALS then
    local c = GetSafeColor(CONFIG.COL_HEAL)
    for targetName, data in pairs(healData.done) do
        local key = "done_" .. targetName
        RecordHealLog(key, targetName, "--- HEALED: " .. targetName .. " ---", c[1], c[2], c[3], { logType = "summary" })
        local totalHeal = 0
        for skill, amount in pairs(data.skills) do
            RecordHealLog(key, targetName, "  + " .. skill .. ": " .. amount, c[1], c[2], c[3], { logType = "summary" })
            totalHeal = totalHeal + amount
        end
        if totalHeal > 0 then
            local duration = 1
            if data.startTime and data.lastUpdate then
                duration = (data.lastUpdate - data.startTime) / 1000
                if duration < 1 then duration = 1 end
            end
            local hps = totalHeal / duration
            if healSessionByTarget[key] then
                healSessionByTarget[key].totalHeal = totalHeal
                healSessionByTarget[key].hps = hps
                healSessionByTarget[key].duration = duration
            end
            RecordHealLog(key, targetName, string.format("  Total: %d (%.0f HPS | %.1fs)", totalHeal, hps, duration), c[1]*0.7, c[2]*0.7, c[3]*0.7, { logType = "summary" })
            local critHealBonus  = data.critHealBonus or 0
            local zealHealBonus  = data.zealHealBonus or 0
            local healPowerBonus = data.healPowerBonus or 0
            local healMulBonus   = data.healMulBonus or 0
            local healCrits      = data.healCrits or 0
            if critHealBonus > 0 then
                RecordHealLog(key, targetName,
                    string.format("  [*] Crit healing: +%d (+%.0f HPS) over %d crits",
                        critHealBonus, critHealBonus / duration, healCrits),
                    1, 0.85, 0.2, { logType = "summary" })
            end
            if zealHealBonus > 0 then
                RecordHealLog(key, targetName,
                    string.format("  [Z] Zeal crit healing: +%d (+%.0f HPS)",
                        zealHealBonus, zealHealBonus / duration),
                    0.85, 0.4, 1, { logType = "summary" })
            end
            if healPowerBonus > 0 then
                RecordHealLog(key, targetName,
                    string.format("  [H] Heal power (Rhythm/Ode): +%d (+%.0f HPS)",
                        healPowerBonus, healPowerBonus / duration),
                    0.5, 1, 0.8, { logType = "summary" })
            end
            if healMulBonus > 0 then
                RecordHealLog(key, targetName,
                    string.format("  [H] Heal %% buffs: +%d (+%.0f HPS)",
                        healMulBonus, healMulBonus / duration),
                    0.5, 1, 0.8, { logType = "summary" })
            end
            if (critHealBonus + zealHealBonus + healPowerBonus + healMulBonus) > 0 then
                local baseHeal = math.max(0, totalHeal - critHealBonus - zealHealBonus - healPowerBonus - healMulBonus)
                RecordHealLog(key, targetName,
                    string.format("  Base healing: %d (%.0f HPS)", baseHeal, baseHeal / duration),
                    c[1]*0.7, c[2]*0.7, c[3]*0.7, { logType = "summary" })
            end
            if (data.overhealTotal or 0) > 0 then
                local ohPctSum = totalHeal > 0 and math.floor(data.overhealTotal / totalHeal * 100) or 0
                RecordHealLog(key, targetName,
                    string.format("  Overheal: %d (%d%% of total)", data.overhealTotal, ohPctSum),
                    0.55, 0.75, 0.95, { logType = "summary" })
            end
            local hSnap = data.healSnap
            if hSnap then
                local statParts = {}
                if hSnap.healCritRate > 0 then
                    table.insert(statParts, string.format("Crit %.1f%% (+%.0f%%)", hSnap.healCritRate, hSnap.healCritBonus))
                end
                if hSnap.healMul ~= 0 then
                    table.insert(statParts, string.format("Heal power %+.1f%%", hSnap.healMul))
                end
                if hSnap.castingTime < 99 then
                    table.insert(statParts, string.format("Cast time %.0f%% of base", hSnap.castingTime))
                end
                if #statParts > 0 then
                    RecordHealLog(key, targetName, "  [Heal Stats] " .. table.concat(statParts, " | "), c[1]*0.7, c[2]*0.7, c[3]*0.7, { logType = "summary" })
                end
            end
        end
    end
    end -- SHOW_HEALS

    -- Healing Received Summary (separate green sessions)
    if CONFIG.SHOW_HEALS then
    local c = GetSafeColor(CONFIG.COL_HEAL)
    for sourceName, data in pairs(healData.received) do
        local key = "recv_" .. sourceName
        RecordHealLog(key, sourceName, "--- HEALED BY: " .. sourceName .. " ---", c[1], c[2], c[3], { logType = "summary" })
        local totalHeal = 0
        for skill, amount in pairs(data.skills) do
            RecordHealLog(key, sourceName, "  + " .. skill .. ": " .. amount, c[1], c[2], c[3], { logType = "summary" })
            totalHeal = totalHeal + amount
        end
        if totalHeal > 0 then
            local duration = 1
            if data.startTime and data.lastUpdate then
                duration = (data.lastUpdate - data.startTime) / 1000
                if duration < 1 then duration = 1 end
            end
            local hps = totalHeal / duration
            if healSessionByTarget[key] then
                healSessionByTarget[key].totalHeal = totalHeal
                healSessionByTarget[key].hps = hps
                healSessionByTarget[key].duration = duration
            end
            RecordHealLog(key, sourceName, string.format("  Total: %d (%.0f HPS | %.1fs)", totalHeal, hps, duration), c[1]*0.7, c[2]*0.7, c[3]*0.7, { logType = "summary" })
            local okP, pInfo = pcall(function() return api.Unit:UnitInfo("player") end)
            if okP and pInfo then
                local incomingHealMul = tonumber(pInfo.incoming_heal_mul or 0)
                if incomingHealMul ~= 0 then
                    RecordHealLog(key, sourceName,
                        string.format("  [Heal received mod] %+.1f%%", incomingHealMul),
                        c[1]*0.7, c[2]*0.7, c[3]*0.7, { logType = "summary" })
                end
            end
        end
    end
    end -- SHOW_HEALS

    -- Per-fight revive tally (single-target Revive YOU cast -- often mid-fight via a stealth
    -- combat-drop, so it belongs to THIS fight). Emitted at fight end; the count then resets.
    if (CONFIG._fightReviveCount or 0) > 0 then
        LogEntry(string.format("      Revives this fight: %d", CONFIG._fightReviveCount), 0.4, 1, 0.7)
    end
    CONFIG._fightReviveCount = 0

    -- Fight separator in the live feed -- only when this fight actually logged a live line,
    -- so empty/aborted combats (brief flag, stray proc, target tab) don't spam dividers.
    if CONFIG._liveSinceDiv then
        LogEntry("---------------------------", 0.5, 0.5, 0.5)
    end
    CONFIG._liveSinceDiv = false  -- reset for the next fight

    -- Save damage sessions. One fightId per FinishFight tags all of this fight's sessions
    -- (player + recap) so history can group by fight instead of by name.
    local timeStr = GetTimestamp()
    local savedCount = 0
    CONFIG._fightId = (CONFIG._fightId or 0) + 1
    -- Freeze this fight's Raid Meter aggregate, keyed by fightId (parallel to allSessions).
    if CONFIG.RAID_METER and CONFIG._meterAgg then pcall(function()
        CONFIG._fightMeters = CONFIG._fightMeters or {}
        local mrows, mdur = {}, 0
        for _, a in pairs(CONFIG._meterAgg) do mrows[#mrows + 1] = a end
        for _, s in pairs(sessionByTarget) do if (s.duration or 0) > mdur then mdur = s.duration end end
        CONFIG._fightMeters[CONFIG._fightId] = { rows = mrows, durSec = mdur, time = timeStr }
        local minKeep = CONFIG._fightId - 60   -- keep only the most recent ~60 fights' meters
        for fid in pairs(CONFIG._fightMeters) do if fid <= minKeep then CONFIG._fightMeters[fid] = nil end end
    end) end
    for id, data in pairs(sessionByTarget) do
        if data.logs and #data.logs > 0 then
            table.insert(allSessions, {
                time = timeStr, fightId = CONFIG._fightId, targetName = data.name, targetId = id, logs = data.logs,
                who = (data.name == PLAYER_NAME) and "ally" or CONFIG._classifyUnit(data.name, id),  -- opponent class (icon + WHO filter)
                isIncoming = data.isIncoming, isOutgoing = data.isOutgoing,
                dps = data.dps or 0, totalDmg = data.totalDmg or 0,
                duration = data.duration or 0, totalAbsorbed = data.totalAbsorbed or 0,
                endedInDeath = CONFIG._diedThisFight,
                endedInKill = (data.isOutgoing and fightData.killedNames and fightData.killedNames[data.name]) and true or nil,
                wasDuel = CONFIG._fightWasDuel or nil,
                targetClass = data.targetClass or (fightData.outgoing[id] and fightData.outgoing[id].targetClass) or nil
            })
            savedCount = savedCount + 1
        end
    end

    -- Save heal sessions
    for id, data in pairs(healSessionByTarget) do
        if #data.logs > 0 then
            local isDone = string.sub(id, 1, 5) == "done_"
            local isRecv = string.sub(id, 1, 5) == "recv_"
            table.insert(allSessions, {
                time = timeStr, fightId = CONFIG._fightId, targetName = data.name, logs = data.logs,
                who = (data.name == PLAYER_NAME) and "ally" or CONFIG._classifyUnit(data.name, nil),  -- the healed/healer unit's class
                isHeal = true, isHealDone = isDone, isHealReceived = isRecv,
                totalHeal = data.totalHeal or 0, hps = data.hps or 0, duration = data.duration or 0,
                endedInDeath = CONFIG._diedThisFight, targetClass = data.targetClass
            })
            savedCount = savedCount + 1
        end
    end

    -- Authoritative deaths from the UNIT_DEAD event override the HP heuristics on ally recaps.
    if CONFIG._deadByEvent then
        for nm in pairs(CONFIG._deadByEvent) do
            if recapData[nm] then recapData[nm].died = true; recapData[nm].keep = true end
        end
        CONFIG._deadByEvent = nil
    end

    -- Save unit recap sessions. Floodgates: every unit (ally/enemy/mob) with any logged combat is
    -- kept (rec.keep is set on the first line); the top-bar toggles filter the view. `who` carries
    -- the unit's class (ally/enemy/mob) for the name icon and the WHO filter.
    for allyName, rec in pairs(recapData) do
        if #rec.logs > 0 and rec.keep then
            table.insert(allSessions, {
                time = timeStr, fightId = CONFIG._fightId, targetName = rec.name, logs = rec.logs, isRecap = true,
                who = rec.who,
                endedInDeath = rec.died  -- the unit died -> recap [DIED] tag
            })
            savedCount = savedCount + 1
        end
    end

    -- Session cap kept high for the tester build so testers can accumulate lots of history
    -- (restore to ~300 for a public release).
    if #allSessions > 999999 then
        local trimmed = {}
        local start = #allSessions - 999999 + 1
        for i = start, #allSessions do trimmed[#trimmed + 1] = allSessions[i] end
        allSessions = trimmed
    end

    if savedCount > 0 and sidebarMode ~= "SESSIONS" then sessionScrollOffset = 0 end  -- don't jump the list when you're drilled in
    UpdateSessionList(true)
    currentSessionLogs = {}; sessionByTarget = {}; healSessionByTarget = {}; recapData = {}
    fightData = { outgoing = {}, incoming = {} }; healData = { done = {}, received = {} }; CONFIG._shieldAbsorb = nil; CONFIG._fightWasDuel = nil
    if CONFIG._meterReset then CONFIG._meterReset() end
    activeDots = {}; activeCCSessions = {}
    -- Prune activeDebuffsCache: keep only current target and player, discard old unit entries
    local keepPlayer = api.Unit:GetUnitId("player")
    local keepTarget = api.Unit:GetUnitId("target")
    for uid in pairs(activeDebuffsCache) do
        if uid ~= keepPlayer and uid ~= keepTarget then
            activeDebuffsCache[uid] = nil
        end
    end
end

local function ScanUnitDebuffs(unitTag)
    if not CONFIG.ENABLE_SCANNER then return end
    local unitID = api.Unit:GetUnitId(unitTag)
    if not unitID then return end
    if not activeDebuffsCache[unitID] then activeDebuffsCache[unitID] = {} end
    if not activeCCSessions[unitID] then activeCCSessions[unitID] = {} end
    
    local count = api.Unit:UnitDeBuffCount(unitTag) or 0
    local currentScan = {}
    
    for i = 1, count do
        local debuff = api.Unit:UnitDeBuff(unitTag, i)
        if debuff and debuff.buff_id then
            local dName = "Unknown"
            if buffDB[debuff.buff_id] then dName = buffDB[debuff.buff_id]
            elseif buffNameCache[debuff.buff_id] then dName = buffNameCache[debuff.buff_id]
            else
                local tooltip = api.Ability.GetBuffTooltip(debuff.buff_id, debuff.buff_id)
                if tooltip and tooltip.name then dName = tooltip.name elseif debuff.name then dName = debuff.name end
                buffNameCache[debuff.buff_id] = dName
            end
            
            if dName ~= "Unknown" and not IsIgnoredBuff(dName) then
                currentScan[dName] = true
                if not activeDebuffsCache[unitID][dName] then
                    -- Scanner extends combat if already fighting, but never starts it
                    if inCombat then
                        timeSinceLastAction = 0
                    end

                    local duration = debuff.timeLeft or 0
                    local durStr = "Active"
                    if duration > 0 then durStr = string.format("%.1fs", duration/1000) end
                    local targetName = api.Unit:GetUnitNameById(unitID) or unitTag
                    local isCC = CC_DB[dName]
                    if not isCC then
                        local lower = string.lower(dName)
                        if string.find(lower, "sleep") or string.find(lower, "trip") or string.find(lower, "fear") then isCC = true end
                    end
                    local c = GetSafeColor(isCC and CONFIG.COL_CC or CONFIG.COL_OUT_NRM)
                    if unitTag == "player" then
                        if not activeCCSessions[unitID] or not activeCCSessions[unitID][dName] then
                            LogEntry(string.format("[Debuff] %s: Applied to YOU (%s)", dName, durStr), c[1], c[2], c[3])
                        end
                    else
                        if not activeCCSessions[unitID][dName] then
                            RecordLogForTarget(unitID, targetName, string.format("[Debuff] %s (%s)", dName, durStr), c[1], c[2], c[3])
                            activeCCSessions[unitID][dName] = api.Time:GetUiMsec()
                        end
                    end
                end
            end
        end
    end
    
    for oldBuff, startTime in pairs(activeCCSessions[unitID]) do
        if not currentScan[oldBuff] then
            local totalDur = (api.Time:GetUiMsec() - startTime) / 1000
            local c = GetSafeColor(CONFIG.COL_CC)
            local tName = api.Unit:GetUnitNameById(unitID) or unitTag
            if unitTag ~= "player" then
                RecordLogForTarget(unitID, tName, string.format("[Debuff] %s: Ended (%.1fs)", oldBuff, totalDur), c[1], c[2], c[3])
                local outData = GetOrCreateOutgoing(unitID, tName, api.Time:GetUiMsec())
                if not outData.ccDurations then outData.ccDurations = {} end
                local prev = outData.ccDurations[oldBuff] or 0
                outData.ccDurations[oldBuff] = prev + totalDur
                outData.lastUpdate = api.Time:GetUiMsec()
            end
            activeCCSessions[unitID][oldBuff] = nil
        end
    end
    activeDebuffsCache[unitID] = currentScan
end

-- === ANCESTRAL- (HEIR-) SKILL VARIANT ICONS ===
-- Same-named skills (e.g. all 3 forms of "Meteor Strike") share a combat-log name but have
-- different icons. The game fires HEIR_SKILL_LEARN(skillName, pos) when you switch a variant; we
-- map (skill, pos) -> icon via skill_variants.lua and stamp it (ResolveSkillIcon checks
-- CONFIG._detectedVariant). The event only fires ON a switch, so we PERSIST the chosen pos per
-- skill to heir_variants.txt and reload it at login.

local HEIR_FILE = "CombatLogPro/heir_variants.txt"

-- Apply a (skill, pos) choice: set the variant icon, or clear to base when pos isn't a known
-- variant (you switched back to the base node, or HEIR_SKILL_RESET). `persist` also records the
-- choice and saves the file. Returns the icon (or nil for base).
local function ApplyHeirVariant(skill, pos, persist)
    if not skill or skill == "" then return end
    CONFIG._detectedVariant = CONFIG._detectedVariant or {}
    CONFIG._heirPos = CONFIG._heirPos or {}
    local sig = SKILL_VARIANTS[skill]
    if not sig then return end  -- not a same-named/variant skill -> nothing to do
    pos = tonumber(pos)
    local icon = (pos and sig.byPos) and sig.byPos[pos] or nil  -- nil = base node
    if CONFIG._detectedVariant[skill] ~= icon then
        CONFIG._detectedVariant[skill] = icon       -- nil -> ResolveSkillIcon falls through to base
        iconPathCache[skill] = nil                  -- re-resolve with the new icon
    end
    if persist then
        CONFIG._heirPos[skill] = pos
        pcall(function() api.File:Write(HEIR_FILE, CONFIG._heirPos) end)
    end
    return icon
end

-- Load persisted variant choices at startup (HEIR_SKILL_LEARN doesn't fire on login).
local function LoadHeirVariants()
    CONFIG._heirPos = {}
    local ok, t = pcall(function() return api.File:Read(HEIR_FILE) end)
    if ok and type(t) == "table" then
        for skill, pos in pairs(t) do
            ApplyHeirVariant(skill, pos, false)
            CONFIG._heirPos[skill] = tonumber(pos)
        end
    end
end

-- Incoming variant: a same-named skill cast AT you carries no variant info, but a NON-base variant
-- leaves a uniquely-named debuff on you (readable on the "player" token). Match it to identify the
-- caster's variant; nil (base) if none. Best-effort -- only forms with a distinct debuff. See the
-- `debuffs` maps in skill_variants.lua.
local function IncomingVariantIcon(skill)
    local sig = SKILL_VARIANTS[skill]
    if not sig or not sig.debuffs then return nil end
    local okC, cnt = pcall(function() return api.Unit:UnitDeBuffCount("player") end)
    if not okC or not cnt or cnt == 0 then return nil end
    for i = 1, cnt do
        local d = api.Unit:UnitDeBuff("player", i)
        if d and d.buff_id then
            local nm = buffDB[d.buff_id] or buffNameCache[d.buff_id]
            if not nm then
                local okT, tt = pcall(function() return api.Ability:GetBuffTooltip(d.buff_id) end)
                nm = (okT and type(tt) == "table" and tt.name) or d.name
                if nm then buffNameCache[d.buff_id] = nm end
            end
            if nm and sig.debuffs[nm] then return sig.debuffs[nm] end
        end
    end
    return nil
end

-- Expose on CONFIG so the big event-handler closure + Load can reach these WITHOUT taking new
-- upvalues (it's near Lua's 60-upvalue cap -- all added state goes through CONFIG already).
CONFIG._skillVariants = SKILL_VARIANTS
CONFIG._applyHeir = ApplyHeirVariant
CONFIG._loadHeir = LoadHeirVariants
CONFIG._incomingVariantIcon = IncomingVariantIcon
CONFIG._detectedVariant = CONFIG._detectedVariant or {}  -- skill name -> variant icon (base = nil)

-- === EVENT HANDLER ===
local function OnLiveEvent(self, event, ...)
    local args = { ... }; if #args == 0 and arg then args = arg end

    -- Ancestral-variant icon: the game fires these when you switch/reset a heir (ancestral) skill.
    -- HEIR_SKILL_LEARN(skillName, pos) -> point that skill's icon at the variant; RESET -> base.
    if event == "HEIR_SKILL_LEARN" then
        CONFIG._applyHeir(tostring(args[1] or ""), args[2], true)
        return
    elseif event == "HEIR_SKILL_RESET" then
        CONFIG._applyHeir(tostring(args[1] or ""), nil, true)
        return
    end

    if event == "COMBAT_TEXT" then
        local sourceUnitId = tostring(args[1] or "")
        local targetUnitId = tostring(args[2] or "")
        if targetUnitId == PLAYER_UNIT_ID and sourceUnitId ~= "" then
            lastIncomingSourceId = sourceUnitId
        end
        if CONFIG.RAID_METER then CONFIG._ctPush(sourceUnitId, targetUnitId, tonumber(args[3] or 0)) end
        return
    end

    if event == "UNIT_DEAD" then
        -- AUTHORITATIVE death event (proven via the `numbers` addon). Fires for ANY unit death.
        -- args = (unitId, lostExpStr, durabilityLossRatio). GetUnitInfoById resolves the dead
        -- unit's .name and .type ("character" = a player). This replaces HP-poll guesswork.
        local deadId = tostring(args[1] or "")
        if deadId == "" then return end
        local okI, info = pcall(function() return api.Unit:GetUnitInfoById(deadId) end)
        local dName = (okI and info and info.name) or "?"
        local dType = (okI and info and info.type) or "?"
        -- A just-dead MOB's unit info is often already gone (name "?"). Recover the name from the
        -- outgoing session we already have for that unit id, so mob kills still log + tag [KILL].
        if dName == "?" and fightData.outgoing and fightData.outgoing[deadId] and fightData.outgoing[deadId].name then
            dName = fightData.outgoing[deadId].name
        end
        local isSelf = (deadId == PLAYER_UNIT_ID) or (dName ~= "?" and dName == PLAYER_NAME)
        -- Killer attribution (from the last damage source we recorded for this unit id).
        local killer = CONFIG._lastDmgSrc and CONFIG._lastDmgSrc[deadId]
        local killStr = ""
        if killer and killer ~= "" and killer ~= dName then
            killStr = (killer == PLAYER_NAME) and "  (your kill)" or ("  (killed by " .. killer .. ")")
        end
        if isSelf then
            -- Latch the death log (cleared only when HP recovers, NOT by FinishFight) so it fires
            -- exactly once per actual death -- no re-spam while the corpse lingers in combat.
            if not CONFIG._playerDeadLatch then CONFIG._playerDeadLatch = true; CONFIG._playerDied = true; LogEntry("YOU DIED" .. killStr, 1, 0.2, 0.2, { death = true }) end
        elseif dName ~= "?" then
            CONFIG._deadByEvent = CONFIG._deadByEvent or {}
            CONFIG._deadByEvent[dName] = true  -- consumed by FinishFight -> authoritative ally recap [DIED]
            local youDamaged = fightData.outgoing and fightData.outgoing[deadId] ~= nil
            if youDamaged then fightData.killedNames = fightData.killedNames or {}; fightData.killedNames[dName] = true
                fightData.killedIds = fightData.killedIds or {}; fightData.killedIds[deadId] = true end  -- per-INSTANCE kill
            -- Kill feed: only deaths your SIDE was INVOLVED in -- a unit you damaged (your kill / a
            -- foe you fought), one of your own party/raid (a teammate dropping), OR a unit your
            -- party/raid killed. That last clause covers HEALERS: they deal no damage, so without it
            -- they'd see only teammate deaths and miss every kill their team scored. Random deaths
            -- from other people's fights (sieges, crowded zones) are still skipped -- pure noise.
            -- Deduped by UNIT ID against the combat-state path.
            CONFIG._deathLogged = CONFIG._deathLogged or {}
            local involved = youDamaged or (GetAllyTag(dName) ~= nil)
                             or (killer and GetAllyTag(killer) ~= nil)
            if involved and not CONFIG._deathLogged[deadId] then
                CONFIG._deathLogged[deadId] = true
                LogEntry(dName .. " DIED" .. killStr, 1, 0.5, 0.2, { death = true })
            end
        end
        return
    end


    if event == "COMBAT_MSG" then
        local unitID = tostring(args[1] or "0")
        local actionType = tostring(args[2] or "")
        -- ENVIRONMENTAL_DAMAGE (falling/drowning/zone fields) uses a SHIFTED arg layout:
        -- [3]src [4]tgt [5]cause [7]amount [8]powerType. Remap it into the standard damage
        -- shape so the normal incoming path handles it -- starts a session, logs the hit,
        -- and (combat having started) the HP==0 death poll catches a lethal fall/drown even
        -- out of combat. All environmental damage is logged (no threshold), per design.
        if actionType == "ENVIRONMENTAL_DAMAGE" then
            local envAmt = tonumber(args[7]) or 0
            local cause  = tostring(args[5] or "Environment")
            cause = cause:sub(1, 1):upper() .. cause:sub(2):lower()  -- FALLING -> Falling
            args[6]  = cause              -- skill label = the cause
            args[7]  = "PHYSICAL"         -- damage-type slot (env ignores armor; label only)
            args[8]  = -envAmt            -- standard damage slot (negative = incoming)
            args[10] = tostring(args[9] or "HIT")
            args[11] = envAmt             -- raw pre-mitigation = amount (no mitigation chain)
            -- Leave source/target as-is (you). With the ENVIRONMENTAL_DAMAGE guard on the
            -- outgoing branch below, a self-fall routes to the INCOMING side and groups under
            -- YOUR name, with "Falling" as the skill -- not under a fake "Falling" attacker.
        end
        local sourceName = tostring(args[3] or "Unknown")
        local targetName = tostring(args[4] or "Unknown")
        local skill = tostring(args[6] or "Attack")
        -- Normalize auto-attack skill names before early-exit checks
        if skill == "HEALTH" or skill == "Attack" then
            skill = string.find(actionType, "RANGED") and "Ranged Attack" or "Auto Attack"
        end

        if not skill or skill == "nil" then return end
        if IsIgnoredBuff(skill) then return end

        -- Defer string.upper until after early exits (saves work on filtered events)
        local upAct = string.upper(actionType)
        local missSubType = string.upper(tostring(args[5] or ""))
        local hitType = tostring(args[10] or "HIT")
        local upHit = string.upper(hitType)
        local damage = tonumber(args[8] or 0)
        -- arg[11] = raw pre-mitigation damage (before armor/resist/toughness)
        local rawDamage = tonumber(args[11] or 0)

        -- Heal detection
        local isHeal = false
        if string.find(upHit, "HEAL") or upHit == "HOT" then isHeal = true end
        if string.find(upAct, "HEAL") or upAct == "HOT" then isHeal = true end

        local absDmg = math.abs(damage)
        local now = frameNow  -- cached by OnUpdate, avoids GetUiMsec() per event

        if CONFIG.RAID_METER and inCombat then
            -- Effect-ticks (HoT/DoT) report the EFFECT as the source; attribute them to the real
            -- caster via the paired COMBAT_TEXT (matched by target + amount). Falls back to the
            -- effect name (-> classified "other" -> excluded) when no caster resolves.
            local meterSrc = sourceName
            if sourceName == skill then
                meterSrc = CONFIG._resolveTickCaster(unitID, absDmg) or sourceName
            end
            -- HOTFIX: pcall-guard so a fault in the meter tap can NEVER abort the combat handler
            -- (which would drop ALL damage/heal logging). Captures the first error for diagnosis.
            local mok, merr = pcall(CONFIG._meterTap, meterSrc, absDmg, isHeal)
            if not mok and not CONFIG._meterErr then
                CONFIG._meterErr = true
                pcall(function() api.File:Write("CombatLogPro/meter_err.txt", "meterTap error: " .. tostring(merr)) end)
            end
        end

        -- Killer attribution: remember who last DAMAGED each unit (by its unit id) so a
        -- following UNIT_DEAD can show "X killed by Y". Damage only -- skip heals/self-procs.
        if not isHeal and absDmg > 0 and sourceName ~= "Unknown" and sourceName ~= targetName then
            CONFIG._lastDmgSrc = CONFIG._lastDmgSrc or {}
            CONFIG._lastDmgSrc[unitID] = sourceName
        end

        -- Defensive self-procs (Absorb Damage, damage-converting runes) arrive as self
        -- SPELL_HEALED on every incoming hit. They're mitigation, not healing -- tally them
        -- as "shield absorbed" (surfaced in the incoming recap) and drop the event so it
        -- neither spams the live feed nor inflates heal stats. (Insulating Lens emits no
        -- combat event at all, so it cannot be tracked.)
        if isHeal and sourceName == targetName and
           (string.lower(skill) == "absorb damage" or string.find(string.lower(skill), "rune")) then
            if inCombat then
                CONFIG._shieldAbsorb = CONFIG._shieldAbsorb or {}
                CONFIG._shieldAbsorb[skill] = (CONFIG._shieldAbsorb[skill] or 0) + absDmg
            end
            return
        end

        -- Ally Damage Recap: record any hit/heal landing on a party/raid member.
        -- Runs before the heal/miss/own-vs-other early-returns so it sees ALL events.
        if CONFIG.LOG_ALLY_RECAP
           or (isHeal and sourceName == PLAYER_NAME and CONFIG.SHOW_HEALS) then
            RecordAllyRecap(sourceName, targetName, skill, absDmg, isHeal,
                string.find(upHit, "CRITICAL") ~= nil, unitID)
        end

        -- HEALS: route to separate tracking, never trigger combat
        if isHeal and absDmg > 0 and CONFIG.SHOW_HEALS then
            local c = GetSafeColor(CONFIG.COL_HEAL)
            if sourceName == PLAYER_NAME then
                -- (Overheal capture moved into RecordAllyRecap so it reads HP for ANY
                --  party/raid member via the team tag, not just the selected target.)

                -- HP% suffix = the heal TARGET's resulting HP%. Mirror the damage-line read so heals
                -- get it too: player handle for self-heals (works even while targeting an enemy),
                -- else the target's id (any ally/unit), else the current-target handle as a fallback.
                local hpSuffix = ""
                do
                    local hp, mhp
                    if targetName == PLAYER_NAME then
                        local okH, h = pcall(function() return api.Unit:UnitHealth("player") end)
                        local okM, m = pcall(function() return api.Unit:UnitMaxHealth("player") end)
                        if okH and okM then hp, mhp = h, m end
                    end
                    if not (hp and mhp) and unitID and unitID ~= "" and unitID ~= "0" then
                        local okI, info = pcall(function() return api.Unit:GetUnitInfoById(unitID) end)
                        if okI and type(info) == "table" then
                            hp  = tonumber(info.hp or info.health or info.current_health)
                            mhp = tonumber(info.max_health or info.max_hp or info.maxHealth)
                        end
                    end
                    if not (hp and mhp) then
                        local okN, tn = pcall(function() return api.Unit:UnitName("target") end)
                        if okN and tn == targetName then
                            local okH, h = pcall(function() return api.Unit:UnitHealth("target") end)
                            local okM, m = pcall(function() return api.Unit:UnitMaxHealth("target") end)
                            if okH and okM then hp, mhp = h, m end
                        end
                    end
                    if hp and mhp and mhp > 0 then
                        local pct = math.floor(hp / mhp * 100)
                        if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
                        hpSuffix = string.format(" [%d%%]", pct)
                    end
                end

                -- Heal crit detection (parseResult isn't computed yet in the heal path):
                -- check the hit-type slot plus args 9-12 for "CRITICAL".
                local healCrit = string.find(upHit, "CRITICAL") ~= nil
                if not healCrit then
                    for ci = 9, 12 do
                        if string.find(string.upper(tostring(args[ci] or "")), "CRITICAL") then healCrit = true; break end
                    end
                end

                if inCombat then
                    if not healData.done[targetName] then
                        local okP, pInfo = pcall(function() return api.Unit:UnitInfo("player") end)
                        if not okP then pInfo = {} end
                        healData.done[targetName] = {
                            skills = {}, startTime = now, lastUpdate = now,
                            critHealBonus = 0, zealHealBonus = 0, healCrits = 0,
                            -- Capture class only when the heal target IS your current target
                            -- (cheap, no extra lookups); lets healed ally players show a role icon.
                            targetClass = (function()
                                local okN, tn = pcall(function() return api.Unit:UnitName("target") end)
                                if not (okN and tn == targetName) then return nil end
                                local okC, c = pcall(function() return api.Ability:GetUnitClassName("target") end)
                                if okC and c and c ~= "" and tostring(c):lower() ~= "pending" then return tostring(c) end
                                return nil
                            end)(),
                            healSnap = {
                                healMul       = tonumber(pInfo.heal_mul            or 0),
                                healCritRate  = tonumber(pInfo.heal_critical_rate  or 0),
                                healCritBonus = tonumber(pInfo.heal_critical_bonus or 50),
                                castingTime   = tonumber(pInfo.casting_time        or 100),
                            },
                        }
                    end
                    local hd = healData.done[targetName]
                    local critB = (hd.healSnap and hd.healSnap.healCritBonus) or 50

                    -- Attribute crit (and Zeal's +75% crit healing), mirroring the damage crit math.
                    local critBonus, zealHealBonus = 0, 0
                    if healCrit then
                        if zealActive then
                            local denom     = 100 + critB + 75
                            local critTotal = math.floor(absDmg * (critB + 75) / denom)
                            critBonus     = math.floor(critTotal * critB / (critB + 75))
                            zealHealBonus = critTotal - critBonus
                        else
                            critBonus = math.floor(absDmg * critB / (100 + critB))
                        end
                        hd.healCrits = (hd.healCrits or 0) + 1
                    end

                    -- Heal-power buffs: flat heal_dps gain over the idle baseline (Rhythm/Ode),
                    -- plus heal_mul %. Computed off the pre-crit portion to avoid overlap.
                    local preCrit = math.max(0, absDmg - critBonus - zealHealBonus)
                    local healPowerBonus, healMulBonus = 0, 0
                    local hDps  = bonuses.healDps or 0
                    local hBase = bonuses.baseHealDps or hDps
                    if hDps > 0 and hDps > hBase then
                        healPowerBonus = math.floor(preCrit * (hDps - hBase) / hDps)
                    end
                    local hMul = bonuses.healMul or 0
                    if hMul > 0 then
                        healMulBonus = math.floor((preCrit - healPowerBonus) * hMul / (100 + hMul))
                    end

                    local baseHeal = math.max(0, absDmg - critBonus - zealHealBonus - healPowerBonus - healMulBonus)

                    hd.skills[skill]  = (hd.skills[skill] or 0) + absDmg
                    hd.critHealBonus  = (hd.critHealBonus or 0) + critBonus
                    hd.zealHealBonus  = (hd.zealHealBonus or 0) + zealHealBonus
                    hd.healPowerBonus = (hd.healPowerBonus or 0) + healPowerBonus
                    hd.healMulBonus   = (hd.healMulBonus or 0) + healMulBonus
                    hd.lastUpdate     = now

                    local critTag = healCrit and " (Crit)" or ""
                    RecordHealLog("done_" .. targetName, targetName,
                        string.format("+ %s -> %s: %d%s%s", skill, targetName, absDmg, critTag, hpSuffix),
                        c[1], c[2], c[3],
                        { logType = "heal", skill = skill, source = sourceName, target = targetName, damage = absDmg, dmgTag = "Heal" })

                    if critBonus > 0 or zealHealBonus > 0 or healPowerBonus > 0 or healMulBonus > 0 then
                        local parts = { string.format("Base %d", baseHeal) }
                        if critBonus      > 0 then parts[#parts+1] = string.format("Crit +%d", critBonus) end
                        if zealHealBonus  > 0 then parts[#parts+1] = string.format("Zeal +%d", zealHealBonus) end
                        if healPowerBonus > 0 then parts[#parts+1] = string.format("HealPwr +%d", healPowerBonus) end
                        if healMulBonus   > 0 then parts[#parts+1] = string.format("Heal%% +%d", healMulBonus) end
                        RecordHealLog("done_" .. targetName, targetName,
                            "  " .. table.concat(parts, " | "), 0.6, 0.85, 0.6,
                            { logType = "heal", detailOnly = true })
                    end

                    -- Overheal line -- only when this heal spilled over the target's max HP.
                    local oh = CONFIG._healOverheal
                    if oh and oh.name == targetName and oh.over and oh.over > 0 then
                        hd.overhealTotal = (hd.overhealTotal or 0) + oh.over
                        local eff = math.max(0, absDmg - oh.over)
                        local ohPctLine = absDmg > 0 and math.floor(oh.over / absDmg * 100) or 0
                        RecordHealLog("done_" .. targetName, targetName,
                            string.format("  Effective %d | Overheal %d (%d%%)", eff, oh.over, ohPctLine),
                            0.55, 0.75, 0.95, { logType = "heal", detailOnly = true })
                    end
                else
                    RecordHealLog("done_" .. targetName, targetName,
                        string.format("+ %s -> %s: %d%s", skill, targetName, absDmg, hpSuffix),
                        c[1], c[2], c[3],
                        { logType = "heal", skill = skill, source = sourceName, target = targetName, damage = absDmg, dmgTag = "Heal" })
                end
            elseif targetName == PLAYER_NAME then
                local hText = string.format("+ %s from %s: %d", skill, sourceName, absDmg)
                do  -- append your HP% on heals you receive
                    local okH, h = pcall(function() return api.Unit:UnitHealth("player") end)
                    local okM, m = pcall(function() return api.Unit:UnitMaxHealth("player") end)
                    if okH and okM and h and m and m > 0 then hText = hText .. string.format(" [%d%%]", math.floor(h / m * 100)) end
                end
                RecordHealLog("recv_" .. sourceName, sourceName, hText, c[1], c[2], c[3],
                    { logType = "heal", skill = skill, source = sourceName, target = targetName, damage = absDmg, dmgTag = "Heal" })
                if inCombat then
                    if not healData.received[sourceName] then healData.received[sourceName] = { skills = {}, startTime = now, lastUpdate = now } end
                    healData.received[sourceName].skills[skill] = (healData.received[sourceName].skills[skill] or 0) + absDmg
                    healData.received[sourceName].lastUpdate = now
                end
            end
            return
        end

        -- Defend / Miss detection (outgoing hits negated by target)
        -- args[5] sub-type distinguishes DODGE/BLOCK/MISS/PARRY within MELEE_MISSED events
        local isDefend = (missSubType == "BLOCK" or missSubType == "PARRY"
                       or string.find(upHit, "DEFEND") ~= nil or string.find(upAct, "DEFEND") ~= nil
                       or string.find(upHit, "PARRI")  ~= nil or string.find(upAct, "PARRI")  ~= nil)
        local isMiss   = (missSubType == "MISS" or missSubType == "DODGE" or missSubType == "EVADE"
                       or (missSubType == "" and (
                           string.find(upHit, "MISS")  ~= nil or string.find(upAct, "MISS")  ~= nil
                        or string.find(upHit, "EVADE") ~= nil or string.find(upAct, "EVADE") ~= nil
                        or string.find(upHit, "DODGE") ~= nil or string.find(upAct, "DODGE") ~= nil)))
        local isImmune = (missSubType == "IMMUNE"
                       or string.find(upHit, "IMMUN") ~= nil or string.find(upAct, "IMMUN") ~= nil
                       or string.find(upHit, "INVINCIB") ~= nil or string.find(upAct, "INVINCIB") ~= nil)

        if (isDefend or isMiss or isImmune) and sourceName == PLAYER_NAME and targetName ~= PLAYER_NAME and targetName ~= "Unknown" and unitID ~= "0" then
            timeSinceLastAction = 0
            if not inCombat then
                inCombat = true
                lastTargetBuffCount = -1  -- force buff effects re-scan on combat start
                SetCombatStatus(true)
            end
            local outData = GetOrCreateOutgoing(unitID, targetName, now)
            outData.lastUpdate = now
            local label, verb
            if     isImmune               then label = "!Immune!"   verb = "immune"
            elseif missSubType == "BLOCK"  then label = "!Blocked"  verb = "blocked"
            elseif missSubType == "PARRY"  then label = "!Parried"  verb = "parried"
            elseif missSubType == "DODGE"  then label = "!Evaded"   verb = "evaded"
            elseif missSubType == "EVADE"  then label = "!Evaded"   verb = "evaded"
            elseif isDefend               then label = "!Defended"  verb = "blocked"
            else                               label = "!Missed"    verb = "missed"
            end
            local sc = GetSafeColor(CONFIG.COL_SKILL_LABEL)
            local missColor = isImmune and { 1, 0.4, 0.1 } or { 0.55, 0.55, 0.55 }
            RecordLogForTarget(unitID, targetName,
                string.format("%s: %s", skill, targetName),
                sc[1], sc[2], sc[3],
                { logType = "miss", skill = skill, source = sourceName, target = targetName, missType = label })
            RecordLogForTarget(unitID, targetName, label, missColor[1], missColor[2], missColor[3], nil)
            if isImmune then
                outData.invincibleSkills[skill] = (outData.invincibleSkills[skill] or 0) + 1
            elseif isDefend then
                outData.defends[skill] = (outData.defends[skill] or 0) + 1
            else
                outData.misses[skill] = (outData.misses[skill] or 0) + 1
            end
            return
        end

        -- Parse absorb data (only for non-heal combat events)
        local absorbed = 0
        local parseOk, parseResult = false, nil
        if _parseAvailable then
            -- pcall-guarded: the game's parser throws on actionTypes it doesn't know
            -- (e.g. ENVIRONMENTAL_DAMAGE). An unguarded throw aborts the whole handler
            -- before the hit is even recorded -- which is why fall damage logged nothing.
            parseOk, parseResult = pcall(_parseCombatMessage, actionType, unpack(args, 5))
            if not parseOk then parseResult = nil end
        end
        if parseOk and parseResult then
            if parseResult.reduced then
                absorbed = math.abs(tonumber(parseResult.reduced) or 0)
            end
            -- MELEE_DAMAGE (auto attacks): args[8] is unreliable — sometimes 0, sometimes the
            -- absorbed amount. Always prefer parseResult.damage for auto attacks when available.
            if parseResult.damage and (absDmg == 0 or skill == "Auto Attack") then
                absDmg = math.abs(tonumber(parseResult.damage) or 0)
            end
            -- hitType for auto attacks is in parseResult, not args[10]
            if parseResult.hitType and tonumber(args[10]) ~= nil then
                upHit = string.upper(tostring(parseResult.hitType))
            end
        end

        -- COMBAT: damage or CC from COMBAT_MSG also triggers combat (backup for game event)
        -- Player-initiated 0-damage actions are handled by UNIT_COMBAT_STATE_CHANGED
        local isCC = CC_DB[skill] ~= nil
        local isPlayerAction = (sourceName == PLAYER_NAME and targetName ~= PLAYER_NAME and targetName ~= "Unknown")
        local isCombatTrigger = (absDmg > 0) or isCC or isPlayerAction
        if not isCombatTrigger then return end
        if sourceName ~= PLAYER_NAME and targetName ~= PLAYER_NAME then return end
        -- Falling/drowning shouldn't START a fight (otherwise it spams a 1s "fight" every time you
        -- take fall damage out of combat). Only log it while ALREADY in combat -- a lethal
        -- out-of-combat fall is still caught by the UNIT_DEAD death event.
        if actionType == "ENVIRONMENTAL_DAMAGE" and not inCombat then return end

        timeSinceLastAction = 0
        if not inCombat then
            inCombat = true
            SetCombatStatus(true)
        end

        if sourceName == PLAYER_NAME and actionType ~= "ENVIRONMENTAL_DAMAGE" then
            local outData = GetOrCreateOutgoing(unitID, targetName, now)
            outData.lastUpdate = now

            -- Infer damage type from mitigation ratio (physical vs magic)
            local dmgTag = InferDamageType(upAct, skill, absDmg, absorbed, outData.statSnapshot)
            local isMagicHit = (dmgTag == "Magic" or dmgTag == "Spell")
            local isRangedTag = (dmgTag == "Ranged")
            local dmgLabel = TYPE_SHORT[dmgTag] or dmgTag

            if absDmg > 0 then
                outData.skills[skill] = (outData.skills[skill] or 0) + absDmg
                outData.hitCounts[skill] = (outData.hitCounts[skill] or 0) + 1
                outData.skillTypes[skill] = dmgTag
                outData.totalAbsorbed = (outData.totalAbsorbed or 0) + absorbed
                -- Track physical/ranged/magic split for mitigation estimates
                if isMagicHit then
                    outData.magicDmg      = (outData.magicDmg      or 0) + absDmg
                    outData.magicAbsorbed = (outData.magicAbsorbed  or 0) + absorbed
                    outData.magicHits     = (outData.magicHits      or 0) + 1
                    if rawDamage > 0 then
                        outData.rawMagicDmg = (outData.rawMagicDmg or 0) + rawDamage
                    end
                elseif isRangedTag then
                    outData.rangedDmg     = (outData.rangedDmg      or 0) + absDmg
                    outData.rangedAbsorbed= (outData.rangedAbsorbed or 0) + absorbed
                    outData.rangedHits    = (outData.rangedHits     or 0) + 1
                    if rawDamage > 0 then
                        outData.rawRangedDmg = (outData.rawRangedDmg or 0) + rawDamage
                    end
                else
                    outData.physDmg       = (outData.physDmg        or 0) + absDmg
                    outData.physAbsorbed  = (outData.physAbsorbed   or 0) + absorbed
                    outData.physHits      = (outData.physHits        or 0) + 1
                    if rawDamage > 0 then
                        outData.rawPhysDmg = (outData.rawPhysDmg or 0) + rawDamage
                    end
                end

                -- Spell Shield: magic damage heals target
                if isMagicHit and targetBuffEffects.spellShieldPct > 0 then
                    local rawMagicHit = absDmg + absorbed
                    local healed = math.floor(rawMagicHit * targetBuffEffects.spellShieldPct / 100)
                    outData.spellShieldDmg = (outData.spellShieldDmg or 0) + rawMagicHit
                    outData.spellShieldHealed = (outData.spellShieldHealed or 0) + healed
                end

                -- Rune conversion: % of all damage heals target
                if targetBuffEffects.runeConvertPct > 0 then
                    local rawHit = absDmg + absorbed
                    local runeHealed = math.floor(rawHit * targetBuffEffects.runeConvertPct / 100)
                    outData.runeConvertDmg = (outData.runeConvertDmg or 0) + runeHealed
                    outData.runeConvertPct = targetBuffEffects.runeConvertPct
                    outData.runeConvertName = targetBuffEffects.runeConvertName
                end

                -- Damage shield: track damage dealt while any absorb shield is up
                if targetBuffEffects.dmgShield then
                    local rawHit = absDmg + absorbed
                    local shName = targetBuffEffects.dmgShieldName or "Damage Shield"
                    if not outData.dmgShields[shName] then
                        outData.dmgShields[shName] = { max = targetBuffEffects.dmgShieldMax, rawDmg = 0 }
                    end
                    outData.dmgShields[shName].rawDmg = outData.dmgShields[shName].rawDmg + rawHit
                    if targetBuffEffects.dmgShieldMax > outData.dmgShields[shName].max then
                        outData.dmgShields[shName].max = targetBuffEffects.dmgShieldMax
                    end
                end

            end

            if isCC then
                local c = GetSafeColor(CONFIG.COL_CC)
                -- A CC skill that ALSO deals damage (e.g. Dissonance) should still show its hit
                -- number on the live line -- not just "Hit" (the damage was tallied for the summary
                -- above either way). Pure-CC skills (no damage) keep the plain "(CC): Hit".
                local ccTxt
                if absDmg > 0 then
                    local critTag = (string.find(upHit, "CRITICAL") ~= nil) and " Crit" or ""
                    ccTxt = absorbed > 0
                        and string.format("%s (CC): %d [%s]%s (%d absorbed)", skill, absDmg, dmgLabel, critTag, absorbed)
                        or  string.format("%s (CC): %d [%s]%s", skill, absDmg, dmgLabel, critTag)
                else
                    ccTxt = string.format("%s (CC): Hit", skill)
                end
                RecordLogForTarget(unitID, targetName, ccTxt, c[1], c[2], c[3],
                    { logType = "cc", skill = skill, source = sourceName, target = targetName })
            elseif dotSkills[skill] then
                local key = unitID .. "_" .. skill
                if not activeDots[key] then
                    activeDots[key] = { target = targetName, skill = skill, dmg = 0, hits = 0, start = now, timer = 0 }
                else
                    activeDots[key].start = now
                    activeDots[key].timer = 0
                end
                activeDots[key].dmg = activeDots[key].dmg + absDmg
                activeDots[key].hits = activeDots[key].hits + 1
                local c = GetSafeColor(CONFIG.COL_OUT_NRM)
                outData.skillTypes[skill] = dmgTag
                local sc = GetSafeColor(CONFIG.COL_SKILL_LABEL)
                RecordLogForTarget(unitID, targetName,
                    string.format("%s (DoT): %s", skill, targetName),
                    sc[1], sc[2], sc[3],
                    { logType = "dot", skill = skill, source = sourceName, target = targetName, damage = absDmg, absorbed = absorbed })
                RecordLogForTarget(unitID, targetName,
                    absorbed > 0
                        and string.format("[%s] %d (%d absorbed)", dmgLabel, absDmg, absorbed)
                        or  string.format("[%s] %d", dmgLabel, absDmg),
                    c[1], c[2], c[3], nil)
            elseif absDmg > 0 then
                local isCrit     = string.find(upHit, "CRITICAL")  ~= nil
                local isBackstab = string.find(upHit, "BACKSTAB")  ~= nil
                                or string.find(upAct, "BACKSTAB")  ~= nil
                local bsSkillInfo = isBackstab and SKILL_BACKSTAB_BONUSES[skill] or nil
                if isBackstab then
                    outData.backstabHits = (outData.backstabHits or 0) + 1
                    outData.backstabDmg  = (outData.backstabDmg  or 0) + absDmg
                    if bsSkillInfo then
                        outData.backstabSkillHits = outData.backstabSkillHits or {}
                        outData.backstabSkillHits[skill] = (outData.backstabSkillHits[skill] or 0) + 1
                    end
                end
                local c
                if zealActive and isCrit then
                    c = GetSafeColor(CONFIG.COL_ZEAL_CRIT)
                else
                    c = isCrit and GetSafeColor(CONFIG.COL_OUT_CRIT) or GetSafeColor(CONFIG.COL_OUT_NRM)
                end
                local hitDisplay = isCrit and "Critical" or "HIT"
                -- Line 1: skill + target (backstab annotation here)
                local bsTag = isBackstab and (bsSkillInfo and " [BS+]" or " [BS]") or ""
                local skillLine = string.format("%s: %s%s", skill, targetName, bsTag)
                -- Compute per-hit bonuses (accumulated into outData, logged as separate colored lines)
                local zealBonus, chantyBonus, critExtra, rhythmBonus = 0, 0, 0, 0
                local mcBonus, deliriumBonus, bbBonus, opBonus, assassinBonus, inspiredBonus = 0, 0, 0, 0, 0, 0
                -- Rhythm: additive to spell_dps, computed from current stacks and spell_dps stat
                if rhythmStacks > 0 and isMagicHit and currentSpellDps > 0 then
                    local rhythmDpsBonus = rhythmStacks * RHYTHM_DPS_PER_STACK
                    rhythmBonus = math.floor(absDmg * rhythmDpsBonus / currentSpellDps)
                    outData.rhythmBonusDmg = (outData.rhythmBonusDmg or 0) + rhythmBonus
                end
                -- Magic Circle: spell_dps boost isolated from Rhythm via baseline delta
                if bonuses.magicCircleActive and bonuses.magicCircleDpsBonus > 0 and isMagicHit and currentSpellDps > 0 then
                    mcBonus = math.floor(absDmg * bonuses.magicCircleDpsBonus / currentSpellDps)
                    outData.magicCircleBonusDmg = (outData.magicCircleBonusDmg or 0) + mcBonus
                end
                -- Delirium: +2%/stack for melee and ranged hits
                if bonuses.deliriumStacks > 0 and not isMagicHit then
                    local pct = bonuses.deliriumStacks * 2
                    deliriumBonus = math.floor(absDmg * pct / (100 + pct))
                    outData.deliriumBonusDmg = (outData.deliriumBonusDmg or 0) + deliriumBonus
                end
                -- Burning Brand: +2%/stack for magic hits
                if bonuses.burningBrandStacks > 0 and isMagicHit then
                    local pct = bonuses.burningBrandStacks * 2
                    bbBonus = math.floor(absDmg * pct / (100 + pct))
                    outData.burningBrandBonusDmg = (outData.burningBrandBonusDmg or 0) + bbBonus
                end
                -- Overpowered Spell Locus: fixed +15% all skill damage
                if bonuses.overpoweredActive then
                    opBonus = math.floor(absDmg * 15 / 115)
                    outData.overpoweredBonusDmg = (outData.overpoweredBonusDmg or 0) + opBonus
                end
                -- Assassination: fixed +12% all skill damage
                if bonuses.assassinationActive then
                    assassinBonus = math.floor(absDmg * 12 / 112)
                    outData.assassinationBonusDmg = (outData.assassinationBonusDmg or 0) + assassinBonus
                end
                -- Inspired: +52%/stack bonus to Vicious Implosion only
                if bonuses.inspiredStacks > 0 and skill == "Vicious Implosion" then
                    local pct = bonuses.inspiredStacks * 52
                    inspiredBonus = math.floor(absDmg * pct / (100 + pct))
                    outData.inspiredBonusDmg = (outData.inspiredBonusDmg or 0) + inspiredBonus
                end
                -- Battle Focus / Intensified Harm: boost crit stat (already in critExtra via snapshot)
                -- Track as flags so summary can note they were active during this fight.
                if bonuses.battleFocusActive    then outData.battleFocusWasActive    = true end
                if bonuses.intensifiedHarmActive then outData.intensifiedHarmWasActive = true end
                -- Chanty is computed first — it's the outermost multiplier and is independent of crit.
                -- Crit must then be computed from the pre-chanty damage to avoid double-counting.
                if chantyActive and chantySpellBonus > 0 and isMagicHit then
                    chantyBonus = math.floor(absDmg * chantySpellBonus / (100 + chantySpellBonus))
                    outData.chantyBonusDmg = (outData.chantyBonusDmg or 0) + chantyBonus
                end
                if isCrit then
                    local snap = outData.statSnapshot
                    local critBonusPct = isMagicHit
                        and (snap and snap.playerSpellCritBonus or 50)
                        or  (snap and snap.playerMeleeCritBonus or 50)
                    -- Remove chanty multiplier before computing crit attribution
                    local preChanty = chantyBonus > 0
                        and (absDmg - chantyBonus)
                        or  absDmg
                    if zealActive then
                        -- Zeal adds 75% to crit bonus; both share one combined denominator
                        local denom = 100 + critBonusPct + 75
                        local critTotal = math.floor(preChanty * (critBonusPct + 75) / denom)
                        critExtra = math.floor(critTotal * critBonusPct / (critBonusPct + 75))
                        zealBonus  = critTotal - critExtra  -- remainder avoids rounding drift
                        outData.zealExtraDmg = (outData.zealExtraDmg or 0) + zealBonus
                    else
                        critExtra = math.floor(preChanty * critBonusPct / (100 + critBonusPct))
                    end
                    outData.critBonusDmg = (outData.critBonusDmg or 0) + critExtra
                end
                if zealActive then
                    outData.zealHits = (outData.zealHits or 0) + 1
                end
                -- Base damage = total minus all tracked bonuses (clamped to 0)
                local baseDmg = math.max(0, absDmg - critExtra - zealBonus - chantyBonus - rhythmBonus
                    - mcBonus - deliriumBonus - bbBonus - opBonus - assassinBonus - inspiredBonus)
                local dmgLine = absorbed > 0
                    and string.format("[%s] %d (%s|%d absorbed)", dmgLabel, absDmg, hitDisplay, absorbed)
                    or  string.format("[%s] %d (%s)", dmgLabel, absDmg, hitDisplay)
                -- Append target HP% when the hit lands on the currently selected target
                do
                    local okN, tn = pcall(function() return api.Unit:UnitName("target") end)
                    if okN and tn == targetName then
                        local okH, h = pcall(function() return api.Unit:UnitHealth("target") end)
                        local okM, m = pcall(function() return api.Unit:UnitMaxHealth("target") end)
                        if okH and okM and h and m and m > 0 then
                            dmgLine = dmgLine .. string.format(" [%d%%]", math.floor(h / m * 100))
                        end
                    end
                end
                -- Combo detection: build labels, log separately after damage line
                local isSynergy = parseOk and parseResult and parseResult.synergy == true
                local comboLabels = {}
                local totalBonus = 0
                if isSynergy then
                    local comboConds = SKILL_COMBOS[skill]
                    if comboConds then
                        for _, entry in ipairs(comboConds) do
                            local cond     = entry.cond
                            local pct      = entry.pct
                            local effect   = entry.effect
                            local selfbuff = entry.selfbuff
                            local matched = false
                            local matchName = nil
                            if cond then
                                local dotKey = unitID .. "_" .. cond
                                if activeDots[dotKey] ~= nil
                                or (activeDebuffsCache[unitID] and activeDebuffsCache[unitID][cond]) then
                                    matched = true; matchName = cond
                                end
                            elseif selfbuff then
                                matched = true; matchName = selfbuff
                            end
                            if matched then
                                local effectivePct = pct
                                if selfbuff and pct then
                                    local stacks = GetPlayerBuffStacks(selfbuff)
                                    if stacks > 1 then effectivePct = pct * stacks end
                                end
                                local label
                                if effectivePct then
                                    local pct = effectivePct
                                    local bonus = math.floor(absDmg * pct / (100 + pct))
                                    totalBonus = totalBonus + bonus
                                    label = effect
                                        and string.format("%s +%d%% (+%d) | %s", matchName, pct, bonus, effect)
                                        or  string.format("%s +%d%% (+%d)", matchName, pct, bonus)
                                    -- key by skill+condition so different combo triggers stay separate
                                    local csKey = skill .. "|" .. matchName
                                    local sk = outData.comboSkills[csKey]
                                    if not sk then
                                        outData.comboSkills[csKey] = { skillName=skill, cond=matchName, pct=pct, hits=1, bonusDmg=bonus }
                                    else
                                        sk.hits = sk.hits + 1
                                        sk.bonusDmg = sk.bonusDmg + bonus
                                        sk.pct = pct  -- update to latest (stack count can vary)
                                    end
                                elseif effect then
                                    label = matchName .. " | " .. effect
                                    local csKey = skill .. "|" .. matchName
                                    local sk = outData.comboSkills[csKey]
                                    if not sk then
                                        outData.comboSkills[csKey] = { skillName=skill, cond=matchName, pct=nil, hits=1, bonusDmg=0 }
                                    else
                                        sk.hits = sk.hits + 1
                                    end
                                else
                                    label = matchName
                                    local csKey = skill .. "|" .. matchName
                                    local sk = outData.comboSkills[csKey]
                                    if not sk then
                                        outData.comboSkills[csKey] = { skillName=skill, cond=matchName, pct=nil, hits=1, bonusDmg=0 }
                                    else
                                        sk.hits = sk.hits + 1
                                    end
                                end
                                table.insert(comboLabels, label)
                            end
                        end
                    end
                    if #comboLabels > 0 then
                        outData.comboHits = (outData.comboHits or 0) + 1
                        outData.comboBonusDmg = (outData.comboBonusDmg or 0) + totalBonus
                    end
                end
                local sc = GetSafeColor(CONFIG.COL_SKILL_LABEL)
                local cc = { 0.75, 0.5, 1 }  -- soft purple for combo lines
                RecordLogForTarget(unitID, targetName, skillLine, sc[1], sc[2], sc[3],
                    { logType = "outgoing", skill = skill, source = sourceName, target = targetName, damage = absDmg, absorbed = absorbed, hitType = hitType, dmgTag = dmgTag })
                RecordLogForTarget(unitID, targetName, dmgLine, c[1], c[2], c[3], { archiveHide = true })
                if critExtra > 0 or zealBonus > 0 or chantyBonus > 0 or rhythmBonus > 0
                or mcBonus > 0 or deliriumBonus > 0 or bbBonus > 0 or opBonus > 0
                or assassinBonus > 0 or inspiredBonus > 0 then
                    local parts = { string.format("Base %d", baseDmg) }
                    if critExtra    > 0 then parts[#parts+1] = string.format("Crit +%d",    critExtra)    end
                    if zealBonus    > 0 then parts[#parts+1] = string.format("Zeal +%d",    zealBonus)    end
                    if chantyBonus  > 0 then parts[#parts+1] = string.format("Chanty +%d",  chantyBonus)  end
                    if rhythmBonus  > 0 then parts[#parts+1] = string.format("Rhythm +%d",  rhythmBonus)  end
                    if mcBonus      > 0 then parts[#parts+1] = string.format("M.Circle +%d", mcBonus)      end
                    if deliriumBonus> 0 then parts[#parts+1] = string.format("Delirium +%d", deliriumBonus) end
                    if bbBonus      > 0 then parts[#parts+1] = string.format("B.Brand +%d",  bbBonus)      end
                    if opBonus      > 0 then parts[#parts+1] = string.format("Op.Locus +%d", opBonus)      end
                    if assassinBonus> 0 then parts[#parts+1] = string.format("Assassin +%d", assassinBonus) end
                    if inspiredBonus> 0 then parts[#parts+1] = string.format("Inspired +%d", inspiredBonus) end
                    RecordLogForTarget(unitID, targetName, "  " .. table.concat(parts, " | "),
                        0.75, 0.75, 0.75, { detailOnly = true })
                end
                -- Outgoing mitigation breakdown: reverse-compute raw from snap, then split toughness + armor/resist
                do
                    local snap = outData.statSnapshot
                    if snap then
                        local targetToughness = snap.targetToughness or 0
                        local effectiveDef = isMagicHit
                            and math.max(0, (snap.targetResist  or 0) - (snap.playerMagicPen or 0))
                            or  math.max(0, (snap.targetDefense or 0) - (snap.playerPhysPen  or 0))
                        if targetToughness > 0 then
                            local computedRaw = math.floor(
                                absDmg * (targetToughness + 8000) / 8000 * (effectiveDef + 8000) / 8000)
                            local toughReduction = targetToughness > 0
                                and math.floor(computedRaw * targetToughness / (targetToughness + 8000))
                                or  0
                            local postTough    = computedRaw - toughReduction
                            local defReduction = math.max(0, postTough - absDmg)
                            local defLabel     = isMagicHit and "Resist" or "Armor"
                            local mitParts = { string.format("Raw %d", computedRaw) }
                            if toughReduction > 0 then mitParts[#mitParts+1] = string.format("Tough -%d", toughReduction) end
                            if defReduction   > 0 then mitParts[#mitParts+1] = string.format("%s -%d", defLabel, defReduction) end
                            RecordLogForTarget(unitID, targetName,
                                "  " .. table.concat(mitParts, " | "),
                                0.5, 0.5, 0.5, { detailOnly = true })
                        end
                    end
                end
                if isSynergy then
                    if #comboLabels > 0 then
                        local header = #comboLabels == 1 and "Skill Comboed:" or string.format("Skills Comboed x%d:", #comboLabels)
                        RecordLogForTarget(unitID, targetName, header, cc[1], cc[2], cc[3], { logType = "combo", detailOnly = true })
                        for _, lbl in ipairs(comboLabels) do
                            RecordLogForTarget(unitID, targetName, lbl, cc[1], cc[2], cc[3], { detailOnly = true })
                        end
                    else
                        RecordLogForTarget(unitID, targetName, "Skill Comboed", cc[1], cc[2], cc[3], { logType = "combo", detailOnly = true })
                    end
                end
            elseif isPlayerAction then
                if targetBuffEffects.invincible then
                    -- Skill eaten by invincibility (detected via buff scanner)
                    outData.invincibleSkills[skill] = (outData.invincibleSkills[skill] or 0) + 1
                    local sc = GetSafeColor(CONFIG.COL_SKILL_LABEL)
                    RecordLogForTarget(unitID, targetName,
                        string.format("%s: %s", skill, targetName),
                        sc[1], sc[2], sc[3],
                        { logType = "invincible", skill = skill, source = sourceName, target = targetName })
                    RecordLogForTarget(unitID, targetName, "!Immune!", 1, 0.4, 0.1, nil)
                else
                    -- 0-damage player action (Fear, Sleep, debuff opener, etc.)
                    outData.appliedDebuffs[skill] = true
                    local c = GetSafeColor("Cyan")
                    RecordLogForTarget(unitID, targetName, string.format("%s -> %s", skill, targetName), c[1], c[2], c[3],
                        { logType = "cc", skill = skill, source = sourceName, target = targetName })
                    -- Debug: dump target buff names so we can identify unknown invincibility buffs
                    if CONFIG.DEBUG_ZERO_HITS then
                        local n = api.Unit:UnitBuffCount("target") or 0
                        local parts = {}
                        for i = 1, n do
                            local b = api.Unit:UnitBuff("target", i)
                            if b and b.buff_id then
                                local bname = buffNameCache[b.buff_id] or ("id:" .. b.buff_id)
                                table.insert(parts, bname)
                            end
                        end
                        local buffStr = #parts > 0 and table.concat(parts, ", ") or "none"
                        api.Log:Info(string.format("[DEBUG_ZERO_HITS] %s hit %s for 0 | target buffs: %s", skill, targetName, buffStr))
                    end
                end
            end

        elseif targetName == PLAYER_NAME then
            -- Use sourceUnitId from COMBAT_TEXT (fires just before COMBAT_MSG) to
            -- distinguish same-named mobs in PvE. Falls back to name-only for PvP.
            local sourceUnitId = lastIncomingSourceId
            lastIncomingSourceId = nil
            -- Stable per-name key for the whole fight. COMBAT_TEXT (which carries the
            -- unit id) doesn't fire on every hit, so without caching, a single mob whose
            -- id is seen on only some hits splits into two sessions ("Mob|id" + "Mob").
            if not fightData.incomingKeys then fightData.incomingKeys = {} end
            local incomingKey = fightData.incomingKeys[sourceName]
            if not incomingKey then
                incomingKey = sourceUnitId and (sourceName .. "|" .. sourceUnitId) or sourceName
                fightData.incomingKeys[sourceName] = incomingKey
            end
            -- Check source's toughness to determine if this is a PvP hit (toughness only applies in PvP)
            local incSourceToughness = 0
            if sourceUnitId then
                local okSrc, srcInfo = pcall(function() return api.Unit:UnitInfo(sourceUnitId) end)
                if okSrc and srcInfo then
                    incSourceToughness = tonumber(srcInfo.battle_resist or 0)
                end
            end

            if not fightData.incoming[incomingKey] then
                local okP, pInfo = pcall(function() return api.Unit:UnitInfo("player") end)
                if not okP then pInfo = {} end
                fightData.incoming[incomingKey] = {
                    displayName = sourceName,
                    skills = {}, startTime = now, lastUpdate = now,
                    physDmg = 0, magicDmg = 0, rangedDmg = 0,
                    physAbsorbed = 0, magicAbsorbed = 0, rangedAbsorbed = 0,
                    physHits = 0, magicHits = 0, rangedHits = 0,
                    defSnap = {
                        armor            = tonumber(pInfo.armor                      or 0),
                        armorPct         = tonumber(pInfo.armor_percentage           or 0),
                        resist           = tonumber(pInfo.magic_resist               or 0),
                        resistPct        = tonumber(pInfo.magic_resist_percentage    or 0),
                        dodge            = tonumber(pInfo.dodge_rate                 or 0),
                        block            = tonumber(pInfo.block_rate                 or 0),
                        parry            = tonumber(pInfo.melee_parry_rate           or 0),
                        toughness        = tonumber(pInfo.battle_resist              or 0),
                        incomingMeleeMul = tonumber(pInfo.incoming_melee_damage_mul  or 0),
                        incomingSpellMul = tonumber(pInfo.incoming_spell_damage_mul  or 0),
                        incomingRangedMul= tonumber(pInfo.incoming_ranged_damage_mul or 0),
                        incomingMeleeVal = tonumber(pInfo.incoming_melee_damage_val  or 0),
                        incomingSpellVal = tonumber(pInfo.incoming_spell_damage_val  or 0),
                        incomingRangedVal= tonumber(pInfo.incoming_ranged_damage_val or 0),
                    },
                }
            else
                fightData.incoming[incomingKey].lastUpdate = now
            end
            -- Sticky PvP flag: only players have toughness, so a source with battle_resist
            -- means this was a PvP hit. Used to gate the toughness summary line (PvE = hide).
            if incSourceToughness > 0 then fightData.incoming[incomingKey].isPvP = true end
            if absDmg > 0 then
                -- Infer damage type for incoming hits using our own defense stats
                local incSnap = fightData.incoming[incomingKey].defSnap
                local incInferSnap = incSnap and {
                    targetArmorPct = incSnap.armorPct or 0,
                    targetResistPct = incSnap.resistPct or 0,
                    targetDefense = incSnap.armor or 0,
                    targetResist = incSnap.resist or 0,
                    playerPhysPen = 0, playerMagicPen = 0,
                } or nil
                local incTag = InferDamageType(upAct, skill, absDmg, absorbed, incInferSnap)
                local incLabel = TYPE_SHORT[incTag] or incTag
                local incIsMagic = (incTag == "Magic" or incTag == "Spell")
                local incIsRanged = (incTag == "Ranged")

                -- Log first occurrence of each incoming skill to file
                if CONFIG.LOG_UNKNOWN_INCOMING then
                    if not incomingSkillLoaded then
                        incomingSkillLoaded = true
                        local ok, existing = pcall(function() return api.File:Read(incomingSkillFile) end)
                        if ok and existing then
                            for s in string.gmatch(existing, "skill=([^\n]+)\n?") do
                                seenIncomingSkills[s] = true
                            end
                        end
                    end
                    if not seenIncomingSkills[skill] then
                        seenIncomingSkills[skill] = true
                        local isKnown = SKILL_DAMAGE_TYPES[skill] ~= nil
                        local confidence = absorbed > 0 and "inferred" or "no-mitigation-data"
                        local entry = string.format("[%s] type=%s skill=%s source=%s action=%s confidence=%s",
                            isKnown and "KNOWN" or "NEW", incTag, skill, sourceName, actionType, confidence)
                        local prev = ""
                        local ok2, existing2 = pcall(function() return api.File:Read(incomingSkillFile) end)
                        if ok2 and existing2 and existing2 ~= "" then prev = existing2 end
                        local append = prev ~= "" and (prev .. "\n" .. entry) or entry
                        pcall(function() api.File:Write(incomingSkillFile, append) end)
                        if not isKnown then
                            LogEntry(string.format("[New] %s from %s = %s", skill, sourceName, incTag), 1, 0.7, 0.2)
                        end
                    end
                end
                if actionType == "ENVIRONMENTAL_DAMAGE" then
                    -- Falling/drowning ignores armor/dodge/parry -- keep it OUT of the physical
                    -- mitigation breakdown so the summary doesn't show armor/dodge/modifiers for it.
                    -- It still appears in the per-skill list + the Total line (both from data.skills).
                    fightData.incoming[incomingKey].envDmg = (fightData.incoming[incomingKey].envDmg or 0) + absDmg
                elseif incIsMagic then
                    fightData.incoming[incomingKey].magicDmg      = (fightData.incoming[incomingKey].magicDmg      or 0) + absDmg
                    fightData.incoming[incomingKey].magicAbsorbed = (fightData.incoming[incomingKey].magicAbsorbed  or 0) + absorbed
                    fightData.incoming[incomingKey].magicHits     = (fightData.incoming[incomingKey].magicHits      or 0) + 1
                elseif incIsRanged then
                    fightData.incoming[incomingKey].rangedDmg      = (fightData.incoming[incomingKey].rangedDmg      or 0) + absDmg
                    fightData.incoming[incomingKey].rangedAbsorbed = (fightData.incoming[incomingKey].rangedAbsorbed or 0) + absorbed
                    fightData.incoming[incomingKey].rangedHits     = (fightData.incoming[incomingKey].rangedHits     or 0) + 1
                else
                    fightData.incoming[incomingKey].physDmg      = (fightData.incoming[incomingKey].physDmg      or 0) + absDmg
                    fightData.incoming[incomingKey].physAbsorbed = (fightData.incoming[incomingKey].physAbsorbed  or 0) + absorbed
                    fightData.incoming[incomingKey].physHits     = (fightData.incoming[incomingKey].physHits      or 0) + 1
                end
                fightData.incoming[incomingKey].skills[skill] = (fightData.incoming[incomingKey].skills[skill] or 0) + absDmg
                fightData.incoming[incomingKey].totalAbsorbed = (fightData.incoming[incomingKey].totalAbsorbed or 0) + absorbed
                -- Bulwark Ballad: damage prevented by ballad's defense bonus
                local bulwarkAnno = ""
                if bulwarkActive then
                    local defBonus, baseline = 0, 0
                    if incIsMagic and bulwarkResistBonus > 0 and baselineMagicResist then
                        defBonus = bulwarkResistBonus; baseline = baselineMagicResist
                    elseif bulwarkArmorBonus > 0 and baselineArmor then
                        defBonus = bulwarkArmorBonus; baseline = baselineArmor
                    end
                    if defBonus > 0 and baseline > 0 then
                        local prevented = math.floor(absDmg * defBonus / (baseline + 8000))
                        if prevented > 0 then
                            fightData.incoming[incomingKey].bulwarkPrevented = (fightData.incoming[incomingKey].bulwarkPrevented or 0) + prevented
                            bulwarkAnno = " [Ballad +" .. prevented .. "]"
                        end
                    end
                end
                -- Shield absorb attribution: if a player-cast shield is up and this hit was
                -- (partly) absorbed, credit the shield. Approximate when multiple shields exist.
                local shieldAnno = ""
                if absorbed > 0 and bonuses.shieldName then
                    local sn = bonuses.shieldName
                    fightData.incoming[incomingKey].shieldAbsorbed = fightData.incoming[incomingKey].shieldAbsorbed or {}
                    fightData.incoming[incomingKey].shieldAbsorbed[sn] = (fightData.incoming[incomingKey].shieldAbsorbed[sn] or 0) + absorbed
                    shieldAnno = " [Shield: " .. sn .. "]"
                end
                local c = GetSafeColor(CONFIG.COL_INCOMING)
                local incHitDisplay = string.find(tostring(hitType):upper(), "CRITICAL") and "Critical" or "HIT"
                local sc = GetSafeColor(CONFIG.COL_SKILL_LABEL)
                -- Incoming ancestral-variant icon: a same-named skill cast AT you -> read the debuff it
                -- left on you to identify the caster's variant (best-effort; nil/base if none).
                local incVarIcon = nil
                if targetName == PLAYER_NAME and CONFIG._skillVariants[skill] then
                    incVarIcon = CONFIG._incomingVariantIcon(skill)
                end
                RecordLogForTarget(incomingKey, sourceName,
                    string.format("< %s from %s", skill, sourceName),
                    sc[1], sc[2], sc[3],
                    { logType = "incoming", skill = skill, source = sourceName, target = targetName, damage = absDmg, absorbed = absorbed, hitType = hitType, dmgTag = incTag, varIcon = incVarIcon })
                local incLine = absorbed > 0
                    and string.format("[%s] %d (%s|%d absorbed)%s%s", incLabel, absDmg, incHitDisplay, absorbed, bulwarkAnno, shieldAnno)
                    or  string.format("[%s] %d (%s)%s%s", incLabel, absDmg, incHitDisplay, bulwarkAnno, shieldAnno)
                local incLineSimple = absorbed > 0
                    and string.format("[%s] %d (%s|%d absorbed)", incLabel, absDmg, incHitDisplay, absorbed)
                    or  string.format("[%s] %d (%s)", incLabel, absDmg, incHitDisplay)
                -- Append your HP% to incoming hits
                do
                    local okH, h = pcall(function() return api.Unit:UnitHealth("player") end)
                    local okM, m = pcall(function() return api.Unit:UnitMaxHealth("player") end)
                    if okH and okM and h and m and m > 0 then
                        local hpS = string.format(" [%d%%]", math.floor(h / m * 100))
                        incLine = incLine .. hpS
                        incLineSimple = incLineSimple .. hpS
                    end
                end
                local incMeta = incLine ~= incLineSimple and { liveText = incLineSimple } or nil
                RecordLogForTarget(incomingKey, sourceName, incLine, c[1], c[2], c[3], incMeta)
                -- Incoming mitigation breakdown: reverse the full reduction chain
                -- Chain: raw → toughness → armor/resist → % reduction → flat reduction = absDmg.
                -- Skipped for falling/drowning -- environmental damage ignores armor/DR/toughness.
                if actionType ~= "ENVIRONMENTAL_DAMAGE" then
                    local playerDef  = incIsMagic and currentMagicResist or currentArmor
                    local incPctMul  = incIsMagic and incDmgStats.spellMul  or (incIsRanged and incDmgStats.rangedMul or incDmgStats.meleeMul)
                    local incFlatVal = incIsMagic and incDmgStats.spellVal   or (incIsRanged and incDmgStats.rangedVal or incDmgStats.meleeVal)
                    -- Step 1: reverse flat reduction (flatVal is negative, so add it back)
                    local flatReduction = math.max(0, -math.floor(incFlatVal))
                    local postPct = absDmg + flatReduction
                    -- Step 2: reverse % reduction (pctMul is negative, e.g. -19.4 means ×0.806)
                    local pctMul = 1 + incPctMul / 100  -- e.g. 1 + (-19.4/100) = 0.806
                    local postArmor = pctMul < 1 and pctMul > 0 and math.floor(postPct / pctMul) or postPct
                    local pctReduction = math.max(0, postArmor - postPct)
                    -- Step 3: reverse armor/resist (enemy pen unknown; PvE exact, PvP approximate)
                    local postTough = playerDef > 0
                        and math.floor(postArmor * (playerDef + 8000) / 8000)
                        or  postArmor
                    local defReduction = math.max(0, postTough - postArmor)
                    -- Step 4: reverse toughness — only applies in PvP (source must be a player)
                    local computedRaw = incSourceToughness > 0
                        and math.floor(postTough * (incSourceToughness + 8000) / 8000)
                        or  postTough
                    local toughReduction = math.max(0, computedRaw - postTough)
                    if computedRaw > absDmg then
                        local defLabel = incIsMagic and "Resist" or "Armor"
                        local mitParts = { string.format("Raw %d", computedRaw) }
                        if toughReduction > 0 then mitParts[#mitParts+1] = string.format("Tough -%d", toughReduction) end
                        if defReduction   > 0 then mitParts[#mitParts+1] = string.format("%s -%d", defLabel, defReduction) end
                        local redLabel   = incIsMagic and "Magic DR"   or (incIsRanged and "Ranged DR"   or "Melee DR")
                        local fixedLabel = incIsMagic and "Fixed Magic" or (incIsRanged and "Fixed Ranged" or "Fixed Melee")
                        if pctReduction  > 0 then mitParts[#mitParts+1] = string.format("%s -%d", redLabel,   pctReduction)  end
                        if flatReduction > 0 then mitParts[#mitParts+1] = string.format("%s -%d", fixedLabel, flatReduction) end
                        RecordLogForTarget(incomingKey, sourceName,
                            "  " .. table.concat(mitParts, " | "),
                            0.6, 0.6, 0.6, { detailOnly = true })
                    end
                end
            elseif isCC then
                local c = GetSafeColor(CONFIG.COL_CC)
                RecordLogForTarget(incomingKey, sourceName, string.format("< %s (CC) from %s", skill, sourceName), c[1], c[2], c[3],
                    { logType = "cc", skill = skill, source = sourceName, target = targetName })
            end
        end

    elseif event == "UNIT_COMBAT_STATE_CHANGED" then
        -- args[1] = boolean (true=entering, false=leaving), args[2] = unitId (string)
        local enteringCombat = args[1]
        local unitId = tostring(args[2] or "")
        local playerId = tostring(api.Unit:GetUnitId("player") or "")
        -- A mob you damaged LEAVING combat = it died (proven via probe: mobs fire entering=false
        -- on death; UNIT_DEAD never fires for them). Catches NON-targeted deaths (AoE/DoT) the HP
        -- poll can't see. Keyed by unit id so several same-named mobs each register. The TIGHT
        -- recent-hit gate distinguishes a KILL (left combat <1.5s after your killing blow) from a
        -- LEASH (you fled -> the mob gives up SECONDS after your last hit): a stale last-hit means
        -- you disengaged, not killed it. Players win via UNIT_DEAD (deduped by id).
        if enteringCombat == false and unitId ~= playerId and unitId ~= "" then
            local od = fightData.outgoing[unitId]
            if od and od.name and (frameNow - (od.lastUpdate or 0) < 1500) then
                CONFIG._deathLogged = CONFIG._deathLogged or {}
                if not CONFIG._deathLogged[unitId] then
                    fightData.killedNames = fightData.killedNames or {}; fightData.killedNames[od.name] = true
                    local ks, kr = "", CONFIG._lastDmgSrc and CONFIG._lastDmgSrc[unitId]
                    if kr and kr ~= "" and kr ~= od.name then ks = (kr == PLAYER_NAME) and "  (your kill)" or ("  (killed by " .. kr .. ")") end
                    CONFIG._killGrace = CONFIG._killGrace or {}
                    if not CONFIG._killGrace[unitId] then CONFIG._killGrace[unitId] = { t = frameNow, ks = ks, name = od.name } end
                end
            end
        end
        -- Spectator / raid-log mode (opt-in): a NEARBY unit entering combat opens a fight even when
        -- you never participate. The gap-timeout (kept alive by recorded nearby events) closes + saves
        -- it once nearby combat stops.
        if CONFIG.SPECTATE and enteringCombat == true and unitId ~= playerId and unitId ~= "" and not inCombat then
            inCombat = true
            timeSinceLastAction = 0
            SetCombatStatus(true)
        end
        if unitId == playerId then
            if enteringCombat == true then
                CONFIG._gameInCombat = true  -- runtime flag (not a setting): the game's combat state
                if not inCombat then
                    inCombat = true
                    timeSinceLastAction = 0
                    SetCombatStatus(true)
                end
            else
                CONFIG._gameInCombat = false
                -- Game says combat ended - give DOT_WAIT room for trailing DoT ticks
                -- before FinishFight closes the session.
                if inCombat then
                    local waitAfterCombatEnd = CONFIG.COMBAT_WAIT - CONFIG.DOT_WAIT
                    if waitAfterCombatEnd < 0 then waitAfterCombatEnd = 0 end
                    timeSinceLastAction = waitAfterCombatEnd
                end
            end
        end

    elseif event == "TARGET_CHANGED" then
        -- Cache the current target's name so the recap can read its HP% via the "target" handle
        -- (the only way to read an enemy's health -- they have no team tag).
        do
            local okTN, tName = pcall(function() return api.Unit:UnitName("target") end)
            CONFIG._curTargetName = (okTN and tName and tName ~= "") and tName or nil
        end
        -- Cache the targeted unit's gear score by name. UnitGearScore only works for your CURRENT
        -- target (the deep stats are nil for arbitrary feed units, proven via probe) and reads 0 for
        -- mobs -- so we opportunistically stash a real (>0) score whenever you target a player, and
        -- surface it in that unit's history view.
        if CONFIG._curTargetName then
            local tln = string.lower(CONFIG._curTargetName)
            -- Gear score / faction name / force-PvP are PLAYER-only stats (mobs read 0/nothing,
            -- gathering nodes aren't characters at all). The old code fired all three native unit
            -- queries on EVERY target change -- which storms the engine when you churn targets fast
            -- (harvesting a farm flips through hundreds of nodes a minute), and pcall can't catch a
            -- native access violation. Gate them: resolve a name AT MOST ONCE, and only after a cheap
            -- class check confirms the target is a character (player). Non-players cost one
            -- GetUnitClassName call on first sight, then nothing. Players keep retrying until gear
            -- score loads (it's async).
            CONFIG._nameSeen = CONFIG._nameSeen or {}
            if not CONFIG._nameSeen[tln] then
                local isChar = false
                -- Post-2026-06-18 lockdown: GetUnitInfoById(targetId) returns nil, so the old
                -- info.type=="character" probe ALWAYS failed -- faction/force/gear-score were never
                -- cached and faction colour + the bloodlust mark broke for every target. GetUnitClassName
                -- still works as a token read: a real class name for players, "Pending" for mobs /
                -- gathering nodes -- so it's the post-lockdown "is this a character?" signal.
                local okCN, cn = pcall(function() return api.Ability:GetUnitClassName("target") end)
                if okCN and cn and cn ~= "" and tostring(cn) ~= "Pending" then isChar = true end
                if isChar then
                    local okG, g = pcall(function() return api.Unit:UnitGearScore("target") end)
                    local gs = okG and tonumber(g) or nil
                    if gs and gs > 0 then CONFIG._nameGS = CONFIG._nameGS or {}; CONFIG._nameGS[tln] = gs end
                    local okF, fn = pcall(function() return api.Unit:GetFactionName("target") end)
                    if okF and fn and fn ~= "" then CONFIG._nameFaction = CONFIG._nameFaction or {}; CONFIG._nameFaction[tln] = tostring(fn) end
                    local okA, fa = pcall(function() return api.Unit:UnitIsForceAttack("target") end)
                    if okA then CONFIG._nameForce = CONFIG._nameForce or {}; CONFIG._nameForce[tln] = fa and true or false end
                    if CONFIG._nameGS and CONFIG._nameGS[tln] then CONFIG._nameSeen[tln] = true end  -- gear score landed; stop
                else
                    CONFIG._nameSeen[tln] = true   -- non-character (mob / gathering node / mount): never re-probe
                end
            end
        end
        -- TEMP probe: dump EACH distinct target's UnitInfo (and the player once) so we can compare
        -- mounts vs players vs mobs and find a reliable "is a mount" signal. Target several things.
        if CONFIG.DEBUG_UNITINFO then
            local okTN, tName = pcall(function() return api.Unit:UnitName("target") end)
            local nm = (okTN and tName) or nil
            CONFIG._dumpedTargets = CONFIG._dumpedTargets or {}
            if nm and not CONFIG._dumpedTargets[nm] then
                CONFIG._dumpedTargets[nm] = true
                local lines = {}
                local function dumpUI(label, tbl)
                    lines[#lines + 1] = "=== " .. label .. " ==="
                    if type(tbl) == "table" then
                        for k, v in pairs(tbl) do lines[#lines + 1] = "  " .. tostring(k) .. " = " .. tostring(v) end
                    end
                end
                if not CONFIG._dumpedPlayer then
                    CONFIG._dumpedPlayer = true
                    pcall(function() api.File:Write("CombatLogPro/unitinfo_dump.txt", "") end)  -- fresh file
                    local okP, pInfo = pcall(function() return api.Unit:UnitInfo("player") end)
                    dumpUI("PLAYER (you)", okP and pInfo or nil)
                end
                local okT, tInfo = pcall(function() return api.Unit:UnitInfo("target") end)
                dumpUI("TARGET = " .. nm, okT and tInfo or nil)
                -- CLASS source (separate from UnitInfo) + skillset decode -- this is what tags a
                -- ridden mount as a "player", so capture what it returns for mounts vs real players.
                local okCN, cn = pcall(function() return api.Ability:GetUnitClassName("target") end)
                local okUC, uc = pcall(function() return api.Unit:UnitClass("target") end)
                lines[#lines + 1] = "  [GetUnitClassName] = " .. tostring((okCN and cn) or "nil")
                lines[#lines + 1] = "  [UnitClass] = " .. tostring((okUC and uc) or "nil")
                if type(tInfo) == "table" then
                    for k, v in pairs(tInfo) do
                        local n = tonumber(v)
                        if n and n > 0 and n < 100 then
                            local okS, sn = pcall(function() return api.Ability:GetSkillsetNameById(n) end)
                            if okS and sn and sn ~= "" then lines[#lines + 1] = "  [skillset] " .. tostring(k) .. "=" .. n .. " -> " .. tostring(sn) end
                        end
                    end
                end
                local okR, ex = pcall(function() return api.File:Read("CombatLogPro/unitinfo_dump.txt") end)
                local prev = (okR and ex and ex ~= "") and (tostring(ex) .. "\n") or ""
                pcall(function() api.File:Write("CombatLogPro/unitinfo_dump.txt", prev .. table.concat(lines, "\n")) end)
            end
        end
        -- patch 243+: instant target update instead of waiting for 200ms scan tick
        local currentTgtID = api.Unit:GetUnitId("target")
        if currentTgtID ~= lastTargetID then
            lastTargetID = currentTgtID
            if currentTgtID then activeDebuffsCache[currentTgtID] = {} end
            lastTargetBuffCount = -1  -- force buff effects re-scan on next tick
        end
        -- Immediately rescan buffs/debuffs on the new target
        ScanUnitDebuffs("player")
        ScanUnitDebuffs("target")

    elseif event == "SPELLCAST_SUCCEEDED" then
        -- patch 243+: fires when a cast-time skill completes (before the COMBAT_MSG damage event).
        -- Attempt to cache the skill name (arg layout TBD; try common positions)
        local castSkill = tostring(args[2] or args[1] or "")
        if castSkill ~= "" and castSkill ~= "0" then
            lastPlayerCast = castSkill
        end
        currentCast = nil  -- cast finished, clear in-progress state
        -- A pending Revive reaching SUCCEEDED = a completed revive (success fires SUCCEEDED, an
        -- interrupt fires STOP -- mutually exclusive, confirmed via probe). Log it + bump the
        -- running session count. Freshness guard ignores a stale pending (e.g. a missed STOP) so a
        -- later unrelated cast can't claim it.
        if CONFIG._pendingRevive and (api.Time:GetUiMsec() - (CONFIG._pendingRevive.t or 0)) < 8000 then
            local rv = CONFIG._pendingRevive
            CONFIG._fightReviveCount = (CONFIG._fightReviveCount or 0) + 1
            local tgt = (rv.target and rv.target ~= "") and rv.target or "an ally"
            LogEntry(string.format("+ %s -> %s  [revive #%d]", rv.skill, tgt, CONFIG._fightReviveCount),
                0.4, 1, 0.7, { skill = rv.skill })
        end
        CONFIG._pendingRevive = nil

    elseif event == "SPELLCAST_START" then
        -- patch 243+: fires when the player begins casting a cast-time skill.
        -- arg[1]=skill name, arg[2]=cast time ms, arg[3]="player", arg[4]=false
        local castSkill = tostring(args[1] or "")
        if castSkill ~= "" and castSkill ~= "0" then
            currentCast = castSkill
            lastPlayerCast = castSkill  -- cache here since SUCCEEDED only returns "player"
            -- Single-target Revive tracking: capture the revivee NOW (your target at cast START --
            -- Revive can't be cast without a dead ally selected, and you may re-target mid-cast).
            -- Finalised on SUCCEEDED, discarded on STOP (interrupt). Defy Death / AoE NOT tracked.
            if string.match(string.lower(castSkill), "^revive") then
                CONFIG._pendingRevive = { skill = castSkill, target = CONFIG._curTargetName, t = api.Time:GetUiMsec() }
            end
        end

    elseif event == "SPELLCAST_STOP" then
        -- patch 243+: fires when a cast ends. Per the revive probe, a SUCCESSFUL cast fires only
        -- SUCCEEDED and an interrupt fires only STOP -- so STOP here means the cast was interrupted.
        currentCast = nil
        lastPlayerCast = nil
        CONFIG._pendingRevive = nil   -- interrupted -> no revive happened, don't count it

    elseif event == "TARGET_TO_TARGET_CHANGED" then
        -- patch 243+: fires when what your target is targeting changes.
        -- Update the live targeting flag used at fight-start snapshot time.
        local okTU, targeting = pcall(function()
            return api.Unit:TargetUnit("target")
        end)
        targetIsTargetingPlayerLive = (okTU and targeting == "player")
        -- Also update any active outgoing session for the current target so
        -- the summary reflects the live state rather than just the fight-start snapshot.
        local currentTgt = api.Unit:GetUnitId("target")
        if currentTgt and fightData.outgoing[tostring(currentTgt)] then
            local snap = fightData.outgoing[tostring(currentTgt)].statSnapshot
            if snap then snap.targetIsTargetingPlayer = targetIsTargetingPlayerLive end
        end
    end
end

local function OnLiveUpdate(self, dt)
    local elapsed = dt
    if elapsed < 1 then elapsed = elapsed * 1000 end
    local now = api.Time:GetUiMsec()

    -- Update cached timestamp once per frame (used by all log entry functions)
    RefreshTimestamp(now)

    -- Flush any throttled live label rebuild / history display update
    if (liveRebuildDirty or histDisplayDirty) and (now - lastLiveRebuildTime) >= 50 then
        lastLiveRebuildTime = now
        if liveRebuildDirty then
            liveRebuildDirty = false
            RebuildLiveLabels()
        end
        if histDisplayDirty then
            histDisplayDirty = false
            UpdateHistoryDisplay()
        end
    end

    -- === TIME INITIALIZATION ===
    if not TIME_INITIALIZED then
        local t = api.Time:GetLocalTime()
        if t then
            if type(t) == "table" then
                local h = tonumber(t.hour or t.Hour) or 0
                local m = tonumber(t.minute or t.Minute) or 0
                local s = tonumber(t.second or t.Second) or 0
                BASE_SECONDS_OF_DAY = (h * 3600) + (m * 60) + s
                BASE_APP_MSEC = now
                TIME_INITIALIZED = true
            elseif type(t) == "number" or type(t) == "string" then
                local tVal = tonumber(t)
                if tVal and tVal > 0 then
                    BASE_SECONDS_OF_DAY = tVal % 86400
                    BASE_APP_MSEC = now
                    TIME_INITIALIZED = true
                end
            end
        end
    end
    
    if PLAYER_NAME == "Unknown" then
        nameCheckTimer = nameCheckTimer + elapsed
        if nameCheckTimer > 1000 then
            nameCheckTimer = 0
            local myName = api.Unit:UnitName("player")  -- patch 243+: simpler than GetUnitId+GetUnitNameById
            if not myName or myName == "" then
                local myId = api.Unit:GetUnitId("player")
                myName = api.Unit:GetUnitNameById(myId)
            end
            if myName and myName ~= "" then PLAYER_NAME = myName; LogEntry("[System] Player Name Detected: " .. PLAYER_NAME, 0, 1, 0) end
        end
    end
    
    scannerTimer = scannerTimer + elapsed
    if scannerTimer > CONFIG.SCAN_FREQ then
        scannerTimer = 0
        -- Target-ID change is now handled instantly by TARGET_CHANGED event (patch 243+).
        -- Poll here as fallback in case the event is not fired (e.g. on older builds).
        local currentTgtID = api.Unit:GetUnitId("target")
        if currentTgtID ~= lastTargetID then
            lastTargetID = currentTgtID
            if currentTgtID then activeDebuffsCache[currentTgtID] = {} end
            lastTargetBuffCount = -1  -- force buff effects re-scan on next tick
        end
        if inCombat then ScanUnitDebuffs("player"); ScanUnitDebuffs("target") end

        -- Player absorb-shield tracking (Insulating Lens, etc.). These carry a pool that depletes
        -- as it soaks hits but fires NO combat event. The live remaining is the buff instance's
        -- `stack` field (proven via probe: stack ticks 2049->... while the by-id tooltip stays
        -- frozen at max). On buff-set change, identify the shield by its "absorbs ... damage"
        -- tooltip (one scan); each tick, read its `stack` and bank every drop into "Shields
        -- absorbed". State on CONFIG (no main-chunk locals). NB: `stack` means remaining pool
        -- ONLY for the identified shield -- for other buffs it's an ordinary stack count.
        if inCombat then do
            local pbc = api.Unit:UnitBuffCount("player") or 0
            if pbc ~= (CONFIG._pbCount or -1) then
                CONFIG._pbCount = pbc
                local sid, sname
                for i = 1, pbc do
                    local b = api.Unit:UnitBuff("player", i)
                    if b and b.buff_id then
                        local tt = api.Ability:GetBuffTooltip(b.buff_id)
                        local d = string.lower(tt and (tt.desc or tt.description or tt.text or tt.info) or "")
                        if string.find(d, "absorbs") and string.find(d, "damage") then
                            sid = b.buff_id; sname = (tt and tt.name) or "Shield"; break
                        end
                    end
                end
                if sid then
                    if not (CONFIG._poolShield and CONFIG._poolShield.id == sid) then
                        CONFIG._poolShield = { id = sid, name = sname }
                    end
                else
                    CONFIG._poolShield = nil
                end
            end
            local ps = CONFIG._poolShield
            if ps and ps.id then
                local rem
                for i = 1, pbc do
                    local b = api.Unit:UnitBuff("player", i)
                    if b and b.buff_id == ps.id then rem = tonumber(b.stack); break end
                end
                if rem then
                    if ps.last == nil then
                        ps.last = rem
                    elseif rem < ps.last then
                        CONFIG._shieldAbsorb = CONFIG._shieldAbsorb or {}
                        CONFIG._shieldAbsorb[ps.name] = (CONFIG._shieldAbsorb[ps.name] or 0) + (ps.last - rem)
                        ps.last = rem
                    elseif rem > ps.last then
                        ps.last = rem  -- recast/refresh
                    end
                end
            end
        end end

        -- Scan target buffs for combat-affecting effects (invincibility, spell shield, runes)
        -- Target buff effects scan (invincibility, spell shield, rune, damage shield).
        -- Skip if buff count unchanged since last scan — avoids redundant API calls.
        local tgtBuffCount = api.Unit:UnitBuffCount("target") or 0
        if tgtBuffCount ~= lastTargetBuffCount then
            lastTargetBuffCount = tgtBuffCount
            targetBuffEffects.invincible = false
            targetBuffEffects.spellShieldPct = 0
            targetBuffEffects.runeConvertPct = 0
            targetBuffEffects.runeConvertName = nil
            targetBuffEffects.dmgShield = false
            targetBuffEffects.dmgShieldMax = 0
            targetBuffEffects.dmgShieldName = nil
            for i = 1, tgtBuffCount do
                local b = api.Unit:UnitBuff("target", i)
                if b and b.buff_id then
                    -- Use buffEffectCache to avoid re-parsing tooltip text per buff_id
                    local fx = buffEffectCache[b.buff_id]
                    if fx == nil then
                        fx = {}
                        local tt = api.Ability:GetBuffTooltip(b.buff_id)
                        local name = tt and tt.name or ""
                        local desc = tt and (tt.desc or tt.description or tt.text or tt.info) or ""
                        local combined = string.lower(name .. " " .. desc)
                        buffNameCache[b.buff_id] = name

                        -- Invincibility: tooltip text patterns
                        if (string.find(combined, "immun") and
                           (string.find(combined, "all damage") or string.find(combined, "all attacks") or
                            string.find(combined, "immune to all") or string.find(combined, "immune to damage") or
                            string.find(combined, "immune to incoming")))
                           or string.find(combined, "invincib")
                           or string.find(combined, "cannot receive damage")
                           or string.find(combined, "cannot take damage")
                           or string.find(combined, "damage immunity")
                           or string.find(combined, "impervious to damage")
                           or string.find(combined, "negates all damage")
                           or (string.find(combined, "shadowsong") and string.find(combined, "resists all damage")) then
                            fx.invincible = true
                        end
                        -- Invincibility: known mount/glider buff names (tooltip may not mention immunity)
                        if not fx.invincible and KNOWN_INVINCIBLE_BUFF_NAMES[string.lower(name)] then
                            fx.invincible = true
                        end
                        if string.find(combined, "spell shield") or
                           (string.find(combined, "convert") and string.find(combined, "magic") and string.find(combined, "health")) then
                            fx.spellShieldPct = tonumber(string.match(desc, "(%d+)%%")) or 0
                        end
                        if string.find(combined, "rune") and string.find(combined, "convert") and string.find(combined, "received damage") then
                            local pct = tonumber(string.match(desc, "(%d[%d%.]*)%%")) or 0
                            if pct > 0 then fx.runeConvertPct = pct; fx.runeConvertName = name end
                        end
                        if string.find(combined, "absorb") and string.find(combined, "damage") and
                           not string.find(combined, "absorb.-lifeforce") then
                            local maxAbs = string.match(desc, "absorbs%s+up%s+to%s+([%d,]+)")
                                        or string.match(desc, "absorbs%s+([%d,]+)")
                            if maxAbs then
                                local val = tonumber(string.gsub(maxAbs, ",", "")) or 0
                                if val > 0 then fx.dmgShield = true; fx.dmgShieldMax = val; fx.dmgShieldName = name end
                            end
                        end
                        buffEffectCache[b.buff_id] = fx
                    end
                    -- Apply cached flags
                    if fx.invincible    then targetBuffEffects.invincible = true end
                    if fx.spellShieldPct and fx.spellShieldPct > 0 then targetBuffEffects.spellShieldPct = fx.spellShieldPct end
                    if fx.runeConvertPct and fx.runeConvertPct > 0 then
                        targetBuffEffects.runeConvertPct  = fx.runeConvertPct
                        targetBuffEffects.runeConvertName = fx.runeConvertName
                    end
                    if fx.dmgShield then
                        targetBuffEffects.dmgShield    = true
                        targetBuffEffects.dmgShieldMax  = fx.dmgShieldMax or 0
                        targetBuffEffects.dmgShieldName = fx.dmgShieldName
                    end
                end
            end
        end

        -- Zeal uptime + duel-end detection (both scan player buffs while in combat)
        -- Also refreshes playerBuffStackCache so GetPlayerBuffStacks() reads a cached value
        -- instead of calling UnitBuff() again inside the combat event handler.
        do
            local nowMs = api.Time:GetUiMsec()
            local wasZeal = zealActive
            zealActive = false
            chantyActive = false
            bulwarkActive = false
            bonuses.magicCircleActive    = false
            bonuses.deliriumStacks       = 0
            bonuses.burningBrandStacks   = 0
            bonuses.overpoweredActive    = false
            bonuses.assassinationActive  = false
            bonuses.battleFocusActive    = false
            bonuses.intensifiedHarmActive = false
            bonuses.inspiredStacks       = 0
            bonuses.shieldName           = nil
            local bc = api.Unit:UnitBuffCount("player") or 0
            local newStackCache = {}
            for i = 1, bc do
                local b = api.Unit:UnitBuff("player", i)
                if b and b.buff_id then
                    local bid = b.buff_id
                    local bstacks = math.max(1, tonumber(b.stack or b.count or 1))
                    -- Zeal check (IDs 494 and 495 both exist in static data)
                    if bid == 494 or bid == 495 then zealActive = true end
                    -- Magic Circle (Sorcery): Ranks 1-3 and 5-6 (no Rank 4 in static data)
                    if bid == 1248 or bid == 1249 or bid == 8075
                    or bid == 13775 or bid == 13776 then
                        bonuses.magicCircleActive = true
                    end
                    -- Delirium (Battlerage): stacking melee/ranged dmg
                    if bid == 11344 then bonuses.deliriumStacks = bstacks end
                    -- Burning Brand (Occultism): stacking magic dmg
                    if bid == 15002 then bonuses.burningBrandStacks = bstacks end
                    -- Overpowered Spell Locus (Occultism): fixed +15% all skill dmg
                    if bid == 2969 or bid == 2970 then bonuses.overpoweredActive = true end
                    -- Assassination (Shadowplay): fixed +12% all skill dmg
                    if bid == 18346 then bonuses.assassinationActive = true end
                    -- Battle Focus (Battlerage): +20% melee crit dmg
                    if bid == 404 or bid == 5134 or bid == 7651 or bid == 13612 or bid == 13613 then
                        bonuses.battleFocusActive = true
                    end
                    -- Intensified Harm (Occultism): +25% all crit dmg after receiving crit
                    if bid == 971 or bid == 7559 then bonuses.intensifiedHarmActive = true end
                    -- Inspired (Auramancy): +52%/stack to Vicious Implosion
                    if bid == 127 then bonuses.inspiredStacks = bstacks end
                    -- Duel ("mock fight"): the Duel buff is present throughout the duel -> tag the fight
                    -- so its sidebar row gets the duel icon (id 1834/3649 from static_buff_list).
                    if bid == 1834 or bid == 3649 then CONFIG._fightWasDuel = true end
                    -- Damage-absorb shields on the player (for absorb attribution)
                    if bid == 11273 then bonuses.shieldName = "Omnipotent Ward"
                    elseif bid == 15078 then bonuses.shieldName = "Deliverance Shield" end
                    -- Name resolution (needed for duel-end check and stack cache)
                    local bname = buffDB[b.buff_id] or buffNameCache[b.buff_id]
                    if not bname then
                        local ok, tt = pcall(function() return api.Ability:GetBuffTooltip(b.buff_id) end)
                        if ok and tt and tt.name then bname = tt.name; buffNameCache[b.buff_id] = bname end
                    end
                    if bname then
                        -- Chanty check (by name prefix, covers all ranks)
                        if string.find(string.lower(bname), "bloody chant") then chantyActive = true end
                        -- Bulwark Ballad check
                        if string.find(string.lower(bname), "bulwark ballad") then bulwarkActive = true end
                        -- Populate stack cache (used by GetPlayerBuffStacks in combat handler)
                        newStackCache[bname] = math.max(1, tonumber(b.stack or b.count or 1))
                        -- Duel-end check (a mock-fight-end buff also confirms this WAS a duel)
                        if inCombat and DUEL_END_BUFF_NAMES[string.lower(bname)] then
                            CONFIG._fightWasDuel = true
                            playerBuffStackCache = newStackCache
                            FinishFight()
                            break
                        end
                    end
                end
            end
            playerBuffStackCache = newStackCache

            -- Update song buff stats from playerInfo
            rhythmStacks = (playerBuffStackCache and playerBuffStackCache["Rhythm"]) or 0
            local okP, pInfoScan = pcall(function() return api.Unit:UnitInfo("player") end)
            if okP and pInfoScan then
                currentSpellDmgMul  = tonumber(pInfoScan.spell_damage_mul or 0)
                currentArmor        = tonumber(pInfoScan.armor             or 0)
                currentMagicResist  = tonumber(pInfoScan.magic_resist      or 0)
                currentSpellDps     = tonumber(pInfoScan.spell_dps                  or 0)
                currentBattleResist = tonumber(pInfoScan.battle_resist               or 0)
                -- Magic Circle baseline: capture spell_dps when no Rhythm and no Magic Circle active
                if not bonuses.magicCircleActive and rhythmStacks == 0 then
                    bonuses.baseSpellDps = currentSpellDps
                end
                if bonuses.magicCircleActive and bonuses.baseSpellDps then
                    bonuses.magicCircleDpsBonus = math.max(0,
                        currentSpellDps - bonuses.baseSpellDps - rhythmStacks * RHYTHM_DPS_PER_STACK)
                else
                    bonuses.magicCircleDpsBonus = 0
                end
                -- Heal-power buff tracking: heal_dps = flat healing power (parallels spell_dps;
                -- raised by Rhythm/Ode); heal_mul = % heal bonus. Baseline captured out of
                -- combat (gear-only) so the in-combat delta is the buff contribution.
                bonuses.healDps = tonumber(pInfoScan.heal_dps or 0)
                bonuses.healMul = tonumber(pInfoScan.heal_mul or 0)
                if not inCombat then bonuses.baseHealDps = bonuses.healDps end
                incDmgStats.spellMul  = tonumber(pInfoScan.incoming_spell_damage_mul  or 0)
                incDmgStats.meleeMul  = tonumber(pInfoScan.incoming_melee_damage_mul  or 0)
                incDmgStats.rangedMul = tonumber(pInfoScan.incoming_ranged_damage_mul or 0)
                incDmgStats.spellVal  = tonumber(pInfoScan.incoming_spell_damage_val  or 0)
                incDmgStats.meleeVal  = tonumber(pInfoScan.incoming_melee_damage_val  or 0)
                incDmgStats.rangedVal = tonumber(pInfoScan.incoming_ranged_damage_val or 0)
            end
            if chantyActive then
                if baselineSpellDmgMul then
                    chantySpellBonus = math.max(0, currentSpellDmgMul - baselineSpellDmgMul)
                end
            else
                baselineSpellDmgMul = currentSpellDmgMul
                chantySpellBonus = 0
            end
            if bulwarkActive then
                if baselineArmor       then bulwarkArmorBonus  = math.max(0, currentArmor       - baselineArmor)       end
                if baselineMagicResist then bulwarkResistBonus = math.max(0, currentMagicResist - baselineMagicResist) end
            else
                baselineArmor        = currentArmor
                baselineMagicResist  = currentMagicResist
                bulwarkArmorBonus    = 0
                bulwarkResistBonus   = 0
            end

            if inCombat then
                if zealActive and not wasZeal then
                    zealStartTime = nowMs
                elseif not zealActive and wasZeal and zealStartTime then
                    fightZealTime = fightZealTime + (nowMs - zealStartTime)
                    zealStartTime = nil
                end
            end
        end

        if CONFIG.DUMP_BUFFS then
            CONFIG.DUMP_BUFFS = false
            local buffData = {}
            local count = api.Unit:UnitBuffCount("player") or 0
            for i = 1, count do
                local b = api.Unit:UnitBuff("player", i)
                if b then
                    -- Resolve buff name via tooltip
                    local bname = buffDB[b.buff_id] or buffNameCache[b.buff_id]
                    if not bname then
                        local ok2, tt = pcall(function() return api.Ability:GetBuffTooltip(b.buff_id) end)
                        if ok2 and tt and tt.name then bname = tt.name end
                    end
                    buffData[i] = { buff_id = b.buff_id, name = bname or "?", stack = b.stack, timeLeft = b.timeLeft }
                end
            end
            -- Also dump playerInfo spell/magic/damage fields
            local ok, pInfo = pcall(function() return api.Unit:UnitInfo("player") end)
            if ok and pInfo then
                local pDump = {}
                for k, v in pairs(pInfo) do
                    local ks = tostring(k):lower()
                    if string.find(ks, "damage") or string.find(ks, "spell") or string.find(ks, "magic")
                    or string.find(ks, "armor") or string.find(ks, "defense") or string.find(ks, "resist")
                    or string.find(ks, "toughness") or string.find(ks, "battle") then
                        pDump[k] = v
                    end
                end
                buffData["_playerSpellStats"] = pDump
            end
            api.File:Write("CombatLogPro/buff_dump.txt", buffData)
            LogEntry(string.format("[DUMP] %d player buffs + spell stats written to buff_dump.txt", count), 0, 1, 0)
        end

        if CONFIG.DUMP_RHYTHM then
            local rhythmStacks = playerBuffStackCache and playerBuffStackCache["Rhythm"] or 0
            if rhythmStacks ~= rhythmDumpLastStacks then
                rhythmDumpLastStacks = rhythmStacks
                local ok, pInfo = pcall(function() return api.Unit:UnitInfo("player") end)
                if ok and pInfo then
                    local okR, prev = pcall(function() return api.File:Read("CombatLogPro/rhythm_dump.txt") end)
                    local existing = (okR and type(prev) == "table") and prev or {}
                    local entry = { rhythm_stacks = rhythmStacks, stats = {} }
                    for k, v in pairs(pInfo) do entry.stats[tostring(k)] = v end
                    existing[#existing + 1] = entry
                    api.File:Write("CombatLogPro/rhythm_dump.txt", existing)
                    LogEntry(string.format("[DUMP] Rhythm %d stacks captured", rhythmStacks), 0, 1, 1)
                end
            end
        end

    end
    
    if inCombat then
        -- Player death: absolute HP at 0 means dead, from ANY source (hits, DoT, fall,
        -- drown, environmental) -- layout-independent and unambiguous. Log once; the
        -- timeout below is then forced to 0 so the session closes + saves immediately.
        -- Player death via HP poll (backup to UNIT_DEAD). Hardened against the "YOU DIED" spam:
        --   * the latch is the log-dedup -- cleared ONLY when HP recovers (>0), never by FinishFight,
        --     so a corpse still flagged in-combat (DoTs/AoE, or a probe-lagged frame) can't re-fire
        --     the death line every fight-close cycle.
        --   * require an actual number AND HP<=0 on two reads -- a single failed/transient 0 read
        --     while alive must not declare death (mirrors the target-death guard above).
        do
            local okPD, pdh = pcall(function() return api.Unit:UnitHealth("player") end)
            if okPD and type(pdh) == "number" then
                if pdh > 0 then
                    CONFIG._playerDeadLatch = false       -- alive -> re-arm for the next death
                    CONFIG._playerZeroCount = 0
                else
                    CONFIG._playerZeroCount = (CONFIG._playerZeroCount or 0) + 1
                    if CONFIG._playerZeroCount >= 2 and not CONFIG._playerDeadLatch then
                        CONFIG._playerDeadLatch = true
                        CONFIG._playerDied = true
                        CONFIG._gameInCombat = false
                        LogEntry("YOU DIED", 1, 0.2, 0.2, { death = true })
                    end
                end
            end
        end
        timeSinceLastAction = timeSinceLastAction + elapsed
        local currentTimeoutLimit = CONFIG.COMBAT_WAIT
        local tId = api.Unit:GetUnitId("target")
        local targetDead = false

        local okHp, hp = pcall(function() return api.Unit:UnitHealth("target") end)
        -- Only treat as dead when we actually READ a number <= 0. A failed/nil read must
        -- NOT count as death -- that was prematurely shortening the close timeout to 2s
        -- mid-fight (a cause of one fight splitting into several saved sessions).
        if okHp and tId and tId ~= "0" and type(hp) == "number" and hp <= 0 then targetDead = true end

        if not targetDead then CONFIG._targetDeadLogged = false end
        if targetDead then
             -- UNIT_DEAD fires for the player + other PLAYERS, but NOT for mobs (NPCs). So the
             -- HP poll is the only death source for mob kills. Record a DEFERRED pending kill;
             -- the flush below logs it only if UNIT_DEAD hasn't already -- players win via the
             -- real event, mobs (no event) get their death line from the poll, with attribution.
             if not CONFIG._targetDeadLogged and fightData.outgoing[tId] then
                 CONFIG._targetDeadLogged = true
                 local okTN, tn = pcall(function() return api.Unit:UnitName("target") end)
                 local nm = (okTN and tn) or (fightData.outgoing[tId] and fightData.outgoing[tId].name) or "Target"
                 fightData.killedNames = fightData.killedNames or {}; fightData.killedNames[nm] = true
                 local ks, kr = "", CONFIG._lastDmgSrc and CONFIG._lastDmgSrc[tId]
                 if kr and kr ~= "" and kr ~= nm then ks = (kr == PLAYER_NAME) and "  (your kill)" or ("  (killed by " .. kr .. ")") end
                 CONFIG._killGrace = CONFIG._killGrace or {}
                 if not CONFIG._killGrace[tId] then CONFIG._killGrace[tId] = { t = now, ks = ks, name = nm } end
             end
             -- Only shorten timeout if no other active outgoing targets
             local hasOtherTargets = false
             for id, _ in pairs(fightData.outgoing) do
                 if tostring(id) ~= tostring(tId) then hasOtherTargets = true; break end
             end
             currentTimeoutLimit = hasOtherTargets and CONFIG.COMBAT_WAIT or 2000
        elseif tId and activeCCSessions[tId] and (function(t) for _ in pairs(t) do return true end return false end)(activeCCSessions[tId]) then
             currentTimeoutLimit = 10000
             for buffName, startTime in pairs(activeCCSessions[tId]) do
                 if (now - startTime) > 45000 then activeCCSessions[tId][buffName] = nil end
             end
        end

        -- Flush deferred kills: after a short grace, log a pending kill ONLY if UNIT_DEAD didn't
        -- already claim it. Players are logged instantly by UNIT_DEAD (skipped here); mobs (no
        -- UNIT_DEAD) get their death line here. Keyed by UNIT ID so several same-named mobs each
        -- register (the death line still shows the name).
        if CONFIG._killGrace then
            CONFIG._deathLogged = CONFIG._deathLogged or {}
            for id, info in pairs(CONFIG._killGrace) do
                if now - info.t >= 400 then
                    if not CONFIG._deathLogged[id] then
                        CONFIG._deathLogged[id] = true
                        LogEntry((info.name or "?") .. " DIED" .. (info.ks or ""), 1, 0.5, 0.2, { death = true })
                    end
                    CONFIG._killGrace[id] = nil
                end
            end
        end

        -- While the game still reports the player in combat, don't close on the normal
        -- action-gap timeout — long fights have lulls. Only this generous safety net can
        -- close it then (covers a missed "left combat" event). Tunable.
        if CONFIG._gameInCombat then currentTimeoutLimit = math.max(currentTimeoutLimit, 30000) end
        if CONFIG._playerDied then currentTimeoutLimit = 0 end  -- your death ends the fight now

        if timeSinceLastAction >= currentTimeoutLimit then
            FinishFight()
        end
    end

    for key, data in pairs(activeDots) do
        data.timer = (data.timer or 0) + elapsed
        if data.timer >= CONFIG.DOT_WAIT then
            LogEntry(string.format("[Total] %s (%s): %d (%d hits)", data.skill, data.target, data.dmg, data.hits), 1, 0.6, 0)
            activeDots[key] = nil
        end
    end
end

-- ============================================================================
--  OPTIONS WINDOW (UI REDESIGN & CENTERED)
-- ============================================================================

local function CreateOptionsWindow()
    wOptions = api.Interface:CreateEmptyWindow("OpWin", "UIParent")
    wOptions:Show(false); wOptions:SetExtent(380, 1000); wOptions:AddAnchor("CENTER", "UIParent", 0, 0); MakeDraggable(wOptions, wOptions)
    
    CreateBackdrop(wOptions, {0.05, 0.05, 0.05, 0.95})
    
    local opTitleBar = wOptions:CreateChildWidget("emptywidget", "TBar", 0, true)
    opTitleBar:AddAnchor("TOPLEFT", wOptions, 0, 0); opTitleBar:AddAnchor("TOPRIGHT", wOptions, 0, 0); opTitleBar:SetHeight(30)
    CreateBackdrop(opTitleBar, COL_HEADER)
    
    local opTitle = opTitleBar:CreateChildWidget("label", "T", 0, true)
    opTitle:SetText("CLP Configuration"); opTitle:AddAnchor("CENTER", opTitleBar, 0, 0)
    if opTitle.style then opTitle.style:SetFontSize(16) end; MakeDraggable(opTitleBar, wOptions)

    -- Boxed-toggle layout matching the history filter bar; a running Y cursor keeps spacing
    -- consistent (no hardcoded offsets that can collide). Two columns at LX / RX.
    local uid = 0
    local y = 40
    local LX, RX, CW, FULLW = 14, 196, 170, 352
    local function nid() uid = uid + 1; return tostring(uid) end
    local function section(title)
        y = y + 4
        local ln = wOptions:CreateColorDrawable(0.28, 0.28, 0.32, 1, "overlay")
        ln:AddAnchor("TOPLEFT", wOptions, LX, y); ln:SetExtent(FULLW, 1)
        local l = wOptions:CreateChildWidget("label", "sc" .. nid(), 0, true)
        l:SetText(title); l:SetExtent(FULLW, 18); l:AddAnchor("TOPLEFT", wOptions, LX, y + 4)
        if l.style then l.style:SetColor(0.5, 0.8, 1, 1); l.style:SetAlign(ALIGN.LEFT); l.style:SetFontSize(13) end
        y = y + 26
    end
    -- Boxed toggle (green ON / gray OFF). persist -> SaveSettings; after() runs post-toggle. No y advance.
    local function toggle(field, label, x, w, persist, after)
        local b = wOptions:CreateChildWidget("button", "tg" .. nid(), 0, true)
        b:SetExtent(w, 22); b:AddAnchor("TOPLEFT", wOptions, x, y)
        local bg = b:CreateColorDrawable(0, 0, 0, 1, "background")
        bg:AddAnchor("TOPLEFT", b, 0, 0); bg:AddAnchor("BOTTOMRIGHT", b, 0, 0)
        if b.style then b.style:SetAlign(ALIGN.CENTER); b.style:SetFontSize(12) end
        local function refresh()
            if CONFIG[field] ~= false then bg:SetColor(0.15, 0.33, 0.18, 1); b:SetTextColor(0.8, 1, 0.8, 1)
            else bg:SetColor(0.16, 0.16, 0.16, 1); b:SetTextColor(0.55, 0.55, 0.55, 1) end
        end
        b:SetText(label); refresh()
        b:SetHandler("OnClick", function()
            CONFIG[field] = (CONFIG[field] == false)
            refresh(); if after then after() end; if persist then SaveSettings() end
        end)
        return b
    end
    -- [-] value [+] adjuster at (x, y), width w. text()=label; dec()/inc() mutate+persist. No y advance.
    local function adjuster(text, x, w, dec, inc)
        local d = wOptions:CreateChildWidget("button", "ad" .. nid(), 0, true)
        d:SetText("-"); d:SetExtent(24, 22); d:AddAnchor("TOPLEFT", wOptions, x, y)
        local v = wOptions:CreateChildWidget("label", "av" .. nid(), 0, true)
        v:SetText(text()); v:SetExtent(w - 52, 22); v:AddAnchor("LEFT", d, "RIGHT", 2, 0)
        if v.style then v.style:SetAlign(ALIGN.CENTER); v.style:SetFontSize(12) end
        local i = wOptions:CreateChildWidget("button", "ai" .. nid(), 0, true)
        i:SetText("+"); i:SetExtent(24, 22); i:AddAnchor("LEFT", v, "RIGHT", 2, 0)
        d:SetHandler("OnClick", function() dec(); v:SetText(text()) end)
        i:SetHandler("OnClick", function() inc(); v:SetText(text()) end)
    end

    section("Live Window Size")
    adjuster(function() return "W: " .. CONFIG.LIVE_WIDTH end, LX, CW,
        function() CONFIG.LIVE_WIDTH = math.max(300, CONFIG.LIVE_WIDTH - 20); liveLayoutDirty = true; RebuildLiveLabels(); SaveSettings() end,
        function() CONFIG.LIVE_WIDTH = math.min(800, CONFIG.LIVE_WIDTH + 20); liveLayoutDirty = true; RebuildLiveLabels(); SaveSettings() end)
    adjuster(function() return "H: " .. CONFIG.LIVE_HEIGHT end, RX, CW,
        function() CONFIG.LIVE_HEIGHT = math.max(200, CONFIG.LIVE_HEIGHT - 20); liveLayoutDirty = true; RebuildLiveLabels(); SaveSettings() end,
        function() CONFIG.LIVE_HEIGHT = math.min(800, CONFIG.LIVE_HEIGHT + 20); liveLayoutDirty = true; RebuildLiveLabels(); SaveSettings() end)
    y = y + 26

    section("Features")
    toggle("ENABLE_SCANNER", "Scan Debuffs", LX, CW, true)
    toggle("SHOW_TIMESTAMP", "Timestamps", RX, CW, true, function() RebuildLiveLabels(); UpdateHistoryDisplay() end)
    y = y + 26
    toggle("SHOW_ICONS", "Show Icons", LX, CW, true, function() liveLayoutDirty = true; RebuildLiveLabels(); UpdateHistoryDisplay() end)
    y = y + 26
    adjuster(function() return "Offset: " .. CONFIG.TIME_OFFSET .. "h" end, LX, CW,
        function() CONFIG.TIME_OFFSET = CONFIG.TIME_OFFSET - 1; RebuildLiveLabels(); UpdateHistoryDisplay(); SaveSettings() end,
        function() CONFIG.TIME_OFFSET = CONFIG.TIME_OFFSET + 1; RebuildLiveLabels(); UpdateHistoryDisplay(); SaveSettings() end)
    adjuster(function() return "Scan: " .. CONFIG.SCAN_FREQ .. "ms" end, RX, CW,
        function() CONFIG.SCAN_FREQ = math.max(100, CONFIG.SCAN_FREQ - 50); SaveSettings() end,
        function() CONFIG.SCAN_FREQ = math.min(1000, CONFIG.SCAN_FREQ + 50); SaveSettings() end)
    y = y + 26

    -- Recording (floodgates capture control): which OTHER units get recorded. The master gate
    -- LOG_ALLY_RECAP stays on while any class is being recorded.
    section("Recording")
    do
        local rl = wOptions:CreateChildWidget("label", "rl" .. nid(), 0, true)
        rl:SetText("Record:"); rl:SetExtent(52, 22); rl:AddAnchor("TOPLEFT", wOptions, LX, y)
        if rl.style then rl.style:SetAlign(ALIGN.LEFT); rl.style:SetColor(0.7, 0.7, 0.7, 1); rl.style:SetFontSize(12) end
        local recAfter = function() CONFIG.LOG_ALLY_RECAP = (CONFIG.REC_ALLY ~= false) or (CONFIG.REC_ENEMY ~= false) or (CONFIG.REC_MOB ~= false) end
        toggle("REC_ALLY",  "Ally",  72,  80, true, recAfter)
        toggle("REC_ENEMY", "Enemy", 156, 86, true, recAfter)
        toggle("REC_MOB",   "Mob",   246, 86, true, recAfter)
    end
    y = y + 26
    do
        -- Disclaimer under Raid-Log: the addon only receives OTHERS' combat when the client's
        -- "Damage/Heal Info: Target" is Raid or higher (Game Settings > Game Info).
        local function recHint(txt)
            local h = wOptions:CreateChildWidget("label", "recHint" .. nid(), 0, true)
            h:SetText(txt); h:SetExtent(FULLW, 14); h:AddAnchor("TOPLEFT", wOptions, LX, y)
            if h.style then h.style:SetAlign(ALIGN.CENTER); h.style:SetColor(0.62, 0.6, 0.52, 1); h.style:SetFontSize(11) end
            y = y + 13
        end
        recHint("To capture others' combat, raise Damage/Heal Info:")
        recHint("Target to Raid+  (Game Settings > Game Info)")
    end
    y = y + 8

    section("Color Theme")
    local palletWindow = nil
    local swatches = {}
    local DEFAULT_COLORS = {
        COL_OUT_NRM = {1, 0.5, 0}, COL_OUT_CRIT = {1, 0, 0}, COL_INCOMING = {1, 0.5, 0},
        COL_HEAL = {0, 1, 0}, COL_CC = {0.8, 0.3, 1}, COL_ZEAL_CRIT = {1, 0.3, 1}, COL_SKILL_LABEL = {0, 1, 1},
    }
    local function swatchCell(label, key, x)
        local l = wOptions:CreateChildWidget("label", "cl" .. nid(), 0, true)
        l:SetText(label); l:SetExtent(108, 18); l:AddAnchor("TOPLEFT", wOptions, x, y)
        if l.style then l.style:SetAlign(ALIGN.LEFT); l.style:SetFontSize(12) end
        local sw = wOptions:CreateChildWidget("button", "cs" .. nid(), 0, true)
        sw:SetExtent(46, 14); sw:AddAnchor("TOPLEFT", wOptions, x + 112, y + 3)
        local col = CONFIG[key]
        local bg = sw:CreateColorDrawable(col[1], col[2], col[3], 1, "background")
        bg:AddAnchor("TOPLEFT", sw, 0, 0); bg:AddAnchor("BOTTOMRIGHT", sw, 0, 0)
        sw.colorBG = bg; sw.cfgKey = key
        sw:SetHandler("OnClick", function(self)
            if palletWindow then palletWindow:Show(false); palletWindow = nil end
            palletWindow = W_ETC.CreatePopupPallet("clpPallet_" .. key, "UIParent")
            palletWindow:SetUILayer("hud"); palletWindow:SetCloseOnEscape(true)
            palletWindow:RemoveAllAnchors(); palletWindow:Show(true)
            palletWindow:AddAnchor("TOPLEFT", self, "TOPRIGHT", 2, 0)
            palletWindow:SetSelectEventListenWidget(self)
            palletWindow:EnableHidingIsRemove(true)
            palletWindow:SetHandler("OnHide", function() palletWindow = nil end)
        end)
        function sw:SelectedProcedure(r, g, b, a)
            self.colorBG:SetColor(r, g, b, 1); CONFIG[self.cfgKey] = {r, g, b}; SaveSettings()
        end
        swatches[#swatches + 1] = sw
    end
    swatchCell("Outgoing Dmg", "COL_OUT_NRM",     LX); swatchCell("Critical Hits", "COL_OUT_CRIT",  RX); y = y + 24
    swatchCell("Incoming Dmg", "COL_INCOMING",    LX); swatchCell("Healing",       "COL_HEAL",      RX); y = y + 24
    swatchCell("CC Effects",   "COL_CC",          LX); swatchCell("Zeal Crit",     "COL_ZEAL_CRIT", RX); y = y + 24
    swatchCell("Skill Labels", "COL_SKILL_LABEL", LX); y = y + 26

    do
        local bf = wOptions:CreateChildWidget("button", "bf" .. nid(), 0, true)
        bf:SetExtent(CW, 22); bf:AddAnchor("TOP", wOptions, 0, y)
        local bg = bf:CreateColorDrawable(0.18, 0.18, 0.24, 1, "background")
        bg:AddAnchor("TOPLEFT", bf, 0, 0); bg:AddAnchor("BOTTOMRIGHT", bf, 0, 0)
        bf:SetText("Manage Filters..."); if bf.style then bf.style:SetAlign(ALIGN.CENTER); bf.style:SetFontSize(12) end
        bf:SetTextColor(0.7, 0.85, 1, 1)
        bf:SetHandler("OnClick", function() if CONFIG._openFilters then CONFIG._openFilters() end end)
    end
    y = y + 26

    -- Size the window to the content + room for the two bottom buttons.
    wOptions:SetHeight(y + 84)

    local btnClose = wOptions:CreateChildWidget("button", "Close", 0, true)
    btnClose:SetExtent(150, 26); btnClose:AddAnchor("BOTTOM", wOptions, 0, -14)
    do local bg = btnClose:CreateColorDrawable(0.16, 0.3, 0.46, 1, "background"); bg:AddAnchor("TOPLEFT", btnClose, 0, 0); bg:AddAnchor("BOTTOMRIGHT", btnClose, 0, 0) end
    btnClose:SetText("Done"); if btnClose.style then btnClose.style:SetAlign(ALIGN.CENTER) end
    btnClose:SetHandler("OnClick", function() wOptions:Show(false) end)

    local btnRestore = wOptions:CreateChildWidget("button", "RestoreColors", 0, true)
    btnRestore:SetExtent(200, 22); btnRestore:AddAnchor("BOTTOM", btnClose, "TOP", 0, -8)
    btnRestore:SetText("Restore Default Colors"); if btnRestore.style then btnRestore.style:SetAlign(ALIGN.CENTER); btnRestore.style:SetFontSize(12) end
    btnRestore:SetTextColor(0.85, 0.72, 0.5, 1)
    btnRestore:SetHandler("OnClick", function()
        for _, sw in ipairs(swatches) do
            local d = DEFAULT_COLORS[sw.cfgKey]
            if d then CONFIG[sw.cfgKey] = {d[1], d[2], d[3]}; sw.colorBG:SetColor(d[1], d[2], d[3], 1) end
        end
        SaveSettings()
    end)
end

-- In-game Filter Manager: type a skill/buff name + Add to hide it from the log,
-- click X next to an entry to un-hide it. Custom filters persist in settings.txt and
-- merge straight into IGNORE_LOOKUP (the path IsIgnoredBuff checks: scanner + combat
-- lines). Stored entirely on CONFIG/closures -- adds ZERO main-chunk locals, so it
-- stays within Lua 5.1's 200-locals-per-function limit. Window is built once, lazily.
CONFIG._openFilters = function()
    CONFIG._customFilters = CONFIG._customFilters or {}   -- safety: should be set by LoadSavedSettings
    if not CONFIG._wFilters then
        local VIS = 12
        local win = api.Interface:CreateEmptyWindow("ClpFilters", "UIParent")
        CONFIG._wFilters = win
        win:Show(false); win:SetExtent(340, 480); win:AddAnchor("CENTER", "UIParent", 0, 0)
        MakeDraggable(win, win)
        CreateBackdrop(win, {0.05, 0.05, 0.05, 0.96})

        local tbar = win:CreateChildWidget("emptywidget", "fTBar", 0, true)
        tbar:AddAnchor("TOPLEFT", win, 0, 0); tbar:AddAnchor("TOPRIGHT", win, 0, 0); tbar:SetHeight(30)
        CreateBackdrop(tbar, COL_HEADER)
        local title = win:CreateChildWidget("label", "fTitle", 0, true)
        title:SetText("Skill / Buff Filters"); title:SetExtent(260, 26); title:AddAnchor("LEFT", tbar, 12, 0)
        if title.style then title.style:SetFontSize(16); title.style:SetAlign(ALIGN.LEFT) end
        MakeDraggable(tbar, win)
        MakeDraggable(title, win)   -- the title label covers most of the bar; make it a drag handle too

        -- Dark button style matching the rest of the addon (Options / live feed) -- replaces the
        -- game's tan ApplyButtonSkin so this window is uniform. Local, so no main-chunk local.
        local function skin(btn)
            local d = btn:CreateColorDrawable(0.18, 0.18, 0.23, 1, "background")
            d:AddAnchor("TOPLEFT", btn, 0, 0); d:AddAnchor("BOTTOMRIGHT", btn, 0, 0)
            if btn.style then btn.style:SetAlign(ALIGN.CENTER); btn.style:SetFontSize(12) end
            btn:SetTextColor(0.82, 0.88, 1, 1)
            return true
        end

        -- Add row: typable field + Add button
        local edit = W_CTRL.CreateEdit("clpFilterEdit", win)
        edit:SetExtent(208, 24); edit:AddAnchor("TOPLEFT", win, 14, 44)

        local addBtn = win:CreateChildWidget("button", "fAdd", 0, true)
        skin(addBtn)
        addBtn:SetExtent(72, 26); addBtn:AddAnchor("LEFT", edit, "RIGHT", 8, 0); addBtn:SetText("Add")

        local hint = win:CreateChildWidget("label", "fHint", 0, true)
        hint:SetText("Type a skill/buff name, then Add. Hidden everywhere in the log.")
        hint:AddAnchor("TOPLEFT", win, 14, 72); hint:SetExtent(312, 16)
        if hint.style then hint.style:SetAlign(ALIGN.LEFT); hint.style:SetColor(0.5, 0.5, 0.5, 1); hint.style:SetFontSize(11) end

        local listHdr = win:CreateChildWidget("label", "fListHdr", 0, true)
        listHdr:SetText("Filtered:"); listHdr:SetExtent(180, 20); listHdr:AddAnchor("TOPLEFT", win, 14, 94)
        if listHdr.style then listHdr.style:SetColor(0.5, 0.8, 1, 1); listHdr.style:SetAlign(ALIGN.LEFT) end

        -- Show Defaults toggle: reveals the built-in filters (gray) so they can be removed too.
        local toggleDef = win:CreateChildWidget("button", "fShowDef", 0, true)
        skin(toggleDef)
        toggleDef:SetExtent(118, 22); toggleDef:AddAnchor("TOPRIGHT", win, -14, 92)
        local function refreshToggle()
            toggleDef:SetText(CONFIG._showDefaults and "Defaults: ON" or "Defaults: OFF")
        end
        refreshToggle()
        toggleDef:SetHandler("OnClick", function()
            CONFIG._showDefaults = not CONFIG._showDefaults
            CONFIG._filterScroll = 0
            refreshToggle()
            SaveSettings()
            if CONFIG._renderFilters then CONFIG._renderFilters() end
        end)

        -- Scrollable list body
        local body = win:CreateChildWidget("emptywidget", "fBody", 0, true)
        body:AddAnchor("TOPLEFT", win, 10, 116); body:AddAnchor("BOTTOMRIGHT", win, -10, -46)
        CreateBackdrop(body, {0.10, 0.10, 0.10, 0.9})
        body:SetHandler("OnMouseWheel", function(_, d)
            CONFIG._filterScroll = (CONFIG._filterScroll or 0) - d
            if CONFIG._renderFilters then CONFIG._renderFilters() end
        end)

        -- Row pool: name label + red X remove button
        local rows = {}
        for i = 1, VIS do
            local row = body:CreateChildWidget("emptywidget", "fRow"..i, 0, true)
            row:SetExtent(300, 24); row:AddAnchor("TOPLEFT", body, 6, 6 + ((i-1) * 26))

            local lbl = body:CreateChildWidget("label", "fRowL"..i, 0, true)
            lbl:AddAnchor("LEFT", row, 4, 0); lbl:SetExtent(252, 24)
            if lbl.style then lbl.style:SetAlign(ALIGN.LEFT) end
            row.lbl = lbl

            local x = body:CreateChildWidget("button", "fRowX"..i, 0, true)
            skin(x)
            x:SetExtent(22, 22); x:AddAnchor("RIGHT", row, "RIGHT", 0, 0)
            x:SetText("-"); x:SetTextColor(1, 0.45, 0.45, 1)
            x:SetHandler("OnClick", function()
                local name = row.filterName
                if name then
                    local ln = string.lower(name)
                    if row.isDefault then
                        IGNORE_LOOKUP[ln] = false        -- disable a built-in default (persists, survives updates)
                    else
                        IGNORE_LOOKUP[ln] = nil           -- remove a custom filter
                        local list = CONFIG._customFilters
                        for idx = #list, 1, -1 do
                            if string.lower(list[idx]) == ln then table.remove(list, idx) end
                        end
                    end
                    for k in pairs(isIgnoredCache) do isIgnoredCache[k] = nil end
                    SaveSettings()
                    if CONFIG._renderFilters then CONFIG._renderFilters() end
                end
            end)
            row.x = x
            rows[i] = row
        end

        local doneBtn = win:CreateChildWidget("button", "fDone", 0, true)
        skin(doneBtn)
        doneBtn:SetExtent(110, 26); doneBtn:AddAnchor("BOTTOM", win, 0, -12); doneBtn:SetText("Done")
        doneBtn:SetHandler("OnClick", function() win:Show(false) end)

        -- Scroll buttons -- addon UIs don't receive mousewheel, so the (long) defaults list
        -- needs these. Each click pages by VIS rows; the render clamps the offset.
        local function scrollBy(delta)
            CONFIG._filterScroll = (CONFIG._filterScroll or 0) + delta
            if CONFIG._renderFilters then CONFIG._renderFilters() end
        end
        local upBtn = win:CreateChildWidget("button", "fUp", 0, true)
        skin(upBtn)
        upBtn:SetExtent(44, 24); upBtn:AddAnchor("BOTTOMLEFT", win, 12, -13); upBtn:SetText("^")
        upBtn:SetHandler("OnClick", function() scrollBy(-VIS) end)
        local downBtn = win:CreateChildWidget("button", "fDn", 0, true)
        skin(downBtn)
        downBtn:SetExtent(44, 24); downBtn:AddAnchor("LEFT", upBtn, "RIGHT", 6, 0); downBtn:SetText("v")
        downBtn:SetHandler("OnClick", function() scrollBy(VIS) end)

        local function doAdd()
            local name = tostring(edit:GetText() or ""):gsub("^%s*(.-)%s*$", "%1")  -- trim
            local ln = string.lower(name)
            if name ~= "" and not IGNORE_LOOKUP[ln] then  -- skip blanks / already-filtered / dup
                IGNORE_LOOKUP[ln] = true
                local list = CONFIG._customFilters
                list[#list + 1] = name
                for k in pairs(isIgnoredCache) do isIgnoredCache[k] = nil end
                SaveSettings()
                edit:SetText(""); CONFIG._filterScroll = 0
            end
            if CONFIG._renderFilters then CONFIG._renderFilters() end
        end
        addBtn:SetHandler("OnClick", doAdd)

        CONFIG._renderFilters = function()
            -- Visible list: your custom filters (white) first, then -- if "Show Defaults" is
            -- on -- the still-active built-in defaults (gray). Disabled defaults are skipped.
            local items = {}
            local cf = {}
            for _, n in ipairs(CONFIG._customFilters) do cf[#cf + 1] = n end
            table.sort(cf, function(a, b) return string.lower(a) < string.lower(b) end)
            for _, n in ipairs(cf) do items[#items + 1] = { name = n, def = false } end
            local nCustom, nDef = #cf, 0
            if CONFIG._showDefaults then
                local df = {}
                for _, n in ipairs(IGNORE_BUFFS_RAW) do
                    if IGNORE_LOOKUP[string.lower(n)] ~= false then df[#df + 1] = n end  -- skip disabled
                end
                table.sort(df, function(a, b) return string.lower(a) < string.lower(b) end)
                for _, n in ipairs(df) do items[#items + 1] = { name = n, def = true } end
                nDef = #df
            end

            local total = #items
            local maxScroll = total - VIS
            if maxScroll < 0 then maxScroll = 0 end
            local off = CONFIG._filterScroll or 0
            if off > maxScroll then off = maxScroll end
            if off < 0 then off = 0 end
            CONFIG._filterScroll = off

            if CONFIG._showDefaults then
                listHdr:SetText("Yours: " .. nCustom .. "   Defaults: " .. nDef)
            else
                listHdr:SetText("Filtered: " .. nCustom)
            end
            for i = 1, VIS do
                local row, it = rows[i], items[i + off]
                if it then
                    row.filterName = it.name; row.isDefault = it.def
                    row.lbl:SetText(it.name)
                    if row.lbl.style then
                        if it.def then row.lbl.style:SetColor(0.5, 0.5, 0.5, 1)
                        else row.lbl.style:SetColor(0.95, 0.95, 0.95, 1) end
                    end
                    row:Show(true); row.lbl:Show(true); row.x:Show(true)
                else
                    row.filterName = nil; row.isDefault = nil
                    row:Show(false); row.lbl:Show(false); row.x:Show(false)
                end
            end
        end
    end
    CONFIG._wFilters:Show(true)
    if CONFIG._renderFilters then CONFIG._renderFilters() end
end

-- In-game icon picker. Opened by clicking a recap icon (which stamps the skill). Shows a
-- searchable, scrollable grid of every icon in all_icons.lua; picking one writes the override
-- to icon_overrides.txt (the file testers send back), clears the icon cache, and refreshes.
-- Everything on CONFIG/closures -- no new main-chunk local (we're at the 200 cap).
CONFIG._openIconPicker = function(skill)
    if skill then CONFIG._iconEditSkill = skill end
    if not CONFIG._allIcons then
        local ok, t = pcall(require, "/CombatLogPro/all_icons")
        CONFIG._allIcons = (ok and type(t) == "table") and t or {}
    end
    if not CONFIG._iconPickerWin then
        local COLS, ROWS, CELL = 6, 8, 42
        local W = COLS * CELL + 28
        local win = api.Interface:CreateEmptyWindow("ClpIconPicker", "UIParent")
        CONFIG._iconPickerWin = win
        win:Show(false); win:SetExtent(W, ROWS * CELL + 124); win:AddAnchor("CENTER", "UIParent", 0, 0)
        MakeDraggable(win, win); CreateBackdrop(win, {0.05, 0.05, 0.05, 0.97})

        local tbar = win:CreateChildWidget("emptywidget", "ipTBar", 0, true)
        tbar:AddAnchor("TOPLEFT", win, 0, 0); tbar:AddAnchor("TOPRIGHT", win, 0, 0); tbar:SetHeight(30)
        CreateBackdrop(tbar, COL_HEADER)
        local title = win:CreateChildWidget("label", "ipTitle", 0, true)
        title:SetText("Pick Icon"); title:SetExtent(W - 24, 26); title:AddAnchor("LEFT", tbar, 12, 0)
        if title.style then title.style:SetFontSize(15); title.style:SetAlign(ALIGN.LEFT) end
        MakeDraggable(tbar, win)

        local sub = win:CreateChildWidget("label", "ipSub", 0, true)
        sub:SetExtent(W - 24, 16); sub:AddAnchor("TOPLEFT", win, 14, 34)
        if sub.style then sub.style:SetAlign(ALIGN.LEFT); sub.style:SetColor(0.5, 0.85, 1, 1); sub.style:SetFontSize(11) end

        local edit = W_CTRL.CreateEdit("clpIconSearch", win)
        edit:SetExtent(W - 90, 22); edit:AddAnchor("TOPLEFT", win, 14, 54)
        edit:SetHandler("OnTextChanged", function(self)
            CONFIG._iconFilter = string.lower(tostring(self:GetText() or ""))
            CONFIG._iconScroll = 0
            if CONFIG._renderIconPicker then CONFIG._renderIconPicker() end
        end)
        local shint = win:CreateChildWidget("label", "ipHint", 0, true)
        shint:SetText("search"); shint:AddAnchor("LEFT", edit, "RIGHT", 6, 0); shint:SetExtent(60, 22)
        if shint.style then shint.style:SetColor(0.4, 0.4, 0.4, 1) end

        local body = win:CreateChildWidget("emptywidget", "ipBody", 0, true)
        body:AddAnchor("TOPLEFT", win, 14, 84); body:SetExtent(COLS * CELL, ROWS * CELL)
        local cells = {}
        for r = 0, ROWS - 1 do for c = 0, COLS - 1 do
            local b = ClpMakeIcon(body, CELL - 4)
            if b then
                b:AddAnchor("TOPLEFT", body, c * CELL, r * CELL); b:Show(false)
                pcall(function() b:SetHandler("OnClick", function(self)
                    if self.iconName and CONFIG._iconEditSkill then
                        CONFIG._iconOverrides = CONFIG._iconOverrides or {}
                        CONFIG._iconOverrides[CONFIG._iconEditSkill] = self.iconName
                        pcall(function() api.File:Write("CombatLogPro/icon_overrides.txt", CONFIG._iconOverrides) end)
                        for k in pairs(iconPathCache) do iconPathCache[k] = nil end
                        win:Show(false); UpdateHistoryDisplay(); UpdateSessionList()
                    end
                end) end)
                cells[#cells + 1] = b
            end
        end end

        local function scroll(d) CONFIG._iconScroll = (CONFIG._iconScroll or 0) + d; if CONFIG._renderIconPicker then CONFIG._renderIconPicker() end end
        local up = win:CreateChildWidget("button", "ipUp", 0, true); up:SetText("^"); up:SetExtent(40, 24); up:AddAnchor("BOTTOMLEFT", win, 12, -12); up:SetHandler("OnClick", function() scroll(-ROWS) end)
        local dn = win:CreateChildWidget("button", "ipDn", 0, true); dn:SetText("v"); dn:SetExtent(40, 24); dn:AddAnchor("LEFT", up, "RIGHT", 6, 0); dn:SetHandler("OnClick", function() scroll(ROWS) end)
        local clr = win:CreateChildWidget("button", "ipClr", 0, true); clr:SetText("Clear"); clr:SetExtent(56, 24); clr:AddAnchor("LEFT", dn, "RIGHT", 8, 0)
        clr:SetHandler("OnClick", function()
            if CONFIG._iconEditSkill and CONFIG._iconOverrides then
                CONFIG._iconOverrides[CONFIG._iconEditSkill] = nil
                pcall(function() api.File:Write("CombatLogPro/icon_overrides.txt", CONFIG._iconOverrides) end)
                for k in pairs(iconPathCache) do iconPathCache[k] = nil end
                win:Show(false); UpdateHistoryDisplay(); UpdateSessionList()
            end
        end)
        local done = win:CreateChildWidget("button", "ipDone", 0, true); done:SetText("Done"); done:SetExtent(64, 24); done:AddAnchor("BOTTOMRIGHT", win, -12, -12); done:SetHandler("OnClick", function() win:Show(false) end)

        CONFIG._renderIconPicker = function()
            local flt = CONFIG._iconFilter or ""
            local list = {}
            for _, nm in ipairs(CONFIG._allIcons) do
                if flt == "" or string.find(nm, flt, 1, true) then list[#list + 1] = nm end
            end
            local total = #list
            local maxScroll = math.ceil(total / COLS) - ROWS
            if maxScroll < 0 then maxScroll = 0 end
            local off = CONFIG._iconScroll or 0
            if off > maxScroll then off = maxScroll end
            if off < 0 then off = 0 end
            CONFIG._iconScroll = off
            local forName = ({ ["__mob__"] = "all mobs", ["__player__"] = "all players", ["__mount__"] = "all mounts", ["__death__"] = "session-death marker" })[CONFIG._iconEditSkill] or tostring(CONFIG._iconEditSkill or "?")
            sub:SetText("for: " .. forName .. "   (" .. total .. " icons)")
            local startIdx = off * COLS
            for ci = 1, #cells do
                local nm = list[startIdx + ci]
                local b = cells[ci]
                if nm then b.iconName = nm; ClpSetIcon(b, "Game\\ui\\icon\\" .. nm .. ".dds")
                else b.iconName = nil; b:Show(false) end
            end
        end
    end
    CONFIG._iconPickerWin:Show(true); CONFIG._iconPickerWin:Raise()
    if CONFIG._renderIconPicker then CONFIG._renderIconPicker() end
end

-- Builds the history window. File-scope (not inside Load) so its many widget
-- references are CreateHistoryWindow's upvalues, not Load's — keeps Load well
-- under Lua's 60-upvalue limit. Sidebar drills: names -> that name's sessions.
local function CreateHistoryWindow()
    wHistory = api.Interface:CreateEmptyWindow("HistWin", "UIParent")
    wHistory:Show(false)
    wHistory:SetExtent(CONFIG.HIST_WIDTH, CONFIG.HIST_HEIGHT)
    if savedSettings.histX then
        wHistory:AddAnchor("TOPLEFT", "UIParent", savedSettings.histX, savedSettings.histY)
    else
        wHistory:AddAnchor("CENTER", "UIParent", 0, 0)
    end

    local histHeader = wHistory:CreateChildWidget("emptywidget", "hHeader", 0, true)
    histHeader:AddAnchor("TOPLEFT", wHistory, 0, 0)
    histHeader:AddAnchor("TOPRIGHT", wHistory, 0, 0)
    histHeader:SetHeight(30)
    CreateBackdrop(histHeader, COL_HEADER)
    MakeDraggable(histHeader, wHistory, SaveSettings)

    -- Title (left)
    local histTitle = histHeader:CreateChildWidget("label", "hTitle", 0, true)
    histTitle:SetText("Session History")
    histTitle:AddAnchor("LEFT", histHeader, 12, 0)
    histTitle:SetExtent(140, 30)
    if histTitle.style then histTitle.style:SetFontSize(15); histTitle.style:SetAlign(ALIGN.LEFT) end
    MakeDraggable(histTitle, wHistory, SaveSettings)

    -- Action buttons (right): Close, then Options to its left
    local btnClose = histHeader:CreateChildWidget("button", "close", 0, true)
    btnClose:AddAnchor("RIGHT", histHeader, -5, 0)
    btnClose:SetExtent(28, 24)
    btnClose:SetText("X")
    btnClose:SetHandler("OnClick", function() wHistory:Show(false); if CONFIG._refreshHistBtn then CONFIG._refreshHistBtn() end end)

    local btnHistOpt = histHeader:CreateChildWidget("button", "hOpt", 0, true)
    btnHistOpt:AddAnchor("RIGHT", btnClose, "LEFT", -6, 0)
    btnHistOpt:SetExtent(60, 24)
    btnHistOpt:SetText("Options")
    btnHistOpt:SetHandler("OnClick", function() if not wOptions then CreateOptionsWindow() end; wOptions:Show(not wOptions:IsVisible()) end)

    -- Name search/filter box (guarded; filters the names list)
    if W_CTRL and W_CTRL.CreateEdit then
        local searchBox = W_CTRL.CreateEdit("clpSessSearch", histHeader)
        searchBox:SetExtent(180, 20)
        searchBox:AddAnchor("LEFT", histTitle, "RIGHT", 8, 0)
        searchBox:SetHandler("OnTextChanged", function(self)
            sessionFilter = tostring(self:GetText() or "")
            -- Name search = find a PERSON across ALL fights. Drop into the Overall scope and list its
            -- contributors filtered by the typed text (clicking one VIEWS that unit's combat across
            -- every fight). Clearing the box pops back to the fights list.
            if sessionFilter ~= "" then
                selectedGroup = (sessionGroups[1] and sessionGroups[1].isOverall) and sessionGroups[1] or selectedGroup
                sidebarMode = "SESSIONS"
            else
                selectedGroup = nil
                sidebarMode = "NAMES"
            end
            UpdateSessionList()
        end)
        local searchHint = histHeader:CreateChildWidget("label", "clpSearchHint", 0, true)
        searchHint:SetText("filter by name")
        searchHint:AddAnchor("LEFT", searchBox, "RIGHT", 8, 0)
        searchHint:SetExtent(120, 30)
        if searchHint.style then searchHint.style:SetAlign(ALIGN.LEFT); searchHint.style:SetColor(0.4, 0.4, 0.4, 1) end
    end

    -- Category filter bar across the top (below the header). Toggling a chip filters the names
    -- list (a name shows only if it holds data in an enabled category) and the feed. Persisted.
    local catBar = wHistory:CreateChildWidget("emptywidget", "hCatBar", 0, true)
    catBar:AddAnchor("TOPLEFT", histHeader, "BOTTOMLEFT", 0, 0)
    catBar:AddAnchor("TOPRIGHT", histHeader, "BOTTOMRIGHT", 0, 0)
    catBar:SetHeight(28)
    CreateBackdrop(catBar, {0.11, 0.11, 0.11, 1})
    do
        -- WHO x WHAT x DIR filter. Each toggle flips a CONFIG.F_* bool, re-filters the open stream,
        -- and refreshes the sidebar list. (mkTog/mkLabel are local to this block -> no main-chunk local.)
        local function mkTog(field, label, x, w)
            local tb = catBar:CreateChildWidget("button", "ftog_" .. field, 0, true)
            tb:SetExtent(w, 20); tb:AddAnchor("LEFT", catBar, x, 0)
            local bg = tb:CreateColorDrawable(0, 0, 0, 1, "background")
            bg:AddAnchor("TOPLEFT", tb, 0, 0); bg:AddAnchor("BOTTOMRIGHT", tb, 0, 0)
            tb:SetText(label)
            if tb.style then tb.style:SetAlign(ALIGN.CENTER); tb.style:SetFontSize(12) end
            local function refresh()
                if CONFIG[field] ~= false then bg:SetColor(0.15, 0.33, 0.18, 1); tb:SetTextColor(0.8, 1, 0.8, 1)
                else bg:SetColor(0.16, 0.16, 0.16, 1); tb:SetTextColor(0.5, 0.5, 0.5, 1) end
            end
            refresh()
            tb:SetHandler("OnClick", function()
                CONFIG[field] = not CONFIG[field]
                refresh(); SaveSettings(); UpdateSessionList()
                if CONFIG._viewingOverall and CONFIG._buildOverall then
                    viewingMode = "ARCHIVE"
                    displayBuffer = ExpandArchive(CONFIG._buildView(CONFIG._viewingOverall))
                    logScrollOffset = math.max(0, #displayBuffer - CONFIG.VISIBLE_ROWS_HIST)
                    UpdateHistoryDisplay()
                end
            end)
        end
        local function mkLabel(text, x, w)
            local l = catBar:CreateChildWidget("label", "flbl_" .. (string.gsub(text, "%W", "")), 0, true)
            l:SetText(text); l:SetExtent(w, 28); l:AddAnchor("LEFT", catBar, x, 0)
            if l.style then l.style:SetAlign(ALIGN.LEFT); l.style:SetColor(0.6, 0.6, 0.6, 1); l.style:SetFontSize(12) end
        end
        -- Leading title so it's obvious what this bar is for.
        local fTitle = catBar:CreateChildWidget("label", "flblTitle", 0, true)
        fTitle:SetText("Combat Filters"); fTitle:SetExtent(104, 28); fTitle:AddAnchor("LEFT", catBar, 8, 0)
        if fTitle.style then fTitle.style:SetAlign(ALIGN.LEFT); fTitle.style:SetColor(0.55, 0.8, 1, 1); fTitle.style:SetFontSize(13) end
        mkLabel("WHO:",  120, 34)
        mkTog("F_WHO_ME",    "Me",    156, 46)
        mkTog("F_WHO_ALLY",  "Ally",  204, 48)
        mkTog("F_WHO_ENEMY", "Enemy", 254, 58)
        mkTog("F_WHO_MOB",   "Mob",   314, 46)
        mkLabel("TYPE:", 372, 40)
        mkTog("F_WHAT_DMG",  "Damage",  414, 66)
        mkTog("F_WHAT_HEAL", "Healing", 482, 66)
        mkLabel("DIRECTION:", 560, 76)
        mkTog("F_DIR_DEALT", "Dealt", 638, 54)
        mkTog("F_DIR_TAKEN", "Taken", 694, 54)
    end

    local histSidebar = wHistory:CreateChildWidget("emptywidget", "hSide", 0, true)
    histSidebar:AddAnchor("TOPLEFT", catBar, "BOTTOMLEFT", 0, 0)
    histSidebar:SetExtent(CONFIG.SIDEBAR_WIDTH, CONFIG.HIST_HEIGHT - 58)
    CreateBackdrop(histSidebar, COL_SIDEBAR)
    histSidebar:EnableDrag(true)
    histSidebar:SetHandler("OnMouseWheel", function(self, d) ScrollSession(d) end)

    lblSessionCount = histSidebar:CreateChildWidget("label", "lblCount", 0, true)
    lblSessionCount:SetText("Saved: 0")
    -- Anchored to the right of the Back button so long names don't overlap it
    lblSessionCount:AddAnchor("TOPLEFT", histSidebar, 64, 6)
    lblSessionCount:SetExtent(CONFIG.SIDEBAR_WIDTH - 72, 20)
    if lblSessionCount.style then lblSessionCount.style:SetAlign(ALIGN.CENTER); lblSessionCount.style:SetColor(0.6, 0.6, 0.6, 1) end

    -- Back button (top-left of sidebar), shown only when viewing one name's sessions
    sidebarBackBtn = histSidebar:CreateChildWidget("button", "sBack", 0, true)
    sidebarBackBtn:AddAnchor("TOPLEFT", histSidebar, 5, 4)
    sidebarBackBtn:SetExtent(54, 20)
    sidebarBackBtn:SetText("< Back")
    sidebarBackBtn:SetHandler("OnClick", function()
        if selectedContributor then
            selectedContributor = nil          -- Level 3 -> Level 2
        else
            sidebarMode = "NAMES"; selectedGroup = nil   -- Level 2 -> Level 1
        end
        sessionScrollOffset = 0
        UpdateSessionList()
    end)
    sidebarBackBtn:Show(false)

    local btnLive = histSidebar:CreateChildWidget("button", "btnLive", 0, true)
    btnLive:AddAnchor("TOP", histSidebar, 0, 30)
    btnLive:SetExtent(CONFIG.BUTTON_WIDTH, 28)
    local lbg = btnLive:CreateColorDrawable(0.20, 0.20, 0.20, 1, "background")
    lbg:AddAnchor("TOPLEFT", btnLive, 0, 1)
    lbg:AddAnchor("BOTTOMRIGHT", btnLive, 0, -1)
    btnLive:SetText("Live Log")
    btnLive:SetTextColor(0.6, 1, 0.6, 1)
    btnLive:SetHandler("OnClick", function() viewingMode = "LIVE"; CONFIG._viewingOverall = nil; displayBuffer = {}; for _,v in ipairs(masterBuffer) do table.insert(displayBuffer, v) end; logScrollOffset = #displayBuffer - CONFIG.VISIBLE_ROWS_HIST; if logScrollOffset < 0 then logScrollOffset = 0 end; UpdateHistoryDisplay() end)

    for i = 1, CONFIG.SESSIONS_VISIBLE do
        local btn = histSidebar:CreateChildWidget("button", "SessBtn"..i, 0, true)
        btn:SetExtent(CONFIG.BUTTON_WIDTH, 24)
        btn:AddAnchor("TOP", histSidebar, 0, 70 + ((i-1)*26))
        -- Subtle raised backdrop so each entry reads as a button/tab
        local sbg = btn:CreateColorDrawable(0.17, 0.17, 0.17, 1, "background")
        sbg:AddAnchor("TOPLEFT", btn, 0, 1)
        sbg:AddAnchor("BOTTOMRIGHT", btn, 0, -1)
        if btn.style then btn.style:SetAlign(ALIGN.LEFT) end
        -- NOTE: these icons are parented to the SIDEBAR (an emptywidget), not the button --
        -- a clickable icon nested inside a button never receives its own OnClick (the button
        -- eats the click). Anchored onto the button so they still track its row.
        -- Icons sit in the sidebar's side MARGINS (the button is 180 wide in a 230 sidebar, so
        -- ~25px of clear space each side), NOT over the button -- an icon overlapping a button
        -- never receives its own click. Parented to the sidebar (emptywidget), anchored to the
        -- button edges so they track each row.
        btn.clpIcon = ClpMakeIcon(histSidebar, 22)  -- match the skull marker (clpMarkIcon, 22)
        if btn.clpIcon then
            btn.clpIcon:AddAnchor("LEFT", btn, 4, 0); btn.clpIcon:Show(false)  -- inside the box's left edge
            -- Clicking a name icon (mobs only -- key set during render) opens the picker.
            pcall(function() btn.clpIcon:SetHandler("OnClick", function()
                if btn.clpIconKey and CONFIG._openIconPicker then CONFIG._openIconPicker(btn.clpIconKey) end
            end) end)
        end
        -- KILL/DIED marker icon, INSIDE the button at the right end (clear of the scroll buttons
        -- in the right margin). Display-only there -- the button captures the click, so clicking
        -- this row (marker included) drills into the session. The kill/death icons are assignable
        -- from Options instead.
        btn.clpMarkIcon = ClpMakeIcon(histSidebar, 22)
        if btn.clpMarkIcon then
            btn.clpMarkIcon:AddAnchor("RIGHT", btn, -4, 0); btn.clpMarkIcon:Show(false)
        end
        -- Fight-row sub-labels (children of the button, so they ride its z-order; no clicks needed):
        -- bright duration (left), faint time (right), death count just left of the skull so "N [skull]"
        -- reads as "N deaths". Hidden except on fight rows.
        btn.durLabel = btn:CreateChildWidget("label", "sdur" .. i, 0, true)
        btn.durLabel:SetExtent(70, 24); btn.durLabel:AddAnchor("LEFT", btn, 30, 0)
        if btn.durLabel.style then btn.durLabel.style:SetAlign(ALIGN.LEFT) end
        btn.durLabel:Show(false)
        btn.timeLabel = btn:CreateChildWidget("label", "stime" .. i, 0, true)
        btn.timeLabel:SetExtent(40, 24); btn.timeLabel:AddAnchor("RIGHT", btn, -54, 0)
        if btn.timeLabel.style then btn.timeLabel.style:SetAlign(ALIGN.RIGHT); btn.timeLabel.style:SetFontSize(11); btn.timeLabel.style:SetColor(0.45, 0.45, 0.45, 1) end
        btn.timeLabel:Show(false)
        btn.deathLabel = btn:CreateChildWidget("label", "sdth" .. i, 0, true)
        btn.deathLabel:SetExtent(22, 24); btn.deathLabel:AddAnchor("RIGHT", btn, -28, 0)
        if btn.deathLabel.style then btn.deathLabel.style:SetAlign(ALIGN.RIGHT); btn.deathLabel.style:SetFontSize(12) end
        btn.deathLabel:Show(false)
        -- Up to 3 skillset (class) icons from the game HUD atlas (same method as the
        -- role_identifier addon). Shown instead of the single role glyph when we know the
        -- player's build. TEXTURE_PATH is a game global; guarded so absence is harmless.
        btn.clpSkill = {}
        if TEXTURE_PATH and TEXTURE_PATH.HUD then
            for j = 1, 3 do
                local ok, d = pcall(function() return btn:CreateImageDrawable(TEXTURE_PATH.HUD, "overlay") end)
                if ok and d then
                    d:SetExtent(13, 13); d:AddAnchor("LEFT", btn, 3 + (j - 1) * 14, 0)
                    pcall(function() d:SetSRGB(false) end)
                    d:SetVisible(false)
                    btn.clpSkill[j] = d
                end
            end
        end
        btn:SetText("")
        btn:Show(false)
        btn:SetHandler("OnClick", function(self)
            if self.drillContributor then
                -- Level 2 -> Level 3: drill into a multi-instance contributor's same-named units.
                selectedContributor = self.drillContributor
                sessionScrollOffset = 0
                UpdateSessionList()
            elseif self.drillGroup then
                -- Level 1 -> Level 2: drill into the fight/Overall and show its stream in the body.
                selectedGroup = self.drillGroup
                selectedContributor = nil
                sidebarMode = "SESSIONS"
                sessionScrollOffset = 0
                if CONFIG._buildOverall then
                    viewingMode = "ARCHIVE"
                    CONFIG._viewingOverall = self.drillGroup
                    displayBuffer = ExpandArchive(CONFIG._buildView(self.drillGroup))
                    logScrollOffset = math.max(0, #displayBuffer - CONFIG.VISIBLE_ROWS_HIST)
                end
                UpdateSessionList()
                UpdateHistoryDisplay()
            elseif self.viewGroup and CONFIG._buildOverall then
                -- View a scope-Overall or a single contributor's combat in the body.
                viewingMode = "ARCHIVE"
                CONFIG._viewingOverall = self.viewGroup
                displayBuffer = ExpandArchive(CONFIG._buildView(self.viewGroup))
                logScrollOffset = math.max(0, #displayBuffer - CONFIG.VISIBLE_ROWS_HIST)
                UpdateHistoryDisplay()
            end
        end)
        btn:SetHandler("OnMouseWheel", function(self, d) ScrollSession(d) end)
        sessionButtons[i] = btn
    end

    local btnClear = histSidebar:CreateChildWidget("button", "btnClear", 0, true)
    btnClear:AddAnchor("BOTTOM", histSidebar, 0, -10)
    btnClear:SetExtent(CONFIG.BUTTON_WIDTH, 24)
    btnClear:SetText("CLEAR ALL")
    if btnClear.style then btnClear.style:SetColor(COL_BTN_RED[1], COL_BTN_RED[2], COL_BTN_RED[3], 1) end
    btnClear:SetHandler("OnClick", ClearAll)
    local btnSessUp = histSidebar:CreateChildWidget("button", "btnSUp", 0, true)
    btnSessUp:AddAnchor("TOPRIGHT", histSidebar, -5, 70)
    btnSessUp:SetExtent(14, 40)
    btnSessUp:SetText("^")
    btnSessUp:SetHandler("OnClick", function() ScrollSession(1) end)
    local btnSessDown = histSidebar:CreateChildWidget("button", "btnSDown", 0, true)
    btnSessDown:AddAnchor("BOTTOMRIGHT", histSidebar, -5, -40)
    btnSessDown:SetExtent(14, 40)
    btnSessDown:SetText("v")
    btnSessDown:SetHandler("OnClick", function() ScrollSession(-1) end)

    -- Draggable scrollbar for the session list, between its up/down arrows (same as the log's).
    sessTrack = histSidebar:CreateChildWidget("emptywidget", "ssTrack", 0, true)
    sessTrack:AddAnchor("TOPRIGHT", btnSessUp, "BOTTOMRIGHT", 0, 4)
    sessTrack:SetExtent(14, CONFIG.HIST_HEIGHT - 256)
    CreateBackdrop(sessTrack, { 0.08, 0.08, 0.08, 0.55 })
    sessThumb = sessTrack:CreateChildWidget("button", "ssThumb", 0, true)
    sessThumb:SetExtent(8, 40)
    sessThumb:AddAnchor("TOP", sessTrack, 0, 0)
    CreateBackdrop(sessThumb, { 0.55, 0.55, 0.6, 0.95 })
    sessThumb:EnableDrag(true)
    sessThumb:SetHandler("OnDragStart", function()
        CONFIG._sessDragging = true
        local _, my = api.Input:GetMousePos()
        CONFIG._sessDragStartMouseY = my or 0
        local range = CONFIG._sessRange or 0
        local maxScroll = CONFIG._sessMaxScroll or 0
        CONFIG._sessDragStartThumbY = (maxScroll > 0 and range > 0) and (sessionScrollOffset / maxScroll) * range or 0
    end)
    sessThumb:SetHandler("OnDragStop", function() CONFIG._sessDragging = false end)
    sessThumb:SetHandler("OnUpdate", function()
        if not CONFIG._sessDragging then return end
        local range = CONFIG._sessRange or 0
        if range <= 0 then return end
        local _, my = api.Input:GetMousePos()
        if not my then return end
        local newY = (CONFIG._sessDragStartThumbY or 0) + (my - (CONFIG._sessDragStartMouseY or my))
        if newY < 0 then newY = 0 elseif newY > range then newY = range end
        local maxScroll = CONFIG._sessMaxScroll or 0
        sessionScrollOffset = math.floor((newY / range) * maxScroll + 0.5)
        UpdateSessionList()
    end)
    UpdateSessionThumb()

    local histBody = wHistory:CreateChildWidget("emptywidget", "hBody", 0, true)
    histBody:AddAnchor("TOPLEFT", histSidebar, "TOPRIGHT", 0, 0)
    histBody:AddAnchor("BOTTOMRIGHT", wHistory, 0, 0)
    CreateBackdrop(histBody, COL_LOG_BG)
    for i = 1, CONFIG.VISIBLE_ROWS_HIST do
        local btn = histBody:CreateChildWidget("label", "HL"..i, 0, true)
        btn:SetExtent(CONFIG.HIST_WIDTH - CONFIG.SIDEBAR_WIDTH - 64, CONFIG.HIST_ROW_H)  -- -64 clears the scrollbar
        btn:AddAnchor("TOPLEFT", histBody, 32, 8 + ((i-1) * CONFIG.HIST_ROW_H))
        if btn.SetLimitWidth then btn:SetLimitWidth(true) end
        if btn.style then
            btn.style:SetAlign(ALIGN.LEFT)
            btn.style:SetShadow(true)
            btn.style:SetEllipsis(true)
        end
        historyLabels[i] = btn
        -- Raid Meter bar: a colored fill on the body's BACKGROUND layer (renders behind the text
        -- labels), width re-anchored per render to the row's contribution. Created 0-width (hidden);
        -- only the Raid Meter view sets entry.barPct. All render ops are pcall-guarded.
        CONFIG._histBars = CONFIG._histBars or {}
        local barD = histBody:CreateColorDrawable(0.235, 0.45, 0.62, 0.32, "background")
        barD:AddAnchor("TOPLEFT", histBody, 32, 8 + ((i-1) * CONFIG.HIST_ROW_H) + 2)
        barD:AddAnchor("BOTTOMRIGHT", histBody, "TOPLEFT", 32, 8 + ((i-1) * CONFIG.HIST_ROW_H) + CONFIG.HIST_ROW_H - 2)
        barD.clpBarW = 0
        CONFIG._histBars[i] = barD
        -- Ally-recap rows split the line around an inline icon: a right-aligned LEFT label
        -- ("[time] Source —>") so the arrow hugs the icon column, then a left-aligned RIGHT
        -- label ("Skill ±N [HP%]") after it. Stored on CONFIG (no new top-level locals).
        CONFIG._recapL = CONFIG._recapL or {}
        CONFIG._recapR = CONFIG._recapR or {}
        local rL = histBody:CreateChildWidget("label", "HLrL"..i, 0, true)
        rL:SetExtent(CONFIG.RECAP_ICON_X - 7, CONFIG.HIST_ROW_H)
        rL:AddAnchor("TOPLEFT", histBody, 5, 8 + ((i-1) * CONFIG.HIST_ROW_H))
        if rL.SetLimitWidth then rL:SetLimitWidth(true) end
        if rL.style then rL.style:SetAlign(ALIGN.RIGHT); rL.style:SetShadow(true) end
        rL:Show(false); CONFIG._recapL[i] = rL
        local rR = histBody:CreateChildWidget("label", "HLrR"..i, 0, true)
        rR:SetExtent(CONFIG.HIST_WIDTH - CONFIG.SIDEBAR_WIDTH - CONFIG.RECAP_ICON_X - 60, CONFIG.HIST_ROW_H)
        rR:AddAnchor("TOPLEFT", histBody, CONFIG.RECAP_ICON_X + 26, 8 + ((i-1) * CONFIG.HIST_ROW_H))
        if rR.SetLimitWidth then rR:SetLimitWidth(true) end
        if rR.style then rR.style:SetAlign(ALIGN.LEFT); rR.style:SetShadow(true); rR.style:SetEllipsis(true) end
        rR:Show(false); CONFIG._recapR[i] = rR
        historyIcons[i] = ClpMakeIcon(histBody, 22)
        if historyIcons[i] then
            CONFIG._histBody = histBody
            historyIcons[i]:AddAnchor("TOPLEFT", histBody, 5, 9 + ((i-1) * CONFIG.HIST_ROW_H))
            historyIcons[i].clpIconX = 5
            historyIcons[i]:Show(false)
            -- Click an icon (or blank slot) to reassign it via the picker. The skill name is
            -- stamped on the widget during render; the picker writes icon_overrides.txt.
            pcall(function() historyIcons[i]:SetHandler("OnClick", function(self)
                if self.clpSkill and CONFIG._openIconPicker then CONFIG._openIconPicker(self.clpSkill) end
            end) end)
        end
    end
    local btnUp = histBody:CreateChildWidget("button", "bUp", 0, true)
    btnUp:AddAnchor("TOPRIGHT", histBody, -5, 5)
    btnUp:SetExtent(14, 40)
    btnUp:SetText("^")
    btnUp:SetHandler("OnClick", ScrollLogUp)
    local btnDown = histBody:CreateChildWidget("button", "bDown", 0, true)
    btnDown:AddAnchor("BOTTOMRIGHT", histBody, -5, -5)
    btnDown:SetExtent(14, 40)
    btnDown:SetText("v")
    btnDown:SetHandler("OnClick", ScrollLogDown)
    histBody:EnableDrag(true)
    histBody:SetHandler("OnMouseWheel", function(self, d) if d>0 then ScrollLogUp() else ScrollLogDown() end end)

    -- Draggable scrollbar between the up/down arrows. (AA grabs the mouse wheel for camera zoom, so
    -- the arrows + this bar are the only ways to scroll.) The thumb shows position + size and can be
    -- dragged; driven off the cursor Y (api.Input:GetMousePos) via a start-offset + mouse delta,
    -- since AA has no clean cursor-to-widget mapping.
    scrollTrack = histBody:CreateChildWidget("emptywidget", "scTrack", 0, true)
    scrollTrack:AddAnchor("TOPRIGHT", btnUp, "BOTTOMRIGHT", 0, 4)
    scrollTrack:SetExtent(14, CONFIG.HIST_HEIGHT - 156)
    CreateBackdrop(scrollTrack, { 0.08, 0.08, 0.08, 0.55 })
    scrollThumb = scrollTrack:CreateChildWidget("button", "scThumb", 0, true)
    scrollThumb:SetExtent(8, 40)
    scrollThumb:AddAnchor("TOP", scrollTrack, 0, 0)
    CreateBackdrop(scrollThumb, { 0.55, 0.55, 0.6, 0.95 })
    scrollThumb:EnableDrag(true)
    scrollThumb:SetHandler("OnDragStart", function()
        CONFIG._scrollDragging = true
        local _, my = api.Input:GetMousePos()
        CONFIG._dragStartMouseY = my or 0
        local range = CONFIG._scrollRange or 0
        local maxOffset = math.max(0, #displayBuffer - CONFIG.VISIBLE_ROWS_HIST)
        CONFIG._dragStartThumbY = (maxOffset > 0 and range > 0) and (logScrollOffset / maxOffset) * range or 0
    end)
    scrollThumb:SetHandler("OnDragStop", function() CONFIG._scrollDragging = false end)
    scrollThumb:SetHandler("OnUpdate", function()
        if not CONFIG._scrollDragging then return end
        local range = CONFIG._scrollRange or 0
        if range <= 0 then return end
        local _, my = api.Input:GetMousePos()
        if not my then return end
        local newY = (CONFIG._dragStartThumbY or 0) + (my - (CONFIG._dragStartMouseY or my))
        if newY < 0 then newY = 0 elseif newY > range then newY = range end
        local maxOffset = math.max(0, #displayBuffer - CONFIG.VISIBLE_ROWS_HIST)
        logScrollOffset = math.floor((newY / range) * maxOffset + 0.5)
        UpdateHistoryDisplay()
    end)
    UpdateScrollThumb()
end

local function Load()
    local myId = api.Unit:GetUnitId("player")
    PLAYER_NAME = api.Unit:GetUnitNameById(myId)
    if not PLAYER_NAME or PLAYER_NAME == "" then PLAYER_NAME = "Unknown" end
    PLAYER_UNIT_ID = tostring(myId or "")

    -- Seed song buff baselines from current player stats so they're never nil,
    -- even if chanty/ballad was already active when the addon loaded.
    local okInit, pInit = pcall(function() return api.Unit:UnitInfo("player") end)
    if okInit and pInit then
        baselineSpellDmgMul = tonumber(pInit.spell_damage_mul or 0)
        baselineArmor       = tonumber(pInit.armor             or 0)
        baselineMagicResist = tonumber(pInit.magic_resist      or 0)
    end

    BASE_SECONDS_OF_DAY = 0
    BASE_APP_MSEC = 0
    TIME_INITIALIZED = false
    LoadSavedSettings()

    -- === SMALL TOGGLE PANEL (always visible, Shift+Drag to move): titled header + Live | History ===
    -- One housing: a thin "Combat Log Pro" header over two segments split by a seam.
    wButton = api.Interface:CreateEmptyWindow("CLPBtn", "UIParent")
    wButton:Show(true)
    wButton:SetExtent(112, 37)
    if savedSettings.btnX then
        wButton:AddAnchor("TOPLEFT", "UIParent", savedSettings.btnX, savedSettings.btnY)
    else
        wButton:AddAnchor("LEFT", "UIParent", 20, -100)
    end
    CreateBackdrop(wButton, {0.15, 0.15, 0.15, 0.9})

    -- Thin title header (drag here to move the panel).
    local btnHeader = wButton:CreateChildWidget("emptywidget", "clpBtnHdr", 0, true)
    btnHeader:AddAnchor("TOPLEFT", wButton, 0, 0)
    btnHeader:AddAnchor("TOPRIGHT", wButton, 0, 0)
    btnHeader:SetHeight(13)
    CreateBackdrop(btnHeader, COL_HEADER)
    MakeDraggable(btnHeader, wButton, SaveSettings)
    local btnTitle = btnHeader:CreateChildWidget("label", "clpBtnTitle", 0, true)
    btnTitle:AddAnchor("CENTER", btnHeader, 0, 0)
    btnTitle:SetExtent(110, 13)
    btnTitle:SetText("Combat Log Pro")
    if btnTitle.style then btnTitle.style:SetAlign(ALIGN.CENTER); btnTitle.style:SetFontSize(9); btnTitle.style:SetColor(0.72, 0.72, 0.78, 1) end
    MakeDraggable(btnTitle, wButton, SaveSettings)

    -- Both segments share one scheme so they always match: green = its window open, grey = closed.
    -- Left segment: Live (toggles the live combat feed).
    local toggleBtn = wButton:CreateChildWidget("button", "Toggle", 0, true)
    toggleBtn:AddAnchor("TOPLEFT", btnHeader, "BOTTOMLEFT", 0, 0)
    toggleBtn:SetExtent(52, 24)
    toggleBtn:SetText("Live")
    toggleBtn:SetTextColor(0, 1, 0, 1)
    MakeDraggable(toggleBtn, wButton, SaveSettings)

    -- Right segment: History (toggles the history window). Reachable even when Live is closed.
    local histBtn = wButton:CreateChildWidget("button", "HistBtn", 0, true)
    histBtn:AddAnchor("TOPRIGHT", btnHeader, "BOTTOMRIGHT", 0, 0)
    histBtn:SetExtent(56, 24)
    histBtn:SetText("History")
    histBtn:SetTextColor(0.5, 0.5, 0.5, 1)  -- history starts closed -> grey
    MakeDraggable(histBtn, wButton, SaveSettings)
    -- Keep the History segment's colour in sync with the window from any of its toggle points.
    CONFIG._histBtn = histBtn
    CONFIG._refreshHistBtn = function()
        if not CONFIG._histBtn then return end
        if wHistory and wHistory:IsVisible() then CONFIG._histBtn:SetTextColor(0, 1, 0, 1)
        else CONFIG._histBtn:SetTextColor(0.5, 0.5, 0.5, 1) end
    end
    histBtn:SetHandler("OnClick", function()
        wHistory:Show(not wHistory:IsVisible()); UpdateHistoryDisplay(); UpdateSessionList()
        CONFIG._refreshHistBtn()
    end)

    -- Seam: a thin vertical line in the gap so the two segments read as connected-but-separate.
    local btnSeam = wButton:CreateColorDrawable(0.4, 0.4, 0.4, 1, "overlay")
    btnSeam:AddAnchor("TOPLEFT", toggleBtn, "TOPRIGHT", 1, 3)
    btnSeam:AddAnchor("BOTTOMRIGHT", histBtn, "BOTTOMLEFT", -1, -3)

    -- === LIVE LOG WINDOW (detached, toggled by button or X) ===
    wLive = api.Interface:CreateEmptyWindow("LiveWin", "UIParent")
    wLive:Show(true)
    wLive:SetExtent(CONFIG.LIVE_WIDTH, CONFIG.LIVE_HEIGHT)
    if savedSettings.liveX then
        wLive:AddAnchor("TOPLEFT", "UIParent", savedSettings.liveX, savedSettings.liveY)
    else
        wLive:AddAnchor("LEFT", "UIParent", 80, 0)
    end
    MakeDraggable(wLive, wLive, SaveSettings)

    local liveHeader = wLive:CreateChildWidget("emptywidget", "lHeader", 0, true)
    liveHeader:AddAnchor("TOPLEFT", wLive, 0, 0)
    liveHeader:AddAnchor("TOPRIGHT", wLive, 0, 0)
    liveHeader:SetHeight(30)
    CreateBackdrop(liveHeader, COL_HEADER)
    MakeDraggable(liveHeader, wLive, SaveSettings)

    liveTitleLabel = liveHeader:CreateChildWidget("label", "Title", 0, true)
    liveTitleLabel:AddAnchor("LEFT", liveHeader, 12, 0)
    liveTitleLabel:SetExtent(105, 30)
    liveTitleLabel:SetText("Combat Log")
    if liveTitleLabel.style then liveTitleLabel.style:SetAlign(ALIGN.LEFT); liveTitleLabel.style:SetFontSize(15); liveTitleLabel.style:SetColor(0.9, 0.9, 0.9, 1) end
    MakeDraggable(liveTitleLabel, wLive, SaveSettings)

    -- Status badge stored on the title label (avoids a new file-level Load upvalue)
    local liveStatus = liveHeader:CreateChildWidget("label", "Status", 0, true)
    liveStatus:AddAnchor("LEFT", liveTitleLabel, "RIGHT", 4, 0)
    liveStatus:SetExtent(90, 30)
    liveStatus:SetText("IDLE")
    if liveStatus.style then liveStatus.style:SetAlign(ALIGN.LEFT); liveStatus.style:SetFontSize(11); liveStatus.style:SetColor(0.45, 0.45, 0.45, 1) end
    MakeDraggable(liveStatus, wLive, SaveSettings)
    liveTitleLabel.statusLabel = liveStatus

    local btnHide = liveHeader:CreateChildWidget("button", "btnHide", 0, true)
    btnHide:AddAnchor("RIGHT", liveHeader, -5, 0)
    btnHide:SetExtent(24, 24)
    btnHide:SetText("X")
    btnHide:SetHandler("OnClick", function()
        wLive:Show(false)
        isMinimized = true
        toggleBtn:SetTextColor(0.5, 0.5, 0.5, 1)
        CONFIG.LIVE_OPEN = false; SaveSettings()  -- remember closed for next login
    end)

    -- History + Options live in a bottom FOOTER (moved out of the header) so the IDLE/IN COMBAT
    -- badge always has room up top -- it used to hide when the window was below ~360px wide.
    local liveFooter = wLive:CreateChildWidget("emptywidget", "lFooter", 0, true)
    liveFooter:AddAnchor("BOTTOMLEFT", wLive, 0, 0)
    liveFooter:AddAnchor("BOTTOMRIGHT", wLive, 0, 0)
    liveFooter:SetHeight(26)
    CreateBackdrop(liveFooter, COL_HEADER)
    MakeDraggable(liveFooter, wLive, SaveSettings)

    local btnHist = liveFooter:CreateChildWidget("button", "btnHist", 0, true)
    btnHist:SetExtent(82, 22); btnHist:AddAnchor("LEFT", liveFooter, 8, 0)
    btnHist:SetText("History")
    btnHist:SetHandler("OnClick", function() wHistory:Show(not wHistory:IsVisible()); UpdateHistoryDisplay(); UpdateSessionList(); if CONFIG._refreshHistBtn then CONFIG._refreshHistBtn() end end)

    local btnOp = liveFooter:CreateChildWidget("button", "btnOp", 0, true)
    btnOp:SetExtent(82, 22); btnOp:AddAnchor("LEFT", btnHist, "RIGHT", 6, 0)
    btnOp:SetText("Options")
    btnOp:SetHandler("OnClick", function() if not wOptions then CreateOptionsWindow() end; wOptions:Show(not wOptions:IsVisible()) end)

    liveBodyWidget = wLive:CreateChildWidget("emptywidget", "lBody", 0, true)
    liveBodyWidget:AddAnchor("TOPLEFT", liveHeader, "BOTTOMLEFT", 0, 0)
    liveBodyWidget:AddAnchor("BOTTOMRIGHT", liveFooter, "TOPRIGHT", 0, 0)
    CreateBackdrop(liveBodyWidget, COL_BODY)
    MakeDraggable(liveBodyWidget, wLive, SaveSettings)
    RebuildLiveLabels()

    -- Toggle button click handler (set after wLive exists)
    toggleBtn:SetHandler("OnClick", function()
        if wLive:IsVisible() then
            wLive:Show(false)
            isMinimized = true
            toggleBtn:SetTextColor(0.5, 0.5, 0.5, 1)
            CONFIG.LIVE_OPEN = false
        else
            wLive:Show(true)
            isMinimized = false
            toggleBtn:SetTextColor(0, 1, 0, 1)
            CONFIG.LIVE_OPEN = true
        end
        SaveSettings()  -- remember open/closed for next login
    end)

    -- Restore last session's open/closed state (default open). Closed = start minimized.
    if CONFIG.LIVE_OPEN == false then
        wLive:Show(false)
        isMinimized = true
        toggleBtn:SetTextColor(0.5, 0.5, 0.5, 1)
    end

    CreateHistoryWindow()

    -- Events on the always-visible button so combat tracking works when log is hidden
    wButton:SetHandler("OnEvent", OnLiveEvent)
    wButton:SetHandler("OnUpdate", OnLiveUpdate)
    wButton:RegisterEvent("COMBAT_MSG")
    wButton:RegisterEvent("COMBAT_TEXT")  -- provides sourceUnitId to distinguish same-named mobs
    wButton:RegisterEvent("UNIT_DEAD")    -- authoritative death event for ALL units incl. the local player
    wButton:RegisterEvent("UNIT_COMBAT_STATE_CHANGED")
    wButton:RegisterEvent("TARGET_CHANGED")           -- patch 243+: instant target tracking
    wButton:RegisterEvent("TARGET_TO_TARGET_CHANGED") -- patch 243+: live enemy-targeting-player state
    wButton:RegisterEvent("SPELLCAST_START")          -- patch 243+: cast began
    wButton:RegisterEvent("SPELLCAST_SUCCEEDED")      -- patch 243+: cast completed
    wButton:RegisterEvent("SPELLCAST_STOP")           -- patch 243+: cast interrupted/cancelled
    pcall(function() wButton:RegisterEvent("HEIR_SKILL_LEARN") end)  -- ancestral variant switched -> update icon
    pcall(function() wButton:RegisterEvent("HEIR_SKILL_RESET") end)  -- ancestral variant reset -> base icon
    pcall(CONFIG._loadHeir)                            -- restore persisted ancestral-variant icons (event doesn't fire on login)
    pcall(BuildPlayerSkillIcons)                       -- name->icon map for your own skills (history)
    LogEntry("CombatLogPro v2.0.0 Loaded (" .. PLAYER_NAME .. ")", 0, 1, 0, { time = "" })
end

local function Unload()
    SaveSettings()
    if wButton then wButton:Show(false); wButton = nil end
    if wLive then wLive:Show(false); wLive = nil end
    if wHistory then wHistory:Show(false); wHistory = nil end
    if wOptions then wOptions:Show(false); wOptions = nil end
end

addon.OnLoad = Load; addon.OnUnload = Unload; return addon
