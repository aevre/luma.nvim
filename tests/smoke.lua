local root = vim.fn.getcwd()
local win_dir = vim.env.WIN_NVIM or "/home/immortal/Projects/lib/win.nvim"
local animate_dir = vim.env.ANIMATE_NVIM or "/home/immortal/Projects/lib/animate.nvim"
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(win_dir)
vim.opt.runtimepath:prepend(animate_dir)

local function test_config()
  require("luma")._bootstrap()
  assert(vim.api.nvim_get_hl(0, { name = "LumaLoadingBorder" }).link == "FloatBorder")
  assert(vim.api.nvim_get_hl(0, { name = "LumaResultBorder" }).link == "FloatTitle")
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
  assert(value.prompt == "test" and value.debug == false)
  assert(value.ui.width == 0.5 and value.ui.height == 0.8)
  assert(#value.models == 2 and value.models[1].name == "local_ollama")
  assert(value.models[1].url == "http://127.0.0.1:11434/api/chat")
  assert(value.models[2].url == "https://api.openai.com/v1/chat/completions")
  local again = config.setup({ models = { { name = "only", backend = "ollama", model = "tiny" } } })
  assert(again.model == "only" and #again.models == 1)
  local original_notify = vim.notify
  local message
  rawset(vim, "notify", function(text, level)
    message = { text = text, level = level }
  end)
  config.setup({ debug = true, models = { { name = "only", backend = "ollama", model = "tiny" } } })
  require("luma.debug").log("test.event", { messages = 2, input_bytes = 10 })
  rawset(vim, "notify", original_notify)
  assert(message and message.level == vim.log.levels.DEBUG)
  assert(message.text == "luma debug: test.event input_bytes=10 messages=2")
  config.setup({ models = { { name = "only", backend = "ollama", model = "tiny" } } })
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

local function test_empty_response()
  local original_system = vim.system
  local error_message
  rawset(vim, "system", function(_, opts, callback)
    opts.stdout(nil, '{"message":{"content":""}}')
    vim.schedule(function()
      callback({ code = 0, stdout = "", stderr = "" })
    end)
    return { kill = function() end }
  end)
  require("luma.request").start({ backend = "ollama", model = "test", url = "http://test", stream = false }, {}, {
    on_delta = function() end,
    on_error = function(err)
      error_message = err
    end,
    on_done = function()
      error("empty response must not complete successfully")
    end,
  })
  vim.wait(50, function()
    return error_message ~= nil
  end)
  rawset(vim, "system", original_system)
  assert(error_message == "provider returned an empty response")
end

local function test_large_request_body_uses_stdin()
  local original_system = vim.system
  local completed = false
  local prompt = string.rep("x", 256 * 1024)
  rawset(vim, "system", function(args, opts, callback)
    assert(vim.tbl_contains(args, "@-"))
    assert(not vim.tbl_contains(args, prompt))
    assert(type(opts.stdin) == "string" and #opts.stdin > #prompt)
    local body = vim.json.decode(opts.stdin)
    assert(body.messages[2].content == prompt)
    opts.stdout(nil, '{"message":{"content":"ok"}}')
    vim.schedule(function()
      callback({ code = 0, stdout = "", stderr = "" })
    end)
    return { kill = function() end }
  end)
  require("luma.request").start({ backend = "ollama", model = "test", url = "http://test", stream = false }, {
    { role = "system", content = "test" },
    { role = "user", content = prompt },
  }, {
    on_delta = function(text)
      assert(text == "ok")
    end,
    on_error = function(err)
      error(err)
    end,
    on_done = function()
      completed = true
    end,
  })
  assert(vim.wait(50, function()
    return completed
  end))
  rawset(vim, "system", original_system)
end

local function test_visual_selection()
  local original = vim.api.nvim_get_current_buf()
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(scratch)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "    model = spec.model,", "next line" })
  vim.fn.setpos("'<", { 0, 1, 5, 0 })
  vim.fn.setpos("'>", { 0, 1, 9, 0 })
  local text, range = require("luma.context").visual()
  assert(text == "model")
  assert(range.start_line == 1 and range.start_col == 5)
  assert(range.end_line == 1 and range.end_col == 9)
  vim.fn.setpos("'<", { 0, 1, 1, 0 })
  vim.fn.setpos("'>", { 0, 1, 100, 0 })
  text, range = require("luma.context").visual()
  assert(text == "    model = spec.model,")
  assert(range.end_col == #"    model = spec.model,")
  vim.fn.setpos("'<", { 0, 1, 13, 0 })
  vim.fn.setpos("'>", { 0, 2, 4, 0 })
  text = require("luma.context").visual()
  assert(text == "spec.model,\nnext")
  vim.api.nvim_set_current_buf(original)
  vim.api.nvim_buf_delete(scratch, { force = true })
end

local function test_context_completion()
  local context = require("luma.context")
  local start_col, items = context.complete("ask /b", 6)
  assert(start_col == 5 and vim.deep_equal(items, { "/buffer" }))

  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local file = dir .. "/example.lua"
  vim.fn.writefile({ "return true" }, file)
  start_col, items = context.complete("/file " .. dir .. "/exa", #(dir .. "/exa") + 6)
  assert(start_col and vim.tbl_contains(items, file))

  local target = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(target, dir .. "/target.lua")
  vim.api.nvim_buf_set_lines(target, 0, -1, false, { "target buffer" })
  start_col, items = context.complete("/buffer tar", 11)
  assert(start_col == 9)
  local match = vim.tbl_filter(function(item)
    return item.word == tostring(target)
  end, items)
  assert(#match == 1 and match[1].abbr:match("target.lua$"))
  local expanded = assert(context.expand("review /buffer " .. target, { bufnr = vim.api.nvim_get_current_buf() }))
  assert(expanded:find("target buffer", 1, true))
  vim.api.nvim_buf_delete(target, { force = true })
  vim.fn.delete(dir, "rf")
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
  assert(history.delete("second", opts))
  assert(not history.load("second", opts))
  local unsafe, unsafe_err = history.delete("../third", opts)
  assert(not unsafe and unsafe_err == "invalid history id")
  history.save({ id = "shared", model = "test", messages = {} }, opts)
  local tool_opts = { path = dir .. "/tools/translate", max = 2 }
  history.save({ id = "shared", model = "test", messages = {} }, tool_opts)
  assert(history.delete("shared", tool_opts))
  assert(history.load("shared", opts) and not history.load("shared", tool_opts))
  local original_history = require("luma.config").get().history
  require("luma.config").get().history = opts
  history.save({ id = "encoded", model = "test", messages = {} }, { scope = "tool", tool = "translate/zh" })
  local scopes = history.scopes()
  assert(vim.tbl_contains(
    vim.tbl_map(function(scope)
      return scope.tool
    end, scopes),
    "translate/zh"
  ))
  assert(history.delete("encoded", { scope = "tool", tool = "translate/zh" }))
  require("luma.config").get().history = original_history
  local cleared = assert(history.clear(opts))
  assert(cleared.deleted == 2 and #cleared.failed == 0 and #history.list(opts) == 0)
  vim.fn.delete(dir, "rf")
end

local function test_tools_registry()
  local original_buf = vim.api.nvim_get_current_buf()
  local history_dir = vim.fn.tempname()
  require("luma.config").setup({
    history = { path = history_dir, max = 20 },
    models = { { name = "only", backend = "ollama", model = "tiny" } },
  })
  local tools = require("luma.tools")
  local ok, err = pcall(tools.generate, { title = "invalid" })
  assert(not ok and err:match("requires string system and user fields"))
  local request = require("luma.request")
  local original_start = request.start
  local received
  local killed = 0
  local callbacks
  rawset(request, "start", function(model, messages, opts)
    received = { model = model, messages = messages }
    callbacks = opts
    return {
      kill = function()
        killed = killed + 1
      end,
    }
  end)
  local handle = tools.generate({ system = "system", user = "user", model = "only", loading = false })
  assert(received.model.name == "only")
  assert(received.messages[1].content == "system" and received.messages[2].content == "user")
  assert(vim.fn.maparg("<C-c>", "n", false, true).desc == "Cancel Luma task")
  handle.cancel()
  handle.kill()
  assert(killed == 1)
  assert(vim.fn.maparg("<C-c>", "n", false, true).buffer ~= 1)
  tools.generate({ system = "system", user = "user", model = "only", loading = false })
  assert(vim.fn.maparg("<C-c>", "n", false, true).desc == "Cancel Luma task")
  callbacks.on_error("test error")
  assert(vim.fn.maparg("<C-c>", "n", false, true).buffer ~= 1)
  local history_panel
  tools.generate({
    system = "system",
    user = "remember me",
    model = "only",
    tool = "translate",
    loading = false,
    on_done = function(_, output)
      history_panel = output
    end,
  })
  callbacks.on_delta("translated")
  callbacks.on_done()
  local saved = require("luma.history").list({ scope = "tool", tool = "translate" })
  assert(#saved == 1 and saved[1].kind == "generate" and saved[1].tool == "translate")
  assert(saved[1].messages[1].content == "remember me" and saved[1].messages[2].content == "translated")
  history_panel:destroy()
  tools.generate({
    system = "system",
    user = "forget me",
    model = "only",
    tool = "translate",
    history = false,
    loading = false,
    on_done = function(_, output)
      history_panel = output
    end,
  })
  callbacks.on_delta("not saved")
  callbacks.on_done()
  assert(#require("luma.history").list({ scope = "tool", tool = "translate" }) == 1)
  history_panel:destroy()
  vim.api.nvim_set_current_buf(original_buf)
  rawset(request, "start", original_start)
  local called
  tools.setup({
    custom = function(ctx)
      called = ctx.has_range
    end,
    prompt_tool = {
      system = "Return a short answer.",
      source = "buffer",
    },
    ask = false,
  })
  assert(tools.get("custom") and tools.get("prompt_tool"))
  assert(not tools.get("ask"))
  tools.run("custom", true)
  assert(called == true)
  assert(vim.tbl_contains(tools.names(), "prompt_tool"))

  local declarative_original = vim.api.nvim_get_current_buf()
  local declarative_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(declarative_buf)
  vim.api.nvim_buf_set_lines(declarative_buf, 0, -1, false, { "one", "two", "three" })
  local original_generate = tools.generate
  local generated
  rawset(tools, "generate", function(spec)
    generated = spec
    return spec
  end)
  tools.setup({
    auto = {
      system = "auto system",
      instruction = "auto instruction",
    },
    buffer = {
      source = "buffer",
      system = function(_, input)
        return "buffer system: " .. input
      end,
    },
    prompt = {
      source = "prompt",
      input_title = "Question: ",
      system = "prompt system",
    },
    invalid = {
      source = "unknown",
      system = "invalid",
    },
  })
  tools.run("auto", false)
  assert(generated.system == "auto system")
  assert(generated.user == "auto instruction\n\none\ntwo\nthree")
  local visual = tools.visual
  rawset(tools, "visual", function()
    return "selected", { bufnr = vim.api.nvim_get_current_buf() }
  end)
  tools.setup({
    auto = { system = "auto" },
    selection = { source = "selection", system = "selection" },
    buffer = { source = "buffer", system = "buffer" },
  })
  tools.run("auto", true)
  assert(generated.user == "selected")
  tools.run("selection", true)
  assert(generated.user == "selected")
  tools.run("buffer", true)
  assert(generated.user == "one\ntwo\nthree")
  local selection_ok = pcall(tools.run, "selection", false)
  assert(selection_ok and generated.user == "one\ntwo\nthree")
  rawset(tools, "visual", visual)
  tools.setup({
    auto = { system = "auto system", instruction = "auto instruction" },
    buffer = {
      source = "buffer",
      system = function(_, input)
        return "buffer system: " .. input
      end,
    },
    prompt = {
      source = "prompt",
      input_title = "Question: ",
      system = "prompt system",
    },
    invalid = { source = "unknown", system = "invalid" },
  })
  tools.run("buffer", true)
  assert(generated.system == "buffer system: one\ntwo\nthree")
  assert(generated.user == "one\ntwo\nthree")
  vim.api.nvim_feedkeys(vim.keycode("question<CR>"), "t", false)
  tools.run("prompt", false)
  assert(generated.system == "prompt system" and generated.user == "question")
  local source_ok, source_err = pcall(tools.run, "invalid", false)
  assert(not source_ok and type(source_err) == "string" and source_err:match("invalid source unknown"))
  rawset(tools, "generate", original_generate)
  vim.api.nvim_set_current_buf(declarative_original)
  vim.api.nvim_buf_delete(declarative_buf, { force = true })

  tools.setup()
  assert(#tools.names() == 0)
  assert(not tools.get("custom"))
  local panel = tools.panel(" Test ")
  assert(vim.fn.maparg("?", "n", false, true).desc == "Help")
  assert(vim.fn.maparg("q", "n", false, true).desc == "Close")
  local footer = vim.tbl_map(function(part)
    return part[1]
  end, panel.opts.footer)
  assert(table.concat(footer):find("Help", 1, true))
  assert(table.concat(footer):find("Close", 1, true))
  assert(vim.wo[panel.win].winhighlight:find("FloatBorder:LumaResultBorder", 1, true))
  panel:destroy()
  local small = tools._result_size("short")
  local large = tools._result_size(string.rep("x", 1000) .. "\n" .. string.rep("line\n", 100))
  assert(small.width == 36 and small.height == 6)
  assert(large.width <= math.floor(vim.o.columns * 0.8))
  assert(large.height <= math.floor(vim.o.lines * 0.8))
  local original = vim.api.nvim_get_current_buf()
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(scratch)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "one", "two", "three" })
  local source_text = table.concat(vim.api.nvim_buf_get_lines(scratch, 0, -1, false), "\n")
  local clear = tools._spinner({ text = false, interval = 10 })
  local spinner_win
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.focusable == false and vim.api.nvim_win_get_buf(win) ~= scratch then
      spinner_win = win
      break
    end
  end
  assert(spinner_win and vim.api.nvim_win_is_valid(spinner_win))
  assert(vim.wo[spinner_win].winhighlight == "Normal:LumaLoading,FloatBorder:LumaLoadingBorder")
  assert(#vim.api.nvim_win_get_config(spinner_win).border == 8)
  assert(vim.api.nvim_win_get_config(spinner_win).focusable == false)
  assert(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(spinner_win), 0, -1, false)[1] == "⠋")
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  vim.wait(30)
  assert(vim.api.nvim_win_get_config(spinner_win).relative ~= "")
  assert(table.concat(vim.api.nvim_buf_get_lines(scratch, 0, -1, false), "\n") == source_text)
  clear()
  assert(not vim.api.nvim_win_is_valid(spinner_win))
  local clear_text = tools._spinner({ text = "Generating", interval = 10 })
  spinner_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.focusable == false and vim.api.nvim_win_get_buf(win) ~= scratch then
      spinner_win = win
    end
  end
  assert(spinner_win)
  assert(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(spinner_win), 0, -1, false)[1]:match("Generating$"))
  clear_text()
  vim.api.nvim_set_current_buf(original)
  vim.api.nvim_buf_delete(scratch, { force = true })
  vim.fn.delete(history_dir, "rf")
end

local function test_tool_chat()
  local tool_chat = require("luma.tool_chat")
  local spec = { title = "Translator", system = "Translate", model = "only", history_max = 3 }
  local chat = tool_chat.open("translate", spec)
  assert(chat.model == "only")
  assert(chat.input:valid() and chat.output:valid())
  assert(chat.output.opts.footer == nil)
  local help_count = 0
  for _, item in ipairs(chat.input.opts.footer or {}) do
    if item[1] == " Help " then
      help_count = help_count + 1
    end
  end
  assert(help_count == 1)
  local insert_mapping
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(chat.input.buf, "n")) do
    if mapping.lhs == "i" then
      insert_mapping = mapping
    end
  end
  assert(insert_mapping and insert_mapping.desc == "Insert")
  local output_lines = vim.api.nvim_buf_get_lines(chat.output.buf, 0, -1, false)
  assert(#output_lines == 1 and output_lines[1] == " ")
  local output_config = vim.api.nvim_win_get_config(chat.output.win)
  local input_config = vim.api.nvim_win_get_config(chat.input.win)
  local group_left = output_config.col
  local group_right = output_config.col + output_config.width + 2
  local group_top = output_config.row
  local group_bottom = input_config.row + input_config.height + 2
  assert(math.abs((group_left + group_right) / 2 - vim.o.columns / 2) <= 0.5)
  assert(math.abs((group_top + group_bottom) / 2 - vim.o.lines / 2) <= 0.5)
  local history = tool_chat._history_config(chat)
  assert(history.scope == "tool" and history.tool == "translate" and history.max == 3)
  local request = require("luma.request")
  local original_start = request.start
  rawset(request, "start", function(_, _, opts)
    vim.schedule(function()
      opts.on_error("provider unavailable")
    end)
    return { kill = function() end }
  end)
  vim.api.nvim_buf_set_lines(chat.input.buf, 0, -1, false, { "retry me" })
  chat.input.opts.actions.submit(chat.input)
  vim.wait(50, function()
    return chat.error ~= nil
  end)
  rawset(request, "start", original_start)
  assert(chat.error == "provider unavailable")
  assert(chat.input:text() == "retry me")
  assert(chat.output:text() == "Error: provider unavailable")
  tool_chat.close("translate")
  assert(tool_chat._chats.translate == nil)
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
  assert(vim.wo[ui.output.win].winhighlight:find("FloatBorder:LumaBorder", 1, true))
  assert(vim.wo[ui.input.win].winhighlight:find("FloatTitle:LumaTitle", 1, true))
  assert(require("luma.config").get().ui.start_insert)
  assert(vim.api.nvim_get_current_win() == ui.input.win)
  assert(vim.bo[ui.input.buf].completefunc == "v:lua.require'luma.ui'.complete")
  assert(#vim.api.nvim_get_autocmds({ event = "TextChangedI", buffer = ui.input.buf }) == 0)
  vim.api.nvim_buf_set_lines(ui.input.buf, 0, -1, false, { "/b" })
  vim.api.nvim_win_set_cursor(ui.input.win, { 1, 2 })
  assert(ui.complete(1, "") == 0)
  assert(vim.deep_equal(ui.complete(0, "/b"), { "/buffer" }))
  vim.api.nvim_buf_set_lines(ui.input.buf, 0, -1, false, { "" })
  ui.models:focus()
  assert(vim.fn.maparg("h", "n", false, true).desc == "History")
  assert(vim.fn.maparg("o", "n", false, true).desc == "Chat")
  ui.input:focus()
  ui.input.opts.actions.models(ui.input)
  assert(vim.api.nvim_get_current_win() == ui.models.win)
  ui.models.opts.actions.history(ui.models)
  assert(vim.api.nvim_get_current_win() == ui.history.win)
  ui.history.opts.actions.output(ui.history)
  assert(vim.api.nvim_get_current_win() == ui.output.win)
  ui.output.opts.actions.input(ui.output)
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
  local output_buf = assert(ui.output.buf)
  local input_buf = assert(ui.input.buf)
  local models_buf = assert(ui.models.buf)
  local history_buf = assert(ui.history.buf)
  ui.history:focus()
  assert(vim.fn.maparg("q", "n", false, true).desc == "Close chat")
  ui.history.opts.actions.close(ui.history)
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
  ui.set_input("translate this")
  assert(ui.input_text() == "translate this")
  ui.clear_input()
  assert(ui.input_text() == "")
  ui.render({ "##  You", "", "hello", "", "## 󰚩 Assistant", "", "" }, " Test… ", true)
  local highlights = vim.api.nvim_buf_get_extmarks(ui.output.buf, vim.api.nvim_get_namespaces().luma, 0, -1, {
    details = true,
  })
  assert(#highlights == 2)
  assert(highlights[1][4].hl_group == "LumaUser")
  assert(highlights[2][4].hl_group == "LumaAssistant")
  ui.render_stream("one", " Test… ")
  ui.render_stream("\ntwo", " Test… ")
  assert(ui.output:text() == "##  You\n\nhello\n\n## 󰚩 Assistant\n\none\ntwo")
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
  test_empty_response()
  test_large_request_body_uses_stdin()
  test_visual_selection()
  test_context_completion()
  test_history()
  test_tools_registry()
  test_tool_chat()
  test_window_lifecycle()
end

local ok, err = xpcall(test, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("luma.nvim smoke tests passed")
vim.cmd("qa!")
