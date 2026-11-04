local api = require("api")

-- The raid being recorded: who was in it and every item that dropped.
-- While recording, everything is kept in current.dat so a reload or crash resumes the raid;
-- Finish() moves it to Raids/<start date>.dat.
local raidlog = {}

local ADDON_DIR = "RaidsDB/"
local RAIDS_DIR = ADDON_DIR .. "Raids/"
local CURRENT_PATH = ADDON_DIR .. "current.dat"
-- rewritten on raid start, end and every drop so an outside tool can take a screenshot
local SCREENSHOT_REQUEST_PATH = RAIDS_DIR .. "request.sht"
-- optional: { items = { ["Item Name"] = true, ... } }, drops of these items ask for no screenshot
local IGNORE_PATH = ADDON_DIR .. "ignore.dat"
-- errors go here instead of chat; only the newest are kept
local ERRORS_PATH = ADDON_DIR .. "errors.dat"
local MAX_ERRORS = 20
local MAX_TEAM_MEMBERS = 50
-- ADDED_ITEM's third argument says where the item came from; these are loot
-- (crafting, buying, mail etc. use other codes and are not drops). Turn DEBUG on to see
-- the codes of items that were left out.
local ADDED_ITEM_LOOT = {
	[10] = true,
	[35] = true,
}

-- dev: keep the raw arguments of every loot event (also the ones not saved as drops) and
-- write a copy of the raid with them next to it, as Raids/<start date>.raw
local DEBUG = false
local MAX_RAW_EVENTS = 1000
local RAW_ARG_COUNT = 8

local raid = nil
-- screenshot requests made since load, part of each request's id
local requestCount = 0
-- item names from IGNORE_PATH, read when a raid starts or resumes
local ignoredItems = {}
-- RaidsDB's version, saved with each raid; set from main.lua
local addonVersion = nil

local function safeCall(fn)
	local ok, result = pcall(fn)
	if not ok then
		return nil
	end
	return result
end

-- File:Write rounds big numbers (8000641 -> 8.00064e+006), so numbers are saved as strings
local function numberToString(value)
	if value == math.floor(value) then
		return string.format("%.0f", value)
	end
	return string.format("%.14g", value)
end

local function count(map)
	local total = 0
	for _ in pairs(map) do
		total = total + 1
	end
	return total
end

-- ---------------------------------------------------------------------------
-- Time
-- api.Time:GetLocalTime() gives unix seconds (UTC) as a string, exact to the second; this is
-- what WorldSatNav saves in its location file. The game's Lua numbers are single precision,
-- so tonumber() on it would only move in steps of 128s. Times are kept as those strings
-- ("1792106676") and the maths below works on them in pieces small enough to stay exact.
-- ---------------------------------------------------------------------------

-- the current unix time as a string of digits, or nil
local function now()
	local value = safeCall(function() return api.Time:GetLocalTime() end)
	if type(value) == "number" then
		value = string.format("%.0f", value)
	end
	if type(value) ~= "string" or not string.match(value, "^%d+$") then
		return nil
	end
	return value
end

-- "1792106676" -> 17921, 6676 (high * 100000 + low), both exact
local function splitTime(unix)
	return tonumber(string.sub(unix, 1, -6)) or 0, tonumber(string.sub(unix, -5)) or 0
end

-- whole seconds from one unix time string to another
local function secondsBetween(from, to)
	local fromHigh, fromLow = splitTime(from)
	local toHigh, toLow = splitTime(to)
	return (toHigh - fromHigh) * 100000 + (toLow - fromLow)
end

local function isLeapYear(year)
	return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

-- unix time string -> year, month, day, hour, minute, second (UTC)
local function dateParts(unix)
	-- long division by a day's seconds, one digit at a time so every step stays exact
	local days, rest = 0, 0
	for digit in string.gmatch(unix, "%d") do
		rest = rest * 10 + tonumber(digit)
		local whole = math.floor(rest / 86400)
		days = days * 10 + whole
		rest = rest - whole * 86400
	end
	local year = 1970
	while days >= (isLeapYear(year) and 366 or 365) do
		days = days - (isLeapYear(year) and 366 or 365)
		year = year + 1
	end
	local monthDays = { 31, isLeapYear(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	local month = 1
	while days >= monthDays[month] do
		days = days - monthDays[month]
		month = month + 1
	end
	return year, month, days + 1, math.floor(rest / 3600), math.floor(rest % 3600 / 60), rest % 60
end

-- "2026-10-15 22:40:05"
local function dateText(unix)
	return string.format("%04d-%02d-%02d %02d:%02d:%02d", dateParts(unix))
end

-- "2026-10-15_22-40-05", safe as a file name
local function fileDate(unix)
	return string.format("%04d-%02d-%02d_%02d-%02d-%02d", dateParts(unix))
end

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	if minutes < 60 then
		return minutes .. "m"
	end
	return math.floor(minutes / 60) .. "h " .. (minutes % 60) .. "m"
end

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------

-- item links read like "|i<itemType>,...": the item type is the number after "|i"
local function itemTypeFromLink(link)
	return tonumber(string.match(link, "^|i(%d+)"))
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

-- strings and numbers as File:Write can keep them, anything else as "<type>"
local function plainArg(value)
	if type(value) == "number" then
		return numberToString(value)
	elseif type(value) == "string" or type(value) == "boolean" then
		return value
	elseif value == nil then
		return "<nil>"
	end
	return "<" .. type(value) .. ">"
end

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

local function saveCurrent()
	api.File:Write(CURRENT_PATH, raid or { recording = false })
end

-- The addon can't take a screenshot itself and can't delete files, so each request
-- overwrites SCREENSHOT_REQUEST_PATH with a new id; the outside tool watches it for changes.
-- raidStarted is the unix start time of the raid the request belongs to.
local function requestScreenshot(request, raidStarted)
	local at = now() or "0"
	requestCount = requestCount + 1
	request.id = at .. "-" .. numberToString(requestCount)
	request.time = at
	request.time_text = dateText(at)
	request.raid_started = raidStarted
	request.raid_started_text = dateText(raidStarted)
	api.File:Write(SCREENSHOT_REQUEST_PATH, request)
end

-- reads IGNORE_PATH; no file means nothing is ignored
local function loadIgnoredItems()
	ignoredItems = {}
	local saved = safeCall(function() return api.File:Read(IGNORE_PATH) end)
	if type(saved) ~= "table" or type(saved.items) ~= "table" then
		return
	end
	for key, value in pairs(saved.items) do
		if type(key) == "string" and value then
			ignoredItems[key] = true
		elseif type(value) == "string" then
			-- also take a plain list of names
			ignoredItems[value] = true
		end
	end
end

-- keeps the newest MAX_ERRORS messages in ERRORS_PATH
function raidlog.LogError(message)
	local list = api.File:Read(ERRORS_PATH)
	if type(list) ~= "table" then
		list = {}
	end
	list[#list + 1] = {
		time = now(),
		message = tostring(message),
	}
	while #list > MAX_ERRORS do
		table.remove(list, 1)
	end
	api.File:Write(ERRORS_PATH, list)
end

-- ---------------------------------------------------------------------------
-- Players
-- ---------------------------------------------------------------------------

-- Each member keeps a list of stays, { joined = <unix>, left = <unix> }, so leaving and
-- rejoining later shows as two stays; the last one has no left while they are still here.
local function openStay(member)
	if type(member.stays) ~= "table" then
		return nil
	end
	local last = member.stays[#member.stays]
	if last ~= nil and last.left == nil then
		return last
	end
	return nil
end

-- total seconds over the member's finished stays
local function timeInRaid(member)
	local total = 0
	for _, stay in ipairs(member.stays or {}) do
		if stay.joined ~= nil and stay.left ~= nil then
			total = total + secondsBetween(stay.joined, stay.left)
		end
	end
	return total
end

-- dev: what each team slot gave in the last scan, saved as raid.scan_debug
local scanDebug = nil

local function noteSlot(unit, unitId, name, byId)
	if scanDebug == nil or (unitId == nil and name == nil and byId == nil) then
		return
	end
	scanDebug[unit] = {
		unit_id = plainArg(unitId),
		name = plainArg(name),
		name_by_id = plainArg(byId),
		offline = plainArg(safeCall(function() return api.Unit:UnitIsOffline(unit) end)),
		distance = plainArg(safeCall(function() return api.Unit:UnitDistance(unit) end)),
	}
end

-- Returns the member's name; nil if nobody is in that slot, or nil, true if somebody is but
-- their name can't be read yet (they only just joined or are still loading).
local function recordMember(unit, seen)
	-- the name comes first: members too far away to be loaded can have no unit id but still
	-- have a name, like on the raid frames
	local name = safeCall(function() return api.Unit:UnitName(unit) end)
	local unitId = safeCall(function() return api.Unit:GetUnitId(unit) end)
	local byId = nil
	if (type(name) ~= "string" or name == "") and unitId ~= nil then
		byId = safeCall(function() return api.Unit:GetUnitNameById(unitId) end)
	end
	noteSlot(unit, unitId, name, byId)
	if type(name) ~= "string" or name == "" then
		name = byId
	end
	if type(name) ~= "string" or name == "" then
		if unitId == nil then
			return nil
		end
		return nil, true
	end
	local member = raid.members[name]
	if member == nil then
		member = { name = name, first_seen = seen }
		raid.members[name] = member
	end
	if type(member.stays) ~= "table" then
		member.stays = {}
	end
	if openStay(member) == nil then
		member.stays[#member.stays + 1] = { joined = seen }
	end
	member.last_seen = seen
	-- a unit id means the game had them loaded near you at least once, not only on the raid list
	if unitId ~= nil then
		member.seenWithRaid = true
	elseif member.seenWithRaid == nil then
		member.seenWithRaid = false
	end
	-- out of range members may not give a class yet; a later scan fills it in
	local class = safeCall(function() return api.Ability:GetUnitClassName(unit) end)
	if type(class) == "string" and class ~= "" then
		member.class = class
	end
	return name
end

-- ends the stay of everyone not in present (everyone when present is nil)
local function closeStays(present, at)
	for name, member in pairs(raid.members) do
		local stay = openStay(member)
		if stay ~= nil and (present == nil or not present[name]) then
			stay.left = at
			member.last_seen = at
		end
	end
end

-- Adds everyone currently in the party/raid (and yourself) and marks who has left.
-- Returns how many were seen, and whether everyone could be read.
function raidlog.ScanMembers()
	local seen = now()
	if raid == nil or seen == nil then
		return 0, false
	end
	local present = {}
	local found = 0
	local unreadable = false
	scanDebug = DEBUG and {} or nil
	for i = 1, MAX_TEAM_MEMBERS do
		local name, missed = recordMember("team" .. i, seen)
		if name ~= nil then
			present[name] = true
			found = found + 1
		elseif missed then
			unreadable = true
		end
	end
	local own = recordMember("player", seen)
	if own ~= nil then
		present[own] = true
	end
	-- only a full scan says who has left: an unreadable slot may be someone still here, and
	-- not even reading yourself (loading screen etc.) is no sign that everyone left
	local complete = own ~= nil and not unreadable
	if complete then
		closeStays(present, seen)
	end
	raid.scan_debug = scanDebug
	scanDebug = nil
	saveCurrent()
	return found, complete
end

-- ---------------------------------------------------------------------------
-- Drops
-- ---------------------------------------------------------------------------

-- the same broadcast can arrive twice; an identical drop within the same second is that repeat
local function isDuplicate(entry)
	for i = #raid.drops, 1, -1 do
		local other = raid.drops[i]
		if other.time ~= entry.time then
			return false
		end
		if other.player == entry.player and other.item == entry.item and other.count == entry.count then
			return true
		end
	end
	return false
end

local function ownName()
	local name = safeCall(function() return api.Unit:UnitName("player") end)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return nil
end

local function recordRaw(event, args)
	if raid.raw_events == nil then
		raid.raw_events = {}
	end
	if #raid.raw_events >= MAX_RAW_EVENTS then
		return
	end
	local raw = {}
	for i = 1, RAW_ARG_COUNT do
		raw[i] = plainArg(args[i])
	end
	raid.raw_events[#raid.raw_events + 1] = {
		time = now(),
		event = event,
		args = raw,
	}
end

-- Records one loot event:
--   ITEM_ACQUISITION_BY_LOOT(player, link, count) everyone in the raid except you
--   ADDED_ITEM(link, count, source, "")          your own items; only kept when looted
-- Returns the saved drop, or nil (not recording, not a drop, or a repeat).
function raidlog.AddDrop(event, a1, a2, a3, a4, a5, a6, a7, a8)
	if raid == nil then
		return nil
	end
	if DEBUG then
		recordRaw(event, { a1, a2, a3, a4, a5, a6, a7, a8 })
		saveCurrent()
	end
	local player, link, amount
	if event == "ADDED_ITEM" then
		if not ADDED_ITEM_LOOT[tonumber(a3)] then
			return nil
		end
		player, link, amount = ownName(), a1, a2
	else
		player, link, amount = a1, a2, a3
	end
	if type(link) ~= "string" then
		return nil
	end

	local entry = {
		time = now(),
		player = type(player) == "string" and player or "?",
		item = itemName(itemTypeFromLink(link)) or "?",
		count = numberToString(tonumber(amount) or 1),
	}
	if isDuplicate(entry) then
		return nil
	end
	raid.drops[#raid.drops + 1] = entry
	saveCurrent()
	if ignoredItems[entry.item] then
		return entry
	end
	requestScreenshot({ reason = "drop", player = entry.player, item = entry.item, count = entry.count },
		raid.started)
	return entry
end

-- ---------------------------------------------------------------------------
-- Raid
-- ---------------------------------------------------------------------------

function raidlog.SetAddonVersion(version)
	addonVersion = version
end

function raidlog.IsRecording()
	return raid ~= nil
end

-- Picks up a raid that was still recording when the addon was unloaded. Returns true if one was.
function raidlog.Resume()
	local saved = api.File:Read(CURRENT_PATH)
	if type(saved) ~= "table" or saved.recording ~= true or saved.started == nil then
		return false
	end
	raid = saved
	raid.members = type(raid.members) == "table" and raid.members or {}
	raid.drops = type(raid.drops) == "table" and raid.drops or {}
	if not DEBUG then
		raid.raw_events = nil
	end
	loadIgnoredItems()
	return true
end

function raidlog.Start()
	loadIgnoredItems()
	local started = now() or "0"
	raid = {
		recording = true,
		started = started,
		started_text = dateText(started),
		addon_version = addonVersion,
		members = {},
		drops = {},
	}
	raidlog.ScanMembers()
	requestScreenshot({ reason = "start" }, started)
end

-- Stops recording and writes the raid to Raids/. Returns the file path and the totals.
function raidlog.Finish()
	if raid == nil then
		return nil
	end
	raidlog.ScanMembers()
	local started = raid.started
	local ended = now() or started
	closeStays(nil, ended)
	for _, member in pairs(raid.members) do
		member.time_in_raid = formatDuration(timeInRaid(member))
	end
	raid.recording = nil
	raid.scan_debug = nil
	-- left by older versions, which timed raids with the UI clock
	raid.started_msec = nil
	raid.last_elapsed = nil
	raid.ended = ended
	raid.ended_text = dateText(ended)
	raid.duration = formatDuration(secondsBetween(started, ended))
	raid.player_count = numberToString(count(raid.members))
	raid.drop_count = numberToString(#raid.drops)

	local name = RAIDS_DIR .. fileDate(started)
	local path = name .. ".dat"
	local raw = raid.raw_events
	raid.raw_events = nil
	api.File:Write(path, raid)
	if DEBUG then
		raid.raw_events = raw or {}
		api.File:Write(name .. ".raw", raid)
	end
	local totals = { players = raid.player_count, drops = raid.drop_count, duration = raid.duration }
	raid = nil
	saveCurrent()
	requestScreenshot({ reason = "end", raid = path }, started)
	return path, totals
end

-- Text for the button's tooltip.
function raidlog.StatusText()
	if raid == nil then
		return "Raid drops: not recording\nClick to start a new raid"
	end
	local text = "Raid drops: recording\nStarted " .. tostring(raid.started_text)
		.. " (" .. formatDuration(secondsBetween(raid.started, now() or raid.started)) .. " ago)"
	local here = 0
	for _, member in pairs(raid.members) do
		if openStay(member) ~= nil then
			here = here + 1
		end
	end
	text = text .. "\nPlayers: " .. here .. " here, " .. count(raid.members) .. " in total, drops: " .. #raid.drops
	local last = raid.drops[#raid.drops]
	if last ~= nil then
		text = text .. "\nLast: " .. last.player .. " looted " .. last.item
			.. (last.count ~= "1" and (" x" .. last.count) or "")
	end
	return text .. "\nClick to stop and save"
end

return raidlog
