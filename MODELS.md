# Custom Models

Source: `/home/dev/.factory/settings.json`

Sorted by `id` when present, otherwise by `model`.

| # | ID | Model | Display name | Provider | Base URL | Max output tokens | Image support |
|---:|---|---|---|---|---|---:|---|
| 1 | `custom:deepseek-v4-flash---DeepSeek` | `deepseek-v4-flash` | DeepSeek V4 Flash [DeepSeek API] | `generic-chat-completion-api` | `https://api.deepseek.com` | 384000 | No |
| 2 | `custom:deepseek-v4-pro---DeepSeek` | `deepseek-v4-pro` | DeepSeek V4 Pro [DeepSeek API] | `generic-chat-completion-api` | `https://api.deepseek.com` | 384000 | No |
| 3 | `custom:gpt-5.5-high---Codex` | `gpt-5.5-high` | GPT 5.5 (high) | `generic-chat-completion-api` | `http://127.0.0.1:8317/v1` | — | Yes |
| 4 | `custom:gpt-5.5-low---Codex` | `gpt-5.5-low` | GPT 5.5 (low) | `generic-chat-completion-api` | `http://127.0.0.1:8317/v1` | — | Yes |
| 5 | `custom:gpt-5.5-medium---Codex` | `gpt-5.5-medium` | GPT 5.5 (medium) | `generic-chat-completion-api` | `http://127.0.0.1:8317/v1` | — | Yes |
| 6 | `custom:gpt-5.5-xhigh---Codex` | `gpt-5.5-xhigh` | GPT 5.5 (xhigh) | `generic-chat-completion-api` | `http://127.0.0.1:8317/v1` | — | Yes |
| 7 | `custom:qwen3.6-35b-a3b-apex-262k-rx9070xt-turbo3-coding---Local` | `qwen3.6-35b-a3b-apex-262k-rx9070xt-turbo3-coding` | Qwen 3.6 [RX 9070 XT] | `generic-chat-completion-api` | `http://127.0.0.1:8080/v1` | 64000 | Yes |
| 8 | `custom:qwen3.6-35b-a3b-apex-262k-rx9070xt-turbo3-coding-low---Local` | `qwen3.6-35b-a3b-apex-262k-rx9070xt-turbo3-coding` | Qwen 3.6 (low) [RX 9070 XT] | `generic-chat-completion-api` | `http://127.0.0.1:8080/v1` | 16384 | Yes |
| 9 | `—` | `deepseek-v4-flash:cloud` | DeepSeek V4 Flash [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 65536 | Yes |
| 10 | `—` | `deepseek-v4-pro:cloud` | DeepSeek V4 Pro [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 65536 | Yes |
| 11 | `—` | `gemini-3-flash-preview:cloud` | Gemini 3 Flash Preview [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 65536 | Yes |
| 12 | `—` | `gemma4:31b-cloud` | Gemma 4 31B [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 128000 | Yes |
| 13 | `—` | `glm-5.1:cloud` | GLM 5.1 [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 128000 | Yes |
| 14 | `—` | `gpt-oss:120b-cloud` | GPT-OSS 120B [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 128000 | Yes |
| 15 | `—` | `kimi-k2.5:cloud` | Kimi K2.5 [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 128000 | Yes |
| 16 | `—` | `kimi-k2.6:cloud` | Kimi K2.6 [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 128000 | Yes |
| 17 | `—` | `mimo-v2.5` | Mimo V2.5 [OpenCode GO] | `generic-chat-completion-api` | `https://opencode.ai/zen/go/v1` | 128000 | Yes |
| 18 | `—` | `mimo-v2.5-pro` | Mimo V2.5 Pro [OpenCode GO] | `generic-chat-completion-api` | `https://opencode.ai/zen/go/v1` | 128000 | Yes |
| 19 | `—` | `minimax-m2.5:cloud` | Minimax M2.5 [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 128000 | Yes |
| 20 | `—` | `minimax-m2.7:cloud` | Minimax M2.7 [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 128000 | Yes |
| 21 | `—` | `qwen3-coder-next:cloud` | Qwen 3 Coder Next [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 32768 | Yes |
| 22 | `—` | `qwen3.5:cloud` | Qwen 3.5 [Ollama Cloud] | `generic-chat-completion-api` | `https://ollama.com/v1` | 65536 | Yes |
| 23 | `—` | `qwen3.6-plus` | Qwen 3.6 Plus [OpenCode GO] | `generic-chat-completion-api` | `https://opencode.ai/zen/go/v1` | 65536 | Yes |

## Comma-separated list

custom:deepseek-v4-flash---DeepSeek, custom:deepseek-v4-pro---DeepSeek, custom:gpt-5.5-high---Codex, custom:gpt-5.5-low---Codex, custom:gpt-5.5-medium---Codex, custom:gpt-5.5-xhigh---Codex, custom:qwen3.6-35b-a3b-apex-262k-rx9070xt-turbo3-coding---Local, custom:qwen3.6-35b-a3b-apex-262k-rx9070xt-turbo3-coding-low---Local, deepseek-v4-flash:cloud, deepseek-v4-pro:cloud, gemini-3-flash-preview:cloud, gemma4:31b-cloud, glm-5.1:cloud, gpt-oss:120b-cloud, kimi-k2.5:cloud, kimi-k2.6:cloud, mimo-v2.5, mimo-v2.5-pro, minimax-m2.5:cloud, minimax-m2.7:cloud, qwen3-coder-next:cloud, qwen3.5:cloud, qwen3.6-plus
