---@alias luma.HistoryMessage luma.Message

---@class luma.HistoryEntryInput
---@field id? string
---@field kind? "chat"|"generate"
---@field tool? string
---@field model? string
---@field messages? luma.Message[]
---@field created_at? integer
---@field updated_at? integer

---@class luma.HistoryEntry: luma.HistoryEntryInput
---@field id string

---@class luma.HistoryConfigInput
---@field path? string
---@field max? integer

---@class luma.HistoryConfig: luma.HistoryConfigInput
---@field path string

---@class luma.HistoryOptions
---@field scope? "chat"|"tool"|"all"
---@field tool? string
---@field max? integer

---@class luma.HistoryScope
---@field scope "chat"|"tool"
---@field tool? string
---@field name string

---@class luma.HistoryClearFailure
---@field id string
---@field error string

---@class luma.HistoryClearResult
---@field deleted integer
---@field failed luma.HistoryClearFailure[]

local M = {}

---@param value unknown
---@param label string
---@return string? name
---@return string? error
local function safe_name(value, label)
  if type(value) ~= "string" or value == "" or value == "." or value == ".." or not value:match("^[%w%._-]+$") then
    return nil, "invalid " .. label
  end
  return value
end

---Keep common tool names readable and encode names that cannot be path components.
---@param value unknown
---@return string? directory
---@return string? error
local function encode_name(value)
  if type(value) ~= "string" or value == "" then
    return nil, "invalid tool name"
  end
  if safe_name(value, "tool name") then
    return value
  end
  return "@" .. value:gsub(".", function(char)
    return ("%02X"):format(char:byte())
  end)
end

---@param value string
---@return string
local function decode_name(value)
  if value:sub(1, 1) ~= "@" or #value % 2 ~= 1 or not value:sub(2):match("^%x+$") then
    return value
  end
  return (value:sub(2):gsub("(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

---Resolve a public scope or an internal explicit path to one storage directory.
---@param opts? luma.HistoryOptions|luma.HistoryConfig
---@return luma.HistoryConfig? config
---@return string? error
local function config(opts)
  if opts and opts.path then
    return { path = opts.path, max = opts.max }
  end
  local cfg = require("luma.config").get().history
  if not opts or not opts.scope or opts.scope == "chat" then
    return cfg
  end
  if opts.scope == "tool" then
    local tool, err = encode_name(opts.tool)
    if not tool then
      return nil, err
    end
    return { path = cfg.path .. "/tools/" .. tool, max = opts.max or cfg.max }
  end
  return nil, "invalid history scope"
end

---History IDs are validated before they are joined to the configured directory.
---@param id unknown
---@return string? id
---@return string? error
local function history_id(id)
  if type(id) == "string" then
    id = id:gsub("%.json$", "")
  end
  return safe_name(id, "history id")
end

---@param path string
---@return table? value
---@return string? error
local function read(path)
  local fd, err = io.open(path, "rb")
  if not fd then
    return nil, err
  end
  local data = fd:read("*a")
  fd:close()
  local ok, decoded = pcall(vim.json.decode, data)
  return ok and decoded or nil, ok and nil or decoded
end

---@param path string
---@param value table
---@return boolean? success
---@return string? error
local function write(path, value)
  local fd, err = io.open(path, "wb")
  if not fd then
    return nil, err
  end
  local ok, encoded = pcall(vim.json.encode, value)
  if not ok then
    fd:close()
    return nil, encoded
  end
  local wrote, write_err = fd:write(encoded)
  fd:close()
  return wrote and true or nil, write_err
end

---@param path string
---@return string[]
local function files(path)
  local ret = {} ---@type string[]
  local handle = vim.uv.fs_scandir(path)
  if not handle then
    return ret
  end
  while true do
    local name, kind = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if kind == "file" and name:sub(-5) == ".json" then
      ret[#ret + 1] = name
    end
  end
  table.sort(ret, function(a, b)
    return a > b
  end)
  return ret
end

---@param session luma.HistoryEntryInput
---@param opts? luma.HistoryOptions|luma.HistoryConfig
---@return string? id
---@return string? error
function M.save(session, opts)
  local cfg, config_err = config(opts)
  if not cfg then
    return nil, config_err
  end
  vim.fn.mkdir(cfg.path, "p")
  local id = session.id or (os.date("%Y%m%d-%H%M%S") .. "-" .. tostring(vim.uv.hrtime()))
  local valid_id, id_err = history_id(id)
  if not valid_id then
    return nil, id_err
  end
  session.id = valid_id
  session.created_at = session.created_at or os.time()
  session.updated_at = os.time()
  local ok, err = write(cfg.path .. "/" .. valid_id .. ".json", session)
  if not ok then
    return nil, "failed to save history: " .. tostring(err)
  end
  M.prune(cfg)
  return valid_id
end

---@param id string
---@param opts? luma.HistoryOptions|luma.HistoryConfig
---@return luma.HistoryEntry? entry
---@return string? error
function M.load(id, opts)
  local cfg, config_err = config(opts)
  if not cfg then
    return nil, config_err
  end
  local valid_id, id_err = history_id(id)
  if not valid_id then
    return nil, id_err
  end
  return read(cfg.path .. "/" .. valid_id .. ".json")
end

---@param opts? luma.HistoryOptions|luma.HistoryConfig
---@return luma.HistoryEntry[]
function M.list(opts)
  local cfg = config(opts)
  if not cfg then
    return {}
  end
  local ret = {} ---@type luma.HistoryEntry[]
  for _, name in ipairs(files(cfg.path)) do
    local item = read(cfg.path .. "/" .. name)
    if item then
      item.id = item.id or name:sub(1, -6)
      ret[#ret + 1] = item
    end
  end
  return ret
end

---Delete one entry from exactly one resolved history directory.
---@param id string
---@param opts? luma.HistoryOptions|luma.HistoryConfig
---@return boolean? success
---@return string? error
function M.delete(id, opts)
  local cfg, config_err = config(opts)
  if not cfg then
    return nil, config_err
  end
  local valid_id, id_err = history_id(id)
  if not valid_id then
    return nil, id_err
  end
  local path = cfg.path .. "/" .. valid_id .. ".json"
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil, "history not found"
  end
  local ok, err = vim.uv.fs_unlink(path)
  return ok and true or nil, err and ("failed to delete history: " .. tostring(err)) or "failed to delete history"
end

---Delete only JSON history files in the selected scope; directories are retained.
---@param opts? luma.HistoryOptions|luma.HistoryConfig
---@return luma.HistoryClearResult? result
---@return string? error
function M.clear(opts)
  local cfg, config_err = config(opts)
  if not cfg then
    return nil, config_err
  end
  local result = { deleted = 0, failed = {} } ---@type luma.HistoryClearResult
  for _, name in ipairs(files(cfg.path)) do
    local id = name:sub(1, -6)
    local ok, err = M.delete(id, cfg)
    if ok then
      result.deleted = result.deleted + 1
    else
      result.failed[#result.failed + 1] = { id = id, error = err or "failed to delete history" }
    end
  end
  return result
end

---Discover the main chat and tool directories that Luma can safely decode.
---@return luma.HistoryScope[]
function M.scopes()
  local cfg = require("luma.config").get().history
  local ret = { { scope = "chat", name = "chat" } } ---@type luma.HistoryScope[]
  local handle = vim.uv.fs_scandir(cfg.path .. "/tools")
  if not handle then
    return ret
  end
  while true do
    local name, kind = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if kind == "directory" then
      local tool = decode_name(name)
      if encode_name(tool) == name then
        ret[#ret + 1] = { scope = "tool", tool = tool, name = tool }
      end
    end
  end
  table.sort(ret, function(a, b)
    if a.scope ~= b.scope then
      return a.scope == "chat"
    end
    return a.name < b.name
  end)
  return ret
end

---@param opts? luma.HistoryOptions|luma.HistoryConfig
function M.prune(opts)
  local cfg = config(opts)
  if not cfg then
    return
  end
  local names = files(cfg.path)
  for i = (cfg.max or 20) + 1, #names do
    os.remove(cfg.path .. "/" .. names[i])
  end
end

M._config = config
M._read = read
M._write = write

return M
