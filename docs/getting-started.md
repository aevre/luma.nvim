# Getting started

## Install

This lazy.nvim example configures one OpenAI-compatible model:

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

Set the environment variable before starting Neovim:

```sh
export OPENROUTER_API_KEY="..."
```

Restart Neovim after changing shell environment variables.

## Open the chat

Run:

```vim
:LumaToggle
```

Type a prompt in the Prompt window and press `<C-s>`. The response appears in Chat.

Useful commands:

```vim
:LumaNew
:LumaModel
:LumaHistory
:LumaCancel
```

## Add buffer context

Use a directive in the Prompt window:

```text
Explain this file.

/buffer
```

Other directives include `/file path` and `@web_search query`. Web search requires Tavily configuration.

## Use Ollama

Ollama does not need an API key:

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

Make sure Ollama is running and the selected model is installed.

## Add a tool

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

Run it with:

```vim
:LumaTool explain
```

From Visual mode, the same command uses the selected text.

## Next steps

- [Using Luma](usage.md)
- [Configuration](configuration.md)
- [Providers and API keys](providers.md)
- [Writing tools](tools.md)
