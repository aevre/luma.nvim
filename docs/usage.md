# Using Luma

## Commands

| Command | Action |
| --- | --- |
| `:LumaToggle` | Show or hide the chat UI. |
| `:LumaSubmit [prompt]` | Submit the argument or current Prompt buffer. |
| `:LumaCancel` | Cancel active chat and one-off tool requests. |
| `:LumaNew` | Start a new chat session. |
| `:LumaHistory [all\|chat\|tool name]` | Open main-chat history or browse an isolated tool history. |
| `:LumaModel [name]` | Select or switch the active model. |
| `:LumaTool {name}` | Run a registered user tool; Visual ranges are supported. |

## Chat windows

The main chat coordinates four windows: Chat, Prompt, Models, and History.

- `i`, `o`, `m`, and `h` move between windows.
- `<CR>` selects a model or restores a history item.
- `d` in the main History window deletes the selected entry after confirmation.
- `<Esc>` returns to Prompt.
- `?` opens key help.
- `q` closes the complete group.

Prompt enters Insert mode by default when `ui.start_insert` is enabled. Streaming output appends to the active Assistant response and does not force the viewport to the bottom after manual scrolling.

`:LumaHistory all` first selects the main chat or a tool scope. Tool entries can be opened as read-only snapshots or deleted; opening history never reruns a tool or its side effects. Programmatic management uses `luma.history_delete(id, opts)` and `luma.history_clear(opts)` with `{ scope = "chat" }` or `{ scope = "tool", tool = "name" }`. These APIs do not prompt, and deletion is permanent.

## Context directives

Chat prompts support:

- `/buffer` to append the source buffer.
- `/buffer number` to append another listed and loaded buffer.
- `/file path` to append a file within `max_context_bytes`.
- `@web_search query` to search Tavily when configured.
- `diagnostics = true` to append source-buffer diagnostics automatically.

Unknown buffers and unreadable files produce an explicit error instead of silently dropping context.

## Completion

Prompt exposes directives, listed buffers, and file paths through its standard `completefunc`. Luma returns candidates but does not open, replace, or control an external completion menu.

Without a completion plugin, use Neovim's native user-defined completion:

```text
<C-x><C-u>
```

### blink.cmp

Add a provider backed by the current buffer's `completefunc`:

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

The provider is enabled only in buffers that define `completefunc`, so ordinary code buffers keep their normal source set.

### nvim-cmp

`nvim-cmp` does not include a source that reads an existing buffer `completefunc`. Keep native `<C-x><C-u>` available, or explicitly forward that key sequence when cmp mappings override it:

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

This opens Neovim's native completion menu for Luma candidates; other nvim-cmp sources continue to use the cmp menu.

## Tools

Run configured tools with `:LumaTool name`. A Visual range is passed to the tool when the command is invoked as:

```vim
:'<,'>LumaTool explain
```

See [Writing Luma Tools](tools.md) for tool definitions and [complete examples](../examples/tools.lua).
