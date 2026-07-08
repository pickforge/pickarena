# V1+ evidence: `async.refresh_deduplicator`

## Hidden fixture literal audit

3-model read-only audit completed with no blockers:

- GPT 5.5 xhigh: `/tmp/pickarena_v1plus_gpt_audit.md`
- Opus 4.8 xhigh: `/tmp/pickarena_v1plus_opus_audit.md`
- GLM 5.2 xhigh: `/tmp/pickarena_v1plus_glm_audit.md`

Result: no hidden-only literals or hidden paths were found in `instruction.md`, `baseline/`, or public tests. The deleted/weakened public-test negative is present and rejected by hidden tests.

## Solver attempts

Solvers were run in sanitized `/tmp` workspaces containing only `instruction.md`, `pubspec.yaml`, `lib/feed_refresh_controller.dart`, and `test/feed_refresh_controller_test.dart`. Hidden tests, solution files, negative cases, and author notes were not present during solving.

| Solver | Model | Public tests | Hidden tests | Notes |
| --- | --- | --- | --- | --- |
| Kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | pass, 2/2 | pass, 6/6 | Used request ids plus in-flight counter. |
| MiniMax | `ollama/minimax-m3:cloud:xhigh` | pass, 2/2 | pass, 6/6 | Used pending refresh future plus stale request guard. |

Solver reports:

- `/tmp/pickarena_solver_async_kimi_report.md`
- `/tmp/pickarena_solver_async_minimax_report.md`

Validation command after injecting hidden tests into each scratch workspace:

```sh
flutter test test/feed_refresh_controller_test.dart
flutter test test/_hidden/feed_refresh_controller_hidden_test.dart
```

Both solver outputs passed both commands.
