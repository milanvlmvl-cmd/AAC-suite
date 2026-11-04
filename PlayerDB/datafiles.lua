local api = require("api")

-- Writes logged data files and remembers which ones exist, so they can be reset later:
-- the addon api can't list or delete files, so each data folder keeps an index (_files.dat)
-- of the files written to it. Reset empties every indexed file.
local datafiles = {}

local INDEX_NAME = "_files.dat"

-- folder -> { paths = list, known = set }, loaded from the index on first use
local indexes = {}

local function loadIndex(dir)
	local index = indexes[dir]
	if index ~= nil then
		return index
	end
	index = { paths = {}, known = {} }
	local saved = api.File:Read(dir .. INDEX_NAME)
	if type(saved) == "table" then
		for _, path in ipairs(saved) do
			if type(path) == "string" and not index.known[path] then
				index.known[path] = true
				index.paths[#index.paths + 1] = path
			end
		end
	end
	indexes[dir] = index
	return index
end

-- Writes data to path (a file inside dir) and adds it to dir's index.
function datafiles.Write(dir, path, data)
	api.File:Write(path, data)
	local index = loadIndex(dir)
	if not index.known[path] then
		index.known[path] = true
		index.paths[#index.paths + 1] = path
		api.File:Write(dir .. INDEX_NAME, index.paths)
	end
end

-- Empties every file written to dir and clears its index. Returns how many files were emptied.
function datafiles.Reset(dir)
	local index = loadIndex(dir)
	for _, path in ipairs(index.paths) do
		api.File:Write(path, {})
	end
	local count = #index.paths
	indexes[dir] = { paths = {}, known = {} }
	api.File:Write(dir .. INDEX_NAME, {})
	return count
end

return datafiles
