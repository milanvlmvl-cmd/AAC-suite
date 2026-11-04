# X2UI Lua API Documentation

This document describes the API methods and functions used throughout the X2UI Lua codebase.

## Table of Contents

1. [Widget/UI Methods](#widgetui-methods)
2. [Widget Creation Methods](#widget-creation-methods)
3. [X2 Game API](#x2-game-api)
4. [Helper Functions](#helper-functions)
5. [Event System](#event-system)
6. [ADDON/UI System](#addonui-system)
7. [Localization](#localization)
8. [Drawing/Graphics](#drawinggraphics)

---

## Widget/UI Methods

These methods are called on widget objects to control their behavior and appearance.

### Basic State Control

#### `:Enable(boolean)`
Enables or disables a widget.
```lua
changeButton:Enable(false)
changeButton:Enable(true)
```

#### `:Show(boolean)`
Shows or hides a widget.
```lua
window:Show(false)
window:Show(true)
```

#### `:SetVisible(boolean)`
Sets the visibility of a widget.
```lua
selectedIcon:SetVisible(true)
selectedIcon:SetVisible(false)
```

#### `:IsVisible()`
Returns whether the widget is currently visible.
```lua
if window:IsVisible() then
  -- do something
end
```

#### `:IsEnabled()`
Returns whether the widget is currently enabled.
```lua
local isEnabled = button:IsEnabled()
```

### Text and Content

#### `:SetText(string)`
Sets the text content of a widget.
```lua
button:SetText("Click Me")
label:SetText(someTextVariable)
```

#### `:GetText()`
Gets the current text of a widget.
```lua
local text = button:GetText()
```

#### `:GetTextHeight()`
Gets the height of the text within a widget (useful for auto-sizing).
```lua
local height = textbox:GetTextHeight()
label:SetHeight(label:GetTextHeight())
```

#### `:GetTextWidth(text)`
Gets the width of the given text using the widget's current style.
```lua
local width = label.style:GetTextWidth(label:GetText())
```

#### `:GetLongestLineWidth()`
Gets the width of the longest line in a multi-line text widget.
```lua
local width = textbox:GetLongestLineWidth()
textbox:SetExtent(textbox:GetLongestLineWidth() + 5, textbox:GetTextHeight())
```

#### `:SetTitle(string)`
Sets the title of a window.
```lua
wnd:SetTitle("Window Title")
```

#### `:SetContentEx(content, value)`
Sets dialog content with additional value parameter.
```lua
wnd:SetContentEx(content, valueText)
```

### Sizing and Layout

#### `:SetExtent(width, height)`
Sets the width and height of a widget.
```lua
window:SetExtent(300, 400)
```

#### `:GetWidth()`
Gets the width of a widget.
```lua
local width = window:GetWidth()
```

#### `:GetHeight()`
Gets the height of a widget.
```lua
local height = window:GetHeight()
```

#### `:SetHeight(height)`
Sets the height of a widget.
```lua
titleBar:SetHeight(50)
```

#### `:SetWidth(width)`
Sets the width of a widget.
```lua
icon:SetWidth(32)
```

#### `:SetAutoResize(boolean)`
Enables automatic resizing of the widget.
```lua
button:SetAutoResize(true)
```

### Anchoring

#### `:AddAnchor(point, relativeTo, relativePoint, offsetX, offsetY)`
Adds an anchor point to position the widget relative to another widget or absolute position.
```lua
-- Anchor to another widget
button:AddAnchor("TOPLEFT", parentWindow, "TOPLEFT", 10, 10)

-- Anchor to "UIParent" (screen)
window:AddAnchor("CENTER", "UIParent", 0, 0)

-- Simple anchor
label:AddAnchor("BOTTOM", window, 0, -10)
```

**Common anchor points:**
- `TOPLEFT`, `TOP`, `TOPRIGHT`
- `LEFT`, `CENTER`, `RIGHT`
- `BOTTOMLEFT`, `BOTTOM`, `BOTTOMRIGHT`

#### `:RemoveAllAnchors()`
Removes all anchor points from the widget.
```lua
selectedIcon:RemoveAllAnchors()
```

### Event Handlers

#### `:SetHandler(eventName, function)`
Sets an event handler for the widget.
```lua
button:SetHandler("OnClick", button.OnClick)
button:SetHandler("OnEnter", OnEnter)
button:SetHandler("OnLeave", OnLeave)
button:SetHandler("OnEvent", function(this, event, ...)
  -- handle event
end)
```

**Common event names:**
- `"OnClick"` - Mouse click
- `"OnEnter"` - Mouse enters widget
- `"OnLeave"` - Mouse leaves widget
- `"OnShow"` - Widget is shown
- `"OnHide"` - Widget is hidden
- `"OnEvent"` - Custom events

### Focus and Input

#### `:SetFocus()`
Sets the input focus to this widget.
```lua
webBrowser:SetFocus()
editBox:SetFocus()
```

#### `:ClearFocus()`
Removes input focus from this widget.
```lua
webBrowser:ClearFocus()
editBox:ClearFocus()
```

#### `:SetMaxTextLength(length)`
Sets the maximum number of characters allowed in an edit box.
```lua
editBox:SetMaxTextLength(50)
editBox:SetMaxTextLength(namePolicyInfo.local_max)
```

#### `:SetCursorColor(r, g, b, a)`
Sets the cursor color for edit boxes (0.0 to 1.0 for each component).
```lua
editBox:SetCursorColor(0, 0, 0, 1)
editBox:SetCursorColor(0.3, 0.3, 0.3, 1)
```

#### `:UseSelectAllWhenFocused(boolean)`
Enables/disables selecting all text when the edit box receives focus.
```lua
editBox:UseSelectAllWhenFocused(true)
```

### Special Widget Properties

#### `:SetChecked(boolean)`
Sets the checked state of a checkbox.
```lua
checkButton:SetChecked(true)
```

#### `:GetChecked()`
Gets the checked state of a checkbox.
```lua
local checked = checkButton:GetChecked()
```

#### `:SetURL(url)`
Sets the URL for a web browser widget.
```lua
webBrowser:SetURL("https://example.com")
```

#### `:SetEscEvent(boolean)`
Enables escape key event for the widget.
```lua
webBrowser:SetEscEvent(true)
```

#### `:SetCloseOnEscape(boolean)`
Sets whether the window closes when Escape is pressed.
```lua
window:SetCloseOnEscape(true)
```

#### `:SetSounds(soundKey)`
Sets the sound theme for the widget. Pass an empty string `""` to disable sounds.

```lua
-- Window/dialog sounds
window:SetSounds("dialog_common")
window:SetSounds("ability_change")
window:SetSounds("character_info")
window:SetSounds("achievement")
window:SetSounds("battlefield_entrance")
window:SetSounds("option")
window:SetSounds("config")
window:SetSounds("tutorial")

-- Web browser sounds
window:SetSounds("web_wiki")
window:SetSounds("web_play_diary")
window:SetSounds("web_messenger")
window:SetSounds("web_note")
window:SetSounds("web_market")

-- Trade/commerce sounds
window:SetSounds("trade")
window:SetSounds("auction")
button:SetSounds("auction_put_up") -- gives a DING sound in AAC
window:SetSounds("store") -- gives a DING sound in AAC
button:SetSounds("store_drain")  -- gives the remove item in AAC
window:SetSounds("loot") 

-- Mail sounds
window:SetSounds("mail")
readWindow:SetSounds("mail_read")
writeWindow:SetSounds("mail_write")

-- Inventory sounds
bagWindow:SetSounds("bag")
bankWindow:SetSounds("bank")
cofferWindow:SetSounds("coffer")

-- Customization sounds
window:SetSounds("cosmetic_details")
window:SetSounds("dialog_enter_beautyshop")
window:SetSounds("dyeing")
window:SetSounds("wash")
window:SetSounds("dialog_gender_transfer")

-- Crafting/skills sounds
window:SetSounds("craft")
window:SetSounds("skill_book")
window:SetSounds("item_enchant")
window:SetSounds("composition_score")

-- Team/social sounds
window:SetSounds("raid_team")
window:SetSounds("ranking")
window:SetSounds("ranking_reward")
window:SetSounds("community")

-- Map/portal sounds
mapFrame:SetSounds("world_map")
window:SetSounds("portal")

-- Quest/trial sounds
window:SetSounds("quest_context_list")
button:SetSounds("quest_directing_mode") -- gives the default sound
window:SetSounds("crime_records")
window:SetSounds("ruling_status")

-- Pet/farm sounds
window:SetSounds("pet_info")
window:SetSounds("my_farm_info")
window:SetSounds("common_farm_info")

-- UI component sounds
editBox:SetSounds("edit_box")
button:SetSounds("default")
item:SetSounds("default_r")
button:SetSounds("submenu")
window:SetSounds("ucc")

-- Disable sounds
button:SetSounds("")
```

### Graphics Properties

#### `:SetCoords(x, y, width, height)`
Sets the texture coordinates for image drawables.
```lua
texture:SetCoords(0, 0, 147, 28)
```

#### `:SetColor(r, g, b, a)`
Sets the color of the widget (0.0 to 1.0 for each component).
```lua
texture:SetColor(1, 1, 1, 0.8)
```

#### `:SetInset(left, top, right, bottom)`
Sets inset values for textures.
```lua
texture:SetInset(3, 1, 3, 1)
editBox:SetInset(8, 8, 8, 8)
```

### Z-Order Management

#### `:Raise()`
Brings the widget to the front (on top of other widgets).
```lua
window:Raise()
tooltip:Raise()
```

#### `:Lower()`
Sends the widget to the back (behind other widgets).
```lua
background:Lower()
roadmapWindow:Lower()
```

### Animation

#### `:StartAnimation()`
Starts an animation sequence on the widget.
```lua
button:StartAnimation()
modelView:StartAnimation()
```

#### `:StopAnimation()`
Stops the current animation sequence.
```lua
modelView:StopAnimation()
effect:StopAnimation()
```

### Identification

#### `:GetId()`
Gets the ID string of the widget.
```lua
local id = window:GetId()
```

---

## Widget Creation Methods

These methods create new widgets and visual elements.

### Child Widgets

#### `:CreateChildWidget(widgetType, id, index, inherits)`
Creates a child widget of the specified type.
```lua
local button = wnd:CreateChildWidget("button", "okButton", 0, true)
local label = frame:CreateChildWidget("label", "nameLabel", 0, true)
local textbox = window:CreateChildWidget("textbox", "desc", 0, true)
local emptywidget = parent:CreateChildWidget("emptywidget", "frame", 0, false)
local window = parent:CreateChildWidget("window", "subWindow", 0, true)
```

**Common widget types:**
- `"button"` - Button widget
- `"label"` - Text label
- `"textbox"` - Multi-line text
- `"emptywidget"` - Container widget
- `"window"` - Window container
- `"webview"` - Web browser widget

### Drawables

#### `:CreateImageDrawable(path, layer)`
Creates an image drawable.
```lua
local bg = window:CreateImageDrawable(TEXTURE_PATH.HUD, "background")
local icon = widget:CreateImageDrawable("ui/icon/path.dds", "artwork")
```

**Layer values:**
- `"background"`
- `"border"`
- `"artwork"`
- `"overlay"`

#### `:CreateNinePartDrawable(path, layer)`
Creates a nine-part drawable (stretchable corners).
```lua
local bg = widget:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
```

#### `:CreateThreePartDrawable(path, layer)`
Creates a three-part drawable (stretchable middle).
```lua
local line = window:CreateThreePartDrawable(TEXTURE_PATH.UCC, "background")
```

#### `:CreateColorDrawable(r, g, b, a, layer)`
Creates a solid color drawable.
```lua
local bg = widget:CreateColorDrawable(ConvertColor(241), ConvertColor(236), ConvertColor(225), 1, "background")
```

#### `:CreateThreeColorDrawable(texture, textureSize, layer)`
Creates a three-color drawable.
```lua
local bg = widget:CreateThreeColorDrawable(1024, 1024, "background")
```

#### `:CreateEffectDrawable(path, layer)`
Creates an effect drawable.
```lua
local effect = widget:CreateEffectDrawable(TEXTURE_PATH.HUD, "artwork")
```

#### `:CreateIconImageDrawable(path, layer)`
Creates an icon image drawable.
```lua
local icon = widget:CreateIconImageDrawable("ui/icon/item.dds", "overlay")
```

### Special Drawables

#### `:CreateOpenedImageDrawable(path)`
Creates an image for opened state (tree controls).
```lua
local opened = treeCtrl:CreateOpenedImageDrawable("ui/button/grid.dds")
```

#### `:CreateClosedImageDrawable(path)`
Creates an image for closed state (tree controls).
```lua
local closed = treeCtrl:CreateClosedImageDrawable("ui/button/grid.dds")
```

#### `:CreateSeparatorImageDrawable(path, layer)`
Creates a separator line drawable.
```lua
local line = treeCtrl:CreateSeparatorImageDrawable(TEXTURE_PATH.DEFAULT, "background")
```

### Other Creation Methods

#### `:SetDefaultDrawable(drawable)`
Sets the default drawable for a browser widget.
```lua
webBrowser:SetDefaultDrawable(defaultDrawable)
```

#### `:CreateGuideText(text, align)`
Creates guide/placeholder text for edit controls.
```lua
editBox:CreateGuideText("Enter text here...", ALIGN_TOP_LEFT)
```

---

## X2 Game API

These are game-specific APIs provided by the X2 engine.

### X2Ability

Handles character abilities and skills.

```lua
X2Ability:GetActiveAbility()                    -- Get active abilities
X2Ability:GetAllCombatAbility()                 -- Get all combat abilities
X2Ability:SelectHighAbility(index, boolean)     -- Select high ability
X2Ability:IsActiveHighAbility(index)            -- Check if high ability is active
X2Ability:GetHighAbilityFromView(index)         -- Get high ability info
X2Ability:SwapAbility(index1, index2)           -- Swap two abilities
X2Ability:CanBuyAbilityChange()                 -- Check if ability change can be bought
X2Ability:GetAbilityChangeCost()                -- Get cost to change abilities
X2Ability:CancelPlayerBuff(index)              -- Cancel a buff
```

### X2Unit

Handles unit (player, NPC, monster) information.

```lua
-- Name and identity
X2Unit:UnitName(unit)                           -- Get unit name
X2Unit:GetUnitId(unit)                          -- Get unit ID
X2Unit:GetTargetUnitId()                        -- Get target's unit ID
X2Unit:GetUnitInfoById(unitId)                  -- Get unit info by ID
X2Unit:GetUnitMateType(unit)                    -- Get mate type
X2Unit:GetUnitMateTypeById(unitId)              -- Get mate type by ID

-- Stats and state
X2Unit:UnitLevel(unit)                          -- Get unit level
X2Unit:UnitHealth(unit)                         -- Get current health
X2Unit:UnitMaxHealth(unit)                      -- Get max health
X2Unit:UnitMana(unit)                           -- Get current mana
X2Unit:UnitMaxMana(unit)                        -- Get max mana
X2Unit:UnitDistance(unit)                       -- Get distance to unit
X2Unit:UnitCombatState(unit)                    -- Get combat state
X2Unit:UnitIsOffline(unit)                      -- Check if unit is offline

-- Type and classification
X2Unit:GetUnitType(unit)                        -- Get unit type
X2Unit:GetUnitTypeString(unit)                  -- Get unit type as string
X2Unit:GetTargetTypeString()                    -- Get target type string
X2Unit:GetTargetKindType(unit)                  -- Get target kind type
X2Unit:GetUnitGradeById(unitId)                 -- Get unit grade by ID
X2Unit:GetNpcInfo(unit)                         -- Get NPC information

-- Combat and relationships
X2Unit:GetCombatRelationshipStr(unit)           -- Get combat relationship
X2Unit:UnitTeamAuthority(unit)                  -- Get team authority
X2Unit:IsReporter(unit)                         -- Check if unit is a reporter
X2Unit:IsFirstHitByMeOrMyTeam(unit)            -- Check first hit status
X2Unit:UnitIsForceAttack(unit)                  -- Check force attack status

-- Abilities and targeting
X2Unit:GetTargetAbilityTemplates(unit)          -- Get ability templates
X2Unit:TargetUnit(unit)                         -- Target a unit
X2Unit:TargetFrameOpened()                      -- Notify target frame opened
X2Unit:ReleaseWatchTarget()                     -- Release watch target
X2Unit:GetOverHeadMarkerUnitId(index)           -- Get overhead marker unit
```

**Common unit strings:**
- `"player"` - The player character
- `"target"` - Current target
- `"targettarget"` - Target's target
- `"watchtarget"` - Watch target
- `"pet"` - Player's pet

### X2Player

Player-specific information.

```lua
X2Player:GetFeatureSet()                        -- Get enabled features
X2Player:GetBreathTime()                        -- Get breathing time (underwater)
X2Player:GetGamePoints()                        -- Get player's game points (honor, living, contribution)
X2Player:RequestRefreshCash()                   -- Request cash info refresh
X2Player:SetSensitiveOperationTime(time)        -- Set sensitive operation time
```

### X2Time

Time and date functions.

```lua
X2Time:GetLocalTime()                           -- Get local time
X2Time:GetLocalDate()                           -- Get local date
X2Time:TimeToDate(time)                         -- Convert time to date
```

### X2Locale

Localization functions.

```lua
X2Locale:LocalizeUiText(category, key, ...)     -- Localize UI text with parameters
X2Locale:GetLocale()                            -- Get current locale string (e.g., "en_us")
```

### X2Util

Utility functions.

```lua
X2Util:GetGameProvider()                        -- Get game provider (TENCENT, TRION, GAMEON, etc.)
X2Util:GetMyMoneyString()                       -- Get player's money as string
X2Util:GetMyAAPointString()                     -- Get player's AA points as string
X2Util:GetAAPointExchangeFee()                  -- Get AA point exchange fee
X2Util:RaiseLuaCallStack(message)               -- Raise Lua error with stack trace
X2Util:GetNamePolicyInfo(type)                  -- Get name policy info (character limits, etc.)
```

### X2Team

Team/party functions.

```lua
X2Team:GetTeamPlayerIndex()                     -- Get team player index
X2Team:GetTeamDistributorName()                 -- Get team distributor name
X2Team:GetMaxPartyMembers()                     -- Get maximum party member count
X2Team:IsPartyTeam()                            -- Check if in party team
X2Team:IsRaidTeam()                             -- Check if in raid team
X2Team:GetPartyFrameVisible()                   -- Check if party frame visible
X2Team:SetPartyFrameVisible(visible)            -- Set party frame visibility
X2Team:SetRaidFrameVisible(visible)             -- Set raid frame visibility
X2Team:SetPartyVisible(party, visible)          -- Set specific party visibility
X2Team:SetSimpleView(simple)                    -- Set simple view mode
X2Team:SetRefuseAreaInvitation(refuse)          -- Set refuse area invitation
X2Team:GetTeamPlayerPartyHeadIndex()            -- Get party head index
X2Team:SetRole(role)                            -- Set player role
```

### X2Ability

Handles character abilities and skills.

```lua
X2Ability:GetActiveAbility()                    -- Get active abilities
X2Ability:GetAllCombatAbility()                 -- Get all combat abilities
X2Ability:SelectHighAbility(index, boolean)     -- Select high ability
X2Ability:IsActiveHighAbility(index)            -- Check if high ability is active
X2Ability:GetHighAbilityFromView(index)         -- Get high ability info
X2Ability:SwapAbility(index1, index2)           -- Swap two abilities
X2Ability:CanBuyAbilityChange()                 -- Check if ability change can be bought
X2Ability:GetAbilityChangeCost()                -- Get cost to change abilities
X2Ability:CancelPlayerBuff(index)              -- Cancel a buff
X2Ability:SetAbilityToView(index, ability, enhancedAbility) -- Set ability to view slot
X2Ability:SetHighAbilityLevelUp(index)          -- Level up high ability
X2Ability:SetSelectSpecialAbility(ability)      -- Select special ability
X2Ability:SaveAbilitySet(index)                 -- Save ability set
X2Ability:RequestExpandAbilitySetSlot()         -- Request to expand ability set slots
```

### X2Hero

Hero/reputation system.

```lua
X2Hero:CanAddReputation()                       -- Check if can add reputation
X2Hero:GetAbleReputationLevel()                 -- Get able reputation level
X2Hero:VoteReputation(value)                    -- Vote reputation (1 or -1)
```

### X2Team

Team/party functions.

```lua
X2Team:GetTeamPlayerIndex()                     -- Get team player index
X2Team:GetTeamDistributorName()                 -- Get team distributor name
```

### X2DialogManager

Dialog management.

```lua
X2DialogManager:RequestDefaultDialog(handler, id)   -- Request default dialog
X2DialogManager:RequestNoticeDialog(handler, id)    -- Request notice dialog
X2DialogManager:SetHandler(dialogType, handler)     -- Set dialog handler
```

### X2Decal

Ground decal management (target circles, quest markers).

```lua
X2Decal:SetTargetDecalMaterial(layer, type, materialPath)
  -- Set material for target decal
X2Decal:SetTargetDecalStartAnimation(layer, type, duration, alpha, params)
  -- Set start animation for target decal
X2Decal:SetTargetDecalLoopAnimation(layer, type, duration, count, delay, params)
  -- Set loop animation for target decal
X2Decal:SetQuestGuidDecalByIndex(decalIndex, questType, visible)
  -- Set quest guide decal visibility
```

### X2Map

Map and world map functions.

```lua
X2Map:SetMapFilter(filterType, show)            -- Set map filter visibility
X2Map:SetNpcShowFilter(show)                    -- Filter NPC markers
X2Map:SetDoodadShowFilter(show)                 -- Filter doodad markers
X2Map:SetHouseShowFilter(show)                  -- Filter house markers
X2Map:SetMapIconCoords(count, coordList)        -- Set map icon coordinates
X2Map:SetShipCoords(count, coordList)           -- Set ship coordinates
X2Map:SetNotifyCoords(count, coordList)         -- Set notify coordinates
X2Map:SetNotifyAreaCoords(count, coordList)     -- Set notify area coordinates
X2Map:SetNotifyAreaColors(count, colorList)     -- Set notify area colors
X2Map:UpdateNotifyQuestInfo(index, questType, visible)
  -- Update notify quest information
```

### X2Cursor

Cursor management.

```lua
X2Cursor:SetCursorImage(path, x, y)             -- Set cursor image
X2Cursor:ClearCursor()                          -- Clear custom cursor
```

### X2Input

Input state checking.

```lua
X2Input:IsShiftKeyDown()                        -- Check if Shift is pressed
X2Input:SetInputLanguage(language)              -- Set input language ("Native", etc.)
```

### X2Option

Game option management.

```lua
X2Option:SetItemFloatValue(optionItem, value)   -- Set option float value
X2Option:Save()                                 -- Save options
```

### X2Hotkey

Hotkey binding management.

```lua
X2Hotkey:SetOptionBindingWithIndex(action, keyName, keyType, arg)
  -- Set keybinding with index
X2Hotkey:SetOptionBindingButtonWithIndex(action, keyName, keyType)
  -- Set button binding with index
X2Hotkey:SaveHotKey()                           -- Save hotkey bindings
```

### X2NameTag

Name tag display management.

```lua
X2NameTag:SetNameTag()                          -- Apply name tag settings
```

### X2Rank

Ranking system.

```lua
X2Rank:RequestRankSnapshots()                   -- Request rank snapshot data
```

### X2Warp

Portal/warp system.

```lua
X2Warp:SetFavoritePortal(portalType, portalId, favorite)
  -- Set portal as favorite
```

### X2Store

Store and specialty system.

```lua
X2Store:GetStoreCurrency()                      -- Get store currency type
X2Store:SetStoreOpenType(openType)              -- Set store open type
X2Store:GetSellableZoneGroups(zoneGroup)        -- Get sellable zone groups
X2Store:GetProductionZoneGroups()               -- Get production zone groups
X2Store:GetSpecialtyRatioBetween(src, dest)     -- Get specialty ratio
```

### X2Bag

Inventory/bag management.

```lua
X2Bag:GetBagItemInfo(bagIndex, slotIndex, flags)
  -- Get bag item information
  -- flags: IIK_SELL, IIK_STACK, etc.
```

### X2Item

Item information.

```lua
X2Item:GetItemInfoByType(itemType)              -- Get item info by type
```

### X2Equipment

Equipment management.

```lua
X2Equipment:GetBackPackGoodsInfo(unit)          -- Get backpack goods info
X2Equipment:GetEquippedItemTooltipText(unit, slotIdx)
  -- Get equipped item tooltip
```

### X2House

Housing and territory system.

```lua
X2House:IsConvertTaxItemToAAPoint()             -- Check tax item conversion
X2House:GetTaxations(taxRate)                   -- Get tax information
X2House:GetTaxItem()                            -- Get tax item info
X2House:GetGuardTowerStepInfo()                 -- Get guard tower step info
```

### X2Dominion

Territory dominion system.

```lua
X2Dominion:GetOwnerExpeditionName(zoneGroup)    -- Get owner expedition name
X2Dominion:GetOwnerPlayerName(zoneGroup)        -- Get owner player name
X2Dominion:GetReignStartDate(zoneGroup)         -- Get reign start date
X2Dominion:GetPeaceTaxMoney(zoneGroup)          -- Get peace tax money
X2Dominion:GetPeaceTaxAAPoint(zoneGroup)        -- Get peace tax AA points
X2Dominion:IsTaxationWithoutMyExpedition(zoneGroup)
  -- Check taxation status
X2Dominion:GetTaxRate(zoneGroup)                -- Get tax rate
X2Dominion:IsDominionOwner(zoneGroup)           -- Check if dominion owner
```

### X2Trial

Trial/jury system.

```lua
X2Trial:GetCrimeData()                          -- Get crime data
X2Trial:ChooseVerdict(index)                    -- Choose verdict
X2Trial:ReportCrime(message)                    -- Report a crime
X2Trial:ReportBotSuspect(message)               -- Report bot suspect
X2Trial:ReportBadUser(name, msg, type)          -- Report bad user
X2Trial:GetDailyReportBadUser()                 -- Get daily report count
X2Trial:GetDailyReportBadUserMaxCount()         -- Get max daily reports
X2Trial:SendBountyUpdate(id, name, price)       -- Send bounty update
X2Trial:GetCrimeRecordsByPage(pageIndex)        -- Get crime records by page
X2Trial:GetTrialType()                          -- Get trial type
X2Trial:GetBountyData()                         -- Get bounty data
X2Trial:GetBadUserRecordsByPage(pageIndex)      -- Get bad user records
X2Trial:GetReciveBadUserListCount()             -- Get receive bad user list count
X2Trial:GetClientBadUserList(index)             -- Get client bad user list
X2Trial:RequestBadUserList(index, lastIndex)    -- Request bad user list
X2Trial:CancelTrial()                           -- Cancel trial
X2Trial:RequestSetBountyMoney(name)             -- Request set bounty money
```

### X2LoginCharacter

Login stage character management.

```lua
X2LoginCharacter:RequestLpManageCharacter(charIndex)
  -- Request LP manage character
X2LoginCharacter:RequestCharacterListRefresh(full)
  -- Request character list refresh
X2LoginCharacter:SetEquipedItem(slot, itemType) -- Set equipped item (character creator)
X2LoginCharacter:SetClothPack(clothType)        -- Set cloth pack
X2LoginCharacter:SetLoginStageTOD(hour, minute) -- Set time of day
X2LoginCharacter:SetFreeze(frozen)              -- Freeze character
X2LoginCharacter:SetCustomizingLight(morning)   -- Set customizing light
X2LoginCharacter:GetCurrentStage()              -- Get current stage
```

### X2World

World/server selection.

```lua
X2World:RequestWorldListRefresh()               -- Request world list refresh
```

### X2Ucc

UCC (User Created Content) system.

```lua
X2Ucc:GetUccCategoryInfo()                      -- Get UCC category info
X2Ucc:GetPatternPath(typeNumber)                -- Get pattern path
X2Ucc:GetFgUserPath(index)                      -- Get foreground user path
X2Ucc:GetPatternIconPath(typeNumber)            -- Get pattern icon path
X2Ucc:GetUccUserDirectoryPath()                 -- Get UCC user directory
X2Ucc:GetMakeUccConsumeInfo(doodad, useUserImage)
  -- Get make UCC consume info
X2Ucc:GetPatternTypeNumbers()                   -- Get pattern type numbers
X2Ucc:GetPatternKind(typeNumber)                -- Get pattern kind
X2Ucc:GetFgUserCount()                          -- Get foreground user count
```

### X2Trade

Trading system.

```lua
X2Trade:GetCurrencyForUserTrade()               -- Get currency for user trade
```

### X2Tutorial

Tutorial system.

```lua
X2Tutorial:GetUiAviTable()                      -- Get UI AVI table
```

### X2Loot

Loot system.

```lua
X2Loot:SetDiceBidRule(rule)                     -- Set dice bid rule
X2Loot:RequestNextDiceItem()                    -- Request next dice item
```

### X2PremiumService

Premium service management.

```lua
X2PremiumService:SetVisiblePremiumService(visible)
  -- Set premium service visibility
X2PremiumService:RequestPremiumServiceList()    -- Request premium service list
```

### X2Faction

Faction system.

```lua
X2Faction:RequestMobilizationOrder(result, heroId, zoneGroupType)
  -- Request mobilization order
X2Faction:RequestMobilizationOrderNotRecv(notRecv)
  -- Request mobilization order not received
X2Faction:RequestIssuanceOfMobilizationOrder(doodadId)
  -- Request issuance of mobilization order
```

### X2

Core game functions.

```lua
X2:IsWebEnable()                                -- Check if web is enabled
```

### X2Debug

Debug functions.

```lua
X2Debug:GetDevMode()                            -- Check if in dev mode
```

### X2BattleField

Battlefield system.

```lua
X2BattleField:HasBindShip()                     -- Check if has bind ship
```

---

## Helper Functions

Global helper functions used throughout the codebase.

### UI Creation Helpers

#### `CreateCheckButton(id, parent, text)`
Creates a checkbox button.
```lua
local checkButton = CreateCheckButton("myCheck", window, "Enable Feature")
```

#### `CreateTitleBar(id, parent)`
Creates a title bar for a window.
```lua
local titleBar = CreateTitleBar(window:GetId() .. ".titleBar", window)
```

#### `W_CTRL.CreatePageControl(id, parent, style)`
Creates page navigation controls.
```lua
local pageControl = W_CTRL.CreatePageControl(window:GetId() .. ".pageControl", window, "note")
```

#### `W_CTRL.CreateMultiLineEdit(id, parent)`
Creates a multi-line edit control.
```lua
local editBox = W_CTRL.CreateMultiLineEdit("report_edit", frame)
```

#### `W_CTRL.CreateEdit(id, parent)`
Creates a single-line edit control.
```lua
local editBox = W_CTRL.CreateEdit("name_edit", frame)
```

#### `W_CTRL.CreatePageScrollListCtrl(id, parent)`
Creates a scrollable list with pagination.
```lua
local listCtrl = W_CTRL.CreatePageScrollListCtrl("pageListCtrl", window)
```

### UI Interaction Helpers

#### `SetTooltip(text, widget, ...)`
Shows a tooltip on a widget.
```lua
SetTooltip("This is a tooltip", self)
SetTooltip(GetCommonText("some_key"), self)
```

#### `HideTooltip()`
Hides the current tooltip.
```lua
HideTooltip()
```

#### `ApplyDialogStyle(dialog, style)`
Applies a style to a dialog window.
```lua
ApplyDialogStyle(wnd, "TYPE2")
ApplyDialogStyle(wnd, "TYPE1")
ApplyDialogStyle(wnd, DIALOG_STYLE.INCLUDE_ITEM_AND_DESCRIPTION)
```

#### `ButtonOnClickHandler(button, function, ...)`
Sets up a click handler for a button.
```lua
ButtonOnClickHandler(okButton, OkButtonLeftClickFunc)
ButtonOnClickHandler(window.leftButton, function()
  -- handle click
end)
```

### Messaging

#### `AddMessageToSysMsgWindow(message)`
Adds a message to the system message window.
```lua
AddMessageToSysMsgWindow("|cFFFF6600" .. locale.abilityChanger.reqActivationAbility)
```

### Text Helpers

#### `GetCommonText(key, ...)`
Gets common localized text.
```lua
local text = GetCommonText("some_text_key")
local text = GetCommonText("formatted_text", param1, param2)
```

#### `GetUIText(category, key, ...)`
Gets UI text from a specific category.
```lua
local text = GetUIText(COMMON_TEXT, "key_name")
local text = GetUIText(SKILL_TEXT, "skill_key", param)
```

### Color Functions

#### `ConvertColor(value)`
Converts a color value (0-255) to normalized (0.0-1.0).
```lua
local r = ConvertColor(241)
local g = ConvertColor(236)
```

#### `GetUnitGradeColor(grade)`
Gets the color for a unit grade.
```lua
local color = GetUnitGradeColor(grade)
```

### Widget Helper Functions

These are namespaced helper modules for creating common UI elements.

#### W_ICON - Icon Creation Helpers

```lua
-- Create various icon types
W_ICON.CreateGuideIconWidget(parent)            -- Create guide/help icon
W_ICON.CreateLeaderMark(id, parent)             -- Create leader marker icon
W_ICON.CreateLootIconWidget(parent)             -- Create loot icon
W_ICON.CreateQuestGradeMarker(parent)           -- Create quest grade marker
W_ICON.CreateAchievementGradeIcon(parent)       -- Create achievement grade icon
W_ICON.CreatePartyIconWidget(parent)            -- Create party icon
W_ICON.CreateArrowIcon(parent)                  -- Create arrow icon
W_ICON.DrawSkillFlameIcon(parent)               -- Draw skill flame icon
W_ICON.DrawRoundDingbat(widget)                 -- Draw round bullet point
W_ICON.DrawMinusDingbat(widget)                 -- Draw minus symbol
```

#### W_BTN - Button Creation Helpers

```lua
-- Create button widgets
W_BTN.CreateTab(id, parent, style)              -- Create tab control
-- style can be "ingameshop", or nil for default
```

#### W_BAR - Bar/Gauge Creation Helpers

```lua
-- Create various progress bars
W_BAR.CreateStatusBar(id, parent, style)        -- Create status bar
W_BAR.CreateStatusBarOfUnitFrame(id, parent, barType) -- Unit frame bar ("hp", "mp")
W_BAR.CreateStatusBarOfRaidFrame(id, parent)    -- Raid frame bar
W_BAR.CreateCastingBar(id, parent, unit)        -- Create casting bar
W_BAR.CreateSkillBar(id, parent)                -- Create skill progress bar
```

#### W_CTRL - Control Creation Helpers

```lua
-- Create widgets
W_CTRL.CreatePageControl(id, parent, style)     -- Create page control
W_CTRL.CreateMultiLineEdit(id, parent)          -- Create multi-line edit box
W_CTRL.CreateEdit(id, parent)                   -- Create single-line edit box
W_CTRL.CreatePageScrollListCtrl(id, parent)     -- Create scrollable list with pages
W_CTRL.CreateLabel(id, parent)                  -- Create label widget
W_CTRL.CreateListCtrl(id, parent)               -- Create list control
```

#### F_SOUND - Sound Functions

```lua
-- Play UI sounds
F_SOUND.PlayUISound(soundKey, stopPrevious)     -- Play UI sound effect
F_SOUND.PlayMusic(musicKey)                     -- Play background music

-- Common sound keys:
-- "event_mail_alarm", "event_trade_lock", "event_trade_item_putup"
-- "event_quest_list_changed", "login_stage_try_login", etc.
```

#### F_TEXT - Text Helper Functions

```lua
F_TEXT.SetEnterString(str, newText, count)      -- Add line breaks and append text
F_TEXT.ConvertAbbreviatedBindingText(text)      -- Convert binding text abbreviations
F_TEXT.ApplyEllipsisText(widget, maxWidth, params) -- Apply ellipsis to long text
F_TEXT.GetLimitInfoText(policyInfo)             -- Get text limit info string
```

#### F_LAYOUT - Layout Helper Functions

```lua
F_LAYOUT.CalcDontApplyUIScale(value)            -- Calculate value without UI scaling
F_LAYOUT.GetExtentWidgets(widget1, widget2)     -- Get extent between widgets
F_LAYOUT.AdjustTextWidth(widgetArray)           -- Adjust text width for widgets
F_LAYOUT.AttachAnchor(widget1, widget2, ...)    -- Attach anchor from widget1 to widget2
F_LAYOUT.GetUIScaleValueByRealValue(value)      -- Get UI scale value from real value
F_LAYOUT.GetUIScaleValueByOptionWindowValue(value) -- Get UI scale from option value
```

#### F_TEXTURE - Texture Helper Functions

```lua
F_TEXTURE.ApplyCoordAndAnchor(drawable, coords, parent, offsetX, offsetY)
  -- Apply texture coordinates and anchor at once
```

#### F_CALC - Calculation Functions

```lua
F_CALC.SubNum(num1Str, num2Str)                 -- Subtract number strings (for big numbers)
```

#### F_UNIT - Unit Helper Functions

```lua
F_UNIT.GetPetTargetName(mateType)               -- Get target name for pet/mate  
```

#### F_MONEY - Money Display Functions

```lua
F_MONEY.currency.pipeString                     -- Currency format strings table
```

### Other Helpers

#### `GetAbilityName(abilityType)`
Gets the name of an ability.
```lua
local name = GetAbilityName(abilityType)
```

#### `SetBGPushed(button, pushed, color)`
Sets the background pushed state of a button.
```lua
SetBGPushed(button, true, GetMyAbilityButtonFontColor())
```

#### `SetBGHighlighted(button, highlighted, color)`
Sets the background highlighted state of a button.
```lua
SetBGHighlighted(button, true, GetAbilityButtonFontColor())
```

#### `F_UNIT.GetPetTargetName(mateType)`
Gets the target name for a pet/mate.
```lua
local targetName = F_UNIT.GetPetTargetName(mateType)
```

---

## Event System

### Registering Events

#### `:RegisterEvent(eventName)`
Registers the widget to receive a specific event.
```lua
widget:RegisterEvent("SET_UI_MESSAGE")
playerFrame:RegisterEvent("SPELLCAST_START")
playerFrame:RegisterEvent("SPELLCAST_STOP")
```

**Common events:**
- `"ABILITY_CHANGED"`
- `"TARGET_CHANGED"`
- `"ENTERED_WORLD"`
- `"SPELLCAST_START"`
- `"SPELLCAST_STOP"`
- `"SPELLCAST_SUCCEEDED"`
- `"DIVE_START"`
- `"DIVE_END"`
- `"LEFT_LOADING"`
- `"WEB_BROWSER_ESC_EVENT"`
- `"BAD_USER_LIST_UPDATE"`
- `"OPEN_EMBLEM_IMPRINT_UI"`
- `"INTERACTION_END"`

### Event Handlers

#### `UIParent:SetEventHandler(eventName, function)`
Sets a global event handler.
```lua
UIParent:SetEventHandler("REPORT_CRIME", ShowReportCrimeWindow)
UIParent:SetEventHandler("ENTERED_WORLD", function()
  -- handle event
end)
```

#### `RegistUIEvent(widget, eventTable)`
Registers multiple UI events from a table.
```lua
local events = {
  ABILITY_CHANGED = function()
    -- handle ability changed
  end,
  TARGET_CHANGED = function()
    -- handle target changed
  end
}
widget:SetHandler("OnEvent", function(this, event, ...)
  events[event](...)
end)
RegistUIEvent(widget, events)
```

---

## ADDON/UI System

### Widget Registration

#### `ADDON:RegisterContentWidget(contentType, widget)`
Registers a content widget with the addon system.
```lua
ADDON:RegisterContentWidget(UIC_ABILITY_CHANGE, abilityChangeFrame)
ADDON:RegisterContentWidget(UIC_PLAYER_UNITFRAME, playerFrame)
```

#### `ADDON:RegisterContentTriggerFunc(contentType, function)`
Registers a trigger function for content.
```lua
ADDON:RegisterContentTriggerFunc(UIC_WEB_WIKI, OnToggleWebWikiAAC)
```

### Widget Creation

#### `UIParent:CreateWidget(widgetType, id, parent)`
Creates a top-level widget.
```lua
local widget = UIParent:CreateWidget("emptywidget", id, parent)
local window = UIParent:CreateWidget(baselibLocale.webWidgetName, id, parent)
```

### UI Stamps (Persistent Data)

#### `UI:SetUIStamp(key, value)`
Saves a UI stamp (persistent data).
```lua
UI:SetUIStamp(timeStampKey, stamp)
```

#### `UI:GetUIStamp(key)`
Gets a UI stamp.
```lua
local savedStamp = UI:GetUIStamp(timeStampKey)
```

---

## Localization

### Locale Tables

Locale data is stored in global tables and accessed by key:

```lua
locale.common.abilityCategoryName[abilityType]
locale.abilityChanger.title
locale.abilityChanger.GetExchangeText(ability1, ability2)
locale.trial.crimeReport
locale.mail.GetUnreadMail(count)
locale.time.GetDateToDateFormat(date, format)
locale.time.GetPeriodToMinutesSecondFormat(table)
```

**Common locale tables:**
- `locale.common` - Common strings
- `locale.trial` - Trial/jury system
- `locale.mail` - Mail system
- `locale.time` - Time formatting
- `locale.abilityChanger` - Ability system
- `locale.reportBadUser` - Report system
- `locale.unitFrame` - Unit frames
- `locale.territory` - Territory system
- `locale.skill` - Skills

### Locale View

Locale-specific UI configuration:

```lua
localeView.useWebContent
localeView.abilityButton.SetPushedFunc(button)
localeView.abilityButton.ResetFunc(button)
```

### Base Lib Locale

```lua
baselibLocale.useWebWiki
baselibLocale.useWebDiary
baselibLocale.useWebMessenger
baselibLocale.useWebInquire
baselibLocale.webWidgetName
```

---

## Drawing/Graphics

### Coordinate and Size Methods

#### `:SetCoords(x, y, width, height)`
Sets texture coordinates.
```lua
texture:SetCoords(0, 281, 296, 80)
```

#### `:SetExtent(width, height)`
Sets drawable extent.
```lua
texture:SetExtent(296, 80)
```

### Color and Visual Effects

#### `:SetColor(r, g, b, a)`
Sets color (values 0.0 to 1.0).
```lua
texture:SetColor(1, 1, 1, 0.8)
```

#### `:SetTextureInfo(textureName)`
Sets texture from predefined info.
```lua
icon:SetTextureInfo("icon_clock")
icon:SetTextureInfo("material")
```

### List Controls

#### `:InsertColumn(title, width, type, dataFunc, ...)`
Inserts a column in a list control.
```lua
pageListCtrl:InsertColumn(locale.trial.crimeRecordReportedBy, 150, LCCIT_STRING, DataSetFunc)
pageListCtrl:InsertColumn("Name", 200, LCCIT_WINDOW, DataSetFunc, nil, nil, LayoutFunc)
```

**Column types:**
- `LCCIT_STRING` - String column
- `LCCIT_WINDOW` - Custom window column

#### `:InsertRows(count, useEventWindow)`
Inserts the specified number of rows into a list control.
```lua
listCtrl:InsertRows(10, false)
listCtrl:InsertRows(MAX_ROW_COUNT, true)
```

#### `:InsertData(rowIndex, columnIndex, data, enableSorting)`
Inserts data into a specific cell of the list control.
```lua
listCtrl:InsertData(i, 1, nameData)
listCtrl:InsertData(i, 2, valueData, true)
```

#### `:InsertRowData(rowIndex, columnIndex, data)`
Inserts data for a single row (alternative method).
```lua
scrollList:InsertRowData(i, 1, data[i])
```

#### `:DeleteAllDatas()`
Clears all data from the list control.
```lua
listCtrl:DeleteAllDatas()
```

#### `:DeleteData(key)`
Deletes a specific row by key.
```lua
listCtrl:DeleteData(portalId)
```

#### `:DeleteRow(rowIndex)`
Deletes a specific row by index.
```lua
listCtrl:DeleteRow(3)
```

### Page Controls

#### `:SetPageByItemCount(count, perPage)`
Sets pagination based on item count.
```lua
pageControl:SetPageByItemCount(#items, 1)
```

### Text Styling

#### `.style:SetFont(fontPath, fontSize)`
Sets font for text.
```lua
label.style:SetFont(FONT_PATH.DEFAULT, FONT_SIZE.LARGE)
label.style:SetFont(FONT_PATH.LEEYAGI, FONT_SIZE.XLARGE)
```

#### `.style:SetFontSize(size)`
Sets font size.
```lua
label.style:SetFontSize(FONT_SIZE.MIDDLE)
```

#### `.style:SetAlign(alignment)`
Sets text alignment.
```lua
textbox.style:SetAlign(ALIGN_LEFT)
textbox.style:SetAlign(ALIGN_CENTER)
```

**Alignment constants:**
- `ALIGN_LEFT`
- `ALIGN_CENTER`
- `ALIGN_RIGHT`
- `ALIGN_TOP`
- `ALIGN_TOP_LEFT`
- `ALIGN_BOTTOM`

#### `:SetLineSpace(spacing)`
Sets line spacing for textboxes.
```lua
textbox:SetLineSpace(TEXTBOX_LINE_SPACE.SMALL)
```

#### `.style:SetSnap(boolean)`
Sets text snapping.
```lua
title.style:SetSnap(true)
```

### Item/Icon Methods

#### `:SetTooltip(data)`
Sets tooltip for an item icon.
```lua
item:SetTooltip(itemInfo)
self.buff:SetTooltip(buffInfo)
```

### Drag and Drop

#### `:RegisterForDrag(mouseButton)`
Enables dragging on a widget.
```lua
eventWindow:RegisterForDrag("LeftButton")
```

---

## Constants and Enums

### Content Types

- `UIC_ABILITY_CHANGE`
- `UIC_PLAYER_UNITFRAME`
- `UIC_WEB_WIKI`
- `UIC_WEB_PLAY_DIARY`
- `UIC_WEB_MESSENGER`
- `UIC_WEB_HELP`
- `UIC_TGOS`

### Game Providers

- `TENCENT`
- `TRION`
- `GAMEON`
- `LAGER`

### Mate Types

- `MATE_TYPE_RIDE` - Mount
- `MATE_TYPE_BATTLE` - Battle pet

### Text Categories

- `COMMON_TEXT`
- `SKILL_TEXT`
- `QUEST_TEXT`
- `TEAM_TEXT`
- `UNIT_GRADE_TEXT`
- `TOOLTIP_TEXT`
- `OPTION_TEXT`

### Chat Message Filters

- `CMF_SAY` - Say channel
- `CMF_SYSTEM` - System messages

### Date Format Filters

- `DATE_FORMAT_FILTER1`

---

## Examples

### Creating a Simple Button with Click Handler

```lua
-- Create button
local button = window:CreateChildWidget("button", "myButton", 0, true)
button:SetText("Click Me")
button:AddAnchor("CENTER", window, 0, 0)

-- Define click function
function button:OnClick()
  AddMessageToSysMsgWindow("Button clicked!")
end

-- Set handler
button:SetHandler("OnClick", button.OnClick)
```

### Creating a Window with Anchoring

```lua
-- Create window
local window = UIParent:CreateWidget("window", "myWindow", "UIParent")
window:SetExtent(400, 300)
window:AddAnchor("CENTER", "UIParent", 0, 0)

-- Add title bar
local titleBar = CreateTitleBar(window:GetId() .. ".titleBar", window)
window:SetTitle("My Window")

-- Add content
local label = window:CreateChildWidget("label", "label", 0, true)
label:SetText("Hello World")
label:AddAnchor("CENTER", window, 0, 0)
```

### Using X2 API to Get Unit Information

```lua
-- Get target information
local targetName = X2Unit:UnitName("target")
local targetLevel = X2Unit:UnitLevel("target")
local currentHP = X2Unit:UnitHealth("target")
local maxHP = X2Unit:UnitMaxHealth("target")

-- Display in label
local text = string.format("%s (Level %d): %d/%d HP", 
  targetName, targetLevel, currentHP, maxHP)
label:SetText(text)
```

### Registering and Handling Events

```lua
-- Define event handlers
local events = {
  ABILITY_CHANGED = function()
    window:Reset()
  end,
  TARGET_CHANGED = function()
    window:Show(false)
  end
}

-- Set event handler
window:SetHandler("OnEvent", function(this, event, ...)
  events[event](...)
end)

-- Register events
RegistUIEvent(window, events)
```

### Creating a Tooltip

```lua
local button = window:CreateChildWidget("button", "helpBtn", 0, true)
button:AddAnchor("TOPRIGHT", window, -10, 10)

function button:OnEnter()
  SetTooltip(GetCommonText("help_tooltip"), self)
end

function button:OnLeave()
  HideTooltip()
end

button:SetHandler("OnEnter", button.OnEnter)
button:SetHandler("OnLeave", button.OnLeave)
```

---

## Notes

- Most method names use camelCase (`:SetText`, `:AddAnchor`)
- Widget creation uses string type names (`"button"`, `"label"`, etc.)
- Colors are typically 0.0 to 1.0 (use `ConvertColor()` for 0-255 values)
- Anchoring is relative - you can anchor to "UIParent" for absolute screen positioning
- Event names are in UPPER_CASE with underscores
- X2 API namespaces use colon syntax (e.g., `X2Unit:UnitName()`)

---

**Document Version:** 1.0  
**Generated:** Based on analysis of X2UI Lua codebase  
**Coverage:** 958 Lua files analyzed
