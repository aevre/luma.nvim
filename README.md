# luma.nvim

A small Neovim 0.10+ LLM client built on [win.nvim](https://github.com/aevre/win.nvim) and [animate.nvim](https://github.com/aevre/animate.nvim). It provides streaming chat, multiple models, saved sessions, context expansion, optional Tavily search, and a user-defined tool API without NUI or Plenary.

[简体中文](README.zh-CN.md)

## Requirements

- Neovim 0.10 or newer.
- `curl` available in `$PATH`.
- [win.nvim](https://github.com/aevre/win.nvim).
- [animate.nvim](https://github.com/aevre/animate.nvim).

## Installation

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

`api_key` may be an environment variable name, a literal key, or a function returning a key. See [Configuration](docs/configuration.md) for OpenAI-compatible models, Ollama, UI, keys, history, Tavily, and debug logging.

## Usage

```vim
:LumaToggle
:LumaSubmit Explain this buffer
:LumaModel
:LumaHistory
:LumaCancel
```

The chat has Chat, Prompt, Models, and History windows. Prompt supports `/buffer`, `/file`, `@web_search`, diagnostics, and standard `completefunc` completion.

See [Using Luma](docs/usage.md) for commands, navigation, context directives, native completion, blink.cmp, and nvim-cmp integration.

## Tools

Luma registers no concrete tools by default. A minimal declarative tool looks like this:

```lua
require("luma").setup({
  tools = {
    explain = {
      source = "auto",
      system = "Explain the supplied code clearly.",
    },
  },
})
```

Use `source = "auto"`, `"selection"`, `"buffer"`, or `"prompt"` to state where input comes from. Custom workflows use a `run(ctx)` function and named-field `ctx.generate({ ... })` calls.

See [Writing Luma Tools](docs/tools.md) for every field, execution flow, custom runs, isolated tool chats, cancellation, guarded rewrites, and side-effect safety. [`examples/tools.lua`](examples/tools.lua) contains complete examples.

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

Supported backends are OpenAI-compatible chat completions and Ollama chat.

## Documentation

- [Configuration](docs/configuration.md)
- [Using Luma](docs/usage.md)
- [Writing Luma Tools](docs/tools.md)
- [llm.nvim API Keys and Free Providers](docs/llm-api-keys.md)
- [Complete tool examples](examples/tools.lua)

## Development

Run from the repository root:

```sh
make check
make test
```

Override local dependency paths when needed:

```sh
make test WIN_NVIM=/path/to/win.nvim ANIMATE_NVIM=/path/to/animate.nvim
```
