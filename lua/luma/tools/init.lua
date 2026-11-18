local Win = require("win")

local M = {}
local registry = {}
local spinner_ns = vim.api.nvim_create_namespace("luma.tool_spinner")

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

local function spinner()
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local frame = 1
  local active = true
  local mark
  local timer = vim.uv.new_timer()
  local function draw()
    if not active or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local row = math.min(math.max(cursor[1] - 1, 0), line_count - 1)
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    local col = math.min(math.max(cursor[2], 0), #line)
    mark = vim.api.nvim_buf_set_extmark(bufnr, spinner_ns, row, col, {
      id = mark,
      virt_text = { { " " .. frames[frame] .. " Luma", "Title" } },
      virt_text_pos = "eol",
    })
    frame = frame % #frames + 1
  end
  draw()
  timer:start(80, 80, vim.schedule_wrap(draw))
  return function()
    if not active then
      return
    end
    active = false
    timer:stop()
    timer:close()
    if vim.api.nvim_buf_is_valid(bufnr) and mark then
      pcall(vim.api.nvim_buf_del_extmark, bufnr, spinner_ns, mark)
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
  local result = ""
  local clear_spinner = spinner()
  local request = require("luma.request").start(require("luma.models").get(require("luma.config").get().model), {
    { role = "system", content = system },
    { role = "user", content = user },
  }, {
    on_delta = function(text)
      result = result .. text
    end,
    on_error = function(err)
      clear_spinner()
      vim.notify("luma: " .. err, vim.log.levels.ERROR)
    end,
    on_done = function()
      clear_spinner()
      result = M.strip_fence(result)
      local dimensions = result_size(result)
      local output
      output = M.panel(title:gsub("…", ""), {
        q = function(self)
          self:destroy()
        end,
        ["<Esc>"] = "close",
      }, vim.tbl_deep_extend("force", dimensions, opts or {}))
      vim.bo[output.buf].modifiable = true
      vim.api.nvim_buf_set_lines(output.buf, 0, -1, false, vim.split(result, "\n", { plain = true }))
      vim.bo[output.buf].modifiable = false
      if on_done then
        on_done(result, output)
      end
    end,
  })
  local handle = {
    kill = function()
      clear_spinner()
      request.kill()
    end,
  }
  return handle
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
  return M.generate(
    spec.title or (" " .. ctx.name .. "… "),
    system or "Follow the user's request.",
    user,
    spec.on_done,
    spec.window
  )
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
  registry = {}
  for name, spec in pairs(tools or {}) do
    if spec ~= false then
      M.register(name, spec)
    end
  end
end

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
    generate = M.generate,
    panel = M.panel,
    strip_fence = M.strip_fence,
  }
  if spec.handler then
    return spec.handler(ctx)
  end
  return declarative(spec, ctx)
end

return M
