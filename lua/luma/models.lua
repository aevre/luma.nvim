local M = {}

---@return luma.ModelConfig[]
function M.list()
  return require("luma.config").get().models
end

---@param name string
---@return luma.ModelConfig?
function M.get(name)
  return require("luma.config").model(name)
end

---@return string[]
function M.names()
  local names = {} ---@type string[]
  for _, model in ipairs(M.list()) do
    names[#names + 1] = model.name
  end
  return names
end

return M
