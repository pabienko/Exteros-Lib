--- Player lookup and validity helpers.
--- Stages: control.

local M = {}

--- Whether `player` is usable right now: not nil, not invalidated, and
--- connected. Use this before touching a player from an event handler, a
--- stored reference or a loop over every player.
---@param player LuaPlayer?
---@return boolean
function M.is_connected(player)
  return player ~= nil and player.valid and player.connected
end

--- `game.get_player(index)` if the result is valid, else nil. Unlike
--- `is_connected`, this does not require the player to be connected, so it
--- also returns an offline player.
---@param index integer
---@return LuaPlayer?
function M.get(index)
  local player = game.get_player(index)
  if player ~= nil and player.valid then
    return player
  end
  return nil
end

--- The player behind `event.player_index`, or nil if that player is not
--- connected right now. Use this at the top of an event handler instead of
--- `game.get_player` + `is_connected`.
---@param event { player_index: integer }
---@return LuaPlayer?
function M.from_event(event)
  local player = game.get_player(event.player_index)
  if M.is_connected(player) then
    return player
  end
  return nil
end

--- Whether `player` is an admin. Does not require `player` to be connected.
---@param player LuaPlayer?
---@return boolean
function M.is_admin(player)
  return player ~= nil and player.valid and player.admin
end

return M
