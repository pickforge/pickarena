# Replay log

Clean replay is verified for four fresh solver families: GPT, MiniMax, GLM, and Kimi. Hidden replay logs are restricted evaluator-only artifacts.

| Family | Model | Patch SHA-256 | Public replay | Hidden replay |
| --- | --- | --- | --- | --- |
| gpt | `openai-codex/gpt-5.5:xhigh` | `884b00a17ad0d65bf2c209ed633828fbaded1af8c8d9ab59ac3bad1bf50b52a9` | exit `0` | exit `0` |
| minimax | `ollama/minimax-m3:cloud:xhigh` | `2a1d3f4684cdffb6f93c145b3c95c041941a31d7dd1d1d0fba3b99a6953fe886` | exit `0` | exit `0` |
| glm | `ollama/glm-5.2:cloud:xhigh` | `690154a33792bc3d89b3f4a828f408de8e00e0d15befda6b5c6098b59366e043` | exit `0` | exit `0` |
| kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | `76fd293e5fb07520d85afce4257c773f2e5c6b1ec1d1be7957d6b3b8a510d057` | exit `0` | exit `0` |
