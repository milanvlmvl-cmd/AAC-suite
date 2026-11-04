-- user_filters.lua — YOUR personal combat-log filter.
--
-- Add buff/skill names here to hide them from the log (this hides them from BOTH
-- the buff/debuff scanner AND combat lines like energize/mana-restore spam).
-- Matching is case-insensitive. After editing, reload the UI (/reloadui or relog).
--
-- The built-in filter already hides food/drink, gliders, mounts, "Wanted",
-- "Heroic Grandeur", "Calleil's Memory" and other mana-restore trinkets, etc.
-- Use THIS file only for extra things you personally want gone.
--
-- HOW TO ADD: put the exact name in quotes with a trailing comma, e.g.
--     "Some Annoying Buff",
-- To find a name, hover the buff/debuff in-game (the title at the top of the
-- tooltip is the name), or copy it straight out of the combat log.

return {
    -- Exact names (case-insensitive). One per line.
    names = {
        -- "Some Annoying Buff",
        -- "Another Skill Name",
    },

    -- ADVANCED: keyword patterns (lowercase). Any name CONTAINING one of these is
    -- hidden, so a single entry can cover a whole family. Leave empty unless needed.
    --   "potion"   hides anything with "potion" in the name
    --   "'s scroll" hides "X's Scroll" items
    patterns = {
        -- "potion",
    },
}
