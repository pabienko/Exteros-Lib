local family = require("__exteros-lib__.internal.family")
local manifest_lib = require("__exteros-lib__.internal.manifest")
local lib_storage = require("__exteros-lib__.storage")
local lib_color = require("__exteros-lib__.color")
local lib_values = require("__exteros-lib__.internal.values")

local M = {}

M.NAME = "exteros-lib-hub"
M.FRAME = "exteros_lib_hub"
M.BODY = "exteros_lib_hub_body"
M.TAG = "exteros_lib_hub"
M.PANEL = "exteros_lib_hub_transfer"
M.PANEL_INPUT = "exteros_lib_hub_transfer_input"
M.COLUMNS = "exteros_lib_hub_columns"
M.LIST = "exteros_lib_hub_list"
M.RIGHT = "exteros_lib_hub_right"

local MOD_ORDER = { "Exteros-QoL-System", "Exteros-QoL-Cheats", "Exteros-QoL-Tweaks" }
local MOD_COLOR = {
  ["Exteros-QoL-System"] = "#84CDEC",
  ["Exteros-QoL-Cheats"] = "#E0807A",
  ["Exteros-QoL-Tweaks"] = "#8FD18F",
}

---@type { get: fun(player: LuaPlayer|integer): table, peek: fun(player: LuaPlayer|integer): table?, set: fun(player: LuaPlayer|integer, value: table): nil }?
local selected_feature = nil

---@class ExterosLibHubTransferPanel
---@field mode "export"|"import"|"result"
---@field text string?
---@field message LocalisedString?

---@type { get: fun(player: LuaPlayer|integer): ExterosLibHubTransferPanel, peek: fun(player: LuaPlayer|integer): ExterosLibHubTransferPanel?, set: fun(player: LuaPlayer|integer, value: ExterosLibHubTransferPanel): nil, clear: fun(player: LuaPlayer|integer): nil }?
local transfer_panel = nil

---@return boolean
function M.active()
  return prototypes.custom_input[M.NAME] ~= nil and prototypes.shortcut[M.NAME] ~= nil
end

---@return nil
function M.init()
  selected_feature = lib_storage.player_table("exteros_lib_hub_selected_feature")
  transfer_panel = lib_storage.player_table("exteros_lib_hub_transfer_panel")
end

---@param element LuaGuiElement?
---@return string?
local function role(element)
  if not element or not element.valid then return nil end
  if element.get_mod() ~= "exteros-lib" then return nil end
  return element.tags[M.TAG]
end

---@param player LuaPlayer
---@return LuaGuiElement?
function M.frame(player)
  local frame = player.gui.screen[M.FRAME]
  if frame and frame.valid then return frame end
  return nil
end

---@param player LuaPlayer
---@return nil
function M.close(player)
  local frame = M.frame(player)
  if frame then
    if player.opened == frame then
      player.opened = nil
    end
    if frame.valid then
      frame.destroy()
    end
  end
  player.set_shortcut_toggled(M.NAME, false)
  transfer_panel.clear(player.index)
end

---@param mod string
---@return string
local function values_iface(mod)
  return "exteros-lib-values-" .. mod
end

---@param manifest ExterosLibManifest
---@param feature ExterosLibFeatureDef
---@return boolean
local function feature_startup_enabled(manifest, feature)
  for _, setting in ipairs(feature.startup or {}) do
    if setting.name == "enabled" then
      local full_name = manifest_lib.setting_name(manifest, feature, setting)
      local def = settings.startup[full_name]
      if def ~= nil then return def.value == true end
      return setting.default == true
    end
  end
  return true
end

---@param manifest ExterosLibManifest
---@param feature ExterosLibFeatureDef
---@return string?
local function runtime_enabled_setting_name(manifest, feature)
  for _, setting in ipairs(feature.runtime_global or {}) do
    if setting.name == "enabled" then
      return manifest_lib.setting_name(manifest, feature, setting)
    end
  end
  return nil
end

---@class ExterosLibHubRow
---@field scope "global"|"player"
---@field name string
---@field type ExterosLibSettingType
---@field min number?
---@field max number?
---@field step number?
---@field allowed string[]?
---@field allow_blank boolean?
---@field value boolean|number|string

---@param described_rows table[]
---@param scope "global"|"player"
---@return ExterosLibHubRow[]
local function build_rows(described_rows, scope)
  local out = {}
  for _, item in ipairs(described_rows) do
    if not item.hidden then
      table.insert(out, {
        scope = scope,
        name = item.name,
        type = item.type,
        min = item.min,
        max = item.max,
        step = item.step,
        allowed = item.allowed,
        allow_blank = item.allow_blank,
        value = item.value,
      })
    end
  end
  return out
end

---@class ExterosLibHubFeature
---@field mod string
---@field feature string
---@field title_key string
---@field iface string
---@field global_rows ExterosLibHubRow[]
---@field player_rows ExterosLibHubRow[]

---@class ExterosLibHubMod
---@field mod string
---@field color string?
---@field features ExterosLibHubFeature[]

---@param player LuaPlayer
---@param mod string
---@param manifest ExterosLibManifest
---@return ExterosLibHubFeature[]
local function build_mod_features(player, mod, manifest)
  local iface = values_iface(mod)
  if remote.interfaces[iface] == nil then return {} end

  local described = remote.call(iface, "describe", player.index) --[[@as { features: table[] }]]

  local manifest_by_name = {}
  for _, feature in ipairs(manifest.features) do
    manifest_by_name[feature.name] = feature
  end

  local out = {}
  for _, described_feature in ipairs(described.features) do
    local feature = manifest_by_name[described_feature.name]
    if feature ~= nil and feature_startup_enabled(manifest, feature) then
      local global_rows = build_rows(described_feature.runtime_global, "global")
      local player_rows = build_rows(described_feature.runtime_per_user, "player")

      local enabled_name = runtime_enabled_setting_name(manifest, feature)
      if enabled_name ~= nil then
        local enabled_value = true
        for _, row in ipairs(global_rows) do
          if row.name == enabled_name then enabled_value = row.value == true end
        end
        if not enabled_value then
          local kept = {}
          for _, row in ipairs(global_rows) do
            if row.name == enabled_name then table.insert(kept, row) end
          end
          global_rows = kept
          player_rows = {}
        end
      end

      local visible_global = player.admin and global_rows or {}
      local visible_player = player_rows

      if #visible_global > 0 or #visible_player > 0 then
        table.insert(out, {
          mod = mod,
          feature = feature.name,
          title_key = manifest.prefix .. feature.name,
          iface = iface,
          global_rows = visible_global,
          player_rows = visible_player,
        })
      end
    end
  end

  return out
end

---@param clients table<string, { manifest: ExterosLibManifest, blocked: table<string, string> }>
---@return string[]
local function ordered_mod_names(clients)
  local names = {}
  for name in pairs(clients) do
    table.insert(names, name)
  end
  table.sort(names)

  local seen = {}
  local result = {}
  for _, name in ipairs(MOD_ORDER) do
    if clients[name] ~= nil then
      table.insert(result, name)
      seen[name] = true
    end
  end
  for _, name in ipairs(names) do
    if not seen[name] then table.insert(result, name) end
  end
  return result
end

---@param player LuaPlayer
---@return ExterosLibHubMod[]
function M.build(player)
  local clients = family.clients()
  local out = {}

  for _, mod in ipairs(ordered_mod_names(clients)) do
    local features = build_mod_features(player, mod, clients[mod].manifest)
    if #features > 0 then
      table.insert(out, { mod = mod, color = MOD_COLOR[mod], features = features })
    end
  end

  return out
end

---@param mods ExterosLibHubMod[]
---@param mod string
---@param feature string
---@return boolean
local function has_feature(mods, mod, feature)
  for _, m in ipairs(mods) do
    if m.mod == mod then
      for _, f in ipairs(m.features) do
        if f.feature == feature then return true end
      end
    end
  end
  return false
end

---@param mods ExterosLibHubMod[]
---@param mod string
---@param feature string
---@return ExterosLibHubFeature?
local function find_feature(mods, mod, feature)
  for _, m in ipairs(mods) do
    if m.mod == mod then
      for _, f in ipairs(m.features) do
        if f.feature == feature then return f end
      end
    end
  end
  return nil
end

---@param player LuaPlayer
---@param mods ExterosLibHubMod[]
---@return string?, string?
local function selected_mod_feature(player, mods)
  local stored = selected_feature.peek(player.index)
  if stored and has_feature(mods, stored.mod, stored.feature) then
    return stored.mod, stored.feature
  end
  local first = mods[1]
  if first == nil then return nil, nil end
  local first_feature = first.features[1]
  if first_feature == nil then return nil, nil end
  return first.mod, first_feature.feature
end

---@param row ExterosLibHubRow
---@return boolean|number|string
local function clamp_for_display(row)
  if row.type ~= "int" and row.type ~= "double" then return row.value end
  local value = row.value --[[@as number]]
  local min = row.min or 0
  local max = row.max or value
  if value < min then value = min end
  if value > max then value = max end
  return value
end

---@param parent LuaGuiElement
---@param mod string
---@param feature string
---@param iface string
---@param row ExterosLibHubRow
---@return nil
local function add_row(parent, mod, feature, iface, row)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  flow.style.horizontal_spacing = 8
  flow.style.vertical_align = "center"

  local label = flow.add({
    type = "label",
    caption = { "exteros-lib-setting-name." .. row.name },
    tooltip = { "exteros-lib-setting-description." .. row.name },
  })
  label.style.width = 220

  ---@param kind string
  ---@param allowed string[]?
  ---@return table
  local function make_tags(kind, allowed)
    return {
      [M.TAG] = "control",
      mod = mod,
      feature = feature,
      iface = iface,
      scope = row.scope,
      setting = row.name,
      kind = kind,
      allowed = allowed,
    }
  end

  if row.type == "bool" then
    flow.add({
      type = "checkbox",
      state = row.value --[[@as boolean]],
      tags = make_tags("bool"),
    })
  elseif row.type == "int" or row.type == "double" then
    local value = clamp_for_display(row)
    local min = row.min or 0
    local max = row.max or value

    local slider = flow.add({
      type = "slider",
      minimum_value = min,
      maximum_value = max,
      value = value,
      value_step = row.step,
      tags = make_tags("slider"),
    })
    slider.style.minimal_width = 120
    slider.style.maximal_width = 160

    local textfield = flow.add({
      type = "textfield",
      text = tostring(value),
      numeric = true,
      allow_decimal = (row.type == "double"),
      allow_negative = min < 0,
      lose_focus_on_confirm = true,
      tags = make_tags("number_text"),
    })
    textfield.style.minimal_width = 70
    textfield.style.maximal_width = 90
  elseif row.type == "string" and row.allowed ~= nil then
    local items = {}
    for i, value in ipairs(row.allowed) do
      items[i] = { "exteros-lib-setting-option." .. row.name .. "-" .. value }
    end
    local selected_index = 1
    for i, value in ipairs(row.allowed) do
      if value == row.value then selected_index = i end
    end

    local dropdown = flow.add({
      type = "drop-down",
      items = items,
      selected_index = selected_index,
      tags = make_tags("dropdown", row.allowed),
    })
    dropdown.style.minimal_width = 120
  elseif row.type == "string" then
    local textfield = flow.add({
      type = "textfield",
      text = row.value --[[@as string]],
      numeric = false,
      lose_focus_on_confirm = true,
      tags = make_tags("string_text"),
    })
    textfield.style.minimal_width = 120
    textfield.style.maximal_width = 160
  end
end

---@param body LuaGuiElement
---@param player LuaPlayer
---@param mods ExterosLibHubMod[]
---@param mod string
---@param feature_name string
---@return nil
local function build_right_pane(body, player, mods, mod, feature_name)
  local feature = find_feature(mods, mod, feature_name)
  if feature == nil then return end

  local right = body.add({
    type = "frame",
    name = M.RIGHT,
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
    tags = { [M.TAG] = "settings", mod = mod, feature = feature_name },
  })
  right.style.horizontally_stretchable = true
  right.style.vertically_stretchable = true

  local content = right.add({ type = "scroll-pane" })
  content.style.minimal_width = 420
  content.style.horizontally_stretchable = true
  content.style.vertically_stretchable = true

  local inner = content.add({ type = "flow", direction = "vertical" })
  inner.style.vertical_spacing = 16

  local heading = inner.add({
    type = "label",
    caption = { "exteros-lib-feature-name." .. feature.title_key },
    style = "subheader_caption_label",
  })
  local mod_color = nil
  for _, m in ipairs(mods) do
    if m.mod == mod then mod_color = m.color end
  end
  if mod_color ~= nil then
    heading.style.font_color = lib_color.parse_hex(mod_color, lib_color.WHITE)
  end

  local show_section_captions = #feature.player_rows > 0 and #feature.global_rows > 0

  if #feature.player_rows > 0 then
    if show_section_captions then
      local caption = inner.add({ type = "label", caption = { "exteros-lib-hub.section-per-user" } })
      caption.style.font = "default-bold"
      caption.style.bottom_padding = 4
    end
    local rows_flow = inner.add({ type = "flow", direction = "vertical" })
    rows_flow.style.vertical_spacing = 8
    for _, row in ipairs(feature.player_rows) do
      add_row(rows_flow, mod, feature_name, feature.iface, row)
    end
  end

  if #feature.global_rows > 0 then
    if show_section_captions then
      local caption = inner.add({ type = "label", caption = { "exteros-lib-hub.section-global" } })
      caption.style.font = "default-bold"
      caption.style.bottom_padding = 4
    end
    local rows_flow = inner.add({ type = "flow", direction = "vertical" })
    rows_flow.style.vertical_spacing = 8
    for _, row in ipairs(feature.global_rows) do
      add_row(rows_flow, mod, feature_name, feature.iface, row)
    end
  end
end

---@param root LuaGuiElement
---@param predicate fun(tags: table): boolean
---@return LuaGuiElement?
local function find_control(root, predicate)
  if not root.valid then return nil end
  if root.tags and root.tags[M.TAG] == "control" and predicate(root.tags) then return root end
  for _, child in pairs(root.children) do
    local found = find_control(child, predicate)
    if found then return found end
  end
  return nil
end

---@param rows ExterosLibHubRow[]
---@param into table<string, boolean>
---@return nil
local function add_row_keys(rows, into)
  for _, row in ipairs(rows) do
    into[row.scope .. ":" .. row.name] = true
  end
end

---@param right LuaGuiElement
---@return table<string, boolean>
local function current_row_keys(right)
  local keys = {}
  local function walk(element)
    if not element.valid then return end
    if element.tags and element.tags[M.TAG] == "control" then
      keys[element.tags.scope .. ":" .. element.tags.setting] = true
    end
    for _, child in pairs(element.children) do walk(child) end
  end
  walk(right)
  return keys
end

---@param a table<string, boolean>
---@param b table<string, boolean>
---@return boolean
local function same_keys(a, b)
  for key in pairs(a) do
    if not b[key] then return false end
  end
  for key in pairs(b) do
    if not a[key] then return false end
  end
  return true
end

---@param right LuaGuiElement
---@param feature ExterosLibHubFeature
---@return boolean
local function settings_structure_changed(right, feature)
  local new_keys = {}
  add_row_keys(feature.global_rows, new_keys)
  add_row_keys(feature.player_rows, new_keys)
  return not same_keys(current_row_keys(right), new_keys)
end

---@param right LuaGuiElement
---@param row ExterosLibHubRow
---@param skip_index uint?
---@return nil
local function sync_row_display(right, row, skip_index)
  if row.type == "bool" then
    local checkbox = find_control(right, function(tags) return tags.setting == row.name and tags.kind == "bool" end)
    if checkbox then checkbox.state = row.value --[[@as boolean]] end
  elseif row.type == "int" or row.type == "double" then
    local value = clamp_for_display(row) --[[@as number]]
    local slider = find_control(right, function(tags) return tags.setting == row.name and tags.kind == "slider" end)
    if slider and slider.index ~= skip_index then slider.slider_value = value end
    local textfield = find_control(right, function(tags) return tags.setting == row.name and tags.kind == "number_text" end)
    if textfield then textfield.text = tostring(value) end
  elseif row.type == "string" and row.allowed ~= nil then
    local dropdown = find_control(right, function(tags) return tags.setting == row.name and tags.kind == "dropdown" end)
    if dropdown then
      for i, allowed_value in ipairs(row.allowed) do
        if allowed_value == row.value then dropdown.selected_index = i end
      end
    end
  elseif row.type == "string" then
    local textfield = find_control(right, function(tags) return tags.setting == row.name and tags.kind == "string_text" end)
    if textfield then textfield.text = row.value --[[@as string]] end
  end
end

---@return string[]
local function values_remote_clients()
  local clients = family.clients()
  local with_remote = {}
  for name in pairs(clients) do
    if remote.interfaces[values_iface(name)] ~= nil then
      with_remote[name] = true
    end
  end
  return ordered_mod_names(with_remote)
end

---@param player LuaPlayer
---@return string
local function build_export_string(player)
  local tables_by_mod = {}
  for _, mod in ipairs(values_remote_clients()) do
    local exported = remote.call(values_iface(mod), "export_table", player.index) --[[@as table]]
    if not player.admin then
      exported = { mod = exported.mod, version = exported.version, global = {}, player = exported.player }
    end
    tables_by_mod[mod] = exported
  end
  return lib_values.encode(tables_by_mod)
end

---@param player LuaPlayer
---@param text string
---@return LocalisedString, boolean
local function run_import(player, text)
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then
    return { "exteros-lib-hub.error-empty" }, false
  end

  local envelope, err = lib_values.decode(trimmed)
  if envelope == nil then
    if err == "unsupported format" then
      return { "exteros-lib-hub.error-format" }, false
    end
    return { "exteros-lib-hub.error-invalid" }, false
  end

  local mod_names = {}
  for name in pairs(envelope.mods) do mod_names[name] = true end

  local applied, clamped, skipped, refused = 0, 0, 0, 0
  local unknown_mods = {}
  local has_global_change = false

  for _, mod in ipairs(ordered_mod_names(mod_names)) do
    local iface = values_iface(mod)
    if remote.interfaces[iface] == nil then
      table.insert(unknown_mods, mod)
    else
      local report = remote.call(iface, "import_table", player.index, envelope.mods[mod]) --[[@as table]]
      applied = applied + #report.applied
      clamped = clamped + #report.clamped
      skipped = skipped + #report.skipped_unknown
      refused = refused + #report.refused_not_admin
      for _, label in ipairs(report.applied) do
        if label:sub(1, 7) == "global:" then has_global_change = true end
      end
    end
  end

  local lines = {}
  if applied > 0 then table.insert(lines, { "exteros-lib-hub.result-applied", applied }) end
  if clamped > 0 then table.insert(lines, { "exteros-lib-hub.result-clamped", clamped }) end
  if skipped > 0 then table.insert(lines, { "exteros-lib-hub.result-skipped", skipped }) end
  if refused > 0 then table.insert(lines, { "exteros-lib-hub.result-refused", refused }) end
  for _, mod in ipairs(unknown_mods) do
    table.insert(lines, { "exteros-lib-hub.result-unknown-mod", mod })
  end

  local message = { "" }
  for i, line in ipairs(lines) do
    if i > 1 then table.insert(message, "\n") end
    table.insert(message, line)
  end

  return message, has_global_change
end

---@param body LuaGuiElement
---@param player LuaPlayer
---@return nil
local function build_transfer_footer(body, player)
  local footer = body.add({ type = "flow", direction = "horizontal" })
  footer.style.top_padding = 8
  footer.style.horizontal_spacing = 8
  footer.add({
    type = "button",
    caption = { "exteros-lib-hub.export" },
    tags = { [M.TAG] = "export" },
  })
  footer.add({
    type = "button",
    caption = { "exteros-lib-hub.import" },
    tags = { [M.TAG] = "import" },
  })

  local panel_state = transfer_panel.peek(player.index)
  if panel_state == nil then return end

  local panel = body.add({
    type = "frame",
    name = M.PANEL,
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
    tags = { [M.TAG] = "transfer" },
  })
  panel.style.top_padding = 8

  if panel_state.mode == "export" then
    panel.add({ type = "label", caption = { "exteros-lib-hub.export-caption" } })
    local textbox = panel.add({
      type = "text-box",
      name = M.PANEL_INPUT,
      text = panel_state.text,
    })
    textbox.read_only = true
    textbox.style.minimal_width = 420
    textbox.style.minimal_height = 120
    textbox.select_all()
    textbox.focus()
  elseif panel_state.mode == "import" then
    panel.add({ type = "label", caption = { "exteros-lib-hub.import-caption" } })
    local textbox = panel.add({ type = "text-box", name = M.PANEL_INPUT, text = "" })
    textbox.style.minimal_width = 420
    textbox.style.minimal_height = 120
  elseif panel_state.mode == "result" then
    panel.add({ type = "label", caption = panel_state.message })
  end

  local buttons = panel.add({ type = "flow", direction = "horizontal" })
  buttons.style.top_padding = 8
  buttons.style.horizontal_spacing = 8
  if panel_state.mode == "import" then
    buttons.add({
      type = "button",
      caption = { "exteros-lib-hub.import-confirm" },
      tags = { [M.TAG] = "import-confirm" },
    })
  end
  buttons.add({
    type = "button",
    caption = { "exteros-lib-hub.transfer-close" },
    tags = { [M.TAG] = "transfer-close" },
  })
end

---@param player LuaPlayer
---@param has_global_change boolean
---@return nil
local function after_transfer(player, has_global_change)
  M.render(player)
  if has_global_change then
    for _, other in pairs(game.players) do
      if other.valid and other.index ~= player.index and M.frame(other) ~= nil then
        M.render(other)
      end
    end
  end
end

---@param player LuaPlayer
---@return nil
function M.render(player)
  local frame = M.frame(player)
  if frame == nil then return end

  local old_body = frame[M.BODY]
  if old_body ~= nil and old_body.valid then old_body.destroy() end

  local body = frame.add({ type = "flow", name = M.BODY, direction = "vertical", tags = { [M.TAG] = "body" } })
  body.style.horizontally_stretchable = true
  body.style.vertically_stretchable = true

  local mods = M.build(player)
  if #mods == 0 then
    body.add({ type = "label", caption = { "exteros-lib-hub.no-runtime-settings" } })
    return
  end

  local selected_mod, selected_name = selected_mod_feature(player, mods)
  if selected_mod ~= nil and selected_name ~= nil then
    selected_feature.set(player.index, { mod = selected_mod, feature = selected_name })
  end

  local columns = body.add({ type = "flow", name = M.COLUMNS, direction = "horizontal" })
  columns.style.horizontal_spacing = 8
  columns.style.horizontally_stretchable = true
  columns.style.vertically_stretchable = true

  local list_scroll = columns.add({ type = "scroll-pane", name = M.LIST })
  list_scroll.style.width = 200
  list_scroll.style.vertically_stretchable = true

  local list = list_scroll.add({ type = "flow", direction = "vertical" })

  for _, mod in ipairs(mods) do
    list.add({
      type = "label",
      caption = { "mod-name." .. mod.mod },
      style = "caption_label",
    })
    for _, feature in ipairs(mod.features) do
      local caption = { "exteros-lib-feature-name." .. feature.title_key }
      if mod.color ~= nil then
        caption = { "", "[color=" .. mod.color .. "]", caption, "[/color]" }
      end
      list.add({
        type = "button",
        style = "list_box_item",
        caption = caption,
        toggled = mod.mod == selected_mod and feature.feature == selected_name,
        tags = { [M.TAG] = "feature", mod = mod.mod, feature = feature.feature },
      })
    end
  end

  if selected_mod ~= nil and selected_name ~= nil then
    build_right_pane(columns, player, mods, selected_mod, selected_name)
  end

  build_transfer_footer(body, player)
end

---@param player LuaPlayer
---@return { width: integer, height: integer }
function M.frame_size(player)
  local resolution = player.display_resolution
  local scale = player.display_scale
  return {
    width = math.floor(resolution.width / scale * 0.6),
    height = math.floor(resolution.height / scale * 0.6),
  }
end

---@param player LuaPlayer
---@return nil
local function apply_frame_size(player)
  local frame = M.frame(player)
  if frame == nil then return end
  local size = M.frame_size(player)
  frame.style.width = size.width
  frame.style.height = size.height
end

---@param player LuaPlayer
---@return nil
function M.open(player)
  if M.frame(player) then return end

  local frame = player.gui.screen.add({
    type = "frame",
    name = M.FRAME,
    direction = "vertical",
    tags = { [M.TAG] = "frame" },
  })

  local titlebar = frame.add({ type = "flow", direction = "horizontal" })
  titlebar.drag_target = frame
  titlebar.style.horizontal_spacing = 8
  titlebar.add({
    type = "label",
    style = "frame_title",
    caption = { "exteros-lib-hub.title" },
    ignored_by_interaction = true,
  })
  local filler = titlebar.add({
    type = "empty-widget",
    style = "draggable_space_header",
    ignored_by_interaction = true,
  })
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  filler.style.right_margin = 4
  titlebar.add({
    type = "sprite-button",
    style = "frame_action_button",
    sprite = "utility/close",
    tooltip = { "gui.close-instruction" },
    tags = { [M.TAG] = "close" },
  })

  M.render(player)
  apply_frame_size(player)

  frame.force_auto_center()
  player.opened = frame
  player.set_shortcut_toggled(M.NAME, true)
end

---@param player LuaPlayer
---@return nil
function M.toggle(player)
  if M.frame(player) then
    M.close(player)
  else
    M.open(player)
  end
end

---@param player_index integer
---@return LuaPlayer?
local function player_of(player_index)
  local player = game.get_player(player_index)
  if player and player.valid then return player end
  return nil
end

---@param e EventData.CustomInputEvent
---@return nil
function M.on_input(e)
  local player = player_of(e.player_index)
  if player then M.toggle(player) end
end

---@param e EventData.on_lua_shortcut
---@return nil
function M.on_lua_shortcut(e)
  if e.prototype_name ~= M.NAME then return end
  local player = player_of(e.player_index)
  if player then M.toggle(player) end
end

---@param player LuaPlayer
---@param tags table
---@param value boolean|number|string
---@return boolean
local function attempt_set(player, tags, value)
  if tags.scope == "global" and not player.admin then return false end
  return remote.call(tags.iface, "set", player.index, tags.scope, tags.setting, value) --[[@as boolean]]
end

---@param player LuaPlayer
---@return nil
local function refresh_selection(player)
  local frame = M.frame(player)
  if frame == nil then return end
  local body = frame[M.BODY]
  if body == nil or not body.valid then return end
  local columns = body[M.COLUMNS]
  if columns == nil or not columns.valid then return end

  local mods = M.build(player)
  local selected_mod, selected_name = selected_mod_feature(player, mods)

  local list_scroll = columns[M.LIST]
  if list_scroll ~= nil and list_scroll.valid then
    local list = list_scroll.children[1]
    if list ~= nil and list.valid then
      for _, child in pairs(list.children) do
        if child.tags and child.tags[M.TAG] == "feature" then
          child.toggled = child.tags.mod == selected_mod and child.tags.feature == selected_name
        end
      end
    end
  end

  local right = columns[M.RIGHT]
  if right ~= nil and right.valid then right.destroy() end
  if selected_mod ~= nil and selected_name ~= nil then
    build_right_pane(columns, player, mods, selected_mod, selected_name)
  end
end

---@param player LuaPlayer
---@param tags table
---@param ok boolean
---@param source LuaGuiElement?
---@return nil
local function refresh_after_write(player, tags, ok, source)
  if ok and tags.scope == "global" then
    for _, other in pairs(game.players) do
      if other.valid and other.index ~= player.index and M.frame(other) ~= nil then
        M.render(other)
      end
    end
  end

  local frame = M.frame(player)
  if frame == nil then return end
  local body = frame[M.BODY]
  if body == nil or not body.valid then return end
  local columns = body[M.COLUMNS]
  if columns == nil or not columns.valid then return end
  local right = columns[M.RIGHT]
  if right == nil or not right.valid then return end
  if right.tags.mod ~= tags.mod or right.tags.feature ~= tags.feature then return end

  local mods = M.build(player)
  local feature = find_feature(mods, tags.mod, tags.feature)
  if feature == nil then
    M.render(player)
    return
  end

  if settings_structure_changed(right, feature) then
    right.destroy()
    build_right_pane(columns, player, mods, tags.mod, tags.feature)
    return
  end

  local skip_index = (ok and source ~= nil and source.valid) and source.index or nil
  for _, row in ipairs(feature.global_rows) do sync_row_display(right, row, skip_index) end
  for _, row in ipairs(feature.player_rows) do sync_row_display(right, row, skip_index) end
end

---@param e EventData.on_gui_click
---@return nil
function M.on_gui_click(e)
  local kind = role(e.element)
  if kind == "close" then
    local player = player_of(e.player_index)
    if player then M.close(player) end
    return
  end
  if kind == "feature" then
    local player = player_of(e.player_index)
    if player == nil then return end
    selected_feature.set(player.index, { mod = e.element.tags.mod, feature = e.element.tags.feature })
    refresh_selection(player)
    return
  end
  if kind == "export" then
    local player = player_of(e.player_index)
    if player == nil then return end
    transfer_panel.set(player.index, { mode = "export", text = build_export_string(player) })
    M.render(player)
    return
  end
  if kind == "import" then
    local player = player_of(e.player_index)
    if player == nil then return end
    transfer_panel.set(player.index, { mode = "import" })
    M.render(player)
    return
  end
  if kind == "transfer-close" then
    local player = player_of(e.player_index)
    if player == nil then return end
    transfer_panel.clear(player.index)
    M.render(player)
    return
  end
  if kind == "import-confirm" then
    local player = player_of(e.player_index)
    if player == nil then return end
    local frame = M.frame(player)
    local panel = frame and frame[M.BODY] and frame[M.BODY][M.PANEL]
    local input = panel and panel[M.PANEL_INPUT]
    local text = (input ~= nil and input.valid) and input.text or ""
    local message, has_global_change = run_import(player, text)
    transfer_panel.set(player.index, { mode = "result", message = message })
    after_transfer(player, has_global_change)
    return
  end
end

---@param e EventData.on_gui_checked_state_changed
---@return nil
function M.on_gui_checked_state_changed(e)
  if role(e.element) ~= "control" or e.element.tags.kind ~= "bool" then return end
  local player = player_of(e.player_index)
  if player == nil then return end

  local ok = attempt_set(player, e.element.tags, e.element.state)
  refresh_after_write(player, e.element.tags, ok)
end

---@param e EventData.on_gui_value_changed
---@return nil
function M.on_gui_value_changed(e)
  if role(e.element) ~= "control" or e.element.tags.kind ~= "slider" then return end
  local player = player_of(e.player_index)
  if player == nil then return end

  local value = e.element.slider_value
  local tags = e.element.tags
  local row_type = "double"
  for _, child in pairs(e.element.parent.children) do
    if child.tags[M.TAG] == "control" and child.tags.setting == tags.setting and child.tags.kind == "number_text" then
      row_type = child.allow_decimal and "double" or "int"
    end
  end
  if row_type == "int" then value = math.floor(value + 0.5) end

  local ok = attempt_set(player, tags, value)
  refresh_after_write(player, tags, ok, e.element)
end

---@param e EventData.on_gui_confirmed
---@return nil
function M.on_gui_confirmed(e)
  if role(e.element) ~= "control" then return end
  local kind = e.element.tags.kind
  if kind ~= "number_text" and kind ~= "string_text" then return end
  local player = player_of(e.player_index)
  if player == nil then return end

  if kind == "string_text" then
    local value = e.element.text
    local ok = attempt_set(player, e.element.tags, value)
    refresh_after_write(player, e.element.tags, ok)
    return
  end

  local text = e.element.text
  local value = tonumber(text)
  if value == nil then
    refresh_after_write(player, e.element.tags, false)
    return
  end

  local ok = attempt_set(player, e.element.tags, value)
  refresh_after_write(player, e.element.tags, ok)
end

---@param e EventData.on_gui_selection_state_changed
---@return nil
function M.on_gui_selection_state_changed(e)
  if role(e.element) ~= "control" or e.element.tags.kind ~= "dropdown" then return end
  local player = player_of(e.player_index)
  if player == nil then return end

  local allowed = e.element.tags.allowed --[[@as string[] ]]
  local value = allowed[e.element.selected_index]

  local ok = attempt_set(player, e.element.tags, value)
  refresh_after_write(player, e.element.tags, ok)
end

---@param e EventData.on_gui_closed
---@return nil
function M.on_gui_closed(e)
  if role(e.element) ~= "frame" then return end
  local player = player_of(e.player_index)
  if player then M.close(player) end
end

---@param e EventData.on_player_promoted|EventData.on_player_demoted
---@return nil
function M.on_player_promotion_changed(e)
  local player = player_of(e.player_index)
  if player and M.frame(player) ~= nil then M.render(player) end
end

---@param e EventData.on_player_display_resolution_changed
---@return nil
function M.on_display_resolution_changed(e)
  local player = player_of(e.player_index)
  if player and M.frame(player) ~= nil then apply_frame_size(player) end
end

---@param e EventData.on_player_display_scale_changed
---@return nil
function M.on_display_scale_changed(e)
  local player = player_of(e.player_index)
  if player and M.frame(player) ~= nil then apply_frame_size(player) end
end

---@return nil
function M.close_all()
  for _, player in pairs(game.players) do
    if player.valid then M.close(player) end
  end
end

return M
