local api = require("api")
local clock = require("PlayerDB/clock")
local settings = require("PlayerDB/settings")

-- A floppy disk with a bag on it (images/inventory.png). Hover for the last scan, click to scan now,
-- drag it to move it.
local icon = {}

local IMAGE = api.baseDir .. "/PlayerDB/images/inventory.png"
-- position kept in the addon settings (settings.lua)
local POSITION_X = "InventoryIconX"
local POSITION_Y = "InventoryIconY"
local ICON_SIZE = 32
local DEFAULT_X = 400
local DEFAULT_Y = 460

local window = nil
-- called when the icon is clicked
local clickFn = nil
-- summary and time of the last scan, for the tooltip
local lastSummary = nil
local lastTime = nil

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
	local text = "Inventory log\nClick to scan now"
	if lastSummary == nil then
		return text .. "\nNo scan yet this session"
	end
	text = text .. "\nItems: " .. lastSummary.items
	local current = now()
	if current ~= nil and lastTime ~= nil then
		text = text .. "\nScanned " .. formatAgo(current - lastTime)
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

-- keeps the "ago" time ticking while the mouse stays on the icon
local function refreshTooltip(button, id)
	api:DoIn(TOOLTIP_REFRESH_MS, function()
		if id ~= hoverId or window == nil then
			return -- mouse left or unloaded
		end
		pcall(showTooltip, button)
		refreshTooltip(button, id)
	end)
end

-- invisible button over the icon, for the hover tooltip and click to scan
local function createHoverArea()
	local button = window:CreateChildWidget("button", "PlayerDBInventoryIconHover", 0, true)
	button:AddAnchor("TOPLEFT", window, 0, 0)
	button:SetExtent(ICON_SIZE, ICON_SIZE)
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
		if clickFn ~= nil then
			clickFn()
		end
		pcall(showTooltip, button)
	end
	button:SetHandler("OnClick", button.OnClick)
	attachDrag(button)
	button:Show(true)
end

-- onClick() is called when the icon is clicked
function icon.Create(onClick)
	if window ~= nil then
		return
	end
	clickFn = onClick
	local x, y = loadPosition()
	window = api.Interface:CreateEmptyWindow("PlayerDBInventoryIcon")
	window:AddAnchor("TOPLEFT", "UIParent", x, y)
	window:SetExtent(ICON_SIZE, ICON_SIZE)
	window:SetCloseOnEscape(false)

	local image = window:CreateImageDrawable("PlayerDBInventoryIconImage", "artwork")
	image:AddAnchor("TOPLEFT", window, 0, 0)
	image:SetExtent(ICON_SIZE, ICON_SIZE)
	image:SetTexture(IMAGE)
	image:Show(true)
	createHoverArea()
	attachDrag(window)

	window:Show(true)
end

-- A scan just finished; summary is { items }.
function icon.SetScan(summary)
	lastSummary = summary
	lastTime = now()
end

function icon.Free()
	if window == nil then
		return
	end
	-- stop a running tooltip refresh, then hide before freeing (as WorldSatNav unloads its windows)
	hoverId = hoverId + 1
	window:Show(false)
	api.Interface:Free(window)
	window = nil
	clickFn = nil
	lastSummary = nil
	lastTime = nil
end

return icon
