# dart_arena

A Flutter desktop app for benchmarking AI coding models across Dart/Flutter tasks.

## Model Recommendations (2026-05-07)

Based on benchmark runs across 12 tasks × 40+ model/effort combos.

### Overall Best
`gpt-5.3-codex` / `gpt-5.5` (local) — consistent top scores, 1–25s latency, zero failures, reliable output structure.

| Capability | Model | Notes |
|---|---|---|
| Brainstorming | `qwen3.6-plus::high` | Verbose reasoning, explores alternatives. Cap with `max_tokens` to prevent loops |
| Creating plans | `deepseek-v4-pro::high` | Strong chain-of-thought, structured output |
| Executing plans | `gpt-5.5` (local) | Follows instructions precisely, minimal hallucination |
| Debugging | `kimi-k2.6::medium` | Methodical, catches edge cases and off-by-one errors |
| Refactoring | `glm-5.1::medium` | Good balance of minimal changes vs correctness |
| Widget / UI | `gpt-5.5` (local) | Fastest time-to-correct-code ratio |
| Speed | `gpt-5.3-codex` | 1–3s per task vs 3–500s for cloud models |
| Value (score/latency) | `deepseek-v4-flash::high` | Decent output at 3–22s, 10× faster than Kimi/Qwen |

### Effort Levels
Higher effort does not reliably produce higher scores. The safest universal effort list for OpenCode Go is `low`, `medium`, `high` — only these are accepted by all 14 models. See [opencode_go_efforts.md](opencode_go_efforts.md) for per-model effort support details.

### Provider Effort Support
| Provider | Supported Efforts |
|---|---|
| OpenCode Go | low, medium, high (universal) |
| DeepSeek | high, max |
| OpenAI | low, medium, high, xhigh |
| Anthropic | (budget_tokens — not yet implemented) |
| Local / Ollama / DroidExec | none |
