local M = {}

local function selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local first = vim.fn.getpos("'<")
  local last = vim.fn.getpos("'>")
  if first[2] == 0 or last[2] == 0 then
    return nil, "no visual selection"
  end
  local lines = vim.api.nvim_buf_get_text(bufnr, first[2] - 1, first[3] - 1, last[2] - 1, last[3], {})
  return table.concat(lines, "\n"),
    {
      bufnr = bufnr,
      start_line = first[2],
      start_col = first[3],
      end_line = last[2],
      end_col = last[3],
    }
end

local function read_file(path, limit)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return nil, "cannot read file: " .. path
  end
  if stat.type ~= "file" then
    return nil, "not a file: " .. path
  end
  if stat.size > limit then
    return nil, ("file exceeds %d byte context limit: %s"):format(limit, path)
  end
  local fd, err = io.open(path, "rb")
  if not fd then
    return nil, "cannot read file: " .. tostring(err)
  end
  local data = fd:read("*a")
  fd:close()
  return data
end

local function buffer_name(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and vim.fn.fnamemodify(name, ":~:.") or ("[%d] [No Name]"):format(bufnr)
end

local function resolve_buffer(value, fallback)
  if not value or value == "" then
    return fallback
  end
  local number = tonumber(value)
  if number and vim.api.nvim_buf_is_valid(number) then
    return number
  end
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if value == buffer_name(info.bufnr) or value == vim.api.nvim_buf_get_name(info.bufnr) then
      return info.bufnr
    end
  end
  return nil
end

local function diagnostics(bufnr)
  local lines = {}
  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr)) do
    lines[#lines + 1] = ("%d:%d %s"):format(diagnostic.lnum + 1, diagnostic.col + 1, diagnostic.message)
  end
  return table.concat(lines, "\n")
end

function M.visual()
  return selection()
end

function M.expand(text, opts)
  opts = opts or {}
  local cfg = require("luma.config").get()
  local bufnr = opts.bufnr and vim.api.nvim_buf_is_valid(opts.bufnr) and opts.bufnr or vim.api.nvim_get_current_buf()
  local max_bytes = opts.max_context_bytes or cfg.max_context_bytes
  local additions = {}
  local total = 0

  local function add(label, content)
    if total + #content > max_bytes then
      return nil, ("context exceeds %d byte limit"):format(max_bytes)
    end
    total = total + #content
    additions[#additions + 1] = ('\n\n<context source="%s">\n%s\n</context>'):format(label, content)
    return true
  end

  local buffer_error
  text = text:gsub("/buffer%s*([^%s/]*)", function(value)
    if buffer_error then
      return ""
    end
    local target = resolve_buffer(value, bufnr)
    if not target then
      buffer_error = "unknown buffer: " .. value
      return ""
    end
    local content = table.concat(vim.api.nvim_buf_get_lines(target, 0, -1, false), "\n")
    local name = vim.api.nvim_buf_get_name(target)
    local ok, err = add(name ~= "" and name or ("buffer-%d"):format(target), content)
    buffer_error = not ok and err or nil
    return ""
  end)
  if buffer_error then
    return nil, buffer_error
  end

  local error_message
  text = text:gsub("/file%s+([^%s]+)", function(path)
    if error_message then
      return ""
    end
    local content, err = read_file(vim.fn.expand(path), max_bytes - total)
    if not content then
      error_message = err
      return ""
    end
    local ok, add_err = add(path, content)
    error_message = not ok and add_err or nil
    return ""
  end)
  if error_message then
    return nil, error_message
  end

  if opts.diagnostics or cfg.diagnostics then
    local content = diagnostics(bufnr)
    if content ~= "" then
      local ok, err = add("diagnostics", content)
      if not ok then
        return nil, err
      end
    end
  end

  return vim.trim(text) .. table.concat(additions)
end

function M.complete(text, cursor_col)
  local before = text:sub(1, cursor_col or #text)
  local file = before:match("/file%s+([^%s]*)$")
  if file then
    return #before - #file + 1, vim.fn.getcompletion(file .. "*", "file")
  end

  local buffer = before:match("/buffer%s+([^%s]*)$")
  if buffer then
    local items = {}
    for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
      local name = buffer_name(info.bufnr)
      if buffer == "" or name:lower():find(buffer:lower(), 1, true) or tostring(info.bufnr):find(buffer, 1, true) then
        items[#items + 1] = { word = tostring(info.bufnr), abbr = name, menu = ("buffer %d"):format(info.bufnr) }
      end
    end
    return #before - #buffer + 1, items
  end

  local directive = before:match("(/[%a_]*)$")
  if directive then
    local items = vim.tbl_filter(function(item)
      return item:sub(1, #directive) == directive
    end, { "/buffer", "/file" })
    return #before - #directive + 1, items
  end
end

M.read_file = read_file
M.diagnostics = diagnostics
M.resolve_buffer = resolve_buffer

return M
