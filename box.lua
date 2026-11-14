--- Bounding box helpers. Accepts both the explicit `{left_top=, right_bottom=}`
--- shape and the positional `{{..},{..}}` shape on input; always returns the
--- explicit shape in a new table.
--- Stages: any.

local position = require("__exteros-lib__.position")

local M = {}

---@class ExterosLibBox
---@field left_top ExterosLibPosition
---@field right_bottom ExterosLibPosition

--- Normalize `box` to the explicit `{left_top=,right_bottom=}` shape. Does
--- not mutate the input.
---@param box BoundingBox
---@return ExterosLibBox
function M.ensure_explicit(box)
  local left_top = box.left_top or box[1]
  local right_bottom = box.right_bottom or box[2]
  return {
    left_top = position.ensure_explicit(left_top),
    right_bottom = position.ensure_explicit(right_bottom),
  }
end

--- Grow (or, for a negative `amount`, shrink) `box` by `amount` on all four
--- sides.
---@param box BoundingBox
---@param amount number
---@return ExterosLibBox
function M.expand(box, amount)
  local explicit = M.ensure_explicit(box)
  return {
    left_top = { x = explicit.left_top.x - amount, y = explicit.left_top.y - amount },
    right_bottom = { x = explicit.right_bottom.x + amount, y = explicit.right_bottom.y + amount },
  }
end

--- Snap `box` outward to whole tile coordinates: floor `left_top`, ceil
--- `right_bottom`. Never makes the box smaller.
---@param box BoundingBox
---@return ExterosLibBox
function M.snap_outward(box)
  local explicit = M.ensure_explicit(box)
  return {
    left_top = { x = math.floor(explicit.left_top.x), y = math.floor(explicit.left_top.y) },
    right_bottom = { x = math.ceil(explicit.right_bottom.x), y = math.ceil(explicit.right_bottom.y) },
  }
end

--- A square box of `radius` around `position` (corners at `position ± radius`).
--- A zero radius gives a degenerate box equal to `position`.
---@param pos MapPosition
---@param radius number
---@return ExterosLibBox
function M.around(pos, radius)
  local explicit = position.ensure_explicit(pos)
  return {
    left_top = { x = explicit.x - radius, y = explicit.y - radius },
    right_bottom = { x = explicit.x + radius, y = explicit.y + radius },
  }
end

--- Whether boxes `a` and `b` overlap, touching edges counting as overlap.
---@param a BoundingBox
---@param b BoundingBox
---@return boolean
function M.intersects(a, b)
  local ea = M.ensure_explicit(a)
  local eb = M.ensure_explicit(b)
  return ea.left_top.x <= eb.right_bottom.x and ea.right_bottom.x >= eb.left_top.x
    and ea.left_top.y <= eb.right_bottom.y and ea.right_bottom.y >= eb.left_top.y
end

--- Whether `pos` lies inside `box`, including its edges.
---@param box BoundingBox
---@param pos MapPosition
---@return boolean
function M.contains(box, pos)
  local ebox = M.ensure_explicit(box)
  local epos = position.ensure_explicit(pos)
  return epos.x >= ebox.left_top.x and epos.x <= ebox.right_bottom.x
    and epos.y >= ebox.left_top.y and epos.y <= ebox.right_bottom.y
end

--- The smallest box containing every position in `points` (a non-empty
--- array; each entry accepts both position shapes).
---@param points MapPosition[]
---@return ExterosLibBox
function M.from_points(points)
  if #points == 0 then
    error("exteros-lib box: from_points requires at least one point", 2)
  end

  local min_x, min_y, max_x, max_y
  for _, point in ipairs(points) do
    local explicit = position.ensure_explicit(point)
    min_x = min_x and math.min(min_x, explicit.x) or explicit.x
    min_y = min_y and math.min(min_y, explicit.y) or explicit.y
    max_x = max_x and math.max(max_x, explicit.x) or explicit.x
    max_y = max_y and math.max(max_y, explicit.y) or explicit.y
  end

  return {
    left_top = { x = min_x, y = min_y },
    right_bottom = { x = max_x, y = max_y },
  }
end

--- The smallest box containing every box in `boxes` (a non-empty array).
---@param boxes BoundingBox[]
---@return ExterosLibBox
function M.union(boxes)
  if #boxes == 0 then
    error("exteros-lib box: union requires at least one box", 2)
  end

  local min_x, min_y, max_x, max_y
  for _, box in ipairs(boxes) do
    local explicit = M.ensure_explicit(box)
    min_x = min_x and math.min(min_x, explicit.left_top.x) or explicit.left_top.x
    min_y = min_y and math.min(min_y, explicit.left_top.y) or explicit.left_top.y
    max_x = max_x and math.max(max_x, explicit.right_bottom.x) or explicit.right_bottom.x
    max_y = max_y and math.max(max_y, explicit.right_bottom.y) or explicit.right_bottom.y
  end

  return {
    left_top = { x = min_x, y = min_y },
    right_bottom = { x = max_x, y = max_y },
  }
end

--- The tile size of `box` (snapped outward first): width and height in
--- tiles, each at least 1, and their product.
---@param box BoundingBox
---@return number width
---@return number height
---@return number tiles
function M.tile_size(box)
  local snapped = M.snap_outward(box)
  local width = math.max(1, snapped.right_bottom.x - snapped.left_top.x)
  local height = math.max(1, snapped.right_bottom.y - snapped.left_top.y)
  return width, height, width * height
end

return M
