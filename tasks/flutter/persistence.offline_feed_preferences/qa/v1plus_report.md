# V1+ evidence: `persistence.offline_feed_preferences`

## Hidden fixture literal audit

3-model read-only audit completed with no blockers:

- GPT 5.5 xhigh: `/tmp/pickarena_v1plus_gpt_audit.md`
- Opus 4.8 xhigh: `/tmp/pickarena_v1plus_opus_audit.md`
- GLM 5.2 xhigh: `/tmp/pickarena_v1plus_glm_audit.md`

Result: no hidden-only literals or hidden paths were found in `instruction.md`, `baseline/`, or public tests. The deleted/weakened public-test negative is present and rejected.

## Solver attempts

Solvers were run in sanitized `/tmp` workspaces containing only `instruction.md`, `pubspec.yaml`, `lib/offline_feed_preferences.dart`, and `test/offline_feed_preferences_test.dart`. Hidden tests, solution files, negative cases, and author notes were not present during solving.

| Solver | Model | Public tests | Hidden tests | Notes |
| --- | --- | --- | --- | --- |
| Kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | pass, 4/4 | pass, 6/6 | Persisted all fields via store and kept per-field safe parsing. |
| MiniMax | `ollama/minimax-m3:cloud:xhigh` | pass, 4/4 | pass, 6/6 | Added canonical writes and preserved robust per-field fallback behavior. |

Solver reports:

- `/tmp/pickarena_solver_persistence_kimi_report.md`
- `/tmp/pickarena_solver_persistence_minimax_report.md`

Validation command after injecting hidden tests into each scratch workspace:

```sh
flutter test test/offline_feed_preferences_test.dart
flutter test test/_hidden/offline_feed_preferences_hidden_test.dart
```

Both solver outputs passed both commands.
