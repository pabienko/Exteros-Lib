--- Static tables describing entity, player and item behaviour that Factorio
--- itself does not expose directly. Treat every table here as read-only.
--- Stages: any.

local M = {}

--- Which inventories to move when transferring items into or out of an
--- entity, keyed by entity type. Use it to walk every inventory an entity
--- can hold without hard-coding the list per type.
---@type table<string, defines.inventory[]>
M.ENTITY_TRANSFER_INVENTORIES = {
  ["agricultural-tower"] = {
    defines.inventory.fuel,
    defines.inventory.agricultural_tower_input,
  },
  ["ammo-turret"] = { defines.inventory.turret_ammo },
  ["artillery-turret"] = { defines.inventory.artillery_turret_ammo },
  ["artillery-wagon"] = { defines.inventory.artillery_wagon_ammo },
  ["assembling-machine"] = {
    defines.inventory.fuel,
    defines.inventory.crafter_input,
    defines.inventory.crafter_modules,
  },
  ["asteroid-collector"] = { defines.inventory.asteroid_collector_output },
  ["beacon"] = { defines.inventory.fuel, defines.inventory.beacon_modules },
  ["boiler"] = { defines.inventory.fuel },
  ["burner-generator"] = { defines.inventory.fuel },
  ["car"] = { defines.inventory.fuel, defines.inventory.car_ammo, defines.inventory.car_trunk },
  ["cargo-landing-pad"] = { defines.inventory.cargo_landing_pad_main },
  ["cargo-wagon"] = { defines.inventory.cargo_wagon },
  ["character"] = {
    defines.inventory.character_ammo,
    defines.inventory.character_armor,
    defines.inventory.character_guns,
    defines.inventory.character_main,
    defines.inventory.character_vehicle,
  },
  ["container"] = { defines.inventory.chest },
  ["furnace"] = {
    defines.inventory.fuel,
    defines.inventory.crafter_input,
    defines.inventory.crafter_modules,
  },
  ["fusion-reactor"] = { defines.inventory.fuel },
  ["inserter"] = { defines.inventory.fuel },
  ["lab"] = {
    defines.inventory.fuel,
    defines.inventory.lab_input,
    defines.inventory.lab_modules,
  },
  ["infinity-container"] = { defines.inventory.chest },
  ["linked-container"] = { defines.inventory.linked_container_main },
  ["locomotive"] = { defines.inventory.fuel },
  ["logistic-container"] = { defines.inventory.chest },
  ["mining-drill"] = { defines.inventory.fuel, defines.inventory.mining_drill_modules },
  ["reactor"] = { defines.inventory.fuel },
  ["roboport"] = {
    defines.inventory.fuel,
    defines.inventory.roboport_material,
    defines.inventory.roboport_robot,
  },
  ["rocket-silo"] = {
    defines.inventory.fuel,
    defines.inventory.crafter_input,
    defines.inventory.crafter_modules,
    defines.inventory.rocket_silo_rocket,
  },
  ["space-platform-hub"] = { defines.inventory.hub_main },
  ["spider-vehicle"] = { defines.inventory.fuel, defines.inventory.spider_ammo, defines.inventory.spider_trunk },
  ["temporary-container"] = { defines.inventory.chest },
}

--- Which inventories to move when transferring items into or out of a
--- player, keyed by the player's current controller type.
---@type table<defines.controllers, defines.inventory[]>
M.PLAYER_TRANSFER_INVENTORIES = {
  [defines.controllers.character] = { defines.inventory.character_main },
  [defines.controllers.cutscene] = {},
  [defines.controllers.editor] = { defines.inventory.editor_main },
  [defines.controllers.ghost] = {},
  [defines.controllers.god] = { defines.inventory.god_main },
  [defines.controllers.remote] = {},
  [defines.controllers.spectator] = {},
}

--- Item types that carry extra data beyond a plain stack (blueprints,
--- armor, items with inventories, ...). Use it to tell apart items that
--- need special handling when moved or counted.
---@type table<string, boolean>
M.COMPLEX_ITEM_TYPES = {
  ["item-with-entity-data"] = true,
  ["armor"] = true,
  ["spidertron-remote"] = true,
  ["blueprint"] = true,
  ["blueprint-book"] = true,
  ["upgrade-item"] = true,
  ["deconstruction-item"] = true,
  ["item-with-inventory"] = true,
  ["item-with-label"] = true,
}

return M
