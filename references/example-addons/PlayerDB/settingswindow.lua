local api = require("api")

-- Settings window opened from the addon manager (OnSettingToggle):
-- one checkbox per feature (changes apply right away and are saved) and a Reset data button.
-- Look and checkbox logic copied from WorldSatNav's settings page (ui/configui.lua, helpers/widgets.lua).
local settingswindow = {}

local IMAGE_DIR = api.baseDir .. "/PlayerDB/images/"
local BACKGROUND = IMAGE_DIR .. "settingsbackground.png"
local CHECKED = IMAGE_DIR .. "controls/checkbox_checked.png"
local UNCHECKED = IMAGE_DIR .. "controls/checkbox_unchecked.png"
local CLICK_SOUND = "auction_put_up"

local WINDOW_WIDTH = 300
local PADDING = 25
local TITLE_Y = 10
local DIVIDER_Y = 40
-- first checkbox row
local TOP = 55
local ROW_HEIGHT = 30
local CHECKBOX_SIZE = 25
local FONT_SIZE = 14
-- reset button, below the checkboxes
local RESET_GAP = 10
local RESET_WIDTH = 140
local RESET_HEIGHT = 26
local RESET_TEXT = "Reset data"
local RESET_CONFIRM_TEXT = "Click to confirm"
-- the second click must come within this time, or the button goes back to RESET_TEXT
local RESET_CONFIRM_MS = 5000

local window = nil
local closeButton = nil
local resetButton = nil
-- bumped on every reset click; an older confirm timeout sees a newer id and leaves the button alone
local resetClickId = 0
local resetArmed = false
-- parts of each checkbox, hidden and released on unload
local checkboxes = {}

-- dragging the window moves it
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
	end
	widget:SetHandler("OnDragStop", widget.OnDragStop)
	if widget.RegisterForDrag ~= nil then
		widget:RegisterForDrag("LeftButton")
	end
	widget:EnableDrag(true)
end

local function createTitle(height)
	local background = window:CreateImageDrawable("PlayerDBSettingsBackground", "background")
	background:SetExtent(WINDOW_WIDTH, height)
	background:AddAnchor("TOPLEFT", window, "TOPLEFT", 0, 0)
	background:SetTexture(BACKGROUND)
	background:Show(true)
	if background.Lower then
		background:Lower()
	end

	local title = api.Interface:CreateWidget("label", "PlayerDBSettingsTitle", window)
	title:AddAnchor("TOPLEFT", window, PADDING, TITLE_Y)
	title:SetExtent(WINDOW_WIDTH - 2 * PADDING, 30)
	title:SetText("PlayerDB Settings")
	title.style:SetColor(FONT_COLOR.TITLE[1], FONT_COLOR.TITLE[2], FONT_COLOR.TITLE[3], 1)
	title.style:SetAlign(ALIGN.LEFT)
	title.style:SetFontSize(20)
	title:Show(true)

	local divider = window:CreateImageDrawable("PlayerDBSettingsDivider", "background")
	divider:SetExtent(WINDOW_WIDTH - 2 * PADDING, 3)
	divider:AddAnchor("TOPLEFT", window, "TOPLEFT", PADDING, DIVIDER_Y)
	divider:SetTexture("bg_quest")
	divider:SetColor(0, 0, 0, 0.5)
	divider:Show(true)

	closeButton = window:CreateChildWidget("button", "PlayerDBSettingsClose", 0, true)
	closeButton:AddAnchor("TOPLEFT", window, WINDOW_WIDTH - 20, 3)
	api.Interface:ApplyButtonSkin(closeButton, BUTTON_BASIC.WINDOW_SMALL_CLOSE)
	closeButton:SetHandler("OnClick", function()
		window:Show(false)
	end)
	closeButton:Show(true)
end

-- Checkbox image with an invisible button over it and over its text, as WorldSatNav does.
-- onClick(newChecked) is called when the box is clicked.
local function createCheckbox(id, text, offsetX, offsetY, checked, onClick)
	local overlay = window:CreateImageDrawable(id .. "CheckBoxOverlay", "artwork")
	overlay:AddAnchor("TOPLEFT", window, offsetX, offsetY)
	overlay:SetExtent(CHECKBOX_SIZE, CHECKBOX_SIZE)
	overlay:SetTexture(checked and CHECKED or UNCHECKED)
	overlay:Show(true)

	local button = window:CreateChildWidget("button", id .. "CheckBoxButton", 0, true)
	button:AddAnchor("TOPLEFT", window, offsetX, offsetY)
	button:SetExtent(CHECKBOX_SIZE, CHECKBOX_SIZE)
	button:Show(true)
	button:Enable(true)
	if button.SetSounds ~= nil then
		button:SetSounds(CLICK_SOUND)
	end
	button:Raise()

	local label = api.Interface:CreateWidget("label", id .. "CheckBoxLabel", window)
	label:SetExtent(200, 30)
	label:AddAnchor("TOPLEFT", button, CHECKBOX_SIZE, 0)
	label:SetText(text)
	label.style:SetAlign(ALIGN.LEFT)
	label.style:SetFontSize(FONT_SIZE)
	label.style:SetColor(0, 0, 0, 1)
	local labelWidth = label.GetTextWidth and (label:GetTextWidth() + 4) or label:GetWidth()
	local labelHeight = label.GetTextHeight and (label:GetTextHeight() + 4) or label:GetHeight()
	if type(labelWidth) == "number" and type(labelHeight) == "number" then
		label:SetExtent(labelWidth, labelHeight)
	end
	label:Raise()
	label:Show(true)

	-- clicking the text toggles too, with the button sound
	local labelButton = window:CreateChildWidget("button", id .. "CheckBoxLabelButton", 0, true)
	labelButton:AddAnchor("TOPLEFT", button, CHECKBOX_SIZE, 0)
	if type(labelWidth) == "number" and type(labelHeight) == "number" then
		labelButton:SetExtent(labelWidth, labelHeight)
	else
		labelButton:SetExtent(200, 30)
	end
	labelButton:Show(true)
	labelButton:Enable(true)
	if labelButton.SetSounds ~= nil then
		labelButton:SetSounds(CLICK_SOUND)
	end
	labelButton:Raise()

	local isChecked = checked
	local function toggle()
		isChecked = not isChecked
		overlay:SetTexture(isChecked and CHECKED or UNCHECKED)
		onClick(isChecked)
	end
	button:SetHandler("OnClick", toggle)
	labelButton:SetHandler("OnClick", toggle)

	checkboxes[#checkboxes + 1] = {
		overlay = overlay,
		button = button,
		label = label,
		labelButton = labelButton,
	}
end

-- same steps as WorldSatNav's ToggleCheckboxVisable(id, false), plus releasing the click handlers
local function hideCheckbox(checkbox)
	checkbox.button:ReleaseHandler("OnClick")
	checkbox.button:Show(false)
	checkbox.button:Enable(false)
	checkbox.labelButton:ReleaseHandler("OnClick")
	checkbox.labelButton:Show(false)
	checkbox.labelButton:Enable(false)
	checkbox.label:Show(false)
	checkbox.overlay:Show(false)
end

-- Wipes all logged data, but only on a second click within RESET_CONFIRM_MS.
local function createResetButton(offsetY, resetData)
	resetButton = api.Interface:CreateWidget("button", "PlayerDBSettingsReset", window)
	resetButton:AddAnchor("TOPLEFT", window, PADDING, offsetY)
	-- the skin sets its own size, so size the button after applying it
	api.Interface:ApplyButtonSkin(resetButton, BUTTON_BASIC.DEFAULT)
	resetButton:SetExtent(RESET_WIDTH, RESET_HEIGHT)
	resetButton:SetText(RESET_TEXT)
	function resetButton:OnClick()
		resetClickId = resetClickId + 1
		if not resetArmed then
			resetArmed = true
			resetButton:SetText(RESET_CONFIRM_TEXT)
			local clickId = resetClickId
			api:DoIn(RESET_CONFIRM_MS, function()
				if clickId ~= resetClickId or resetButton == nil then
					return -- clicked again, or unloaded
				end
				resetArmed = false
				resetButton:SetText(RESET_TEXT)
			end)
			return
		end
		resetArmed = false
		resetButton:SetText(RESET_TEXT)
		resetData()
	end
	resetButton:SetHandler("OnClick", resetButton.OnClick)
	resetButton:Show(true)
end

-- features: list of { id, label }; isEnabled(id) -> bool; setEnabled(id, bool); resetData()
local function create(features, isEnabled, setEnabled, resetData)
	local resetY = TOP + #features * ROW_HEIGHT + RESET_GAP
	local height = resetY + RESET_HEIGHT + PADDING
	window = api.Interface:CreateEmptyWindow("PlayerDBSettings")
	window:AddAnchor("CENTER", "UIParent", 0, 0)
	window:SetExtent(WINDOW_WIDTH, height)
	window:SetCloseOnEscape(true)

	createTitle(height)
	for index, feature in ipairs(features) do
		createCheckbox("PlayerDBSettings" .. feature.id, feature.label,
			PADDING, TOP + (index - 1) * ROW_HEIGHT, isEnabled(feature.id),
			function(checked)
				setEnabled(feature.id, checked)
			end)
	end
	createResetButton(resetY, resetData)
	attachDrag(window)
end

function settingswindow.Open(features, isEnabled, setEnabled, resetData)
	if window == nil then
		create(features, isEnabled, setEnabled, resetData)
	end
	window:Show(true)
end

-- Called from OnUnload: hide and release every part, then hide and free the window
-- (WorldSatNav's maprendering.OnUnload does Show(false) then Free for each window).
function settingswindow.Free()
	if window == nil then
		return
	end
	for _, checkbox in ipairs(checkboxes) do
		pcall(hideCheckbox, checkbox)
	end
	checkboxes = {}
	if closeButton ~= nil then
		pcall(function()
			closeButton:ReleaseHandler("OnClick")
			closeButton:Show(false)
		end)
		closeButton = nil
	end
	if resetButton ~= nil then
		pcall(function()
			resetButton:ReleaseHandler("OnClick")
			resetButton:Show(false)
		end)
		resetButton = nil
	end
	resetArmed = false
	resetClickId = resetClickId + 1
	pcall(function()
		window:ReleaseHandler("OnDragStart")
		window:ReleaseHandler("OnDragStop")
	end)
	window:Show(false)
	api.Interface:Free(window)
	window = nil
end

return settingswindow
