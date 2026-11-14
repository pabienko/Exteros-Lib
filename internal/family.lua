local util = require("util")
local manifest_lib = require("__exteros-lib__.internal.manifest")

local M = {}

---@type table<string, { manifest: ExterosLibManifest, blocked: table<string, string> }>?
local cached_clients = nil

---@param manifest ExterosLibManifest
---@return nil
function M.register(manifest)
  manifest_lib.validate(manifest)

  local mod_data_name = manifest_lib.mod_data_name(manifest.mod)

  if data.raw["mod-data"] and data.raw["mod-data"][mod_data_name] then
    error("exteros-lib manifest (" .. manifest.mod .. "): mod-data '" .. mod_data_name .. "' is already registered", 0)
  end

  local blocked = {}
  for _, feature in ipairs(manifest.features) do
    local conflicting_mod = manifest_lib.blocked_by(feature, mods)
    if conflicting_mod then
      blocked[feature.name] = conflicting_mod
    end
  end

  data:extend({
    {
      type = "mod-data",
      name = mod_data_name,
      data_type = manifest_lib.DATA_TYPE,
      data = {
        manifest = util.table.deepcopy(manifest),
        blocked = blocked,
      },
    },
  })
end

---@return table<string, { manifest: ExterosLibManifest, blocked: table<string, string> }>
function M.clients()
  if cached_clients then
    return cached_clients
  end

  local clients = {}
  for name, mod_data in pairs(prototypes.mod_data) do
    if string.sub(name, 1, #manifest_lib.MOD_DATA_PREFIX) == manifest_lib.MOD_DATA_PREFIX
        and mod_data.data_type == manifest_lib.DATA_TYPE then
      clients[mod_data.data.manifest.mod] = {
        manifest = mod_data.data.manifest,
        blocked = mod_data.data.blocked,
      }
    end
  end

  cached_clients = clients
  return clients
end

return M
