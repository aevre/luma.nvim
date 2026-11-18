local backend = require("luma.backend")

local M = {}

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

local function parser_for(model, on_delta)
  if model.backend == "ollama" then
    return backend.ollama_parser(on_delta)
  end
  return backend.openai_parser(on_delta)
end

function M.start(model, messages, opts)
  opts = opts or {}
  local cfg = require("luma.config").get()
  local body = backend.body(model, messages, cfg)
  local stream = body.stream
  local stdout = ""
  local stderr = ""
  local parse_error
  local done = false
  local key, key_err = api_key(model.api_key)
  if key_err then
    vim.schedule(function()
      opts.on_error("API key function failed: " .. tostring(key_err))
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
  args[#args + 1] = vim.json.encode(body)
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
        if vim.in_fast_event() then
          vim.schedule(function()
            if not done then
              opts.on_delta(text)
            end
          end)
        else
          opts.on_delta(text)
        end
      end)
    or nil

  local process = vim.system(args, {
    text = true,
    timeout = model.timeout or cfg.timeout,
    stdout = function(_, data)
      if not data or done then
        return
      end
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
      if result.code ~= 0 then
        local message = vim.trim(stderr ~= "" and stderr or result.stderr or "curl failed")
        opts.on_error(("request failed (%d): %s"):format(result.code, message))
        return
      end
      if parse_error then
        opts.on_error(parse_error)
        return
      end
      if not stream then
        local text, err = backend.parse_response(model, stdout)
        if not text then
          opts.on_error(err)
          return
        end
        opts.on_delta(text)
      end
      opts.on_done()
    end)
  end)

  return {
    kill = function()
      if done then
        return
      end
      done = true
      pcall(process.kill, process, 15)
    end,
  }
end

M.api_key = api_key

return M
