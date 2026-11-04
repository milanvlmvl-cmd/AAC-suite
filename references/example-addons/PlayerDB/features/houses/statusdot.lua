local api = require("api")
local clock = require("PlayerDB/clock")
local settings = require("PlayerDB/settings")

-- One dot showing the state of the current target:
--   green  (a.png) the targeted building has been logged
--   red    (b.png) no building targeted, or still locating it
--   yellow (c.png) the targeted building is too far away to log
-- Hover for details, the last logged building and the house count. Drag it to move it.
local statusdot = {}

statusdot.NONE = "none"
statusdot.LOCATING = "locating"
statusdot.FAR = "far"
statusdot.LOGGED = "logged"

local IMAGE_DIR = api.baseDir .. "/PlayerDB/images/"
local GREEN = IMAGE_DIR .. "a.png"
local RED = IMAGE_DIR .. "b.png"
local YELLOW = IMAGE_DIR .. "c.png"
local TEXTURES = {
	[statusdot.NONE] = RED,
	[statusdot.LOCATING] = RED,
	[statusdot.FAR] = YELLOW,
	[statusdot.LOGGED] = GREEN,
}
-- position kept in the addon settings (settings.lua)
local POSITION_X = "HouseDotX"
local POSITION_Y = "HouseDotY"
local DOT_SIZE = 16
local DEFAULT_X = 400
local DEFAULT_Y = 420

local window = nil
local dot = nil
local state = statusdot.NONE
-- distance (m) of the targeted building while state is FAR
local farDistance = nil
-- now() of the last logged building
local lastScan = nil
-- last building logged, shown in the tooltip
local lastName = nil
-- returns the house count for the tooltip
local countFn = nil

local function loadPosition()
	local x, y = tonumber(settings.Get(POSITION_X)), tonumber(settings.Get(POSITION_Y))
	if x ~= nil and y ~= nil then
		return x, y
	end
	return DEFAULT_X, DEFAULT_Y
end

local function savePosition()
	local x, y = window:GetEffectiveOffset()
	if x == nil or y == nil then
		return
	end
	settings.Update(POSITION_X, math.floor(x + 0.5))
	settings.Update(POSITION_Y, math.floor(y + 0.5))
end

-- seconds on a steadily running clock; only differences are used
local function now()
	local ok, msec = pcall(function()
		return api.Time:GetUiMsec()
	end)
	msec = ok and tonumber(msec) or nil
	if msec ~= nil then
		return msec / 1000
	end
	local okLocal, time = pcall(function()
		return clock.Now()
	end)
	return okLocal and tonumber(time) or nil
end

local function formatAgo(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return seconds .. "s ago"
	end
	local minutes = math.floor(seconds / 60)
	if minutes < 60 then
		return minutes .. "m " .. (seconds % 60) .. "s ago"
	end
	return math.floor(minutes / 60) .. "h " .. (minutes % 60) .. "m ago"
end

local function tooltipText()
	local text = "House scan"
	if state == statusdot.LOGGED then
		text = text .. "\nTarget logged"
	elseif state == statusdot.LOCATING then
		text = text .. "\nLocating target, keep it targeted"
	elseif state == statusdot.FAR then
		text = text .. "\nTarget out of range (" .. string.format("%.0f", farDistance or 0) .. "m), move closer"
	else
		text = text .. "\nNo house targeted"
	end
	local current = now()
	if lastScan == nil then
		text = text .. "\nLast: never"
	elseif current == nil then
		text = text .. "\nLast: unknown"
	else
		text = text .. "\nLast: " .. formatAgo(current - lastScan)
	end
	if lastName ~= nil then
		text = text .. " (" .. lastName .. ")"
	end
	if countFn ~= nil then
		local ok, count = pcall(countFn)
		if ok and count ~= nil then
			text = text .. "\nHouses: " .. tostring(count)
		end
	end
	return text
end

local function attachDrag(widget)
	function widget:OnDragStart()
		window:StartMoving()
		api.Cursor:ClearCursor()
		api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
	end
	widget:SetHandler("OnDragStart", widget.OnDragStart)
	function widget:OnDragStop()
		window:StopMovingOrSizing()
		api.Cursor:ClearCursor()
		savePosition()
	end
	widget:SetHandler("OnDragStop", widget.OnDragStop)
	if widget.RegisterForDrag ~= nil then
		widget:RegisterForDrag("LeftButton")
	end
	widget:EnableDrag(true)
end

local TOOLTIP_REFRESH_MS = 1000
-- bumped on every hover change; a refresh loop from an earlier hover sees a newer id and stops
local hoverId = 0

local function showTooltip(button)
	local x, y = button:GetEffectiveOffset()
	-- clear first so the client redraws the text instead of keeping the old tooltip
	api.Interface:SetTooltipOnPos("", button, 0, 0)
	api.Interface:SetTooltipOnPos(tooltipText(), button, x + button:GetWidth(), y)
end

-- keeps the "ago" time ticking while the mouse stays on the dot
local function refreshTooltip(button, id)
	api:DoIn(TOOLTIP_REFRESH_MS, function()
		if id ~= hoverId or window == nil then
			return -- mouse left or unloaded
		end
		pcall(showTooltip, button)
		refreshTooltip(button, id)
	end)
end

-- invisible button over the dot, for the hover tooltip
local function createHoverArea()
	local button = window:CreateChildWidget("button", "PlayerDBHouseDotHover", 0, true)
	button:AddAnchor("TOPLEFT", window, 0, 0)
	button:SetExtent(DOT_SIZE, DOT_SIZE)
	function button:OnEnter()
		hoverId = hoverId + 1
		showTooltip(button)
		refreshTooltip(button, hoverId)
	end
	button:SetHandler("OnEnter", button.OnEnter)
	function button:OnLeave()
		hoverId = hoverId + 1
		api.Interface:SetTooltipOnPos("", button, 0, 0)
	end
	button:SetHandler("OnLeave", button.OnLeave)
	attachDrag(button)
	button:Show(true)
end

function statusdot.Create(getCount)
	if window ~= nil then
		return
	end
	countFn = getCount
	local x, y = loadPosition()
	window = api.Interface:CreateEmptyWindow("PlayerDBHouseDot")
	window:AddAnchor("TOPLEFT", "UIParent", x, y)
	window:SetExtent(DOT_SIZE, DOT_SIZE)
	window:SetCloseOnEscape(false)

	dot = window:CreateImageDrawable("PlayerDBHouseDotImage", "artwork")
	dot:AddAnchor("TOPLEFT", window, 0, 0)
	dot:SetExtent(DOT_SIZE, DOT_SIZE)
	state = statusdot.NONE
	dot:SetTexture(TEXTURES[state])
	dot:Show(true)
	createHoverArea()
	attachDrag(window)

	window:Show(true)
end

-- Sets the dot to one of the states above; distance is only used with FAR.
function statusdot.SetState(newState, distance)
	farDistance = distance
	if newState == state then
		return
	end
	state = newState
	if dot ~= nil then
		dot:SetTexture(TEXTURES[state])
	end
end

-- A building was just saved: remember it for the tooltip and go green.
function statusdot.MarkLogged(name)
	lastScan = now()
	lastName = name
	statusdot.SetState(statusdot.LOGGED)
end

function statusdot.Free()
	if window == nil then
		return
	end
	-- stop a running tooltip refresh, then hide before freeing (as WorldSatNav unloads its windows)
	hoverId = hoverId + 1
	window:Show(false)
	api.Interface:Free(window)
	window = nil
	dot = nil
	state = statusdot.NONE
	farDistance = nil
	lastScan = nil
	lastName = nil
	countFn = nil
end

return statusdot
