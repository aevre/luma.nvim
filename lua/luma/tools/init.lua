local Win = require("win")

local M = {}
local registry = {}
local pending = {}
local cancel_maps = {}
local next_request_id = 0

local function remove_cancel_map(bufnr)
  local state = cancel_maps[bufnr]
  if not state then
    return
  end
  state.count = state.count - 1
  if state.count > 0 then
    return
  end
  cancel_maps[bufnr] = nil
  if state.mapped and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.keymap.del, "n", state.key, { buffer = bufnr })
    pcall(vim.keymap.del, "i", state.key, { buffer = bufnr })
  end
end

local function add_cancel_map(bufnr)
  local state = cancel_maps[bufnr]
  if state then
    state.count = state.count + 1
    return
  end
  local key = require("luma.config").get().keys.cancel
  state = { count = 1, key = key, mapped = false }
  cancel_maps[bufnr] = state
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local normal = vim.fn.maparg(key, "n", false, true)
  local insert = vim.fn.maparg(key, "i", false, true)
  if normal.buffer == 1 or insert.buffer == 1 then
    return
  end
  state.mapped = true
  vim.keymap.set({ "n", "i" }, key, function()
    M.cancel()
  end, { buffer = bufnr, desc = "Cancel Luma task" })
end

local function finish_request(id)
  local active = pending[id]
  if not active then
    return
  end
  pending[id] = nil
  remove_cancel_map(active.bufnr)
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

function M.strip_fence(text)
  return text:match("^%s*```[^\n]*\n(.-)\n```%s*$") or text
end

function M.visual()
  local text, range = require("luma.context").visual()
  if not text then
    vim.notify("luma: " .. range, vim.log.levels.ERROR)
    return
  end
  return text, range
end

function M.source(has_range)
  if has_range then
    return M.visual()
  end
  local bufnr = vim.api.nvim_get_current_buf()
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"), { bufnr = bufnr }
end

local function spinner(opts)
  if opts == false then
    return function() end
  end
  opts = type(opts) == "table" and opts or {}
  local frames = opts.frames or { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local text = opts.text
  local frame = 1
  local active = true
  local buf = vim.api.nvim_create_buf(false, true)
  local win
  local timer = assert(vim.uv.new_timer())
  vim.bo[buf].bufhidden = "wipe"
  local function draw()
    if not active then
      return
    end
    local label = frames[frame]
    if text ~= false and text ~= nil and text ~= "" then
      label = label .. " " .. text
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { label })
    local config = {
      relative = "cursor",
      row = opts.row or 1,
      col = opts.col or 1,
      width = vim.api.nvim_strwidth(label),
      height = 1,
      style = "minimal",
      focusable = false,
      noautocmd = true,
      zindex = opts.zindex or 60,
    }
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(win, config)
    else
      win = vim.api.nvim_open_win(buf, false, config)
      vim.wo[win].winhighlight = "Normal:" .. (opts.hl or "Title")
      vim.wo[win].winblend = opts.blend or 0
    end
    frame = frame % #frames + 1
  end
  draw()
  timer:start(opts.interval or 80, opts.interval or 80, vim.schedule_wrap(draw))
  return function()
    if not active then
      return
    end
    active = false
    timer:stop()
    timer:close()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    elseif vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

local function result_size(text)
  local lines = vim.split(text ~= "" and text or " ", "\n", { plain = true })
  local longest = 1
  for _, line in ipairs(lines) do
    longest = math.max(longest, vim.api.nvim_strwidth(line))
  end
  return {
    width = math.min(math.max(longest + 4, 36), math.max(36, math.floor(vim.o.columns * 0.8))),
    height = math.min(math.max(#lines + 2, 6), math.max(6, math.floor(vim.o.lines * 0.8))),
  }
end

function M.panel(title, keys, opts)
  keys = keys or {}
  local function close_or(action, self)
    if close_help() then
      return
    end
    if type(action) == "function" then
      action(self)
    else
      self:close()
    end
  end
  local mappings = vim.tbl_extend("force", {}, keys, {
    ["?"] = function(self)
      self:toggle_help({
        win = {
          border = "rounded",
          title = " Luma keys ",
          row = 0.2,
          col = 0.15,
          width = 0.7,
        },
      })
    end,
    q = function(self)
      close_or(keys.q, self)
    end,
    ["<Esc>"] = function(self)
      close_or(keys["<Esc>"], self)
    end,
  })
  return Win(vim.tbl_deep_extend("force", {
    position = "float",
    width = 0.7,
    height = 0.7,
    border = "rounded",
    title = title,
    text = {},
    ft = "markdown",
    bo = { modifiable = false, buftype = "nofile", bufhidden = "wipe" },
    wo = { wrap = true, linebreak = true },
    keys = mappings,
    footer_keys = { "?", "q" },
  }, opts or {}))
end

function M.generate(title, system, user, on_done, opts)
  local spec
  if type(title) == "table" then
    spec = title
  else
    opts = opts or {}
    local window = vim.deepcopy(opts)
    window.loading = nil
    spec = {
      title = title,
      system = system,
      user = user,
      on_done = on_done,
      loading = opts.loading,
      window = window,
    }
  end
  if type(spec.system) ~= "string" or type(spec.user) ~= "string" then
    error("luma: generate requires string system and user fields")
  end
  local loading = type(spec.loading) == "string" and { text = spec.loading } or spec.loading
  local result = ""
  local bufnr = vim.api.nvim_get_current_buf()
  next_request_id = next_request_id + 1
  local request_id = next_request_id
  local clear_spinner = spinner(loading)
  local model_name = spec.model or require("luma.config").get().model
  local model = require("luma.models").get(model_name)
  if not model then
    clear_spinner()
    error("luma: unknown model " .. tostring(model_name))
  end
  local request
  local function cancel()
    if not pending[request_id] then
      return
    end
    finish_request(request_id)
    clear_spinner()
    if request then
      request.kill()
    end
    vim.notify("luma: task cancelled", vim.log.levels.INFO)
  end
  local handle = { kill = cancel, cancel = cancel }
  pending[request_id] = { cancel = cancel, bufnr = bufnr }
  add_cancel_map(bufnr)
  request = require("luma.request").start(model, {
    { role = "system", content = spec.system },
    { role = "user", content = spec.user },
  }, {
    on_delta = function(text)
      result = result .. text
    end,
    on_error = function(err)
      finish_request(request_id)
      clear_spinner()
      if spec.on_error then
        spec.on_error(err)
      end
      vim.notify("luma: " .. err, vim.log.levels.ERROR)
    end,
    on_done = function()
      finish_request(request_id)
      clear_spinner()
      result = M.strip_fence(result)
      local dimensions = result_size(result)
      local output
      output = M.panel((spec.title or " Luma… "):gsub("…", ""), {
        q = function(self)
          self:destroy()
        end,
        ["<Esc>"] = "close",
      }, vim.tbl_deep_extend("force", dimensions, spec.window or {}))
      vim.bo[output.buf].modifiable = true
      vim.api.nvim_buf_set_lines(output.buf, 0, -1, false, vim.split(result, "\n", { plain = true }))
      vim.bo[output.buf].modifiable = false
      if spec.on_done then
        spec.on_done(result, output)
      end
    end,
  })
  return handle
end

function M.cancel()
  local active = vim.tbl_values(pending)
  for _, request in ipairs(active) do
    request.cancel()
  end
  return #active > 0
end

local function declarative(spec, ctx)
  local input
  if spec.input == "selection" then
    if not ctx.has_range then
      vim.notify("luma: " .. ctx.name .. " requires a visual selection", vim.log.levels.ERROR)
      return
    end
    input = M.source(true)
  elseif spec.input == "prompt" then
    input = vim.fn.input(spec.prompt_title or (ctx.name .. ": "))
  else
    input = M.source(ctx.has_range)
  end
  if not input or input == "" then
    return
  end
  local system = type(spec.system) == "function" and spec.system(ctx, input) or spec.system
  local prompt = type(spec.prompt) == "function" and spec.prompt(ctx, input) or spec.prompt
  local user = prompt and (prompt .. "\n\n" .. input) or input
  return M.generate({
    title = spec.title or (" " .. ctx.name .. "… "),
    system = system or "Follow the user's request.",
    user = user,
    on_done = spec.on_done,
    on_error = spec.on_error,
    loading = spec.loading,
    window = spec.window,
    model = spec.model,
  })
end

function M.register(name, spec)
  if type(name) ~= "string" or name == "" then
    error("luma: tool name must be a non-empty string")
  end
  if type(spec) == "function" then
    spec = { handler = spec }
  end
  if type(spec) ~= "table" or (type(spec.handler) ~= "function" and spec.system == nil) then
    error("luma: tool " .. name .. " needs a handler or system prompt")
  end
  registry[name] = spec
  return M
end

function M.unregister(name)
  registry[name] = nil
end

function M.get(name)
  return registry[name]
end

function M.names()
  local names = vim.tbl_keys(registry)
  table.sort(names)
  return names
end

function M.setup(tools)
  M.cancel()
  registry = {}
  for name, spec in pairs(tools or {}) do
    if spec ~= false then
      M.register(name, spec)
    end
  end
end

M.loading = spinner
M._result_size = result_size
M._spinner = spinner

function M.run(name, has_range)
  local spec = registry[name]
  if not spec then
    vim.notify("luma: unknown tool " .. tostring(name), vim.log.levels.ERROR)
    return
  end
  local ctx = {
    name = name,
    tool = spec,
    has_range = has_range == true,
    visual = M.visual,
    source = M.source,
    generate = function(generate_spec, ...)
      if type(generate_spec) == "table" and generate_spec.model == nil then
        generate_spec = vim.tbl_extend("force", { model = spec.model }, generate_spec)
      end
      return M.generate(generate_spec, ...)
    end,
    chat = function(chat_spec)
      return require("luma.tool_chat").open(name, vim.tbl_extend("force", { model = spec.model }, chat_spec or {}))
    end,
    cancel = M.cancel,
    loading = M.loading,
    panel = M.panel,
    strip_fence = M.strip_fence,
  }
  if spec.handler then
    return spec.handler(ctx)
  end
  return declarative(spec, ctx)
end

return M
