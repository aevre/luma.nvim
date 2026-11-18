# luma.nvim

A small Neovim 0.10+ LLM client built on [win.nvim](../win.nvim) and [animate.nvim](../animate.nvim). It provides streaming chat, multiple models, saved sessions, buffer/file context, optional Tavily search, and selection rewrite tools without NUI or Plenary.

## Requirements

- Neovim 0.10+
- `curl`
- `win.nvim`
- `animate.nvim`

## Install

Local `lazy.nvim` setup:

```lua
{
  dir = vim.fn.expand("~/Projects/lib/luma.nvim"),
  dependencies = {
    { dir = vim.fn.expand("~/Projects/lib/win.nvim") },
    { dir = vim.fn.expand("~/Projects/lib/animate.nvim") },
  },
  opts = {
    model = "openai",
    models = {
      openai = {
        backend = "openai",
        model = "gpt-4o-mini",
        api_key = "OPENAI_API_KEY",
      },
    },
  },
}
```

`api_key` may be an environment variable name, a literal key, or a function returning a key. OpenAI-compatible services can override `url`, `headers`, and `model`.

Ollama needs no API key:

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

## Configuration

```lua
require("luma").setup({
  prompt = "You are a concise coding assistant.",
  stream = true,
  timeout = 120000,
  max_tokens = nil,
  temperature = nil,
  diagnostics = false,
  max_context_bytes = 200000,
  history = {
    path = vim.fn.stdpath("state") .. "/luma-history",
    max = 20,
  },
  ui = {
    position = "float", -- float, top, right, bottom, or left
    width = 0.8,
    height = 0.8,
    input_height = 0.18,
    border = "rounded",
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
})
```

`models` accepts either the keyed form shown above or a list of model tables with explicit `name` fields.

## Commands

| Command | Action |
| --- | --- |
| `:LumaToggle` | Show or hide the chat UI. |
| `:LumaSubmit [prompt]` | Submit the argument or current input buffer. |
| `:LumaCancel` | Cancel the active request. |
| `:LumaNew` | Start a new session. |
| `:LumaHistory` | Restore a saved session with `vim.ui.select`. |
| `:LumaModel [name]` | Select or switch the active model. |
| `:LumaTool {name}` | Run a registered user tool. Accepts a visual range. |

The floating chat layout uses a bordered output and prompt column plus a right sidebar with Models and History. Navigation works from every chat window: `i` focuses Prompt, `o` focuses Chat, `m` focuses Models, and `h` focuses History. Press `<CR>` to select a sidebar item, `<Esc>` to return to Prompt, and `?` to toggle key help. Prompt enters Insert mode by default; set `ui.start_insert = false` to keep Normal mode.

In chat prompts:

- `/buffer` appends the source buffer.
- `/file path` appends a file, subject to `max_context_bytes`.
- `@web_search query` searches Tavily when `web_search.api_key` is configured.
- `diagnostics = true` appends diagnostics from the source buffer.

## Tool API

Luma registers no tools by default. `:LumaTool` only dispatches tools supplied through `setup()` or `require("luma.tools").register()`.

Add a prompt-based tool in `setup()`:

```lua
require("luma").setup({
  tools = {
    review = {
      title = " Code review… ",
      input = "selection", -- selection, buffer, or prompt
      system = "Review this code for correctness, security, and missing tests.",
      prompt = "Return findings in severity order.",
    },
  },
})
```

Run it with `:'<,'>LumaTool review`. Valid `input` values are `selection`, `buffer`, and `prompt`. Without `input`, a visual range is used when provided and the current buffer otherwise. `system` and `prompt` may also be functions receiving `(ctx, input)`; `on_done(result, window)` can customize the completed result window.

For custom UI, external commands, or side effects, register a handler:

```lua
require("luma.tools").register("project_files", function(ctx)
  local files = vim.fn.systemlist({ "git", "ls-files" })
  ctx.generate(
    " Project files… ",
    "Summarize the project structure.",
    table.concat(files, "\n")
  )
end)
```

A handler receives `ctx.name`, `ctx.tool`, `ctx.has_range`, `ctx.visual()`, `ctx.source(has_range)`, `ctx.generate(title, system, user, on_done, window_opts)`, `ctx.panel(title, keys, opts)`, and `ctx.strip_fence(text)`. Public registry methods are `register`, `unregister`, `get`, `names`, `run`, and `setup`.

`ctx.generate()` shows an animated extmark at the current cursor while the request runs and returns a cancellable request handle. It does not create an empty result window. After completion it removes the spinner, sizes the result window from its content, and calls `on_done(result, output)` with the newly created window.

Calling `require("luma.tools").register(name, spec)` after `require("luma").setup()` is useful for separate extension modules. A later Luma `setup()` resets the registry and reapplies `opts.tools`, so persistent extensions should be declared in `opts.tools` or registered from the plugin's `config` callback after setup.

Recipes for attach, rewrite, translation, test generation, commit messages, Bash generation, and post-commit LazyGit belong in user configuration rather than Luma core. A complete working example is available in `examples/tools.lua`.

## Scope

Implemented: OpenAI-compatible and Ollama chat, streaming and non-streaming responses, cancellation, multiple models, persisted history, context expansion, Tavily search, guarded diff support, and the user tool API.

Not implemented: image input, function calling, inline completion, `nvim-cmp`/`blink.cmp` adapters, or provider-specific authentication flows such as Copilot.

## Development

```sh
make check
make test
```

Override dependency paths when needed:

```sh
make test WIN_NVIM=/path/to/win.nvim ANIMATE_NVIM=/path/to/animate.nvim
```
