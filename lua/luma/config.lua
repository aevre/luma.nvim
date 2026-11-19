---@alias luma.ApiKey string|fun(): string?
---@alias luma.MessageRole "system"|"user"|"assistant"

---@class luma.Message
---@field role luma.MessageRole|string
---@field content string

---@class luma.ModelInput
---@field name? string
---@field backend? "openai"|"ollama"
---@field model? string
---@field url? string
---@field api_key? luma.ApiKey
---@field headers? string[]
---@field stream? boolean
---@field timeout? integer

---@class luma.ModelConfig: luma.ModelInput
---@field name string
---@field backend "openai"|"ollama"
---@field model string
---@field url string
---@field stream boolean

---@class luma.UIConfig
---@field position "float"|"left"|"right"|"top"|"bottom"
---@field width number
---@field height number
---@field input_height number
---@field border string
---@field start_insert boolean

---@class luma.KeyConfig
---@field submit string
---@field close string
---@field cancel string
---@field new string
---@field resend string

---@class luma.WebSearchConfig
---@field api_key? luma.ApiKey
---@field url string
---@field max_results integer

---@class luma.ConfigInput
---@field model? string
---@field prompt? string
---@field stream? boolean
---@field timeout? integer
---@field max_tokens? integer
---@field temperature? number
---@field diagnostics? boolean
---@field debug? boolean
---@field max_context_bytes? integer
---@field history? luma.HistoryConfig
---@field ui? luma.UIConfig
---@field tools? table<string, luma.ToolSpec|fun(ctx: luma.ToolContext)|false>
---@field keys? luma.KeyConfig
---@field models? table<string|integer, string|luma.ModelInput>
---@field web_search? luma.WebSearchConfig

---@class luma.Config
---@field model string
---@field prompt string
---@field stream boolean
---@field timeout integer
---@field max_tokens? integer
---@field temperature? number
---@field diagnostics boolean
---@field debug boolean
---@field max_context_bytes integer
---@field history luma.HistoryConfig
---@field ui luma.UIConfig
---@field tools table<string, luma.ToolSpec|fun(ctx: luma.ToolContext)|false>
---@field keys luma.KeyConfig
---@field models luma.ModelConfig[]
---@field web_search luma.WebSearchConfig

local M = {}

local defaults = { ---@type luma.ConfigInput
  model = nil,
  prompt = "You are a helpful coding assistant.",
  stream = true,
  timeout = 120000,
  max_tokens = nil,
  temperature = nil,
  diagnostics = false,
  debug = false,
  max_context_bytes = 200000,
  history = {
    path = vim.fn.stdpath("state") .. "/luma-history",
    max = 20,
  },
  ui = {
    position = "float",
    width = 0.8,
    height = 0.8,
    input_height = 0.18,
    border = "rounded",
    start_insert = true,
  },
  tools = {},
  keys = {
    submit = "<C-s>",
    close = "<C-q>",
    cancel = "<C-c>",
    new = "<C-n>",
    resend = "<C-r>",
  },
  models = {
    {
      name = "openai",
      backend = "openai",
      model = "gpt-4o-mini",
      url = "https://api.openai.com/v1/chat/completions",
      api_key = "OPENAI_API_KEY",
    },
  },
  web_search = {
    api_key = nil,
    url = "https://api.tavily.com/search",
    max_results = 5,
  },
}

local current ---@type luma.Config?

---@param value table
---@return boolean
local function is_list(value)
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    count = count + 1
  end
  for i = 1, count do
    if value[i] == nil then
      return false
    end
  end
  return true
end

---@param models table<string|integer, string|luma.ModelInput>
---@return luma.ModelConfig[]
local function normalize_models(models)
  local ret = {} ---@type luma.ModelConfig[]
  if type(models) ~= "table" then
    error("luma: models must be a table")
  end

  local list = is_list(models)
  for key, value in pairs(models) do
    local model
    if type(value) == "string" then
      model = { name = list and value or key, model = value }
    elseif type(value) == "table" then
      model = vim.deepcopy(value)
      model.name = model.name or (not list and key or model.model)
    else
      error("luma: each model must be a string or table")
    end
    model.backend = model.backend or "openai"
    model.model = model.model or model.name
    if not model.name or not model.model then
      error("luma: each model needs a name and model")
    end
    if model.backend ~= "openai" and model.backend ~= "ollama" then
      error("luma: unsupported backend " .. tostring(model.backend))
    end
    model.stream = model.stream ~= false
    if model.backend == "openai" then
      model.url = model.url or "https://api.openai.com/v1/chat/completions"
    else
      model.url = model.url or "http://127.0.0.1:11434/api/chat"
    end
    ret[#ret + 1] = model
  end

  table.sort(ret, function(a, b)
    return a.name < b.name
  end)
  if #ret == 0 then
    error("luma: configure at least one model")
  end
  return ret
end

---Merge defaults, normalize model entries, and validate the selected model.
---@param opts? luma.ConfigInput
---@return luma.Config
function M.setup(opts)
  current = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  current.models = normalize_models(current.models)
  if current.model == nil then
    current.model = current.models[1].name
  end
  if not M.model(current.model) then
    error("luma: unknown default model " .. tostring(current.model))
  end
  return current
end

---@return luma.Config
function M.get()
  return current or M.setup()
end

---@param name string
---@return luma.ModelConfig?
function M.model(name)
  local cfg = current or defaults
  local models = cfg.models
  if models == defaults.models then
    models = normalize_models(models)
  end
  for _, model in ipairs(models) do
    if model.name == name then
      return model
    end
  end
end

M.defaults = defaults
M.normalize_models = normalize_models

return M
