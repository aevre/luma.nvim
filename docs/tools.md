# Writing Luma Tools

Luma core provides the tool runtime but does not register concrete tools. A tool belongs in your Neovim configuration and is registered through `require("luma").setup({ tools = ... })` or `require("luma.tools").register(name, spec)`.

Start with a declarative tool when the job is "collect text, send one request, show the result." Use a run when you need custom input, an independent chat, a guarded rewrite, external commands, or custom result-window actions.

## Registering tools

The recommended setup keeps persistent tools under `opts.tools`:

```lua
require("luma").setup({
  tools = {
    explain = {
      system = "Explain the supplied code clearly.",
    },
  },
})
```

Run it with:

```vim
:LumaTool explain
```

A command with a Visual range sets `ctx.has_range = true` and lets declarative tools use the exact selection:

```vim
:'<,'>LumaTool explain
```

Direct registration is useful for modules loaded after setup:

```lua
require("luma.tools").register("explain", {
  system = "Explain the supplied code clearly.",
})
```

Calling `require("luma").setup()` again resets the registry from `opts.tools`. Keep persistent definitions in `opts.tools`, or register them after the final setup call.

## Declarative tools

A declarative tool is a table with a `system` field and no `run`. Luma collects input, builds the request, displays loading state, and opens a result window.

```lua
local tools = {
  tests = {
    source = "selection",
    title = " Tests… ",
    system = "Write useful tests. Return only test code.",
    loading = "Generating tests",
  },
}
```

The request sent to the model contains exactly two messages:

1. A system message from `system`.
2. A user message containing `instruction`, when configured, followed by the collected input.

### Input selection

`source` controls where a declarative tool gets its text:

| Value | Behavior |
| --- | --- |
| omitted or `"auto"` | Use the exact Visual selection when the command has a range; otherwise use the whole current buffer. |
| `"selection"` | Require a Visual range. The tool stops with an error when no range was supplied. |
| `"buffer"` | Always use the whole current buffer, even when a range was supplied. |
| `"prompt"` | Open `vim.fn.input()` and use the entered text. |

`input_title` only labels the `vim.fn.input()` prompt used by `source = "prompt"`.

The `instruction` field is different: it adds text before the collected input in the model's user message. It does not open an input UI.

```lua
review = {
  source = "selection",
  system = "Review code for correctness and safety.",
  instruction = "Prioritize concrete bugs over style comments.",
}
```

The resulting user message is:

```text
Prioritize concrete bugs over style comments.

<selected text>
```

Both `system` and `instruction` may be functions receiving `(ctx, input)`:

```lua
explain = {
  system = function(ctx, input)
    return ("Explain this %s input clearly."):format(ctx.has_range and "selected" or "buffer")
  end,
  instruction = function(_, input)
    return ("The input contains %d bytes."):format(#input)
  end,
}
```

### Declarative field reference

| Field | Type | Meaning |
| --- | --- | --- |
| `system` | `string \| fun(ctx, input): string` | Required in declarative mode. Becomes the model's system message. |
| `source` | `"auto" \| "selection" \| "buffer" \| "prompt"` | Selects the input source. Omitted means `"auto"`; any other value is an error. |
| `input_title` | `string` | Label for `vim.fn.input()` when `source = "prompt"`. |
| `instruction` | `string \| fun(ctx, input): string` | Optional instruction prepended to the collected input in the user message. |
| `title` | `string` | Result-window title. The default is derived from the tool name. |
| `model` | `string` | Tool-level model override. |
| `loading` | `false \| string \| table` | Disables or configures the cursor-adjacent loading spinner. A string sets its text. |
| `window` | `table` | Overrides the generated result window's `win.nvim` options. |
| `on_done` | `fun(result, output)` | Runs after the result window is populated. |
| `on_error` | `fun(error)` | Runs when the provider request fails. No result window is created. |
| `run` | `fun(ctx)` | Switches the tool to run mode; declarative input/request processing is skipped. |

Model precedence is:

1. `ctx.generate({ model = "name" })` for one request.
2. The tool's top-level `model`.
3. The global Luma model.

## Run tools

A run receives a context table and owns the workflow. Function shorthand and an explicit `run` field are equivalent:

```lua
local tools = {
  first = function(ctx)
    -- run
  end,
  second = {
    model = "fast-model",
    run = function(ctx)
      -- run
    end,
  },
}
```

When `run` exists, Luma does not automatically process declarative `source`, `system`, or `instruction` fields. The run may still use the top-level `model` through `ctx.generate()` and `ctx.chat()`.

### Run context

| Member | Meaning |
| --- | --- |
| `ctx.name` | Registered tool name. |
| `ctx.tool` | The original registered tool table. |
| `ctx.has_range` | `true` when the tool command was invoked with a Visual range. |
| `ctx.visual()` | Returns `text, range`, or `nil` after displaying an error. |
| `ctx.source(has_range)` | Returns the Visual selection when `has_range` is true; otherwise returns the whole current buffer. Also returns a range/source table. |
| `ctx.generate(spec)` | Starts a one-off request and opens a generated-result window on success. |
| `ctx.chat(spec)` | Opens an isolated two-window tool chat. |
| `ctx.cancel()` | Cancels all active one-off tool requests. |
| `ctx.loading(opts)` | Starts a standalone loading spinner and returns a cleanup function. |
| `ctx.panel(title, keys, opts)` | Creates a themed generated-result panel. |
| `ctx.strip_fence(text)` | Removes one surrounding Markdown code fence when present. |

The range returned by `ctx.visual()` contains `bufnr`, `start_line`, `start_col`, `end_line`, and `end_col`. Before an asynchronous rewrite, record the source buffer's current `changedtick`; Luma's diff module uses it to reject stale replacements.

## One-off generation

Use `ctx.generate()` when one request should produce one result window:

```lua
local handle = ctx.generate({
  title = " Explanation… ",
  system = "Explain the supplied code clearly.",
  user = text,
  model = "fast-model",
  loading = { text = "Explaining" },
  window = {
    ft = "markdown",
    width = 0.7,
    height = 0.7,
  },
  on_done = function(result, output)
    output:set_title(" Explanation ")
  end,
  on_error = function(err)
    vim.notify("explain failed: " .. err, vim.log.levels.ERROR)
  end,
})
```

### `ctx.generate()` fields

| Field | Required | Meaning |
| --- | --- | --- |
| `system` | yes | System message for the request. |
| `user` | yes | User message for the request. |
| `title` | no | Result-window title. Defaults to `" Luma… "`. |
| `model` | no | Per-request model override. |
| `loading` | no | `false` disables loading; a string sets its label; a table configures it. |
| `window` | no | `win.nvim` options merged into the automatically sized result panel. |
| `on_done` | no | Receives `(result, output)` after the result window is created and filled. |
| `on_error` | no | Receives the error string. No result window is created. |

When `loading` is a table, it accepts `text`, `frames`, `interval`, `row`, `col`, `zindex`, `hl`, and `blend`. `text = false` hides the label and leaves only the animated frame.

The returned handle has idempotent `cancel()` and `kill()` methods. `kill()` is a compatibility alias. During generation, Luma temporarily maps the configured cancel key in the source buffer unless that buffer already has a local mapping. `:LumaCancel` and `ctx.cancel()` are always available.

Luma collects streamed chunks, rejects blank provider responses, strips one surrounding Markdown fence, sizes the result panel, writes the result, and then calls `on_done`. The callback may add buffer-local actions through the returned `output` window.

```lua
ctx.generate({
  system = "Return only a shell command. Do not execute it.",
  user = task,
  on_done = function(command, output)
    output:set_title(" Review command · y copy ")
    vim.keymap.set("n", "y", function()
      vim.fn.setreg("+", command)
    end, { buffer = output.buf, desc = "Copy generated command" })
  end,
})
```

## Independent tool chats

Use `ctx.chat()` for a reusable prompt/output UI such as a translator:

```lua
translator = {
  run = function(ctx)
    ctx.chat({
      title = "Translator",
      system = "Translate Chinese into English and other text into Chinese. Output only the translation.",
      model = "fast-model",
      history = true,
    })
  end,
}
```

`ctx.chat()` is isolated from the main Luma session:

- It has independent model selection and history storage.
- Switching its model does not change the main chat model.
- Each submission sends only the tool system prompt and current Prompt input.
- Previous tool output is displayed and may be saved for viewing, but is not sent with the next request.
- Prompt owns the footer; Output contains only generated content.

### `ctx.chat()` fields

| Field | Type | Meaning |
| --- | --- | --- |
| `title` | `string` | Tool window title. Defaults to the registered tool name. |
| `system` | `string` | System message sent with every submission. |
| `model` | `string` | Initial model; defaults to the tool model, then the global model. |
| `history` | `boolean` | Controls independent persisted history. It is enabled unless explicitly set to `false`. |

Use `i` to focus Prompt, `m` to choose a model, `h` to choose tool history, and the configured submit key to send input.

## Guarded rewrites

Generated text must not silently replace content that changed while the request was running:

```lua
rewrite = function(ctx)
  if not ctx.has_range then
    vim.notify("luma: rewrite requires a visual selection", vim.log.levels.ERROR)
    return
  end

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

The diff preview validates buffer identity, range bounds, and `changedtick` before applying a replacement.

## Side effects and generated commands

Treat model output as untrusted. A tool that generates shell commands, Git operations, or other side effects should:

1. Generate and display the content first.
2. Add an explicit result-window action.
3. Execute only after that user action.
4. Show command errors instead of discarding them.

Do not execute generated content automatically from `on_done`. See [`examples/tools.lua`](../examples/tools.lua) for Commit and Bash examples that require `c` or `r` in the result window.

## Registry API

```lua
local tools = require("luma.tools")

tools.register(name, spec)
tools.unregister(name)
tools.get(name)
tools.names()
tools.run(name, has_range?)
tools.setup(definitions?)
tools.cancel()
```

`tools.setup()` cancels active one-off tool requests, clears the registry, and registers every non-`false` definition in the supplied table.

## Complete examples

[`examples/tools.lua`](../examples/tools.lua) contains copyable examples for:

- Prompt-based questions.
- Buffer or selection explanation.
- Attaching a selection to the main chat.
- Independent translation chat.
- Word or selection translation.
- Selection-only test generation.
- Guarded rewrites.
- Staged-diff commit messages with explicit commit/copy actions.
- Bash generation with explicit run/copy actions.
