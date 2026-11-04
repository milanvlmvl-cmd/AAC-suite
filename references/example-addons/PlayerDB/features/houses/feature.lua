-- Houses: logs targeted buildings with their owner and position.
local api = require("api")
local logbook = require("PlayerDB/features/houses/logbook")
local statusdot = require("PlayerDB/features/houses/statusdot")
local locate = require("PlayerDB/features/houses/locate")

local feature = {
	id = "houses",
	label = "Houses",
}

local enabled = false

local function runSafe(fn)
	local ok, result = pcall(fn)
	if not ok then
		-- always in the log file; in chat only in dev mode
		api.Log:Info("[PlayerDB Houses] error: " .. tostring(result))
		logbook.Chat(3, "[PlayerDB Houses] error: " .. tostring(result))
		return nil
	end
	return result
end

-- the target frame (where the owner name comes from) is filled in a moment after TARGET_CHANGED
local SCAN_DELAY_MS = 600
-- if the owner is still missing, look once more
local RETRY_DELAY_MS = 1500
-- how often to check whether a targeted building out of range has come within range
local RANGE_POLL_MS = 1000
-- bumped on every target change; scans queued for an older target see a newer id and skip
local targetChangeId = 0

-- while a building stays targeted, sample its screen position to find where it stands
local LOCATE_INTERVAL_MS = 500
local LOCATE_MAX_SAMPLES = 60
-- samples kept in the dev dump
local LOCATE_DUMP_SAMPLES = 20
-- the building being located; saved at the player's position if it is not located in time
local activeSession = nil

-- dot state (statusdot.NONE / LOCATING / FAR); distance only with FAR
local function setDot(state, distance)
	-- a UI problem must never stop logging
	runSafe(function()
		statusdot.SetState(state, distance)
	end)
end

local function markScan(building)
	runSafe(function()
		statusdot.MarkLogged(building)
	end)
end

-- shown in the dot's tooltip when the distance to an out-of-range building can't be read
local UNKNOWN_DISTANCE = 999

-- saves the session's building where the player stood, unless it was already saved
local function finishApprox(session)
	if session.done then
		return
	end
	session.done = true
	if activeSession == session then
		activeSession = nil
	end
	if session.lon == nil then
		return
	end
	runSafe(function()
		logbook.LogApprox(session.building, session.owner, session.lon, session.lat)
	end)
	markScan(session.building)
end

local function finishLocated(session, point)
	session.done = true
	if activeSession == session then
		activeSession = nil
	end
	if runSafe(function() return logbook.LogLocated(session.building, session.owner, point) end) then
		logbook.Chat(11, "[PlayerDB Houses] " .. session.building .. " position pinned")
		markScan(session.building)
	else
		session.done = false
		finishApprox(session)
	end
end

local function queueLocate(changeId, session, count)
	api:DoIn(LOCATE_INTERVAL_MS, function()
		if session.done or changeId ~= targetChangeId or not enabled then
			return -- already saved (target changed), or disabled meanwhile
		end
		local point, info
		local sampled = runSafe(function()
			point, info = locate.Sample(session)
			session.samples[#session.samples + 1] = info
			if #session.samples > LOCATE_DUMP_SAMPLES then
				table.remove(session.samples, 1)
			end
			logbook.DumpLocate(session.samples)
			return true
		end)
		if not sampled then
			finishApprox(session) -- error already logged
			return
		end
		if point ~= nil then
			finishLocated(session, point)
			return
		end
		if count >= LOCATE_MAX_SAMPLES then
			logbook.DebugLog("gave up locating " .. session.building .. ": " .. tostring(info.result))
			finishApprox(session)
			return
		end
		queueLocate(changeId, session, count + 1)
	end)
end

local function startLocate(changeId, building, owner)
	local session = locate.NewSession()
	session.building = building
	session.owner = owner
	session.lon, session.lat = logbook.PlayerPosition()
	activeSession = session
	logbook.Chat(11, "[PlayerDB Houses] Keep " .. building .. " targeted for a few seconds to pin its position")
	queueLocate(changeId, session, 1)
end

local function queueScan(changeId, delay, retry)
	api:DoIn(delay, function()
		if changeId ~= targetChangeId or not enabled then
			return -- target changed again, or disabled meanwhile
		end
		-- FOUND: building, owner; TOO_FAR: distance
		local status, first, second
		runSafe(function()
			status, first, second = logbook.ReadTarget()
		end)
		if status == logbook.TOO_FAR then
			setDot(statusdot.FAR, first or UNKNOWN_DISTANCE)
		elseif status == logbook.FOUND then
			setDot(statusdot.LOCATING)
		else
			setDot(statusdot.NONE)
		end
		if status == logbook.FOUND then
			runSafe(function()
				startLocate(changeId, first, second)
			end)
		elseif status == logbook.TOO_FAR then
			-- keep watching while it stays targeted; stops on the next target change
			queueScan(changeId, RANGE_POLL_MS, retry)
		elseif status == logbook.NO_OWNER and retry then
			queueScan(changeId, RETRY_DELAY_MS, false)
		end
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
	runSafe(function()
		statusdot.Create(logbook.Count)
	end)
end

function feature.Disable()
	if not enabled then
		return
	end
	-- keep what was found so far for a building still being located
	if activeSession ~= nil then
		finishApprox(activeSession)
	end
	enabled = false
	-- stop pending scans
	targetChangeId = targetChangeId + 1
	runSafe(statusdot.Free)
end

-- main.lua calls this from its event window
function feature.OnTargetChanged()
	if not enabled then
		return
	end
	-- the previous building was not located before the target moved on
	if activeSession ~= nil then
		finishApprox(activeSession)
	end
	-- new target: red until it is known to be a building in range and logged
	setDot(statusdot.NONE)
	targetChangeId = targetChangeId + 1
	queueScan(targetChangeId, SCAN_DELAY_MS, true)
end

return feature
