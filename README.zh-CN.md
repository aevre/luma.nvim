# luma.nvim

一个面向 Neovim 0.10+ 的轻量 LLM 客户端，基于 [win.nvim](https://github.com/aevre/win.nvim) 和 [animate.nvim](https://github.com/aevre/animate.nvim)。它提供流式聊天、多模型、历史会话、上下文扩展、可选 Tavily 搜索和用户自定义工具 API，不依赖 NUI 或 Plenary。

[English](README.md)

- [要求](#要求)
- [安装](#安装)
- [配置](#配置)
- [使用](#使用)
- [工具](#工具)
- [API](#api)
- [开发](#开发)

## 要求

- Neovim 0.10 或更新版本。
- `$PATH` 中可用的 `curl`。
- [win.nvim](https://github.com/aevre/win.nvim)。
- [animate.nvim](https://github.com/aevre/animate.nvim)。

## 安装

GitHub 地址：<https://github.com/aevre/luma.nvim>。

使用 lazy.nvim：

```lua
{
  "https://github.com/aevre/luma.nvim",
  dependencies = {
    "https://github.com/aevre/win.nvim",
    "https://github.com/aevre/animate.nvim",
  },
  opts = {
    model = "openrouter",
    models = {
      openrouter = {
        backend = "openai",
        model = "openai/gpt-4o-mini",
        url = "https://openrouter.ai/api/v1/chat/completions",
        api_key = "OPENROUTER_API_KEY",
      },
    },
  },
}
```

带保护的 `plugin/luma.lua` 入口会应用默认配置。可通过插件管理器配置，或调用 `require("luma").setup(opts)`。

`api_key` 可以是环境变量名、直接填写的密钥，或返回密钥的函数。OpenAI 兼容模型可以覆盖 `url`、`headers`、`timeout` 和 `model`。

Ollama 不需要 API 密钥：

```lua
require("luma").setup({
  model = "qwen",
  models = {
    qwen = {
      backend = "ollama",
      model = "qwen2.5-coder:7b",
      url = "http://127.0.0.1:11434/api/chat",
    },
  },
})
```

## 配置

```lua
require("luma").setup({
  prompt = "You are a concise coding assistant.",
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
    position = "float", -- float、top、right、bottom 或 left
    width = 0.8,
    height = 0.8,
    input_height = 0.18,
    border = "rounded",
    start_insert = true,
  },
  keys = {
    submit = "<C-s>",
    close = "<C-q>",
    cancel = "<C-c>",
    new = "<C-n>",
    resend = "<C-r>",
  },
  web_search = {
    api_key = "TAVILY_API_KEY",
    url = "https://api.tavily.com/search",
    max_results = 5,
  },
  tools = require("my_luma_tools"),
})
```

`models` 支持上面的键值表形式，也支持带显式 `name` 字段的模型列表。工具顶层的 `model` 会覆盖全局模型；单次 `ctx.generate({ model = "name" })` 会再次覆盖工具模型。

设置 `debug = true` 后，LLM 和 Tavily 请求会通过 `vim.log.levels.DEBUG` 输出生命周期日志。日志包含请求编号、backend/model、是否流式、消息和字节数量、耗时、完成、取消及错误信息，不会包含 API key、headers、完整 prompt 或生成内容。可通过 `:messages` 或当前通知插件的历史记录查看。

## 使用

| 命令 | 行为 |
| --- | --- |
| `:LumaToggle` | 显示或隐藏聊天界面。 |
| `:LumaSubmit [prompt]` | 提交参数或当前 Prompt buffer。 |
| `:LumaCancel` | 取消正在进行的 Chat 和一次性工具请求。 |
| `:LumaNew` | 创建新的聊天会话。 |
| `:LumaHistory` | 通过 `vim.ui.select` 恢复历史会话。 |
| `:LumaModel [name]` | 选择或切换当前模型。 |
| `:LumaTool {name}` | 运行用户注册的工具，支持可视范围。 |

浮动聊天包含 Chat、Prompt、Models 和 History 四个窗口。使用 `i`、`o`、`m`、`h` 切换窗口，`<CR>` 选择侧栏项目，`<Esc>` 返回 Prompt，`?` 查看帮助，`q` 关闭整组窗口。Prompt 默认进入 Insert 模式。

聊天输入支持：

- `/buffer`：附加来源 buffer。
- `/file path`：在 `max_context_bytes` 限制内附加文件。
- `@web_search query`：配置 Tavily 后执行网络搜索。
- `diagnostics = true`：附加来源 buffer 的 diagnostics。

## 工具

Luma 默认不注册具体工具。用户通过 `tools` 或 `require("luma.tools").register()` 提供声明式工具或 handler。

声明式工具可读取当前选区、buffer 或输入框：

```lua
local tools = {
  explain = {
    title = " Explain… ",
    loading = { text = "Explaining" },
    system = "Explain the supplied code clearly and answer in Chinese.",
  },
  tests = {
    input = "selection",
    title = " Tests… ",
    system = "Write useful tests and return only test code.",
  },
}
```

Handler 可以自行收集输入、打开独立工具会话、自定义结果窗口、运行外部命令或显示受保护的 diff：

```lua
local tools = {
  translator = {
    handler = function(ctx)
      ctx.chat({
        title = "Translator",
        system = "Translate Chinese into English and other text into Chinese. Output only the translation.",
        history = true,
      })
    end,
  },
  rewrite = function(ctx)
    local text, range = ctx.visual()
    if not text then
      return
    end
    range.changedtick = vim.api.nvim_buf_get_changedtick(range.bufnr)
    ctx.generate({
      title = " Rewriting… ",
      system = "Return only the rewritten replacement text.",
      user = text,
      on_done = function(result, output)
        output:destroy()
        require("luma.diff").show(text, result, range)
      end,
    })
  end,
}
```

[`examples/tools.lua`](examples/tools.lua) 包含作者当前配置使用的完整工具示例：

| 工具 | 行为 |
| --- | --- |
| `ask` | 输入问题并显示一次性回答。 |
| `attach` | 将可视选区附加到当前主聊天上下文。 |
| `explain` | 用中文解释当前 buffer 或选区。 |
| `translate` | 打开拥有独立模型和历史的 Translator。 |
| `word_translate` | 翻译光标下单词或可视选区。 |
| `tests` | 为可视选区生成测试代码。 |
| `rewrite` | 改写选区并打开 Luma 的 guarded diff 预览。 |
| `commit` | 根据暂存改动生成提交信息；按 `c` 提交，按 `y` 复制。 |
| `bash` | 生成 Bash 脚本；按 `r` 执行，按 `y` 复制。 |

Commit 和 Bash 示例不会自动执行生成内容，必须在结果窗口按显式键位。示例刻意不显示第二次确认弹窗；需要时可在用户配置中自行加入。

### 工具上下文

Handler 会收到：

- `ctx.name`、`ctx.tool` 和 `ctx.has_range`。
- 用于收集输入的 `ctx.visual()` 和 `ctx.source(has_range)`。
- 用于一次性请求和结果窗口的 `ctx.generate(spec)`。
- 用于取消进行中一次性工具请求的 `ctx.cancel()`。
- 用于独立双窗口工具会话的 `ctx.chat(spec)`。
- `ctx.loading(opts)`、`ctx.panel(title, keys, opts)` 和 `ctx.strip_fence(text)`。

`ctx.generate()` 支持 `title`、`system`、`user`、`model`、`loading`、`window` 和 `on_done(result, output)`。它显示不抢焦点的光标旁 loading，不修改来源 buffer，返回带 `cancel()` 和兼容别名 `kill()` 的 handle，并移除结果外层的 Markdown fence。生成期间，Luma 会在来源 buffer 临时绑定配置中的取消键（默认 `<C-c>`）；也可以使用 `:LumaCancel` 或 `ctx.cancel()`。已有的 buffer-local 映射不会被覆盖。

`ctx.chat()` 的模型、历史和请求上下文与主聊天隔离。每次提交只发送工具 system prompt 和当前输入。Prompt 是唯一带 footer 的窗口；Output 只显示结果。使用 `i` 聚焦 Prompt、`m` 选择模型、`h` 查看工具历史。

公开注册表方法为 `register`、`unregister`、`get`、`names`、`run` 和 `setup`。之后再次调用 `require("luma").setup()` 会重置并重新应用配置中的工具，因此持久工具应放入 `opts.tools`，或在 setup 之后注册。

## API

```lua
local luma = require("luma")

luma.setup(opts?)
luma.toggle()
luma.submit(text?)
luma.cancel()
luma.new()
luma.resend()
luma.history()
luma.model(name?)
luma.tool(name, has_range?)
```

支持 OpenAI 兼容 chat completions 和 Ollama chat 后端。Luma 还提供流式与非流式请求、取消、历史持久化、上下文扩展、Tavily 搜索和受保护的选区替换。

图片输入、提供商 function calling、行内补全、补全引擎适配器和提供商专属认证流程不在当前范围内。

## 开发

在仓库根目录运行：

```sh
make check
make test
```

需要时可覆盖本地依赖路径：

```sh
make test WIN_NVIM=/path/to/win.nvim ANIMATE_NVIM=/path/to/animate.nvim
```

`make check` 会运行 Stylua、Selene 和 headless smoke suite。带保护的运行时入口应用默认值后，`setup()` 必须仍能安全接受插件管理器传入的用户配置。
