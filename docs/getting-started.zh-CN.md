# 快速开始

## 安装

下面的 lazy.nvim 配置使用一个 OpenAI 兼容模型：

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

启动 Neovim 前设置环境变量：

```sh
export OPENROUTER_API_KEY="..."
```

修改 Shell 环境变量后需要重新启动 Neovim。

## 打开 Chat

运行：

```vim
:LumaToggle
```

在 Prompt 窗口输入内容并按 `<C-s>`。回复会显示在 Chat 窗口。

常用命令：

```vim
:LumaNew
:LumaModel
:LumaHistory
:LumaCancel
```

## 加入 Buffer 上下文

在 Prompt 中使用指令：

```text
Explain this file.

/buffer
```

还可以使用 `/file path` 和 `@web_search query`。Web 搜索需要配置 Tavily。

## 使用 Ollama

Ollama 不需要 API Key：

```lua
opts = {
  model = "qwen",
  models = {
    qwen = {
      backend = "ollama",
      model = "qwen2.5-coder:7b",
      url = "http://127.0.0.1:11434/api/chat",
    },
  },
}
```

使用前确认 Ollama 已启动，并且已经安装对应模型。

## 添加工具

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

运行：

```vim
:LumaTool explain
```

如果先进入 Visual 模式选择文本，同一命令会使用选中的内容。

## 接下来

- [使用 Luma](usage.zh-CN.md)
- [配置](configuration.zh-CN.md)
- [模型平台和 API Key](providers.zh-CN.md)
- [编写工具](tools.zh-CN.md)
