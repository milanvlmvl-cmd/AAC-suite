local api = require("api")
local addoninfo = require("PlayerDB/addoninfo")
local datafiles = require("PlayerDB/datafiles")
local clock = require("PlayerDB/clock")
local regionmap = require("PlayerDB/features/houses/regionmap")

local logbook = {}

local HOUSES_DIR = "PlayerDB/Houses/"
local COUNT_PATH = HOUSES_DIR .. "_count.dat"
-- dev mode: chat messages (new houses, changes, errors) and debug output; off = silent
local DEBUG = false
-- dev: write everything the API returns for each targeted building to DUMP_PATH (overwritten per target)
local DUMP_TARGET = false
local DUMP_PATH = "PlayerDB/house_dump.dat"

-- sextant degrees per world unit, same value WorldSatNav uses (core/constants.lua)
local COORD_COEF = 0.00097657363894522145695357130138029
-- same name and owner closer than this = same house (8x8 plots can sit 8m apart)
local SAME_HOUSE_RADIUS_M = 6
-- a different owner or name only counts as the same house (sold, renamed) when this close;
-- located positions can be a few metres out, so a looser match would hand one house's entry to a neighbour
local CHANGED_HOUSE_RADIUS_M = 1.5
-- approximate positions are where the player stood, which can be up to targeting range from the house
local APPROX_MATCH_RADIUS_M = 150
-- buildings further away than this are ignored until the player comes closer
-- (distant ones locate less accurately)
local MAX_TARGET_DISTANCE_M = 15

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
	api.Log:Info("[PlayerDB Houses] DEBUG " .. message)
	logbook.Chat(3, "[PlayerDB Houses] DEBUG " .. message)
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

-- ---------------------------------------------------------------------------
-- Coordinates
-- Positions are kept as decimal degrees: lon positive = East, lat positive = North.
-- World positions are x = East, y = North in world units.
-- ---------------------------------------------------------------------------

-- engine field names (longitudeDir, longitudeDeg, ...) or the short WorldSatNav ones
local function normalizeSextant(sextant)
	if type(sextant) ~= "table" then
		return nil
	end
	local s = {
		longitude = sextant.longitudeDir or sextant.longitude,
		latitude = sextant.latitudeDir or sextant.latitude,
		deg_long = tonumber(sextant.longitudeDeg or sextant.deg_long or sextant.degLong),
		min_long = tonumber(sextant.longitudeMin or sextant.min_long or sextant.minLong) or 0,
		sec_long = tonumber(sextant.longitudeSec or sextant.sec_long or sextant.secLong) or 0,
		deg_lat = tonumber(sextant.latitudeDeg or sextant.deg_lat or sextant.degLat),
		min_lat = tonumber(sextant.latitudeMin or sextant.min_lat or sextant.minLat) or 0,
		sec_lat = tonumber(sextant.latitudeSec or sextant.sec_lat or sextant.secLat) or 0,
	}
	if s.longitude == nil or s.latitude == nil or s.deg_long == nil or s.deg_lat == nil then
		return nil
	end
	return s
end

local function sextantToDecimal(s)
	local lon = s.deg_long + s.min_long / 60 + s.sec_long / 3600
	local lat = s.deg_lat + s.min_lat / 60 + s.sec_lat / 3600
	if s.longitude == "W" then
		lon = -lon
	end
	if s.latitude == "S" then
		lat = -lat
	end
	return lon, lat
end

-- one axis of decimal degrees -> direction, degrees, minutes, whole seconds
local function splitDegrees(value, positiveDir, negativeDir)
	local dir = positiveDir
	if value < 0 then
		dir = negativeDir
		value = -value
	end
	local totalSeconds = math.floor(value * 3600 + 0.5)
	local deg = math.floor(totalSeconds / 3600)
	local min = math.floor((totalSeconds % 3600) / 60)
	return dir, deg, min, totalSeconds % 60
end

-- same shape as WorldSatNav's demos.dat "location", so entries can be shared with it
local function decimalToSextant(lon, lat)
	local longitude, degLong, minLong, secLong = splitDegrees(lon, "E", "W")
	local latitude, degLat, minLat, secLat = splitDegrees(lat, "N", "S")
	return {
		longitude = longitude,
		deg_long = degLong,
		min_long = minLong,
		sec_long = secLong,
		latitude = latitude,
		deg_lat = degLat,
		min_lat = minLat,
		sec_lat = secLat,
	}
end

local function formatSextant(s)
	return string.format("%s %d°%d'%d\" %s %d°%d'%d\"",
		s.longitude, s.deg_long, s.min_long, s.sec_long,
		s.latitude, s.deg_lat, s.min_lat, s.sec_lat)
end

local function metersBetween(lonA, latA, lonB, latB)
	local dLon = lonB - lonA
	local dLat = latB - latA
	return math.sqrt(dLon * dLon + dLat * dLat) / COORD_COEF
end

-- the addon sandbox has no select(), so take x, y straight from the call
local function worldPosition(unit)
	local ok, x, y = pcall(function()
		return api.Unit:UnitWorldPosition(unit)
	end)
	x = ok and tonumber(x) or nil
	y = ok and tonumber(y) or nil
	if x == nil or y == nil then
		return nil, nil
	end
	return x, y
end

-- player's position as decimal degrees, or nil
local function playerPosition()
	local playerSextant = normalizeSextant(api.Map:GetPlayerSextants())
	if playerSextant == nil then
		debugLog("no player sextant")
		return nil
	end
	return sextantToDecimal(playerSextant)
end

-- ---------------------------------------------------------------------------
-- Target checks
-- ---------------------------------------------------------------------------

local function safeCall(fn)
	local ok, result = pcall(fn)
	if not ok then
		return nil
	end
	return result
end

-- Buildings are targets with a name but no unit id, info, class or target of their own
-- (same test as WorldSatNav's demo "+" button).
local function targetIsBuilding()
	local U = api.Unit
	local name = safeCall(function() return U:UnitName("target") end)
	if name == nil or name == "" then
		return nil
	end
	if safeCall(function() return U:GetUnitId("target") end) ~= nil
		or safeCall(function() return U:UnitInfo("target") end) ~= nil
		or safeCall(function() return U:UnitModifierInfo("target") end) ~= nil
		or safeCall(function() return U:UnitClass("target") end) ~= nil
		or safeCall(function() return U:TargetUnit("target") end) ~= nil then
		return nil
	end
	return name
end

local function getTargetFrame()
	local frame = safeCall(function() return ADDON:GetContent(UIC.TARGET_UNITFRAME) end)
	if type(frame) == "table" then
		return frame
	end
	return nil
end

-- The target frame tooltip reads like "Owner: Cawyn\nHealth : |p2; / |p3; (|p4;%)".
local function getOwnerName()
	local frame = getTargetFrame()
	if frame == nil or type(frame.tooltipText) ~= "string" then
		-- frame not shown/populated yet: force it visible, then retry once
		pcall(function() ADDON:ShowContent(UIC.TARGET_UNITFRAME, true) end)
		frame = getTargetFrame()
	end
	if frame == nil or type(frame.tooltipText) ~= "string" then
		return nil
	end
	local owner = frame.tooltipText:match("Owner:%s*([^\r\n]+)")
	if owner == nil then
		return nil
	end
	owner = owner:gsub("%s+$", "")
	if owner == "" then
		return nil
	end
	return owner
end

-- ---------------------------------------------------------------------------
-- Storage
-- Houses are split into one file per sextant degree square, e.g. W16_S23.dat (~1km each).
-- ---------------------------------------------------------------------------

local function cellPath(lon, lat)
	local s = decimalToSextant(lon, lat)
	return HOUSES_DIR .. s.longitude .. s.deg_long .. "_" .. s.latitude .. s.deg_lat .. ".dat"
end

-- every file a match within radius could be in (more than one only near a cell edge)
local function nearbyPaths(lon, lat, radius)
	local reach = radius * COORD_COEF
	local paths, seen = {}, {}
	for _, dLon in ipairs({ -reach, reach }) do
		for _, dLat in ipairs({ -reach, reach }) do
			local path = cellPath(lon + dLon, lat + dLat)
			if not seen[path] then
				seen[path] = true
				paths[#paths + 1] = path
			end
		end
	end
	return paths
end

local function readList(path)
	local list = api.File:Read(path)
	if type(list) ~= "table" then
		return {}
	end
	return list
end

local function readCount()
	local stats = api.File:Read(COUNT_PATH)
	if type(stats) ~= "table" then
		return 0
	end
	return tonumber(stats.houses) or 0
end

local function writeCount(count)
	api.File:Write(COUNT_PATH, { houses = copyPlain(count), addon_version = addoninfo.version })
end

local function isApprox(entry)
	return entry.approx == true or entry.approx == "true"
end

-- Closest stored house to lon/lat; approximate sightings only match the same building and owner.
-- Returns entry, path, list.
local function findHouse(lon, lat, approx, building, owner)
	local best, bestPath, bestList, bestDistance = nil, nil, nil, nil
	for _, path in ipairs(nearbyPaths(lon, lat, APPROX_MATCH_RADIUS_M)) do
		local list = readList(path)
		for _, entry in ipairs(list) do
			local entryLon, entryLat = tonumber(entry.lon), tonumber(entry.lat)
			if entryLon ~= nil and entryLat ~= nil then
				local distance = metersBetween(lon, lat, entryLon, entryLat)
				local same = entry.building == building and entry.owner == owner
				local radius
				if approx or isApprox(entry) then
					-- a player position says nothing about which house it is, so only the same name and owner match
					radius = same and APPROX_MATCH_RADIUS_M or nil
				else
					radius = same and SAME_HOUSE_RADIUS_M or CHANGED_HOUSE_RADIUS_M
				end
				if radius ~= nil and distance <= radius and (bestDistance == nil or distance < bestDistance) then
					best, bestPath, bestList, bestDistance = entry, path, list, distance
				end
			end
		end
	end
	return best, bestPath, bestList
end

local function setPosition(entry, lon, lat, approx)
	entry.lon = string.format("%.6f", lon)
	entry.lat = string.format("%.6f", lat)
	entry.location = decimalToSextant(lon, lat)
	entry.approx = approx == true
end

-- not known from a target scan; entries from other sources may fill these in
local NOT_AVAILABLE = "na"

-- fields every entry carries (see the house file spec); existing values are kept
local function fillSpecFields(entry)
	if entry.building_type == nil then
		entry.building_type = NOT_AVAILABLE
	end
	if entry.status == nil then
		entry.status = NOT_AVAILABLE
	end
	if entry.status_at == nil then
		entry.status_at = NOT_AVAILABLE
	end
	if entry.approx == nil then
		entry.approx = false
	end
end

-- region code ("N", "H", "Sea", ...) and name, from WorldSatNav's region map
local function setRegion(entry)
	local ok, code, name = pcall(regionmap.GetRegionForSextant, entry.location)
	if not ok then
		debugLog("region lookup error: " .. tostring(code))
		code, name = "?", "?"
	end
	entry.region_code = code
	entry.region = name
	-- zone group ids from earlier versions were not usable
	entry.zone = nil
end

local function removeEntry(list, entry)
	for index, value in ipairs(list) do
		if value == entry then
			table.remove(list, index)
			return
		end
	end
end

-- Adds or updates the house; returns isNew, and whether its stored position is still approximate.
local function saveHouse(building, owner, lon, lat, approx)
	local seen = clock.NowText()
	local entry, path, list = findHouse(lon, lat, approx, building, owner)

	if entry == nil then
		entry = {
			building = building,
			owner = owner,
			first_seen = seen,
			last_seen = seen,
			addon_version = addoninfo.version,
		}
		setPosition(entry, lon, lat, approx)
		setRegion(entry)
		fillSpecFields(entry)
		path = cellPath(lon, lat)
		list = readList(path)
		list[#list + 1] = entry
		datafiles.Write(HOUSES_DIR, path, list)
		writeCount(readCount() + 1)
		logbook.Chat(11, "[PlayerDB Houses] New house: " .. building .. " owned by " .. owner
			.. " in " .. entry.region .. " at " .. formatSextant(entry.location) .. (approx and " (approx)" or ""))
		return true, isApprox(entry)
	end

	local changes = {}
	if entry.owner ~= owner or entry.building ~= building then
		if entry.owner ~= owner then
			changes[#changes + 1] = "owner " .. tostring(entry.owner) .. " -> " .. owner
		end
		if entry.building ~= building then
			changes[#changes + 1] = "building " .. tostring(entry.building) .. " -> " .. building
		end
		entry.owner = owner
		entry.building = building
	end
	-- a real house position replaces one taken from where the player stood
	if isApprox(entry) and not approx then
		removeEntry(list, entry)
		datafiles.Write(HOUSES_DIR, path, list)
		setPosition(entry, lon, lat, false)
		path = cellPath(lon, lat)
		list = readList(path)
		list[#list + 1] = entry
		changes[#changes + 1] = "exact position " .. formatSextant(entry.location)
	end
	setRegion(entry)
	fillSpecFields(entry)
	entry.last_seen = seen
	entry.addon_version = addoninfo.version
	-- no longer kept; drop it from entries saved by earlier versions
	entry.history = nil
	datafiles.Write(HOUSES_DIR, path, list)

	if #changes > 0 then
		logbook.Chat(3, "[PlayerDB Houses] " .. building .. " changed: " .. table.concat(changes, ", "))
	end
	return false, isApprox(entry)
end

-- ---------------------------------------------------------------------------
-- Dev dump
-- ---------------------------------------------------------------------------

-- the addon sandbox has no select(), so capture up to 4 return values (enough for x, y, z)
local function probe(fn)
	local ok, a, b, c, d = pcall(fn)
	if not ok then
		return "<error: " .. tostring(a) .. ">"
	end
	if b == nil and c == nil and d == nil then
		if a == nil then
			return "<nil>"
		end
		return copyPlain(a)
	end
	return copyPlain({ a, b, c, d })
end

-- strings, numbers and booleans on the target frame, to find other useful fields
local function frameFields()
	local frame = getTargetFrame()
	if frame == nil then
		return "<nil>"
	end
	local out = {}
	for key, value in pairs(frame) do
		local valueType = type(value)
		if valueType == "string" or valueType == "number" or valueType == "boolean" then
			out[tostring(key)] = copyPlain(value)
		end
	end
	return out
end

-- raw client calls that might know where the target is; the addon api has no position for buildings
local function rawProbes()
	local out = {}
	local function try(label, fn)
		out[label] = probe(fn)
	end
	try("X2Unit.UnitWorldPosition", function() return X2Unit:UnitWorldPosition("target") end)
	try("X2Unit.GetTargetUnitId", function() return X2Unit:GetTargetUnitId() end)
	try("X2Unit.GetUnitType", function() return X2Unit:GetUnitType("target") end)
	try("X2Unit.GetUnitTypeString", function() return X2Unit:GetUnitTypeString("target") end)
	try("X2Unit.GetTargetTypeString", function() return X2Unit:GetTargetTypeString() end)
	try("X2Unit.GetTargetKindType", function() return X2Unit:GetTargetKindType("target") end)
	try("X2Unit.GetUnitScreenPosition", function() return X2Unit:GetUnitScreenPosition("target") end)
	try("X2Unit.GetUnitWorldPosition", function() return X2Unit:GetUnitWorldPosition("target") end)
	try("X2Unit.UnitPosition", function() return X2Unit:UnitPosition("target") end)
	return out
end

-- which client globals the sandbox lets through, and what is on them
local DISCOVERY_PATH = "PlayerDB/api_discovery.dat"
-- read each global inside its own function, so a sandbox that errors on unknown globals is caught by pcall
local DISCOVERY_GLOBALS = {
	{ "X2", function() return X2 end },
	{ "X2Unit", function() return X2Unit end },
	{ "X2Map", function() return X2Map end },
	{ "X2House", function() return X2House end },
	{ "X2Util", function() return X2Util end },
	{ "X2Player", function() return X2Player end },
	{ "X2Camera", function() return X2Camera end },
	{ "X2Doodad", function() return X2Doodad end },
	{ "X2Housing", function() return X2Housing end },
	{ "X2World", function() return X2World end },
	{ "X2Dominion", function() return X2Dominion end },
	{ "X2Decal", function() return X2Decal end },
	{ "X2Debug", function() return X2Debug end },
	{ "X2Interaction", function() return X2Interaction end },
	{ "X2Ability", function() return X2Ability end },
	{ "_G", function() return _G end },
}
local discoveryDone = false

local function dumpDiscovery()
	if discoveryDone then
		return
	end
	discoveryDone = true
	local out = {}
	for _, global in ipairs(DISCOVERY_GLOBALS) do
		local name = global[1]
		local ok, value = pcall(global[2])
		if not ok then
			out[name] = "<error: " .. tostring(value) .. ">"
		elseif value == nil then
			out[name] = "<nil>"
		else
			local keys = {}
			local listed = pcall(function()
				for key, member in pairs(value) do
					keys[#keys + 1] = tostring(key) .. " (" .. type(member) .. ")"
				end
			end)
			table.sort(keys)
			out[name] = { type = type(value), listed = listed, keys = keys }
		end
	end
	api.File:Write(DISCOVERY_PATH, out)
	debugLog("wrote " .. DISCOVERY_PATH)
end

local function dumpTarget()
	local U = api.Unit
	dumpDiscovery()
	api.File:Write(DUMP_PATH, {
		raw = rawProbes(),
		targetScreenPosition = probe(function() return U:GetUnitScreenPosition("target") end),
		targetNameTagOffset = probe(function() return U:GetUnitScreenNameTagOffset("target") end),
		playerScreenPosition = probe(function() return U:GetUnitScreenPosition("player") end),
		playerWorldToScreen = probe(function()
			local x, y, z = U:UnitWorldPosition("player")
			return X2Util:ConvertWorldToScreen(x, y, z)
		end),
		name = probe(function() return U:UnitName("target") end),
		unitId = probe(function() return U:GetUnitId("target") end),
		distance = probe(function() return U:UnitDistance("target") end),
		targetWorldPosition = probe(function() return U:UnitWorldPosition("target") end),
		playerWorldPosition = probe(function() return U:UnitWorldPosition("player") end),
		playerSextants = probe(function() return api.Map:GetPlayerSextants() end),
		region = probe(function() return regionmap.GetRegionForSextant(normalizeSextant(api.Map:GetPlayerSextants())) end),
		frame = frameFields(),
	})
	debugLog("dumped target to " .. DUMP_PATH)
end

-- ---------------------------------------------------------------------------
-- Public
-- ---------------------------------------------------------------------------

logbook.NOT_BUILDING = "not_building"
logbook.TOO_FAR = "too_far"
logbook.NO_OWNER = "no_owner"
logbook.FOUND = "found"

-- Reads the targeted building without saving it. Returns one of the status values above,
-- with FOUND also the building name and owner, with TOO_FAR the distance (nil if unknown).
-- TOO_FAR and NO_OWNER (target frame not filled in yet) can change, so the caller may retry.
function logbook.ReadTarget()
	local building = targetIsBuilding()
	if building == nil then
		return logbook.NOT_BUILDING
	end
	local distance = tonumber(safeCall(function() return api.Unit:UnitDistance("target") end))
	if distance == nil or distance > MAX_TARGET_DISTANCE_M then
		return logbook.TOO_FAR, distance
	end
	if DUMP_TARGET then
		dumpTarget()
	end
	local owner = getOwnerName()
	if owner == nil then
		debugLog("'" .. building .. "' has no owner (yet)")
		return logbook.NO_OWNER
	end
	return logbook.FOUND, building, owner
end

-- the player's current position (decimal lon, lat), kept by the caller in case locating fails
function logbook.PlayerPosition()
	return playerPosition()
end

local function reportNew(isNew)
	if isNew then
		logbook.Chat(11, "[PlayerDB Houses] You now have " .. readCount() .. " houses logged")
	end
end

-- Saves a building that could not be located, at the position the player had when targeting it.
function logbook.LogApprox(building, owner, lon, lat)
	reportNew(saveHouse(building, owner, lon, lat, true))
end

-- Saves the building's world position found by locate.lua.
function logbook.LogLocated(building, owner, point)
	local playerLon, playerLat = playerPosition()
	local px, py = worldPosition("player")
	if playerLon == nil or px == nil then
		debugLog("located " .. building .. " but player position is unavailable")
		return false
	end
	-- the target frame may still have shown the previous building's owner when the target changed
	if targetIsBuilding() == building then
		local current = getOwnerName()
		if current ~= nil and current ~= owner then
			debugLog("owner of " .. building .. " now reads " .. current .. " (was " .. owner .. ")")
			owner = current
		end
	end
	local dx, dy = point[1] - px, point[2] - py
	debugLog(string.format("located %s %.1fm east, %.1fm north of player", building, dx, dy))
	reportNew(saveHouse(building, owner, playerLon + dx * COORD_COEF, playerLat + dy * COORD_COEF, false))
	return true
end

-- dev: per-sample locate details, written next to the target dump
local LOCATE_DUMP_PATH = "PlayerDB/locate_dump.dat"
function logbook.DumpLocate(samples)
	if not DUMP_TARGET then
		return
	end
	api.File:Write(LOCATE_DUMP_PATH, samples)
end

logbook.DebugLog = debugLog

-- name of the building currently targeted, or nil
function logbook.TargetBuildingName()
	return targetIsBuilding()
end

-- Empties every house file and zeroes the count. Returns how many files were emptied.
function logbook.ResetData()
	local emptied = datafiles.Reset(HOUSES_DIR)
	writeCount(0)
	return emptied
end

function logbook.Count()
	return readCount()
end

return logbook
