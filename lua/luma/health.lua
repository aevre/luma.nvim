local M = {}

local health = vim.health
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error

local function module(name)
  local loaded = pcall(require, name)
  if loaded then
    ok(("Module `%s` is available"):format(name))
  else
    error(("Module `%s` is required"):format(name))
  end
end

function M.check()
  start("luma.nvim")
  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim 0.10+ is available")
  else
    error("Neovim 0.10+ is required")
  end

  module("win")
  module("animate")

  if vim.fn.executable("curl") == 1 then
    ok("`curl` is available")
  else
    error("`curl` is required and must be in $PATH")
  end

  local models = require("luma.models").list()
  if #models == 0 then
    error("No models are configured")
    return
  end
  ok(("%d model(s) configured"):format(#models))

  for _, model in ipairs(models) do
    if model.backend == "ollama" then
      ok(("Model `%s` uses Ollama and does not require an API key"):format(model.name))
    else
      local key = model.api_key
      if key == nil or key == "" then
        warn(("Model `%s` has no API key configured"):format(model.name))
      elseif type(key) == "function" then
        ok(("Model `%s` has an API key callback configured"):format(model.name))
      elseif vim.env[key] and vim.env[key] ~= "" then
        ok(("Model `%s` API key environment variable is set"):format(model.name))
      elseif key:match("^[A-Z][A-Z0-9_]+$") then
        warn(("Model `%s` may reference an unset API key environment variable"):format(model.name))
      else
        ok(("Model `%s` has an API key configured"):format(model.name))
      end
    end
  end
end

return M
