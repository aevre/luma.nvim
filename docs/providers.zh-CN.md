# 模型平台和 API Key

Luma 支持 OpenAI 兼容的 Chat Completions 接口和 Ollama Chat。

平台地址、模型名称和账户限制可能变化。如果请求失败或模型下线，请以平台自己的文档为准。

## API Key

推荐在配置中填写环境变量名：

```sh
export PROVIDER_API_KEY="..."
```

```lua
api_key = "PROVIDER_API_KEY"
```

Luma 会在请求开始时读取该环境变量。`api_key` 也可以直接填写字符串，或使用函数：

```lua
api_key = function()
  return vim.env.PROVIDER_API_KEY
end
```

不要提交真实密钥，也不要把密钥输出到日志中。

## OpenAI 兼容平台

支持 OpenAI Chat Completions API 的平台可以使用下面的模板：

```lua
models = {
  provider = {
    backend = "openai",
    model = "provider/model-name",
    url = "https://provider.example/v1/chat/completions",
    api_key = "PROVIDER_API_KEY",
  },
}
```

`url` 必须指向 Chat Completions 接口，不能只填写平台的 `/v1` 基础地址。

### OpenRouter 示例

```lua
models = {
  openrouter = {
    backend = "openai",
    model = "openai/gpt-4o-mini",
    url = "https://openrouter.ai/api/v1/chat/completions",
    api_key = "OPENROUTER_API_KEY",
  },
}
```

### 自定义 Header

部分平台需要额外 header：

```lua
headers = {
  "HTTP-Referer: https://example.com",
  "X-Title: Neovim",
}
```

配置 API Key 后，Luma 会自动加入 JSON Content-Type 和 Bearer Authorization header。

## Ollama

```lua
models = {
  qwen = {
    backend = "ollama",
    model = "qwen2.5-coder:7b",
    url = "http://127.0.0.1:11434/api/chat",
  },
}
```

Ollama 不需要 API Key。发送请求前需要启动 Ollama，并安装对应模型。

## 多模型

```lua
require("luma").setup({
  model = "cloud",
  models = {
    cloud = {
      backend = "openai",
      model = "provider/model-name",
      url = "https://provider.example/v1/chat/completions",
      api_key = "PROVIDER_API_KEY",
    },
    local_model = {
      backend = "ollama",
      model = "qwen2.5-coder:7b",
      url = "http://127.0.0.1:11434/api/chat",
    },
  },
})
```

使用 `:LumaModel` 切换模型。

## 排查问题

- **Unknown model**：`model` 没有对应 `models` 中的名称。
- **Missing API key**：配置的环境变量不存在或为空。
- **HTTP error**：检查完整接口地址、模型名称、账户权限和平台状态。
- **Timeout**：提高全局或单个模型的 `timeout`。
- **Ollama 无法连接**：确认服务已启动，并且地址使用 `/api/chat`。

设置 `debug = true` 可以查看请求生命周期。调试输出不会包含密钥、完整 Prompt 或生成内容。
