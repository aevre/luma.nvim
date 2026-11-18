# llm.nvim 大模型 API Key 指南

本文整理 `llm.nvim` 常用云端模型平台的官方 API Key 入口，以及对应的接口配置。平台的免费额度、模型名称和政策可能变化；创建密钥前请在控制台确认当前价格、地区可用性与限额。

## 免费平台清单

这里的“免费”分为三类：长期免费层、明确标注为免费的模型路由，以及一次性的试用额度。试用额度不等同于长期免费，额度用完或过期后可能自动转为计费；不确定时应打开平台的“免费额度用完即停”或消费上限。

| 平台 | 免费类型与当前范围 | OpenAI 兼容接口 | 主要限制 |
| --- | --- | --- | --- |
| Google Gemini | Gemini API Free tier：仅部分模型，输入和输出 Token 免费；例如 `gemini-2.5-flash`、`gemini-2.5-flash-lite` 的免费层仍列在官方价格页 | `https://generativelanguage.googleapis.com/v1beta/openai` | 按模型和项目限速；免费层数据可能用于改进 Google 产品；高级模型不在免费层 |
| Groq | Free 计划，适合开发和测试；可用模型和额度以账户 Limits 页面为准 | `https://api.groq.com/openai/v1` | 免费计划有 RPM、RPD、TPM、TPD 等限制，且会随模型和账户变化 |
| SambaNova | SambaCloud Free tier；当前官方表格列出 `DeepSeek-V3.1`、`Meta-Llama-3.3-70B-Instruct`、`gpt-oss-120b`，部分 Preview 模型也有免费层 | `https://api.sambanova.ai/v1` | 示例免费额度为每模型 20 RPM、20 RPD、200K TPD；无支付方式时使用 Free tier |
| Cohere | 注册即可获得免费的 trial key | `https://api.cohere.com/v2` | Chat 通常 20 RPM；trial key 其他端点合计每月 1,000 次调用；适合个人测试，不是无限免费生产额度 |
| OpenRouter | `openrouter/free` 免费路由，以及多个带 `:free` 后缀的模型 | `https://openrouter.ai/api/v1` | 路由会从可用免费模型中随机选择，模型、可用性和上下文长度会变化；免费模型有独立速率限制 |
| Cloudflare Workers AI | Workers Free 每日 10,000 Neurons；Paid 计划仍包含每日免费额度 | 需按账户 ID 构造 Workers AI URL | 额度按 UTC 每日重置；部分 frontier 模型需要付费计划或 AI Gateway credits |
| NVIDIA NIM | `build.nvidia.com` 提供部分托管模型的免费 inference 试用 | 以 Build 页面生成的 Endpoint 和 Key 为准 | 免费访问、模型、并发和速率由 NVIDIA 控制台当前状态决定，不能视为无限免费 API |
| SiliconFlow 硅基流动 | 部分模型或新用户额度可能免费，具体以模型页和账户控制台为准 | `https://api.siliconflow.com/v1` | 不是所有模型长期免费；模型页显示的价格、最大用量和活动可能变化 |
| 阿里云百炼 / Qwen | 新用户免费额度：北京地域、按模型独立发放，通常每模型 100 万 Token，有效期 90 天 | `https://dashscope.aliyuncs.com/compatible-mode/v1`，或使用业务空间专属地址 | 需实名认证；其他地域通常无该额度；额度耗尽后默认可能转按量付费，建议开启“免费额度用完即停” |

**不应列为长期免费：** Cerebras 当前 Free Trial 是绑定已验证支付方式后获得的 5 美元额度，30 天到期；DeepSeek、OpenAI、Anthropic、Mistral、Kimi 和智谱的 API 不应在没有当前官方赠金凭据时表述为长期免费。OpenAI 的免费层级（若账户符合地区条件）是账户级使用层限额，不是免费模型；ChatGPT Pro/Business 的 API credits 也是订阅权益。

## 申请入口

| 平台 | API Key 入口 | `llm.nvim` 接口地址 | `api_type` |
| --- | --- | --- | --- |
| OpenAI | [API Keys](https://platform.openai.com/api-keys) | `https://api.openai.com/v1/chat/completions` | `openai` |
| Anthropic Claude | [Console API Keys](https://console.anthropic.com/settings/keys) | `https://api.anthropic.com/v1/messages` | Anthropic 原生格式；不要在未验证前假定 `llm.nvim` 当前后端能解析该响应 |
| Google Gemini | [Google AI Studio API Keys](https://aistudio.google.com/app/apikey) | `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` | `openai`（兼容接口） |
| DeepSeek | [API Keys](https://platform.deepseek.com/api_keys) | `https://api.deepseek.com/chat/completions` | `deepseek` |
| Kimi / Moonshot | [Kimi API Platform](https://platform.kimi.ai/docs/get-your-api-key) | `https://api.moonshot.ai/v1/chat/completions` | `openai`（兼容接口） |
| 智谱 GLM | [开放平台 API Keys](https://open.bigmodel.cn/usercenter/apikeys) | `https://open.bigmodel.cn/api/paas/v4/chat/completions` | `zhipu` |
| 阿里云百炼 / Qwen | [获取与配置 API Key](https://help.aliyun.com/zh/model-studio/get-api-key) | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`；北京业务空间推荐 `https://{WorkspaceId}.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions` | `openai`；API Key 必须与地域匹配 |
| SiliconFlow 硅基流动 | [API Keys](https://cloud.siliconflow.cn/account/ak) | `https://api.siliconflow.com/v1/chat/completions` | `openai`（兼容接口） |
| OpenRouter | [API Keys](https://openrouter.ai/keys) | `https://openrouter.ai/api/v1/chat/completions` | `openai` |
| Requesty | [Router 控制台](https://app.requesty.ai/router) | `https://router.requesty.ai/v1/chat/completions` | `openai` |
| ChatAnywhere | [授权入口](https://api.chatanywhere.org/v1/oauth/free/render) | `https://api.chatanywhere.tech/v1/chat/completions` | `openai` |
| Cloudflare Workers AI | [Cloudflare Dashboard](https://dash.cloudflare.com/) | `https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/v1/chat/completions`（OpenAI 兼容） | `openai`；另有 Workers AI 原生 API |

Groq、SambaNova、Cohere、OpenRouter、NVIDIA NIM 等平台的免费使用状态见上方“免费平台清单”。本地 Ollama 和 LM Studio 通常不需要云端 API Key。GitHub Models / Copilot 未列入本指南，因为相关服务已停止或不可用。

## 配置密钥

`llm.nvim` 默认从环境变量 `LLM_KEY` 读取密钥。将其写入 shell 配置文件（例如 `~/.zshrc`），然后重启 Neovim：

```sh
export LLM_KEY="在此填入 API Key"
```

不要把真实密钥写进 Lua 配置、提交到 Git 或贴进日志。若同时使用多个平台，建议分别设置环境变量，并在模型配置中通过 `fetch_key` 选择：

```sh
export DEEPSEEK_API_KEY="..."
export OPENROUTER_API_KEY="..."
```

```lua
models = {
  {
    name = "DeepSeek",
    url = "https://api.deepseek.com/chat/completions",
    model = "deepseek-chat",
    api_type = "deepseek",
    fetch_key = function()
      return vim.env.DEEPSEEK_API_KEY
    end,
  },
  {
    name = "OpenRouter",
    url = "https://openrouter.ai/api/v1/chat/completions",
    model = "deepseek/deepseek-chat",
    api_type = "openai",
    fetch_key = function()
      return vim.env.OPENROUTER_API_KEY
    end,
  },
}
```

对于单模型配置也可以设置 `fetch_key`；它支持字符串或返回字符串的函数。使用多个模型时，显式设置各自的 `fetch_key`，不要依赖共享的 `LLM_KEY`。

## 平台配置示例

以下是 OpenAI 兼容接口的通用形式。把地址和模型名替换为平台文档当前提供的值：

```lua
require("llm").setup({
  url = "https://api.siliconflow.com/v1/chat/completions",
  model = "Qwen/Qwen2.5-7B-Instruct",
  api_type = "openai",
  fetch_key = function()
    return vim.env.SILICONFLOW_API_KEY
  end,
})
```

DeepSeek、Kimi、智谱等平台的 `api_type`、URL 和模型名应以表格及平台文档为准。OpenRouter 的模型标识通常采用 `提供商/模型名` 格式。Cloudflare Workers AI 还需要配置账户 ID；具体字段和模型地址请参考插件的 Cloudflare 示例。

## 本地模型

Ollama 默认地址通常为 `http://localhost:11434/api/chat`。按插件配置使用 `api_type = "ollama"`；本地服务不需要密钥时，插件文档要求将 `LLM_KEY` 设为 `NONE`：

```sh
export LLM_KEY="NONE"
```

```lua
require("llm").setup({
  url = "http://localhost:11434/api/chat",
  model = "qwen2.5-coder:7b",
  api_type = "ollama",
  fetch_key = "NONE",
})
```

## 官方文档与额度依据

- [llm.nvim 中文 README](https://github.com/Kurama622/llm.nvim/blob/main/README_CN.md)
- [Google Gemini API Key](https://ai.google.dev/gemini-api/docs/api-key) 与 [价格/免费层](https://aistudio.google.com/docs/pricing)
- [Groq 免费计划](https://console.groq.com/settings/billing/plans) 与 [Rate Limits](https://console.groq.com/docs/rate-limits)
- [SambaNova API Keys/URLs](https://docs.sambanova.ai/docs/en/get-started/api-keys-urls) 与 [Rate Limits](https://docs.sambanova.ai/docs/en/models/rate-limits)
- [Cohere API Keys and Rate Limits](https://docs.cohere.com/docs/rate-limits)
- [OpenRouter Free Models Router](https://openrouter.ai/openrouter/free)
- [Cloudflare Workers AI Pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/)
- [NVIDIA Build](https://build.nvidia.com/)
- [阿里云百炼新人免费额度](https://help.aliyun.com/zh/model-studio/new-free-quota)、[OpenAI 兼容接口](https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope) 与 [API Key](https://help.aliyun.com/zh/model-studio/get-api-key)
- [SiliconFlow 快速开始](https://docs.siliconflow.com/en/userguide/quickstart)
- [Moonshot API 快速开始](https://platform.kimi.ai/docs/get-your-api-key)
- [OpenRouter 认证说明](https://openrouter.ai/docs/api_reference/authentication)
- [OpenAI API 预付费说明](https://help.openai.com/en/articles/8264644-setting-up-prepaid-api-billing) 与 [订阅 API credits](https://developers.openai.com/api/docs/guides/chatgpt-api-credits)
- [Cerebras Rate Limits / Free Trial 说明](https://inference-docs.cerebras.ai/support/rate-limits)
