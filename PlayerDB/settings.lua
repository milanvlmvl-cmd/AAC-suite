local api = require("api")

-- PlayerDB's settings, kept in the game's addon_settings under "PlayerDB" (the same way WorldSatNav's
-- core/settings.lua does it): feature switches and status dot positions.
local settings = {}

local addonName = "PlayerDB"
local getSettings = api.GetSettings
local saveSettings = api.SaveSettings

local loaded = nil
local defaultSettings = {
	-- features
	PlayersEnabled = true,
	HousesEnabled = true,
	RegradesEnabled = true,
	ForSaleEnabled = true,
	-- off until switched on in the settings window
	InventoryEnabled = false,
	DemoOCREnabled = false,

	-- status dot positions
	PlayerDotsX = 400,
	PlayerDotsY = 400,
	HouseDotX = 400,
	HouseDotY = 420,
	RegradeDotX = 400,
	RegradeDotY = 440,
	InventoryIconX = 400,
	InventoryIconY = 460,
	DemoOCRIconX = 400,
	DemoOCRIconY = 500,
}

-- feature id -> setting key
local FEATURE_KEYS = {
	players = "PlayersEnabled",
	houses = "HousesEnabled",
	regrades = "RegradesEnabled",
	forsale = "ForSaleEnabled",
	inventory = "InventoryEnabled",
	demoocr = "DemoOCREnabled",
}

local function loadSettings()
	local loadedSettings = getSettings(addonName)
	if loadedSettings == nil then
		loadedSettings = {}
	end
	-- Fill in missing keys with defaults in memory only (as WorldSatNav does): if getSettings came
	-- back empty because of a load problem, saving here would overwrite the real settings.
	for key, value in pairs(defaultSettings) do
		if loadedSettings[key] == nil then
			loadedSettings[key] = value
		end
	end
	return loadedSettings
end

local function ensureLoaded()
	if loaded == nil then
		loaded = loadSettings()
	end
	return loaded
end

function settings.KeyExists(key)
	return key ~= nil and defaultSettings[key] ~= nil
end

function settings.Get(key)
	if not settings.KeyExists(key) then
		return nil
	end
	local current = ensureLoaded()
	if current[key] == nil then
		return defaultSettings[key]
	end
	return current[key]
end

function settings.Is(key, value)
	return settings.Get(key) == value
end

function settings.Update(key, value)
	if not settings.KeyExists(key) then
		return false
	end
	local current = ensureLoaded()
	local oldValue = current[key]
	current[key] = value
	if oldValue ~= value then
		saveSettings(addonName, current)
	end
	return true
end

-- feature switches, by feature id ("players", "houses", "regrades", "forsale", "inventory", "demoocr")
function settings.IsEnabled(featureId)
	return settings.Get(FEATURE_KEYS[featureId]) ~= false
end

function settings.SetEnabled(featureId, isEnabled)
	settings.Update(FEATURE_KEYS[featureId], isEnabled == true)
end

return settings
