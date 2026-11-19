# Luma 配置

通过插件管理器或 `require("luma").setup(opts)` 配置 Luma。带保护的运行时入口只应用默认值，不会打开窗口或启动请求。

## 完整示例

```lua
require("luma").setup({
  prompt = "You are a concise coding assistant.",
  model = "openrouter",
  models = {
    openrouter = {
      backend = "openai",
      model = "openai/gpt-4o-mini",
      url = "https://openrouter.ai/api/v1/chat/completions",
      api_key = "OPENROUTER_API_KEY",
    },
  },
  stream = true,
  timeout = 120000,
  max_tokens = nil,
  temperature = nil,
  diagnostics = false,
  debug = false,
  max_context_bytes = 200000,
  history = {
    path = vim.fn.stdpath("state") .. "/luma-history",
    max = 20,
  },
  ui = {
    position = "float",
    width = 0.8,
    height = 0.8,
    input_height = 0.18,
    border = "rounded",
    start_insert = true,
  },
  keys = {
    submit = "<C-s>",
    close = "<C-q>",
    cancel = "<C-c>",
    new = "<C-n>",
    resend = "<C-r>",
  },
  web_search = {
    api_key = "TAVILY_API_KEY",
    url = "https://api.tavily.com/search",
    max_results = 5,
  },
  tools = require("my_luma_tools"),
})
```

## 模型

`models` 支持键值表，也支持包含显式 `name` 字段的列表。`model` 用于选择初始模型。

### OpenAI 兼容模型

```lua
models = {
  openrouter = {
    backend = "openai",
    model = "openai/gpt-4o-mini",
    url = "https://openrouter.ai/api/v1/chat/completions",
    api_key = "OPENROUTER_API_KEY",
    headers = {},
    timeout = 120000,
  },
}
```

`api_key` 可以是环境变量名、直接填写的密钥，或返回密钥的函数。模型字段可以覆盖请求 URL、headers、timeout 和 provider 模型名称。

### Ollama

```lua
models = {
  qwen = {
    backend = "ollama",
    model = "qwen2.5-coder:7b",
    url = "http://127.0.0.1:11434/api/chat",
  },
}
```

Ollama 不需要 API key。

## 请求与上下文

| 选项 | 含义 |
| --- | --- |
| `prompt` | 主 Chat system prompt。 |
| `stream` | 是否使用流式响应。 |
| `timeout` | 请求超时，单位为毫秒。 |
| `max_tokens` | 可选 provider token 限制。 |
| `temperature` | 可选 provider sampling temperature。 |
| `diagnostics` | 提交时附加来源 buffer diagnostics。 |
| `max_context_bytes` | 上下文指令最多读取的字节数。 |

## 历史

`history.path` 控制持久化目录。`history.max` 分别限制每个独立历史作用域：主 Chat 和每个注册工具各自最多保留该数量的记录。工具 Chat 和成功完成的 `ctx.generate()` 使用 `history.path .. "/tools"` 下的独立子目录。工具或单次请求可设置 `history = false`，工具可通过 `history_max` 覆盖保留数量。

历史只保存用户输入、生成结果、模型、时间戳和工具名，不保存 system prompt、凭据、请求 header，也不保存生成完成后产生的副作用结果。

## UI 与键位

`ui.position` 支持 `float`、`top`、`right`、`bottom` 和 `left`。小数形式的 width 和 height 相对编辑器尺寸计算。`ui.input_height` 控制 Prompt 所占比例。`ui.start_insert` 决定打开 Chat 时是否聚焦 Prompt 并进入 Insert 模式。

配置键位分别控制提交、关闭、取消、新会话和重新发送。一次性工具生成期间，如果来源 buffer 没有相同的 buffer-local 映射，Luma 会临时使用 `keys.cancel`。

## Tavily 搜索

设置 `web_search.api_key` 后，可在 Chat Prompt 中使用 `@web_search query`。Luma 请求 `web_search.url`，最多包含 `max_results` 条结果。

## 调试日志

设置 `debug = true` 后，LLM 和 Tavily 请求会输出 `vim.log.levels.DEBUG` 生命周期日志，包括请求编号、backend/model、是否流式、消息和字节数、耗时、完成、取消及错误。

日志不会包含 API key、Authorization headers、完整 prompt 或生成内容。可通过 `:messages` 或通知插件历史查看。

## 工具模型

工具模型优先级为：

1. 单次请求的 `ctx.generate({ model = "name" })`。
2. 工具顶层 `model`。
3. 全局 `model`。

工具配置详见[编写 Luma 工具](tools.zh-CN.md)。
