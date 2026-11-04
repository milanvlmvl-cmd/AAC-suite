-- PlayerDB Main Module
-- Hosts the features (players, houses, regrades, forsale, inventory, demoocr). One hidden event window registers every event and
-- calls the features directly; switched-off features ignore them. The addon manager's settings button
-- opens a window to switch features on and off.
local api = require("api")
local addoninfo = require("PlayerDB/addoninfo")
local clock = require("PlayerDB/clock")
local settings = require("PlayerDB/settings")
local settingswindow = require("PlayerDB/settingswindow")

local PlayerDB = {
	name = "PlayerDB",
	author = "Madpeter",
	version = "2.7.1",
	desc = "Logs players, houses, regrades, inventory"
}
-- stamped on every logged entry as addon_version
addoninfo.version = PlayerDB.version

local players = require("PlayerDB/features/players/feature")
local houses = require("PlayerDB/features/houses/feature")
local regrades = require("PlayerDB/features/regrades/feature")
local forsale = require("PlayerDB/features/forsale/feature")
local inventory = require("PlayerDB/features/inventory/feature")
local demoocr = require("PlayerDB/features/demoocr/feature")

-- for the settings window, reset and startup line
local FEATURES = { players, houses, regrades, forsale, inventory, demoocr }

-- house sale events, all passed to the ForSale feature as they come
local HOUSE_SALE_EVENTS = {
	HOUSE_SALE_SUCCESS = true,
	HOUSE_SET_SELL_SUCCESS = true,
	HOUSE_SET_SELL_FAIL = true,
	HOUSE_CANCEL_SELL_SUCCESS = true,
	HOUSE_CANCEL_SELL_FAIL = true,
	HOUSE_BUY_SUCCESS = true,
	HOUSE_BUY_FAIL = true,
}

local function runSafe(fn)
	local ok, result = pcall(fn)
	if not ok then
		api.Log:Info("[PlayerDB] error: " .. tostring(result))
		return nil
	end
	return result
end

local function findFeature(featureId)
	for _, feature in ipairs(FEATURES) do
		if feature.id == featureId then
			return feature
		end
	end
	return nil
end

local function isEnabled(featureId)
	return settings.IsEnabled(featureId)
end

-- switches a feature on or off right away and remembers the choice
local function setEnabled(featureId, enable)
	local feature = findFeature(featureId)
	if feature == nil then
		return
	end
	runSafe(function()
		settings.SetEnabled(featureId, enable)
	end)
	if enable then
		runSafe(feature.Enable)
	else
		runSafe(feature.Disable)
	end
	api.Log:Info("[PlayerDB] " .. feature.label .. (enable and " on" or " off"))
end

-- empties every feature's logged data (Players, Houses, Regrades), from the settings window
local function resetData()
	local parts = {}
	for _, feature in ipairs(FEATURES) do
		local emptied = runSafe(feature.ResetData)
		parts[#parts + 1] = feature.label .. " " .. tostring(emptied or "failed")
	end
	api.Log:Info("[PlayerDB] Data reset, files emptied: " .. table.concat(parts, ", "))
end

local function startupLine()
	local parts = {}
	for _, feature in ipairs(FEATURES) do
		local text = feature.label .. (isEnabled(feature.id) and " on" or " off")
		if isEnabled(feature.id) and feature.StartupInfo ~= nil then
			local info = runSafe(feature.StartupInfo)
			if info ~= nil then
				text = text .. " (" .. info .. ")"
			end
		end
		parts[#parts + 1] = text
	end
	return "[" .. PlayerDB.name .. "] Starting version " .. PlayerDB.version .. ": " .. table.concat(parts, ", ")
end

-- Addon initialization
local function OnLoad()
	api.Log:Info(startupLine())
	-- keeps clock.lua running between the game's coarse time steps (as WorldSatNav does)
	api.On("UPDATE", function(dt)
		clock.Advance(dt)
	end)
	-- hidden window, only used to receive game events
	PlayerDB.eventWindow = api.Interface:CreateEmptyWindow("PlayerDBEvents")
	PlayerDB.eventWindow:Show(false)
	-- attach events; each feature call is guarded on its own so one failing can't stop another
	function PlayerDB:EventListener(event, ...)
		if event == "TARGET_CHANGED" then
			runSafe(players.OnTargetChanged)
			runSafe(houses.OnTargetChanged)
		elseif event == "TEAM_MEMBERS_CHANGED" then
			runSafe(players.OnTeamMembersChanged)
		elseif event == "GRADE_ENCHANT_BROADCAST" then
			local characterName, resultCode, itemLink, oldGrade, newGrade = ...
			runSafe(function()
				regrades.OnGradeEnchantBroadcast(characterName, resultCode, itemLink, oldGrade, newGrade)
			end)
		elseif event == "GRADE_ENCHANT_RESULT" then
			local resultCode, itemLink, oldGrade, newGrade = ...
			runSafe(function()
				regrades.OnGradeEnchantResult(resultCode, itemLink, oldGrade, newGrade)
			end)
		elseif HOUSE_SALE_EVENTS[event] then
			local a1, a2, a3, a4, a5, a6, a7, a8 = ...
			runSafe(function()
				forsale.OnHouseEvent(event, a1, a2, a3, a4, a5, a6, a7, a8)
			end)
		end
	end
	PlayerDB.eventWindow:SetHandler("OnEvent", PlayerDB.EventListener)
	PlayerDB.eventWindow:RegisterEvent("TARGET_CHANGED")
	PlayerDB.eventWindow:RegisterEvent("TEAM_MEMBERS_CHANGED")
	PlayerDB.eventWindow:RegisterEvent("GRADE_ENCHANT_BROADCAST")
	PlayerDB.eventWindow:RegisterEvent("GRADE_ENCHANT_RESULT")
	PlayerDB.eventWindow:RegisterEvent("HOUSE_SALE_SUCCESS")
	PlayerDB.eventWindow:RegisterEvent("HOUSE_SET_SELL_SUCCESS")
	PlayerDB.eventWindow:RegisterEvent("HOUSE_SET_SELL_FAIL")
	PlayerDB.eventWindow:RegisterEvent("HOUSE_CANCEL_SELL_SUCCESS")
	PlayerDB.eventWindow:RegisterEvent("HOUSE_CANCEL_SELL_FAIL")
	PlayerDB.eventWindow:RegisterEvent("HOUSE_BUY_SUCCESS")
	PlayerDB.eventWindow:RegisterEvent("HOUSE_BUY_FAIL")

	for _, feature in ipairs(FEATURES) do
		if isEnabled(feature.id) then
			runSafe(feature.Enable)
		end
	end
end

-- Addon cleanup
local function OnUnload()
	-- unhook the clock (WorldSatNav unregisters UPDATE the same way)
	api.On("UPDATE", function() return end)
	for _, feature in ipairs(FEATURES) do
		runSafe(feature.Disable)
	end
	runSafe(settingswindow.Free)
	-- Unregister events
	if PlayerDB.eventWindow ~= nil then
		PlayerDB.eventWindow:ReleaseHandler("OnEvent")
		api.Interface:Free(PlayerDB.eventWindow)
		PlayerDB.eventWindow = nil
	end
end

local function OnSettingToggle()
	runSafe(function()
		settingswindow.Open(FEATURES, isEnabled, setEnabled, resetData)
	end)
end

PlayerDB.OnSettingToggle = OnSettingToggle

PlayerDB.OnLoad = OnLoad
PlayerDB.OnUnload = OnUnload

return PlayerDB
