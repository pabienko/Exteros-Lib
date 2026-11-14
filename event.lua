--- Multi-handler dispatcher: lets many parts of one mod subscribe to the same
--- event, custom input, nth-tick, on_init, on_load or on_configuration_changed,
--- registering each with Factorio only once (Factorio allows only one handler
--- per event per mod).
--- Handlers can also be subscribed as a named GROUP (`group()`), switched on/off
--- at runtime with `set_active()`: an id or nth-tick used only by inactive groups
--- is not registered with Factorio. The active set persists across save/load.
--- Event filters are not supported yet.
--- Stages: control.

local M = {}

local STORAGE_KEY = "exteros_lib_event"

local registered = false

---@class ExterosLibEventEntry
---@field handler function
---@field group string?

---@type table<any, ExterosLibEventEntry[]>
local event_handlers = {}
---@type table<any, function[]>
local late_event_handlers = {}
---@type table<integer, ExterosLibEventEntry[]>
local nth_tick_handlers = {}
---@type function[]
local init_handlers = {}
---@type function[]
local load_handlers = {}
---@type function[]
local configuration_changed_handlers = {}

---@type table<string, { event_ids: any[], nth_ticks: integer[] }>
local groups = {}
---@type table<string, boolean>
local active_groups = {}

---@type table<any, fun(e: table)>
local dispatch_fns = {}
---@type table<integer, fun(e: NthTickEventData)>
local dispatch_fns_nth = {}

local ADD_KEYS = { events = true, on_nth_tick = true, on_init = true, on_load = true, on_configuration_changed = true }
local GROUP_KEYS = { events = true, on_nth_tick = true }

---@param handler any
---@return nil
local function check_handler(handler)
  if type(handler) ~= "function" then
    error("exteros-lib event: handler must be a function", 3)
  end
end

---@param list table<any, any[]>
---@param id any
---@param item any
---@return nil
local function append(list, id, item)
  local items = list[id]
  if not items then
    items = {}
    list[id] = items
  end
  table.insert(items, item)
end

--- Subscribe `handler` to one event (a `defines.events` value, a custom-input
--- name, or a `script.generate_event_name()` id), or to an array of them. Call
--- before `register()`, from control.lua's main chunk.
---@param events LuaEventType|LuaEventType[]
---@param handler fun(event: table)
---@return nil
function M.on(events, handler)
  if registered then
    error("exteros-lib event: on() cannot be called after register()", 2)
  end
  check_handler(handler)
  if events == nil then
    error("exteros-lib event: unknown event — check the defines.events name", 2)
  end

  if type(events) == "table" then
    if #events == 0 then
      error("exteros-lib event: unknown event — check the defines.events name", 2)
    end
    for _, id in ipairs(events) do
      append(event_handlers, id, { handler = handler, group = nil })
    end
  else
    append(event_handlers, events, { handler = handler, group = nil })
  end
end

--- Internal: subscribe `handler` to run after every ordinary `on()` subscriber
--- of `events`, regardless of subscription order. Not part of the public API.
---@param events LuaEventType|LuaEventType[]
---@param handler fun(event: table)
---@return nil
function M._on_late(events, handler)
  if registered then
    error("exteros-lib event: _on_late() cannot be called after register()", 2)
  end
  check_handler(handler)
  if events == nil then
    error("exteros-lib event: unknown event — check the defines.events name", 2)
  end

  if type(events) == "table" then
    if #events == 0 then
      error("exteros-lib event: unknown event — check the defines.events name", 2)
    end
    for _, id in ipairs(events) do
      append(late_event_handlers, id, handler)
    end
  else
    append(late_event_handlers, events, handler)
  end
end

---@param value any
---@return nil
local function check_ticks_value(value)
  if type(value) ~= "number" or value <= 0 or value ~= math.floor(value) then
    error("exteros-lib event: on_nth_tick ticks must be a positive integer", 3)
  end
end

--- Subscribe `handler` to `script.on_nth_tick(ticks)`, or to an array of tick
--- counts. Call before `register()`.
---@param ticks integer|integer[]
---@param handler fun(event: NthTickEventData)
---@return nil
function M.on_nth_tick(ticks, handler)
  if registered then
    error("exteros-lib event: on_nth_tick() cannot be called after register()", 2)
  end
  check_handler(handler)

  if type(ticks) == "table" then
    if #ticks == 0 then
      error("exteros-lib event: on_nth_tick ticks must be a positive integer", 2)
    end
    for _, value in ipairs(ticks) do
      check_ticks_value(value)
    end
    for _, value in ipairs(ticks) do
      append(nth_tick_handlers, value, { handler = handler, group = nil })
    end
  else
    check_ticks_value(ticks)
    append(nth_tick_handlers, ticks, { handler = handler, group = nil })
  end
end

--- Subscribe `handler` to run once from `script.on_init`. Call before `register()`.
---@param handler fun()
---@return nil
function M.on_init(handler)
  if registered then
    error("exteros-lib event: on_init() cannot be called after register()", 2)
  end
  check_handler(handler)
  table.insert(init_handlers, handler)
end

--- Subscribe `handler` to run once from `script.on_load`. Call before `register()`.
---@param handler fun()
---@return nil
function M.on_load(handler)
  if registered then
    error("exteros-lib event: on_load() cannot be called after register()", 2)
  end
  check_handler(handler)
  table.insert(load_handlers, handler)
end

--- Subscribe `handler` to run from `script.on_configuration_changed`. Call
--- before `register()`.
---@param handler fun(data: ConfigurationChangedData)
---@return nil
function M.on_configuration_changed(handler)
  if registered then
    error("exteros-lib event: on_configuration_changed() cannot be called after register()", 2)
  end
  check_handler(handler)
  table.insert(configuration_changed_handlers, handler)
end

--- Convenience for a feature module table with optional `events`
--- (`{ [LuaEventType] = handler }`), `on_nth_tick` (`{ [ticks] = handler }`),
--- `on_init`, `on_load` and `on_configuration_changed` fields. Equivalent to
--- calling the functions above once per entry. Call before `register()`.
---@param module { events: table<any, function>?, on_nth_tick: table<integer, function>?, on_init: function?, on_load: function?, on_configuration_changed: function? }
---@return nil
function M.add(module)
  if type(module) ~= "table" then
    error("exteros-lib event: add() expects a table", 2)
  end
  for key in pairs(module) do
    if not ADD_KEYS[key] then
      error("exteros-lib event: add() received an unknown key '" .. tostring(key) .. "'", 2)
    end
  end

  if module.events then
    for id, handler in pairs(module.events) do
      M.on(id, handler)
    end
  end
  if module.on_nth_tick then
    for ticks, handler in pairs(module.on_nth_tick) do
      M.on_nth_tick(ticks, handler)
    end
  end
  if module.on_init then
    M.on_init(module.on_init)
  end
  if module.on_load then
    M.on_load(module.on_load)
  end
  if module.on_configuration_changed then
    M.on_configuration_changed(module.on_configuration_changed)
  end
end

--- Declare a named group of event/nth-tick handlers that starts INACTIVE and is
--- switched on/off at runtime with `set_active()`. `spec.events` and
--- `spec.on_nth_tick` use the same shape as `on()`/`on_nth_tick()`; at least one
--- handler is required, and `name` must be unique across the mod. Call before
--- `register()`.
---@param name string
---@param spec { events: table<any, function>?, on_nth_tick: table<integer, function>? }
---@return nil
function M.group(name, spec)
  if registered then
    error("exteros-lib event: group() cannot be called after register()", 2)
  end
  if type(name) ~= "string" or name == "" then
    error("exteros-lib event: group name must be a non-empty string", 2)
  end
  if groups[name] ~= nil then
    error("exteros-lib event: duplicate event group '" .. name .. "'", 2)
  end
  if type(spec) ~= "table" then
    error("exteros-lib event: group() spec must be a table", 2)
  end
  for key in pairs(spec) do
    if not GROUP_KEYS[key] then
      error("exteros-lib event: group() received an unknown key '" .. tostring(key) .. "'", 2)
    end
  end

  local event_ids = {}
  local nth_ticks = {}
  local handler_count = 0

  if spec.events then
    for id, handler in pairs(spec.events) do
      check_handler(handler)
      append(event_handlers, id, { handler = handler, group = name })
      table.insert(event_ids, id)
      handler_count = handler_count + 1
    end
  end
  if spec.on_nth_tick then
    for ticks, handler in pairs(spec.on_nth_tick) do
      check_ticks_value(ticks)
      check_handler(handler)
      append(nth_tick_handlers, ticks, { handler = handler, group = name })
      table.insert(nth_ticks, ticks)
      handler_count = handler_count + 1
    end
  end

  if handler_count == 0 then
    error("exteros-lib event: group() needs at least one handler", 2)
  end

  groups[name] = { event_ids = event_ids, nth_ticks = nth_ticks }
end

---@param id any
---@return boolean
local function needs_id(id)
  local late = late_event_handlers[id]
  if late and #late > 0 then
    return true
  end
  local entries = event_handlers[id]
  if entries then
    for _, entry in ipairs(entries) do
      if entry.group == nil or active_groups[entry.group] then
        return true
      end
    end
  end
  return false
end

---@param id any
---@return nil
local function sync_id(id)
  local fn = dispatch_fns[id]
  if fn == nil then
    return
  end
  script.on_event(id, needs_id(id) and fn or nil)
end

---@param ticks integer
---@return boolean
local function needs_nth(ticks)
  local entries = nth_tick_handlers[ticks]
  if not entries then
    return false
  end
  for _, entry in ipairs(entries) do
    if entry.group == nil or active_groups[entry.group] then
      return true
    end
  end
  return false
end

---@param ticks integer
---@return nil
local function sync_nth(ticks)
  local fn = dispatch_fns_nth[ticks]
  if fn == nil then
    return
  end
  script.on_nth_tick(ticks, needs_nth(ticks) and fn or nil)
end

---@param name string
---@return nil
local function resync_group(name)
  local declared = groups[name]
  if declared == nil then
    return
  end
  for _, id in ipairs(declared.event_ids) do
    sync_id(id)
  end
  for _, ticks in ipairs(declared.nth_ticks) do
    sync_nth(ticks)
  end
end

--- Internal: rebuild the in-memory active-group set from the calling mod's own
--- storage record and resync every group's registrations to match. Read-only
--- on storage, safe to call from `on_load`. Not part of the public API.
---@return nil
function M._resync()
  active_groups = {}
  local record = storage[STORAGE_KEY]
  if record ~= nil and record.groups ~= nil then
    for name in pairs(record.groups) do
      if groups[name] ~= nil then
        active_groups[name] = true
      end
    end
  end
  for name in pairs(groups) do
    resync_group(name)
  end
end

---@return nil
local function prune_group_record()
  local record = storage[STORAGE_KEY]
  if record == nil or record.groups == nil then
    return
  end
  for name in pairs(record.groups) do
    if groups[name] == nil then
      record.groups[name] = nil
    end
  end
end

--- Register every subscribed event, nth-tick, on_init, on_load and
--- on_configuration_changed with Factorio, fanning out to each handler in
--- subscription order (no `pcall` — errors surface normally). An id or
--- nth-tick used only by `group()`s is not registered until one of its groups
--- becomes active. Call exactly once, from the main chunk of control.lua.
--- After this, on()/on_nth_tick()/on_init()/on_load()/on_configuration_changed()/
--- add()/group() all error.
---@return nil
function M.register()
  if game ~= nil then
    error("exteros-lib event: register() must be called while control.lua loads, not from an event", 2)
  end
  if registered then
    error("exteros-lib event: register() was already called", 2)
  end
  registered = true

  local merged_ids = {}
  local seen_ids = {}
  for id in pairs(event_handlers) do
    seen_ids[id] = true
    table.insert(merged_ids, id)
  end
  for id in pairs(late_event_handlers) do
    if not seen_ids[id] then
      seen_ids[id] = true
      table.insert(merged_ids, id)
    end
  end

  for _, id in ipairs(merged_ids) do
    local entries = event_handlers[id]
    local late_handlers = late_event_handlers[id]
    dispatch_fns[id] = function(e)
      if entries then
        for _, entry in ipairs(entries) do
          if entry.group == nil or active_groups[entry.group] then
            entry.handler(e)
          end
        end
      end
      if late_handlers then
        for _, handler in ipairs(late_handlers) do
          handler(e)
        end
      end
    end
    sync_id(id)
  end

  for ticks, entries in pairs(nth_tick_handlers) do
    dispatch_fns_nth[ticks] = function(e)
      for _, entry in ipairs(entries) do
        if entry.group == nil or active_groups[entry.group] then
          entry.handler(e)
        end
      end
    end
    sync_nth(ticks)
  end

  if #init_handlers > 0 then
    script.on_init(function()
      for _, handler in ipairs(init_handlers) do
        handler()
      end
    end)
  end

  local any_group = next(groups) ~= nil

  if #load_handlers > 0 or any_group then
    script.on_load(function()
      if any_group then
        M._resync()
      end
      for _, handler in ipairs(load_handlers) do
        handler()
      end
    end)
  end

  if #configuration_changed_handlers > 0 or any_group then
    script.on_configuration_changed(function(data)
      if any_group then
        prune_group_record()
      end
      for _, handler in ipairs(configuration_changed_handlers) do
        handler(data)
      end
    end)
  end
end

--- Whether `register()` has already run. Use it to guard setup that must
--- happen before registration, like `storage.player_table`'s cleanup handler.
---@return boolean
function M.is_registered()
  return registered
end

--- Switch event group `name` on or off. Must be called after `register()`,
--- never from the main chunk or `on_load` (both run with `game == nil`).
--- Persists the active set in storage so it survives save/load, and
--- re-registers the affected ids/nth-ticks immediately. A no-op if the
--- group is already in that state.
---@param name string
---@param active boolean
---@return nil
function M.set_active(name, active)
  if type(active) ~= "boolean" then
    error("exteros-lib event: set_active() active must be a boolean", 2)
  end
  if not registered then
    error("exteros-lib event: set_active() must be called after register()", 2)
  end
  if groups[name] == nil then
    error("exteros-lib event: unknown event group '" .. tostring(name) .. "'", 2)
  end
  if game == nil then
    error("exteros-lib event: set_active() needs game state — call it from an event handler or a remote interface, not the main chunk or on_load", 2)
  end

  active_groups[name] = active

  local record = storage[STORAGE_KEY]
  if active then
    if record == nil then
      record = { groups = {} }
      storage[STORAGE_KEY] = record
    end
    if record.groups == nil then
      record.groups = {}
    end
    record.groups[name] = true
  elseif record ~= nil and record.groups ~= nil then
    record.groups[name] = nil
  end

  resync_group(name)
end

--- Whether event group `name` is currently active. Never called from the main
--- chunk or `on_load` (both run with `game == nil`).
---@param name string
---@return boolean
function M.is_active(name)
  if groups[name] == nil then
    error("exteros-lib event: unknown event group '" .. tostring(name) .. "'", 2)
  end
  if game == nil then
    error("exteros-lib event: is_active() needs game state — call it from an event handler or a remote interface, not the main chunk or on_load", 2)
  end
  return active_groups[name] == true
end

--- Internal test introspection: the subscribers of event/custom-input `id` in
--- dispatch order, each `{ group = <name or nil>, late = <boolean> }`. Works
--- even when `game == nil`. Not part of the public API.
---@param id any
---@return { group: string?, late: boolean }[]
function M._subscribers(id)
  local out = {}
  local entries = event_handlers[id]
  if entries then
    for _, entry in ipairs(entries) do
      table.insert(out, { group = entry.group, late = false })
    end
  end
  local late = late_event_handlers[id]
  if late then
    for _ in ipairs(late) do
      table.insert(out, { group = nil, late = true })
    end
  end
  return out
end

--- Internal test introspection: the currently active group names, sorted.
--- Works even when `game == nil`. Not part of the public API.
---@return string[]
function M._active_groups()
  local names = {}
  for name in pairs(active_groups) do
    if active_groups[name] then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

---@param kind "on_init"|"on_configuration_changed"
---@return integer
function M._handler_count(kind)
  if kind == "on_init" then
    return #init_handlers
  end
  if kind == "on_configuration_changed" then
    return #configuration_changed_handlers
  end
  error("exteros-lib event: unknown handler kind '" .. tostring(kind) .. "'", 2)
end

return M
