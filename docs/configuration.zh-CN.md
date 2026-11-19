# 配置

通过插件管理器或 `require("luma").setup(opts)` 配置 Luma。

## 最小配置

```lua
require("luma").setup({
  model = "openrouter",
  models = {
    openrouter = {
      backend = "openai",
      model = "openai/gpt-4o-mini",
      url = "https://openrouter.ai/api/v1/chat/completions",
      api_key = "OPENROUTER_API_KEY",
    },
  },
})
```

`model` 必须对应一个已配置的模型名称。

## 通用选项

| 选项 | 默认值 | 作用 |
| --- | --- | --- |
| `model` | 第一个已配置模型 | 初始模型名称。 |
| `prompt` | 编码助手 Prompt | 主 Chat 的 system prompt。 |
| `stream` | `true` | 使用流式输出。 |
| `timeout` | `120000` | 请求超时，单位为毫秒。 |
| `max_tokens` | `nil` | 可选的 provider token 限制。 |
| `temperature` | `nil` | 可选的 provider temperature。 |
| `diagnostics` | `false` | 主 Chat 提交时加入来源 Buffer 的诊断信息。 |
| `debug` | `false` | 通过 `vim.notify` 输出请求生命周期日志。 |
| `max_context_bytes` | `200000` | `/buffer` 和 `/file` 共用的字节限制。 |

## 模型

`models` 可以使用以名称为键的表：

```lua
models = {
  fast = {
    backend = "openai",
    model = "provider/model-name",
    url = "https://provider.example/v1/chat/completions",
    api_key = "PROVIDER_API_KEY",
  },
}
```

也可以使用列表，但每项都必须提供 `name`。

| 字段 | 作用 |
| --- | --- |
| `name` | 仅列表形式需要。 |
| `backend` | `"openai"` 或 `"ollama"`，默认 `"openai"`。 |
| `model` | 发送给 provider 的模型标识。 |
| `url` | Chat 接口地址。 |
| `api_key` | 环境变量名、密钥字符串，或返回密钥的函数。 |
| `headers` | 额外的 curl header。 |
| `stream` | 覆盖该模型的流式设置。 |
| `timeout` | 覆盖该模型的超时设置。 |

示例见[模型平台和 API Key](providers.zh-CN.md)。

## 历史记录

```lua
history = {
  path = vim.fn.stdpath("state") .. "/luma-history",
  max = 20,
}
```

主 Chat 和每个工具分别计算保留数量。工具 Chat 和成功完成的 `ctx.generate()` 保存在 `history.path .. "/tools"` 下。

历史记录包含用户输入、生成结果、模型、时间和工具名称，不包含 system prompt、密钥、请求 header，也不包含生成完成后执行命令产生的结果。

工具或单次生成可以设置 `history = false`。工具可以使用 `history_max` 覆盖保留数量。

## UI

```lua
ui = {
  position = "float",
  width = 0.8,
  height = 0.8,
  input_height = 0.18,
  border = "rounded",
  start_insert = true,
}
```

`position` 支持 `float`、`left`、`right`、`top` 和 `bottom`。小于 1 的 width 和 height 会按编辑器尺寸计算。

## 键位

```lua
keys = {
  submit = "<C-s>",
  close = "<C-q>",
  cancel = "<C-c>",
  new = "<C-n>",
  resend = "<C-r>",
}
```

一次性生成只会在来源 Buffer 没有同名本地映射时，临时使用配置的取消键。

## Web 搜索

```lua
web_search = {
  api_key = "TAVILY_API_KEY",
  url = "https://api.tavily.com/search",
  max_results = 5,
}
```

配置后可在主 Prompt 中使用 `@web_search query`。

## 工具

```lua
tools = require("my_luma_tools")
```

工具使用模型的优先级为：

1. `ctx.generate({ model = "name" })`
2. 工具的 `model`
3. 全局 `model`

详见[编写工具](tools.zh-CN.md)。

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
    qwen = {
      backend = "ollama",
      model = "qwen2.5-coder:7b",
      url = "http://127.0.0.1:11434/api/chat",
    },
  },
  diagnostics = false,
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
  web_search = {
    api_key = "TAVILY_API_KEY",
    url = "https://api.tavily.com/search",
    max_results = 5,
  },
  tools = require("my_luma_tools"),
})
```
