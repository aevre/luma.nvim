# 使用 Luma

## 命令

| 命令 | 行为 |
| --- | --- |
| `:LumaToggle` | 显示或隐藏聊天界面。 |
| `:LumaSubmit [prompt]` | 提交参数或当前 Prompt buffer。 |
| `:LumaCancel` | 取消进行中的 Chat 和一次性工具请求。 |
| `:LumaNew` | 创建新聊天会话。 |
| `:LumaHistory [all\|chat\|tool name]` | 打开主 Chat 历史或浏览独立工具历史。 |
| `:LumaModel [name]` | 选择或切换当前模型。 |
| `:LumaTool {name}` | 运行用户注册的工具，支持 Visual 范围。 |

## Chat 窗口

主 Chat 协调 Chat、Prompt、Models 和 History 四个窗口。

- 使用 `i`、`o`、`m` 和 `h` 在窗口间移动。
- 使用 `<CR>` 选择模型或恢复历史项目。
- 在主 History 窗口使用 `d`，确认后删除当前记录。
- 使用 `<Esc>` 返回 Prompt。
- 使用 `?` 查看键位帮助。
- 使用 `q` 关闭整个窗口组。

启用 `ui.start_insert` 时，Prompt 打开后默认进入 Insert 模式。流式输出追加到当前 Assistant 回复；用户手动向上滚动后，不会强制把视口拉到底部。

`:LumaHistory all` 会先选择主 Chat 或工具作用域。工具记录可作为只读快照打开或删除；查看历史绝不会重新运行工具或其副作用。程序化管理使用 `luma.history_delete(id, opts)` 和 `luma.history_clear(opts)`，作用域为 `{ scope = "chat" }` 或 `{ scope = "tool", tool = "name" }`。这些 API 不弹确认，删除不可恢复。

## 上下文指令

Chat Prompt 支持：

- `/buffer`：附加来源 buffer。
- `/buffer 编号`：附加其他已列出且已加载的 buffer。
- `/file path`：在 `max_context_bytes` 限制内附加文件。
- `@web_search query`：配置 Tavily 后执行网络搜索。
- `diagnostics = true`：自动附加来源 buffer diagnostics。

未知 buffer 和不可读文件会显示明确错误，不会静默丢弃上下文。

## 补全

Prompt 通过标准 `completefunc` 暴露指令、已列出的 buffer 和文件路径候选。Luma 只返回候选，不会打开、替换或控制外部补全菜单。

不使用补全插件时，通过 Neovim 原生 user-defined completion 调用：

```text
<C-x><C-u>
```

### blink.cmp

添加读取当前 buffer `completefunc` 的 provider：

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

只有定义了 `completefunc` 的 buffer 才会启用该 provider，普通代码 buffer 继续使用原有 source 集合。

### nvim-cmp

`nvim-cmp` 没有读取现有 buffer `completefunc` 的内置 source。可以保留原生 `<C-x><C-u>`，或在 cmp mapping 覆盖该键位时显式转交：

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

该映射会为 Luma 候选打开 Neovim 原生补全菜单；其他 nvim-cmp source 继续使用 cmp 菜单。

## 工具

通过 `:LumaTool name` 运行已配置工具。以下形式会把 Visual 范围传给工具：

```vim
:'<,'>LumaTool explain
```

工具定义详见[编写 Luma 工具](tools.zh-CN.md)，完整实现见[工具示例](../examples/tools.lua)。
