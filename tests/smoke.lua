local root = vim.fn.getcwd()
local win_dir = vim.env.WIN_NVIM or "/home/immortal/Projects/lib/win.nvim"
local animate_dir = vim.env.ANIMATE_NVIM or "/home/immortal/Projects/lib/animate.nvim"
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(win_dir)
vim.opt.runtimepath:prepend(animate_dir)

local function test_config()
  package.loaded["luma.config"] = nil
  local config = require("luma.config")
  local value = config.setup({
    prompt = "test",
    ui = { width = 0.5 },
    models = {
      local_ollama = { backend = "ollama", model = "qwen2.5-coder" },
      remote = { backend = "openai", model = "test-model", api_key = "TEST_KEY" },
    },
    model = "local_ollama",
  })
  assert(value.prompt == "test")
  assert(value.ui.width == 0.5 and value.ui.height == 0.8)
  assert(#value.models == 2 and value.models[1].name == "local_ollama")
  assert(value.models[1].url == "http://127.0.0.1:11434/api/chat")
  assert(value.models[2].url == "https://api.openai.com/v1/chat/completions")
  local again = config.setup({ models = { { name = "only", backend = "ollama", model = "tiny" } } })
  assert(again.model == "only" and #again.models == 1)
end

local function test_openai_parser()
  local chunks = {}
  local parse = require("luma.backend").openai_parser(function(text)
    chunks[#chunks + 1] = text
  end)
  assert(not parse('data: {"choices":[{"delta":{"content":"hel', false))
  assert(
    not parse(
      'lo"},"finish_reason":null}]}\n\ndata: {"choices":[{"delta":{"content":"!"},"finish_reason":null}]}\n\n',
      false
    )
  )
  local done, err = parse("data: [DONE]\n\n", false)
  assert(done and not err)
  assert(table.concat(chunks) == "hello!")
end

local function test_ollama_parser()
  local chunks = {}
  local parse = require("luma.backend").ollama_parser(function(text)
    chunks[#chunks + 1] = text
  end)
  assert(not parse('{"message":{"content":"one"},"done":false}\n{"message":{"content":"tw', false))
  local done, err = parse('o"},"done":false}\n{"message":{"content":""},"done":true}\n', false)
  assert(done and not err)
  assert(table.concat(chunks) == "onetwo")
end

local function test_history()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local opts = { path = dir, max = 2 }
  local history = require("luma.history")
  local session = {
    id = "roundtrip",
    model = "test",
    messages = { { role = "user", content = "hello" } },
  }
  local id, err = history.save(session, opts)
  assert(id == "roundtrip" and not err)
  local loaded = assert(history.load(id, opts))
  assert(loaded.model == "test" and loaded.messages[1].content == "hello")
  history.save({ id = "second", model = "test", messages = {} }, opts)
  history.save({ id = "third", model = "test", messages = {} }, opts)
  assert(#history.list(opts) == 2)
  vim.fn.delete(dir, "rf")
end

local function test_tools_registry()
  local tools = require("luma.tools")
  local called
  tools.setup({
    custom = function(ctx)
      called = ctx.has_range
    end,
    prompt_tool = {
      system = "Return a short answer.",
      input = "buffer",
    },
    ask = false,
  })
  assert(tools.get("custom") and tools.get("prompt_tool"))
  assert(not tools.get("ask"))
  tools.run("custom", true)
  assert(called == true)
  assert(vim.tbl_contains(tools.names(), "prompt_tool"))
  tools.setup()
  assert(#tools.names() == 0)
  assert(not tools.get("custom"))
  local small = tools._result_size("short")
  local large = tools._result_size(string.rep("x", 1000) .. "\n" .. string.rep("line\n", 100))
  assert(small.width == 36 and small.height == 6)
  assert(large.width <= math.floor(vim.o.columns * 0.8))
  assert(large.height <= math.floor(vim.o.lines * 0.8))
  local before = #vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, {})
  local clear = tools._spinner()
  assert(#vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, {}) == before + 1)
  clear()
  assert(#vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, {}) == before)
end

local function test_window_lifecycle()
  local Win = require("win")
  assert(type(require("animate")) == "table")
  Win.setup({ win = { enter = false, backdrop = false } })
  package.loaded["luma.config"] = nil
  package.loaded["luma.ui"] = nil
  package.loaded["luma.session"] = nil
  package.loaded["luma.models"] = nil
  require("luma.config").setup({
    model = "test",
    models = { { name = "test", backend = "ollama", model = "test" } },
    ui = { position = "float", width = 0.7, height = 0.7 },
  })
  require("luma.session").new()
  local source_win = vim.api.nvim_get_current_win()
  vim.wo[source_win].cursorline = true
  local ui = require("luma.ui")
  ui.open()
  assert(not vim.wo[source_win].cursorline)
  assert(ui.valid() and ui.output:valid() and ui.input:valid())
  assert(ui.models:valid() and ui.history:valid())
  assert(require("luma.config").get().ui.start_insert)
  assert(vim.api.nvim_get_current_win() == ui.input.win)
  ui.models:focus()
  assert(vim.fn.maparg("h", "n", false, true).desc == "History")
  assert(vim.fn.maparg("o", "n", false, true).desc == "Chat")
  ui.input:focus()
  ui.input.opts.actions.models()
  assert(vim.api.nvim_get_current_win() == ui.models.win)
  ui.models.opts.actions.history()
  assert(vim.api.nvim_get_current_win() == ui.history.win)
  ui.history.opts.actions.output()
  assert(vim.api.nvim_get_current_win() == ui.output.win)
  ui.output.opts.actions.input()
  assert(vim.api.nvim_get_current_win() == ui.input.win)
  vim.cmd("stopinsert")
  local output_config = vim.api.nvim_win_get_config(ui.output.win)
  local input_config = vim.api.nvim_win_get_config(ui.input.win)
  local models_config = vim.api.nvim_win_get_config(ui.models.win)
  local history_config = vim.api.nvim_win_get_config(ui.history.win)
  assert(output_config.border and input_config.border and models_config.border and history_config.border)
  assert(input_config.row == output_config.row + output_config.height + 2)
  assert(models_config.col == output_config.col + output_config.width + 2)
  assert(history_config.row == models_config.row + models_config.height + 2)
  assert(vim.api.nvim_buf_get_lines(ui.models.buf, 0, 1, false)[1] == "● test")
  local output_help = vim.fn.maparg("?", "n", false, true)
  assert(output_help.buffer == 1 and output_help.desc == "Help")
  ui.input:focus()
  local input_help = vim.fn.maparg("?", "n", false, true)
  assert(input_help.buffer == 1 and input_help.desc == "Help")
  ui.input.opts.actions.help(ui.input)
  local help_win
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "win_help" then
      help_win = win
    end
  end
  assert(help_win)
  local help_config = vim.api.nvim_win_get_config(help_win)
  assert(help_config.border and help_config.row and help_config.col)
  ui.input.opts.actions.help(ui.input)
  assert(not vim.api.nvim_win_is_valid(help_win))
  local output_buf = ui.output.buf
  local input_buf = ui.input.buf
  local models_buf = ui.models.buf
  local history_buf = ui.history.buf
  ui.history:focus()
  assert(vim.fn.maparg("q", "n", false, true).desc == "Close chat")
  ui.history.opts.actions.close()
  assert(vim.wo[source_win].cursorline)
  assert(not ui.valid())
  assert(vim.api.nvim_buf_is_valid(output_buf) and vim.api.nvim_buf_is_valid(input_buf))
  ui.open()
  assert(not vim.wo[source_win].cursorline)
  assert(ui.valid() and ui.output.buf == output_buf and ui.input.buf == input_buf)
  assert(ui.models.buf == models_buf and ui.history.buf == history_buf)
  vim.api.nvim_win_close(ui.input.win, true)
  assert(vim.wait(1000, function()
    return not ui.output:valid() and not ui.models:valid() and not ui.history:valid()
  end))
  assert(vim.wo[source_win].cursorline)
  ui.open()
  assert(ui.valid())
  ui.render({ "## You", "", "hello", "", "## Assistant", "", "" }, " Test… ", true)
  ui.render_stream("one", " Test… ")
  ui.render_stream("\ntwo", " Test… ")
  assert(ui.output:text() == "## You\n\nhello\n\n## Assistant\n\none\ntwo")
  for _ = 1, 1000 do
    ui.render_stream("x", " Test… ")
  end
  assert(ui.output:text():sub(-1000) == string.rep("x", 1000))
  ui.render({ "hello", "world" }, " Test ")
  assert(ui.output:text() == "hello\nworld")
  ui.render(vim.fn.map(vim.fn.range(1, 30), "'line ' .. v:val"), " Test ")
  vim.api.nvim_win_set_cursor(ui.output.win, { 1, 0 })
  ui.render(vim.fn.map(vim.fn.range(1, 31), "'line ' .. v:val"), " Test ", true)
  assert(vim.api.nvim_win_get_cursor(ui.output.win)[1] == 1)
  vim.api.nvim_win_set_cursor(ui.output.win, { 31, 0 })
  ui.render(vim.fn.map(vim.fn.range(1, 32), "'line ' .. v:val"), " Test ", true)
  assert(vim.api.nvim_win_get_cursor(ui.output.win)[1] == 32)
  ui.destroy()
  assert(vim.wo[source_win].cursorline)
  assert(not vim.api.nvim_buf_is_valid(output_buf) and not vim.api.nvim_buf_is_valid(input_buf))
  assert(not vim.api.nvim_buf_is_valid(models_buf) and not vim.api.nvim_buf_is_valid(history_buf))
end

local function test()
  test_config()
  test_openai_parser()
  test_ollama_parser()
  test_history()
  test_tools_registry()
  test_window_lifecycle()
end

local ok, err = xpcall(test, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("luma.nvim smoke tests passed")
vim.cmd("qa!")
