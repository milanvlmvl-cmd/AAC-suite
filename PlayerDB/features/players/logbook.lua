local api = require("api")
local addoninfo = require("PlayerDB/addoninfo")
local datafiles = require("PlayerDB/datafiles")
local clock = require("PlayerDB/clock")

local logbook = {}

local PLAYERS_DIR = "PlayerDB/Players/"
local COUNT_PATH = PLAYERS_DIR .. "_count.dat"
-- dev mode: chat messages (new players, changes, errors) and debug output; off = silent
local DEBUG = false
-- dev: write everything the API returns for each targeted player to DUMP_PATH (overwritten per target)
local DUMP_TARGET = false
local DUMP_PATH = "PlayerDB/target_dump.dat"
-- dev: same for every raid member, written to RAID_DUMP_PATH on each raid scan (overwritten per scan)
local DUMP_RAID = false
local RAID_DUMP_PATH = "PlayerDB/raid_dump.dat"

-- the only way the addon writes to chat, so nothing reaches chat unless DEBUG is on
function logbook.Chat(filter, message)
	if not DEBUG then
		return
	end
	api.Chat:DispatchChatMessage(filter, message)
end

local function debugLog(message)
	if not DEBUG then
		return
	end
	api.Log:Info("[PlayerDB] DEBUG " .. message)
	logbook.Chat(3, "[PlayerDB] DEBUG " .. message)
end

local function numberToString(value)
	if value == math.floor(value) then
		return string.format("%.0f", value)
	end
	return string.format("%.14g", value)
end

local function copyPlain(value, visited)
	local valueType = type(value)
	if valueType ~= "table" then
		if valueType == "number" then
			return numberToString(value)
		elseif valueType == "string" or valueType == "boolean" then
			return value
		end
		return nil
	end
	visited = visited or {}
	if visited[value] then
		return nil
	end
	visited[value] = true
	local out = {}
	for key, nestedValue in pairs(value) do
		out[key] = copyPlain(nestedValue, visited)
	end
	return out
end

-- returns the first non-empty string field found in info under any of the given keys
local function pickField(info, keys)
	if type(info) ~= "table" then
		return nil
	end
	for _, key in ipairs(keys) do
		local value = info[key]
		if type(value) == "string" and value ~= "" then
			return value
		end
	end
	return nil
end

local function dumpInfo(info)
	if not DEBUG or type(info) ~= "table" then
		return
	end
	local parts = {}
	for key, value in pairs(info) do
		parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
	end
	debugLog("unit info: " .. table.concat(parts, ", "))
end

local function isPlayer(info)
	if type(info) ~= "table" then
		return false
	end
	return info.type == "character"
end

local function getFaction(unit, info)
	local ok, faction = pcall(function()
		return api.Unit:GetFactionName(unit)
	end)
	if ok and type(faction) == "string" and faction ~= "" then
		return faction
	end
	return pickField(info, {"faction", "factionName", "faction_name"})
end

-- Faction names as returned by GetFactionName (lowercased), mapped to a side.
-- Same table as WorldSatNav, plus pirates.
local FACTION_SIDE = {
	-- Nuia (West)
	["dreamwaker exiles"]  = "West", -- Elves (in-game spelling)
	["dreamwalker exiles"] = "West", -- Elves (alt spelling)
	["queen's crown"]      = "West", -- Nuians
	["crescent throne"]    = "West", -- Human
	["andelph"]            = "West", -- Dwarves
	-- Haranya (East)
	["west ishvara"]       = "East", -- Harani (in-game spelling)
	["west ishvaran"]      = "East", -- Harani (alt spelling)
	["wandering winds"]    = "East", -- Firran
	["repentant shadows"]  = "East", -- Warborn
}

-- Substring fallbacks, in case GetFactionName returns a variant spelling.
local FACTION_SIDE_HINTS = {
	{ "pirate", "Pirate" },
	{ "exile", "West" }, { "queen", "West" }, { "andelph", "West" }, { "nuia", "West" },
	{ "ishvara", "East" }, { "wandering wind", "East" }, { "repentant", "East" }, { "haranya", "East" },
}

-- Returns "East", "West", "Pirate" or nil when the faction is unrecognised.
local function getSide(faction)
	if type(faction) ~= "string" then
		return nil
	end
	local f = string.lower(faction)
	local side = FACTION_SIDE[f]
	if side ~= nil then
		return side
	end
	for _, hint in ipairs(FACTION_SIDE_HINTS) do
		if string.find(f, hint[1], 1, true) then
			return hint[2]
		end
	end
	debugLog("no side for faction '" .. faction .. "'")
	return nil
end

local function getGuild(info)
	return pickField(info, {"expeditionName", "expedition_name", "expedition", "guild", "guildName"})
end

local function getClass(unit)
	local ok, class = pcall(function()
		-- Unit:UnitClass only returns a base type (e.g. "mage"), this gives the real class name
		return api.Ability:GetUnitClassName(unit)
	end)
	if not ok or class == nil then
		return nil
	end
	if type(class) == "table" then
		return pickField(class, {"name", "className", "class_name"}) or copyPlain(class)
	end
	return copyPlain(class)
end

local GEAR_SCORE_KEYS = {"gearScore", "gear_score", "gearscore", "total", "score", "value"}

-- Turns a number, numeric string or table holding one into a positive number.
local function toGearScore(value)
	if type(value) == "table" then
		for _, key in ipairs(GEAR_SCORE_KEYS) do
			local found = toGearScore(value[key])
			if found ~= nil then
				return found
			end
		end
		return nil
	end
	local number = tonumber(value)
	if number == nil or number <= 0 then
		return nil
	end
	return number
end

local function getGearScore(unit, info)
	local ok, raw = pcall(function()
		return api.Unit:UnitGearScore(unit)
	end)
	if not ok then
		debugLog("UnitGearScore error: " .. tostring(raw))
		raw = nil
	end
	debugLog("UnitGearScore returned " .. type(raw) .. " '" .. tostring(raw) .. "'")
	if type(raw) == "table" then
		local parts = {}
		for key, value in pairs(raw) do
			parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
		end
		debugLog("UnitGearScore table: " .. table.concat(parts, ", "))
	end
	local gearScore = toGearScore(raw) or toGearScore(info)
	if gearScore == nil then
		return nil
	end
	return copyPlain(gearScore)
end

-- Number from info[key] (at least minimum), stored as a plain value; nil when missing.
local function getNumberField(info, key, minimum)
	if type(info) ~= "table" then
		return nil
	end
	local number = tonumber(info[key])
	if number == nil or number < minimum then
		return nil
	end
	return copyPlain(number)
end

local function getFamily(info)
	return pickField(info, {"family_name", "familyName", "family"})
end

-- buff id => the guild buff read from its tooltip, or false for any other buff; tooltips don't
-- change, so each is only read once a session
local guildBuffs = {}

-- the number after a phrase in a tooltip, colour codes and all, e.g. "Can summon a max of |nc;14|r"
local function tooltipNumber(text, pattern)
	local value = string.match(text, pattern)
	return value and copyPlain(tonumber(value)) or nil
end

local function readGuildBuff(buffId)
	local ok, tooltip = pcall(function()
		return api.Ability:GetBuffTooltip(buffId)
	end)
	if not ok or type(tooltip) ~= "table" then
		return false
	end
	local name = type(tooltip.name) == "string" and tooltip.name or ""
	-- colour codes out: |cFFFF9C27, |nc; and |r
	local text = string.gsub(string.gsub(string.gsub(tostring(tooltip.description or ""), "|c%x%x%x%x%x%x%x%x", ""), "|nc;", ""), "|r", "")
	if not string.find(name, "Kyprosa", 1, true) and not string.find(text, "guild members", 1, true) then
		return false
	end
	return {
		id = copyPlain(buffId),
		summon = tooltipNumber(text, "max of (%d+) guild members"),
		xp = tooltipNumber(text, "XP gain %+(%d+)%%"),
		loot = tooltipNumber(text, "loot drop rate %+(%d+)%%"),
	}
end

-- Their guild buff (Kyprosa's Energy, which grows with the guild): {id, summon, xp, loot}, or nil.
local function getGuildBuff(unit)
	local ok, count = pcall(function()
		return api.Unit:UnitBuffCount(unit)
	end)
	count = ok and tonumber(count) or 0
	for i = 1, count do
		local buffOk, buff = pcall(function()
			return api.Unit:UnitBuff(unit, i)
		end)
		local buffId = buffOk and type(buff) == "table" and tonumber(buff.buff_id) or nil
		if buffId ~= nil then
			if guildBuffs[buffId] == nil then
				guildBuffs[buffId] = readGuildBuff(buffId)
			end
			if guildBuffs[buffId] then
				return guildBuffs[buffId]
			end
		end
	end
	return nil
end

-- Sets the entry's guild buff fields: from the buff when seen, cleared when they have no guild,
-- otherwise left as they were (the buff can be missing for a moment, e.g. while loading in).
local function setGuildBuff(entry, guild, buff)
	if buff ~= nil then
		entry.guild_buff = buff.id
		entry.guild_summon = buff.summon
		entry.guild_xp = buff.xp
		entry.guild_loot = buff.loot
	elseif guild == nil then
		entry.guild_buff = nil
		entry.guild_summon = nil
		entry.guild_xp = nil
		entry.guild_loot = nil
	end
end

local function findPlayer(log, name)
	for _, entry in ipairs(log) do
		if entry.name == name then
			return entry
		end
	end
	return nil
end

-- Players are split into one file per first two letters of their name,
-- e.g. "Madpeter" -> PlayerDB/Players/ma.dat
local function playerPath(name)
	local prefix = string.lower(string.sub(name, 1, 2))
	if not string.find(prefix, "^%w%w$") then
		prefix = "_other"
	end
	return PLAYERS_DIR .. prefix .. ".dat"
end

local function readList(path)
	local log = api.File:Read(path)
	if type(log) ~= "table" then
		return {}
	end
	return log
end

local function readCount()
	local stats = api.File:Read(COUNT_PATH)
	if type(stats) ~= "table" then
		return 0
	end
	return tonumber(stats.players) or 0
end

local function writeCount(count)
	api.File:Write(COUNT_PATH, { players = copyPlain(count), addon_version = addoninfo.version })
end

-- A batch caches the player files touched during one pass (a target change or a raid scan)
-- so each file is read and written once, and _count.dat is only updated once.
local function newBatch()
	return { lists = {}, dirty = {}, added = 0 }
end

local function batchList(batch, path)
	local log = batch.lists[path]
	if log == nil then
		log = readList(path)
		batch.lists[path] = log
		debugLog(path .. " has " .. #log .. " entries")
	end
	return log
end

local function flushBatch(batch)
	for path in pairs(batch.dirty) do
		datafiles.Write(PLAYERS_DIR, path, batch.lists[path])
	end
	if batch.added == 0 then
		return 0
	end
	local count = readCount() + batch.added
	writeCount(count)
	return count
end

-- Records the player behind a unit token ("target", "team1".."team50", ...) into the batch.
local function recordUnit(unit, batch)
	local unitId = api.Unit:GetUnitId(unit)
	if unitId == nil then
		debugLog("no unit id for " .. unit)
		return
	end

	local info = api.Unit:GetUnitInfoById(unitId)
	dumpInfo(info)
	if not isPlayer(info) then
		debugLog(unit .. " " .. tostring(unitId) .. " is not a player")
		return
	end

	local name = api.Unit:UnitName(unit)
	if name == nil or name == "" then
		debugLog(unit .. " has no name")
		return
	end

	local guild = getGuild(info)
	local faction = getFaction(unit, info)
	local side = getSide(faction)
	local class = getClass(unit)
	local gearScore = getGearScore(unit, info)
	local level = getNumberField(info, "level", 1)
	-- 0 is a real heir level (none earned yet)
	local heirLevel = getNumberField(info, "heirLevel", 0)
	-- only party/raid members show their family
	local family = getFamily(info)
	local guildBuffOk, guildBuff = pcall(getGuildBuff, unit)
	if not guildBuffOk then
		debugLog("guild buff error: " .. tostring(guildBuff))
		guildBuff = nil
	end
	local seen = clock.NowText()
	debugLog(unit .. " player '" .. name .. "' guild '" .. tostring(guild) .. "' faction '" .. tostring(faction)
		.. "' side '" .. tostring(side) .. "' class '" .. tostring(class) .. "' gs '" .. tostring(gearScore)
		.. "' level '" .. tostring(level) .. "' heir '" .. tostring(heirLevel) .. "' family '" .. tostring(family)
		.. "' guild buff '" .. tostring(guildBuff and guildBuff.id) .. "'")

	local path = playerPath(name)
	local log = batchList(batch, path)
	batch.dirty[path] = true

	local existing = findPlayer(log, name)
	if existing == nil then
		local entry = {
			name = name,
			guild = guild,
			family = family,
			faction = faction,
			side = side,
			class = class,
			gear_score = gearScore,
			level = level,
			heir_level = heirLevel or "0",
			first_seen = seen,
			last_seen = seen,
			addon_version = addoninfo.version,
		}
		setGuildBuff(entry, guild, guildBuff)
		log[#log + 1] = entry
		batch.added = batch.added + 1
		logbook.Chat(11, "[PlayerDB] New player " .. name
			.. " <" .. tostring(guild or "no guild") .. "> (" .. tostring(faction or "unknown")
			.. ", " .. tostring(side or "unknown side") .. ") "
			.. tostring(class or "unknown class") .. " GS " .. tostring(gearScore or "?") .. ".")
		return
	end

	local changes = {}
	if guild ~= existing.guild then
		changes[#changes + 1] = "guild " .. tostring(existing.guild or "none") .. " -> " .. tostring(guild or "none")
		existing.guild = guild
	end
	if faction ~= nil and faction ~= existing.faction then
		changes[#changes + 1] = "faction " .. tostring(existing.faction or "unknown") .. " -> " .. faction
		existing.faction = faction
	end
	if side ~= nil and side ~= existing.side then
		if existing.side ~= nil then
			changes[#changes + 1] = "side " .. existing.side .. " -> " .. side
		end
		existing.side = side
	end
	-- class (skillset swaps), gear score and levels change often, update silently
	if class ~= nil then
		existing.class = class
	end
	if gearScore ~= nil then
		existing.gear_score = gearScore
	end
	if level ~= nil then
		existing.level = level
	end
	if heirLevel ~= nil then
		existing.heir_level = heirLevel
	elseif existing.heir_level == nil then
		existing.heir_level = "0"
	end
	-- seen on raid members only: a target without one keeps what was seen before
	if family ~= nil then
		existing.family = family
	end
	-- stats were logged by 1.1.0, no longer kept
	existing.max_health = nil
	existing.max_mana = nil
	existing.stats = nil
	setGuildBuff(existing, guild, guildBuff)
	existing.last_seen = seen
	existing.addon_version = addoninfo.version

	if #changes > 0 then
		logbook.Chat(3, "[PlayerDB] " .. name .. " changed: " .. table.concat(changes, ", "))
	end
end

local function reportCount(count)
	if count > 0 then
		logbook.Chat(11, "[PlayerDB] You now have " .. count .. " players logged")
	end
end

-- Calls fn and returns a plain copy of its results; nil shows as "<nil>", errors as "<error: ...>".
local function plainOrNil(value)
	if value == nil then
		return "<nil>"
	end
	return copyPlain(value)
end

-- the addon sandbox has no select(), so capture up to 4 return values (enough for x, y, z)
local function probe(fn)
	local ok, a, b, c, d = pcall(fn)
	if not ok then
		return "<error: " .. tostring(a) .. ">"
	end
	if b == nil and c == nil and d == nil then
		return plainOrNil(a)
	end
	local out = { plainOrNil(a), plainOrNil(b) }
	if c ~= nil or d ~= nil then
		out[3] = plainOrNil(c)
	end
	if d ~= nil then
		out[4] = plainOrNil(d)
	end
	return out
end

local function probeList(countFn, itemFn)
	local ok, count = pcall(countFn)
	count = ok and tonumber(count) or 0
	local out = {}
	for i = 1, count do
		out[i] = probe(function()
			return itemFn(i)
		end)
	end
	return out
end

local MAX_TEAM_MEMBERS = 50

-- adds each buff's tooltip text, to identify passives like heir level by name
local function addBuffTooltips(list)
	for _, buff in ipairs(list) do
		local buffId = type(buff) == "table" and tonumber(buff.buff_id) or nil
		if buffId ~= nil then
			buff.tooltip = probe(function() return api.Ability:GetBuffTooltip(buffId) end)
		end
	end
	return list
end

-- Everything the API returns for a player unit, or nil when the unit is not a player.
local function buildDump(unit)
	local unitId = api.Unit:GetUnitId(unit)
	if unitId == nil or not isPlayer(api.Unit:GetUnitInfoById(unitId)) then
		return nil
	end
	local U = api.Unit
	local dump = {
		unit = unit,
		unitId = copyPlain(unitId),
		name = probe(function() return U:UnitName(unit) end),
		nameById = probe(function() return U:GetUnitNameById(unitId) end),
		unitInfoById = probe(function() return U:GetUnitInfoById(unitId) end),
		unitInfo = probe(function() return U:UnitInfo(unit) end),
		unitModifierInfo = probe(function() return U:UnitModifierInfo(unit) end),
		class = probe(function() return U:UnitClass(unit) end),
		classNameAbility = probe(function() return api.Ability:GetUnitClassName(unit) end),
		gearScore = probe(function() return U:UnitGearScore(unit) end),
		faction = probe(function() return U:GetFactionName(unit) end),
		health = probe(function() return U:UnitHealth(unit) end),
		maxHealth = probe(function() return U:UnitMaxHealth(unit) end),
		mana = probe(function() return U:UnitMana(unit) end),
		maxMana = probe(function() return U:UnitMaxMana(unit) end),
		distance = probe(function() return U:UnitDistance(unit) end),
		worldPosition = probe(function() return U:UnitWorldPosition(unit) end),
		isOffline = probe(function() return U:UnitIsOffline(unit) end),
		isTeamMember = probe(function() return U:UnitIsTeamMember(unit) end),
		isForceAttack = probe(function() return U:UnitIsForceAttack(unit) end),
		teamAuthority = probe(function() return U:UnitTeamAuthority(unit) end),
		lunagems = probe(function() return api.Equipment:GetEquippedSkillsetLunagems(unit) end),
		buffs = addBuffTooltips(probeList(function() return U:UnitBuffCount(unit) end,
			function(i) return U:UnitBuff(unit, i) end)),
		debuffs = addBuffTooltips(probeList(function() return U:UnitDeBuffCount(unit) end,
			function(i) return U:UnitDeBuff(unit, i) end)),
	}
	if string.find(unit, "^team") then
		dump.memberIndex = probe(function() return api.Team:GetMemberIndexByName(U:UnitName(unit)) end)
	end
	return dump
end

local function dumpUnit(unit)
	local dump = buildDump(unit)
	if dump == nil then
		return
	end
	api.File:Write(DUMP_PATH, dump)
	debugLog("dumped " .. unit .. " to " .. DUMP_PATH)
end

-- every member present, in range or not, keyed by unit token
local function dumpRaid(selfId)
	local dump = {}
	local dumped = 0
	for i = 1, MAX_TEAM_MEMBERS do
		local unit = "team" .. i
		local unitId = api.Unit:GetUnitId(unit)
		if unitId ~= nil and unitId ~= selfId then
			local ok, memberDump = pcall(buildDump, unit)
			if not ok then
				memberDump = "<error: " .. tostring(memberDump) .. ">"
			end
			if memberDump ~= nil then
				dump[unit] = memberDump
				dumped = dumped + 1
			end
		end
	end
	if dumped > 0 then
		api.File:Write(RAID_DUMP_PATH, dump)
		debugLog("dumped " .. dumped .. " raid members to " .. RAID_DUMP_PATH)
	end
end

function logbook.LogTarget()
	local batch = newBatch()
	recordUnit("target", batch)
	reportCount(flushBatch(batch))
	if DUMP_TARGET then
		dumpUnit("target")
	end
end

-- Logs your own character, so your entry stays current like any other player.
function logbook.LogSelf()
	local batch = newBatch()
	recordUnit("player", batch)
	reportCount(flushBatch(batch))
end

-- only log members close enough to be inspected, like a target would be
local MAX_SCAN_DISTANCE = 30

local function inScanRange(unit)
	local ok, distance = pcall(function()
		return api.Unit:UnitDistance(unit)
	end)
	distance = ok and tonumber(distance) or nil
	if distance == nil or distance > MAX_SCAN_DISTANCE then
		debugLog(unit .. " out of range (" .. tostring(distance) .. "m)")
		return false
	end
	return true
end

-- Logs every member of your party/raid as if you had targeted them.
-- Returns how many other members are in the team (in range or not), 0 when not in one.
function logbook.ScanRaid()
	local selfId = api.Unit:GetUnitId("player")
	local batch = newBatch()
	local members = 0
	local scanned = 0
	for i = 1, MAX_TEAM_MEMBERS do
		local unit = "team" .. i
		local unitId = api.Unit:GetUnitId(unit)
		if unitId ~= nil and unitId ~= selfId then
			members = members + 1
		end
		if unitId ~= nil and unitId ~= selfId and inScanRange(unit) then
			-- one bad member must not stop the rest of the scan
			local ok, err = pcall(recordUnit, unit, batch)
			if ok then
				scanned = scanned + 1
			else
				api.Log:Info("[PlayerDB] error scanning " .. unit .. ": " .. tostring(err))
				logbook.Chat(3, "[PlayerDB] error scanning " .. unit .. ": " .. tostring(err))
			end
		end
	end
	debugLog("raid scan checked " .. scanned .. "/" .. members .. " members, " .. batch.added .. " new")
	reportCount(flushBatch(batch))
	if DUMP_RAID then
		dumpRaid(selfId)
	end
	return members
end

-- Empties every player file and zeroes the count. Returns how many files were emptied.
function logbook.ResetData()
	local emptied = datafiles.Reset(PLAYERS_DIR)
	writeCount(0)
	return emptied
end

return logbook
