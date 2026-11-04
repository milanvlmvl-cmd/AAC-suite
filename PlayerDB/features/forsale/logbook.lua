local api = require("api")
local addoninfo = require("PlayerDB/addoninfo")
local datafiles = require("PlayerDB/datafiles")
local clock = require("PlayerDB/clock")

-- ForSale, first pass: records every house sale event raw, to find out what the client provides.
-- Each entry keeps the event name, every argument (with its type) and where you were at the time.
local logbook = {}

local FORSALE_DIR = "PlayerDB/ForSale/"
local EVENTS_PATH = FORSALE_DIR .. "events.dat"
-- newest entries kept
local MAX_EVENTS = 200
-- how deep table arguments are copied
local MAX_DEPTH = 4

local function numberToString(value)
	if value == math.floor(value) then
		return string.format("%.0f", value)
	end
	return string.format("%.14g", value)
end

-- a plain, file-safe copy of any value: tables copied (depth limited), nil and functions named
local function describe(value, depth, visited)
	local valueType = type(value)
	if valueType == "nil" then
		return "<nil>"
	elseif valueType == "number" then
		return numberToString(value)
	elseif valueType == "string" or valueType == "boolean" then
		return value
	elseif valueType ~= "table" then
		return "<" .. valueType .. ">"
	end
	depth = depth or 1
	visited = visited or {}
	if visited[value] then
		return "<loop>"
	end
	if depth > MAX_DEPTH then
		return "<table>"
	end
	visited[value] = true
	local out = {}
	for key, nested in pairs(value) do
		out[tostring(key)] = describe(nested, depth + 1, visited)
	end
	return out
end

local function safeCall(fn)
	local ok, result = pcall(fn)
	if not ok then
		return nil
	end
	return result
end

local function readList(path)
	local list = api.File:Read(path)
	if type(list) ~= "table" then
		return {}
	end
	return list
end

-- the addon sandbox has no select(), so arguments come in as a1..a8
function logbook.LogEvent(event, a1, a2, a3, a4, a5, a6, a7, a8)
	local args = { a1, a2, a3, a4, a5, a6, a7, a8 }
	local entry = {
		event = tostring(event),
		time = clock.NowText(),
		addon_version = addoninfo.version,
		args = {},
		arg_types = {},
		-- context, to tie the event to a house
		player_sextant = describe(safeCall(function() return api.Map:GetPlayerSextants() end)),
		target_name = describe(safeCall(function() return api.Unit:UnitName("target") end)),
	}
	for i = 1, 8 do
		entry.args["a" .. i] = describe(args[i])
		entry.arg_types["a" .. i] = type(args[i])
	end

	local list = readList(EVENTS_PATH)
	list[#list + 1] = entry
	while #list > MAX_EVENTS do
		table.remove(list, 1)
	end
	datafiles.Write(FORSALE_DIR, EVENTS_PATH, list)
end

-- Empties the event log. Returns how many files were emptied.
function logbook.ResetData()
	return datafiles.Reset(FORSALE_DIR)
end

return logbook
