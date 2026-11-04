-- Regrades: logs every regrade broadcast, with a light for losses.
local api = require("api")
local logbook = require("PlayerDB/features/regrades/logbook")
local statusdot = require("PlayerDB/features/regrades/statusdot")

local feature = {
	id = "regrades",
	label = "Regrades",
}

local enabled = false

-- errors never reach chat; they are kept in PlayerDB/regrade_errors.dat
local function runSafe(fn)
	local ok, result = pcall(fn)
	if not ok then
		pcall(logbook.LogError, result)
		return nil
	end
	return result
end

local function onRegrade(characterName, resultCode, itemLink, oldGrade, newGrade, source)
	local failure = nil
	local ok, entry = pcall(logbook.LogRegrade, characterName, resultCode, itemLink, oldGrade, newGrade, source)
	if not ok then
		failure = entry
		entry = nil
		pcall(logbook.LogError, failure)
	end
	pcall(logbook.Trace, failure and ("error: " .. tostring(failure)) or (entry and "saved" or "not saved"),
		characterName, resultCode, itemLink, oldGrade, newGrade)
	if entry == nil then
		return -- not saved (error already logged, or a repeated broadcast)
	end
	if not logbook.IsLoss(entry) then
		return -- successes are logged but leave the light alone
	end
	-- a UI problem must never stop logging
	runSafe(function()
		local state = statusdot.LOST
		if entry.result == logbook.DESTROYED then
			state = statusdot.DESTROYED
		end
		statusdot.MarkLoss(state, logbook.Describe(entry))
	end)
end

-- regrade totals for the startup line, e.g. ", 158 regrades logged (40 losses)"
function feature.StartupInfo()
	local counts = runSafe(logbook.Counts)
	if counts == nil then
		return nil
	end
	return counts.regrades .. " regrades logged (" .. counts.losses .. " losses)"
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
		statusdot.Create(logbook.Counts)
	end)
end

function feature.Disable()
	if not enabled then
		return
	end
	enabled = false
	runSafe(statusdot.Free)
end

-- main.lua calls these from its event window

-- GRADE_ENCHANT_BROADCAST: server-wide announcement of anyone's regrade (not received at the moment)
function feature.OnGradeEnchantBroadcast(characterName, resultCode, itemLink, oldGrade, newGrade)
	if not enabled then
		pcall(logbook.Trace, "disabled", characterName, resultCode, itemLink, oldGrade, newGrade)
		return
	end
	-- same arguments loss_porn reads
	onRegrade(characterName, resultCode, itemLink, oldGrade, newGrade, "broadcast")
end

-- GRADE_ENCHANT_RESULT: your own regrade, same codes without the character name
-- (a fifth value is always 0)
function feature.OnGradeEnchantResult(resultCode, itemLink, oldGrade, newGrade)
	local characterName = runSafe(function()
		return api.Unit:UnitName("player")
	end) or "unknown"
	if not enabled then
		pcall(logbook.Trace, "disabled", characterName, resultCode, itemLink, oldGrade, newGrade)
		return
	end
	onRegrade(characterName, resultCode, itemLink, oldGrade, newGrade, "self")
end

return feature
