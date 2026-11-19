# Providers and API keys

Luma supports OpenAI-compatible chat-completion endpoints and Ollama chat.

Provider URLs, model names, and account limits change. Check the provider's own documentation when a request fails or a model is removed.

## API keys

Use an environment variable name in configuration:

```sh
export PROVIDER_API_KEY="..."
```

```lua
api_key = "PROVIDER_API_KEY"
```

Luma reads the environment variable when a request starts. `api_key` may also be a literal string or a function:

```lua
api_key = function()
  return vim.env.PROVIDER_API_KEY
end
```

Do not commit keys or print them in logs.

## OpenAI-compatible providers

Use this template for a provider that implements the OpenAI chat-completions API:

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

The URL must point to the chat-completions endpoint, not only the provider's `/v1` base URL.

### OpenRouter example

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

### Custom headers

Some providers require extra headers:

```lua
headers = {
  "HTTP-Referer: https://example.com",
  "X-Title: Neovim",
}
```

Luma adds the JSON content type and bearer authorization header automatically when an API key is configured.

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

Ollama does not need an API key. Start Ollama and install the selected model before sending a request.

## Multiple models

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

Use `:LumaModel` to switch models.

## Troubleshooting

- **Unknown model**: `model` does not match a key in `models`.
- **Missing API key**: the configured environment variable is unset or empty.
- **HTTP error**: verify the full endpoint, model name, account access, and provider status.
- **Timeout**: increase the global or per-model `timeout`.
- **Ollama connection failure**: confirm the server is running and the URL uses `/api/chat`.

Enable `debug = true` to log request lifecycle details. Debug output does not include keys, prompts, or generated content.
