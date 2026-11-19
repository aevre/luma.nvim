---@class luma.API
local M = {}
local bootstrapped = false

local highlights = {
  LumaNormal = "NormalFloat",
  LumaNormalNC = "NormalFloat",
  LumaBorder = "FloatBorder",
  LumaTitle = "FloatTitle",
  LumaFooter = "FloatFooter",
  LumaSeparator = "WinSeparator",
  LumaUser = "Title",
  LumaAssistant = "Function",
  LumaError = "DiagnosticError",
  LumaLoading = "Special",
  LumaLoadingBorder = "FloatBorder",
  LumaResultBorder = "FloatTitle",
}

local function setup_highlights()
  for name, link in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, { default = true, link = link })
  end
end

---@param values fun(): string[]
---@return fun(arg: string): string[]
local function complete(values)
  return function(arg)
    return vim.tbl_filter(function(value)
      return value:sub(1, #arg) == arg
    end, values())
  end
end

---Reset configuration, tool registrations, UI objects, and session state coherently.
---@param opts? luma.ConfigInput
---@return luma.API
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

---@param text? string
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

---@param item luma.HistoryEntry
---@return string
local function history_label(item)
  local first = item.messages and item.messages[1] and item.messages[1].content or item.id
  first = vim.trim((first or item.id):gsub("%s+", " "))
  return ("%s · %s"):format(item.model or "?", first:sub(1, 60))
end

---Open a saved tool result as a read-only snapshot without rerunning the tool.
---@param item luma.HistoryEntry
---@param tool string
local function show_tool_history(item, tool)
  local lines = { "# " .. tool, "" }
  for _, message in ipairs(item.messages or {}) do
    lines[#lines + 1] = message.role == "assistant" and "## Assistant" or "## Input"
    lines[#lines + 1] = ""
    vim.list_extend(lines, vim.split(message.content or "", "\n", { plain = true }))
    lines[#lines + 1] = ""
  end
  local panel = require("luma.tools").panel((" %s history "):format(tool))
  vim.bo[panel.buf].modifiable = true
  vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, lines)
  vim.bo[panel.buf].modifiable = false
  panel:show()
end

---@param opts luma.HistoryOptions
local function select_history(opts)
  local items = require("luma.history").list(opts)
  if #items == 0 then
    vim.notify("luma: no saved history", vim.log.levels.INFO)
    return
  end
  vim.ui.select(items, {
    prompt = (opts.scope == "tool" and opts.tool or "Luma") .. " history: ",
    format_item = history_label,
  }, function(item)
    if not item then
      return
    end
    if opts.scope ~= "tool" then
      require("luma.ui").open()
      require("luma.session").restore(item)
      return
    end
    vim.ui.select({ "Open", "Delete", "Cancel" }, { prompt = "History action: " }, function(action)
      if action == "Open" then
        show_tool_history(item, opts.tool)
      elseif action == "Delete" then
        vim.ui.select({ "Cancel", "Delete" }, { prompt = "Delete this history entry? " }, function(choice)
          if choice == "Delete" then
            local ok, err = M.history_delete(item.id, opts)
            if not ok then
              vim.notify("luma: " .. err, vim.log.levels.ERROR)
            end
          end
        end)
      end
    end)
  end)
end

---Browse main-chat history, one tool scope, or all discovered scopes.
---@param opts? luma.HistoryOptions
function M.history(opts)
  opts = opts or { scope = "chat" }
  if opts.scope ~= "all" then
    select_history(opts)
    return
  end
  vim.ui.select(require("luma.history").scopes(), {
    prompt = "Luma history scope: ",
    format_item = function(item)
      return item.scope == "chat" and "Main chat" or item.tool
    end,
  }, function(scope)
    if scope then
      select_history({ scope = scope.scope, tool = scope.tool })
    end
  end)
end

---Delete one entry without prompting; confirmation belongs to interactive callers.
---@param id string
---@param opts? luma.HistoryOptions
---@return boolean? success
---@return string? error
function M.history_delete(id, opts)
  opts = opts or {}
  -- Public management accepts named scopes only, never an arbitrary filesystem path.
  opts = { scope = opts.scope or "chat", tool = opts.tool }
  local ok, err = require("luma.history").delete(id, opts)
  if ok and opts.scope ~= "tool" and id:gsub("%.json$", "") == require("luma.session").current_id() then
    -- Reset memory so the next submission cannot recreate the deleted session ID.
    require("luma.session").new()
  elseif ok then
    require("luma.ui").refresh_sidebars()
  end
  return ok, err
end

---Clear one scope without prompting and report partial deletion failures.
---@param opts? luma.HistoryOptions
---@return luma.HistoryClearResult? result
---@return string? error
function M.history_clear(opts)
  opts = opts or {}
  -- Public management accepts named scopes only, never an arbitrary filesystem path.
  opts = { scope = opts.scope or "chat", tool = opts.tool }
  local result, err = require("luma.history").clear(opts)
  local current_id = require("luma.session").current_id()
  if result and opts.scope ~= "tool" and current_id and not require("luma.history").load(current_id, opts) then
    require("luma.session").new()
  elseif result then
    require("luma.ui").refresh_sidebars()
  end
  return result, err
end

---@param name? string
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

---@param name string
---@param has_range? boolean
function M.tool(name, has_range)
  require("luma.tools").run(name, has_range)
end

---Register commands and highlight restoration exactly once per runtime.
function M._bootstrap()
  if bootstrapped then
    return
  end
  bootstrapped = true
  setup_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("luma_highlights", { clear = true }),
    callback = setup_highlights,
  })
  vim.api.nvim_create_user_command("LumaToggle", M.toggle, {})
  vim.api.nvim_create_user_command("LumaSubmit", function(command)
    M.submit(command.args ~= "" and command.args or nil)
  end, { nargs = "*" })
  vim.api.nvim_create_user_command("LumaCancel", M.cancel, {})
  vim.api.nvim_create_user_command("LumaNew", M.new, {})
  vim.api.nvim_create_user_command("LumaHistory", function(command)
    local args = vim.split(vim.trim(command.args), "%s+")
    if args[1] == "all" then
      M.history({ scope = "all" })
    elseif args[1] == "tool" and args[2] then
      M.history({ scope = "tool", tool = args[2] })
    else
      M.history({ scope = "chat" })
    end
  end, { nargs = "*" })
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
