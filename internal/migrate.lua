local event = require("__exteros-lib__.event")

local M = {}

local SCHEMA_KEY = "exteros_lib_schema"

local called = false

---@class ExterosLibMigrateSpec
---@field version integer
---@field legacy (fun(old: table, changes: ConfigurationChangedData): table?)?
---@field steps table<integer, fun(changes: ConfigurationChangedData)>?
---@field init fun(carry: table?)

---@param storage_table table
---@return boolean
local function has_keys(storage_table)
  return next(storage_table) ~= nil
end

---@param storage_table table
---@return nil
local function wipe(storage_table)
  for key in pairs(storage_table) do
    storage_table[key] = nil
  end
end

---@param spec ExterosLibMigrateSpec
---@param from integer
---@param to integer
---@param mod_name string
---@param changes ConfigurationChangedData
---@return nil
local function run_steps(spec, from, to, mod_name, changes)
  for n = from + 1, to do
    local step = spec.steps and spec.steps[n]
    if not step then
      error("exteros-lib migrate (" .. mod_name .. "): missing migration step " .. n, 0)
    end
    step(changes)
    storage[SCHEMA_KEY] = n
  end
end

---@param spec ExterosLibMigrateSpec
---@return nil
local function check_spec(spec, mod_name)
  if type(spec) ~= "table" then
    error("exteros-lib migrate (" .. mod_name .. "): spec must be a table", 3)
  end
  if type(spec.version) ~= "number" or spec.version ~= math.floor(spec.version) or spec.version < 1 then
    error("exteros-lib migrate (" .. mod_name .. "): version must be an integer >= 1", 3)
  end
  if spec.legacy ~= nil and type(spec.legacy) ~= "function" then
    error("exteros-lib migrate (" .. mod_name .. "): legacy must be a function or nil", 3)
  end
  if spec.steps ~= nil and type(spec.steps) ~= "table" then
    error("exteros-lib migrate (" .. mod_name .. "): steps must be a table or nil", 3)
  end
  if type(spec.init) ~= "function" then
    error("exteros-lib migrate (" .. mod_name .. "): init must be a function", 3)
  end
end

---@param spec ExterosLibMigrateSpec
---@return nil
function M.register(spec)
  local mod_name = script.mod_name

  if game ~= nil then
    error("exteros-lib migrate (" .. mod_name .. "): register() must be called while control.lua loads, not from an event", 2)
  end
  if called then
    error("exteros-lib migrate (" .. mod_name .. "): register() was already called", 2)
  end
  if event._handler_count("on_init") > 0 or event._handler_count("on_configuration_changed") > 0 then
    error("migrate.register must be called before any other on_init/on_configuration_changed subscriber", 2)
  end
  check_spec(spec, mod_name)
  called = true

  event.on_init(function()
    spec.init(nil)
    storage[SCHEMA_KEY] = spec.version
  end)

  event.on_configuration_changed(function(changes)
    local schema = storage[SCHEMA_KEY]

    if schema == nil then
      local carry = nil
      if has_keys(storage) then
        if spec.legacy then
          carry = spec.legacy(storage, changes)
        end
        wipe(storage)
        event._resync()
      end
      spec.init(carry)
      storage[SCHEMA_KEY] = spec.version
      return
    end

    if schema < spec.version then
      run_steps(spec, schema, spec.version, mod_name, changes)
      return
    end

    if schema > spec.version then
      log("exteros-lib migrate (" .. mod_name .. "): downgrading schema " .. schema .. " -> " .. spec.version .. ", wiping storage")
      wipe(storage)
      event._resync()
      spec.init(nil)
      storage[SCHEMA_KEY] = spec.version
      return
    end
  end)
end

return M
