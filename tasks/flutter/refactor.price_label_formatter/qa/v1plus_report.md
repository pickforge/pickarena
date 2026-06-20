# V1+ evidence: `refactor.price_label_formatter`

## Hidden fixture literal audit

3-model read-only audit completed with no blockers:

- GPT 5.5 xhigh: `/tmp/pickarena_v1plus_gpt_audit.md`
- Opus 4.8 xhigh: `/tmp/pickarena_v1plus_opus_audit.md`
- GLM 5.2 xhigh: `/tmp/pickarena_v1plus_glm_audit.md`

Result: no hidden-only literals or hidden paths were found in `instruction.md`, `baseline/`, or public tests. The deleted/weakened public-test negative is present and rejected.

## Solver attempts

Solvers were run in sanitized `/tmp` workspaces containing only `instruction.md`, `pubspec.yaml`, `lib/*.dart`, and `test/price_labels_test.dart`. Hidden tests, solution files, negative cases, and author notes were not present during solving.

| Solver | Model | Public tests | Hidden tests | Notes |
| --- | --- | --- | --- | --- |
| Kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | pass, 6/6 | pass, 20/20 | Completed formatter rules and routed widgets through injected formatter. |
| MiniMax | `ollama/minimax-m3:cloud:xhigh` | pass, 6/6 | pass, 20/20 | Completed formatter rules, removed duplicated helpers, preserved API. |

Solver reports:

- `/tmp/pickarena_solver_price_kimi_report.md`
- `/tmp/pickarena_solver_price_minimax_report.md`

Validation command after injecting hidden tests into each scratch workspace:

```sh
flutter test test/price_labels_test.dart
flutter test test/_hidden/price_label_formatter_hidden_test.dart
```

Both solver outputs passed both commands.
