# Development

## Repository layout

| Path                     | Responsibility                                                        |
| ------------------------ | --------------------------------------------------------------------- |
| `lua/luma/init.lua`      | Public API, commands, setup, and runtime bootstrap.                   |
| `lua/luma/config.lua`    | Defaults, option merging, validation, and shared configuration types. |
| `lua/luma/backend.lua`   | Request bodies and OpenAI/Ollama response parsing.                    |
| `lua/luma/request.lua`   | curl process lifecycle, streaming, errors, and cancellation.          |
| `lua/luma/session.lua`   | Main Chat state and request coordination.                             |
| `lua/luma/ui.lua`        | Main windows, navigation, rendering, and source-window restoration.   |
| `lua/luma/history.lua`   | Saved Chat and tool history.                                          |
| `lua/luma/tools.lua`     | Tool registry and one-off generation.                                 |
| `lua/luma/tool_chat.lua` | Isolated tool Chat sessions.                                          |
| `lua/luma/context.lua`   | Buffer, file, diagnostics, and completion context.                    |
| `lua/luma/diff.lua`      | Guarded selection replacement.                                        |
| `lua/luma/web.lua`       | Tavily integration.                                                   |
| `tests/smoke.lua`        | Headless regression tests.                                            |

## LuaLS annotations

Define shared types in the module that owns the data:

- configuration and messages in `config.lua`
- request callbacks and handles in `request.lua`
- selection ranges in `context.lua`
- tool specs and context in `tools.lua`
- history entries in `history.lua`

Reuse those types in other modules. Keep nilability and callback signatures consistent with runtime behavior.

A provider request handle exposes `kill()`. The public handle returned by `ctx.generate()` exposes both `cancel()` and `kill()`.

### Local LuaLS configuration

`.luarc.json.example` is the shared starting point for editor configuration. Copy it to `.luarc.json` in the repository root:

```sh
cp .luarc.json.example .luarc.json
```

Edit `workspace.library` in the copied file when `win.nvim`, `animate.nvim`, Neovim runtime files, or LuaJIT libraries are stored in different locations. For example:

```json
"${workspaceFolder}/../win.nvim/lua",
"${workspaceFolder}/../animate.nvim/lua"
```

Keep `.luarc.json` local. It is ignored by Git and must not be committed. `make lint` creates a temporary LuaLS configuration from `.luarc.json.example` and injects `WIN_NVIM` and `ANIMATE_NVIM`; expanded machine paths are never written to a tracked file. Use `make check` for the complete project check.

## Comments

Use English comments for behavior that is difficult to infer from the code, such as:

- path and credential boundaries
- parser buffering
- cancellation and stale callbacks
- window cleanup and option restoration
- guarded replacement checks

Do not comment ordinary assignments or restate function names.

## Safety rules

- Do not log API keys, authorization headers, full prompts, or generated content.
- Do not run generated shell or Git commands without an explicit user action.
- Check buffer identity, range bounds, and `changedtick` before replacing text.
- Treat timer, process, and window cleanup as idempotent.
- Keep tool Chat state separate from the main Chat.

## Documentation

English and Chinese pages should keep the same section order and examples. Update both when a public command, option, API, or tool field changes.

Keep user instructions in `docs/`. Contributor and agent constraints belong in `AGENTS.md`.

## Verification

Run from the repository root:

```sh
make check
make test
git diff --check
```

`make check` runs Stylua, Selene, LuaLS, and the headless smoke suite. Set local dependency paths when needed:

```sh
make check WIN_NVIM=/path/to/win.nvim ANIMATE_NVIM=/path/to/animate.nvim
```

Headless tests do not verify terminal geometry, animation, picker usability, or live provider behavior. Inspect changed UI surfaces manually and use harmless commands when testing side-effect examples.
