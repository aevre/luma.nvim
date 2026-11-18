# luma.nvim

A small Neovim 0.10+ LLM client built on [win.nvim](https://github.com/aevre/win.nvim) and [animate.nvim](https://github.com/aevre/animate.nvim). It provides streaming chat, multiple models, saved sessions, context expansion, optional Tavily search, and a user-defined tool API without NUI or Plenary.

[简体中文](README.zh-CN.md)

- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Tools](#tools)
- [API](#api)
- [Development](#development)

## Requirements

- Neovim 0.10 or newer.
- `curl` available in `$PATH`.
- [win.nvim](https://github.com/aevre/win.nvim).
- [animate.nvim](https://github.com/aevre/animate.nvim).

## Installation

Available on GitHub: <https://github.com/aevre/luma.nvim>.

With lazy.nvim:

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

The guarded `plugin/luma.lua` entrypoint applies defaults. Configure the plugin through your plugin manager or call `require("luma").setup(opts)`.

`api_key` may be an environment variable name, a literal key, or a function returning a key. OpenAI-compatible models may override `url`, `headers`, `timeout`, and `model`.

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
  debug = false,
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

`models` accepts the keyed form above or a list of model tables with explicit `name` fields. A tool-level `model` overrides the global model; `ctx.generate({ model = "name" })` overrides both for one request.

Set `debug = true` to emit `vim.log.levels.DEBUG` lifecycle messages for LLM and Tavily requests. Logs include request IDs, backend/model, streaming mode, message and byte counts, elapsed time, completion, cancellation, and errors. They never include API keys, headers, complete prompts, or generated content. View them through `:messages` or your configured notification history.

## Usage

| Command | Action |
| --- | --- |
| `:LumaToggle` | Show or hide the chat UI. |
| `:LumaSubmit [prompt]` | Submit the argument or current Prompt buffer. |
| `:LumaCancel` | Cancel active chat and one-off tool requests. |
| `:LumaNew` | Start a new chat session. |
| `:LumaHistory` | Restore a saved chat session with `vim.ui.select`. |
| `:LumaModel [name]` | Select or switch the active model. |
| `:LumaTool {name}` | Run a registered user tool; visual ranges are supported. |

The floating chat contains Chat, Prompt, Models, and History windows. Use `i`, `o`, `m`, and `h` to move between them, `<CR>` to select a sidebar item, `<Esc>` to return to Prompt, `?` for help, and `q` to close the group. Prompt enters Insert mode by default.

Chat prompts support:

- `/buffer [number]` to append the source buffer or another listed buffer.
- `/file path` to append a file within `max_context_bytes`.
- `@web_search query` to search Tavily when configured.
- `diagnostics = true` to append source-buffer diagnostics.

The Prompt exposes directives, listed buffers, and file paths through its standard `completefunc`. Luma does not open or replace an external completion menu.

### Completion plugins

With [blink.cmp](https://github.com/Saghen/blink.cmp), add a provider backed by the current buffer's `completefunc`:

```lua
sources = {
  default = { "lsp", "path", "snippets", "buffer", "complete_func" },
  providers = {
    complete_func = {
      name = "CompleteFunc",
      module = "blink.cmp.sources.complete_func",
      enabled = function()
        return vim.bo.completefunc ~= ""
      end,
      opts = {
        complete_func = function()
          return vim.bo.completefunc
        end,
      },
    },
  },
}
```

`nvim-cmp` does not include a source for an existing buffer `completefunc`. Keep native user-defined completion available with `<C-x><C-u>`, or add an explicit mapping if your cmp mappings override that key sequence:

```lua
local cmp = require("cmp")

cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ["<C-x><C-u>"] = cmp.mapping(function()
      vim.api.nvim_feedkeys(vim.keycode("<C-x><C-u>"), "n", false)
    end, { "i" }),
  }),
})
```

This opens Neovim's native completion menu for Luma candidates; the rest of `nvim-cmp` continues to use its configured sources.

## Tools

Luma registers no concrete tools by default. User configuration supplies declarative tools or handlers through `tools` or `require("luma.tools").register()`.

A declarative tool can use the current selection, buffer, or an input prompt:

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

Handlers can collect input, open independent tool sessions, customize result windows, run external commands, or show guarded diffs:

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

The complete example in [`examples/tools.lua`](examples/tools.lua) contains the tools used by the author's configuration:

| Tool | Behavior |
| --- | --- |
| `ask` | Prompt for a question and show a one-off answer. |
| `attach` | Add a visual selection to the current chat as context. |
| `explain` | Explain the current buffer or selection in Chinese. |
| `translate` | Open an independent translator with its own model and history. |
| `word_translate` | Translate the word under the cursor or a visual selection. |
| `tests` | Generate test code for a visual selection. |
| `rewrite` | Rewrite a selection and open Luma's guarded diff preview. |
| `commit` | Generate a commit message from staged changes; `c` commits and `y` copies. |
| `bash` | Generate a Bash script; `r` executes it and `y` copies it. |

The Commit and Bash examples never execute generated content automatically. Execution requires an explicit result-window mapping. The example intentionally has no second confirmation dialog; add one in user configuration if desired.

### Tool context

Handlers receive:

- `ctx.name`, `ctx.tool`, and `ctx.has_range`.
- `ctx.visual()` and `ctx.source(has_range)` for input collection.
- `ctx.generate(spec)` for one-off requests and result windows.
- `ctx.cancel()` to cancel active one-off tool requests.
- `ctx.chat(spec)` for an independent two-window tool session.
- `ctx.loading(opts)`, `ctx.panel(title, keys, opts)`, and `ctx.strip_fence(text)`.

`ctx.generate()` accepts `title`, `system`, `user`, `model`, `loading`, `window`, and `on_done(result, output)`. It displays a non-focusable cursor-adjacent spinner, does not modify the source buffer, returns a handle with `cancel()` and the compatible `kill()` alias, and strips a surrounding Markdown fence from the completed result. While generation is pending, Luma temporarily maps the configured cancel key (default `<C-c>`) in the source buffer; `:LumaCancel` and `ctx.cancel()` provide global alternatives. Existing buffer-local mappings are never replaced.

`ctx.chat()` keeps its model, history, and request context separate from the main chat. Each submission sends only the tool system prompt and current input. The Prompt window owns the single footer; the Output window renders only the result. Use `i` for Prompt, `m` for model selection, and `h` for tool history.

Public registry methods are `register`, `unregister`, `get`, `names`, `run`, and `setup`. A later `require("luma").setup()` resets and reapplies the configured registry, so persistent tools should live under `opts.tools` or be registered after setup.

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

Supported backends are OpenAI-compatible chat completions and Ollama chat. Luma also provides streaming and non-streaming requests, cancellation, persisted history, context expansion, Tavily search, and guarded selection replacement.

Image input, provider function calling, inline completion, completion-engine adapters, and provider-specific authentication flows are outside the current scope.

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

`make check` runs Stylua, Selene, and the headless smoke suite. Keep `setup()` safe when a plugin manager applies user options after the guarded runtime entrypoint.
