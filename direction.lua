--- Direction and rotation helpers for Factorio's 16-way `defines.direction`
--- (north = 0, east = 4, south = 8, west = 12, with the eight intercardinal
--- values filling the gaps).
--- Stages: any.

local position = require("__exteros-lib__.position")

local M = {}

--- Unit vectors for the four cardinal directions.
---@type table<defines.direction, ExterosLibPosition>
M.VECTOR = {
  [defines.direction.north] = { x = 0, y = -1 },
  [defines.direction.east] = { x = 1, y = 0 },
  [defines.direction.south] = { x = 0, y = 1 },
  [defines.direction.west] = { x = -1, y = 0 },
}

--- The direction facing the opposite way (180°), on the full 16-way scale.
---@param direction defines.direction
---@return defines.direction
function M.opposite(direction)
  return ((direction + 8) % 16) --[[@as defines.direction]]
end

--- Rotate `vec` by whole quarter turns derived from `direction` (0 for
--- north, 1 for east, 2 for south, 3 for west).
---@param vec MapPosition
---@param direction defines.direction
---@return ExterosLibPosition
function M.rotate_vector(vec, direction)
  local explicit = position.ensure_explicit(vec)
  local quarter_turns = math.floor((direction or 0) / 4) % 4
  local x, y = explicit.x, explicit.y
  for _ = 1, quarter_turns do
    x, y = -y, x
  end
  return { x = x, y = y }
end

--- The cardinal direction (east/west/south/north) from `from_position`
--- towards `to_position`, picking the axis with the larger difference and
--- breaking ties (and a zero vector) towards east/south.
---@param from_position MapPosition
---@param to_position MapPosition
---@return defines.direction
function M.between(from_position, to_position)
  local from_explicit = position.ensure_explicit(from_position)
  local to_explicit = position.ensure_explicit(to_position)
  local dx = to_explicit.x - from_explicit.x
  local dy = to_explicit.y - from_explicit.y

  if math.abs(dx) >= math.abs(dy) then
    if dx >= 0 then return defines.direction.east end
    return defines.direction.west
  end

  if dy >= 0 then return defines.direction.south end
  return defines.direction.north
end

--- The 16-way `defines.direction` the vector `(dx, dy)` points to, in map
--- coordinates (x grows east, y grows south). To face something, pass
--- `target - source`. Returns nil for the zero vector.
---@param dx number
---@param dy number
---@return defines.direction?
function M.from_vector(dx, dy)
  if dx == 0 and dy == 0 then return nil end
  local orientation = math.atan2(dx, -dy) / (2 * math.pi)
  if orientation < 0 then orientation = orientation + 1 end
  return (math.floor(orientation * 16 + 0.5) % 16) --[[@as defines.direction]]
end

return M
