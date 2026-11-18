local M = {}
local bootstrapped = false

local function complete(values)
  return function(arg)
    return vim.tbl_filter(function(value)
      return value:sub(1, #arg) == arg
    end, values())
  end
end

function M.setup(opts)
  local config = require("luma.config").setup(opts)
  require("luma.tools").setup(config.tools)
  package.loaded["luma.models"] = nil
  require("luma.ui").destroy()
  require("luma.session").new()
  return M
end

function M.toggle()
  local ui = require("luma.ui")
  if ui.valid() then
    ui.hide()
  else
    ui.open()
    require("luma.session").render()
  end
end

function M.submit(text)
  require("luma.ui").open()
  require("luma.session").submit(text)
end

function M.cancel()
  require("luma.session").cancel()
  require("luma.tools").cancel()
end

function M.new()
  require("luma.ui").open()
  require("luma.session").new()
  require("luma.ui").focus_input()
end

function M.resend()
  require("luma.session").resend()
end

function M.history()
  local history = require("luma.history").list()
  if #history == 0 then
    vim.notify("luma: no saved history", vim.log.levels.INFO)
    return
  end
  vim.ui.select(history, {
    prompt = "Luma history: ",
    format_item = function(item)
      local first = item.messages and item.messages[2] and item.messages[2].content or item.id
      first = vim.trim((first or item.id):gsub("%s+", " "))
      return ("%s · %s"):format(item.model or "?", first:sub(1, 60))
    end,
  }, function(item)
    if item then
      require("luma.ui").open()
      require("luma.session").restore(item)
    end
  end)
end

function M.model(name)
  if name and name ~= "" then
    require("luma.session").set_model(name)
    return
  end
  vim.ui.select(require("luma.models").names(), { prompt = "Luma model: " }, function(selected)
    if selected then
      require("luma.session").set_model(selected)
    end
  end)
end

function M.tool(name, has_range)
  require("luma.tools").run(name, has_range)
end

function M._bootstrap()
  if bootstrapped then
    return
  end
  bootstrapped = true
  vim.api.nvim_create_user_command("LumaToggle", M.toggle, {})
  vim.api.nvim_create_user_command("LumaSubmit", function(command)
    M.submit(command.args ~= "" and command.args or nil)
  end, { nargs = "*" })
  vim.api.nvim_create_user_command("LumaCancel", M.cancel, {})
  vim.api.nvim_create_user_command("LumaNew", M.new, {})
  vim.api.nvim_create_user_command("LumaHistory", M.history, {})
  vim.api.nvim_create_user_command("LumaModel", function(command)
    M.model(command.args)
  end, { nargs = "?", complete = complete(function()
    return require("luma.models").names()
  end) })
  vim.api.nvim_create_user_command("LumaTool", function(command)
    M.tool(command.args, command.range > 0)
  end, { nargs = 1, range = true, complete = complete(function()
    return require("luma.tools").names()
  end) })
end

return M
