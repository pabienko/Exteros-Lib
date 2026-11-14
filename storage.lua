--- Namespaced, per-mod persistent tables on the calling mod's own `storage`.
--- Bind as `local lib_storage = require("__exteros-lib__.storage")`, not `storage`
--- — that name is Factorio's own global.
--- Stages: control.

local event = require("__exteros-lib__.event")
local util = require("util")

local M = {}

---@type table<string, boolean>
local used_keys = {}

---@param key any
---@return nil
local function check_key(key)
  if type(key) ~= "string" or key == "" then
    error("exteros-lib storage: key must be a non-empty string", 3)
  end
  if used_keys[key] then
    error("exteros-lib storage: key '" .. key .. "' is already used in this mod", 3)
  end
  used_keys[key] = true
end

--- Resolve a `LuaPlayer` or a player index to a plain integer index.
---@param player LuaPlayer|integer
---@return integer
function M.player_index(player)
  if type(player) == "number" then
    return player
  end
  if type(player) == "userdata" and player.object_name == "LuaPlayer" then
    if not player.valid then
      error("exteros-lib storage: player is not valid", 3)
    end
    return player.index
  end
  error("exteros-lib storage: player must be a LuaPlayer or a player index", 3)
end

--- A namespace keyed by `key` on the calling mod's `storage`. `get()` creates the
--- entry on first use from `defaults` (a table, deep-copied; a function, called
--- for its return value; or nil, an empty table) and returns it. `peek()` returns
--- the entry or nil without writing, so it's safe from on_load.
---@param key string
---@param defaults table|(fun(): table)|nil
---@return { get: fun(): table, peek: fun(): table? }
function M.namespace(key, defaults)
  check_key(key)
  if defaults ~= nil and type(defaults) ~= "table" and type(defaults) ~= "function" then
    error("exteros-lib storage: defaults must be a table, a function or nil", 2)
  end

  ---@return table
  local function get()
    if storage[key] == nil then
      if type(defaults) == "function" then
        storage[key] = defaults()
      elseif type(defaults) == "table" then
        storage[key] = util.table.deepcopy(defaults)
      else
        storage[key] = {}
      end
    end
    return storage[key]
  end

  ---@return table?
  local function peek()
    return storage[key]
  end

  return { get = get, peek = peek }
end

--- A table keyed by `key` on the calling mod's `storage`, with one entry per
--- player (`player` is a LuaPlayer or a player index; an entry can be any
--- non-nil value, not only a table). `get()` creates the entry via
--- `factory(index)` (or an empty table) on first use; `peek()` never writes;
--- `all()` returns the whole table, or a new empty one. Must be created
--- before `event.register()` — it subscribes its own cleanup on
--- `on_player_removed`, which always runs after the mod's own handlers for
--- that event, so those can still read the entry before it's cleared.
---@param key string
---@param factory (fun(index: integer): any)|nil
---@return { get: fun(player: LuaPlayer|integer): any, peek: fun(player: LuaPlayer|integer): any, set: fun(player: LuaPlayer|integer, value: any): nil, clear: fun(player: LuaPlayer|integer): nil, all: fun(): table<integer, any> }
function M.player_table(key, factory)
  check_key(key)
  if factory ~= nil and type(factory) ~= "function" then
    error("exteros-lib storage: factory must be a function or nil", 2)
  end
  if event.is_registered() then
    error("exteros-lib storage: player_table() must be created before event.register()", 2)
  end

  ---@return table<integer, table>
  local function ensure_table()
    if storage[key] == nil then
      storage[key] = {}
    end
    return storage[key]
  end

  ---@param index integer
  ---@return any
  local function make_entry(index)
    if factory then
      return factory(index)
    end
    return {}
  end

  ---@param player LuaPlayer|integer
  ---@return any
  local function get(player)
    local index = M.player_index(player)
    local entries = ensure_table()
    if entries[index] == nil then
      entries[index] = make_entry(index)
    end
    return entries[index]
  end

  ---@param player LuaPlayer|integer
  ---@return any
  local function peek(player)
    local index = M.player_index(player)
    local entries = storage[key]
    if entries == nil then return nil end
    return entries[index]
  end

  ---@param player LuaPlayer|integer
  ---@param value any
  ---@return nil
  local function set(player, value)
    if value == nil then
      error("exteros-lib storage: set() value must not be nil, use clear()", 2)
    end
    local index = M.player_index(player)
    ensure_table()[index] = value
  end

  ---@param player LuaPlayer|integer
  ---@return nil
  local function clear(player)
    local index = M.player_index(player)
    local entries = storage[key]
    if entries ~= nil then
      entries[index] = nil
    end
  end

  ---@return table<integer, any>
  local function all()
    return storage[key] or {}
  end

  event._on_late(defines.events.on_player_removed, function(e)
    clear(e.player_index)
  end)

  return { get = get, peek = peek, set = set, clear = clear, all = all }
end

return M
