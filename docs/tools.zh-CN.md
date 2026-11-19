# 编写 Luma 工具

Luma 核心提供工具运行机制，但不会注册具体工具。工具应定义在 Neovim 配置中，通过 `require("luma").setup({ tools = ... })` 或 `require("luma.tools").register(name, spec)` 注册。

如果需求只是“收集文本、发送一次请求、显示结果”，优先使用声明式工具。需要自定义输入、独立 Chat、受保护改写、外部命令或结果窗口操作时，再使用 run。

## 注册工具

建议将需要长期存在的工具放入 `opts.tools`：

```lua
require("luma").setup({
  tools = {
    explain = {
      system = "清晰解释提供的代码。",
    },
  },
})
```

运行工具：

```vim
:LumaTool explain
```

带 Visual 范围执行命令时，`ctx.has_range = true`，声明式工具会使用精确选区：

```vim
:'<,'>LumaTool explain
```

需要在 setup 之后加载独立模块时，也可以直接注册：

```lua
require("luma.tools").register("explain", {
  system = "清晰解释提供的代码。",
})
```

再次调用 `require("luma").setup()` 会根据 `opts.tools` 重置注册表。持久工具应放在 `opts.tools`，或在最后一次 setup 之后注册。

## 声明式工具

声明式工具是包含 `system` 且没有 `run` 的表。Luma 会负责收集输入、构造请求、显示 loading，并打开结果窗口。

```lua
local tools = {
  tests = {
    source = "selection",
    title = " Tests… ",
    system = "编写有用的测试，只返回测试代码。",
    loading = "Generating tests",
  },
}
```

发送给模型的请求严格包含两条消息：

1. 来自 `system` 的 system message。
2. user message：可选的 `instruction` 加上收集到的输入。

### 输入来源

`source` 决定声明式工具从哪里取得文本：

| 值 | 行为 |
| --- | --- |
| 省略或 `"auto"` | 命令带 Visual 范围时使用精确选区，否则使用当前整个 buffer。 |
| `"selection"` | 强制要求 Visual 范围；没有范围时显示错误并停止。 |
| `"buffer"` | 始终使用当前整个 buffer，即使命令带 Visual 范围。 |
| `"prompt"` | 调用 `vim.fn.input()`，使用用户输入的文本。 |

`input_title` 只用于设置 `source = "prompt"` 时 `vim.fn.input()` 的标题。

`instruction` 字段含义不同：它会被添加到模型 user message 中，位于收集内容之前；它不会打开输入框。

```lua
review = {
  source = "selection",
  system = "检查代码的正确性和安全性。",
  instruction = "优先报告具体 bug，不要关注纯样式问题。",
}
```

最终 user message 为：

```text
优先报告具体 bug，不要关注纯样式问题。

<选中的文本>
```

`system` 和 `instruction` 都可以是接收 `(ctx, input)` 的函数：

```lua
explain = {
  system = function(ctx, input)
    return ("清晰解释这段%s内容。"):format(ctx.has_range and "选中" or "buffer")
  end,
  instruction = function(_, input)
    return ("输入包含 %d 字节。"):format(#input)
  end,
}
```

### 声明式字段表

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `system` | `string \| fun(ctx, input): string` | 声明式模式必填，作为模型 system message。 |
| `source` | `"auto" \| "selection" \| "buffer" \| "prompt"` | 选择输入来源；省略等于 `"auto"`，其他值会报错。 |
| `input_title` | `string` | `source = "prompt"` 时 `vim.fn.input()` 的标题。 |
| `instruction` | `string \| fun(ctx, input): string` | 可选指令，添加到收集内容之前，组成 user message。 |
| `title` | `string` | 结果窗口标题；默认根据工具名称生成。 |
| `model` | `string` | 工具级模型覆盖。 |
| `loading` | `false \| string \| table` | 禁用或配置光标旁 loading spinner；字符串用于设置文字。 |
| `window` | `table` | 覆盖生成结果窗口的 `win.nvim` 选项。 |
| `on_done` | `fun(result, output)` | 结果窗口写入内容后调用。 |
| `on_error` | `fun(error)` | provider 请求失败时调用；不会创建结果窗口。 |
| `run` | `fun(ctx)` | 切换为 run 模式；跳过声明式输入和请求流程。 |

模型优先级为：

1. 单次请求的 `ctx.generate({ model = "name" })`。
2. 工具顶层 `model`。
3. Luma 全局模型。

## Run 工具

Run 接收 context 表，并自行控制整个流程。函数简写和显式 `run` 字段等价：

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

只要存在 `run`，Luma 就不会自动处理声明式的 `source`、`system` 或 `prompt`。但 run 通过 `ctx.generate()` 和 `ctx.chat()` 时，仍会继承工具顶层 `model`。

### Run context

| 成员 | 含义 |
| --- | --- |
| `ctx.name` | 注册的工具名称。 |
| `ctx.tool` | 原始注册工具表。 |
| `ctx.has_range` | 使用 Visual 范围调用工具时为 `true`。 |
| `ctx.visual()` | 返回 `text, range`；失败时显示错误并返回 `nil`。 |
| `ctx.source(has_range)` | `has_range` 为 true 时返回 Visual 选区，否则返回当前整个 buffer；同时返回 range/source 表。 |
| `ctx.generate(spec)` | 启动一次性请求，成功后打开生成结果窗口。 |
| `ctx.chat(spec)` | 打开与主 Chat 隔离的双窗口工具 Chat。 |
| `ctx.cancel()` | 取消所有进行中的一次性工具请求。 |
| `ctx.loading(opts)` | 启动独立 loading spinner，并返回清理函数。 |
| `ctx.panel(title, keys, opts)` | 创建带 Luma 主题的生成结果窗口。 |
| `ctx.strip_fence(text)` | 移除一层完整包裹结果的 Markdown code fence。 |

`ctx.visual()` 返回的 range 包含 `bufnr`、`start_line`、`start_col`、`end_line` 和 `end_col`。异步改写前应记录来源 buffer 的当前 `changedtick`；Luma diff 模块会用它拒绝过期替换。

## 一次性生成

一个请求只需要产生一个结果窗口时，使用 `ctx.generate()`：

```lua
local handle = ctx.generate({
  title = " Explanation… ",
  system = "清晰解释提供的代码。",
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

### `ctx.generate()` 字段

| 字段 | 是否必填 | 含义 |
| --- | --- | --- |
| `system` | 是 | 请求的 system message。 |
| `user` | 是 | 请求的 user message。 |
| `title` | 否 | 结果窗口标题；默认为 `" Luma… "`。 |
| `model` | 否 | 单次请求模型覆盖。 |
| `loading` | 否 | `false` 禁用；字符串设置文字；表用于完整配置。 |
| `window` | 否 | 与自动尺寸合并的 `win.nvim` 结果窗口选项。 |
| `on_done` | 否 | 结果窗口创建并写入后接收 `(result, output)`。 |
| `on_error` | 否 | 接收错误字符串；失败时不会创建结果窗口。 |
| `history` | 否 | 设为 `false` 时，不把本次成功结果保存到该工具的独立历史。 |
| `history_max` | 否 | 覆盖该工具历史的保留数量。 |

`loading` 为表时支持 `text`、`frames`、`interval`、`row`、`col`、`zindex`、`hl` 和 `blend`。`text = false` 会隐藏文字，只保留动画帧。

返回 handle 提供幂等的 `cancel()` 和 `kill()`；`kill()` 是兼容别名。生成期间，Luma 会临时在来源 buffer 绑定配置中的取消键，但不会覆盖已有 buffer-local 映射。始终可以使用 `:LumaCancel` 或 `ctx.cancel()`。

Luma 会收集流式内容、拒绝空白响应、移除一层外部 Markdown fence；通过注册工具调用时，除非关闭历史，否则会保存成功结果，然后计算结果窗口尺寸、写入结果并调用 `on_done`。失败和取消的请求不会保存。回调可通过 `output` 添加结果窗口操作。

```lua
ctx.generate({
  system = "只返回 shell 命令，不要执行。",
  user = task,
  on_done = function(command, output)
    output:set_title(" Review command · y copy ")
    vim.keymap.set("n", "y", function()
      vim.fn.setreg("+", command)
    end, { buffer = output.buf, desc = "Copy generated command" })
  end,
})
```

## 独立工具 Chat

翻译器等可重复提交的 Prompt/Output UI 使用 `ctx.chat()`：

```lua
translator = {
  run = function(ctx)
    ctx.chat({
      title = "Translator",
      system = "中文翻译成英文，其他内容翻译成中文，只输出译文。",
      model = "fast-model",
      history = true,
    })
  end,
}
```

`ctx.chat()` 与主 Luma 会话隔离：

- 模型选择和历史存储独立。
- 切换工具模型不会改变主 Chat 模型。
- 每次提交只发送工具 system prompt 和当前 Prompt 输入。
- 之前的工具输出可显示、可保存以供查看，但不会发送给下一次请求。
- Prompt 是唯一带 footer 的窗口；Output 只显示生成内容。

### `ctx.chat()` 字段

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `title` | `string` | 工具窗口标题；默认使用注册名称。 |
| `system` | `string` | 每次提交都会发送的 system message。 |
| `model` | `string` | 初始模型；默认依次使用工具模型和全局模型。 |
| `history` | `boolean` | 控制独立持久化历史；只有显式设为 `false` 才会关闭。 |
| `history_max` | `number` | 覆盖该工具历史的保留数量。 |

使用 `i` 聚焦 Prompt、`m` 选择模型、`h` 查看工具历史、`d` 删除选中的历史，并通过配置的 submit 键提交。恢复工具记录只显示保存的输入和输出，不会重新提交请求。

## 受保护改写

请求进行期间来源内容可能已经变化，生成文本不能直接静默覆盖：

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
    system = "只返回替换文本。",
    user = text,
    on_done = function(result, output)
      output:destroy()
      require("luma.diff").show(text, result, range)
    end,
  })
end
```

Diff 预览会在应用替换前检查 buffer 身份、范围边界和 `changedtick`。

## 副作用和生成命令

模型输出必须视为不可信内容。生成 shell 命令、Git 操作或其他副作用的工具应该：

1. 先生成并展示内容。
2. 在结果窗口添加明确操作键。
3. 只有用户按下该键后才执行。
4. 显示命令错误，不能静默丢弃。

不要在 `on_done` 中自动执行生成内容。[`examples/tools.lua`](../examples/tools.lua) 中的 Commit 和 Bash 示例分别要求在结果窗口按 `c` 或 `r`。

## 注册表 API

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

`tools.setup()` 会取消进行中的一次性工具请求、清空注册表，并注册传入表中所有不为 `false` 的定义。

## 完整示例

[`examples/tools.lua`](../examples/tools.lua) 提供以下可复制示例：

- 输入问题并生成一次性回答。
- 解释 buffer 或选区。
- 将选区附加到主 Chat。
- 独立翻译 Chat。
- 翻译光标词或选区。
- 强制选区的测试生成。
- 受保护改写。
- 根据 staged diff 生成 commit message，并通过明确键位提交或复制。
- 生成 Bash 脚本，并通过明确键位运行或复制。
