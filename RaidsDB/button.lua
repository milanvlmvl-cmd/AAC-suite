local api = require("api")

-- One button that starts and stops the raid log:
--   red record (record.png) not recording, click to start a new raid
--   green save (save.png)   recording, click to stop and save it to Raids/
-- Hover for the raid so far, drag it to move it.
local button = {}

local IMAGE_DIR = api.baseDir .. "/RaidsDB/images/"
local TEXTURE_IDLE = IMAGE_DIR .. "record.png"
local TEXTURE_RECORDING = IMAGE_DIR .. "save.png"
local POSITION_PATH = "RaidsDB/ui.dat"
local DOT_SIZE = 24
local DEFAULT_X = 420
local DEFAULT_Y = 440
local TOOLTIP_REFRESH_MS = 1000

local window = nil
local dot = nil
-- called on click
local onClickFn = nil
-- returns the tooltip text
local statusFn = nil
-- bumped on every hover change; a refresh loop from an earlier hover sees a newer id and stops
local hoverId = 0

local function loadPosition()
	local saved = api.File:Read(POSITION_PATH)
	if type(saved) == "table" then
		local x, y = tonumber(saved.x), tonumber(saved.y)
		if x ~= nil and y ~= nil then
			return x, y
		end
	end
	return DEFAULT_X, DEFAULT_Y
end

local function savePosition()
	local x, y = window:GetEffectiveOffset()
	if x == nil or y == nil then
		return
	end
	api.File:Write(POSITION_PATH, {
		x = string.format("%.0f", x),
		y = string.format("%.0f", y),
	})
end

local function tooltipText()
	if statusFn == nil then
		return "Raid drops"
	end
	local ok, text = pcall(statusFn)
	if ok and type(text) == "string" then
		return text
	end
	return "Raid drops"
end

local function showTooltip(widget)
	local x, y = widget:GetEffectiveOffset()
	-- clear first so the client redraws the text instead of keeping the old tooltip
	api.Interface:SetTooltipOnPos("", widget, 0, 0)
	api.Interface:SetTooltipOnPos(tooltipText(), widget, x + widget:GetWidth(), y)
end

-- keeps the counts and times current while the mouse stays on the button
local function refreshTooltip(widget, id)
	api:DoIn(TOOLTIP_REFRESH_MS, function()
		if id ~= hoverId or window == nil then
			return -- mouse left or unloaded
		end
		pcall(showTooltip, widget)
		refreshTooltip(widget, id)
	end)
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

-- invisible button over the image, for the hover tooltip and click to start/stop
local function createHoverArea()
	local hover = window:CreateChildWidget("button", "RaidsDBButtonHover", 0, true)
	hover:AddAnchor("TOPLEFT", window, 0, 0)
	hover:SetExtent(DOT_SIZE, DOT_SIZE)
	function hover:OnEnter()
		hoverId = hoverId + 1
		showTooltip(hover)
		refreshTooltip(hover, hoverId)
	end
	hover:SetHandler("OnEnter", hover.OnEnter)
	function hover:OnLeave()
		hoverId = hoverId + 1
		api.Interface:SetTooltipOnPos("", hover, 0, 0)
	end
	hover:SetHandler("OnLeave", hover.OnLeave)
	function hover:OnClick()
		if onClickFn ~= nil then
			onClickFn()
		end
		pcall(showTooltip, hover)
	end
	hover:SetHandler("OnClick", hover.OnClick)
	attachDrag(hover)
	hover:Show(true)
end

-- onClick() runs on click, getStatus() returns the tooltip text
function button.Create(onClick, getStatus)
	if window ~= nil then
		return
	end
	onClickFn = onClick
	statusFn = getStatus
	local x, y = loadPosition()
	window = api.Interface:CreateEmptyWindow("RaidsDBButton")
	window:AddAnchor("TOPLEFT", "UIParent", x, y)
	window:SetExtent(DOT_SIZE, DOT_SIZE)
	window:SetCloseOnEscape(false)

	dot = window:CreateImageDrawable("RaidsDBButtonImage", "artwork")
	dot:AddAnchor("TOPLEFT", window, 0, 0)
	dot:SetExtent(DOT_SIZE, DOT_SIZE)
	dot:SetTexture(TEXTURE_IDLE)
	dot:Show(true)
	createHoverArea()
	attachDrag(window)

	window:Show(true)
end

function button.SetRecording(recording)
	if dot ~= nil then
		dot:SetTexture(recording and TEXTURE_RECORDING or TEXTURE_IDLE)
	end
end

function button.Free()
	if window == nil then
		return
	end
	api.Interface:Free(window)
	window = nil
	dot = nil
	onClickFn = nil
	statusFn = nil
end

return button
