local backend = require("luma.backend")

---@class luma.RequestCallbacks
---@field on_delta luma.DeltaCallback
---@field on_error fun(error: string)
---@field on_done fun()

---@class luma.RequestHandle
---@field kill fun()

local M = {}
local next_id = 0

---@param messages luma.Message[]
---@return integer
local function message_bytes(messages)
  local bytes = 0
  for _, message in ipairs(messages) do
    bytes = bytes + #(message.content or "")
  end
  return bytes
end

---Resolve an API key callback, environment-variable name, or literal value.
---@param value? luma.ApiKey
---@return string? key
---@return string? error
local function api_key(value)
  if type(value) == "function" then
    local ok, result = pcall(value)
    return ok and result or nil, ok and nil or result
  end
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local env = vim.env[value]
  return env and env ~= "" and env or value
end

---@param model luma.ModelConfig
---@param on_delta luma.DeltaCallback
---@return luma.StreamParser
local function parser_for(model, on_delta, on_response)
  if model.backend == "ollama" then
    return backend.ollama_parser(on_delta, on_response)
  end
  return backend.openai_parser(on_delta, on_response)
end

---Start curl and marshal all completion callbacks onto Neovim's main loop.
---@param model luma.ModelConfig
---@param messages luma.Message[]
---@param opts luma.RequestCallbacks
---@return luma.RequestHandle
function M.start(model, messages, opts)
  opts = opts or {}
  local cfg = require("luma.config").get()
  local body = backend.body(model, messages, cfg)
  local stream = body.stream
  next_id = next_id + 1
  local id = next_id
  local started = vim.uv.hrtime()
  local output_bytes = 0
  local response_bytes = 0
  local response_chunks = 0
  local response_events = 0
  local first_shape
  local last_shape
  local debug = require("luma.debug")
  local function observe_response(data)
    if not cfg.debug then
      return
    end
    response_events = response_events + 1
    last_shape = backend.response_shape(data)
    first_shape = first_shape or last_shape
  end
  debug.log("request.start", {
    id = id,
    backend = model.backend,
    model = model.name or model.model,
    stream = stream,
    messages = #messages,
    input_bytes = message_bytes(messages),
    timeout_ms = model.timeout or cfg.timeout,
    temperature = body.temperature,
    max_tokens = body.max_tokens or (body.options and body.options.num_predict),
    think = body.think,
  })
  local stdout = ""
  local stderr = ""
  local parse_error
  local received = false
  -- Once set by completion or cancellation, late process callbacks become inert.
  local done = false
  local key, key_err = api_key(model.api_key)
  if key_err then
    local err = "API key function failed: " .. tostring(key_err)
    debug.log("request.error", { id = id, error = err })
    vim.schedule(function()
      opts.on_error(err)
    end)
    return { kill = function() end }
  end

  local args = {
    "curl",
    "--no-buffer",
    "--silent",
    "--show-error",
    "--request",
    "POST",
    "--header",
    "Content-Type: application/json",
  }
  if model.backend == "openai" and key and key ~= "" then
    args[#args + 1] = "--header"
    args[#args + 1] = "Authorization: Bearer " .. key
  end
  args[#args + 1] = "--data-binary"
  args[#args + 1] = "@-"
  args[#args + 1] = model.url
  for _, header in ipairs(model.headers or {}) do
    table.insert(args, #args, "--header")
    table.insert(args, #args, header)
  end

  local parser = stream
      and parser_for(model, function(text)
        if done then
          return
        end
        received = received or text:find("%S") ~= nil
        output_bytes = output_bytes + #text
        if vim.in_fast_event() then
          vim.schedule(function()
            if not done then
              opts.on_delta(text)
            end
          end)
        else
          opts.on_delta(text)
        end
      end, observe_response)
    or nil

  local process = vim.system(args, {
    text = true,
    stdin = vim.json.encode(body),
    timeout = model.timeout or cfg.timeout,
    stdout = function(_, data)
      if not data or done then
        return
      end
      response_bytes = response_bytes + #data
      response_chunks = response_chunks + 1
      -- Streaming responses are parsed incrementally; non-streaming output is buffered whole.
      if stream and parser then
        local _, err = parser(data, false)
        parse_error = parse_error or err
      else
        stdout = stdout .. data
      end
    end,
    stderr = function(_, data)
      if data then
        stderr = stderr .. data
      end
    end,
  }, function(result)
    vim.schedule(function()
      if done then
        return
      end
      if stream and parser and not parse_error then
        local _, err = parser("", true)
        parse_error = err
      end
      done = true
      local clean_stderr = stderr ~= "" and stderr or result.stderr or ""
      local diagnostics = {
        id = id,
        elapsed_ms = math.floor((vim.uv.hrtime() - started) / 1000000),
        exit_code = result.code,
        response_bytes = response_bytes,
        response_chunks = response_chunks,
        stderr_bytes = #clean_stderr,
      }
      local function log_result(event)
        diagnostics.response_events = response_events
        diagnostics.response_first = first_shape
        diagnostics.response_last = last_shape
        debug.log(event, diagnostics)
      end
      if result.code ~= 0 then
        local message = vim.trim(clean_stderr ~= "" and clean_stderr or "curl failed")
        local err = ("request failed (%d): %s"):format(result.code, message)
        diagnostics.error = err
        log_result("request.error")
        opts.on_error(err)
        return
      end
      if parse_error then
        diagnostics.error = parse_error
        log_result("request.error")
        opts.on_error(parse_error)
        return
      end
      if not stream then
        local text, err = backend.parse_response(model, stdout, observe_response)
        if not text then
          diagnostics.error = err
          log_result("request.error")
          opts.on_error(err or "provider response could not be parsed")
          return
        end
        received = text:find("%S") ~= nil
        output_bytes = #text
        opts.on_delta(text)
      end
      if not received then
        local err = "provider returned an empty response"
        diagnostics.error = err
        log_result("request.error")
        opts.on_error(err)
        return
      end
      diagnostics.output_bytes = output_bytes
      log_result("request.done")
      opts.on_done()
    end)
  end)

  return {
    kill = function()
      if done then
        return
      end
      done = true
      debug.log(
        "request.cancel",
        { id = id, elapsed_ms = math.floor((vim.uv.hrtime() - started) / 1000000) }
      )
      pcall(process.kill, process, 15)
    end,
  }
end

M.api_key = api_key

return M
