-- role_data.lua — class-name -> role (tank/healer/dps) for CombatLogPro name icons.
-- Class lists adapted from the role_identifier / power_ranger_on role_helper.
local RoleData = {}

local TANKS = {
    ["Abolisher"]=true, ["Skullknight"]=true, ["Templar"]=true,
    ["Bastion"]=true, ["Paladin"]=true, ["Doomlord"]=true,
}
local HEALERS = {
    ["Cleric"]=true, ["Hierophant"]=true, ["Soothsayer"]=true,
    ["Caretaker"]=true, ["Edgewalker"]=true, ["Gypsy"]=true,
}

-- Returns "tank" | "healer" | "dps" for a class name, or nil if unknown/empty.
function RoleData.GetRoleFromClass(className)
    if not className or className == "" then return nil end
    if TANKS[className]   then return "tank"   end
    if HEALERS[className]  then return "healer" end
    return "dps"
end

-- Skillset IDs (from Enhanced_X_UP_Plus/constants.lua). A unit's GetUnitInfoById().class
-- is a table of these IDs -- the character's three skillsets.
RoleData.SKILLSET = {
    BATTLERAGE = 1, WITCHCRAFT = 2, DEFENSE = 3, AURAMANCY = 4,
    OCCULTISM = 5, ARCHERY = 6, SORCERY = 7, SHADOWPLAY = 8,
    SONGCRAFT = 9, VITALISM = 10,
}

-- Robust role from a unit's skillset table -- mirrors Enhanced_X_UP_Plus' DetermineRole,
-- collapsed to tank/healer/dps (our three icons). This covers EVERY class, not just the
-- named tank/healer lists above. Order matters: a melee/archer with a Vitalism splash is
-- dps, NOT a healer, so those checks must come before the bare "has Vitalism" check.
function RoleData.GetRoleFromClassTable(classTable)
    if type(classTable) ~= "table" then return nil end
    local S = RoleData.SKILLSET
    local set = {}
    for _, v in pairs(classTable) do local n = tonumber(v); if n then set[n] = true end end
    local hasVit, hasDef, hasBR = set[S.VITALISM], set[S.DEFENSE], set[S.BATTLERAGE]
    local hasArc, hasSP, hasAur = set[S.ARCHERY], set[S.SHADOWPLAY], set[S.AURAMANCY]
    if hasBR and hasDef and hasVit then return "tank" end   -- Battlerage+Defense+Vitalism
    if hasBR and hasSP and hasVit then return "dps"  end    -- melee bruiser (Vit splash)
    if hasArc and hasSP and hasVit then return "dps" end    -- archer hybrid (Vit splash)
    if hasVit then return "healer" end
    if hasDef then return "tank" end
    if hasAur then return "tank" end
    return "dps"
end

return RoleData
