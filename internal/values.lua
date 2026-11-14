local manifest_lib = require("__exteros-lib__.internal.manifest")
local lib_storage = require("__exteros-lib__.storage")
local lib_player = require("__exteros-lib__.player")

local M = {}

M.FORMAT = 1

---@alias ExterosLibValuesScope "global"|"player"

---@class ExterosLibValuesChange
---@field scope ExterosLibValuesScope
---@field name string
---@field player_index integer?
---@field old boolean|number|string
---@field new boolean|number|string

---@type string?
local mod_name = nil
---@type table<string, { setting: ExterosLibSettingDef, scope: ExterosLibValuesScope }>?
local defs = nil
---@type { get: fun(): table, peek: fun(): table? }?
local global_ns = nil
---@type { get: fun(player: LuaPlayer|integer): table, peek: fun(player: LuaPlayer|integer): table? }?
local player_ns = nil
---@type fun(event: ExterosLibValuesChange)[]
local change_listeners = {}

---@return nil
local function check_ready()
  if defs == nil then
    error("exteros-lib values: setup() has not been called yet", 3)
  end
end

---@param name string
---@param scope ExterosLibValuesScope
---@return { setting: ExterosLibSettingDef, scope: ExterosLibValuesScope }
local function lookup(name, scope)
  check_ready()
  local def = defs[name]
  if def == nil then
    error("exteros-lib values (" .. mod_name .. "): unknown setting '" .. tostring(name) .. "'", 3)
  end
  if def.scope ~= scope then
    error("exteros-lib values (" .. mod_name .. "): '" .. name .. "' is a " .. def.scope .. " setting, not " .. scope, 3)
  end
  return def
end

---@param by_player LuaPlayer|integer
---@return boolean
local function is_admin(by_player)
  local player = lib_player.get(lib_storage.player_index(by_player))
  return player ~= nil and lib_player.is_admin(player) == true
end

---@param setting ExterosLibSettingDef
---@param value any
---@return boolean, string?
local function validate_value(setting, value)
  if setting.type == "bool" then
    if type(value) ~= "boolean" then return false, "must be a boolean" end
  elseif setting.type == "int" then
    if type(value) ~= "number" or value ~= math.floor(value) then return false, "must be an integer" end
  elseif setting.type == "double" then
    if type(value) ~= "number" then return false, "must be a number" end
  elseif setting.type == "string" then
    if type(value) ~= "string" then return false, "must be a string" end
    if value == "" and not setting.allow_blank then return false, "must not be blank" end
    if setting.allowed then
      local found = false
      for _, allowed_value in ipairs(setting.allowed) do
        if allowed_value == value then
          found = true
        end
      end
      if not found then return false, "must be one of the allowed values" end
    end
  end

  if setting.min ~= nil and type(value) == "number" and value < setting.min then
    return false, "must be >= minimum"
  end
  if setting.max ~= nil and type(value) == "number" and value > setting.max then
    return false, "must be <= maximum"
  end

  return true, nil
end

---@param scope ExterosLibValuesScope
---@param name string
---@param player_index integer?
---@param old any
---@param new any
---@return nil
local function fire_change(scope, name, player_index, old, new)
  if old == new then return end
  for _, listener in ipairs(change_listeners) do
    listener({ scope = scope, name = name, player_index = player_index, old = old, new = new })
  end
end

---@return boolean
function M.is_setup()
  return defs ~= nil
end

---@return nil
function M.setup()
  if defs ~= nil then
    error("exteros-lib values (" .. tostring(script.mod_name) .. "): setup() was already called", 2)
  end

  local this_mod_name = script.mod_name
  local mod_data_name = manifest_lib.mod_data_name(this_mod_name)
  local mod_data = prototypes.mod_data[mod_data_name]
  if mod_data == nil then
    error("exteros-lib values (" .. this_mod_name .. "): no manifest registered — call "
      .. "internal.family.register(manifest) in data stage first", 2)
  end

  local manifest = mod_data.data.manifest
  local blocked = mod_data.data.blocked

  local built_defs = {}
  local features = {}

  for _, feature in ipairs(manifest.features) do
    if not blocked[feature.name] then
      local global_list = {}
      local player_list = {}

      for _, setting in ipairs(feature.runtime_global or {}) do
        local full_name = manifest_lib.setting_name(manifest, feature, setting)
        built_defs[full_name] = { setting = setting, scope = "global" }
        table.insert(global_list, { full_name = full_name, setting = setting })
      end

      for _, setting in ipairs(feature.runtime_per_user or {}) do
        local full_name = manifest_lib.setting_name(manifest, feature, setting)
        built_defs[full_name] = { setting = setting, scope = "player" }
        table.insert(player_list, { full_name = full_name, setting = setting })
      end

      table.insert(features, { name = feature.name, runtime_global = global_list, runtime_per_user = player_list })
    end
  end

  mod_name = this_mod_name
  defs = built_defs
  M._features = features

  global_ns = lib_storage.namespace("exteros_lib_values_global", {})
  player_ns = lib_storage.player_table("exteros_lib_values_player", function() return {} end)

  remote.add_interface("exteros-lib-values-" .. mod_name, {
    describe = M.describe,
    set = M.remote_set,
    reset = M.remote_reset,
    export_table = M.export_table,
    import_table = M.import_table,
  })
end

---@param name string
---@return boolean|number|string
function M.get_global(name)
  lookup(name, "global")
  local overrides = global_ns.peek() or {}
  local value = overrides[name]
  if value == nil then
    return defs[name].setting.default
  end
  return value
end

---@param player LuaPlayer|integer
---@param name string
---@return boolean|number|string
function M.get_player(player, name)
  lookup(name, "player")
  local overrides = player_ns.peek(player) or {}
  local value = overrides[name]
  if value == nil then
    return defs[name].setting.default
  end
  return value
end

---@param name string
---@param value boolean|number|string
---@param by_player (LuaPlayer|integer)?
---@return boolean, string?
function M.set_global(name, value, by_player)
  local def = lookup(name, "global")

  if by_player ~= nil and not is_admin(by_player) then
    return false, "only an admin may change a global setting"
  end

  local ok, reason = validate_value(def.setting, value)
  if not ok then return false, reason end

  local overrides = global_ns.get()
  local old = overrides[name]
  if old == nil then old = def.setting.default end

  if value == def.setting.default then
    overrides[name] = nil
  else
    overrides[name] = value
  end

  fire_change("global", name, nil, old, value)
  return true, nil
end

---@param player LuaPlayer|integer
---@param name string
---@param value boolean|number|string
---@return boolean, string?
function M.set_player(player, name, value)
  local def = lookup(name, "player")

  local ok, reason = validate_value(def.setting, value)
  if not ok then return false, reason end

  local index = lib_storage.player_index(player)
  local overrides = player_ns.get(index)
  local old = overrides[name]
  if old == nil then old = def.setting.default end

  if value == def.setting.default then
    overrides[name] = nil
  else
    overrides[name] = value
  end

  fire_change("player", name, index, old, value)
  return true, nil
end

---@param name string
---@param by_player (LuaPlayer|integer)?
---@return boolean, string?
function M.reset_global(name, by_player)
  local def = lookup(name, "global")

  if by_player ~= nil and not is_admin(by_player) then
    return false, "only an admin may change a global setting"
  end

  local overrides = global_ns.get()
  local old = overrides[name]
  if old == nil then old = def.setting.default end

  overrides[name] = nil

  fire_change("global", name, nil, old, def.setting.default)
  return true, nil
end

---@param player LuaPlayer|integer
---@param name string
---@return boolean, string?
function M.reset_player(player, name)
  local def = lookup(name, "player")

  local index = lib_storage.player_index(player)
  local overrides = player_ns.get(index)
  local old = overrides[name]
  if old == nil then old = def.setting.default end

  overrides[name] = nil

  fire_change("player", name, index, old, def.setting.default)
  return true, nil
end

---@param listener fun(event: ExterosLibValuesChange)
---@return nil
function M.on_change(listener)
  if type(listener) ~= "function" then
    error("exteros-lib values: on_change listener must be a function", 2)
  end
  table.insert(change_listeners, listener)
end

---@param player_index integer
---@return { mod: string, version: string, admin: boolean, features: table[] }
function M.describe(player_index)
  check_ready()
  local player = lib_player.get(player_index)
  local admin = player ~= nil and lib_player.is_admin(player) == true

  local features_out = {}
  for _, feature in ipairs(M._features) do
    local global_out = {}
    for _, item in ipairs(feature.runtime_global) do
      table.insert(global_out, {
        name = item.full_name,
        type = item.setting.type,
        default = item.setting.default,
        min = item.setting.min,
        max = item.setting.max,
        step = item.setting.step,
        allowed = item.setting.allowed,
        allow_blank = item.setting.allow_blank,
        hidden = item.setting.hidden,
        value = M.get_global(item.full_name),
      })
    end

    local player_out = {}
    for _, item in ipairs(feature.runtime_per_user) do
      table.insert(player_out, {
        name = item.full_name,
        type = item.setting.type,
        default = item.setting.default,
        min = item.setting.min,
        max = item.setting.max,
        step = item.setting.step,
        allowed = item.setting.allowed,
        allow_blank = item.setting.allow_blank,
        hidden = item.setting.hidden,
        value = M.get_player(player_index, item.full_name),
      })
    end

    table.insert(features_out, { name = feature.name, runtime_global = global_out, runtime_per_user = player_out })
  end

  return {
    mod = mod_name,
    version = script.active_mods[mod_name],
    admin = admin,
    features = features_out,
  }
end

---@param player_index integer
---@param scope ExterosLibValuesScope
---@param name string
---@param value boolean|number|string
---@return boolean, string?
function M.remote_set(player_index, scope, name, value)
  check_ready()
  if scope == "global" then
    return M.set_global(name, value, player_index)
  elseif scope == "player" then
    return M.set_player(player_index, name, value)
  else
    error("exteros-lib values (" .. mod_name .. "): unknown scope '" .. tostring(scope) .. "'", 2)
  end
end

---@param player_index integer
---@param scope ExterosLibValuesScope
---@param name string
---@return boolean, string?
function M.remote_reset(player_index, scope, name)
  check_ready()
  if scope == "global" then
    return M.reset_global(name, player_index)
  elseif scope == "player" then
    return M.reset_player(player_index, name)
  else
    error("exteros-lib values (" .. mod_name .. "): unknown scope '" .. tostring(scope) .. "'", 2)
  end
end

---@param player_index integer
---@return { mod: string, version: string, global: table<string, any>, player: table<string, any> }
function M.export_table(player_index)
  check_ready()

  local global_out = {}
  for name, value in pairs(global_ns.peek() or {}) do
    global_out[name] = value
  end

  local player_out = {}
  for name, value in pairs(player_ns.peek(player_index) or {}) do
    player_out[name] = value
  end

  return {
    mod = mod_name,
    version = script.active_mods[mod_name],
    global = global_out,
    player = player_out,
  }
end

---@param setting ExterosLibSettingDef
---@param value any
---@return boolean|number|string|nil, boolean
local function clamp_value(setting, value)
  if setting.type == "bool" then
    if type(value) ~= "boolean" then return nil, false end
    return value, false
  end

  if setting.type == "string" then
    if type(value) ~= "string" then return nil, false end
    if value == "" and not setting.allow_blank then return nil, false end
    if setting.allowed then
      local found = false
      for _, allowed_value in ipairs(setting.allowed) do
        if allowed_value == value then
          found = true
        end
      end
      if not found then return nil, false end
    end
    return value, false
  end

  if type(value) ~= "number" then return nil, false end
  if setting.type == "int" and value ~= math.floor(value) then return nil, false end

  local clamped = value
  local was_clamped = false
  if setting.min ~= nil and clamped < setting.min then
    clamped = setting.min
    was_clamped = true
  end
  if setting.max ~= nil and clamped > setting.max then
    clamped = setting.max
    was_clamped = true
  end
  return clamped, was_clamped
end

---@param player_index integer
---@param tbl table
---@return { applied: string[], skipped_unknown: string[], clamped: string[], refused_not_admin: string[] }
function M.import_table(player_index, tbl)
  check_ready()
  local report = { applied = {}, skipped_unknown = {}, clamped = {}, refused_not_admin = {} }
  if type(tbl) ~= "table" then return report end

  local admin = is_admin(player_index)

  local function import_scope(raw, scope)
    if type(raw) ~= "table" then return end
    for name, value in pairs(raw) do
      local label = scope .. ":" .. tostring(name)
      local def = defs[name]
      if def == nil or def.scope ~= scope then
        table.insert(report.skipped_unknown, label)
      elseif scope == "global" and not admin then
        table.insert(report.refused_not_admin, label)
      else
        local coerced, was_clamped = clamp_value(def.setting, value)
        if coerced == nil then
          table.insert(report.skipped_unknown, label)
        else
          if was_clamped then
            table.insert(report.clamped, label)
          end
          if scope == "global" then
            M.set_global(name, coerced)
          else
            M.set_player(player_index, name, coerced)
          end
          table.insert(report.applied, label)
        end
      end
    end
  end

  import_scope(tbl.global, "global")
  import_scope(tbl.player, "player")

  return report
end

---@param tables_by_mod table<string, table>
---@return string
function M.encode(tables_by_mod)
  local envelope = { format = M.FORMAT, mods = tables_by_mod }
  local json = helpers.table_to_json(envelope)
  local encoded = helpers.encode_string(json)
  if encoded == nil then
    error("exteros-lib values: encode_string failed", 2)
  end
  return encoded
end

---@param text string
---@return { format: integer, mods: table<string, table> }?, string?
function M.decode(text)
  if type(text) ~= "string" or text == "" then
    return nil, "input must be a non-empty string"
  end

  local decode_ok, decoded = pcall(helpers.decode_string, text)
  if not decode_ok or decoded == nil then
    return nil, "invalid encoding"
  end

  local ok, envelope = pcall(helpers.json_to_table, decoded)
  if not ok or envelope == nil or type(envelope) ~= "table" then
    return nil, "invalid json"
  end

  if envelope.format ~= M.FORMAT then
    return nil, "unsupported format"
  end
  if type(envelope.mods) ~= "table" then
    return nil, "malformed: missing mods"
  end

  return envelope, nil
end

return M
