local hub = require("__exteros-lib__.internal.hub")

if not hub.active() then return end

local event = require("__exteros-lib__.event")
local migrate = require("__exteros-lib__.internal.migrate")

migrate.register({
  version = 1,
  init = function() end,
})

hub.init()

event.on(hub.NAME, hub.on_input)
event.on(defines.events.on_player_created, hub.on_player_created)
event.on(defines.events.on_lua_shortcut, hub.on_lua_shortcut)
event.on(defines.events.on_gui_click, hub.on_gui_click)
event.on(defines.events.on_gui_checked_state_changed, hub.on_gui_checked_state_changed)
event.on(defines.events.on_gui_value_changed, hub.on_gui_value_changed)
event.on(defines.events.on_gui_confirmed, hub.on_gui_confirmed)
event.on(defines.events.on_gui_selection_state_changed, hub.on_gui_selection_state_changed)
event.on(defines.events.on_gui_closed, hub.on_gui_closed)
event.on(defines.events.on_player_promoted, hub.on_player_promotion_changed)
event.on(defines.events.on_player_demoted, hub.on_player_promotion_changed)
event.on(defines.events.on_player_display_resolution_changed, hub.on_display_resolution_changed)
event.on(defines.events.on_player_display_scale_changed, hub.on_display_scale_changed)
event.on_configuration_changed(hub.close_all)

event.register()
