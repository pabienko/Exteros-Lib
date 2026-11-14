--- Player notifications.
--- Stages: control.

local M = {}

--- Flying text for `player`, wrapping `LuaPlayer.create_local_flying_text`.
--- Pass exactly one of `opts.position`/`opts.create_at_cursor` for where it
--- appears; `opts.color`, `opts.speed` and `opts.time_to_live` map directly.
---@param player LuaPlayer
---@param text LocalisedString
---@param opts { position: MapPosition?, create_at_cursor: boolean?, color: Color?, speed: number?, time_to_live: integer? }?
---@return nil
function M.flying(player, text, opts)
  opts = opts or {}
  player.create_local_flying_text({
    text = text,
    position = opts.position,
    create_at_cursor = opts.create_at_cursor,
    color = opts.color,
    speed = opts.speed,
    time_to_live = opts.time_to_live,
  })
end

return M
