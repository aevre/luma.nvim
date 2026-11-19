# Writing tools

Luma provides the tool runtime but does not register concrete tools. Put tool definitions in your Neovim configuration or a separate Lua module.

Use a declarative tool for one request with one result. Use `run(ctx)` when the workflow needs custom input, a reusable tool Chat, a guarded rewrite, or explicit actions in the result window.

## Register tools

The usual place for tools is `setup()`:

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

Run it with:

```vim
:LumaTool explain
```

A Visual range is passed to the tool:

```vim
:'<,'>LumaTool explain
```

Tools loaded later may use `require("luma.tools").register(name, spec)`. Calling `luma.setup()` again resets the registry from `opts.tools`.

## Declarative tools

A declarative tool collects input, sends one request, and opens a result window:

```lua
tests = {
  source = "selection",
  title = " Tests… ",
  system = "Write useful tests. Return only test code.",
  loading = "Generating tests",
}
```

### Input source

| Value | Input |
| --- | --- |
| omitted or `"auto"` | Visual selection when supplied, otherwise the current buffer. |
| `"selection"` | Visual selection only; missing selection is an error. |
| `"buffer"` | Whole current buffer. |
| `"prompt"` | Text entered through `vim.fn.input()`. |

`input_title` labels the input prompt. `instruction` adds text before the collected input:

```lua
review = {
  source = "selection",
  system = "Review this code for correctness and safety.",
  instruction = "Report concrete bugs before style issues.",
}
```

`system` and `instruction` may also be functions receiving `(ctx, input)`.

### Fields

| Field | Meaning |
| --- | --- |
| `system` | Required system message. |
| `source` | Input source. |
| `input_title` | Label used by `source = "prompt"`. |
| `instruction` | Text added before the collected input. |
| `title` | Result-window title. |
| `model` | Tool model override. |
| `loading` | `false`, a label string, or loading-window options. |
| `window` | Result-window options passed to win.nvim. |
| `editable` | Set `true` to allow editing the result buffer. |
| `history` | Set `false` to disable tool history. |
| `history_max` | Tool history retention override. |
| `on_done` | Called with `(result, output)`. |
| `on_error` | Called with the error string. |
| `run` | Enables a custom workflow instead of declarative processing. |

## Custom workflows

A custom tool receives a context table:

```lua
ask = {
  run = function(ctx)
    local question = vim.fn.input("Question: ")
    if question == "" then
      return
    end

    ctx.generate({
      system = "Answer clearly and concisely.",
      user = question,
    })
  end,
}
```

Function shorthand is equivalent:

```lua
ask = function(ctx)
  -- custom workflow
end
```

When `run` exists, Luma does not process the declarative `source`, `system`, or `instruction` fields automatically.

### Context

| Member | Meaning |
| --- | --- |
| `ctx.name` | Registered tool name. |
| `ctx.tool` | Registered tool definition. |
| `ctx.has_range` | Whether the command supplied a Visual range. |
| `ctx.visual()` | Return the Visual text and range. |
| `ctx.source(has_range)` | Return the Visual selection or whole buffer. |
| `ctx.generate(spec)` | Run one request and open a result window. |
| `ctx.chat(spec)` | Open an isolated Prompt/Output tool Chat. |
| `ctx.cancel()` | Cancel active one-off tool requests. |
| `ctx.loading(opts)` | Start a loading window and return its cleanup function. |
| `ctx.panel(title, keys, opts)` | Create a result panel. |
| `ctx.strip_fence(text)` | Remove one surrounding Markdown code fence. |

## One-off generation

```lua
local handle = ctx.generate({
  title = " Explanation… ",
  system = "Explain the supplied code clearly.",
  user = text,
  model = "fast-model",
  loading = "Explaining",
  on_done = function(result, output)
    output:set_title(" Explanation ")
  end,
  on_error = function(err)
    vim.notify(err, vim.log.levels.ERROR)
  end,
})
```

The returned handle provides `cancel()` and `kill()`. Both are safe to call more than once. Result buffers are read-only unless `editable = true`. Use `output:get_text()` in `on_done` actions to read the current text after user edits.

Successful registered-tool requests are saved unless history is disabled. Failed and cancelled requests are not saved. Luma rejects blank responses and removes one surrounding Markdown code fence before calling `on_done`.

### Generation fields

| Field | Required | Meaning |
| --- | --- | --- |
| `system` | yes | System message. |
| `user` | yes | User message. |
| `title` | no | Result-window title. |
| `model` | no | Per-request model override. |
| `loading` | no | Loading label or options; `false` disables it. |
| `window` | no | Result-window options. |
| `editable` | no | Set `true` to allow editing the result buffer. |
| `on_done` | no | Receives `(result, output)`. |
| `on_error` | no | Receives the error string. |
| `history` | no | Set `false` to skip history. |
| `history_max` | no | Retention override for the tool scope. |

## Tool Chat

Use `ctx.chat()` for a reusable Prompt/Output interface:

```lua
translate = {
  run = function(ctx)
    ctx.chat({
      title = "Translator",
      system = "Translate Chinese into English and other text into Chinese. Output only the translation.",
      model = "fast-model",
    })
  end,
}
```

Tool Chat is separate from the main Chat:

- It has its own model and history.
- Each request sends only the tool system message and current Prompt.
- Previous output is not sent with the next request.
- Restoring history displays a snapshot and does not rerun the tool.

| Field | Meaning |
| --- | --- |
| `system` | System message sent with every request. |
| `title` | Window title. |
| `model` | Initial model override. |
| `history` | Set `false` to disable history. |
| `history_max` | History retention override. |

Use `i` for Prompt, `m` for model selection, `h` for history, and `d` to delete a history entry.

## Guarded rewrites

Do not replace a selection after its buffer has changed. Record `changedtick` before starting the request and use the diff module:

```lua
rewrite = function(ctx)
  local text, range = ctx.visual()
  if not text then
    return
  end

  range.changedtick = vim.api.nvim_buf_get_changedtick(range.bufnr)
  ctx.generate({
    system = "Return only replacement text.",
    user = text,
    on_done = function(result, output)
      output:destroy()
      require("luma.diff").show(text, result, range)
    end,
  })
end
```

The preview checks the buffer, range, and `changedtick` before applying the replacement.

## Commands and side effects

Treat generated commands as untrusted:

1. Show the generated content first.
2. Add an explicit key or action to the result window.
3. Run the command only after that action.
4. Display command errors.

Do not execute generated shell or Git commands automatically from `on_done`.

See [`examples/tools.lua`](../examples/tools.lua) for complete Ask, Translate, Rewrite, Commit, and Bash examples.
