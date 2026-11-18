local Win = require("win")

local M = {}
local chats = {}

local function history_config(chat)
  local cfg = require("luma.config").get().history
  return {
    path = cfg.path .. "/tools/" .. chat.name,
    max = chat.spec.history == false and 0 or (chat.spec.history_max or cfg.max),
  }
end

local function render(chat, _, assistant)
  local content = chat.error and ("Error: " .. chat.error) or assistant
  local lines = vim.split(content and content ~= "" and content or " ", "\n", { plain = true })
  vim.bo[chat.output.buf].modifiable = true
  vim.api.nvim_buf_set_lines(chat.output.buf, 0, -1, false, lines)
  vim.bo[chat.output.buf].modifiable = false
  chat.output:set_title((" %s · %s "):format(chat.spec.title or chat.name, chat.model))
end

local function save(chat, user, assistant)
  if chat.spec.history == false then
    return
  end
  require("luma.history").save({
    model = chat.model,
    messages = {
      { role = "user", content = user },
      { role = "assistant", content = assistant },
    },
  }, history_config(chat))
end

local function select_model(chat)
  vim.ui.select(require("luma.models").names(), {
    prompt = (chat.spec.title or chat.name) .. " model: ",
  }, function(name)
    if name then
      chat.model = name
      render(chat, chat.user, chat.assistant)
      chat.input:focus()
      vim.cmd("startinsert")
    end
  end)
end

local function select_history(chat)
  local items = require("luma.history").list(history_config(chat))
  if #items == 0 then
    vim.notify("luma: no " .. chat.name .. " history", vim.log.levels.INFO)
    return
  end
  vim.ui.select(items, {
    prompt = (chat.spec.title or chat.name) .. " history: ",
    format_item = function(item)
      local message = item.messages and item.messages[1]
      return ("%s · %s"):format(item.model or "?", vim.trim(message and message.content or item.id):sub(1, 60))
    end,
  }, function(item)
    if item then
      chat.user = item.messages and item.messages[1] and item.messages[1].content or ""
      chat.assistant = item.messages and item.messages[2] and item.messages[2].content or ""
      render(chat, chat.user, chat.assistant)
    end
  end)
end

local function cancel(chat)
  chat.token = chat.token + 1
  if chat.request then
    chat.request.kill()
    chat.request = nil
  end
end

local function close(chat)
  if chat.closing then
    return
  end
  chat.closing = true
  chats[chat.name] = nil
  cancel(chat)
  for _, window in ipairs({ chat.output, chat.input }) do
    if window then
      window:destroy()
    end
  end
end

local function submit(chat)
  if chat.request then
    vim.notify("luma: a " .. chat.name .. " request is already running", vim.log.levels.WARN)
    return
  end
  local user = vim.trim(chat.input:text())
  if user == "" then
    return
  end
  local model = require("luma.models").get(chat.model)
  if not model then
    vim.notify("luma: unknown model " .. tostring(chat.model), vim.log.levels.ERROR)
    return
  end

  chat.user = user
  chat.assistant = ""
  chat.error = nil
  vim.api.nvim_buf_set_lines(chat.input.buf, 0, -1, false, { "" })
  render(chat, user, "")
  chat.token = chat.token + 1
  local token = chat.token
  chat.request = require("luma.request").start(model, {
    { role = "system", content = chat.spec.system },
    { role = "user", content = user },
  }, {
    on_delta = function(text)
      if token ~= chat.token then
        return
      end
      chat.assistant = chat.assistant .. text
      render(chat, chat.user, chat.assistant)
    end,
    on_error = function(err)
      if token ~= chat.token then
        return
      end
      chat.request = nil
      chat.error = err
      if chat.input:buf_valid() then
        vim.api.nvim_buf_set_lines(chat.input.buf, 0, -1, false, vim.split(chat.user, "\n", { plain = true }))
      end
      render(chat, chat.user, chat.assistant)
      vim.notify("luma: " .. err, vim.log.levels.ERROR)
    end,
    on_done = function()
      if token ~= chat.token then
        return
      end
      chat.request = nil
      chat.error = nil
      save(chat, chat.user, chat.assistant)
    end,
  })
end

local function create(name, spec)
  local cfg = require("luma.config").get()
  local outer_width = type(cfg.ui.width) == "number" and cfg.ui.width < 1 and math.floor(vim.o.columns * cfg.ui.width)
    or cfg.ui.width
  local outer_height = type(cfg.ui.height) == "number" and cfg.ui.height < 1 and math.floor(vim.o.lines * cfg.ui.height)
    or cfg.ui.height
  outer_width = math.max(40, outer_width)
  outer_height = math.max(10, outer_height)
  local border = 2
  local width = outer_width - border
  local input_outer_height = math.max(5, math.floor(outer_height * cfg.ui.input_height))
  local output_outer_height = outer_height - input_outer_height
  local input_height = input_outer_height - border
  local output_height = output_outer_height - border
  local row = math.max(0, math.floor((vim.o.lines - outer_height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - outer_width) / 2))
  local chat = {
    name = name,
    spec = spec,
    model = spec.model or cfg.model,
    token = 0,
  }
  local actions = {
    submit = function()
      submit(chat)
    end,
    close = function()
      close(chat)
    end,
    cancel = function()
      cancel(chat)
    end,
    model = function()
      select_model(chat)
    end,
    history = function()
      select_history(chat)
    end,
    input = function()
      chat.input:focus()
      vim.cmd("startinsert")
    end,
    insert = function()
      vim.cmd("startinsert")
    end,
    help = function(self)
      self:toggle_help({ win = { border = cfg.ui.border, title = " Luma keys " } })
    end,
  }
  local common_keys = {
    q = { "close", mode = "n", desc = "Close" },
    m = { "model", mode = "n", desc = "Select model" },
    h = { "history", mode = "n", desc = "History" },
    [cfg.keys.close] = { "close", mode = { "n", "i" }, desc = "Close" },
    [cfg.keys.cancel] = { "cancel", mode = { "n", "i" }, desc = "Cancel" },
  }
  local output_keys = vim.tbl_extend("force", {}, common_keys, {
    i = { "input", mode = "n", desc = "Prompt" },
  })
  chat.output = Win({
    show = false,
    position = "float",
    row = row,
    col = col,
    width = width,
    height = output_height,
    border = cfg.ui.border,
    title = " " .. (spec.title or name) .. " ",
    ft = "markdown",
    bo = { buftype = "nofile", bufhidden = "wipe", modifiable = false },
    wo = { wrap = true, linebreak = true },
    keys = output_keys,
    actions = actions,
    on_close = function()
      vim.schedule(function()
        if chats[name] then
          close(chat)
        end
      end)
    end,
  })
  local input_keys = vim.tbl_extend("force", {}, common_keys, {
    [cfg.keys.submit] = { "submit", mode = { "n", "i" }, desc = "Submit" },
    i = { "insert", mode = "n", desc = "Insert" },
    ["?"] = { "help", mode = "n", desc = "Help" },
  })
  chat.input = Win({
    show = false,
    position = "float",
    row = row + output_outer_height,
    col = col,
    width = width,
    height = input_height,
    border = cfg.ui.border,
    title = " Prompt ",
    ft = "markdown",
    bo = { buftype = "nofile", bufhidden = "wipe", modifiable = true },
    wo = { wrap = true, linebreak = true },
    keys = input_keys,
    actions = actions,
    footer_keys = { "?", "q", "m", "h" },
    on_close = function()
      vim.schedule(function()
        if chats[name] then
          close(chat)
        end
      end)
    end,
  })
  chats[name] = chat
  chat.output:show()
  chat.input:show()
  render(chat)
  chat.input:focus()
  if cfg.ui.start_insert then
    vim.cmd("startinsert")
  end
  return chat
end

function M.open(name, spec)
  if type(spec) ~= "table" or type(spec.system) ~= "string" then
    error("luma: tool chat requires a system prompt")
  end
  local chat = chats[name]
  if chat and chat.input:valid() and chat.output:valid() then
    chat.input:focus()
    return chat
  end
  return create(name, spec)
end

function M.close(name)
  if chats[name] then
    close(chats[name])
  end
end

M._chats = chats
M._history_config = history_config

return M
