-- stat_icons.lua -- icons for the recap STAT lines (defense, crit, dodge, etc.).
-- AA has no dedicated "stat icons" the addon can reach, so these are thematically-matching
-- SKILL icons (which definitely exist). Swap any you don't like: the value is a game icon
-- base name, rendered as Game\ui\icon\<name>.dds. Pull names from aa-classic.com/skillcalc
-- the same way skill_icons.lua does (the web filename IS the texture name).
--
-- FORMAT: ordered { "line keyword" (lowercase), "icon_base" }. Each recap stat line is
-- lowercased and matched against these in order -- FIRST keyword found wins, so list the
-- more specific keywords first (e.g. "magic res" before a bare "res").
return {
    { "magic res",   "icon_skill_will14"    }, -- Magic Defense   (Spell Shield)
    { "armor",       "icon_skill_adamant06" }, -- Physical Defense (Toughen)
    { "dodge",       "icon_skill_wild11"    }, -- Dodge/Block/Parry avoidance line (Evasion)
    { "modifiers",   "icon_skill_romance31" }, -- Received-damage modifiers (Disciplined Performance)
    { "crit bonus",  "icon_skill_magic32"   }, -- "[*] Crit bonus" summary line -- MUST precede bare "crit" (else it'd grab the Zeal icon)
    { "crit",        "icon_skill_romance03" }, -- Critical rate stat line (Zeal)
    { "heal power",  "icon_skill_romance05" }, -- Heal Power (Ode to Recovery)
    { "cast time",   "icon_skill_romance01" }, -- Cast Time (Hummingbird Ditty)
}
