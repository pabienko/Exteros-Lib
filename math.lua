--- Small numeric helpers that plain Lua `math` does not provide.
--- Stages: any.

local M = {}

--- Clamp `value` into the closed range `[min, max]`.
---@param value number
---@param min number
---@param max number
---@return number
function M.clamp(value, min, max)
  if value < min then
    return min
  elseif value > max then
    return max
  else
    return value
  end
end

--- The largest integer a Lua double can represent without losing precision
--- (2^53 - 1). Use it as a safe upper bound for integer-like settings.
---@type integer
M.MAX_INT53 = 0x1FFFFFFFFFFFFF

--- Round `num` to the nearest multiple of `divisor` (default 1), rounding
--- half away from zero.
---@param num number
---@param divisor number?
---@return number
function M.round_to(num, divisor)
  divisor = divisor or 1
  if num >= 0 then
    return divisor * math.floor(num / divisor + 0.5)
  else
    return divisor * math.ceil(num / divisor - 0.5)
  end
end

return M
