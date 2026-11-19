# 编写工具

Luma 提供工具运行环境，但默认不注册具体工具。工具可以放在 Neovim 配置中，也可以拆到单独的 Lua 模块。

一次请求并显示一个结果时，优先使用声明式工具。需要自定义输入、独立工具 Chat、安全改写或结果窗口操作时，使用 `run(ctx)`。

## 注册工具

通常在 `setup()` 中注册：

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

运行：

```vim
:LumaTool explain
```

Visual 范围会传给工具：

```vim
:'<,'>LumaTool explain
```

后加载的工具可以使用 `require("luma.tools").register(name, spec)`。再次调用 `luma.setup()` 会根据 `opts.tools` 重置注册表。

## 声明式工具

声明式工具会收集输入、发送一次请求并打开结果窗口：

```lua
tests = {
  source = "selection",
  title = " Tests… ",
  system = "Write useful tests. Return only test code.",
  loading = "Generating tests",
}
```

### 输入来源

| 值 | 输入 |
| --- | --- |
| 省略或 `"auto"` | 有 Visual 范围时使用选择，否则使用当前 Buffer。 |
| `"selection"` | 只接受 Visual 选择；没有选择时返回错误。 |
| `"buffer"` | 使用整个当前 Buffer。 |
| `"prompt"` | 使用 `vim.fn.input()` 输入的内容。 |

`input_title` 设置输入框标题。`instruction` 会加在收集到的输入之前：

```lua
review = {
  source = "selection",
  system = "Review this code for correctness and safety.",
  instruction = "Report concrete bugs before style issues.",
}
```

`system` 和 `instruction` 也可以是接收 `(ctx, input)` 的函数。

### 字段

| 字段 | 作用 |
| --- | --- |
| `system` | 必填的 system message。 |
| `source` | 输入来源。 |
| `input_title` | `source = "prompt"` 使用的标题。 |
| `instruction` | 加在输入前的说明。 |
| `title` | 结果窗口标题。 |
| `model` | 工具模型覆盖。 |
| `loading` | `false`、标签字符串或 Loading 窗口选项。 |
| `window` | 传给 win.nvim 的结果窗口选项。 |
| `history` | 设置为 `false` 时不保存工具历史。 |
| `history_max` | 工具历史保留数量。 |
| `on_done` | 接收 `(result, output)`。 |
| `on_error` | 接收错误字符串。 |
| `run` | 使用自定义流程，不执行声明式处理。 |

## 自定义流程

自定义工具接收一个 context：

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

也可以直接使用函数：

```lua
ask = function(ctx)
  -- custom workflow
end
```

存在 `run` 时，Luma 不会自动处理声明式的 `source`、`system` 或 `instruction`。

### Context

| 成员 | 作用 |
| --- | --- |
| `ctx.name` | 注册名称。 |
| `ctx.tool` | 注册时的工具定义。 |
| `ctx.has_range` | 命令是否带有 Visual 范围。 |
| `ctx.visual()` | 返回选择文本和范围。 |
| `ctx.source(has_range)` | 返回 Visual 选择或整个 Buffer。 |
| `ctx.generate(spec)` | 运行一次请求并打开结果窗口。 |
| `ctx.chat(spec)` | 打开独立的 Prompt/Output 工具 Chat。 |
| `ctx.cancel()` | 取消正在运行的一次性工具请求。 |
| `ctx.loading(opts)` | 打开 Loading 窗口并返回清理函数。 |
| `ctx.panel(title, keys, opts)` | 创建结果面板。 |
| `ctx.strip_fence(text)` | 去掉一层 Markdown 代码围栏。 |

## 一次性生成

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

返回的 handle 提供 `cancel()` 和 `kill()`，重复调用也不会产生额外影响。

注册工具中的成功请求默认保存历史。失败和取消的请求不保存。Luma 会拒绝空结果，并在调用 `on_done` 前去掉一层 Markdown 代码围栏。

### 生成字段

| 字段 | 必填 | 作用 |
| --- | --- | --- |
| `system` | 是 | System message。 |
| `user` | 是 | User message。 |
| `title` | 否 | 结果窗口标题。 |
| `model` | 否 | 单次请求的模型覆盖。 |
| `loading` | 否 | Loading 标签或选项；`false` 表示关闭。 |
| `window` | 否 | 结果窗口选项。 |
| `on_done` | 否 | 接收 `(result, output)`。 |
| `on_error` | 否 | 接收错误字符串。 |
| `history` | 否 | 设置为 `false` 时不保存历史。 |
| `history_max` | 否 | 该工具作用域的保留数量。 |

## 工具 Chat

需要可重复输入的 Prompt/Output 界面时使用 `ctx.chat()`：

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

工具 Chat 与主 Chat 分离：

- 使用独立的模型和历史记录。
- 每次请求只发送工具 system message 和当前 Prompt。
- 上一次输出不会发送给下一次请求。
- 恢复历史只显示快照，不会重新运行工具。

| 字段 | 作用 |
| --- | --- |
| `system` | 每次请求发送的 system message。 |
| `title` | 窗口标题。 |
| `model` | 初始模型覆盖。 |
| `history` | 设置为 `false` 时不保存历史。 |
| `history_max` | 历史保留数量。 |

使用 `i` 进入 Prompt，`m` 选择模型，`h` 选择历史，`d` 删除历史记录。

## 安全改写

Buffer 在请求期间发生变化后，不应直接覆盖原选择。请求前记录 `changedtick`，并使用 diff 模块：

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

预览会检查 Buffer、范围和 `changedtick`，通过后才允许替换。

## 命令和副作用

生成的命令应视为不可信内容：

1. 先显示生成结果。
2. 在结果窗口中添加明确操作。
3. 只有用户执行该操作后才运行命令。
4. 显示命令错误。

不要在 `on_done` 中自动执行生成的 Shell 或 Git 命令。

完整的 Ask、Translate、Rewrite、Commit 和 Bash 示例见 [`examples/tools.lua`](../examples/tools.lua)。
