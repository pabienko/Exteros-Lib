local M = {}

---@class ExterosLibDebugLogger
---@field is_enabled fun(): boolean
---@field log fun(message: any, category: string?)
---@field dump fun(tbl: any, category: string?)
---@field error fun(message: any)
---@field reset_cache fun()

---@param prefix string
---@param label string
---@return ExterosLibDebugLogger
function M.new(prefix, label)
  if type(prefix) ~= "string" or prefix == "" then
    error("exteros-lib debug: prefix must be a non-empty string", 2)
  end
  if type(label) ~= "string" or label == "" then
    error("exteros-lib debug: label must be a non-empty string", 2)
  end

  local setting_name = prefix .. "debug-enabled"
  local enabled = nil

  local logger = {}

  ---@return boolean
  local function is_enabled()
    if enabled == nil then
      local success, result = pcall(function()
        return settings.startup[setting_name].value
      end)
      enabled = success and result == true
    end
    return enabled
  end

  function logger.is_enabled()
    return is_enabled()
  end

  function logger.log(message, category)
    if not is_enabled() then return end
    log("[" .. label .. (category and (":" .. category) or "") .. "] " .. tostring(message))
  end

  function logger.dump(tbl, category)
    if not is_enabled() then return end
    local success, result = pcall(function()
      return serpent.line(tbl)
    end)
    logger.log(success and result or "Failed to dump table", category)
  end

  function logger.error(message)
    log("[" .. label .. " ERROR] " .. tostring(message))
  end

  function logger.reset_cache()
    enabled = nil
  end

  return logger
end

return M
