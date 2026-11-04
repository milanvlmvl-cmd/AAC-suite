local api = require("api")
local settingsPage = require('ChatLogs/settings_page')

if LINE_HEIGHT == nil then LINE_HEIGHT = 16 end

-- ============================================================================
-- CONFIG
-- ============================================================================
local CONFIG = {
    BTN_W = 50,  BTN_H = 24,
    BTN_DEFAULT_X = 20,  BTN_DEFAULT_Y = 250,

    IND_W = 70,  IND_H = 24,
    IND_DEFAULT_X = 80,  IND_DEFAULT_Y = 250,

    HIST_W = 600,  HIST_H = 400,
    HIST_DEFAULT_X = 350,  HIST_DEFAULT_Y = 150,
    SIDEBAR_W = 150,
    HEADER_H = 30,
    FOOTER_H = 30,

    COL_BACKDROP = {0.15, 0.15, 0.15, 0.90},
    COL_HEADER   = {0.12, 0.12, 0.18, 0.95},
    COL_SIDEBAR  = {0.10, 0.10, 0.15, 0.95},
    COL_BODY     = {0.08, 0.08, 0.12, 0.95},
    COL_FOOTER   = {0.10, 0.10, 0.14, 0.95},
    COL_ALERT    = {0.40, 0.10, 0.05, 0.90},
    COL_MSG      = {0.80, 0.50, 1.00, 1.00},  -- incoming whisper (purple)
    COL_MSG_SENT = {0.65, 0.85, 1.00, 1.00},  -- outgoing whisper (light blue)
    COL_GREEN    = {0.00, 1.00, 0.00, 1.00},
    COL_ORANGE   = {1.00, 0.60, 0.00, 1.00},
    COL_WHITE    = {1.00, 1.00, 1.00, 1.00},
    COL_RED_FLASH= {0.60, 0.10, 0.10, 0.90},
    COL_EDIT_BG  = {0.12, 0.12, 0.18, 0.90},
    COL_GREY     = {0.45, 0.45, 0.45, 1.00},
    -- Default message colors (overridable per-user via the options page)
    COL_WHISPER_IN  = {1.00, 0.35, 0.95, 1.00},  -- magenta
    COL_WHISPER_OUT = {0.85, 0.65, 1.00, 1.00},  -- light lavender
    COL_CH_GUILD    = {0.40, 0.65, 1.00, 1.00},  -- blue
    COL_CH_FACTION  = {1.00, 0.90, 0.40, 1.00},  -- yellow
    COL_CH_NATION   = {0.35, 0.80, 0.45, 1.00},  -- darker green
    COL_CH_SAY      = {1.00, 1.00, 1.00, 1.00},  -- white
    COL_CH_ZONE     = {1.00, 0.60, 0.80, 1.00},  -- pink
    COL_CH_TRADE    = {1.00, 0.80, 0.50, 1.00},  -- light orange
    COL_CH_PARTY    = {0.45, 0.90, 0.90, 1.00},  -- cyan
    COL_CH_FAMILY   = {0.70, 1.00, 0.80, 1.00},  -- mint
    CHANNEL_WARN_THRESHOLD = 20000,
}

-- Channel routing. Keys are stable internal names used everywhere.
-- NOTE: Zone channel ID is unconfirmed; unmapped channel ids are logged once
-- (see OnUnknownChannel) so the real Zone id can be filled in here.
local CHANNEL_BY_ID = {
    [0]  = "say",
    [1]  = "zone",
    [2]  = "trade",
    [4]  = "party",
    [6]  = "nation",
    [7]  = "guild",
    [9]  = "family",
    [14] = "faction",
}
local CHANNEL_ORDER = { "guild", "faction", "nation", "say", "zone", "trade", "party", "family" }
local CHANNEL_LABEL = {
    guild = "Guild", faction = "Faction", nation = "Nation",
    say = "Say", zone = "Zone", trade = "Trade", party = "Party", family = "Family",
}

-- ============================================================================
-- HELPERS
-- ============================================================================
local function CreateBackdrop(parent, col)
    local bg = parent:CreateColorDrawable(
        col[1], col[2], col[3], col[4] or 1, "background")
    bg:AddAnchor("TOPLEFT", parent, 0, 0)
    bg:AddAnchor("BOTTOMRIGHT", parent, 0, 0)
    return bg
end

-- Declared here so GetHHMM (below) can capture it as an upvalue.
-- The data model section also declares this; LoadData() will update it.
local tzOffset = 0

-- Time system: mirrors CombatLogPro's approach.
-- Capture base UTC seconds-of-day once at load, track elapsed via GetUiMsec(),
-- apply tzOffset (hours) set by the player in the footer.
local BASE_SECONDS_OF_DAY = 0
local BASE_APP_MSEC       = 0
local TIME_INITIALIZED    = false

local function InitTime()
    local tVal = tonumber(api.Time:GetLocalTime())
    if tVal and tVal > 0 then
        BASE_SECONDS_OF_DAY = tVal % 86400
        BASE_APP_MSEC       = api.Time:GetUiMsec()
        TIME_INITIALIZED    = true
    end
end

local function GetHHMM()
    if not TIME_INITIALIZED then return "--:--" end
    local elapsed  = (api.Time:GetUiMsec() - BASE_APP_MSEC) / 1000
    local totalSec = (BASE_SECONDS_OF_DAY + elapsed + tzOffset * 3600) % 86400
    if totalSec < 0 then totalSec = totalSec + 86400 end
    local h = math.floor(totalSec / 3600)
    local m = math.floor((totalSec % 3600) / 60)
    return string.format("%02d:%02d", h, m)
end

local function MakeTimestamp()
    return api.Time:GetUiMsec()
end

local function FormatTimestamp(ts)
    return "--:--"
end

local function MakeDateString()
    if not TIME_INITIALIZED then return "export" end
    local elapsed  = (api.Time:GetUiMsec() - BASE_APP_MSEC) / 1000
    local totalSec = (BASE_SECONDS_OF_DAY + elapsed + tzOffset * 3600) % 86400
    if totalSec < 0 then totalSec = totalSec + 86400 end
    local h    = math.floor(totalSec / 3600)
    local m    = math.floor((totalSec % 3600) / 60)
    local days = math.floor((tonumber(api.Time:GetLocalTime()) + tzOffset * 3600) / 86400)
    return string.format("%d_%02d%02d", days, h, m)
end

-- Drag system — engine-native, matches CombatLogPro.
-- Hold SHIFT and drag the handle to move the window. The game engine drives
-- the movement via StartMoving/StopMovingOrSizing, so a plain click can never
-- leave a widget stuck to the cursor (the old OnMouseUp approach did).
--
-- handle    = widget that receives drag events
-- container = window that actually moves
-- onStop    = called with the window's new (x, y) offset when the drag ends
local function MakeDraggable(handle, container, onStop)
    handle:EnableDrag(true)
    handle:SetHandler("OnDragStart", function(self)
        -- Only move when SHIFT is held; otherwise a drag does nothing.
        if api.Input:IsShiftKeyDown() then
            container:StartMoving()
        end
    end)
    handle:SetHandler("OnDragStop", function(self)
        container:StopMovingOrSizing()
        local x, y = container:GetOffset()
        if onStop then onStop(x, y) end
    end)
end

-- ============================================================================
-- DATA MODEL
-- ============================================================================

-- Forward declarations — these locals are assigned in later tasks.
-- Closures capture the upvalue; assignment in later tasks is visible here.
local UpdateIndicator, RebuildSidebar, RebuildBody, JumpToFirstUnread, DoExport
local UpdateTabBar, RebuildActiveView, UpdateWarning

local conversations  = {}  -- [name] = { messages={}, unreadCount=0 }
local senderOrder    = {}  -- names sorted most-recent-first
local totalUnread    = 0
-- tzOffset declared before HELPERS section so GetHHMM() can capture it
local selectedSender = nil

-- Channels: parallel to conversations, append-only, no cap.
local channels = {}  -- channels[key] = { messages = {}, unreadCount = 0 }
for _, key in ipairs(CHANNEL_ORDER) do
    channels[key] = { messages = {}, unreadCount = 0 }
end
local activeTab = "whispers"  -- "whispers" or a channel key
local channelsDirty = false   -- any channel has unsaved data (gates the timer)
local channelDirty  = {}      -- [key] = true: this channel changed since last save
local savedActive   = {}      -- [key] = index of the last chunk written to disk
for _, key in ipairs(CHANNEL_ORDER) do channelDirty[key] = false; savedActive[key] = 0 end
local searchText = ""         -- active-view search filter
local searchBox               -- search edit widget (created in CreateHistoryWindow)

-- User settings (persisted in data.lua). Defaults overwritten by LoadData.
local channelEnabled = {
    guild = true, faction = true, nation = true, say = false, zone = false,
    trade = false, party = true, family = true,
}
-- Per-channel: also fire the external unread indicator (like whispers).
-- Opt-in, default all off.
local channelNotify = {
    guild = false, faction = false, nation = false, say = false, zone = false,
    trade = false, party = false, family = false,
}
local colors = {
    whisperIn  = CONFIG.COL_WHISPER_IN,
    whisperOut = CONFIG.COL_WHISPER_OUT,
    guild   = CONFIG.COL_CH_GUILD,
    faction = CONFIG.COL_CH_FACTION,
    nation  = CONFIG.COL_CH_NATION,
    say     = CONFIG.COL_CH_SAY,
    zone    = CONFIG.COL_CH_ZONE,
    trade   = CONFIG.COL_CH_TRADE,
    party   = CONFIG.COL_CH_PARTY,
    family  = CONFIG.COL_CH_FAMILY,
}

-- Widget references (assigned during CreateXxx functions)
local wButton, wIndicator, wHistory, histSidebar, histBody
local msgBtn  -- the button widget inside wButton, kept for color updates
local indicatorLabel, histFeedbackLabel, deleteTextbox, deleteTextboxBg
local histWarnLabel           -- orange "channel history large" warning
local tabBar, tabButtons = nil, {}  -- tabButtons[key] = button; key "whispers" or channel
local sidebarRows, bodyRows = {}, {}
local sidebarOffset, bodyOffset = 0, 0
local SIDEBAR_ROWS, BODY_ROWS

-- Saved positions — updated by drag, loaded from disk
local pos = {
    btnX  = CONFIG.BTN_DEFAULT_X,   btnY  = CONFIG.BTN_DEFAULT_Y,
    indX  = CONFIG.IND_DEFAULT_X,   indY  = CONFIG.IND_DEFAULT_Y,
    histX = CONFIG.HIST_DEFAULT_X,  histY = CONFIG.HIST_DEFAULT_Y,
}

-- ============================================================================
-- PERSISTENCE
-- ============================================================================
local DATA_PATH      = "ChatLogs/data.lua"
local CHANNELS_PATH  = "ChatLogs/channels.lua"
local SETTINGS_ID    = "ChatLogs"
local saveDirty      = false
local savePending    = false
local inCombat       = false  -- set by UNIT_COMBAT_STATE_CHANGED; defers saves
local saveErrorLogged = false -- so a failing write logs once, not every retry

local function RebuildSenderOrder()
    local withTime = {}
    for name, conv in pairs(conversations) do
        local lastTs = 0
        if #conv.messages > 0 then
            lastTs = conv.messages[#conv.messages].ts
        end
        table.insert(withTime, { name = name, ts = lastTs })
    end
    table.sort(withTime, function(a, b) return a.ts > b.ts end)
    senderOrder = {}
    for _, entry in ipairs(withTime) do
        table.insert(senderOrder, entry.name)
    end
end

local function SaveData()
    local ok, err = pcall(api.File.Write, api.File, DATA_PATH, {
        conversations  = conversations,
        senderOrder    = senderOrder,
        pos            = pos,
        tzOffset       = tzOffset,
        channelEnabled = channelEnabled,
        channelNotify  = channelNotify,
        colors         = colors,
    })
    if ok then
        saveDirty = false
        local store = api.GetSettings(SETTINGS_ID)
        if store and not store.dataExists then
            store.dataChecked = true; store.dataExists = true; api.SaveSettings()
        end
    elseif not saveErrorLogged then
        -- Log at most once per session; leave saveDirty=true so it retries quietly.
        saveErrorLogged = true
        api.Log:Err("[ChatLogs] Save failed: " .. tostring(err))
    end
end

-- Channels are stored as append-only chunks so a save never re-serializes the
-- whole history. Each channel's messages are split into SEG_SIZE-message chunk
-- files; sealed (full) chunks are never rewritten, and a save only rewrites the
-- one small "active" (last, partial) chunk plus any chunk newly sealed since the
-- last save. CHANNELS_PATH is a tiny manifest of per-channel chunk counts.
local SEG_SIZE = 500
local function ChunkPath(key, i) return "ChatLogs/chan_" .. key .. "_" .. i .. ".lua" end

local function SaveChannels()
    local wroteAnything = false
    for _, key in ipairs(CHANNEL_ORDER) do
        if channelDirty[key] then
            local msgs = channels[key].messages
            local n = #msgs
            local curActive = (n == 0) and 0 or math.ceil(n / SEG_SIZE)
            local writeOk = true
            -- Rewrite from the previously-active chunk (it may have gained
            -- messages and/or sealed) through the current active chunk.
            local fromChunk = math.max(1, savedActive[key])
            for i = fromChunk, curActive do
                local startIdx = (i - 1) * SEG_SIZE + 1
                local endIdx   = math.min(i * SEG_SIZE, n)
                local slice = {}
                for j = startIdx, endIdx do slice[#slice + 1] = msgs[j] end
                local ok = pcall(api.File.Write, api.File, ChunkPath(key, i), { msgs = slice })
                if not ok then writeOk = false; break end
            end
            if writeOk then
                savedActive[key] = curActive
                channelDirty[key] = false
                wroteAnything = true
            end
        end
    end

    -- Write the manifest (chunk counts + unread counts). Small + cheap.
    local segs, unread = {}, {}
    for _, key in ipairs(CHANNEL_ORDER) do
        segs[key]   = savedActive[key] or 0
        unread[key] = channels[key].unreadCount or 0
    end
    local ok, err = pcall(api.File.Write, api.File, CHANNELS_PATH, { segs = segs, unread = unread })
    if ok then
        channelsDirty = false
        local store = api.GetSettings(SETTINGS_ID)
        if store and not store.channelsExists then
            store.channelsChecked = true; store.channelsExists = true; api.SaveSettings()
        end
    elseif not saveErrorLogged then
        saveErrorLogged = true
        api.Log:Err("[ChatLogs] Channel save failed: " .. tostring(err))
    end
end

-- Debounced save: coalesces rapid writes (e.g. burst of whispers) into one
-- disk write 2 seconds after the last change. Deferred while in combat.
local function QueueSave()
    saveDirty = true
    if savePending then return end
    savePending = true
    api:DoIn(2000, function()
        savePending = false
        if saveDirty and not inCombat then SaveData() end
    end)
end

-- Periodic safety saves: whispers every 60s, channels every 5 min.
-- Both deferred while in combat (flushed on combat end — see InitCanvas).
local periodicSaveTimer = 0
local channelSaveTimer  = 0
local function OnPeriodicSave(dt)
    periodicSaveTimer = periodicSaveTimer + dt
    if periodicSaveTimer >= 60000 then
        periodicSaveTimer = 0
        if saveDirty and not inCombat then SaveData() end
    end
    channelSaveTimer = channelSaveTimer + dt
    if channelSaveTimer >= 300000 then
        channelSaveTimer = 0
        if channelsDirty and not inCombat then SaveChannels() end
    end
end

local function LoadData()
    -- Reading a file that doesn't exist produces a "file not found" message every
    -- session. We record in the addon's saved settings (api.GetSettings, part of
    -- the ArcheAge addon API) whether the data file exists, and only read when it
    -- does. The first run does a one-time read to migrate any pre-existing file,
    -- then remembers the result so later runs stay silent.
    local store = api.GetSettings(SETTINGS_ID)
    if store and store.dataChecked and not store.dataExists then
        return
    end
    local ok, data = pcall(function() return api.File:Read(DATA_PATH) end)
    local exists = ok and type(data) == "table"
    if store and (not store.dataChecked or store.dataExists ~= exists) then
        store.dataChecked = true
        store.dataExists = exists
        api.SaveSettings()
    end
    if not exists then
        -- No save file yet (normal on first run) or unreadable — start fresh.
        return
    end
    if type(data.conversations) == "table" then
        conversations = data.conversations
    end
    if type(data.pos) == "table" then
        for k, v in pairs(data.pos) do pos[k] = v end
    end
    if type(data.tzOffset) == "number" then tzOffset = data.tzOffset end
    if type(data.channelEnabled) == "table" then
        for _, key in ipairs(CHANNEL_ORDER) do
            if type(data.channelEnabled[key]) == "boolean" then
                channelEnabled[key] = data.channelEnabled[key]
            end
        end
    end
    if type(data.channelNotify) == "table" then
        for _, key in ipairs(CHANNEL_ORDER) do
            if type(data.channelNotify[key]) == "boolean" then
                channelNotify[key] = data.channelNotify[key]
            end
        end
    end
    if type(data.colors) == "table" then
        for k, v in pairs(data.colors) do
            if type(v) == "table" then colors[k] = v end
        end
    end
    RebuildSenderOrder()
    totalUnread = 0
    for _, conv in pairs(conversations) do
        totalUnread = totalUnread + (conv.unreadCount or 0)
    end
end

local function LoadChannels()
    local store = api.GetSettings(SETTINGS_ID)
    if store and store.channelsChecked and not store.channelsExists then
        return
    end
    local ok, data = pcall(function() return api.File:Read(CHANNELS_PATH) end)
    local exists = ok and type(data) == "table"
    if store and (not store.channelsChecked or store.channelsExists ~= exists) then
        store.channelsChecked = true
        store.channelsExists = exists
        api.SaveSettings()
    end
    if not exists then
        return  -- start empty; channels already initialized in DATA MODEL
    end

    if type(data.segs) == "table" then
        -- New chunked format: reassemble each channel from its chunk files.
        for _, key in ipairs(CHANNEL_ORDER) do
            local nseg = tonumber(data.segs[key]) or 0
            local msgs = {}
            for i = 1, nseg do
                local ok2, chunk = pcall(function() return api.File:Read(ChunkPath(key, i)) end)
                if ok2 and type(chunk) == "table" and type(chunk.msgs) == "table" then
                    for _, m in ipairs(chunk.msgs) do msgs[#msgs + 1] = m end
                end
            end
            channels[key].messages    = msgs
            channels[key].unreadCount = (data.unread and data.unread[key]) or 0
            savedActive[key]          = nseg
        end
    elseif type(data.channels) == "table" then
        -- Migrate the old single-file format: load into memory and mark dirty so
        -- the next save rewrites it as chunks (one-time).
        for _, key in ipairs(CHANNEL_ORDER) do
            local saved = data.channels[key]
            if type(saved) == "table" and type(saved.messages) == "table" then
                channels[key].messages    = saved.messages
                channels[key].unreadCount = saved.unreadCount or 0
            end
            savedActive[key] = 0
            channelDirty[key] = true
        end
        channelsDirty = true
    end
end

-- ============================================================================
-- EVENT CANVAS
-- ============================================================================
local canvas

local function MoveToFront(name)
    for i, n in ipairs(senderOrder) do
        if n == name then table.remove(senderOrder, i); break end
    end
    table.insert(senderOrder, 1, name)
end

-- Item links arrive as "|i<typeId>,<gradeIdx>,<hex...>;" which renders as garbage.
-- Replace each with a readable "[Name]" / "[Name (Grade)]" via GetItemInfoByType.
-- (Approach mirrors iykyk's GuildBroadcast item parser.)
local GRADE_BY_INDEX = {
    [1]="Basic", [2]="Grand", [3]="Rare", [4]="Arcane", [5]="Heroic",
    [6]="Unique", [7]="Celestial", [8]="Divine", [9]="Epic",
    [10]="Legendary", [11]="Mythic", [12]="Eternal",
}
local function ResolveItemLinks(text)
    if type(text) ~= "string" or not text:find("|i", 1, true) then return text end
    local out = text:gsub("|i(%d+)([^;]*);", function(typeId, body)
        local ok, info = pcall(api.Item.GetItemInfoByType, api.Item, tonumber(typeId))
        local name = (ok and info and info.name) or "item"
        local gradeIdx = tonumber((body or ""):match("^,(%d+)") or "0") or 0
        local grade = GRADE_BY_INDEX[gradeIdx]
        if not grade and ok and info and info.grade and info.grade ~= "" then
            grade = info.grade
        end
        if grade and grade ~= "Basic" then
            return "[" .. name .. " (" .. grade .. ")]"
        end
        return "[" .. name .. "]"
    end)
    return out
end

-- totalUnread drives the external indicator: all whisper unread, plus the
-- unread of any channel that has Notify enabled.
local function RecomputeTotalUnread()
    local n = 0
    for _, conv in pairs(conversations) do n = n + (conv.unreadCount or 0) end
    for _, key in ipairs(CHANNEL_ORDER) do
        if channelNotify[key] then n = n + (channels[key].unreadCount or 0) end
    end
    totalUnread = n
end

local function OnWhisperReceived(sender, text, sent)
    text = ResolveItemLinks(text)
    local ok, err = pcall(function()
        local ts      = MakeTimestamp()
        local timeStr = GetHHMM()
        if not conversations[sender] then
            conversations[sender] = { messages = {}, unreadCount = 0 }
        end
        table.insert(conversations[sender].messages,
            { text = text, ts = ts, timeStr = timeStr, sent = sent or false })
        MoveToFront(sender)

        local histOpen = wHistory and wHistory:IsVisible()
        if histOpen and selectedSender == sender then
            bodyOffset = 0
            if RebuildBody then RebuildBody() end
        elseif not sent then
            -- Only incoming messages trigger the unread indicator
            conversations[sender].unreadCount = (conversations[sender].unreadCount or 0) + 1
            RecomputeTotalUnread()
            if UpdateIndicator then UpdateIndicator() end
            if RebuildSidebar then RebuildSidebar() end
        end
        QueueSave()
    end)
    if not ok then
        api.Log:Err("[CL] OnWhisperReceived error: " .. tostring(err))
    end
end

local function OnChannelMessage(key, speaker, text)
    text = ResolveItemLinks(text)
    local ok, err = pcall(function()
        local ch = channels[key]
        if not ch then return end
        table.insert(ch.messages, {
            speaker = speaker, text = text,
            ts = MakeTimestamp(), timeStr = GetHHMM(),
        })
        local histOpen = wHistory and wHistory:IsVisible()
        if histOpen and activeTab == key then
            bodyOffset = 0
            if RebuildActiveView then RebuildActiveView() end
        else
            ch.unreadCount = (ch.unreadCount or 0) + 1
            if UpdateTabBar then UpdateTabBar() end
            if channelNotify[key] then
                RecomputeTotalUnread()
                if UpdateIndicator then UpdateIndicator() end
            end
        end
        channelsDirty = true
        channelDirty[key] = true
        if UpdateWarning then UpdateWarning() end
    end)
    if not ok then api.Log:Err("[CL] OnChannelMessage error: " .. tostring(err)) end
end

-- Some channel ids (zone/trade/party/family) are unconfirmed. "Discovery mode"
-- is on whenever an enabled channel has no id mapped to it; while on, log each
-- unrecognized chat channel id once so it can be added to CHANNEL_BY_ID.
local loggedUnknown = {}
local function DiscoveryModeOn()
    local mapped = {}
    for _, key in pairs(CHANNEL_BY_ID) do mapped[key] = true end
    for _, key in ipairs(CHANNEL_ORDER) do
        if channelEnabled[key] and not mapped[key] then return true end
    end
    return false
end
local function MaybeLogUnknownChannel(channelId, speaker, text)
    -- Whisper ids (-3/-4) are handled upstream and never reach here, so any id
    -- arriving here (positive OR negative) is a candidate to map.
    if CHANNEL_BY_ID[channelId] then return end
    if loggedUnknown[channelId] then return end
    if not DiscoveryModeOn() then return end
    loggedUnknown[channelId] = true
    api.Log:Info("[ChatLogs] Unmapped channel id=" .. tostring(channelId)
        .. " from " .. tostring(speaker) .. ": " .. tostring(text)
        .. "  (give this id to the author to enable that channel)")
end

local function InitCanvas()
    -- Free any stale canvas from a previous load to prevent double-firing
    if canvas then api.Interface:Free(canvas) end
    canvas = api.Interface:CreateEmptyWindow("ChatLogsCanvas", "UIParent")
    canvas:Show(true)
    canvas:SetExtent(1, 1)
    canvas:RegisterEvent("CHAT_MESSAGE")
    canvas:RegisterEvent("UNIT_COMBAT_STATE_CHANGED")
    api.On("UPDATE", OnPeriodicSave)
    canvas:SetHandler("OnEvent", function(self, event, ...)
        if event == "UNIT_COMBAT_STATE_CHANGED" then
            -- arg[1] = boolean (true=entering combat, false=leaving), arg[2] = unitId
            inCombat = (arg[1] == true)
            if not inCombat then
                -- Flush any saves deferred during combat
                if saveDirty then SaveData() end
                if channelsDirty then SaveChannels() end
            end
            return
        end
        if event ~= "CHAT_MESSAGE" then return end
        -- ch=-3 incoming whisper, ch=-4 outgoing whisper.
        -- a4 = the other player's / speaker's name, a5 = message text.
        local channelId = tonumber(arg[1])
        local sender = tostring(arg[4] or "")
        local text   = tostring(arg[5] or "")
        local valid  = sender ~= "" and sender ~= "nil"
                   and text ~= "" and text ~= "nil"
        if not valid then return end
        if channelId == -3 or channelId == -4 then
            OnWhisperReceived(sender, text, channelId == -4)
        else
            local key = CHANNEL_BY_ID[channelId]
            if key and channelEnabled[key] then
                OnChannelMessage(key, sender, text)
            else
                MaybeLogUnknownChannel(channelId, sender, text)
            end
        end
    end)
end

-- Anchor a window with TOPLEFT at (x, y), falling back to (defX, defY) if the
-- saved position is missing or off-screen. This also migrates positions saved
-- by older versions that used a "LEFT" anchor with negative offsets.
local function AnchorWindow(win, x, y, defX, defY)
    local sw = api.Interface:GetScreenWidth()
    local sh = api.Interface:GetScreenHeight()
    if type(x) ~= "number" or type(y) ~= "number"
    or x < 0 or y < 0 or x > sw - 10 or y > sh - 10 then
        x, y = defX, defY
    end
    win:RemoveAllAnchors()
    win:AddAnchor("TOPLEFT", "UIParent", x, y)
    return x, y
end

-- ============================================================================
-- HUD BUTTON
-- ============================================================================
local function CreateButton()
    wButton = api.Interface:CreateEmptyWindow("CLBtn", "UIParent")
    wButton:Show(true)
    wButton:SetExtent(CONFIG.BTN_W, CONFIG.BTN_H)
    pos.btnX, pos.btnY = AnchorWindow(wButton, pos.btnX, pos.btnY,
        CONFIG.BTN_DEFAULT_X, CONFIG.BTN_DEFAULT_Y)
    CreateBackdrop(wButton, CONFIG.COL_BACKDROP)

    msgBtn = wButton:CreateChildWidget("button", "CLBtnToggle", 0, true)
    local btn = msgBtn
    btn:SetText("LOGS")
    btn:SetTextColor(
        CONFIG.COL_GREY[1], CONFIG.COL_GREY[2], CONFIG.COL_GREY[3], 1)
    btn:AddAnchor("TOPLEFT", wButton, 0, 0)
    btn:AddAnchor("BOTTOMRIGHT", wButton, 0, 0)
    btn:SetHandler("OnClick", function()
        if api.Input:IsShiftKeyDown() then return end
        if wHistory then
            wHistory:Show(not wHistory:IsVisible())
            UpdateIndicator()
        end
    end)

    MakeDraggable(btn, wButton, function(x, y)
        pos.btnX, pos.btnY = x, y
        QueueSave()
    end)
end

-- ============================================================================
-- UNREAD INDICATOR
-- ============================================================================
UpdateIndicator = function()
    if not wIndicator then return end
    if totalUnread > 0 then
        indicatorLabel:SetText("! [" .. totalUnread .. "]")
        wIndicator:Show(true)
    else
        wIndicator:Show(false)
    end
    -- Keep MSG button colour in sync
    if msgBtn then
        local lit = totalUnread > 0 or (wHistory and wHistory:IsVisible())
        if lit then
            msgBtn:SetTextColor(CONFIG.COL_GREEN[1], CONFIG.COL_GREEN[2], CONFIG.COL_GREEN[3], 1)
        else
            msgBtn:SetTextColor(CONFIG.COL_GREY[1], CONFIG.COL_GREY[2], CONFIG.COL_GREY[3], 1)
        end
    end
end

local function CreateIndicator()
    wIndicator = api.Interface:CreateEmptyWindow("CLInd", "UIParent")
    wIndicator:SetExtent(CONFIG.IND_W, CONFIG.IND_H)
    pos.indX, pos.indY = AnchorWindow(wIndicator, pos.indX, pos.indY,
        CONFIG.IND_DEFAULT_X, CONFIG.IND_DEFAULT_Y)
    wIndicator:Show(false)
    CreateBackdrop(wIndicator, CONFIG.COL_ALERT)

    indicatorLabel = wIndicator:CreateChildWidget("label", "CLIndLbl", 0, true)
    indicatorLabel:SetText("! [0]")
    indicatorLabel:AddAnchor("CENTER", wIndicator, 0, 0)
    if indicatorLabel.style then
        indicatorLabel.style:SetAlign(ALIGN.CENTER)
        indicatorLabel.style:SetShadow(true)
        indicatorLabel.style:SetColor(
            CONFIG.COL_ORANGE[1], CONFIG.COL_ORANGE[2], CONFIG.COL_ORANGE[3], 1)
    end

    -- Click zone (button captures click + drag; label just displays)
    local clickZone = wIndicator:CreateChildWidget("button", "CLIndClick", 0, true)
    clickZone:AddAnchor("TOPLEFT", wIndicator, 0, 0)
    clickZone:AddAnchor("BOTTOMRIGHT", wIndicator, 0, 0)
    clickZone:SetText("")
    clickZone:SetHandler("OnClick", function()
        if api.Input:IsShiftKeyDown() then return end
        if wHistory then
            wHistory:Show(true)
            if JumpToFirstUnread then JumpToFirstUnread() end
        end
    end)

    MakeDraggable(clickZone, wIndicator, function(x, y)
        pos.indX, pos.indY = x, y
        QueueSave()
    end)

    UpdateIndicator()  -- show immediately if unreads loaded from disk
end

-- ============================================================================
-- HISTORY WINDOW
-- ============================================================================
local function CreateHistoryWindow()
    wHistory = api.Interface:CreateEmptyWindow("CLHist", "UIParent")
    wHistory:SetExtent(CONFIG.HIST_W, CONFIG.HIST_H)
    pos.histX, pos.histY = AnchorWindow(wHistory, pos.histX, pos.histY,
        CONFIG.HIST_DEFAULT_X, CONFIG.HIST_DEFAULT_Y)
    wHistory:Show(false)

    -- Header
    local header = wHistory:CreateChildWidget("emptywidget", "CLHistHdr", 0, true)
    header:AddAnchor("TOPLEFT", wHistory, 0, 0)
    header:AddAnchor("TOPRIGHT", wHistory, 0, 0)
    header:SetHeight(CONFIG.HEADER_H)
    CreateBackdrop(header, CONFIG.COL_HEADER)

    local title = header:CreateChildWidget("label", "CLHistTitle", 0, true)
    title:SetText("ChatLogs")
    title:AddAnchor("LEFT", header, 10, 0)
    title:SetExtent(70, CONFIG.HEADER_H)
    if title.style then
        title.style:SetAlign(ALIGN.LEFT)
        title.style:SetColor(1, 1, 1, 1)
    end

    -- Search box (filters the active view)
    searchBox = W_CTRL.CreateEdit("CLSearch", header)
    searchBox:SetExtent(140, 20)
    searchBox:AddAnchor("LEFT", title, "RIGHT", 6, 0)
    searchBox:SetHandler("OnTextChanged", function(self)
        searchText = tostring(self:GetText() or "")
        bodyOffset = 0
        if RebuildActiveView then RebuildActiveView() end
    end)

    -- Close button — also marks selected sender read before hiding
    local btnClose = header:CreateChildWidget("button", "CLHistClose", 0, true)
    btnClose:SetExtent(30, 24)
    btnClose:AddAnchor("RIGHT", header, -5, 0)
    btnClose:SetText("X")
    btnClose:SetHandler("OnClick", function()
        if selectedSender and conversations[selectedSender] then
            conversations[selectedSender].unreadCount = 0
            RecomputeTotalUnread()
        end
        wHistory:Show(false)
        UpdateIndicator()
        QueueSave()
    end)

    -- Export button
    local btnExport = header:CreateChildWidget("button", "CLHistExport", 0, true)
    btnExport:SetExtent(55, 24)
    btnExport:AddAnchor("RIGHT", btnClose, "LEFT", -5, 0)
    btnExport:SetText("Export")
    btnExport:SetHandler("OnClick", function()
        if DoExport then DoExport() end
    end)

    -- Options button
    local btnOptions = header:CreateChildWidget("button", "CLHistOptions", 0, true)
    btnOptions:SetExtent(60, 24)
    btnOptions:AddAnchor("RIGHT", btnExport, "LEFT", -5, 0)
    btnOptions:SetText("Options")
    btnOptions:SetHandler("OnClick", function()
        settingsPage.Open({
            getEnabled = function(k) return channelEnabled[k] end,
            setEnabled = function(k, v)
                channelEnabled[k] = v and true or false
                if UpdateTabBar then UpdateTabBar() end
                if RebuildActiveView then RebuildActiveView() end
                QueueSave()
            end,
            getNotify = function(k) return channelNotify[k] end,
            setNotify = function(k, v)
                channelNotify[k] = v and true or false
                RecomputeTotalUnread()
                if UpdateIndicator then UpdateIndicator() end
                QueueSave()
            end,
            getColor = function(k) return colors[k] end,
            setColor = function(k, c)
                colors[k] = { c[1], c[2], c[3], 1 }
                if RebuildActiveView then RebuildActiveView() end
                QueueSave()
            end,
            getTz = function() return tzOffset end,
            setTz = function(v)
                tzOffset = v
                if RebuildActiveView then RebuildActiveView() end
                QueueSave()
            end,
        })
    end)

    -- Feedback label ("Exported!" / "Nothing to export") — shown briefly
    histFeedbackLabel = header:CreateChildWidget("label", "CLHistFeedback", 0, true)
    histFeedbackLabel:SetText("")
    histFeedbackLabel:AddAnchor("RIGHT", btnOptions, "LEFT", -8, 0)
    histFeedbackLabel:SetExtent(120, CONFIG.HEADER_H)
    histFeedbackLabel:Show(false)
    if histFeedbackLabel.style then
        histFeedbackLabel.style:SetAlign(ALIGN.RIGHT)
    end

    -- Warning label (channel history large)
    histWarnLabel = header:CreateChildWidget("label", "CLWarn", 0, true)
    histWarnLabel:SetText("")
    histWarnLabel:AddAnchor("LEFT", searchBox, "RIGHT", 10, 0)
    histWarnLabel:SetExtent(260, CONFIG.HEADER_H)
    histWarnLabel:Show(false)
    if histWarnLabel.style then
        histWarnLabel.style:SetAlign(ALIGN.LEFT)
        histWarnLabel.style:SetColor(1, 0.6, 0, 1)
    end

    -- Tab bar (row below header)
    tabBar = wHistory:CreateChildWidget("emptywidget", "CLTabBar", 0, true)
    tabBar:AddAnchor("TOPLEFT", wHistory, 0, CONFIG.HEADER_H)
    tabBar:AddAnchor("TOPRIGHT", wHistory, 0, CONFIG.HEADER_H)
    tabBar:SetHeight(24)
    CreateBackdrop(tabBar, CONFIG.COL_HEADER)

    local function MakeTab(key, labelText, anchorTo)
        local b = tabBar:CreateChildWidget("button", "CLTab_" .. key, 0, true)
        b:SetExtent(64, 22)
        if anchorTo then b:AddAnchor("LEFT", anchorTo, "RIGHT", 2, 0)
        else b:AddAnchor("LEFT", tabBar, 4, 0) end
        b:SetText(labelText)
        b:SetHandler("OnClick", function()
            activeTab = key
            bodyOffset = 0
            searchText = ""
            if searchBox then searchBox:SetText("") end
            local ch = channels[key]
            if ch then ch.unreadCount = 0 end
            RecomputeTotalUnread()
            if UpdateIndicator then UpdateIndicator() end
            if UpdateTabBar then UpdateTabBar() end
            if RebuildActiveView then RebuildActiveView() end
        end)
        tabButtons[key] = b
        return b
    end

    local prev = MakeTab("whispers", "Whispers", nil)
    for _, key in ipairs(CHANNEL_ORDER) do
        prev = MakeTab(key, CHANNEL_LABEL[key], prev)
    end

    -- Drag via header (Shift+drag to move)
    MakeDraggable(header, wHistory, function(x, y)
        pos.histX, pos.histY = x, y
        QueueSave()
    end)
end

-- Compact unread badge: caps at "99+" so huge counts don't blow out the tab.
local function FmtUnread(n)
    if n > 99 then return "99+" end
    return tostring(n)
end

-- Tab bar refresh: re-packs visible tabs (no gaps, width sized to fit them all),
-- then updates labels, unread badges, and active highlight.
local tabLayoutSig = nil
UpdateTabBar = function()
    if not tabButtons then return end

    -- Re-layout only when the enabled set changes (avoids per-message churn).
    local sig = ""
    for _, key in ipairs(CHANNEL_ORDER) do
        sig = sig .. (channelEnabled[key] and "1" or "0")
    end
    if sig ~= tabLayoutSig then
        tabLayoutSig = sig
        -- Width adapts to how many tabs are visible so they pack without
        -- overflowing the bar: wide (readable) when few, narrower when many.
        local visible = 1
        for _, key in ipairs(CHANNEL_ORDER) do
            if channelEnabled[key] then visible = visible + 1 end
        end
        local gap   = 2
        local avail = CONFIG.HIST_W - 8
        local tabW  = math.floor((avail - gap * (visible - 1)) / visible)
        if tabW > 92 then tabW = 92 end
        if tabW < 50 then tabW = 50 end

        local prev = tabButtons["whispers"]
        if prev then
            prev:RemoveAllAnchors()
            prev:SetExtent(tabW, 22)
            prev:AddAnchor("LEFT", tabBar, 4, 0)
            prev:Show(true)
        end
        for _, key in ipairs(CHANNEL_ORDER) do
            local b = tabButtons[key]
            if b then
                if channelEnabled[key] then
                    b:RemoveAllAnchors()
                    b:SetExtent(tabW, 22)
                    if prev then b:AddAnchor("LEFT", prev, "RIGHT", gap, 0)
                    else b:AddAnchor("LEFT", tabBar, 4, 0) end
                    b:Show(true)
                    prev = b
                else
                    b:Show(false)
                end
            end
        end
    end

    -- Refresh badges + active highlight every call.
    for _, key in ipairs(CHANNEL_ORDER) do
        local b = tabButtons[key]
        if b and channelEnabled[key] then
            local ch = channels[key]
            local unread = ch and (ch.unreadCount or 0) or 0
            local label = CHANNEL_LABEL[key]
            if unread > 0 then label = label .. " [" .. FmtUnread(unread) .. "]" end
            b:SetText(label)
            local c = (activeTab == key) and CONFIG.COL_GREEN or CONFIG.COL_WHITE
            b:SetTextColor(c[1], c[2], c[3], 1)
        end
    end
    local wb = tabButtons["whispers"]
    if wb then
        local c = (activeTab == "whispers") and CONFIG.COL_GREEN or CONFIG.COL_WHITE
        wb:SetTextColor(c[1], c[2], c[3], 1)
    end
end

-- Total channel lines across all channels (for the warning + export guard).
local function TotalChannelLines()
    local n = 0
    for _, key in ipairs(CHANNEL_ORDER) do
        n = n + #channels[key].messages
    end
    return n
end

UpdateWarning = function()
    if not histWarnLabel then return end
    local n = TotalChannelLines()
    if n > CONFIG.CHANNEL_WARN_THRESHOLD then
        histWarnLabel:SetText(string.format(
            "Channel history large (%d lines) - Export + Clear recommended.", n))
        histWarnLabel:Show(true)
    else
        histWarnLabel:Show(false)
    end
end

-- ============================================================================
-- SIDEBAR
-- ============================================================================
RebuildSidebar = function()
    if not histSidebar then return end
    for i, btn in ipairs(sidebarRows) do
        local name = senderOrder[i + sidebarOffset]
        if name then
            local conv = conversations[name]
            local unread = conv and (conv.unreadCount or 0) or 0
            if unread > 0 then
                btn:SetText(name .. " [" .. unread .. "]")
                btn:SetTextColor(
                    CONFIG.COL_ORANGE[1], CONFIG.COL_ORANGE[2],
                    CONFIG.COL_ORANGE[3], 1)
            elseif name == selectedSender then
                btn:SetText(name)
                btn:SetTextColor(
                    CONFIG.COL_GREEN[1], CONFIG.COL_GREEN[2],
                    CONFIG.COL_GREEN[3], 1)
            else
                btn:SetText(name)
                btn:SetTextColor(
                    CONFIG.COL_WHITE[1], CONFIG.COL_WHITE[2],
                    CONFIG.COL_WHITE[3], 1)
            end
            btn:Show(true)
            btn.senderName = name
        else
            btn:SetText("")
            btn:Show(false)
            btn.senderName = nil
        end
    end
end

local function SelectSender(name)
    if not name or not conversations[name] then return end
    selectedSender = name
    conversations[name].unreadCount = 0
    RecomputeTotalUnread()
    bodyOffset = 0
    UpdateIndicator()
    RebuildSidebar()
    if RebuildBody then RebuildBody() end
    QueueSave()
end

JumpToFirstUnread = function()
    -- Prefer an unread whisper sender
    for _, name in ipairs(senderOrder) do
        local conv = conversations[name]
        if conv and (conv.unreadCount or 0) > 0 then
            activeTab = "whispers"
            if UpdateTabBar then UpdateTabBar() end
            SelectSender(name)
            if RebuildActiveView then RebuildActiveView() end
            return
        end
    end
    -- Else jump to a notify-enabled channel that has unread
    for _, key in ipairs(CHANNEL_ORDER) do
        if channelNotify[key] and (channels[key].unreadCount or 0) > 0 then
            activeTab = key
            channels[key].unreadCount = 0
            RecomputeTotalUnread()
            bodyOffset = 0
            if UpdateIndicator then UpdateIndicator() end
            if UpdateTabBar then UpdateTabBar() end
            if RebuildActiveView then RebuildActiveView() end
            return
        end
    end
    -- Fallback: most recent whisper
    if senderOrder[1] then
        activeTab = "whispers"
        if UpdateTabBar then UpdateTabBar() end
        SelectSender(senderOrder[1])
        if RebuildActiveView then RebuildActiveView() end
    end
end

local function CreateSidebar()
    local innerH = CONFIG.HIST_H - CONFIG.HEADER_H - 24 - CONFIG.FOOTER_H
    SIDEBAR_ROWS = math.floor(innerH / LINE_HEIGHT)

    histSidebar = wHistory:CreateChildWidget("emptywidget", "CLHistSide", 0, true)
    histSidebar:AddAnchor("TOPLEFT", wHistory, 0, CONFIG.HEADER_H + 24)
    histSidebar:SetExtent(CONFIG.SIDEBAR_W, innerH)
    histSidebar:EnableDrag(true)  -- required for the widget to receive OnMouseWheel
    CreateBackdrop(histSidebar, CONFIG.COL_SIDEBAR)

    local function SideWheel(self, delta)
        local maxOffset = math.max(0, #senderOrder - SIDEBAR_ROWS)
        sidebarOffset = math.max(0, math.min(maxOffset, sidebarOffset - delta))
        RebuildSidebar()
    end

    for i = 1, SIDEBAR_ROWS do
        local btn = histSidebar:CreateChildWidget(
            "button", "CLSideRow" .. i, 0, true)
        btn:SetExtent(CONFIG.SIDEBAR_W - 4, LINE_HEIGHT)
        btn:AddAnchor("TOPLEFT", histSidebar, 2, (i - 1) * LINE_HEIGHT + 2)
        if btn.style then btn.style:SetAlign(ALIGN.LEFT) end
        btn:SetText("")
        btn:Show(false)
        btn.senderName = nil
        btn:SetHandler("OnClick", function(self)
            if self.senderName then SelectSender(self.senderName) end
        end)
        btn:EnableDrag(true)
        btn:SetHandler("OnMouseWheel", SideWheel)
        sidebarRows[i] = btn
    end

    histSidebar:SetHandler("OnMouseWheel", SideWheel)

    RebuildSidebar()
end

-- ============================================================================
-- MESSAGE BODY
-- ============================================================================

-- Cached flat list of wrapped display lines for the current conversation.
-- Rebuilt whenever the conversation changes; scroll operates on this list.
local displayLines = {}

-- Wrap a single message into one or more display lines.
-- Breaks at word boundaries; continuation lines are indented.
-- Whispers wrap narrower (sidebar takes space); channels use the full width.
local WHISPER_WRAP_CHARS = 62
local CHANNEL_WRAP_CHARS = 84
-- The live view only ever wraps/renders the most recent MAX_VIEW messages of the
-- active tab. Set generously: display wrapping is O(n) but doesn't crash (only the
-- old serialize-everything write did, which is gone). This is just a safety bound
-- against pathological sizes; normal scrollback is unaffected. Full history is
-- always stored on disk (chunks) and included in exports regardless.
local MAX_VIEW = 10000

local function WrapMessage(timeStr, prefix, text, col, maxChars)
    local header = "[" .. timeStr .. "] " .. prefix
    local full   = header .. text
    local indent = string.rep(" ", #header)  -- align continuation to message start
    local lines  = {}
    local maxW   = maxChars or WHISPER_WRAP_CHARS

    if #full <= maxW then
        table.insert(lines, { text = full, col = col })
        return lines
    end

    local remaining = full
    while #remaining > maxW do
        local breakAt = maxW
        -- Walk back to find a space to break on
        for i = maxW, math.max(1, maxW - 20), -1 do
            if remaining:sub(i, i) == " " then
                breakAt = i - 1
                break
            end
        end
        table.insert(lines, { text = remaining:sub(1, breakAt), col = col })
        -- Strip leading space from the remainder, add indent
        local rest = remaining:sub(breakAt + 1):match("^%s*(.*)")
        remaining = indent .. rest
    end
    if #remaining > 0 then
        table.insert(lines, { text = remaining, col = col })
    end
    return lines
end

local function ColorFor(key) return colors[key] or CONFIG.COL_WHITE end

local function BuildDisplayLines()
    displayLines = {}
    if activeTab == "whispers" then
        if not selectedSender or not conversations[selectedSender] then return end
        local msgs  = conversations[selectedSender].messages
        local start = math.max(1, #msgs - MAX_VIEW + 1)
        for i = start, #msgs do
            local m = msgs[i]
            local prefix = m.sent and "You: " or ""
            local col    = m.sent and colors.whisperOut or colors.whisperIn
            for _, line in ipairs(WrapMessage(m.timeStr or "--:--", prefix, m.text, col, WHISPER_WRAP_CHARS)) do
                table.insert(displayLines, line)
            end
        end
    else
        local ch = channels[activeTab]
        if not ch then return end
        local col   = ColorFor(activeTab)
        local msgs  = ch.messages
        local start = math.max(1, #msgs - MAX_VIEW + 1)
        for i = start, #msgs do
            local m = msgs[i]
            local prefix = (m.speaker or "?") .. ": "
            for _, line in ipairs(WrapMessage(m.timeStr or "--:--", prefix, m.text, col, CHANNEL_WRAP_CHARS)) do
                table.insert(displayLines, line)
            end
        end
    end
    -- Active-view search filter
    if searchText ~= "" then
        local needle = searchText:lower()
        local filtered = {}
        for _, line in ipairs(displayLines) do
            if tostring(line.text):lower():find(needle, 1, true) then
                table.insert(filtered, line)
            end
        end
        displayLines = filtered
    end
end

RebuildBody = function()
    if not histBody then return end
    BuildDisplayLines()
    local total    = #displayLines
    -- bodyOffset=0 shows the last BODY_ROWS lines; offset N scrolls N lines up
    local endIdx   = total - bodyOffset
    local startIdx = math.max(1, endIdx - BODY_ROWS + 1)
    local row = 1
    for i = startIdx, endIdx do
        local line = displayLines[i]
        if line and bodyRows[row] then
            bodyRows[row]:SetText(line.text)
            if bodyRows[row].style then
                bodyRows[row].style:SetColor(line.col[1], line.col[2], line.col[3], 1)
            end
            bodyRows[row]:Show(true)
        end
        row = row + 1
    end
    for i = row, #bodyRows do
        bodyRows[i]:SetText(""); bodyRows[i]:Show(false)
    end
end

-- Switch the body between the whispers layout (sidebar + narrow body) and a
-- channel layout (no sidebar, full-width body), then redraw.
RebuildActiveView = function()
    if histSidebar then histSidebar:Show(activeTab == "whispers") end
    local labelW
    if histBody then
        histBody:RemoveAllAnchors()
        if activeTab == "whispers" then
            histBody:AddAnchor("TOPLEFT", wHistory, CONFIG.SIDEBAR_W, CONFIG.HEADER_H + 24)
            histBody:SetExtent(CONFIG.HIST_W - CONFIG.SIDEBAR_W,
                CONFIG.HIST_H - CONFIG.HEADER_H - 24 - CONFIG.FOOTER_H)
            labelW = CONFIG.HIST_W - CONFIG.SIDEBAR_W - 12
        else
            histBody:AddAnchor("TOPLEFT", wHistory, 0, CONFIG.HEADER_H + 24)
            histBody:SetExtent(CONFIG.HIST_W,
                CONFIG.HIST_H - CONFIG.HEADER_H - 24 - CONFIG.FOOTER_H)
            labelW = CONFIG.HIST_W - 12
        end
    end
    -- Resize body row labels to match the active layout's width so channel
    -- lines can use the full window width.
    if labelW then
        for _, lbl in ipairs(bodyRows) do lbl:SetExtent(labelW, LINE_HEIGHT) end
    end
    RebuildBody()
    if UpdateWarning then UpdateWarning() end
end

-- Scroll the body by `lines` (positive = older/up, negative = newer/down).
local function ScrollBody(lines)
    if activeTab == "whispers" and not selectedSender then return end
    BuildDisplayLines()
    local maxOffset = math.max(0, #displayLines - BODY_ROWS)
    bodyOffset = math.max(0, math.min(maxOffset, bodyOffset + lines))
    RebuildBody()
end

-- Wheel up (d>0) shows older messages; wheel down shows newer. 3 lines/notch.
local function WheelScroll(self, d) ScrollBody(d > 0 and 3 or -3) end

local function CreateBody()
    local innerH = CONFIG.HIST_H - CONFIG.HEADER_H - 24 - CONFIG.FOOTER_H
    BODY_ROWS = math.floor(innerH / LINE_HEIGHT)
    local bodyW = CONFIG.HIST_W - CONFIG.SIDEBAR_W

    histBody = wHistory:CreateChildWidget("emptywidget", "CLHistBody", 0, true)
    histBody:AddAnchor("TOPLEFT", wHistory, CONFIG.SIDEBAR_W, CONFIG.HEADER_H + 24)
    histBody:SetExtent(bodyW, innerH)
    histBody:EnableDrag(true)
    histBody:SetHandler("OnMouseWheel", WheelScroll)
    CreateBackdrop(histBody, CONFIG.COL_BODY)

    for i = 1, BODY_ROWS do
        local lbl = histBody:CreateChildWidget(
            "label", "CLBodyRow" .. i, 0, true)
        lbl:AddAnchor("TOPLEFT", histBody, 6, (i - 1) * LINE_HEIGHT + 4)
        lbl:SetExtent(bodyW - 12, LINE_HEIGHT)
        if lbl.style then
            lbl.style:SetAlign(ALIGN.LEFT)
            lbl.style:SetShadow(true)
        end
        lbl:SetText("")
        lbl:Show(false)
        -- Labels sit on top of the body; give them the wheel handler too so
        -- wheeling over text is captured instead of falling through to the game.
        lbl:EnableDrag(true)
        lbl:SetHandler("OnMouseWheel", WheelScroll)
        bodyRows[i] = lbl
    end

    -- Up / Down arrow buttons (top-right and bottom-right corners)
    local btnUp = histBody:CreateChildWidget("button", "CLBodyUp", 0, true)
    btnUp:SetExtent(20, 28)
    btnUp:AddAnchor("TOPRIGHT", histBody, -2, -2)
    btnUp:SetText("^")
    btnUp:SetHandler("OnClick", function() ScrollBody(3) end)

    local btnDown = histBody:CreateChildWidget("button", "CLBodyDn", 0, true)
    btnDown:SetExtent(20, 28)
    btnDown:AddAnchor("BOTTOMRIGHT", histBody, -2, -2)
    btnDown:SetText("v")
    btnDown:SetHandler("OnClick", function() ScrollBody(-3) end)
end

-- ============================================================================
-- FOOTER
-- ============================================================================
local function CreateFooter()
    local footer = wHistory:CreateChildWidget(
        "emptywidget", "CLHistFooter", 0, true)
    footer:AddAnchor("BOTTOMLEFT", wHistory, 0, 0)
    footer:AddAnchor("BOTTOMRIGHT", wHistory, 0, 0)
    footer:SetHeight(CONFIG.FOOTER_H)
    CreateBackdrop(footer, CONFIG.COL_FOOTER)

    deleteTextbox = W_CTRL.CreateEdit("CLDelEdit", footer)
    deleteTextbox:SetExtent(120, 20)
    deleteTextbox:AddAnchor("LEFT", footer, 8, 0)

    -- Backdrop behind the textbox used for the red-flash feedback
    deleteTextboxBg = deleteTextbox:CreateColorDrawable(
        CONFIG.COL_EDIT_BG[1], CONFIG.COL_EDIT_BG[2],
        CONFIG.COL_EDIT_BG[3], CONFIG.COL_EDIT_BG[4], "background")
    deleteTextboxBg:AddAnchor("TOPLEFT", deleteTextbox, 0, 0)
    deleteTextboxBg:AddAnchor("BOTTOMRIGHT", deleteTextbox, 0, 0)

    local btnClear = footer:CreateChildWidget(
        "button", "CLClearBtn", 0, true)
    btnClear:SetExtent(110, 22)
    btnClear:AddAnchor("LEFT", deleteTextbox, "RIGHT", 6, 0)
    btnClear:SetText("Clear History")
    btnClear:SetHandler("OnClick", function()
        -- GetText() is the standard method; if it errors, try :GetInputText()
        local input = deleteTextbox:GetText()
        if input == "DELETE" then
            -- Clear the currently-active view only
            if activeTab == "whispers" then
                conversations  = {}
                senderOrder    = {}
                selectedSender = nil
                RebuildSidebar()
                SaveData()
            else
                channels[activeTab] = { messages = {}, unreadCount = 0 }
                channelsDirty = true
                channelDirty[activeTab] = true  -- chunk save resets this channel to 0 chunks
                SaveChannels()
            end
            bodyOffset    = 0
            sidebarOffset = 0
            RecomputeTotalUnread()
            UpdateIndicator()
            UpdateTabBar()
            UpdateWarning()
            RebuildActiveView()
            deleteTextbox:SetText("")
        else
            -- Flash red
            deleteTextboxBg:SetColor(
                CONFIG.COL_RED_FLASH[1], CONFIG.COL_RED_FLASH[2],
                CONFIG.COL_RED_FLASH[3], CONFIG.COL_RED_FLASH[4])
            api:DoIn(800, function()
                deleteTextboxBg:SetColor(
                    CONFIG.COL_EDIT_BG[1], CONFIG.COL_EDIT_BG[2],
                    CONFIG.COL_EDIT_BG[3], CONFIG.COL_EDIT_BG[4])
            end)
        end
    end)

    local hint = footer:CreateChildWidget("label", "CLDelHint", 0, true)
    hint:SetText("type DELETE to confirm (clears the active tab)")
    hint:AddAnchor("LEFT", btnClear, "RIGHT", 8, 0)
    hint:SetExtent(260, CONFIG.FOOTER_H)
    if hint.style then
        hint.style:SetAlign(ALIGN.LEFT)
        hint.style:SetColor(0.4, 0.4, 0.4, 1)
    end
    -- Timezone control moved to the Options page.
end

-- ============================================================================
-- EXPORT
-- ============================================================================
local function ShowFeedback(text, isError)
    if not histFeedbackLabel then return end
    histFeedbackLabel:SetText(text)
    if histFeedbackLabel.style then
        if isError then
            histFeedbackLabel.style:SetColor(1, 0.4, 0.4, 1)
        else
            histFeedbackLabel.style:SetColor(0, 1, 0.5, 1)
        end
    end
    histFeedbackLabel:Show(true)
    api:DoIn(2500, function()
        if histFeedbackLabel then histFeedbackLabel:Show(false) end
    end)
end

-- Export is written in bounded pieces (one file per EXPORT_CHUNK entries) so a
-- large history is never serialized in a single write — that all-at-once write
-- is what crashes the 32-bit client at high message counts.
local EXPORT_CHUNK = 1000
DoExport = function()
    if next(conversations) == nil and TotalChannelLines() == 0 then
        ShowFeedback("Nothing to export", true)
        return
    end

    local stamp = MakeDateString()
    local seq, buf = 0, {}
    local writeOk = true
    local function flush()
        if #buf == 0 then return end
        seq = seq + 1
        local ok = pcall(api.File.Write, api.File,
            "ChatLogs/export_" .. stamp .. "_" .. seq .. ".lua",
            { exported = stamp, part = seq, entries = buf })
        if not ok then writeOk = false end
        buf = {}
    end

    for _, name in ipairs(senderOrder) do
        local conv = conversations[name]
        if conv then
            for _, m in ipairs(conv.messages) do
                buf[#buf + 1] = { kind = "whisper", who = name,
                    time = m.timeStr or "--:--", text = m.text, sent = m.sent or false }
                if #buf >= EXPORT_CHUNK then flush() end
            end
        end
    end
    for _, key in ipairs(CHANNEL_ORDER) do
        for _, m in ipairs(channels[key].messages) do
            buf[#buf + 1] = { kind = "channel", channel = key, speaker = m.speaker,
                time = m.timeStr or "--:--", text = m.text }
            if #buf >= EXPORT_CHUNK then flush() end
        end
    end
    flush()

    if writeOk then
        ShowFeedback("Exported " .. seq .. " file(s)", false)
    else
        ShowFeedback("Export error", true)
    end
end

local addon = {
    name    = "ChatLogs",
    author  = "Cydaphex",
    version = "1.3.1",
    desc    = "Whisper + channel chat logging with notifications and history."
}

function addon.OnLoad()
    LoadData()
    LoadChannels()
    InitTime()
    InitCanvas()
    CreateButton()
    CreateIndicator()
    CreateHistoryWindow()
    CreateSidebar()
    CreateBody()
    CreateFooter()
    RecomputeTotalUnread()
    RebuildSidebar()
    RebuildActiveView()
    UpdateTabBar()
    UpdateWarning()
    UpdateIndicator()
    api.Log:Info("[ChatLogs] Loaded. Senders: " .. #senderOrder
        .. " Channels: " .. TotalChannelLines())
end

function addon.OnUnload()
    SaveData()
    SaveChannels()
    local function safeHide(w) if w then w:Show(false) end end
    safeHide(canvas)
    safeHide(wButton)
    safeHide(wIndicator)
    safeHide(wHistory)
    canvas      = nil
    wButton     = nil
    wIndicator  = nil
    wHistory    = nil
    histSidebar = nil
    histBody    = nil
    sidebarRows = {}
    bodyRows    = {}
    tabButtons  = {}
end

return addon
