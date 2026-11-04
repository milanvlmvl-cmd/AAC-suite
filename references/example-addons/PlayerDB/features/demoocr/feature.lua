-- DemoOCR: hands a request to the sync app through PlayerDB/Demos/. Clicking the icon sets request.dat to
-- status true and starts writing the player's location to location.dat (same layout as WorldSatNav's
-- location.dat). The sync app sets request.dat back to status false when it is done; that stops the
-- location updates. If it is still true after 60 seconds, the sync app is probably not running.
local api = require("api")
local clock = require("PlayerDB/clock")
local icon = require("PlayerDB/features/demoocr/icon")

local feature = {
	id = "demoocr",
	label = "DemoOCR",
}

local DEMOS_DIR = "PlayerDB/Demos/"
local REQUEST_FILE = DEMOS_DIR .. "request.dat"
local LOCATION_FILE = DEMOS_DIR .. "location.dat"

local LOCATION_INTERVAL_MS = 1000
local CHECK_INTERVAL_MS = 5 * 1000
local TIMEOUT_MS = 60 * 1000
local NO_SYNC_MESSAGE = "Enable sync app"
-- chat tab the message goes to (the filter WorldSatNav uses for its notices)
local CHAT_FILTER = 4

local enabled = false
local waiting = false
-- bumped on every click and stop; an older timer sees a newer id and stops
local requestId = 0

local function runSafe(fn)
	local ok, result = pcall(fn)
	if not ok then
		api.Log:Info("[PlayerDB DemoOCR] error: " .. tostring(result))
		return nil
	end
	return result
end

local function writeRequest(status)
	api.File:Write(REQUEST_FILE, { status = status })
end

-- true only when the file says false; a missing or half-written file counts as still waiting
local function requestDone()
	local request = api.File:Read(REQUEST_FILE)
	if type(request) ~= "table" then
		return false
	end
	return request.status == false or request.status == "false"
end

local updateTicker = 0

local function writeLocation()
	updateTicker = updateTicker + LOCATION_INTERVAL_MS
	local time = clock.Now()
	api.File:Write(LOCATION_FILE, {
		time = time ~= nil and math.floor(time) or api.Time:GetLocalTime(),
		location = api.Map:GetPlayerSextants(),
		updateTicker = updateTicker,
	})
	-- reset every 10 seconds, just so file updates can be seen even if time has not changed
	if updateTicker > 10000 then
		updateTicker = 0
	end
end

local function stop()
	waiting = false
	requestId = requestId + 1
	runSafe(function()
		icon.SetBusy(false, "Click to start")
	end)
end

-- writes the location every LOCATION_INTERVAL_MS and checks request.dat every CHECK_INTERVAL_MS
local function run(id, elapsedMs)
	api:DoIn(LOCATION_INTERVAL_MS, function()
		if not enabled or id ~= requestId then
			return
		end
		elapsedMs = elapsedMs + LOCATION_INTERVAL_MS
		if elapsedMs % CHECK_INTERVAL_MS == 0 and runSafe(requestDone) then
			waiting = false
			requestId = requestId + 1
			runSafe(function()
				icon.SetDone("Done")
			end)
			return
		end
		if elapsedMs >= TIMEOUT_MS then
			stop()
			-- cancel the request so the sync app does not pick up a stale one later
			runSafe(function()
				writeRequest(false)
				icon.SetStatus("No answer from the sync app")
			end)
			runSafe(function()
				api.Chat:DispatchChatMessage(CHAT_FILTER, "[PlayerDB] " .. NO_SYNC_MESSAGE)
			end)
			return
		end
		runSafe(writeLocation)
		run(id, elapsedMs)
	end)
end

local function onIconClick()
	if not enabled or waiting then
		return
	end
	waiting = true
	requestId = requestId + 1
	updateTicker = 0
	runSafe(function()
		icon.SetBusy(true, "Waiting for the sync app")
		writeRequest(true)
		writeLocation()
	end)
	run(requestId, 0)
end

-- nothing logged, the Demos files are only a hand-over to the sync app
function feature.ResetData()
	return 0
end

function feature.Enable()
	if enabled then
		return
	end
	enabled = true
	waiting = false
	runSafe(function()
		icon.Create(onIconClick)
	end)
end

function feature.Disable()
	if not enabled then
		return
	end
	enabled = false
	waiting = false
	requestId = requestId + 1
	runSafe(icon.Free)
end

return feature
