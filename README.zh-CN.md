# luma.nvim

一个面向 Neovim 0.10+ 的轻量 LLM 客户端，支持流式 Chat、多模型、历史记录、上下文扩展、可选 Web 搜索和自定义工具。

[English](README.md)

## 要求

- Neovim 0.10 或更高版本
- `$PATH` 中可用的 `curl`
- [win.nvim](https://github.com/aevre/win.nvim)
- [animate.nvim](https://github.com/aevre/animate.nvim)

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

启动 Neovim 前设置密钥：

```sh
export OPENROUTER_API_KEY="..."
```

`api_key` 可以是环境变量名、密钥字符串，或一个返回密钥的函数。

## 使用

```vim
:LumaToggle
:LumaSubmit Explain this buffer
:LumaModel
:LumaHistory
:LumaCancel
```

主界面包含 Chat、Prompt、Models 和 History 四个窗口。在 Prompt 中使用 `/buffer`、`/file path` 或 `@web_search query` 可以加入额外上下文。

Luma 默认不注册具体工具。可以在同一个 `opts` 表中加入工具：

```lua
opts = {
  tools = {
    explain = {
      source = "auto",
      system = "Explain the supplied code clearly.",
    },
  },
}
```

使用 `:LumaTool explain` 运行，也可以先选择一段文本再运行。

## 文档

- [快速开始](docs/getting-started.zh-CN.md)
- [使用 Luma](docs/usage.zh-CN.md)
- [配置](docs/configuration.zh-CN.md)
- [模型平台和 API Key](docs/providers.zh-CN.md)
- [编写工具](docs/tools.zh-CN.md)
- [Lua API](docs/api.zh-CN.md)
- [开发](docs/development.zh-CN.md)
- [完整工具示例](examples/tools.lua)

## 开发

```sh
make check
make test
```
