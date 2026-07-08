# Replay log

Clean replay is verified for three fresh solver families: GPT, GLM, and Opus. MiniMax and Kimi passed public replay but failed hidden replay and are retained as failed fresh solver attempts. Hidden replay logs are restricted evaluator-only artifacts.

## Passing patches

| Family | Model | Patch SHA-256 | Public replay | Hidden replay |
| --- | --- | --- | --- | --- |
| gpt | `openai-codex/gpt-5.5:xhigh` | `98cff265b2452874476f0031fa4e96cf00902fbbd701fe4ca008d1ef4caae2e8` | exit `0` | exit `0` |
| glm | `ollama/glm-5.2:cloud:xhigh` | `1622043629313cbef0ba63c42275ae76a8d632eb234c9c1f4e5fd4a2091fe7c1` | exit `0` | exit `0` |
| opus | `anthropic/claude-opus-4-8:xhigh` | `64f5fbc210e6f62b1548b91d4137461f0a2e341e3d66906c4f367a7576cff5fb` | exit `0` | exit `0` |

## Failed public-only patches

| Family | Model | Patch SHA-256 | Public replay | Hidden replay |
| --- | --- | --- | --- | --- |
| minimax | `ollama/minimax-m3:cloud:xhigh` | `78bfdf5b8f719c0a457e1674b89d69f1df67c164c7a717681661e5e2d87eed6c` | exit `0` | exit `1` |
| kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | `5024d8219fc7a2cc8980db9832d9effb52e80fb00056778407a2984075c31244` | exit `0` | exit `1` |
