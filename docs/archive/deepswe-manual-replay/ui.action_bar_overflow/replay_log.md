# Replay log

Fresh repair replay verified three promoted solver families and one failed solver family. Active solver trajectories now include durable subagent input/output/meta artifacts from repair run `cf75c215`. Opus was aborted/unavailable and has no active solver run. Hidden replay logs are restricted evaluator-only artifacts.

| Family | Model | Subagent | Duration | Patch SHA-256 | Public replay | Hidden replay | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gpt | `openai-codex/gpt-5.5:xhigh` | `cf75c215/coder_0` | `234250ms` | `c0c2136d7ab897542e5284540c9995f88926c2f07a7c931da5db1233b5326816` | exit `0` | exit `0` | promoted |
| glm | `ollama/glm-5.2:cloud:xhigh` | `cf75c215/coder_1` | `277498ms` | `fa8ecb4c137c234d636a82013a07805c6a7d554c02b7ae636182cff464edb67a` | exit `0` | exit `1` | failed |
| minimax | `ollama/minimax-m3:cloud:xhigh` | `cf75c215/coder_3` | `518440ms` | `de079f24ce175c8041b97c711baf6bdd6035098e267cf9d5fe50b07792ca75a7` | exit `0` | exit `0` | promoted |
| kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | `cf75c215/coder_4` | `83339ms` | `465d100194fd24d51c1b3fe36134156b73e939c04243d9566ed726fdc685e3d9` | exit `0` | exit `0` | promoted |

## Aborted/unavailable

- `opus` (`anthropic/claude-opus-4-8:xhigh`) aborted/unavailable after `1038638ms`; metadata is recorded only in top-level telemetry/model-audit artifacts and no active solver run was created.
