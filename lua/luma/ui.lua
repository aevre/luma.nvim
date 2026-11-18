local Win = require("win")

---@class luma.Window
---@field buf integer
---@field win integer
---@field opts table
---@field valid fun(self: luma.Window): boolean
---@field buf_valid fun(self: luma.Window): boolean
---@field show fun(self: luma.Window): luma.Window
---@field hide fun(self: luma.Window): luma.Window
---@field destroy fun(self: luma.Window)
---@field focus fun(self: luma.Window)
---@field text fun(self: luma.Window): string
---@field set_title fun(self: luma.Window, title: string)
---@field toggle_help fun(self: luma.Window, opts?: table)

---@class luma.UI
---@field output? luma.Window
---@field input? luma.Window
---@field models? luma.Window
---@field history? luma.Window
---@field refresh_sidebars fun()
---@field open fun()
---@field hide fun()
---@field destroy fun()
---@field valid fun(): boolean
---@field input_text fun(): string
---@field set_input fun(text?: string)
---@field clear_input fun()
---@field render fun(lines: string[], title?: string, streaming?: boolean)
---@field render_stream fun(delta: string, title?: string)
---@field focus_input fun()
local M = {} ---@type luma.UI
local sidebar = { models = {}, history = {} }
local source_window
local closing_group = false
local stream_active = false

local function close_group_on_external_close()
  if closing_group then
    return
  end
  vim.schedule(function()
    if not closing_group then
      M.hide()
    end
  end)
end

local function restore_source_window()
  if source_window and vim.api.nvim_win_is_valid(source_window.win) then
    vim.wo[source_window.win].cursorline = source_window.cursorline
  end
  source_window = nil
end

local function dim_source_window()
  local win = vim.api.nvim_get_current_win()
  for _, name in ipairs({ "output", "input", "models", "history" }) do
    local window = M[name] ---@type luma.Window?
    if window and window.win == win then
      return
    end
  end
  restore_source_window()
  source_window = { win = win, cursorline = vim.wo[win].cursorline }
  vim.wo[win].cursorline = false
end

local function close_help()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "win_help" then
      vim.api.nvim_win_close(win, true)
      return true
    end
  end
  return false
end

local function toggle_help(self)
  self:toggle_help({
    win = {
      border = "rounded",
      title = " Luma keys ",
      row = 0.2,
      col = 0.15,
      width = 0.7,
    },
  })
end

local function focus(target)
  local window = M[target] ---@type luma.Window?
  if window and window:valid() then
    window:focus()
    if target == "input" and require("luma.config").get().ui.start_insert then
      vim.cmd("startinsert")
    end
  end
end

local function actions()
  local luma = require("luma")
  return {
    submit = function()
      luma.submit()
    end,
    close = function()
      if not close_help() then
        luma.toggle()
      end
    end,
    cancel = function()
      luma.cancel()
    end,
    new = function()
      luma.new()
    end,
    resend = function()
      luma.resend()
    end,
    help = function(self)
      toggle_help(self)
    end,
    input = function()
      focus("input")
    end,
    output = function()
      focus("output")
    end,
    models = function()
      focus("models")
    end,
    history = function()
      focus("history")
    end,
  }
end

local function keys(input)
  local cfg = require("luma.config").get().keys
  local ret = {
    ["?"] = { "help", mode = "n", desc = "Help" },
    q = { "close", mode = "n", desc = "Close chat" },
    i = { "input", mode = "n", desc = "Prompt" },
    o = { "output", mode = "n", desc = "Chat" },
    m = { "models", mode = "n", desc = "Models" },
    h = { "history", mode = "n", desc = "History" },
    [cfg.close] = { "close", mode = { "n", "i" }, desc = "Close chat" },
    [cfg.cancel] = { "cancel", mode = { "n", "i" }, desc = "Cancel request" },
    [cfg.new] = { "new", mode = { "n", "i" }, desc = "New chat" },
    [cfg.resend] = { "resend", mode = { "n", "i" }, desc = "Resend" },
  }
  if input then
    ret[cfg.submit] = { "submit", mode = { "n", "i" }, desc = "Submit" }
  end
  return ret
end

local function common(title, input)
  return {
    show = false,
    title = title,
    title_pos = "center",
    border = require("luma.config").get().ui.border,
    ft = "markdown",
    bo = {
      buftype = "nofile",
      bufhidden = "hide",
      swapfile = false,
      modifiable = input,
    },
    wo = {
      number = false,
      relativenumber = false,
      signcolumn = "no",
      wrap = true,
      linebreak = true,
    },
    keys = keys(input),
    actions = actions(),
    on_close = close_group_on_external_close,
    footer_keys = input and { "?", "o", "m", "h" } or nil,
  }
end

local function size(value, total)
  return type(value) == "number" and value < 1 and math.floor(total * value) or value
end

local function set_lines(win, lines)
  if not win or not win:buf_valid() then
    return
  end
  vim.bo[win.buf].modifiable = true
  vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)
  vim.bo[win.buf].modifiable = false
end

local function history_label(item)
  for _, message in ipairs(item.messages or {}) do
    if message.role == "user" then
      local text = vim.trim((message.content or ""):gsub("\n", " "))
      return text ~= "" and text or item.id
    end
  end
  return item.id
end

function M.refresh_sidebars()
  if not M.models or not M.history then
    return
  end
  local session = require("luma.session")
  sidebar.models = require("luma.models").names()
  local model_lines = {}
  local model_line = 1
  for i, name in ipairs(sidebar.models) do
    local selected = name == session.current_model()
    model_lines[i] = (selected and "● " or "  ") .. name
    if selected then
      model_line = i
    end
  end
  set_lines(M.models, #model_lines > 0 and model_lines or { "No models" })
  if M.models:valid() then
    vim.api.nvim_win_set_cursor(M.models.win, { model_line, 0 })
  end

  sidebar.history = require("luma.history").list()
  local history_lines = {}
  local history_line = 1
  for i, item in ipairs(sidebar.history) do
    local selected = item.id == session.current_id()
    local label = history_label(item)
    history_lines[i] = (selected and "● " or "  ") .. label
    if selected then
      history_line = i
    end
  end
  set_lines(M.history, #history_lines > 0 and history_lines or { "No history" })
  if M.history:valid() then
    vim.api.nvim_win_set_cursor(M.history.win, { history_line, 0 })
  end
end

local function sidebar_window(title, row, col, width, height, select)
  return Win({
    show = false,
    position = "float",
    row = row,
    col = col,
    width = width,
    height = height,
    border = require("luma.config").get().ui.border,
    title = title,
    title_pos = "center",
    ft = "markdown",
    bo = { buftype = "nofile", bufhidden = "hide", swapfile = false, modifiable = false },
    wo = { cursorline = true, wrap = false, number = false, relativenumber = false, signcolumn = "no" },
    keys = vim.tbl_extend("force", keys(false), {
      ["<CR>"] = { select, desc = "Select" },
      ["<Esc>"] = {
        function()
          focus("input")
        end,
        desc = "Back to prompt",
      },
    }),
    actions = actions(),
    on_close = close_group_on_external_close,
  })
end

local function create_float()
  local cfg = require("luma.config").get().ui
  local total_width = math.max(50, size(cfg.width, vim.o.columns))
  local total_height = math.max(12, size(cfg.height, vim.o.lines))
  local top = math.max(0, math.floor((vim.o.lines - total_height) / 2))
  local left = math.max(0, math.floor((vim.o.columns - total_width) / 2))
  local border = 2
  local gap = 0
  local sidebar_outer_width = math.max(20, math.floor(total_width * 0.24))
  local main_outer_width = math.max(32, total_width - sidebar_outer_width - gap)
  local input_outer_height = math.max(5, math.floor(total_height * cfg.input_height))
  local output_outer_height = math.max(6, total_height - input_outer_height - gap)
  local model_outer_height = math.max(6, math.floor((total_height - gap) * 0.32))
  local history_outer_height = math.max(6, total_height - model_outer_height - gap)
  local main_width = main_outer_width - border
  local sidebar_width = sidebar_outer_width - border
  local input_height = input_outer_height - border
  local output_height = output_outer_height - border
  local model_height = model_outer_height - border
  local history_height = history_outer_height - border
  local input_row = top + output_outer_height + gap
  local side_col = left + main_outer_width + gap
  local history_row = top + model_outer_height + gap

  M.output = Win(vim.tbl_deep_extend("force", common(" Luma ", false), {
    position = "float",
    width = main_width,
    height = output_height,
    row = top,
    col = left,
    enter = false,
  }))
  M.input = Win(vim.tbl_deep_extend("force", common(" Prompt ", true), {
    position = "float",
    width = main_width,
    height = input_height,
    row = input_row,
    col = left,
    enter = true,
  }))
  M.models = sidebar_window(" Models ", top, side_col, sidebar_width, model_height, function(self)
    local name = sidebar.models[vim.api.nvim_win_get_cursor(self.win)[1]]
    if name then
      require("luma.session").set_model(name)
      M.refresh_sidebars()
      focus("input")
    end
  end)
  M.history = sidebar_window(" History ", history_row, side_col, sidebar_width, history_height, function(self)
    local item = sidebar.history[vim.api.nvim_win_get_cursor(self.win)[1]]
    if item then
      require("luma.session").restore(item)
      M.refresh_sidebars()
      focus("input")
    end
  end)

  M.output:show()
  M.input:show()
  M.models:show()
  M.history:show()
  M.refresh_sidebars()
end

local function create_split()
  local cfg = require("luma.config").get().ui
  local vertical = cfg.position == "left" or cfg.position == "right"
  M.output = Win(vim.tbl_deep_extend("force", common(" Luma ", false), {
    position = cfg.position,
    width = vertical and cfg.width or nil,
    height = vertical and nil or cfg.height,
    stack = true,
    enter = false,
  }))
  M.output:show()
  M.input = Win(vim.tbl_deep_extend("force", common(" Prompt ", true), {
    position = cfg.position,
    width = vertical and cfg.width or nil,
    height = vertical and nil
      or math.max(3, math.floor((type(cfg.height) == "number" and cfg.height or 12) * cfg.input_height)),
    stack = true,
    enter = true,
  }))
  M.input:show()
end

function M.open()
  if not M.valid() then
    dim_source_window()
  end
  if M.valid() then
    focus("input")
    return
  end
  if M.output and M.input then
    M.output:show()
    M.input:show()
    if M.models and M.history then
      M.models:show()
      M.history:show()
      M.refresh_sidebars()
    end
  elseif require("luma.config").get().ui.position == "float" then
    create_float()
  else
    create_split()
  end
  focus("input")
end

function M.hide()
  if closing_group then
    return
  end
  closing_group = true
  restore_source_window()
  for _, name in ipairs({ "output", "input", "models", "history" }) do
    local window = M[name] ---@type luma.Window?
    if window then
      window:hide()
    end
  end
  closing_group = false
end

function M.destroy()
  if closing_group then
    return
  end
  closing_group = true
  restore_source_window()
  for _, name in ipairs({ "output", "input", "models", "history" }) do
    local window = M[name] ---@type luma.Window?
    if window then
      window:destroy()
      M[name] = nil
    end
  end
  closing_group = false
end

function M.valid()
  return M.output ~= nil and M.input ~= nil and M.output:valid() and M.input:valid()
end

function M.input_text()
  return M.input and M.input:text() or ""
end

function M.set_input(text)
  M.open()
  vim.api.nvim_buf_set_lines(M.input.buf, 0, -1, false, vim.split(text or "", "\n", { plain = true }))
end

function M.clear_input()
  if M.input and M.input:buf_valid() then
    M.set_input("")
  end
end

function M.render(lines, title, streaming)
  if not M.output or not M.output:buf_valid() then
    return
  end
  local follow = false
  if M.output:valid() then
    local count = vim.api.nvim_buf_line_count(M.output.buf)
    follow = vim.api.nvim_win_get_cursor(M.output.win)[1] >= count
  end
  set_lines(M.output, lines)
  stream_active = streaming and vim.tbl_contains(lines, "## Assistant") or false
  M.output:set_title(title or " Luma ")
  if follow then
    require("luma.scroll").bottom(M.output, streaming)
  end
end

function M.render_stream(delta, title)
  if not stream_active or not M.output or not M.output:buf_valid() then
    return
  end
  local follow = false
  if M.output:valid() then
    local count = vim.api.nvim_buf_line_count(M.output.buf)
    follow = vim.api.nvim_win_get_cursor(M.output.win)[1] >= count
  end
  local last = vim.api.nvim_buf_line_count(M.output.buf) - 1
  local line = vim.api.nvim_buf_get_lines(M.output.buf, last, last + 1, false)[1] or ""
  vim.bo[M.output.buf].modifiable = true
  vim.api.nvim_buf_set_text(M.output.buf, last, #line, last, #line, vim.split(delta, "\n", { plain = true }))
  vim.bo[M.output.buf].modifiable = false
  M.output:set_title(title or " Luma ")
  if follow then
    require("luma.scroll").bottom(M.output, true)
  end
end

function M.focus_input()
  M.open()
  focus("input")
end

return M
