--- Generic table helpers for maps and arrays. Named `M` (not `table`) so this
--- module can still call the global `table` library if it ever needs to.
--- Stages: any.

local M = {}

--- Build a new table with the same keys as `tbl`, each value replaced by
--- `fn(value, key)`.
---@generic K, V, R
---@param tbl table<K, V>
---@param fn fun(value: V, key: K): R
---@return table<K, R>
function M.map(tbl, fn)
  local out = {}
  for key, value in pairs(tbl) do
    out[key] = fn(value, key)
  end
  return out
end

--- The first key in `tbl` whose value equals `value` (iteration order is
--- `pairs` order, so for an array use `index_of` instead), or nil.
---@generic K, V
---@param tbl table<K, V>
---@param value V
---@return K?
function M.find(tbl, value)
  for key, candidate in pairs(tbl) do
    if candidate == value then
      return key
    end
  end
  return nil
end

--- Swap keys and values: `out[value] = key` for every pair in `tbl`. If two
--- keys share a value, the one visited last by `pairs` wins.
---@generic K, V
---@param tbl table<K, V>
---@return table<V, K>
function M.invert(tbl)
  local out = {}
  for key, value in pairs(tbl) do
    out[value] = key
  end
  return out
end

--- The first index in the array `list` whose value equals `value`
--- (`ipairs` order), or nil. The array variant of `find`.
---@generic V
---@param list V[]
---@param value V
---@return integer?
function M.index_of(list, value)
  for i, candidate in ipairs(list) do
    if candidate == value then
      return i
    end
  end
  return nil
end

--- Move through the array `list` starting at `index`, in steps of `step`
--- (positive or negative, any size), wrapping around both ends, and return
--- the first index/value pair that `accept(value, index)` allows — or, with
--- no `accept`, simply the index `step` slots away from `index`.
---
--- `index = nil` means "no current element": the scan starts just before the
--- first slot (`step > 0`) or just after the last slot (`step < 0`), so the
--- first candidate is `list[1]` or `list[#list]`. Use this to pick the
--- first/last match.
---
--- Visits at most `#list` candidates, so a never-matching `accept`, or an
--- empty `list`, returns nil, nil instead of looping forever.
---@generic V
---@param list V[]
---@param index integer?
---@param step integer
---@param accept (fun(value: V, index: integer): boolean)?
---@return integer?
---@return V?
function M.cycle(list, index, step, accept)
  local count = #list
  if count == 0 then
    return nil, nil
  end

  local base
  if index == nil then
    base = (step >= 0) and 0 or (count + 1)
  else
    base = index
  end

  for i = 1, count do
    local candidate = ((base - 1 + step * i) % count) + 1
    local value = list[candidate]
    if not accept or accept(value, candidate) then
      return candidate, value
    end
  end
  return nil, nil
end

return M
