# luma.nvim

一个面向 Neovim 0.10+ 的轻量 LLM 客户端，基于 [win.nvim](https://github.com/aevre/win.nvim) 和 [animate.nvim](https://github.com/aevre/animate.nvim)。它提供流式聊天、多模型、历史会话、上下文扩展、可选 Tavily 搜索和用户自定义工具 API，不依赖 NUI 或 Plenary。

[English](README.md)

## 要求

- Neovim 0.10 或更新版本。
- `$PATH` 中可用的 `curl`。
- [win.nvim](https://github.com/aevre/win.nvim)。
- [animate.nvim](https://github.com/aevre/animate.nvim)。

## 安装

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

`api_key` 可以是环境变量名、直接填写的密钥，或返回密钥的函数。OpenAI 兼容模型、Ollama、UI、键位、历史、Tavily 和调试日志详见[配置](docs/configuration.zh-CN.md)。

## 使用

```vim
:LumaToggle
:LumaSubmit Explain this buffer
:LumaModel
:LumaHistory
:LumaCancel
```

聊天界面包含 Chat、Prompt、Models 和 History。Prompt 支持 `/buffer`、`/file`、`@web_search`、diagnostics 和标准 `completefunc` 补全。

命令、窗口导航、上下文指令、原生补全、blink.cmp 和 nvim-cmp 集成详见[使用 Luma](docs/usage.zh-CN.md)。

## 工具

Luma 默认不注册具体工具。最小声明式工具如下：

```lua
require("luma").setup({
  tools = {
    explain = {
      source = "auto",
      system = "清晰解释提供的代码。",
    },
  },
})
```

通过 `source = "auto"`、`"selection"`、`"buffer"` 或 `"prompt"` 明确输入来源。自定义工作流使用 `run(ctx)` 函数和命名字段形式的 `ctx.generate({ ... })`。

全部字段、执行流程、自定义 run、独立工具 Chat、取消、受保护改写和副作用安全规则详见[编写 Luma 工具](docs/tools.zh-CN.md)。[`examples/tools.lua`](examples/tools.lua) 提供完整示例。

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

支持 OpenAI 兼容 chat completions 和 Ollama chat 后端。

## 文档

- [配置](docs/configuration.zh-CN.md)
- [使用 Luma](docs/usage.zh-CN.md)
- [编写 Luma 工具](docs/tools.zh-CN.md)
- [完整工具示例](examples/tools.lua)

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
