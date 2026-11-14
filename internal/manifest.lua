local M = {}

M.FORMAT = 1
M.DATA_TYPE = "exteros-lib.manifest"
M.MOD_DATA_PREFIX = "exteros-lib-"

---@alias ExterosLibSettingType "bool"|"int"|"double"|"string"

---@class ExterosLibSettingDef
---@field name string
---@field type ExterosLibSettingType
---@field default boolean|number|string
---@field min number?
---@field max number?
---@field step number?
---@field allowed string[]?
---@field allow_blank boolean?
---@field hidden boolean?

---@class ExterosLibFeatureDef
---@field name string
---@field conflicts string[]?
---@field startup ExterosLibSettingDef[]?
---@field runtime_global ExterosLibSettingDef[]?
---@field runtime_per_user ExterosLibSettingDef[]?

---@class ExterosLibManifest
---@field format integer
---@field mod string
---@field prefix string
---@field features ExterosLibFeatureDef[]

local SETTING_TYPES = { bool = true, int = true, double = true, string = true }
local MANIFEST_KEYS = { format = true, mod = true, prefix = true, features = true }
local FEATURE_KEYS = { name = true, conflicts = true, startup = true, runtime_global = true, runtime_per_user = true }
local SETTING_KEYS = { name = true, type = true, default = true, min = true, max = true, step = true, allowed = true, allow_blank = true, hidden = true }
local SETTING_GROUPS = { "startup", "runtime_global", "runtime_per_user" }

---@param tbl table
---@param allowed table<string, boolean>
---@param path string
---@param fail fun(path: string, problem: string)
---@return nil
local function check_unknown_keys(tbl, allowed, path, fail)
  for key in pairs(tbl) do
    if not allowed[key] then
      fail(path, "unknown key '" .. tostring(key) .. "'")
    end
  end
end

---@param tbl table
---@return boolean
local function is_array(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  for index = 1, count do
    if tbl[index] == nil then
      return false
    end
  end
  return true
end

---@param name any
---@param path string
---@param fail fun(path: string, problem: string)
---@return nil
local function check_name(name, path, fail)
  if type(name) ~= "string" or name == "" then
    fail(path, "must be a non-empty string")
  end
  if string.match(name, "^[a-z0-9-]+$") == nil then
    fail(path, "must only contain lowercase letters, digits and '-'")
  end
  if string.sub(name, 1, 1) == "-" or string.sub(name, -1) == "-" then
    fail(path, "must not start or end with '-'")
  end
end

---@param manifest ExterosLibManifest
---@param feature ExterosLibFeatureDef
---@param group_name string
---@param path string
---@param seen_setting_names table<string, boolean>
---@param fail fun(path: string, problem: string)
---@return nil
local function validate_setting_group(manifest, feature, group_name, path, seen_setting_names, fail)
  local group = feature[group_name]
  if group == nil then return end
  if type(group) ~= "table" then
    fail(path, "must be an array of settings")
  end
  if not is_array(group) then
    fail(path, "must be an array")
  end

  for index, setting in ipairs(group) do
    local setting_path = path .. "[" .. index .. "]"
    if type(setting) ~= "table" then
      fail(setting_path, "must be a table")
    end

    check_unknown_keys(setting, SETTING_KEYS, setting_path, fail)
    check_name(setting.name, setting_path .. ".name", fail)

    if seen_setting_names[setting.name] then
      fail(setting_path .. ".name", "duplicate setting name '" .. tostring(setting.name) .. "' within feature '" .. tostring(feature.name) .. "'")
    end
    seen_setting_names[setting.name] = true

    if type(setting.type) ~= "string" or not SETTING_TYPES[setting.type] then
      fail(setting_path .. ".type", "must be one of bool, int, double, string")
    end

    if setting.default == nil then
      fail(setting_path .. ".default", "is required")
    end

    if setting.type == "bool" then
      if type(setting.default) ~= "boolean" then
        fail(setting_path .. ".default", "must be a boolean")
      end
    elseif setting.type == "int" then
      if type(setting.default) ~= "number" or setting.default ~= math.floor(setting.default) then
        fail(setting_path .. ".default", "must be an integer")
      end
    elseif setting.type == "double" then
      if type(setting.default) ~= "number" then
        fail(setting_path .. ".default", "must be a number")
      end
    elseif setting.type == "string" then
      if type(setting.default) ~= "string" then
        fail(setting_path .. ".default", "must be a string")
      end
    end

    if setting.min ~= nil or setting.max ~= nil then
      if setting.type ~= "int" and setting.type ~= "double" then
        fail(setting_path .. ".min", "min/max are only allowed for int or double settings")
      end
      if setting.min ~= nil and type(setting.min) ~= "number" then
        fail(setting_path .. ".min", "must be a number")
      end
      if setting.max ~= nil and type(setting.max) ~= "number" then
        fail(setting_path .. ".max", "must be a number")
      end
      if setting.min ~= nil and setting.max ~= nil and setting.min > setting.max then
        fail(setting_path .. ".min", "must be <= max")
      end
      if setting.min ~= nil and type(setting.default) == "number" and setting.default < setting.min then
        fail(setting_path .. ".default", "must be >= min")
      end
      if setting.max ~= nil and type(setting.default) == "number" and setting.default > setting.max then
        fail(setting_path .. ".default", "must be <= max")
      end
    end

    if setting.step ~= nil then
      if setting.type ~= "int" and setting.type ~= "double" then
        fail(setting_path .. ".step", "is only allowed for int or double settings")
      end
      if type(setting.step) ~= "number" then
        fail(setting_path .. ".step", "must be a number")
      end
      if setting.step <= 0 then
        fail(setting_path .. ".step", "must be > 0")
      end
    end

    if setting.allowed ~= nil then
      if setting.type ~= "string" then
        fail(setting_path .. ".allowed", "is only allowed for string settings")
      end
      if type(setting.allowed) ~= "table" then
        fail(setting_path .. ".allowed", "must be an array of strings")
      end
      if not is_array(setting.allowed) then
        fail(setting_path .. ".allowed", "must be an array")
      end
      if #setting.allowed == 0 then
        fail(setting_path .. ".allowed", "must be a non-empty array of strings")
      end
      local default_found = false
      for allowed_index, value in ipairs(setting.allowed) do
        if type(value) ~= "string" then
          fail(setting_path .. ".allowed[" .. allowed_index .. "]", "must be a string")
        end
        if value == setting.default then
          default_found = true
        end
      end
      if not default_found then
        fail(setting_path .. ".default", "must be one of the allowed values")
      end
    end

    if setting.allow_blank ~= nil then
      if setting.type ~= "string" then
        fail(setting_path .. ".allow_blank", "is only allowed for string settings")
      end
      if type(setting.allow_blank) ~= "boolean" then
        fail(setting_path .. ".allow_blank", "must be a boolean")
      end
    end

    if setting.hidden ~= nil and type(setting.hidden) ~= "boolean" then
      fail(setting_path .. ".hidden", "must be a boolean")
    end

    local full_name = manifest.prefix .. feature.name .. "-" .. setting.name
    if string.len(full_name) > 200 then
      fail(setting_path, "full setting name '" .. full_name .. "' exceeds 200 characters")
    end
  end
end

---@param prefix any
---@return boolean
local function is_valid_prefix(prefix)
  if type(prefix) ~= "string" then return false end
  if string.sub(prefix, 1, 8) ~= "exteros-" then return false end
  if string.sub(prefix, -1) ~= "-" then return false end
  if prefix == "exteros-lib-" then return false end

  local word = string.sub(prefix, 9, -2)
  if word == "" then return false end
  if string.match(word, "^[a-z0-9-]+$") == nil then return false end
  if string.sub(word, 1, 1) == "-" or string.sub(word, -1) == "-" then return false end

  return true
end

---@param manifest ExterosLibManifest
---@return nil
function M.validate(manifest)
  if type(manifest) ~= "table" then
    error("exteros-lib manifest (?): <root>: must be a table", 0)
  end

  local mod_name = type(manifest.mod) == "string" and manifest.mod or nil

  ---@param path string
  ---@param problem string
  ---@return nil
  local function fail(path, problem)
    error("exteros-lib manifest (" .. (mod_name or "?") .. "): " .. path .. ": " .. problem, 0)
  end

  check_unknown_keys(manifest, MANIFEST_KEYS, "<root>", fail)

  if manifest.format ~= M.FORMAT then
    fail("format", "must be exactly " .. M.FORMAT)
  end

  if type(manifest.mod) ~= "string" or manifest.mod == "" then
    fail("mod", "must be a non-empty string")
  end

  if not is_valid_prefix(manifest.prefix) then
    fail("prefix", "must match 'exteros-<word>-' with a non-empty word of lowercase letters, digits and '-' (not starting or ending with '-'), and must not be the reserved 'exteros-lib-'")
  end

  if type(manifest.features) ~= "table" then
    fail("features", "must be an array")
  end
  if not is_array(manifest.features) then
    fail("features", "must be an array")
  end
  if #manifest.features == 0 then
    fail("features", "must be a non-empty array")
  end

  local seen_feature_names = {}

  for feature_index, feature in ipairs(manifest.features) do
    local feature_path = "features[" .. feature_index .. "]"
    if type(feature) ~= "table" then
      fail(feature_path, "must be a table")
    end

    check_unknown_keys(feature, FEATURE_KEYS, feature_path, fail)
    check_name(feature.name, feature_path .. ".name", fail)

    if seen_feature_names[feature.name] then
      fail(feature_path .. ".name", "duplicate feature name '" .. tostring(feature.name) .. "'")
    end
    seen_feature_names[feature.name] = true

    if feature.conflicts ~= nil then
      if type(feature.conflicts) ~= "table" then
        fail(feature_path .. ".conflicts", "must be an array of mod names")
      end
      if not is_array(feature.conflicts) then
        fail(feature_path .. ".conflicts", "must be an array")
      end
      for conflict_index, conflict in ipairs(feature.conflicts) do
        if type(conflict) ~= "string" or conflict == "" then
          fail(feature_path .. ".conflicts[" .. conflict_index .. "]", "must be a non-empty string")
        end
      end
    end

    local seen_setting_names = {}
    for _, group_name in ipairs(SETTING_GROUPS) do
      validate_setting_group(manifest, feature, group_name, feature_path .. "." .. group_name, seen_setting_names, fail)
    end
  end
end

---@param manifest ExterosLibManifest
---@param feature ExterosLibFeatureDef
---@param setting ExterosLibSettingDef
---@return string
function M.setting_name(manifest, feature, setting)
  return manifest.prefix .. feature.name .. "-" .. setting.name
end

---@param feature ExterosLibFeatureDef
---@param active_mods table<string, any>
---@return string?
function M.blocked_by(feature, active_mods)
  if not feature.conflicts then return nil end
  for _, conflicting_mod in ipairs(feature.conflicts) do
    if active_mods[conflicting_mod] then
      return conflicting_mod
    end
  end
  return nil
end

---@param group ExterosLibSettingDef[]?
---@return boolean
local function has_non_hidden(group)
  for _, setting in ipairs(group or {}) do
    if not setting.hidden then return true end
  end
  return false
end

---@param manifest ExterosLibManifest
---@param feature ExterosLibFeatureDef
---@param startup_settings table<string, { value: boolean|number|string }>
---@return boolean
local function feature_startup_enabled(manifest, feature, startup_settings)
  for _, setting in ipairs(feature.startup or {}) do
    if setting.name == "enabled" then
      local full_name = M.setting_name(manifest, feature, setting)
      local def = startup_settings[full_name]
      if def ~= nil then
        return def.value == true
      end
      return setting.default == true
    end
  end
  return true
end

---@param manifest ExterosLibManifest
---@param blocked table<string, string>
---@param startup_settings table<string, { value: boolean|number|string }>
---@return boolean
function M.has_hub_settings(manifest, blocked, startup_settings)
  for _, feature in ipairs(manifest.features) do
    if not blocked[feature.name] and feature_startup_enabled(manifest, feature, startup_settings) then
      if has_non_hidden(feature.runtime_global) or has_non_hidden(feature.runtime_per_user) then
        return true
      end
    end
  end
  return false
end

---@param mod string
---@return string
function M.mod_data_name(mod)
  return M.MOD_DATA_PREFIX .. mod
end

return M
