-- skill_combos.lua
-- Maps skill name -> list of combo entries.
-- Each entry: { cond, pct, effect }
--   cond   : target debuff/status name (must be on the enemy's buff bar)
--   pct    : damage bonus % (nil = no damage bonus)
--   effect : description of non-damage effect (nil = none)
--
-- Bonus damage formula: bonus = totalDmg * pct / (100 + pct)
-- Log format:
--   damage + effect  ->  {Cond +X% (+N) | Effect}
--   damage only      ->  {Cond +X% (+N)}
--   effect only      ->  {Cond | Effect}
--   unknown          ->  {Cond}
--
-- Self-buff combos (Energy Shield, Toughen, Bear's Vigor, etc.) excluded —
-- the game synergy flag still fires; hits show {Combo} without a condition name.
--
-- Sources: wiki.aa-classic.com/Skill_Trees + in-game screenshots

local SKILL_COMBOS = {

    -- =========================================================
    -- BATTLERAGE
    -- =========================================================
    ["Triple Slash"]     = {
        { cond="Tripped",   effect="bonus dmg" },               -- Attack 2 (% unconfirmed)
    },
    ["Whirlwind Slash"]  = {
        { cond="Shaken",    effect="bonus dmg" },               -- Attack 1 (% unconfirmed)
        { cond="Tripped",   effect="bonus dmg" },               -- Attack 2 (% unconfirmed)
    },
    ["Sunder Earth"]     = {
        { cond="Bleeding",  effect="bonus dmg" },               -- (% unconfirmed)
    },
    ["Tiger Strike"]     = {
        { cond="Bleeding",  effect="bonus dmg" },               -- (% unconfirmed)
    },

    -- =========================================================
    -- SHADOWPLAY
    -- =========================================================
    ["Rapid Strike"]     = {
        { cond="Tripped",        pct=23 },
    },
    ["Overwhelm"]        = {
        { cond="Stalker's Mark", pct=70, effect="+1s Stun" },
    },
    ["Wallop"]           = {
        { cond="Shaken",         pct=11, effect="4th hit Blood Frenzy" },
    },
    ["Stalker's Mark"]   = {
        { cond="Poisoned",       pct=38 },
    },
    ["Pin Down"]         = {
        { cond="Shackled",       pct=42 },
    },
    ["Shadowsmite"]      = {
        { cond="Stunned",        effect="Trips target 2.5s" },
    },
    ["Throw Dagger"]     = {
        { cond="Stalker's Mark", effect="2x Bloodthirst" },
    },

    -- =========================================================
    -- ARCHERY
    -- =========================================================
    ["Piercing Shot"]    = {
        { cond="Poisoned",   pct=27 },
    },
    ["Concussive Arrow"] = {
        { cond="Feral Aura", pct=51 },
        { cond="Bleeding",   effect="Defense pen bonus" },
    },
    ["Snipe"]            = {
        { cond="Snared",     effect="bonus effect" },           -- exact effect unconfirmed
    },

    -- =========================================================
    -- DEFENSE
    -- =========================================================
    ["Shield Slam"]      = {
        { cond="Snared",    pct=31 },
        { cond="Enervated", effect="+30% Stun duration" },
        { selfbuff="Energy Shield", pct=61 },
    },
    ["Bull Rush"]        = {
        { cond="Stunned",   pct=42, effect="Trips target 4s" },
        { selfbuff="Energy Shield", pct=68 },
    },
    ["Ollo's Hammer"]    = {
        { cond="Slowed",    pct=44 },
    },

    -- =========================================================
    -- SORCERY
    -- =========================================================
    ["Flamebolt"]        = {
        { cond="Frozen",    pct=12 },
        { cond="Burning",   effect="Conflagration" },
        { cond="Enervated", effect="20% dmg as Mana" },
    },
    ["Freezing Arrow"]   = {
        { cond="Burning",   pct=15 },
        { cond="Frozen",    effect="Deep Freeze 20s" },
        { cond="Sleeping",  pct=34 },
    },
    ["Freezing Earth"]   = {
        { cond="Burning",   pct=26 },
        { cond="Frozen",    effect="Ice Shard (Snare 4s)" },
    },
    ["Arc Lightning"]    = {
        { cond="Electric Shock", pct=43 },
        { cond="Impaled",        pct=45 },
    },
    ["Chain Lightning"]  = {
        { cond="Impaled",   pct=30 },
    },
    ["Searing Rain"]     = {
        { cond="Frozen",    pct=44 },
    },
    ["Flame Barrier"]    = {
        { cond="Frozen",    pct=41 },
    },
    ["Meteor Strike"]    = {
        { cond="Frozen",    pct=30 },
    },

    -- =========================================================
    -- OCCULTISM
    -- =========================================================
    ["Mana Force"]       = {
        { cond="Cursed",        pct=101 },
        { cond="Fetter",        effect="Inflicts Weakness" },
    },
    ["Hell Spear"]       = {
        { cond="Impaled",       pct=48 },
    },
    ["Hell Spears"]      = {
        { cond="Impaled",       pct=48 },
    },
    ["Absorb Lifeforce"] = {
        { cond="Stunned",       pct=46 },
        { cond="Burning Brand", effect="CD -3%/stack" },
    },
    ["Summon Crows"]     = {
        { cond="Impaled",       effect="Inflicts Poison" },
        { cond="Snared",        effect="-60% accuracy" },
    },
    ["Crippling Mire"]   = {
        { cond="Poisoned",      pct=30 },
        { cond="Distressed",    effect="Stun on expiry" },
    },

    -- =========================================================
    -- WITCHCRAFT
    -- =========================================================
    ["Dahuta's Breath"]  = {
        { cond="Electric Shock", pct=46 },
    },
    ["Bubble Trap"]      = {
        { cond="Electric Shock", effect="magic dmg" },
        { cond="Burning",        effect="thrown higher" },
    },
    ["Lassitude"]        = {
        { cond="Frozen",         effect="+10s CC duration" },
    },
    ["Banshee Wail"]     = {
        { cond="Burning",        effect="+2s CC duration" },
    },

    -- =========================================================
    -- SONGCRAFT
    -- =========================================================
    ["Critical Discord"] = {
        { cond="Charmed",        effect="consumes Charmed" },
    },

    -- =========================================================
    -- AURAMANCY
    -- =========================================================
    ["Vicious Implosion"] = {
        { selfbuff="Inspired", pct=52 },    -- 52% per Inspired stack; stack count read live at hit time
    },

    -- =========================================================
    -- VITALISM
    -- =========================================================
    ["Antithesis"]       = {
        { cond="Charmed",        pct=26 },
    },

}

return SKILL_COMBOS
