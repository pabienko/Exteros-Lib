local manifest_lib = require("__exteros-lib__.internal.manifest")

local M = {}

M.DEFAULT_SETTINGS_NAME = "exteros-lib-default-settings"
M.CLIENT_MARKER = "exteros_lib_has_client"

local SETTING_TYPE_MAP = {
  bool = "bool-setting",
  int = "int-setting",
  double = "double-setting",
  string = "string-setting",
}

---@param manifest ExterosLibManifest
---@return nil
function M.extend(manifest)
  manifest_lib.validate(manifest)

  rawset(_G, M.CLIENT_MARKER, true)

  local definitions = {}

  for feature_index, feature in ipairs(manifest.features) do
    if not manifest_lib.blocked_by(feature, mods) and feature.startup then
      for setting_index, setting in ipairs(feature.startup) do
        local definition = {
          type = SETTING_TYPE_MAP[setting.type],
          name = manifest_lib.setting_name(manifest, feature, setting),
          setting_type = "startup",
          default_value = setting.default,
          order = string.format("%03d-%03d", feature_index, setting_index),
        }
        if setting.min ~= nil then definition.minimum_value = setting.min end
        if setting.max ~= nil then definition.maximum_value = setting.max end
        if setting.allowed ~= nil then definition.allowed_values = setting.allowed end
        if setting.allow_blank ~= nil then definition.allow_blank = setting.allow_blank end
        if setting.hidden ~= nil then definition.hidden = setting.hidden end
        table.insert(definitions, definition)
      end
    end
  end

  if #definitions > 0 then
    data:extend(definitions)
  end
end

return M
