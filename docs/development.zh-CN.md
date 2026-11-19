# 开发

## 仓库结构

| 路径 | 作用 |
| --- | --- |
| `lua/luma/init.lua` | 公开 API、命令、setup 和运行时初始化。 |
| `lua/luma/config.lua` | 默认配置、合并、校验和共享配置类型。 |
| `lua/luma/backend.lua` | 请求体和 OpenAI/Ollama 响应解析。 |
| `lua/luma/request.lua` | curl 进程、流式输出、错误和取消。 |
| `lua/luma/session.lua` | 主 Chat 状态和请求协调。 |
| `lua/luma/ui.lua` | 主窗口、导航、渲染和来源窗口恢复。 |
| `lua/luma/history.lua` | 主 Chat 和工具历史记录。 |
| `lua/luma/tools.lua` | 工具注册表和一次性生成。 |
| `lua/luma/tool_chat.lua` | 独立工具 Chat。 |
| `lua/luma/context.lua` | Buffer、文件、诊断和补全上下文。 |
| `lua/luma/diff.lua` | 受保护的选择替换。 |
| `lua/luma/web.lua` | Tavily 集成。 |
| `tests/smoke.lua` | Headless 回归测试。 |

## LuaLS 注解

共享类型定义在负责对应数据的模块中：

- 配置和消息：`config.lua`
- 请求回调和 handle：`request.lua`
- 选择范围：`context.lua`
- 工具定义和 context：`tools.lua`
- 历史记录：`history.lua`

其他模块直接复用这些类型。可空字段和回调签名应与实际运行行为一致。

Provider 请求 handle 提供 `kill()`。`ctx.generate()` 返回的公开 handle 同时提供 `cancel()` 和 `kill()`。

### 本地 LuaLS 配置

`.luarc.json.example` 是编辑器配置的共享起点。将它复制到仓库根目录的 `.luarc.json`：

```sh
cp .luarc.json.example .luarc.json
```

如果 `win.nvim`、`animate.nvim`、Neovim runtime 文件或 LuaJIT 库位于其他位置，修改复制后的 `workspace.library`。例如：

```json
"${workspaceFolder}/../win.nvim/lua",
"${workspaceFolder}/../animate.nvim/lua"
```

`.luarc.json` 只保留在本地。它已被 Git 忽略，不应提交。仓库 lint 命令使用 `.luarc.json.example`；使用 `make lint` 检查共享配置，使用 `make check` 运行完整项目检查。

## 注释

英文注释用于解释代码本身不容易看出的行为，例如：

- 路径和密钥边界
- Parser 缓冲
- 取消和陈旧回调
- 窗口清理与选项恢复
- 安全替换检查

不要为普通赋值加注释，也不要重复函数名称已经说明的内容。

## 安全规则

- 不记录 API Key、Authorization header、完整 Prompt 或生成内容。
- 未经用户明确操作，不运行生成的 Shell 或 Git 命令。
- 替换文本前检查 Buffer、范围和 `changedtick`。
- Timer、进程和窗口清理需要允许重复调用。
- 工具 Chat 状态与主 Chat 保持分离。

## 文档

中英文页面使用相同的章节顺序和示例。公开命令、配置项、API 或工具字段变化时，同时更新两个版本。

用户文档放在 `docs/`，贡献者和代理约束放在 `AGENTS.md`。

## 验证

在仓库根目录运行：

```sh
make check
make test
git diff --check
```

`make check` 会运行 Stylua、Selene、LuaLS 和 Headless smoke tests。需要时可以覆盖本地依赖路径：

```sh
make test WIN_NVIM=/path/to/win.nvim ANIMATE_NVIM=/path/to/animate.nvim
```

Headless 测试无法验证终端布局、动画、选择器体验和真实 Provider。修改 UI 后需要手工检查；测试带副作用的示例时应使用无害命令。
