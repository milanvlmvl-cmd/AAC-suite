-- ForSale: house sale events (listing, cancelling, buying, sold). For now it only logs them raw
-- to PlayerDB/ForSale/events.dat, to confirm what the client provides.
local api = require("api")
local logbook = require("PlayerDB/features/forsale/logbook")

local feature = {
	id = "forsale",
	label = "ForSale",
}

local enabled = false

local function runSafe(fn)
	local ok, result = pcall(fn)
	if not ok then
		api.Log:Info("[PlayerDB ForSale] error: " .. tostring(result))
		return nil
	end
	return result
end

-- empties this feature's logged data
function feature.ResetData()
	return logbook.ResetData()
end

function feature.Enable()
	enabled = true
end

function feature.Disable()
	enabled = false
end

-- main.lua calls this from its event window for every house sale event
-- (the addon sandbox has no select(), so arguments come in as a1..a8)
function feature.OnHouseEvent(event, a1, a2, a3, a4, a5, a6, a7, a8)
	if not enabled then
		return
	end
	runSafe(function()
		logbook.LogEvent(event, a1, a2, a3, a4, a5, a6, a7, a8)
	end)
end

return feature
