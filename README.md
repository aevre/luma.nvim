# luma.nvim

A small Neovim 0.10+ LLM client with streaming chat, multiple models, saved history, context expansion, optional web search, and user-defined tools.

[简体中文](README.zh-CN.md)

## Demos

### Coordinated workspace

![Luma Chat, Prompt, Models, and History workspace](docs/workspace.png)

The four coordinated windows can be opened without sending a provider request.

### Keyboard navigation

![Navigating between Luma workspace panels](docs/navigation.gif)

The built-in panel keys move focus between Models, History, Prompt, and Chat. Sending a request still requires a configured provider and API key.

## Requirements

- Neovim 0.10 or newer
- `curl` in `$PATH`
- [win.nvim](https://github.com/aevre/win.nvim)
- [animate.nvim](https://github.com/aevre/animate.nvim)

## Install

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

Set the key before starting Neovim:

```sh
export OPENROUTER_API_KEY="..."
```

`api_key` may be an environment variable name, a literal key, or a function that returns a key.

## Use

```vim
:LumaToggle
:LumaSubmit Explain this buffer
:LumaModel
:LumaHistory
:LumaCancel
```

The main UI contains Chat, Prompt, Models, and History windows. Add `/buffer`, `/file path`, or `@web_search query` to a prompt to include extra context.

Luma does not register concrete tools by default. Add tools to the same `opts` table:

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

Run it with `:LumaTool explain` or from a Visual selection.

## Documentation

- [Getting started](docs/getting-started.md)
- [Using Luma](docs/usage.md)
- [Configuration](docs/configuration.md)
- [Providers and API keys](docs/providers.md)
- [Writing tools](docs/tools.md)
- [Lua API](docs/api.md)
- [Development](docs/development.md)
- [Complete tool examples](examples/tools.lua)

## Development

Run `:checkhealth luma` in Neovim to inspect runtime requirements and model credentials without exposing secrets. `make health` exercises the same provider headlessly.

```sh
make check
make test
```
