# Configuration

Configure Luma through your plugin manager or `require("luma").setup(opts)`.

## Minimal setup

```lua
require("luma").setup({
  model = "openrouter",
  models = {
    openrouter = {
      backend = "openai",
      model = "openai/gpt-4o-mini",
      url = "https://openrouter.ai/api/v1/chat/completions",
      api_key = "OPENROUTER_API_KEY",
    },
  },
})
```

`model` must match one of the configured model names.

## General options

| Option              | Default                 | Meaning                                                 |
| ------------------- | ----------------------- | ------------------------------------------------------- |
| `model`             | first configured model  | Initial model name.                                     |
| `prompt`            | coding assistant prompt | System prompt for the main Chat.                        |
| `stream`            | `true`                  | Stream provider output.                                 |
| `timeout`           | `120000`                | Request timeout in milliseconds.                        |
| `max_tokens`        | `nil`                   | Optional provider token limit.                          |
| `temperature`       | `nil`                   | Optional provider temperature.                          |
| `diagnostics`       | `false`                 | Add source-buffer diagnostics to main-chat submissions. |
| `debug`             | `false`                 | Log request lifecycle, response structure, and provider errors through `vim.notify` without dumping prompts or raw response bodies. |
| `max_context_bytes` | `200000`                | Shared byte limit for `/buffer` and `/file` context.    |

## Models

`models` may be a keyed table:

```lua
models = {
  fast = {
    backend = "openai",
    model = "provider/model-name",
    url = "https://provider.example/v1/chat/completions",
    api_key = "PROVIDER_API_KEY",
  },
}
```

It may also be a list when every item has a `name` field.

| Field     | Meaning                                                              |
| --------- | -------------------------------------------------------------------- |
| `name`    | Required only in list form.                                          |
| `backend` | `"openai"` or `"ollama"`. Defaults to `"openai"`.                    |
| `model`   | Model identifier sent to the provider.                               |
| `url`     | Chat endpoint.                                                       |
| `api_key` | Environment variable name, literal key, or function returning a key. |
| `headers` | Extra curl headers.                                                  |
| `stream`  | Per-model streaming override.                                        |
| `timeout` | Per-model timeout override.                                          |

See [Providers and API keys](providers.md) for examples.

## History

```lua
history = {
  path = vim.fn.stdpath("state") .. "/luma-history",
  max = 20,
}
```

The main Chat and every tool have separate retention limits. Tool Chat and successful `ctx.generate()` calls are stored below `history.path .. "/tools"`.

History stores user input, generated output, model, timestamps, and tool name. It does not store system prompts, credentials, request headers, or command results produced after generation.

A tool or individual generation may set `history = false`. A tool may override retention with `history_max`.

## UI

```lua
ui = {
  position = "float",
  width = 0.8,
  height = 0.8,
  input_height = 0.18,
  border = "rounded",
  start_insert = true,
}
```

`position` accepts `float`, `left`, `right`, `top`, or `bottom`. Fractional width and height values are relative to the editor.

## Keys

```lua
keys = {
  submit = "<C-s>",
  close = "<C-q>",
  cancel = "<C-c>",
  new = "<C-n>",
  resend = "<C-r>",
}
```

One-off generation uses the configured cancel key in the source buffer only when that buffer has no existing local mapping for it.

## Web search

```lua
web_search = {
  api_key = "TAVILY_API_KEY",
  url = "https://api.tavily.com/search",
  max_results = 5,
}
```

After configuration, use `@web_search query` in the main Prompt.

## Tools

```lua
tools = require("my_luma_tools")
```

Tool model selection follows this order:

1. `ctx.generate({ model = "name" })`
2. the tool's `model`
3. the global `model`

See [Writing tools](tools.md).

## Complete example

```lua
require("luma").setup({
  prompt = "You are a concise coding assistant.",
  model = "openrouter",
  models = {
    openrouter = {
      backend = "openai",
      model = "openai/gpt-4o-mini",
      url = "https://openrouter.ai/api/v1/chat/completions",
      api_key = "OPENROUTER_API_KEY",
    },
    qwen = {
      backend = "ollama",
      model = "qwen2.5-coder:7b",
      url = "http://127.0.0.1:11434/api/chat",
    },
  },
  diagnostics = false,
  history = {
    path = vim.fn.stdpath("state") .. "/luma-history",
    max = 20,
  },
  ui = {
    position = "float",
    width = 0.8,
    height = 0.8,
    input_height = 0.18,
    border = "rounded",
    start_insert = true,
  },
  web_search = {
    api_key = "TAVILY_API_KEY",
    url = "https://api.tavily.com/search",
    max_results = 5,
  },
  tools = require("my_luma_tools"),
})
```
