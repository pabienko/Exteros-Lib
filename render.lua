--- Render object cleanup.
--- Stages: control.

local M = {}

--- Destroy `obj_or_table`: a single `LuaRenderObject`, or a table holding
--- (possibly nested) `LuaRenderObject`s, e.g. `{ rectangle = ..., text =
--- ... }` or an array. Invalid render objects and nil entries are skipped.
---@param obj_or_table LuaRenderObject|table|nil
---@return nil
function M.destroy(obj_or_table)
  if obj_or_table == nil then
    return
  end
  if obj_or_table.object_name == "LuaRenderObject" then
    if obj_or_table.valid then
      obj_or_table.destroy()
    end
    return
  end
  for _, value in pairs(obj_or_table) do
    M.destroy(value)
  end
end

return M
