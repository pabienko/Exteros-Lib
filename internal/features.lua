local manifest_lib = require("__exteros-lib__.internal.manifest")
local lib_storage = require("__exteros-lib__.storage")
local event = require("__exteros-lib__.event")
local values = require("__exteros-lib__.internal.values")

local M = {}

local STORAGE_KEY = "exteros_lib_features"

---@class ExterosLibFeatureSpec
---@field events table<any, function>?
---@field on_nth_tick table<integer, function>?
---@field on_enable fun()?
---@field on_disable fun()?

---@class ExterosLibFeatureState
---@field group string?
---@field on_enable function?
---@field on_disable function?

---@class ExterosLibFeatureEnabledSetting
---@field scope "startup"|"global"
---@field full_name string

local SPEC_KEYS = { events = true, on_nth_tick = true, on_enable = true, on_disable = true }

---@type string?
local mod_name = nil
---@type ExterosLibManifest?
local manifest = nil
---@type table<string, string>?
local blocked = nil
---@type table<string, ExterosLibFeatureDef>
local feature_by_name = {}
---@type table<string, ExterosLibFeatureEnabledSetting?>
local enabled_setting_by_name = {}
---@type table<string, string>
local feature_by_global_setting = {}

---@type table<string, ExterosLibFeatureState>
local specs = {}

local setup_done = false
---@type { get: fun(): table, peek: fun(): table? }?
local applied_ns = nil

---@param feature ExterosLibFeatureDef
---@return ExterosLibFeatureEnabledSetting?
local function find_enabled_setting(feature)
  for _, setting in ipairs(feature.startup or {}) do
    if setting.name == "enabled" then
      return { scope = "startup", full_name = manifest_lib.setting_name(manifest, feature, setting) }
    end
  end
  for _, setting in ipairs(feature.runtime_global or {}) do
    if setting.name == "enabled" then
      return { scope = "global", full_name = manifest_lib.setting_name(manifest, feature, setting) }
    end
  end
  return nil
end

---@return nil
local function ensure_manifest()
  if manifest ~= nil then
    return
  end

  local this_mod_name = script.mod_name
  local mod_data_name = manifest_lib.mod_data_name(this_mod_name)
  local mod_data = prototypes.mod_data[mod_data_name]
  if mod_data == nil then
    error("exteros-lib features (" .. this_mod_name .. "): no manifest registered — call "
      .. "internal.family.register(manifest) in data stage first", 3)
  end

  mod_name = this_mod_name
  manifest = mod_data.data.manifest
  blocked = mod_data.data.blocked

  for _, feature in ipairs(manifest.features) do
    feature_by_name[feature.name] = feature
    local enabled_setting = find_enabled_setting(feature)
    enabled_setting_by_name[feature.name] = enabled_setting
    if enabled_setting ~= nil and enabled_setting.scope == "global" then
      feature_by_global_setting[enabled_setting.full_name] = feature.name
    end
  end
end

---@param feature ExterosLibFeatureDef
---@return boolean
local function desired(feature)
  if blocked[feature.name] then
    return false
  end
  local enabled_setting = enabled_setting_by_name[feature.name]
  if enabled_setting == nil then
    return true
  end
  if enabled_setting.scope == "startup" then
    local startup_setting = settings.startup[enabled_setting.full_name]
    return startup_setting ~= nil and startup_setting.value == true
  end
  return values.get_global(enabled_setting.full_name) == true
end

---@param name string
---@return boolean
local function is_applied(name)
  local applied = applied_ns and applied_ns.peek()
  return applied ~= nil and applied[name] == true
end

---@param name string
---@return nil
local function run_enable(name)
  local state = specs[name]
  applied_ns.get()[name] = true
  if state.group ~= nil then
    event.set_active(state.group, true)
  end
  if state.on_enable ~= nil then
    state.on_enable()
  end
end

---@param name string
---@return nil
local function run_disable(name)
  local state = specs[name]
  if state.on_disable ~= nil then
    state.on_disable()
  end
  if state.group ~= nil then
    event.set_active(state.group, false)
  end
  applied_ns.get()[name] = nil
end

---@return nil
function M.setup()
  if setup_done then
    error("exteros-lib features (" .. tostring(script.mod_name) .. "): setup() was already called", 2)
  end
  ensure_manifest()
  if not values.is_setup() then
    error("exteros-lib features (" .. mod_name .. "): values.setup() must be called before features.setup()", 2)
  end

  setup_done = true
  applied_ns = lib_storage.namespace(STORAGE_KEY, {})

  event.on_init(M.reconcile)
  event.on_configuration_changed(M.reconcile)
  values.on_change(function(change)
    if change.scope ~= "global" then
      return
    end
    local name = feature_by_global_setting[change.name]
    if name == nil or specs[name] == nil then
      return
    end
    local want = desired(feature_by_name[name])
    if want ~= is_applied(name) then
      if want then run_enable(name) else run_disable(name) end
    end
  end)
end

---@param name string
---@param spec ExterosLibFeatureSpec
---@return nil
function M.define(name, spec)
  ensure_manifest()
  if feature_by_name[name] == nil then
    error("exteros-lib features (" .. mod_name .. "): unknown feature '" .. tostring(name) .. "'", 2)
  end
  if specs[name] ~= nil then
    error("exteros-lib features (" .. mod_name .. "): feature '" .. name .. "' is already defined", 2)
  end
  if type(spec) ~= "table" then
    error("exteros-lib features (" .. mod_name .. "): define() spec must be a table", 2)
  end
  for key in pairs(spec) do
    if not SPEC_KEYS[key] then
      error("exteros-lib features (" .. mod_name .. "): define() received an unknown key '" .. tostring(key) .. "'", 2)
    end
  end
  if spec.on_enable ~= nil and type(spec.on_enable) ~= "function" then
    error("exteros-lib features (" .. mod_name .. "): on_enable must be a function", 2)
  end
  if spec.on_disable ~= nil and type(spec.on_disable) ~= "function" then
    error("exteros-lib features (" .. mod_name .. "): on_disable must be a function", 2)
  end

  local has_handlers = (spec.events ~= nil and next(spec.events) ~= nil)
      or (spec.on_nth_tick ~= nil and next(spec.on_nth_tick) ~= nil)
  local group = nil
  if has_handlers then
    group = "feature:" .. name
    event.group(group, { events = spec.events, on_nth_tick = spec.on_nth_tick })
  end

  specs[name] = { group = group, on_enable = spec.on_enable, on_disable = spec.on_disable }
end

---@param name string
---@return boolean
function M.is_enabled(name)
  ensure_manifest()
  local feature = feature_by_name[name]
  if feature == nil then
    error("exteros-lib features (" .. mod_name .. "): unknown feature '" .. tostring(name) .. "'", 2)
  end
  if specs[name] ~= nil then
    return is_applied(name)
  end
  return desired(feature)
end

---@return nil
function M.reconcile()
  if not setup_done then
    error("exteros-lib features: reconcile() called before setup()", 2)
  end

  local applied = applied_ns.get()
  for name in pairs(applied) do
    if specs[name] == nil then
      applied[name] = nil
    end
  end

  for _, feature in ipairs(manifest.features) do
    local name = feature.name
    if specs[name] ~= nil then
      local want = desired(feature)
      if want ~= is_applied(name) then
        if want then run_enable(name) else run_disable(name) end
      end
    end
  end
end

return M
