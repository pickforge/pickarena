# Replay log

No fresh solver family is promoted for this slice. GPT, GLM, Opus, MiniMax, and Kimi all passed public replay but failed hidden replay. The reference solution passes hidden replay, so the task remains admitted, but this DeepSWE candidate is not promotion-ready. Hidden replay logs are restricted evaluator-only artifacts.

| Family | Model | Patch SHA-256 | Public replay | Hidden replay |
| --- | --- | --- | --- | --- |
| gpt | `openai-codex/gpt-5.5:xhigh` | `d76c185ed99b457eef01be06d8fef2e567eef0c86a92c80fd8337d1477699a9a` | exit `0` | exit `1` |
| glm | `ollama/glm-5.2:cloud:xhigh` | `e840d8a60daeb38debb2131289239048dc9c933fda468525cc28ae2c81d97d96` | exit `0` | exit `1` |
| opus | `anthropic/claude-opus-4-8:xhigh` | `8a10bb0463741a2a7912194e7ab9636feae8e3d5f5f4528e94585f0aef287cfa` | exit `0` | exit `1` |
| minimax | `ollama/minimax-m3:cloud:xhigh` | `fa834b0667dc135e384b1b4ac39f489d3f34ebaed3f9fa4b3d24c405e580d2d4` | exit `0` | exit `1` |
| kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | `f727b867e7b93e4dd72059e76c10ab707f54eab03dcb8cc99cbf112c4e76df92` | exit `0` | exit `1` |
