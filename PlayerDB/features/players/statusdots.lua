local api = require("api")
local clock = require("PlayerDB/clock")
local settings = require("PlayerDB/settings")

-- Three dots in a row showing scan activity: player, target, raid.
-- Each scan flips its dot between a.png and b.png. Drag the row to move it.
local statusdots = {}

statusdots.PLAYER = 1
statusdots.TARGET = 2
statusdots.RAID = 3

local NAMES = { "Player scan", "Target scan", "Raid scan" }

local IMAGE_DIR = api.baseDir .. "/PlayerDB/images/"
local TEXTURES = { IMAGE_DIR .. "a.png", IMAGE_DIR .. "b.png" }
-- position kept in the addon settings (settings.lua)
local POSITION_X = "PlayerDotsX"
local POSITION_Y = "PlayerDotsY"
local DOT_COUNT = 3
local DOT_SIZE = 16
local DOT_GAP = 4
local DEFAULT_X = 400
local DEFAULT_Y = 400

local window = nil
local dots = {}
-- texture index (1 or 2) currently shown by each dot
local states = {}
-- now() of each dot's last scan
local lastScan = {}

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

-- seconds on a steadily running clock; only differences are used.
-- GetLocalTime only moves in coarse steps, so prefer the UI msec clock (clock.lua as fallback).
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

local function tooltipText(index)
	local last = lastScan[index]
	local current = now()
	if last == nil then
		return NAMES[index] .. "\nLast: never"
	end
	if current == nil then
		return NAMES[index] .. "\nLast: unknown"
	end
	return NAMES[index] .. "\nLast: " .. formatAgo(current - last)
end

-- dragging any part of the row moves the whole window
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

local function showTooltip(button, index)
	local x, y = button:GetEffectiveOffset()
	-- clear first so the client redraws the text instead of keeping the old tooltip
	api.Interface:SetTooltipOnPos("", button, 0, 0)
	api.Interface:SetTooltipOnPos(tooltipText(index), button, x + button:GetWidth(), y)
end

-- keeps the "ago" time ticking while the mouse stays on the dot
local function refreshTooltip(button, index, id)
	api:DoIn(TOOLTIP_REFRESH_MS, function()
		if id ~= hoverId or window == nil then
			return -- mouse left, moved to another dot, or unloaded
		end
		pcall(showTooltip, button, index)
		refreshTooltip(button, index, id)
	end)
end

-- invisible button over a dot, for the hover tooltip
local function createHoverArea(index, offsetX)
	local button = window:CreateChildWidget("button", "PlayerDBStatusDotHover" .. index, 0, true)
	button:AddAnchor("TOPLEFT", window, offsetX, 0)
	button:SetExtent(DOT_SIZE, DOT_SIZE)
	function button:OnEnter()
		hoverId = hoverId + 1
		showTooltip(button, index)
		refreshTooltip(button, index, hoverId)
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

function statusdots.Create()
	if window ~= nil then
		return
	end
	local x, y = loadPosition()
	window = api.Interface:CreateEmptyWindow("PlayerDBStatusDots")
	window:AddAnchor("TOPLEFT", "UIParent", x, y)
	window:SetExtent(DOT_COUNT * DOT_SIZE + (DOT_COUNT - 1) * DOT_GAP, DOT_SIZE)
	window:SetCloseOnEscape(false)

	for i = 1, DOT_COUNT do
		local offsetX = (i - 1) * (DOT_SIZE + DOT_GAP)
		local dot = window:CreateImageDrawable("PlayerDBStatusDot" .. i, "artwork")
		dot:AddAnchor("TOPLEFT", window, offsetX, 0)
		dot:SetExtent(DOT_SIZE, DOT_SIZE)
		dot:SetTexture(TEXTURES[1])
		dot:Show(true)
		dots[i] = dot
		states[i] = 1
		createHoverArea(i, offsetX)
	end

	-- the gaps between dots drag too
	attachDrag(window)

	window:Show(true)
end

-- Swaps the dot for a scan between a.png and b.png.
function statusdots.Toggle(index)
	local dot = dots[index]
	if dot == nil then
		return
	end
	states[index] = 3 - states[index]
	dot:SetTexture(TEXTURES[states[index]])
	lastScan[index] = now()
end

function statusdots.Free()
	if window == nil then
		return
	end
	-- stop a running tooltip refresh, then hide before freeing (as WorldSatNav unloads its windows)
	hoverId = hoverId + 1
	window:Show(false)
	api.Interface:Free(window)
	window = nil
	dots = {}
	states = {}
	lastScan = {}
end

return statusdots
