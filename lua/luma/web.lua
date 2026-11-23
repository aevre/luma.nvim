---@class luma.TavilyResult
---@field title? string
---@field content? string
---@field url? string

---@class luma.TavilyResponse
---@field answer? string
---@field results? luma.TavilyResult[]

---@alias luma.WebSearchCallback fun(content?: string, error?: string)

local M = {}
local next_id = 0

---@param value? luma.ApiKey
---@return string? key
---@return string? error
local function key(value)
  return require("luma.request").api_key(value)
end

---@param query string
---@param callback luma.WebSearchCallback
---@return luma.RequestHandle
function M.search(query, callback)
  local cfg = require("luma.config").get().web_search
  next_id = next_id + 1
  local id = next_id
  local started = vim.uv.hrtime()
  local debug = require("luma.debug")
  debug.log("web.start", { id = id, query_bytes = #query, max_results = cfg.max_results or 5 })
  local api_key, err = key(cfg.api_key)
  if err or not api_key then
    local message = err or "@web_search requires web_search.api_key"
    debug.log("web.error", { id = id, error = message })
    callback(nil, message)
    return { kill = function() end }
  end

  local args = {
    "curl",
    "--silent",
    "--show-error",
    "--request",
    "POST",
    "--header",
    "Content-Type: application/json",
    "--data-binary",
    vim.json.encode({
      api_key = api_key,
      query = query,
      max_results = cfg.max_results or 5,
      include_answer = true,
    }),
    cfg.url,
  }
  local process = vim.system(args, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local message = vim.trim(result.stderr or "Tavily request failed")
        debug.log("web.error", {
          id = id,
          elapsed_ms = math.floor((vim.uv.hrtime() - started) / 1000000),
          error = message,
        })
        callback(nil, message)
        return
      end
      local ok, data = pcall(vim.json.decode, result.stdout or "")
      if not ok or type(data) ~= "table" then
        debug.log("web.error", {
          id = id,
          elapsed_ms = math.floor((vim.uv.hrtime() - started) / 1000000),
          error = "invalid Tavily response",
        })
        callback(nil, "invalid Tavily response")
        return
      end
      local lines = {}
      if data.answer and data.answer ~= "" then
        lines[#lines + 1] = data.answer
      end
      for i, item in ipairs(data.results or {}) do
        lines[#lines + 1] = ("[%d] %s\n%s\n%s"):format(
          i,
          item.title or "Result",
          item.content or "",
          item.url or ""
        )
      end
      local content = table.concat(lines, "\n\n")
      debug.log("web.done", {
        id = id,
        elapsed_ms = math.floor((vim.uv.hrtime() - started) / 1000000),
        results = #(data.results or {}),
        output_bytes = #content,
      })
      callback(content)
    end)
  end)
  return {
    kill = function()
      pcall(process.kill, process, 15)
    end,
  }
end

---Call back synchronously without a directive, or asynchronously after Tavily search.
---@param text string
---@param callback luma.WebSearchCallback
---@return luma.RequestHandle?
function M.inject(text, callback)
  if not text:find("@web_search", 1, true) then
    callback(text)
    return
  end
  local query = vim.trim(text:gsub("@web_search", ""))
  return M.search(query, function(results, err)
    if not results then
      callback(nil, err)
      return
    end
    callback(("%s\n\n<web_search>\n%s\n</web_search>"):format(query, results))
  end)
end

return M
