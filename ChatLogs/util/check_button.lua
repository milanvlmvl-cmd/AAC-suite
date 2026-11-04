local api = require("api")
-- DO NOT TRY TO READ IT
function ButtonInit(button)
    button:EnableDrawables("background")
    button.style:SetAlign(ALIGN.CENTER)
    button.style:SetSnap(true)
    button.style:SetColor(0.87, 0.69, 0, 1)
    SetButtonFontColor(button, GetButtonDefaultFontColor())
    button:RegisterForClicks("LeftButton")
end
function GetDefaultCheckButtonFontColor()
    local color = {}
    color.normal = FONT_COLOR.DEFAULT
    color.highlight = FONT_COLOR.DEFAULT
    color.pushed = FONT_COLOR.DEFAULT
    color.disabled = {0.42, 0.42, 0.42, 1}
    return color
end
function GetButtonDefaultFontColor()
    local color = {}
    color.normal = {ConvertColor(104), ConvertColor(68), ConvertColor(18), 1}
    color.highlight = {ConvertColor(154), ConvertColor(96), ConvertColor(16), 1}
    color.pushed = {ConvertColor(104), ConvertColor(68), ConvertColor(18), 1}
    color.disabled = {ConvertColor(92), ConvertColor(92), ConvertColor(92), 1}
    return color
end
function SetButtonFontColor(button, color)
    local n = color.normal
    local h = color.highlight
    local p = color.pushed
    local d = color.disabled
    button:SetTextColor(n[1], n[2], n[3], n[4])
    button:SetHighlightTextColor(h[1], h[2], h[3], h[4])
    button:SetPushedTextColor(p[1], p[2], p[3], p[4])
    button:SetDisabledTextColor(d[1], d[2], d[3], d[4])
end
function SetViewOfEmptyButton(id, parent)
    local button = api.Interface:CreateWidget("button", id, parent)
    button:RegisterForClicks("LeftButton")
    button:RegisterForClicks("RightButton", false)
    button.style:SetAlign(ALIGN.CENTER)
    button.style:SetSnap(true)
    SetButtonFontColor(button, GetButtonDefaultFontColor())
    return button
end
function CreateEmptyButton(id, parent)
    local button = SetViewOfEmptyButton(id, parent)
    return button
end

function SetButtonBackground(button)
    button:SetNormalBackground(button.bgs[1])
    button:SetHighlightBackground(button.bgs[2])
    button:SetPushedBackground(button.bgs[3])
    button:SetDisabledBackground(button.bgs[4])
    if button.bgs[5] ~= nil then button:SetCheckedBackground(button.bgs[5]) end
    if button.bgs[6] ~= nil then
        button:SetDisabledCheckedBackground(button.bgs[6])
    end
end
function SetButtonCoordsForBg(button, bg, coords)
    if coords ~= nil then
        bg:SetExtent(coords[3], coords[4])
        bg:SetCoords(coords[1], coords[2], coords[3], coords[4])
        return true
    end
    if default ~= nil then
        bg:SetCoords(default[1], default[2], default[3], default[4])
        button:SetNormalBackground(bg)
    end
    return false
end
local CreateDefaultDrawable = function(widget, type, path, layer)
    layer = layer or "background"
    local bg
    if type == "threePart" then
        bg = widget:CreateThreePartDrawable(path, layer)
    end
    if type == "drawable" then bg = widget:CreateImageDrawable(path, layer) end
    if type == "ninePart" then
        bg = widget:CreateNinePartDrawable(path, layer)
    end
    return bg
end
function CreateCheckButtonBackGround(button, path, drawableType, count)
    button.bgs = {}
    for i = 1, count or 4 do
        button.bgs[i] = CreateDefaultDrawable(button, drawableType, path)
        button.bgs[i]:SetExtent(16, 16)
        button.bgs[i]:AddAnchor("CENTER", button, 0, 0)
        if button.bgs[i].SetTexture ~= nil then
            button.bgs[i]:SetTexture(path)
        end
    end
end
function SetViewOfCheckButton(id, parent, text)
    local button = api.Interface:CreateWidget("checkbutton", id, parent)
    CreateCheckButtonBackGround(button, "ui/button/check_button.dds",
                                "drawable", 6)
    if text ~= nil then
        local textButton = CreateEmptyButton(id .. ".textButton", button)
        textButton:AddAnchor("LEFT", button, "RIGHT", 0, 0)
        ButtonInit(textButton)
        textButton:SetAutoResize(true)
        textButton:SetHeight(16)
        textButton:SetText(text)
        textButton.style:SetAlign(ALIGN.LEFT)
        button.textButton = textButton
    end
    function button:SetButtonStyle(style)
        local coords = {}
        if style == "eyeShape" then
            self:SetExtent(27, 18)
            if self.textButton ~= nil then
                self.textButton:RemoveAllAnchors()
                self.textButton:AddAnchor("RIGHT", button, "LEFT", -5, 0)
                SetButtonFontColor(self.textButton,
                                   GetDefaultCheckButtonFontColor())
            end
            coords[1] = {37, 0, 27, 18}
            coords[2] = {37, 0, 27, 18}
            coords[3] = {37, 0, 27, 18}
            coords[4] = {37, 36, 27, 18}
            coords[5] = {37, 18, 27, 18}
            coords[6] = {37, 36, 27, 18}
        elseif style == "soft_brown" then
            if self.textButton ~= nil then
                self.textButton:RemoveAllAnchors()
                self.textButton:AddAnchor("LEFT", button, "RIGHT", 0, 0)
                SetButtonFontColor(self.textButton,
                                   GetSoftCheckButtonFontColor())
            end
            self:SetExtent(18, 17)
            coords[1] = {0, 0, 18, 17}
            coords[2] = {0, 0, 18, 17}
            coords[3] = {0, 0, 18, 17}
            coords[4] = {0, 17, 18, 17}
            coords[5] = {18, 0, 18, 17}
            coords[6] = {18, 17, 18, 17}
        elseif style == "quest_notifier" then
            if self.textButton ~= nil then
                self.textButton:RemoveAllAnchors()
                self.textButton:AddAnchor("LEFT", button, "RIGHT", 0, 0)
                SetButtonFontColor(self.textButton,
                                   GetDefaultCheckButtonFontColor())
            end
            self:SetExtent(18, 17)
            coords[1] = {57, 54, 7, 10}
            coords[2] = {0, 0, 18, 17}
            coords[3] = {0, 0, 18, 17}
            coords[4] = {0, 17, 18, 17}
            coords[5] = {18, 0, 18, 17}
            coords[6] = {18, 17, 18, 17}
        elseif style == "tutorial" then
            if self.textButton ~= nil then
                self.textButton:RemoveAllAnchors()
                self.textButton:AddAnchor("LEFT", button, "RIGHT", 0, 0)
                SetButtonFontColor(self.textButton,
                                   GetBlackCheckButtonFontColor())
            end
            self:SetExtent(18, 18)
            coords[1] = {0, 0, 18, 17}
            coords[2] = {0, 0, 18, 17}
            coords[3] = {0, 0, 18, 17}
            coords[4] = {0, 17, 18, 17}
            coords[5] = {18, 0, 18, 17}
            coords[6] = {18, 17, 18, 17}
        else
            if self.textButton ~= nil then
                self.textButton:RemoveAllAnchors()
                self.textButton:AddAnchor("LEFT", button, "RIGHT", 0, 0)
                SetButtonFontColor(self.textButton,
                                   GetDefaultCheckButtonFontColor())
            end
            self:SetExtent(18, 17)
            coords[1] = {0, 0, 18, 17}
            coords[2] = {0, 0, 18, 17}
            coords[3] = {0, 0, 18, 17}
            coords[4] = {0, 17, 18, 17}
            coords[5] = {18, 0, 18, 17}
            coords[6] = {18, 17, 18, 17}
        end
        for i = 1, #coords do
            SetButtonBackground(button)
            SetButtonCoordsForBg(button, button.bgs[i], coords[i])
        end
    end
    button:SetButtonStyle(nil)
    SetButtonBackground(button)
    return button
end
function CreateCheckButton(id, parent, text)
    local button = SetViewOfCheckButton(id, parent, text)
    function button:SetEnableCheckButton(enable)
        self:Enable(enable, true)
        if self.textButton ~= nil then self.textButton:Enable(enable) end
    end
    function button:OnCheckChanged()
        if self.CheckBtnCheckChagnedProc ~= nil then
            self:CheckBtnCheckChagnedProc(self:GetChecked())
        end
    end
    button:SetHandler("OnCheckChanged", button.OnCheckChanged)
    if button.textButton ~= nil then
        function button.textButton:OnClick()
            if button:IsEnabled() then
                button:SetChecked(not button:GetChecked())
            end
        end
        button.textButton:SetHandler("OnClick", button.textButton.OnClick)
    end
    return button
end

return {CreateCheckButton = CreateCheckButton}
