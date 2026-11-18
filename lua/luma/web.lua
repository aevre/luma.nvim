local M = {}

local function key(value)
  return require("luma.request").api_key(value)
end

function M.search(query, callback)
  local cfg = require("luma.config").get().web_search
  local api_key, err = key(cfg.api_key)
  if err or not api_key then
    callback(nil, err or "@web_search requires web_search.api_key")
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
        callback(nil, vim.trim(result.stderr or "Tavily request failed"))
        return
      end
      local ok, data = pcall(vim.json.decode, result.stdout or "")
      if not ok or type(data) ~= "table" then
        callback(nil, "invalid Tavily response")
        return
      end
      local lines = {}
      if data.answer and data.answer ~= "" then
        lines[#lines + 1] = data.answer
      end
      for i, item in ipairs(data.results or {}) do
        lines[#lines + 1] = ("[%d] %s\n%s\n%s"):format(i, item.title or "Result", item.content or "", item.url or "")
      end
      callback(table.concat(lines, "\n\n"))
    end)
  end)
  return {
    kill = function()
      pcall(process.kill, process, 15)
    end,
  }
end

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
