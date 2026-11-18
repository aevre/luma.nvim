local M = {}

local function config(opts)
  return opts or require("luma.config").get().history
end

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

local function files(path)
  local ret = {}
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

function M.save(session, opts)
  local cfg = config(opts)
  vim.fn.mkdir(cfg.path, "p")
  local id = session.id or (os.date("%Y%m%d-%H%M%S") .. "-" .. tostring(vim.uv.hrtime()))
  session.id = id
  session.updated_at = os.time()
  local ok, err = write(cfg.path .. "/" .. id .. ".json", session)
  if not ok then
    return nil, "failed to save history: " .. tostring(err)
  end
  M.prune(cfg)
  return id
end

function M.load(id, opts)
  local cfg = config(opts)
  return read(cfg.path .. "/" .. id:gsub("%.json$", "") .. ".json")
end

function M.list(opts)
  local cfg = config(opts)
  local ret = {}
  for _, name in ipairs(files(cfg.path)) do
    local item = read(cfg.path .. "/" .. name)
    if item then
      item.id = item.id or name:sub(1, -6)
      ret[#ret + 1] = item
    end
  end
  return ret
end

function M.prune(opts)
  local cfg = config(opts)
  local names = files(cfg.path)
  for i = (cfg.max or 20) + 1, #names do
    os.remove(cfg.path .. "/" .. names[i])
  end
end

M._read = read
M._write = write

return M
