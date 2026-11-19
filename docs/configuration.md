# Luma Configuration

Configure Luma through your plugin manager or `require("luma").setup(opts)`. The guarded runtime entrypoint applies defaults without opening windows or starting requests.

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
  },
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
    position = "float",
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

## Models

`models` accepts a keyed table or a list with explicit `name` fields. `model` selects the initial model.

### OpenAI-compatible

```lua
models = {
  openrouter = {
    backend = "openai",
    model = "openai/gpt-4o-mini",
    url = "https://openrouter.ai/api/v1/chat/completions",
    api_key = "OPENROUTER_API_KEY",
    headers = {},
    timeout = 120000,
  },
}
```

`api_key` may be an environment variable name, a literal key, or a function returning a key. Model fields may override the request URL, headers, timeout, and provider model name.

### Ollama

```lua
models = {
  qwen = {
    backend = "ollama",
    model = "qwen2.5-coder:7b",
    url = "http://127.0.0.1:11434/api/chat",
  },
}
```

Ollama requires no API key.

## Requests and context

| Option | Meaning |
| --- | --- |
| `prompt` | Main chat system prompt. |
| `stream` | Enables streamed responses. |
| `timeout` | Request timeout in milliseconds. |
| `max_tokens` | Optional provider token limit. |
| `temperature` | Optional provider sampling temperature. |
| `diagnostics` | Appends source-buffer diagnostics to chat submissions. |
| `max_context_bytes` | Maximum bytes read by context directives. |

## History

`history.path` controls persisted storage. `history.max` limits each independent history scope: the main chat and every registered tool each retain up to that many entries. Tool chats and successful `ctx.generate()` calls use isolated subdirectories under `history.path .. "/tools"`. A tool or individual request may set `history = false`; tools may override retention with `history_max`.

History stores user input, generated output, model, timestamps, and the tool name. It does not store system prompts, credentials, request headers, or side-effect results produced after generation.

## UI and keys

`ui.position` supports `float`, `top`, `right`, `bottom`, and `left`. Fractional width and height values are relative to the editor. `ui.input_height` controls the Prompt share of the layout. `ui.start_insert` focuses Prompt in Insert mode when opening a chat.

The configured keys control submission, close, cancellation, new session, and resend actions. One-off tool generation temporarily uses `keys.cancel` in its source buffer when that key has no existing buffer-local mapping.

## Tavily search

Set `web_search.api_key` to enable `@web_search query` in chat prompts. Luma sends requests to `web_search.url` and includes at most `max_results` entries.

## Debug logging

Set `debug = true` to emit `vim.log.levels.DEBUG` lifecycle messages for LLM and Tavily requests. Logs include request IDs, backend/model, streaming mode, message and byte counts, elapsed time, completion, cancellation, and errors.

Logs never include API keys, authorization headers, complete prompts, or generated content. View them through `:messages` or your notification history.

## Tool models

Model precedence for tools is:

1. `ctx.generate({ model = "name" })` for one request.
2. The tool's top-level `model`.
3. The global `model`.

See [Writing Luma Tools](tools.md) for tool configuration.
