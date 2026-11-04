-- Inventory: saves what the character carries to PlayerDB/Inventory/, shortly
-- after load and then every 30 minutes. Clicking the icon scans right away and restarts the 30 minutes.
local api = require("api")
local logbook = require("PlayerDB/features/inventory/logbook")
local icon = require("PlayerDB/features/inventory/icon")

local feature = {
	id = "inventory",
	label = "Inventory",
}

-- the bag is not filled the instant the addon loads, so the first scan waits a little
local FIRST_SCAN_MS = 15 * 1000
local SCAN_INTERVAL_MS = 30 * 60 * 1000

local enabled = false
-- bumped whenever the schedule restarts (click, disable); an older timer sees a newer id and stops
local scheduleId = 0

local function runSafe(fn)
	local ok, result = pcall(fn)
	if not ok then
		api.Log:Info("[PlayerDB Inventory] error: " .. tostring(result))
		return nil
	end
	return result
end

local function scan()
	local summary = runSafe(logbook.Scan)
	if summary ~= nil then
		runSafe(function()
			icon.SetScan(summary)
		end)
	end
end

-- scans after delayMs, then every SCAN_INTERVAL_MS, until the schedule is restarted or stopped
local function schedule(delayMs)
	scheduleId = scheduleId + 1
	local id = scheduleId
	local function tick()
		if not enabled or id ~= scheduleId then
			return
		end
		scan()
		api:DoIn(SCAN_INTERVAL_MS, tick)
	end
	api:DoIn(delayMs, tick)
end

local function onIconClick()
	if not enabled then
		return
	end
	scan()
	schedule(SCAN_INTERVAL_MS)
end

-- empties this feature's logged data
function feature.ResetData()
	return logbook.ResetData()
end

function feature.Enable()
	if enabled then
		return
	end
	enabled = true
	runSafe(function()
		icon.Create(onIconClick)
	end)
	schedule(FIRST_SCAN_MS)
end

function feature.Disable()
	if not enabled then
		return
	end
	enabled = false
	scheduleId = scheduleId + 1
	runSafe(icon.Free)
end

return feature
