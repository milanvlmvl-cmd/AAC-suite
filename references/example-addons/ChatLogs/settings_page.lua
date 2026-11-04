local api = require("api")
local CreateColorPickButtons = require('ChatLogs/util/color_picker')
local checkButton            = require('ChatLogs/util/check_button')
local F_ETC                  = require('ChatLogs/util/etc')

-- settings_page exposes Open(ctx); ctx provides live getters/setters from main.lua
-- so this module stays decoupled from main's internals.
local M = {}
local win
local palletWindow

local CHANNEL_ORDER = { "guild", "faction", "nation", "say", "zone", "trade", "party", "family" }
local CHANNEL_LABEL = {
    guild="Guild", faction="Faction", nation="Nation", say="Say", zone="Zone",
    trade="Trade", party="Party", family="Family",
}
local COLOR_ROWS = {
    { "whisperIn", "Whisper (in)" }, { "whisperOut", "Whisper (You:)" },
    { "guild", "Guild" }, { "faction", "Faction" }, { "nation", "Nation" },
    { "say", "Say" }, { "zone", "Zone" }, { "trade", "Trade" },
    { "party", "Party" }, { "family", "Family" },
}

function M.Open(ctx)
    if win then win:Show(not win:IsVisible()); return end

    win = api.Interface:CreateEmptyWindow("CLOptions", "UIParent")
    win:SetExtent(320, 560)
    win:AddAnchor("CENTER", "UIParent", 0, 0)
    local bg = win:CreateColorDrawable(0.08, 0.08, 0.12, 0.96, "background")
    bg:AddAnchor("TOPLEFT", win, 0, 0); bg:AddAnchor("BOTTOMRIGHT", win, 0, 0)

    -- Drag the top header bar to move the window (engine-native; no shift needed).
    local function makeDragHandle(widget)
        widget:EnableDrag(true)
        widget:SetHandler("OnDragStart", function() win:StartMoving() end)
        widget:SetHandler("OnDragStop", function() win:StopMovingOrSizing() end)
    end
    local dragBar = win:CreateChildWidget("emptywidget", "CLOptDrag", 0, true)
    dragBar:AddAnchor("TOPLEFT", win, 0, 0)
    dragBar:AddAnchor("TOPRIGHT", win, 0, 0)
    dragBar:SetHeight(30)
    makeDragHandle(dragBar)

    local title = win:CreateChildWidget("label", "CLOptTitle", 0, true)
    title:SetText("ChatLogs Options"); title:AddAnchor("TOP", win, 0, 8)
    if title.style then title.style:SetFontSize(15) end
    makeDragHandle(title)  -- title sits over dragBar; give it the handle too

    local close = win:CreateChildWidget("button", "CLOptClose", 0, true)
    close:SetExtent(28, 22); close:AddAnchor("TOPRIGHT", win, -6, 6); close:SetText("X")
    close:SetHandler("OnClick", function() F_ETC.HidePallet(); win:Show(false) end)

    local y = 40
    -- Column headers
    local hLog = win:CreateChildWidget("label", "CLhLog", 0, true)
    hLog:SetText("Log"); hLog:AddAnchor("TOPLEFT", win, 16, y - 16); hLog:SetExtent(120, 14)
    if hLog.style then hLog.style:SetAlign(ALIGN.LEFT); hLog.style:SetColor(0.6,0.6,0.6,1) end
    local hNotify = win:CreateChildWidget("label", "CLhNotify", 0, true)
    hNotify:SetText("Notify"); hNotify:AddAnchor("TOPLEFT", win, 190, y - 16); hNotify:SetExtent(90, 14)
    if hNotify.style then hNotify.style:SetAlign(ALIGN.LEFT); hNotify.style:SetColor(0.6,0.6,0.6,1) end

    -- Channel toggles: per channel, a "Log" checkbox and a "Notify" checkbox.
    for _, key in ipairs(CHANNEL_ORDER) do
        local cb = checkButton.CreateCheckButton("CLcb_" .. key, win, CHANNEL_LABEL[key])
        cb:AddAnchor("TOPLEFT", win, 16, y)
        cb:SetChecked(ctx.getEnabled(key) and true or false)
        cb.CheckBtnCheckChagnedProc = function(self, checked)
            ctx.setEnabled(key, checked)
        end

        local nb = checkButton.CreateCheckButton("CLnb_" .. key, win, "")
        nb:AddAnchor("TOPLEFT", win, 200, y)
        nb:SetChecked(ctx.getNotify(key) and true or false)
        nb.CheckBtnCheckChagnedProc = function(self, checked)
            ctx.setNotify(key, checked)
        end
        y = y + 26
    end

    y = y + 12
    -- Color pickers
    for _, row in ipairs(COLOR_ROWS) do
        local key, lbl = row[1], row[2]
        local l = win:CreateChildWidget("label", "CLcl_" .. key, 0, true)
        l:SetText(lbl); l:AddAnchor("TOPLEFT", win, 16, y); l:SetExtent(130, 18)
        if l.style then l.style:SetAlign(ALIGN.LEFT) end

        local picker = CreateColorPickButtons("CLpk_" .. key, win)
        picker:SetExtent(23, 15)
        picker:AddAnchor("LEFT", l, "RIGHT", 10, 0)
        local c = ctx.getColor(key)
        picker.colorBG:SetColor(c[1], c[2], c[3], 1)

        -- The palette calls this with the chosen color.
        function picker:SelectedProcedure(r, g, b, a)
            self.colorBG:SetColor(r, g, b, a)
            ctx.setColor(key, { r, g, b, 1 })
        end
        function picker:OnClick()
            F_ETC.HidePallet()
            palletWindow = F_ETC.ShowPallet(self)
            function palletWindow:OnHide() F_ETC.HidePallet() end
            palletWindow:SetHandler("OnHide", palletWindow.OnHide)
        end
        picker:SetHandler("OnClick", picker.OnClick)
        y = y + 22
    end

    y = y + 12
    -- Timezone
    local tzl = win:CreateChildWidget("label", "CLtz", 0, true)
    tzl:AddAnchor("TOPLEFT", win, 16, y); tzl:SetExtent(150, 20)
    if tzl.style then tzl.style:SetAlign(ALIGN.LEFT) end
    local function tztext()
        local v = ctx.getTz()
        return "Timezone: " .. (v >= 0 and "+" or "") .. v .. "h"
    end
    tzl:SetText(tztext())
    local minus = win:CreateChildWidget("button", "CLtzM", 0, true)
    minus:SetExtent(24, 20); minus:AddAnchor("LEFT", tzl, "RIGHT", 4, 0); minus:SetText("-")
    local plus = win:CreateChildWidget("button", "CLtzP", 0, true)
    plus:SetExtent(24, 20); plus:AddAnchor("LEFT", minus, "RIGHT", 2, 0); plus:SetText("+")
    minus:SetHandler("OnClick", function() ctx.setTz(ctx.getTz() - 1); tzl:SetText(tztext()) end)
    plus:SetHandler("OnClick", function() ctx.setTz(ctx.getTz() + 1); tzl:SetText(tztext()) end)

    win:Show(true)
end

return M
