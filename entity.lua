--- Entity validity and identity helpers, ghost-aware.
--- Stages: control.

local M = {}

--- Whether `entity` is usable right now: not nil and not invalidated.
---@param entity LuaEntity?
---@return boolean
function M.is_valid(entity)
  return entity ~= nil and entity.valid
end

--- `entity`'s type, following through an entity-ghost to the type it will
--- become on revive. For anything else, the same as `entity.type`.
---@param entity LuaEntity
---@return string
function M.effective_type(entity)
  if entity.type == "entity-ghost" then
    return entity.ghost_type
  end
  return entity.type
end

--- `entity`'s name, following through an entity-ghost to the name it will
--- become on revive. For anything else, the same as `entity.name`.
---@param entity LuaEntity
---@return string
function M.effective_name(entity)
  if entity.type == "entity-ghost" then
    return entity.ghost_name
  end
  return entity.name
end

--- `entity`'s `unit_number`. Only entities that can have one (most placed
--- entities, not e.g. resources) should be passed here.
---@param entity LuaEntity
---@return integer
function M.uid(entity)
  return entity.unit_number --[[@as integer]]
end

--- A string key identifying `entity`: its `unit_number` if it has one, else
--- a key built from its surface, force, name and position (for entities
--- without a `unit_number`, e.g. resources).
---@param entity LuaEntity
---@return string
function M.key(entity)
  local unit_number = entity.unit_number
  if unit_number then
    return "u/" .. unit_number
  end
  local position = entity.position
  return string.format("p/%d/%d/%s/%.3f/%.3f", entity.surface.index, entity.force.index, entity.name, position.x, position.y)
end

return M
