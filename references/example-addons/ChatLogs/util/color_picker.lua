local function SetButtonFontColor(button, color)
    local n = color.normal
    local h = color.highlight
    local p = color.pushed
    local d = color.disabled
    button:SetTextColor(n[1], n[2], n[3], n[4])
    button:SetHighlightTextColor(h[1], h[2], h[3], h[4])
    button:SetPushedTextColor(p[1], p[2], p[3], p[4])
    button:SetDisabledTextColor(d[1], d[2], d[3], d[4])
end
local function GetButtonDefaultFontColor()
    local color = {}
    color.normal = {ConvertColor(104), ConvertColor(68), ConvertColor(18), 1}
    color.highlight = {ConvertColor(154), ConvertColor(96), ConvertColor(16), 1}
    color.pushed = {ConvertColor(104), ConvertColor(68), ConvertColor(18), 1}
    color.disabled = {ConvertColor(92), ConvertColor(92), ConvertColor(92), 1}
    return color
end
local function SetViewOfEmptyButton(id, parent)
    local button = api.Interface:CreateWidget("button", id, parent)
    button:RegisterForClicks("LeftButton")
    button:RegisterForClicks("RightButton", false)
    button.style:SetAlign(ALIGN_CENTER)
    button.style:SetSnap(true)
    SetButtonFontColor(button, GetButtonDefaultFontColor())
    return button
end
local function CreateEmptyButton(id, parent)
    local button = SetViewOfEmptyButton(id, parent)
    return button
end

local function SetViewOfColorPickButtons(id, parent)
    local button = CreateEmptyButton(id, parent)
    local colorBG = button:CreateColorDrawable(1, 1, 1, 1, "background")
    colorBG:AddAnchor("TOPLEFT", button, 1, 1)
    colorBG:AddAnchor("BOTTOMRIGHT", button, -1, -1)
    button.colorBG = colorBG
    local decoLine = button:CreateNinePartDrawable("ui/chat_option.dds",
                                                   "overlay")
    decoLine:SetCoords(0, 0, 27, 16)
    decoLine:SetInset(0, 8, 0, 7)
    decoLine:AddAnchor("TOPLEFT", button, -1, -1)
    decoLine:AddAnchor("BOTTOMRIGHT", button, 1, 1)
    return button
end
local function CreateColorPickButtons(id, parent)
    local button = SetViewOfColorPickButtons(id, parent)
    return button
end

return CreateColorPickButtons
