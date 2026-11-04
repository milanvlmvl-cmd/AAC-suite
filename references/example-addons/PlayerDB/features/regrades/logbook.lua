local api = require("api")
local addoninfo = require("PlayerDB/addoninfo")
local datafiles = require("PlayerDB/datafiles")
local clock = require("PlayerDB/clock")

local logbook = {}

local REGRADES_DIR = "PlayerDB/Regrades/"
local COUNT_PATH = REGRADES_DIR .. "_count.dat"
-- errors go here instead of chat; only the newest are kept
local ERRORS_PATH = "PlayerDB/regrade_errors.dat"
local MAX_ERRORS = 20
-- dev: every GRADE_ENCHANT_BROADCAST received, with what happened to it (newest TRACE_MAX kept)
local TRACE = true
local TRACE_PATH = "PlayerDB/regrade_trace.dat"
local TRACE_MAX = 20

-- GRADE_ENCHANT_BROADCAST result codes (same values loss_porn uses)
local RESULT_BREAK = 0
local RESULT_DOWNGRADE = 1
local RESULT_FAIL = 2
local RESULT_SUCCESS = 3
local RESULT_GREAT_SUCCESS = 4

-- result code -> stored name; unknown codes are ignored
local RESULT_NAMES = {
	[RESULT_BREAK] = "destroyed",
	[RESULT_DOWNGRADE] = "downgraded",
	[RESULT_FAIL] = "anchored",
	[RESULT_SUCCESS] = "upgraded",
	[RESULT_GREAT_SUCCESS] = "great_success",
}

-- stored names that count as a loss; the rest count as a success
local LOSSES = {
	destroyed = true,
	downgraded = true,
	anchored = true,
}

-- how a result reads in Describe
local RESULT_VERBS = {
	great_success = "great-success upgraded",
}

-- grade ids as loss_porn names them
local GRADE_NAMES = {
	[1] = "Basic",
	[2] = "Grand",
	[3] = "Rare",
	[4] = "Arcane",
	[5] = "Heroic",
	[6] = "Unique",
	[7] = "Celestial",
	[8] = "Divine",
	[9] = "Epic",
	[10] = "Legendary",
	[11] = "Mythic",
}

local function safeCall(fn)
	local ok, result = pcall(fn)
	if not ok then
		return nil
	end
	return result
end

local function numberToString(value)
	if value == math.floor(value) then
		return string.format("%.0f", value)
	end
	return string.format("%.14g", value)
end

-- ---------------------------------------------------------------------------
-- Time
-- Unix seconds (UTC) from clock.lua, which keeps time between the game's coarse time steps.
-- ---------------------------------------------------------------------------

local function currentTime()
	local now = tonumber(safeCall(clock.Now))
	if now == nil then
		return nil
	end
	return math.floor(now)
end

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------

-- item links read like "|i<itemType>,...": the item type is the number after "|i"
local function itemTypeFromLink(link)
	if type(link) ~= "string" then
		return nil
	end
	return tonumber(string.match(string.sub(link, 3), "^(%d+)"))
end

local function itemName(itemType)
	if itemType == nil then
		return nil
	end
	local info = safeCall(function() return api.Item:GetItemInfoByType(itemType) end)
	if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
		return info.name
	end
	return nil
end

local function gradeName(gradeId)
	return GRADE_NAMES[tonumber(gradeId)]
end

-- ---------------------------------------------------------------------------
-- Storage
-- Regrades are split into one file per first two letters of the character (as players are),
-- e.g. al.dat; names that don't start with two letters/digits go to _other.dat. _count.dat keeps the totals.
-- ---------------------------------------------------------------------------

local function characterPath(name)
	local prefix = string.lower(string.sub(name, 1, 2))
	if not string.find(prefix, "^%w%w$") then
		prefix = "_other"
	end
	return REGRADES_DIR .. prefix .. ".dat"
end

local function readList(path)
	local list = api.File:Read(path)
	if type(list) ~= "table" then
		return {}
	end
	return list
end

local function readCounts()
	local stats = api.File:Read(COUNT_PATH)
	local counts = { regrades = 0, losses = 0, successes = 0 }
	for _, name in pairs(RESULT_NAMES) do
		counts[name] = 0
	end
	if type(stats) ~= "table" then
		return counts
	end
	for key in pairs(counts) do
		counts[key] = tonumber(stats[key]) or 0
	end
	return counts
end

local function writeCounts(counts)
	local out = {}
	for key, value in pairs(counts) do
		out[key] = numberToString(value)
	end
	out.addon_version = addoninfo.version
	api.File:Write(COUNT_PATH, out)
end

-- ---------------------------------------------------------------------------
-- Public
-- ---------------------------------------------------------------------------

-- the same broadcast can arrive twice; an identical entry within the same second is that repeat
local function isDuplicate(list, entry)
	for i = #list, 1, -1 do
		local other = list[i]
		if other.time ~= entry.time then
			return false
		end
		if other.character == entry.character and other.result == entry.result and other.item == entry.item
			and other.old_grade_id == entry.old_grade_id and other.new_grade_id == entry.new_grade_id then
			return true
		end
	end
	return false
end

-- Saves one regrade, failed or not. source is "broadcast" (GRADE_ENCHANT_BROADCAST, anyone's) or
-- "self" (GRADE_ENCHANT_RESULT, your own). Returns the saved entry, or nil (also when it repeats one already saved).
function logbook.LogRegrade(characterName, resultCode, itemLink, oldGrade, newGrade, source)
	local result = RESULT_NAMES[tonumber(resultCode)]
	if result == nil then
		logbook.LogError("unknown regrade result " .. tostring(resultCode) .. " by " .. tostring(characterName))
		return nil
	end
	local seen = currentTime()
	if seen == nil then
		logbook.LogError("no local time, regrade by " .. tostring(characterName) .. " not saved")
		return nil
	end
	local itemType = itemTypeFromLink(itemLink)

	local entry = {
		character = tostring(characterName),
		result = result,
		item = itemName(itemType),
		old_grade_id = tonumber(oldGrade) and numberToString(tonumber(oldGrade)) or nil,
		new_grade_id = tonumber(newGrade) and numberToString(tonumber(newGrade)) or nil,
		time = numberToString(seen),
		source = source,
		addon_version = addoninfo.version,
	}

	local path = characterPath(entry.character)
	local list = readList(path)
	if isDuplicate(list, entry) then
		return nil
	end
	list[#list + 1] = entry
	datafiles.Write(REGRADES_DIR, path, list)

	local counts = readCounts()
	counts.regrades = counts.regrades + 1
	if LOSSES[result] then
		counts.losses = counts.losses + 1
	else
		counts.successes = counts.successes + 1
	end
	counts[result] = counts[result] + 1
	writeCounts(counts)
	return entry
end

logbook.DESTROYED = RESULT_NAMES[RESULT_BREAK]

function logbook.IsLoss(entry)
	return LOSSES[entry.result] == true
end

-- short description of a saved entry, e.g. "Bob destroyed Hiram Cloak (Celestial)"
-- or "Bob upgraded Hiram Cloak (Celestial -> Divine)"
function logbook.Describe(entry)
	local item = entry.item or "an item"
	local grade = gradeName(entry.old_grade_id)
	local newGrade = gradeName(entry.new_grade_id)
	if grade ~= nil and newGrade ~= nil and newGrade ~= grade then
		grade = grade .. " -> " .. newGrade
	end
	return entry.character .. " " .. (RESULT_VERBS[entry.result] or entry.result) .. " " .. item
		.. (grade and (" (" .. grade .. ")") or "")
end

-- keeps the newest MAX_ERRORS messages in ERRORS_PATH
function logbook.LogError(message)
	local list = readList(ERRORS_PATH)
	local seen = currentTime()
	list[#list + 1] = {
		time = seen and numberToString(seen) or nil,
		message = tostring(message),
	}
	while #list > MAX_ERRORS do
		table.remove(list, 1)
	end
	api.File:Write(ERRORS_PATH, list)
end

-- dev: records a received broadcast and its outcome ("saved", "duplicate", "disabled", "error: ...")
function logbook.Trace(outcome, characterName, resultCode, itemLink, oldGrade, newGrade)
	if not TRACE then
		return
	end
	local list = readList(TRACE_PATH)
	local seen = currentTime()
	list[#list + 1] = {
		time = seen and numberToString(seen) or nil,
		outcome = tostring(outcome),
		character = tostring(characterName),
		result_code = tostring(resultCode),
		item_link = tostring(itemLink),
		old_grade = tostring(oldGrade),
		new_grade = tostring(newGrade),
		addon_version = addoninfo.version,
	}
	while #list > TRACE_MAX do
		table.remove(list, 1)
	end
	api.File:Write(TRACE_PATH, list)
end

-- totals: regrades, losses, successes, and one per result name
-- Empties every regrade file and zeroes the totals. Returns how many files were emptied.
function logbook.ResetData()
	local emptied = datafiles.Reset(REGRADES_DIR)
	local counts = readCounts()
	for key in pairs(counts) do
		counts[key] = 0
	end
	writeCounts(counts)
	return emptied
end

function logbook.Counts()
	return readCounts()
end

return logbook
