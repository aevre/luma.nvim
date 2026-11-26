# Lua API

## Main module

```lua
local luma = require("luma")
```

### `setup(opts?)`

Apply configuration, reset the tool registry from `opts.tools`, destroy existing UI objects, and start a fresh in-memory session.

```lua
luma.setup({
  model = "openrouter",
  models = { ... },
})
```

Returns the `luma` module.

### Chat controls

```lua
luma.toggle()
luma.submit(text?)
luma.cancel()
luma.new()
luma.resend()
```

- `toggle()` shows or hides the main UI.
- `submit()` sends the supplied text or current Prompt content.
- `cancel()` cancels the main request and active one-off tool requests.
- `new()` starts a fresh main-chat session.
- `resend()` removes the latest assistant reply and sends the latest user message again.

### Models

```lua
luma.model(name?)
```

Passing a configured name switches directly. Omitting the name opens a selector. A successful switch reports the selected model. Tools without an explicit `model` use the current main-chat model.

### Tools

```lua
luma.tool(name, has_range?)
```

Runs a registered tool. `has_range` tells the tool whether to read the current Visual selection.

## History

History options use one of these scopes:

```lua
{ scope = "chat" }
{ scope = "tool", tool = "translate" }
{ scope = "all" }
```

`scope = "all"` is only used by the interactive browser.

### Browse history

```lua
luma.history()
luma.history({ scope = "tool", tool = "translate" })
luma.history({ scope = "all" })
```

This opens selectors and may prompt before deletion.

### Delete one entry

```lua
local ok, err = luma.history_delete(id, {
  scope = "tool",
  tool = "translate",
})
```

This function does not prompt. It accepts named scopes only and ignores arbitrary path fields.

Deleting the current main-chat record also resets the in-memory session so the deleted file is not recreated by the next save.

### Clear a scope

```lua
local result, err = luma.history_clear({ scope = "chat" })
```

The result contains the number of deleted files and any individual failures:

```lua
{
  deleted = 12,
  failed = {
    { id = "...", error = "..." },
  },
}
```

This function does not prompt.

## Tool registry

```lua
local tools = require("luma.tools")
```

### Register

```lua
tools.register(name, spec)
tools.unregister(name)
```

`spec` may be a declarative table, a table with `run(ctx)`, or a function receiving `ctx`.

### Inspect

```lua
local spec = tools.get(name)
local names = tools.names()
```

### Run and cancel

```lua
tools.run(name, has_range?)
tools.cancel()
```

`cancel()` cancels all active one-off tool requests and returns whether any request was cancelled.

### Replace the registry

```lua
tools.setup(definitions?)
```

This cancels active one-off requests, clears the registry, and registers each non-`false` definition.

## Tool context

A custom tool's `ctx` provides:

```lua
ctx.name
ctx.tool
ctx.has_range
ctx.visual()
ctx.source(has_range?)
ctx.generate(spec)
ctx.chat(spec)
ctx.cancel()
ctx.loading(opts?)
ctx.panel(title, keys?, opts?)
ctx.strip_fence(text)
```

See [Writing tools](tools.md) for examples and field references.
