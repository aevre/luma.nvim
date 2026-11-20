---@alias luma.DeltaCallback fun(text: string)
---@alias luma.StreamParser fun(chunk?: string, eof?: boolean): boolean?, string?

---@class luma.RequestBody
---@field model string
---@field messages luma.Message[]
---@field stream boolean
---@field temperature? number
---@field max_tokens? integer
---@field options? { num_predict: integer }

local M = {}

---@param payload string
---@param on_delta luma.DeltaCallback
---@return boolean? done
---@return string? error
local function emit_openai(payload, on_delta)
  if payload == "[DONE]" then
    return true
  end
  local ok, data = pcall(vim.json.decode, payload)
  if not ok then
    return nil, "invalid OpenAI stream JSON: " .. tostring(data)
  end
  if data.error then
    return nil, data.error.message or vim.inspect(data.error)
  end
  local choice = data.choices and data.choices[1]
  local delta = choice and choice.delta or {}
  local text = delta.content or delta.reasoning_content
  if text and text ~= "" then
    on_delta(text)
  end
  return false
end

---@param payload string
---@param on_delta luma.DeltaCallback
---@return boolean? done
---@return string? error
local function emit_openai_response(payload, on_delta)
  local ok, data = pcall(vim.json.decode, payload)
  if not ok then
    return nil, "OpenAI stream response was neither SSE nor valid JSON: " .. tostring(data)
  end
  if data.error then
    local err = type(data.error) == "table" and (data.error.message or vim.inspect(data.error)) or data.error
    return nil, tostring(err)
  end
  local choice = data.choices and data.choices[1]
  local message = choice and choice.message or {}
  local text = message.content or message.reasoning_content
  if not text or text == "" then
    return nil, "OpenAI response did not contain choices[1].message.content"
  end
  on_delta(text)
  return true
end

---Parse server-sent events, emitting one event only after its blank-line terminator.
---@param on_delta luma.DeltaCallback
---@return luma.StreamParser
function M.openai_parser(on_delta)
  local state = { buffer = "", event = {}, fallback = "", sse = false }

  local function process_event()
    if #state.event == 0 then
      return false
    end
    local payload = table.concat(state.event, "\n")
    state.event = {}
    return emit_openai(payload, on_delta)
  end

  return function(chunk, eof)
    chunk = chunk or ""
    state.buffer = state.buffer .. chunk
    if not state.sse then
      state.fallback = state.fallback .. chunk
    end
    state.buffer = state.buffer:gsub("\r\n", "\n")
    while true do
      local pos = state.buffer:find("\n", 1, true)
      if not pos then
        break
      end
      local line = state.buffer:sub(1, pos - 1)
      state.buffer = state.buffer:sub(pos + 1)
      if line == "" then
        local done, err = process_event()
        if err or done then
          return done, err
        end
      elseif line:sub(1, 5) == "data:" then
        state.sse = true
        state.fallback = ""
        state.event[#state.event + 1] = vim.trim(line:sub(6))
      end
    end
    if eof then
      if state.buffer ~= "" then
        local line = state.buffer
        state.buffer = ""
        if line:sub(1, 5) == "data:" then
          state.sse = true
          state.fallback = ""
          state.event[#state.event + 1] = vim.trim(line:sub(6))
        end
      end
      if state.sse then
        return process_event()
      end
      local payload = vim.trim(state.fallback)
      if payload ~= "" then
        return emit_openai_response(payload, on_delta)
      end
      return false
    end
    return false
  end
end

---Parse Ollama's newline-delimited JSON stream while preserving partial lines.
---@param on_delta luma.DeltaCallback
---@return luma.StreamParser
function M.ollama_parser(on_delta)
  local buffer = ""
  local function process(line)
    if line == "" then
      return false
    end
    local ok, data = pcall(vim.json.decode, line)
    if not ok then
      return nil, "invalid Ollama stream JSON: " .. tostring(data)
    end
    if data.error then
      return nil, tostring(data.error)
    end
    local message = data.message or {}
    local text = message.content or message.thinking
    if text and text ~= "" then
      on_delta(text)
    end
    return data.done == true
  end

  return function(chunk, eof)
    buffer = buffer .. (chunk or "")
    while true do
      local pos = buffer:find("\n", 1, true)
      if not pos then
        break
      end
      local done, err = process(vim.trim(buffer:sub(1, pos - 1)))
      buffer = buffer:sub(pos + 1)
      if err or done then
        return done, err
      end
    end
    if eof and vim.trim(buffer) ~= "" then
      local line = vim.trim(buffer)
      buffer = ""
      return process(line)
    end
    return false
  end
end

---@param model luma.ModelConfig
---@param messages luma.Message[]
---@param cfg luma.Config
---@return luma.RequestBody
function M.body(model, messages, cfg)
  local body = {
    model = model.model,
    messages = messages,
    stream = model.stream ~= false and cfg.stream ~= false,
  }
  if cfg.temperature ~= nil then
    body.temperature = cfg.temperature
  end
  if cfg.max_tokens ~= nil then
    body.max_tokens = cfg.max_tokens
  end
  if model.backend == "ollama" and cfg.max_tokens ~= nil then
    body.max_tokens = nil
    body.options = { num_predict = cfg.max_tokens }
  end
  return body
end

---@param model luma.ModelConfig
---@param text string
---@return string? content
---@return string? error
function M.parse_response(model, text)
  local ok, data = pcall(vim.json.decode, text)
  if not ok then
    return nil, "invalid JSON response: " .. tostring(data)
  end
  if data.error then
    local err = type(data.error) == "table" and (data.error.message or vim.inspect(data.error)) or data.error
    return nil, tostring(err)
  end
  if model.backend == "ollama" then
    return data.message and data.message.content or nil, "Ollama response did not contain message.content"
  end
  local choice = data.choices and data.choices[1]
  return choice and choice.message and choice.message.content or nil,
    "OpenAI response did not contain choices[1].message.content"
end

return M
