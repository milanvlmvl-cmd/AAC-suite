local api = require("api")

-- Timestamps for everything written to file, the same way WorldSatNav does it (helpers/datetime.lua):
-- api.Time:GetLocalTime() only moves in coarse steps, so the last value is kept and advanced by the
-- frame time on every UPDATE (main.lua calls clock.Advance), and only replaced when the game's own
-- time moves past it.
local clock = {}

local state = {
	lastKnownLocalTime = nil,
	lastReturnedTimestamp = nil,
}

local function localTime()
	local ok, value = pcall(function()
		return api.Time:GetLocalTime()
	end)
	if ok and type(value) == "number" then
		return value
	end
	return tonumber(ok and value or nil)
end

-- Unix seconds (may have a fraction), or nil if the game gives no time yet.
function clock.Now()
	local current = localTime()
	if current ~= nil then
		if state.lastKnownLocalTime == nil or current > state.lastKnownLocalTime then
			state.lastKnownLocalTime = current
		end
		if state.lastReturnedTimestamp == nil or current > state.lastReturnedTimestamp then
			state.lastReturnedTimestamp = current
		end
	end
	return state.lastReturnedTimestamp or current
end

-- Called every frame with dt in milliseconds (WorldSatNav's AdvanceCurrentTimestamp).
function clock.Advance(dt)
	local deltaMsec = tonumber(dt)
	if deltaMsec == nil then
		return
	end
	if state.lastReturnedTimestamp == nil then
		clock.Now()
	end
	if state.lastReturnedTimestamp ~= nil and deltaMsec > 0 then
		state.lastReturnedTimestamp = state.lastReturnedTimestamp + (deltaMsec / 1000)
	end
end

-- Whole-second timestamp as a string, the form stored in the data files ("1792324424"), or nil.
function clock.NowText()
	local now = clock.Now()
	if now == nil then
		return nil
	end
	return string.format("%.0f", math.floor(now))
end

return clock
