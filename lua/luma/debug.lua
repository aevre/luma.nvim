---@alias luma.DebugFields table<string, string|number|boolean|nil>

local M = {}

local function enabled()
  return require("luma.config").get().debug == true
end

---@param event string
---@param fields? luma.DebugFields
function M.log(event, fields)
  if not enabled() then
    return
  end
  local parts = { "luma debug:", event }
  local keys = vim.tbl_keys(fields or {})
  table.sort(keys)
  for _, key in ipairs(keys) do
    local value = fields[key]
    if value ~= nil then
      parts[#parts + 1] = ("%s=%s"):format(key, tostring(value):gsub("%s+", " "))
    end
  end
  vim.notify(table.concat(parts, " "), vim.log.levels.DEBUG)
end

return M
