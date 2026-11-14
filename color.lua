--- Color helpers.
--- Stages: any.

local M = {}

--- Pure red. Read-only.
---@type Color
M.RED = { r = 1, g = 0, b = 0 }

--- Pure white. Read-only.
---@type Color
M.WHITE = { r = 1, g = 1, b = 1 }

--- Pure yellow. Read-only.
---@type Color
M.YELLOW = { r = 1, g = 1, b = 0 }

--- Pure green. Read-only.
---@type Color
M.GREEN = { r = 0, g = 1, b = 0 }

--- Pure blue. Read-only.
---@type Color
M.BLUE = { r = 0, g = 0, b = 1 }

--- Parse a `#rrggbb` or `#rrggbbaa` hex string (leading `#` optional) into a
--- `Color` with components in `[0, 1]`. Returns `default` unchanged if `hex`
--- is not a string or does not match either format.
---@param hex string?
---@param default Color
---@return Color
function M.parse_hex(hex, default)
  if type(hex) ~= "string" then return default end

  local clean = hex:match("^#?(%x%x%x%x%x%x%x%x)$") or hex:match("^#?(%x%x%x%x%x%x)$")
  if not clean then return default end

  local r = tonumber(clean:sub(1, 2), 16)
  local g = tonumber(clean:sub(3, 4), 16)
  local b = tonumber(clean:sub(5, 6), 16)
  local a = #clean == 8 and tonumber(clean:sub(7, 8), 16) or 255

  if not r or not g or not b or not a then return default end

  return { r = r / 255, g = g / 255, b = b / 255, a = a / 255 }
end

return M
