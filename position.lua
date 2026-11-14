--- Position and vector helpers. Every function accepts both the explicit
--- `{x=, y=}` shape and the positional `{a, b}` shape on input, and always
--- returns the explicit shape in a new table.
--- Stages: any.

local M = {}

---@class ExterosLibPosition
---@field x number
---@field y number

--- Normalize `position` (or any `{x=,y=}`/`{a,b}` vector) to the explicit
--- `{x=,y=}` shape. Missing components default to 0. Never mutates the
--- input.
---@param position MapPosition
---@return ExterosLibPosition
function M.ensure_explicit(position)
  local x = position.x or position[1] or 0
  local y = position.y or position[2] or 0
  return { x = x, y = y }
end

--- Euclidean distance between `a` and `b`.
---@param a MapPosition
---@param b MapPosition
---@return number
function M.distance(a, b)
  return math.sqrt(M.distance_sq(a, b))
end

--- Squared Euclidean distance between `a` and `b`. Use this instead of
--- `distance` when only comparing distances, to skip the square root.
---@param a MapPosition
---@param b MapPosition
---@return number
function M.distance_sq(a, b)
  local ea = M.ensure_explicit(a)
  local eb = M.ensure_explicit(b)
  local dx = ea.x - eb.x
  local dy = ea.y - eb.y
  return dx * dx + dy * dy
end

--- Chebyshev (chessboard) distance between `a` and `b`: the larger of the
--- two axis-aligned differences.
---@param a MapPosition
---@param b MapPosition
---@return number
function M.chebyshev(a, b)
  local ea = M.ensure_explicit(a)
  local eb = M.ensure_explicit(b)
  return math.max(math.abs(ea.x - eb.x), math.abs(ea.y - eb.y))
end

--- Mirror `vec` across the horizontal and/or vertical axis: negate `x` when
--- `horizontal` is true, negate `y` when `vertical` is true.
---@param vec MapPosition
---@param horizontal boolean?
---@param vertical boolean?
---@return ExterosLibPosition
function M.flip(vec, horizontal, vertical)
  local explicit = M.ensure_explicit(vec)
  local x, y = explicit.x, explicit.y
  if horizontal then x = -x end
  if vertical then y = -y end
  return { x = x, y = y }
end

return M
