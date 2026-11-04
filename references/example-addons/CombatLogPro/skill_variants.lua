-- skill_variants.lua
-- Ancestral- (AA: "heir-") skill variant icons, keyed by the HEIR_SKILL_LEARN position.
--
-- An ancestral skill can morph into variants that SHARE one combat-log name (all 3 "Meteor Strike"
-- forms log as "Meteor Strike") but have different icons. When you switch a variant the game fires
--   HEIR_SKILL_LEARN(skillName, pos)
-- where `pos` is the variant node's position in the heir tree. We map (skill, pos) -> icon here and
-- stamp it. `pos` values come straight from each skill's ancestral.variants[].pos in the
-- aa-classic.com skill JSON; `base` is the unmorphed skill's icon (used when pos isn't a known
-- variant -- i.e. you switched back to the base node).
--
-- The event only fires ON a switch (not at login), so CombatLogPro PERSISTS the chosen pos per
-- skill to CombatLogPro/heir_variants.txt and reloads it on start. icon = icon base, no extension.

local V = {}

-- ARCHERY
V["Charged Bolt"]      = { base = "icon_skill_wild02",     byPos = { [1] = "icon_skill_wild27",  [7] = "icon_skill_wild28" } }
V["Endless Arrows"]    = { base = "icon_skill_vocation25", byPos = { [1] = "icon_skill_wild35" } }
V["Concussive Arrow"]  = { base = "icon_skill_wild15",     byPos = { [1] = "icon_skill_wild29",  [6] = "icon_skill_wild30" } }
V["Missile Rain"]      = { base = "icon_skill_wild10",     byPos = { [1] = "icon_skill_wild31",  [6] = "icon_skill_wild32" } }

-- AURAMANCY
V["Thwart"]            = { base = "icon_skill_will24", byPos = { [4] = "icon_skill_will31", [6] = "icon_skill_will30" } }
V["Spell Shield"]      = { base = "icon_skill_will14", byPos = { [1] = "icon_skill_will33", [6] = "icon_skill_will32" } }
V["Protective Wings"]  = { base = "icon_skill_will13", byPos = { [1] = "icon_skill_will35", [6] = "icon_skill_will34" } }

-- BATTLERAGE
V["Triple Slash"]      = { base = "icon_skill_fight02", byPos = { [3] = "icon_skill_fight35", [8] = "icon_skill_fight34" } }
V["Precision Strike"]  = { base = "icon_skill_fight15", byPos = { [5] = "icon_skill_fight36", [7] = "icon_skill_fight37" } }
V["Tiger Strike"]      = { base = "icon_skill_fight18", byPos = { [2] = "icon_skill_fight39", [8] = "icon_skill_fight38" } }

-- DEFENSE
V["Shield Slam"]       = { base = "icon_skill_adamant01", byPos = { [3] = "icon_skill_adamant34", [7] = "icon_skill_adamant33" } }
V["Redoubt"]           = { base = "icon_skill_adamant05", byPos = { [2] = "icon_skill_adamant36", [7] = "icon_skill_adamant35" } }
V["Imprison"]          = { base = "icon_skill_love10",    byPos = { [5] = "icon_skill_adamant37", [6] = "icon_skill_adamant38" } }

-- OCCULTISM
V["Mana Stars"]        = { base = "icon_skill_death25", byPos = { [3] = "icon_skill_death31", [5] = "icon_skill_death30" } }
V["Hell Spear"]        = { base = "icon_skill_death06", byPos = { [6] = "icon_skill_death33" } }
V["Summon Wraith"]     = { base = "icon_skill_death13", byPos = { [5] = "icon_skill_death34", [6] = "icon_skill_death35" } }

-- SHADOWPLAY
V["Overwhelm"]         = { base = "icon_skill_vocation07", byPos = { [1] = "icon_skill_vocation31", [8] = "icon_skill_vocation32" } }
V["Drop Back"]         = { base = "icon_skill_vocation15", byPos = { [5] = "icon_skill_vocation34", [6] = "icon_skill_vocation33" } }
V["Shadowsmite"]       = { base = "icon_skill_vocation06", byPos = { [6] = "icon_skill_vocation35", [8] = "icon_skill_vocation36" } }

-- SONGCRAFT
V["Startling Strain"]  = { base = "icon_skill_romance15", byPos = { [2] = "icon_skill_romance35", [5] = "icon_skill_romance36" } }
V["Healing Hymn"]      = { base = "icon_skill_romance29", byPos = { [4] = "icon_skill_romance33", [5] = "icon_skill_romance34" } }
V["Alarm Call"]        = { base = "icon_skill_romance25", byPos = { [2] = "icon_skill_romance38", [4] = "icon_skill_romance37" } }

-- SORCERY
-- `debuffs` = the uniquely-named debuff a NON-base variant leaves on its target -> icon. Used to
-- identify an INCOMING cast's variant by reading the debuff it put on YOU (best-effort; base if
-- none matches). Only forms with a distinct debuff are listed; ambiguous/shared ones -> base.
V["Flamebolt"]         = { base = "icon_skill_magic01", byPos = { [1] = "icon_skill_magic34", [8] = "icon_skill_magic35" },
                           debuffs = { ["Shock"] = "icon_skill_magic35" } }  -- electric form (base/heavy both apply Burning)
V["Chain Lightning"]   = { base = "icon_skill_magic19", byPos = { [1] = "icon_skill_magic37", [5] = "icon_skill_magic36" },
                           debuffs = { ["Consuming Flames"] = "icon_skill_magic37", ["Snare"] = "icon_skill_magic36" } }
V["Meteor Strike"]     = { base = "icon_skill_magic13", byPos = { [5] = "icon_skill_magic38", [8] = "icon_skill_magic39" },
                           debuffs = { ["Greater Shock"] = "icon_skill_magic39", ["Deep Freeze"] = "icon_skill_magic38" } }

-- VITALISM
V["Antithesis"]        = { base = "icon_skill_love01", byPos = { [2] = "icon_skill_love33",   [3] = "icon_skill_love34" } }
V["Skewer"]            = { base = "icon_skill_love05", byPos = { [1] = "icon_skill_love38_1", [2] = "icon_skill_love37" } }
V["Fervent Healing"]   = { base = "icon_skill_love21", byPos = { [1] = "icon_skill_love36",   [8] = "icon_skill_love35" } }

-- WITCHCRAFT
V["Earthen Grip"]      = { base = "icon_skill_illusion09", byPos = { [3] = "icon_skill_illusion27", [8] = "icon_skill_illusion28" } }
V["Bubble Trap"]       = { base = "icon_skill_illusion04", byPos = { [6] = "icon_skill_illusion30", [7] = "icon_skill_illusion29" } }
V["Banshee Wail"]      = { base = "icon_skill_illusion18", byPos = { [4] = "icon_skill_illusion31", [6] = "icon_skill_illusion32" } }

return V
