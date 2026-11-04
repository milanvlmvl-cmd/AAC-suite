local F_ETC = {}
palletWindow = nil

function F_ETC.ShowPallet(target)
    if palletWindow == nil then
        palletWindow = W_ETC.CreatePopupPallet("defaultPallet[1]", "UIParent")
        palletWindow:SetUILayer("hud")
        palletWindow:SetCloseOnEscape(true)
    end
    palletWindow:RemoveAllAnchors()
    palletWindow:Show(true)
    palletWindow:AddAnchor("TOPLEFT", target, "TOPRIGHT", 2, 2)
    palletWindow.selectColor = nil
    palletWindow:SetSelectEventListenWidget(target)
    palletWindow:EnableHidingIsRemove(true)
    return palletWindow
end

function F_ETC.HidePallet()
    if palletWindow ~= nil then
        palletWindow:Show(false)
        palletWindow = nil
    end
end

return F_ETC
