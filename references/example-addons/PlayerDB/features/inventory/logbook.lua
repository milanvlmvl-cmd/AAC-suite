local api = require("api")
local addoninfo = require("PlayerDB/addoninfo")
local datafiles = require("PlayerDB/datafiles")
local clock = require("PlayerDB/clock")

-- Inventory: a snapshot of what the character carries, one file per character in PlayerDB/Inventory/.
-- Slots holding the same item are merged by name with the amounts added up: items["name"] = amount.
local logbook = {}

local INVENTORY_DIR = "PlayerDB/Inventory/"
-- api.Bag:GetBagItemInfo(bagType, slot): 1 is the inventory (api.lua)
local BAG_TYPE_INVENTORY = 1

local function safeCall(fn)
	local ok, result = pcall(fn)
	if not ok then
		return nil
	end
	return result
end

-- Reads every bag slot into { [name] = amount, ... } and returns it with the number of different items.
local function readInventory()
	local capacity = tonumber(safeCall(function() return api.Bag:Capacity() end)) or 0
	local items = {}
	local count = 0
	for slot = 1, capacity do
		local info = safeCall(function() return api.Bag:GetBagItemInfo(BAG_TYPE_INVENTORY, slot) end)
		if type(info) == "table" and info.name ~= nil then
			local name = tostring(info.name)
			if items[name] == nil then
				items[name] = 0
				count = count + 1
			end
			items[name] = items[name] + (tonumber(info.stack) or 1)
		end
	end
	return items, count
end

local function characterName()
	local name = safeCall(function() return api.Unit:UnitName("player") end)
	if type(name) ~= "string" or name == "" then
		return "unknown"
	end
	return name
end

-- the character name as a file name
local function characterPath(name)
	return INVENTORY_DIR .. string.gsub(string.lower(name), "[^%w]", "_") .. ".dat"
end

-- Reads the inventory and saves the merged list. Returns a summary { items } for the icon tooltip.
function logbook.Scan()
	local name = characterName()
	local items, count = readInventory()
	datafiles.Write(INVENTORY_DIR, characterPath(name), {
		character = name,
		time = clock.NowText(),
		addon_version = addoninfo.version,
		item_count = count,
		items = items,
	})
	return { items = count }
end

-- Empties the inventory files. Returns how many files were emptied.
function logbook.ResetData()
	return datafiles.Reset(INVENTORY_DIR)
end

return logbook
