# 使用 Luma

## 命令

| 命令                                  | 作用                               |
| ------------------------------------- | ---------------------------------- |
| `:LumaToggle`                         | 显示或隐藏主界面。                 |
| `:LumaSubmit [prompt]`                | 提交参数或当前 Prompt 内容。       |
| `:LumaCancel`                         | 取消当前 Chat 和一次性工具请求。   |
| `:LumaNew`                            | 新建 Chat。                        |
| `:LumaHistory [all\|chat\|tool name]` | 浏览 Chat 或工具历史。             |
| `:LumaModel [name]`                   | 选择模型。                         |
| `:LumaTool {name}`                    | 运行已注册工具，支持 Visual 范围。 |

## 主窗口

浮动界面包含四个窗口：

- **Chat** 显示对话。
- **Prompt** 输入内容。
- **Models** 切换当前模型。
- **History** 恢复或删除 Chat 历史。

使用 `i`、`o`、`m` 和 `h` 在窗口间移动。按 `<CR>` 选择条目，`<Esc>` 返回 Prompt，`?` 查看键位，`q` 关闭整组窗口。

启用 `ui.start_insert` 时，Prompt 打开后会进入 Insert 模式。只有光标已经位于底部时，流式输出才会自动跟随，因此手动向上滚动后不会被拉回底部。

## 上下文

可以在 Prompt 任意位置加入上下文指令：

| 指令                | 作用                                |
| ------------------- | ----------------------------------- |
| `/buffer`           | 加入来源 Buffer。                   |
| `/buffer number`    | 加入另一个已列出且已加载的 Buffer。 |
| `/file path`        | 加入文件内容。                      |
| `@web_search query` | 使用 Tavily 搜索并加入结果。        |

文件和 Buffer 内容共用 `max_context_bytes` 限制。找不到 Buffer 或无法读取文件时会返回错误。

设置 `diagnostics = true` 后，主 Chat 每次提交都会附带来源 Buffer 的诊断信息。

## 历史记录

主 Chat 和每个工具使用独立的历史作用域。

- 在 History 中按 `<CR>` 恢复 Chat。
- 按 `d` 并确认后删除所选 Chat。
- 使用 `:LumaHistory all` 选择主 Chat 或工具历史。
- 打开工具历史只显示保存的快照，不会重新运行工具。

历史删除后不可恢复。Lua API 还提供不弹确认的删除和清空函数，见 [Lua API](api.zh-CN.md#历史记录)。

## 补全

Prompt 通过 Neovim 的 `completefunc` 提供指令、已加载 Buffer 和文件路径补全。

不使用补全插件时，按：

```text
<C-x><C-u>
```

### blink.cmp

使用 blink.cmp 的 `complete_func` source：

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

nvim-cmp 默认不会读取 Buffer 的 `completefunc`。保留原生 `<C-x><C-u>`，或者在 cmp 映射中转发该按键：

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

## 工具

运行已配置工具：

```vim
:LumaTool explain
```

传入 Visual 选择：

```vim
:'<,'>LumaTool explain
```

工具定义见[编写工具](tools.zh-CN.md)，完整示例见 [`examples/tools.lua`](../examples/tools.lua)。
