local api = require("api")

-- Finds where a targeted building really is, since UnitWorldPosition gives nothing for buildings.
--
-- GetUnitScreenPosition("target") does work for buildings and gives screen x, y and a depth.
-- X2Util:ConvertWorldToScreen goes the other way (world -> screen x, y, camera distance), but its
-- screen y is junk for points off screen (clamped to 360), and a building's anchor is usually
-- above the top of the screen. So it is only used on screen, to build a camera model:
--   * four on-screen points are solved back to world rays; they start at the camera
--   * those rays give the screen -> direction mapping (a homography), which also works off screen
--   * the player calibrates the depth: GetUnitScreenPosition's depth reads about 1m more than the
--     real camera distance, so the offset that puts the player's ray on the player is measured
-- The building is then: camera + direction(screen x, y) * (depth - offset).
local locate = {}

-- world units (metres)
local NEWTON_STEP = 0.25
local MAX_NEWTON_STEP = 5
local NEWTON_ITERATIONS = 40
-- pixels / world units the solve must reach
local SCREEN_TOLERANCE = 0.3
local DEPTH_TOLERANCE = 0.05
-- screen offsets from the player of the four reference points used to build the camera model
local REFERENCE_OFFSETS = { { -250, -250 }, { 250, -250 }, { -250, 100 }, { 250, 100 } }
-- camera distances of the two points that make a reference ray
local NEAR_DEPTH = 10
local FAR_DEPTH = 20
-- reference rays must start this close to each other (they all start at the camera)
local MAX_CAMERA_SPREAD = 0.3
-- player check: the player's ray must pass this close to the player's x, y
local MAX_PLAYER_MISS = 0.5
-- the depth offset found from the player must be within this (it has been about 1.07)
local MAX_DEPTH_OFFSET = 3
-- good samples needed, all within SPREAD of their average, before the position is used
local MIN_POINTS = 3
local MAX_POINT_SPREAD = 1.0
-- dev: heights above/below the player's feet projected for the calibration table
local CALIBRATION_HEIGHTS = { -3, -2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2, 2.5, 3, 5, 10, 20, 40 }
-- dev: sideways offsets, to see what ConvertWorldToScreen returns behind the camera
local CALIBRATION_OFFSETS = { { 10, 0 }, { -10, 0 }, { 0, 10 }, { 0, -10 } }

-- ---------------------------------------------------------------------------
-- Small vector / matrix helpers
-- ---------------------------------------------------------------------------

local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local function length(a) return math.sqrt(dot(a, a)) end

local function horizontalDistance(a, b)
	local dx, dy = a[1] - b[1], a[2] - b[2]
	return math.sqrt(dx * dx + dy * dy)
end

local function det3(m)
	return m[1][1] * (m[2][2] * m[3][3] - m[2][3] * m[3][2])
		- m[1][2] * (m[2][1] * m[3][3] - m[2][3] * m[3][1])
		+ m[1][3] * (m[2][1] * m[3][2] - m[2][2] * m[3][1])
end

-- solves m * x = v (Cramer's rule); nil when singular
local function solve3(m, v)
	local det = det3(m)
	if math.abs(det) < 1e-12 then
		return nil
	end
	local out = {}
	for col = 1, 3 do
		local copy = {}
		for row = 1, 3 do
			copy[row] = { m[row][1], m[row][2], m[row][3] }
			copy[row][col] = v[row]
		end
		out[col] = det3(copy) / det
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Screen <-> world
-- ---------------------------------------------------------------------------

-- world point -> raw screen x, y, distance (distance is negative when off screen)
local function projectRaw(p)
	local ok, sx, sy, d = pcall(function()
		return X2Util:ConvertWorldToScreen(p[1], p[2], p[3])
	end)
	sx, sy, d = tonumber(sx), tonumber(sy), tonumber(d)
	if not ok or sx == nil or sy == nil or d == nil then
		return nil
	end
	return { sx, sy, d }
end

-- same, with distance made positive so off-screen points (building tops above the screen) still solve
local function project(p)
	local raw = projectRaw(p)
	if raw == nil then
		return nil
	end
	return { raw[1], raw[2], math.abs(raw[3]) }
end

local function unitScreen(unit)
	local ok, x, y, d = pcall(function()
		return api.Unit:GetUnitScreenPosition(unit)
	end)
	x, y, d = tonumber(x), tonumber(y), tonumber(d)
	if not ok or x == nil or y == nil or d == nil then
		return nil
	end
	return { x, y, d }
end

local function unitWorld(unit)
	local ok, x, y, z = pcall(function()
		return api.Unit:UnitWorldPosition(unit)
	end)
	x, y, z = tonumber(x), tonumber(y), tonumber(z)
	if not ok or x == nil or y == nil or z == nil then
		return nil
	end
	return { x, y, z }
end

-- world point that shows at screen (sx, sy) at camera distance depth (Newton on ConvertWorldToScreen)
local function unproject(screen, start)
	local p = { start[1], start[2], start[3] }
	for _ = 1, NEWTON_ITERATIONS do
		local f = project(p)
		if f == nil then
			return nil
		end
		local e = { f[1] - screen[1], f[2] - screen[2], f[3] - screen[3] }
		if math.abs(e[1]) < SCREEN_TOLERANCE and math.abs(e[2]) < SCREEN_TOLERANCE
			and math.abs(e[3]) < DEPTH_TOLERANCE then
			return p
		end
		local jacobian = { {}, {}, {} }
		for axis = 1, 3 do
			local moved = { p[1], p[2], p[3] }
			moved[axis] = moved[axis] + NEWTON_STEP
			local fm = project(moved)
			if fm == nil then
				return nil
			end
			for row = 1, 3 do
				jacobian[row][axis] = (fm[row] - f[row]) / NEWTON_STEP
			end
		end
		local delta = solve3(jacobian, e)
		if delta == nil then
			return nil
		end
		local len = length(delta)
		if len > MAX_NEWTON_STEP then
			local scale = MAX_NEWTON_STEP / len
			delta = { delta[1] * scale, delta[2] * scale, delta[3] * scale }
		end
		p = sub(p, delta)
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Dev output
-- ---------------------------------------------------------------------------

local function round(value)
	if type(value) ~= "number" then
		return value
	end
	return string.format("%.3f", value)
end

local function roundList(list)
	if list == nil then
		return "<nil>"
	end
	local out = {}
	for i, value in ipairs(list) do
		out[i] = round(value)
	end
	return out
end

local function projectedText(p)
	local raw = projectRaw(p)
	if raw == nil then
		return "<nil>"
	end
	return table.concat(roundList(raw), ", ")
end

-- what ConvertWorldToScreen gives above/below/around the player, to compare with GetUnitScreenPosition
local function calibration(player)
	local rows = {}
	for _, dz in ipairs(CALIBRATION_HEIGHTS) do
		rows[#rows + 1] = "dz " .. dz .. ": " .. projectedText({ player[1], player[2], player[3] + dz })
	end
	for _, offset in ipairs(CALIBRATION_OFFSETS) do
		local p = { player[1] + offset[1], player[2] + offset[2], player[3] }
		rows[#rows + 1] = "dx " .. offset[1] .. " dy " .. offset[2] .. ": " .. projectedText(p)
	end
	return rows
end

-- ---------------------------------------------------------------------------
-- Camera model
-- ---------------------------------------------------------------------------

local function scale(a, k) return { a[1] * k, a[2] * k, a[3] * k } end
local function add(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end

local function normalize(a)
	local len = length(a)
	if len < 1e-9 then
		return nil
	end
	return scale(a, 1 / len)
end

-- 3x3 matrix whose columns are the given vectors
local function columns(c1, c2, c3)
	return {
		{ c1[1], c2[1], c3[1] },
		{ c1[2], c2[2], c3[2] },
		{ c1[3], c2[3], c3[3] },
	}
end

local function multiply(m, v)
	return {
		m[1][1] * v[1] + m[1][2] * v[2] + m[1][3] * v[3],
		m[2][1] * v[1] + m[2][2] * v[2] + m[2][3] * v[3],
		m[3][1] * v[1] + m[3][2] * v[2] + m[3][3] * v[3],
	}
end

-- Builds the camera from four on-screen reference points around the player's screen position.
-- Returns { position, screenBasis, worldBasis, forward }, or nil and a reason.
local function buildCamera(playerScreen, player)
	local screens, dirs, origins = {}, {}, {}
	for i, offset in ipairs(REFERENCE_OFFSETS) do
		local sx, sy = playerScreen[1] + offset[1], playerScreen[2] + offset[2]
		local near = unproject({ sx, sy, NEAR_DEPTH }, player)
		local far = near and unproject({ sx, sy, FAR_DEPTH }, near)
		local dir = far and normalize(sub(far, near))
		if dir == nil then
			return nil, "reference point " .. i .. " could not be solved"
		end
		screens[i] = { sx, sy, 1 }
		dirs[i] = dir
		origins[i] = sub(near, scale(dir, NEAR_DEPTH))
	end
	local position = scale(add(add(origins[1], origins[2]), add(origins[3], origins[4])), 0.25)
	for _, origin in ipairs(origins) do
		if length(sub(origin, position)) > MAX_CAMERA_SPREAD then
			return nil, "reference rays do not start at one camera point"
		end
	end
	-- 4-point homography from screen (x, y, 1) to world direction:
	-- direction(s) = worldBasis * solve(screenBasis, s)
	local mu = solve3(columns(screens[1], screens[2], screens[3]), screens[4])
	local lambda = solve3(columns(dirs[1], dirs[2], dirs[3]), dirs[4])
	if mu == nil or lambda == nil then
		return nil, "reference points are degenerate"
	end
	return {
		position = position,
		screenBasis = columns(scale(screens[1], mu[1]), scale(screens[2], mu[2]), scale(screens[3], mu[3])),
		worldBasis = columns(scale(dirs[1], lambda[1]), scale(dirs[2], lambda[2]), scale(dirs[3], lambda[3])),
		forward = normalize(add(add(dirs[1], dirs[2]), add(dirs[3], dirs[4]))),
	}
end

-- unit world direction the camera looks along for screen point (sx, sy), on or off screen
local function cameraDirection(camera, sx, sy)
	local a = solve3(camera.screenBasis, { sx, sy, 1 })
	if a == nil then
		return nil
	end
	local dir = normalize(multiply(camera.worldBasis, a))
	if dir ~= nil and dot(dir, camera.forward) < 0 then
		dir = scale(dir, -1)
	end
	return dir
end

-- ---------------------------------------------------------------------------
-- Session: one per targeted building
-- ---------------------------------------------------------------------------

function locate.NewSession()
	return { points = {}, samples = {}, count = 0 }
end

local function averagePoint(points)
	local sum = { 0, 0, 0 }
	for _, p in ipairs(points) do
		sum = { sum[1] + p[1], sum[2] + p[2], sum[3] + p[3] }
	end
	return { sum[1] / #points, sum[2] / #points, sum[3] / #points }
end

-- Takes one sample. Returns world x, y, z of the building once enough samples agree, else nil.
-- The second return value is a table describing this sample, for the dev dump.
function locate.Sample(session)
	session.count = session.count + 1
	local info = {}
	local player = unitWorld("player")
	local target = unitScreen("target")
	local playerScreen = unitScreen("player")
	info.playerWorld = roundList(player)
	info.targetScreen = roundList(target)
	info.playerScreen = roundList(playerScreen)
	if player == nil or target == nil or playerScreen == nil then
		info.result = "missing player world, target screen or player screen position"
		return nil, info
	end
	-- the full table on the first sample and then now and again
	if session.count % 10 == 1 then
		info.calibration = calibration(player)
	end

	local camera, reason = buildCamera(playerScreen, player)
	if camera == nil then
		info.result = "no camera model: " .. reason
		return nil, info
	end
	info.camera = roundList(camera.position)

	-- depth calibration: how far along the player's ray the player really is
	local playerDir = cameraDirection(camera, playerScreen[1], playerScreen[2])
	local flat = playerDir and (playerDir[1] * playerDir[1] + playerDir[2] * playerDir[2]) or 0
	if flat < 1e-6 then
		info.result = "player ray is vertical, cannot calibrate depth"
		return nil, info
	end
	local along = ((player[1] - camera.position[1]) * playerDir[1]
		+ (player[2] - camera.position[2]) * playerDir[2]) / flat
	local playerPoint = add(camera.position, scale(playerDir, along))
	local playerMiss = horizontalDistance(playerPoint, player)
	local depthOffset = playerScreen[3] - along
	info.playerMiss = round(playerMiss)
	info.playerAnchorHeight = round(playerPoint[3] - player[3])
	info.depthOffset = round(depthOffset)
	info.depthScale = round(playerScreen[3] / along)

	local targetDir = cameraDirection(camera, target[1], target[2])
	if targetDir == nil then
		info.result = "no direction for the target's screen position"
		return nil, info
	end
	local point = add(camera.position, scale(targetDir, target[3] - depthOffset))
	info.targetSolved = roundList(point)
	info.targetOffset = roundList({ point[1] - player[1], point[2] - player[2], point[3] - player[3] })
	local okDistance, distance = pcall(function() return api.Unit:UnitDistance("target") end)
	info.targetDistance = okDistance and round(tonumber(distance)) or "<nil>"

	if playerMiss > MAX_PLAYER_MISS then
		info.result = "player check failed (miss " .. round(playerMiss) .. "m), not trusted"
		return nil, info
	end
	if math.abs(depthOffset) > MAX_DEPTH_OFFSET then
		info.result = "depth offset " .. round(depthOffset) .. " out of range, not trusted"
		return nil, info
	end
	session.points[#session.points + 1] = point
	if #session.points < MIN_POINTS then
		info.result = "need more samples (" .. #session.points .. "/" .. MIN_POINTS .. ")"
		return nil, info
	end
	-- the last MIN_POINTS samples must agree
	local recent = {}
	for i = #session.points - MIN_POINTS + 1, #session.points do
		recent[#recent + 1] = session.points[i]
	end
	local average = averagePoint(recent)
	for _, p in ipairs(recent) do
		local spread = horizontalDistance(p, average)
		if spread > MAX_POINT_SPREAD then
			info.result = "samples disagree by " .. round(spread) .. "m"
			return nil, info
		end
	end
	info.result = "located"
	return average, info
end

return locate
