# Replay log

## Result

Clean replay is verified for three fresh solver families: GPT, MiniMax, and GLM. Kimi passed public replay but failed hidden replay and is retained as a failed fresh solver attempt.

## Passing patches

| Family | Model | Patch SHA-256 | Public replay | Hidden replay |
| --- | --- | --- | --- | --- |
| gpt | `openai-codex/gpt-5.5:xhigh` | `00136bd4275048283bfbe07386b36ef1d60095bfd4284ef9446912df36f18164` | exit `0` | exit `0` |
| minimax | `ollama/minimax-m3:cloud:xhigh` | `115ccce4428c9805572aa8151b3cbaa6399f1f74e2ec0329ea9bfee744882f74` | exit `0` | exit `0` |
| glm | `ollama/glm-5.2:cloud:xhigh` | `9ebfdeb6285c5207e9380b8e3075b27af87cf63ea6165a142f9df64b61393d5f` | exit `0` | exit `0` |

## Failed fresh solver

| Family | Model | Patch SHA-256 | Public replay | Hidden replay |
| --- | --- | --- | --- | --- |
| kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | `fe1269859a6e1a6b76cb25444fdec3fb51da4062690e266159719ded4a77d9ad` | exit `0` | exit `1` |

Hidden replay logs are restricted evaluator-only artifacts.
