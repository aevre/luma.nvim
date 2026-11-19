---@alias luma.SessionStatus "idle"|"requesting"

---@class luma.SessionState
---@field id? string
---@field model? string
---@field messages luma.Message[]
---@field status luma.SessionStatus
---@field request? luma.RequestHandle
---@field token integer
---@field source_buf? integer
---@field pending string
---@field error? string

local M = { ---@type luma.SessionState
  id = nil,
  model = nil,
  messages = {},
  status = "idle",
  request = nil,
  token = 0,
  source_buf = nil,
  pending = "",
  error = nil,
}

---@return luma.Config
local function cfg()
  return require("luma.config").get()
end

local function title()
  local suffix = M.status == "requesting" and " …" or ""
  return (" Luma · %s%s "):format(M.model or "?", suffix)
end

local headings = {
  user = "##  You",
  assistant = "## 󰚩 Assistant",
  error = "##  Error",
}

local function render()
  local lines = {}
  for _, message in ipairs(M.messages) do
    if message.role ~= "system" then
      local heading = headings[message.role] or ("## " .. message.role)
      lines[#lines + 1] = heading
      lines[#lines + 1] = ""
      vim.list_extend(lines, vim.split(message.content or "", "\n", { plain = true }))
      lines[#lines + 1] = ""
    end
  end
  if M.status == "requesting" then
    lines[#lines + 1] = headings.assistant
    lines[#lines + 1] = ""
    vim.list_extend(lines, vim.split(M.pending, "\n", { plain = true }))
  elseif M.error then
    lines[#lines + 1] = headings.error
    lines[#lines + 1] = ""
    lines[#lines + 1] = M.error
  end
  if #lines == 0 then
    lines = { "# Luma", "", "Type a prompt below. Use /buffer or /file path to add context." }
  end
  require("luma.ui").render(lines, title(), M.status == "requesting")
end

---@return luma.Message[]
local function base_messages()
  local messages = {} ---@type luma.Message[]
  if cfg().prompt and cfg().prompt ~= "" then
    messages[1] = { role = "system", content = cfg().prompt }
  end
  return messages
end

---Cancel pending work and initialize an empty session from current configuration.
function M.new()
  M.cancel()
  M.id = nil
  M.model = cfg().model
  M.messages = base_messages()
  M.status = "idle"
  M.pending = ""
  M.error = nil
  M.source_buf = vim.api.nvim_get_current_buf()
  require("luma.ui").clear_input()
  render()
  require("luma.ui").refresh_sidebars()
end

---@param saved luma.HistoryEntry
function M.restore(saved)
  M.cancel()
  M.id = saved.id
  M.model = saved.model or cfg().model
  M.messages = vim.deepcopy(saved.messages or base_messages())
  M.status = "idle"
  M.pending = ""
  M.error = nil
  render()
  require("luma.ui").refresh_sidebars()
end

---@return string? id
---@return string? error
function M.save()
  local id, err = require("luma.history").save({
    id = M.id,
    model = M.model,
    messages = M.messages,
  })
  if id then
    M.id = id
  end
  return id, err
end

function M.cancel()
  -- Incrementing the generation makes any late web or provider callback inert.
  M.token = M.token + 1
  if M.request then
    M.request.kill()
  end
  M.request = nil
  if M.status == "requesting" then
    M.status = "idle"
    M.pending = ""
    render()
  end
end

---Stream the current message list and commit one assistant message on success.
local function start_request()
  -- Every request captures a generation token so replaced requests cannot mutate state.
  M.token = M.token + 1
  local token = M.token
  M.status = "requesting"
  M.pending = ""
  M.error = nil
  render()
  local model = require("luma.models").get(M.model)
  M.request = require("luma.request").start(model, vim.deepcopy(M.messages), {
    on_delta = function(text)
      if token ~= M.token then
        return
      end
      M.pending = M.pending .. text
      require("luma.ui").render_stream(text, title())
    end,
    on_error = function(err)
      if token ~= M.token then
        return
      end
      M.request = nil
      M.status = "idle"
      M.pending = ""
      M.error = err
      render()
      vim.notify("luma: " .. err, vim.log.levels.ERROR)
    end,
    on_done = function()
      if token ~= M.token then
        return
      end
      M.request = nil
      M.status = "idle"
      M.messages[#M.messages + 1] = { role = "assistant", content = M.pending }
      M.pending = ""
      M.error = nil
      M.save()
      render()
      require("luma.ui").refresh_sidebars()
    end,
  })
end

---Expand local context, optionally inject web results, then start the provider request.
---@param text? string
function M.submit(text)
  if M.status == "requesting" then
    vim.notify("luma: a request is already running", vim.log.levels.WARN)
    return
  end
  text = vim.trim(text or require("luma.ui").input_text())
  if text == "" then
    return
  end
  local expanded, err = require("luma.context").expand(text, { bufnr = M.source_buf })
  if not expanded then
    vim.notify("luma: " .. err, vim.log.levels.ERROR)
    return
  end
  require("luma.ui").clear_input()
  local token = M.token + 1
  M.token = token
  local handle = require("luma.web").inject(expanded, function(content, web_err)
    if token ~= M.token then
      return
    end
    if not content then
      vim.notify("luma: " .. web_err, vim.log.levels.ERROR)
      return
    end
    M.messages[#M.messages + 1] = { role = "user", content = content }
    start_request()
  end)
  if handle then
    M.request = handle
  end
end

function M.resend()
  if M.status == "requesting" then
    M.cancel()
  end
  if M.messages[#M.messages] and M.messages[#M.messages].role == "assistant" then
    table.remove(M.messages)
  end
  if M.messages[#M.messages] and M.messages[#M.messages].role == "user" then
    start_request()
  end
end

---@param name string
function M.set_model(name)
  if not require("luma.models").get(name) then
    vim.notify("luma: unknown model " .. tostring(name), vim.log.levels.ERROR)
    return
  end
  M.cancel()
  M.model = name
  render()
  require("luma.ui").refresh_sidebars()
end

---@param text string
function M.attach(text)
  local ui = require("luma.ui")
  ui.open()
  local input = assert(ui.input)
  local current = vim.trim(input:text())
  local attached = ("<selection>\n%s\n</selection>"):format(text)
  local lines = vim.split(current ~= "" and (current .. "\n\n" .. attached) or attached, "\n", { plain = true })
  lines[#lines + 1] = ""
  vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, lines)
  require("luma.ui").focus_input()
  vim.api.nvim_win_set_cursor(input.win, { #lines, 0 })
end

---@return string?
function M.current_model()
  return M.model
end

---@return string?
function M.current_id()
  return M.id
end

function M.render()
  render()
end

return M
