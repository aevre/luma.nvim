# Using Luma

## Commands

| Command                               | Action                                              |
| ------------------------------------- | --------------------------------------------------- |
| `:LumaToggle`                         | Show or hide the main UI.                           |
| `:LumaSubmit [prompt]`                | Submit the argument or the current Prompt buffer.   |
| `:LumaCancel`                         | Cancel active chat and one-off tool requests.       |
| `:LumaNew`                            | Start a new chat.                                   |
| `:LumaHistory [all\|chat\|tool name]` | Browse saved chat or tool history.                  |
| `:LumaModel [name]`                   | Select a model.                                     |
| `:LumaTool {name}`                    | Run a registered tool. Visual ranges are supported. |

## Main windows

The floating UI contains four windows:

- **Chat** shows the conversation.
- **Prompt** accepts input.
- **Models** switches the active model.
- **History** restores or deletes saved chats.

Use `i`, `o`, `m`, and `h` to move between them. Press `<CR>` to select an item, `<Esc>` to return to Prompt, `?` for key help, and `q` to close the group.

Prompt starts in Insert mode when `ui.start_insert` is enabled. Streaming follows the output only while the cursor is already at the bottom, so manual scrolling is not interrupted.

## Context

Add context directives anywhere in a prompt:

| Directive           | Result                                   |
| ------------------- | ---------------------------------------- |
| `/buffer`           | Append the source buffer.                |
| `/buffer number`    | Append another listed and loaded buffer. |
| `/file path`        | Append a file.                           |
| `@web_search query` | Search Tavily and append the result.     |

File and buffer content share the `max_context_bytes` limit. Unknown buffers and unreadable files return an error.

Set `diagnostics = true` to append diagnostics from the source buffer to every main-chat submission.

## History

Main chat and each tool have separate history scopes.

- Use `<CR>` in History to restore a chat.
- Use `d` to delete the selected chat after confirmation.
- Run `:LumaHistory all` to choose between main-chat and tool history.
- Opening tool history shows a saved snapshot. It does not run the tool again.

History deletion is permanent. The Lua API also provides non-interactive delete and clear functions; see [Lua API](api.md#history).

## Completion

Prompt exposes directives, loaded buffers, and file paths through Neovim's `completefunc`.

Without a completion plugin, press:

```text
<C-x><C-u>
```

### blink.cmp

Use blink.cmp's `complete_func` source:

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

### nvim-cmp

nvim-cmp does not read a buffer's `completefunc` by default. Keep native `<C-x><C-u>` available, or forward it from a cmp mapping:

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

## Tools

Run a configured tool with:

```vim
:LumaTool explain
```

To pass a Visual selection:

```vim
:'<,'>LumaTool explain
```

See [Writing tools](tools.md) for tool definitions and [complete examples](../examples/tools.lua).
