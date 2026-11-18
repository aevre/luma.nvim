local M = {}

function M.list()
  return require("luma.config").get().models
end

function M.get(name)
  return require("luma.config").model(name)
end

function M.names()
  local names = {}
  for _, model in ipairs(M.list()) do
    names[#names + 1] = model.name
  end
  return names
end

return M
