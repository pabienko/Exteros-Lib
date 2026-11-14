--- Quality name and ordering helpers.
--- Stages: control.

local M = {}

---@type string
local HIDDEN_QUALITY = "quality-unknown"

---@type { name: string, level: uint }[]?
local sorted_cache = nil

--- The quality name of `obj` — a `LuaItemStack`, `LuaEntity`, or any table
--- with a `quality` field (a `LuaQualityPrototype` or a name string). Missing
--- quality (nil) means `"normal"`.
---@param obj { quality: (LuaQualityPrototype|string)? }
---@return string
function M.name_of(obj)
  local quality = obj.quality
  if quality == nil then
    return "normal"
  end
  if type(quality) == "string" then
    return quality
  end
  return quality.name
end

--- Every quality known to the game, ordered by level, excluding the hidden
--- `"quality-unknown"` entry. Cached at module level — do not mutate the
--- returned list.
---@return { name: string, level: uint }[]
function M.sorted()
  if sorted_cache then
    return sorted_cache
  end

  local qualities = {}
  for name, quality in pairs(prototypes.quality) do
    if name ~= HIDDEN_QUALITY then
      table.insert(qualities, { name = name, level = quality.level })
    end
  end
  table.sort(qualities, function(a, b) return a.level < b.level end)

  sorted_cache = qualities
  return sorted_cache
end

return M
