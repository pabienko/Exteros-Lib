local manifest_lib = require("__exteros-lib__.internal.manifest")

---@return boolean
local function hub_needed()
  for name, prototype in pairs(data.raw["mod-data"] or {}) do
    if string.sub(name, 1, #manifest_lib.MOD_DATA_PREFIX) == manifest_lib.MOD_DATA_PREFIX
        and prototype.data_type == manifest_lib.DATA_TYPE
        and manifest_lib.has_hub_settings(prototype.data.manifest, prototype.data.blocked, settings.startup) then
      return true
    end
  end
  return false
end

if not hub_needed() then return end

data:extend({
  {
    type = "custom-input",
    name = "exteros-lib-hub",
    key_sequence = "SHIFT + E",
    consuming = "none",
  },
  {
    type = "shortcut",
    name = "exteros-lib-hub",
    order = "e[exteros-lib]-a[hub]",
    action = "lua",
    localised_name = { "shortcut-name.exteros-lib-hub" },
    toggleable = true,
    associated_control_input = "exteros-lib-hub",
    icon = "__exteros-lib__/graphics/shortcut/hub-x56.png",
    icon_size = 56,
    small_icon = "__exteros-lib__/graphics/shortcut/hub-x24.png",
    small_icon_size = 24,
  },
})
