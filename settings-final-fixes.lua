local lib_settings = require("__exteros-lib__.internal.settings")

if not rawget(_G, lib_settings.CLIENT_MARKER) then return end

data:extend({
  {
    type = "string-setting",
    name = lib_settings.DEFAULT_SETTINGS_NAME,
    setting_type = "runtime-per-user",
    default_value = "",
    allow_blank = true,
    auto_trim = true,
    order = "a",
  },
})
