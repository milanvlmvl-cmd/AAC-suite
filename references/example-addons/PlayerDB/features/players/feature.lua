-- Players: logs targeted players, raid/party members in range, and your own character.
local api = require("api")
local logbook = require("PlayerDB/features/players/logbook")
local statusdots = require("PlayerDB/features/players/statusdots")

local feature = {
	id = "players",
	label = "Players",
}

local enabled = false

local function runSafe(fn)
	local ok, result = pcall(fn)
	if not ok then
		-- always in the log file; in chat only in dev mode
		api.Log:Info("[PlayerDB] error: " .. tostring(result))
		logbook.Chat(3, "[PlayerDB] error: " .. tostring(result))
		return nil
	end
	return result
end

-- flips the status dot for a scan; a UI problem must never stop logging
local function markScan(index)
	runSafe(function()
		statusdots.Toggle(index)
	end)
end

-- TEAM_MEMBERS_CHANGED fires in bursts (joining a raid, people swapping groups)
-- and member info is not always ready yet, so wait and scan once.
local RAID_SCAN_DELAY_MS = 2000
-- one more scan a while after the last change, for members who were out of range at first
local RAID_RESCAN_DELAY_MS = 3 * 60 * 1000
local raidScanPending = false
-- bumped on every queued rescan; DoIn can't be cancelled, so older rescans see a newer id and skip
local raidRescanId = 0

local function queueRaidRescan()
	raidRescanId = raidRescanId + 1
	local rescanId = raidRescanId
	api:DoIn(RAID_RESCAN_DELAY_MS, function()
		if rescanId ~= raidRescanId or not enabled then
			return -- superseded by a later change, or disabled meanwhile
		end
		runSafe(logbook.ScanRaid)
		markScan(statusdots.RAID)
	end)
end

local function queueRaidScan()
	if raidScanPending then
		return
	end
	raidScanPending = true
	api:DoIn(RAID_SCAN_DELAY_MS, function()
		raidScanPending = false
		if not enabled then
			return -- disabled meanwhile
		end
		local members = runSafe(logbook.ScanRaid)
		markScan(statusdots.RAID)
		if members ~= nil and members > 0 then
			queueRaidRescan()
		end
	end)
end

-- log our own character on enable and then on a fixed interval
local SELF_LOG_FIRST_DELAY_MS = 5000
local SELF_LOG_INTERVAL_MS = 3 * 60 * 1000
-- bumped on every enable/disable; a timer chain from an earlier one sees a newer id and stops
local selfLogId = 0

local function queueSelfLog(chainId, delay)
	api:DoIn(delay, function()
		if chainId ~= selfLogId or not enabled then
			return -- re-enabled or disabled meanwhile
		end
		runSafe(logbook.LogSelf)
		markScan(statusdots.PLAYER)
		queueSelfLog(chainId, SELF_LOG_INTERVAL_MS)
	end)
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
	runSafe(statusdots.Create)
	-- already in a raid when enabled
	queueRaidScan()
	selfLogId = selfLogId + 1
	queueSelfLog(selfLogId, SELF_LOG_FIRST_DELAY_MS)
end

function feature.Disable()
	if not enabled then
		return
	end
	enabled = false
	-- stop pending timers
	selfLogId = selfLogId + 1
	raidRescanId = raidRescanId + 1
	runSafe(statusdots.Free)
end

-- main.lua calls these from its event window

function feature.OnTargetChanged()
	if not enabled then
		return
	end
	runSafe(logbook.LogTarget)
	markScan(statusdots.TARGET)
end

function feature.OnTeamMembersChanged()
	if not enabled then
		return
	end
	queueRaidScan()
end

return feature
