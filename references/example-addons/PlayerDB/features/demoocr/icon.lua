local api = require("api")
local settings = require("PlayerDB/settings")

-- A burning house (images/demoocr.png). Click to start a request; while it waits the house is replaced
-- by a spinning wheel, then a tick when done. Drag it to move it.
-- The wheel is one sprite sheet (images/spinner.png, 8 frames of 64x64 in a row); SetCoords moves along it.
local icon = {}

local IMAGE_DIR = api.baseDir .. "/PlayerDB/images/"
local HOUSE = IMAGE_DIR .. "demoocr.png"
-- the house with a green tick, shown for DONE_MS after a request finishes
local HOUSE_DONE = IMAGE_DIR .. "demoocr_done.png"
local DONE_MS = 5 * 1000
local SPINNER =IMAGE_DIR .. "spinner.png"
local SPINNER_FRAMES = 8
local SPINNER_FRAME_SIZE = 64
local SPINNER_FRAME_MS = 100
-- position kept in the addon settings (settings.lua)
local POSITION_X = "DemoOCRIconX"
local POSITION_Y = "DemoOCRIconY"
local ICON_SIZE = 32
local DEFAULT_X = 400
local DEFAULT_Y = 500

local window = nil
local image = nil
local spinnerImage = nil
local doneImage = nil
-- called when the icon is clicked
local clickFn = nil
local busy = false
-- bumped whenever the spinner starts or stops; an older frame timer sees a newer id and stops
local spinnerId = 0
-- same for the tick timer; bumped when a request starts, so the tick can't cut a new request short
local doneId = 0
-- text shown in the tooltip
local statusText = "Click to start"

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

local function tooltipText()
	return "DemoOCR\n" .. statusText
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

local function showTooltip(button)
	local x, y = button:GetEffectiveOffset()
	-- clear first so the client redraws the text instead of keeping the old tooltip
	api.Interface:SetTooltipOnPos("", button, 0, 0)
	api.Interface:SetTooltipOnPos(tooltipText(), button, x + button:GetWidth(), y)
end

-- invisible button over the icon, for the hover tooltip and click
local function createHoverArea()
	local button = window:CreateChildWidget("button", "PlayerDBDemoOCRIconHover", 0, true)
	button:AddAnchor("TOPLEFT", window, 0, 0)
	button:SetExtent(ICON_SIZE, ICON_SIZE)
	function button:OnEnter()
		showTooltip(button)
	end
	button:SetHandler("OnEnter", button.OnEnter)
	function button:OnLeave()
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
	window = api.Interface:CreateEmptyWindow("PlayerDBDemoOCRIcon")
	window:AddAnchor("TOPLEFT", "UIParent", x, y)
	window:SetExtent(ICON_SIZE, ICON_SIZE)
	window:SetCloseOnEscape(false)

	image = window:CreateImageDrawable("PlayerDBDemoOCRIconImage", "artwork")
	image:AddAnchor("TOPLEFT", window, 0, 0)
	image:SetExtent(ICON_SIZE, ICON_SIZE)
	image:SetTexture(HOUSE)
	image:Show(true)

	spinnerImage = window:CreateImageDrawable("PlayerDBDemoOCRIconSpinner", "artwork")
	spinnerImage:AddAnchor("TOPLEFT", window, 0, 0)
	spinnerImage:SetExtent(ICON_SIZE, ICON_SIZE)
	spinnerImage:SetTexture(SPINNER)
	spinnerImage:SetCoords(0, 0, SPINNER_FRAME_SIZE, SPINNER_FRAME_SIZE)
	spinnerImage:Show(false)

	doneImage = window:CreateImageDrawable("PlayerDBDemoOCRIconDone", "artwork")
	doneImage:AddAnchor("TOPLEFT", window, 0, 0)
	doneImage:SetExtent(ICON_SIZE, ICON_SIZE)
	doneImage:SetTexture(HOUSE_DONE)
	doneImage:Show(false)
	createHoverArea()
	attachDrag(window)

	window:Show(true)
end

-- frame is 0-based: the nth 64px slice of the sheet
local function showFrame(frame)
	spinnerImage:SetCoords(frame * SPINNER_FRAME_SIZE, 0, SPINNER_FRAME_SIZE, SPINNER_FRAME_SIZE)
end

local function spin(id, frame)
	api:DoIn(SPINNER_FRAME_MS, function()
		if id ~= spinnerId or spinnerImage == nil then
			return -- stopped or unloaded
		end
		frame = (frame + 1) % SPINNER_FRAMES
		showFrame(frame)
		spin(id, frame)
	end)
end

-- Waiting on a request: the house turns into a spinning wheel. Done: back to the house.
function icon.SetBusy(isBusy, text)
	statusText = text or statusText
	if isBusy == busy then
		return
	end
	busy = isBusy
	spinnerId = spinnerId + 1
	if image == nil or spinnerImage == nil then
		return
	end
	if busy then
		doneId = doneId + 1
		doneImage:Show(false)
		image:Show(false)
		showFrame(0)
		spinnerImage:Show(true)
		spin(spinnerId, 0)
	else
		spinnerImage:Show(false)
		image:Show(true)
	end
end

-- The request finished: the house shows a tick for DONE_MS, then goes back to the plain house.
function icon.SetDone(text)
	statusText = text or statusText
	busy = false
	spinnerId = spinnerId + 1
	doneId = doneId + 1
	if image == nil or spinnerImage == nil or doneImage == nil then
		return
	end
	spinnerImage:Show(false)
	image:Show(false)
	doneImage:Show(true)
	local id = doneId
	api:DoIn(DONE_MS, function()
		if id ~= doneId or doneImage == nil then
			return -- a new request started, or unloaded
		end
		doneImage:Show(false)
		image:Show(true)
		statusText = "Click to start"
	end)
end

function icon.SetStatus(text)
	statusText = text
end

function icon.Free()
	if window == nil then
		return
	end
	-- stop a running spinner, then hide before freeing (as WorldSatNav unloads its windows)
	spinnerId = spinnerId + 1
	doneId = doneId + 1
	window:Show(false)
	api.Interface:Free(window)
	window = nil
	image = nil
	spinnerImage = nil
	doneImage = nil
	clickFn = nil
	busy = false
	statusText = "Click to start"
end

return icon
