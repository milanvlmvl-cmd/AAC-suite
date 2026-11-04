local api = require("api")
local clock = require("PlayerDB/clock")
local settings = require("PlayerDB/settings")

-- One light showing failed regrades seen since it was last cleared:
--   green  (a.png) none
--   yellow (c.png) an item was downgraded or anchored
--   red    (b.png) an item was destroyed (stays red until cleared)
-- Hover for the last loss and the totals, click to clear it, drag it to move it.
local statusdot = {}

statusdot.CLEAR = "clear"
statusdot.LOST = "lost"
statusdot.DESTROYED = "destroyed"

local IMAGE_DIR = api.baseDir .. "/PlayerDB/images/"
local TEXTURES = {
	[statusdot.CLEAR] = IMAGE_DIR .. "a.png",
	[statusdot.LOST] = IMAGE_DIR .. "c.png",
	[statusdot.DESTROYED] = IMAGE_DIR .. "b.png",
}
-- a state only replaces one ranked lower, so a destroyed item is not hidden by a later anchor
local RANK = {
	[statusdot.CLEAR] = 0,
	[statusdot.LOST] = 1,
	[statusdot.DESTROYED] = 2,
}
-- position kept in the addon settings (settings.lua)
local POSITION_X = "RegradeDotX"
local POSITION_Y = "RegradeDotY"
local DOT_SIZE = 16
local DEFAULT_X = 400
local DEFAULT_Y = 440

local window = nil
local dot = nil
local state = statusdot.CLEAR
-- losses since the light was last cleared
local unseen = 0
-- now() and description of the last loss
local lastTime = nil
local lastText = nil
-- returns the totals table for the tooltip
local countsFn = nil

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

local function setTexture()
	if dot ~= nil then
		dot:SetTexture(TEXTURES[state])
	end
end

local function tooltipText()
	local text = "Regrade losses"
	if unseen > 0 then
		text = text .. "\nNew: " .. unseen .. " (click to clear)"
	else
		text = text .. "\nNo new losses"
	end
	if lastText == nil then
		text = text .. "\nLast: none this session"
	else
		local current = now()
		text = text .. "\nLast: " .. lastText
		if current ~= nil and lastTime ~= nil then
			text = text .. ", " .. formatAgo(current - lastTime)
		end
	end
	if countsFn ~= nil then
		local ok, counts = pcall(countsFn)
		if ok and type(counts) == "table" then
			text = text .. "\nLosses: " .. tostring(counts.losses)
				.. " (destroyed " .. tostring(counts.destroyed)
				.. ", downgraded " .. tostring(counts.downgraded)
				.. ", anchored " .. tostring(counts.anchored) .. ")"
				.. "\nSuccesses: " .. tostring(counts.successes)
				.. " (great " .. tostring(counts.great_success) .. ")"
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

-- keeps the "ago" time ticking while the mouse stays on the light
local function refreshTooltip(button, id)
	api:DoIn(TOOLTIP_REFRESH_MS, function()
		if id ~= hoverId or window == nil then
			return -- mouse left or unloaded
		end
		pcall(showTooltip, button)
		refreshTooltip(button, id)
	end)
end

-- invisible button over the light, for the hover tooltip and click to clear
local function createHoverArea()
	local button = window:CreateChildWidget("button", "PlayerDBRegradeDotHover", 0, true)
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
	function button:OnClick()
		statusdot.Clear()
		pcall(showTooltip, button)
	end
	button:SetHandler("OnClick", button.OnClick)
	attachDrag(button)
	button:Show(true)
end

function statusdot.Create(getCounts)
	if window ~= nil then
		return
	end
	countsFn = getCounts
	local x, y = loadPosition()
	window = api.Interface:CreateEmptyWindow("PlayerDBRegradeDot")
	window:AddAnchor("TOPLEFT", "UIParent", x, y)
	window:SetExtent(DOT_SIZE, DOT_SIZE)
	window:SetCloseOnEscape(false)

	dot = window:CreateImageDrawable("PlayerDBRegradeDotImage", "artwork")
	dot:AddAnchor("TOPLEFT", window, 0, 0)
	dot:SetExtent(DOT_SIZE, DOT_SIZE)
	state = statusdot.CLEAR
	setTexture()
	dot:Show(true)
	createHoverArea()
	attachDrag(window)

	window:Show(true)
end

-- A loss was just logged: newState is LOST or DESTROYED, text describes it for the tooltip.
function statusdot.MarkLoss(newState, text)
	unseen = unseen + 1
	lastTime = now()
	lastText = text
	if RANK[newState] ~= nil and RANK[newState] > RANK[state] then
		state = newState
		setTexture()
	end
end

-- Back to green; the last loss stays in the tooltip.
function statusdot.Clear()
	unseen = 0
	state = statusdot.CLEAR
	setTexture()
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
	state = statusdot.CLEAR
	unseen = 0
	lastTime = nil
	lastText = nil
	countsFn = nil
end

return statusdot
