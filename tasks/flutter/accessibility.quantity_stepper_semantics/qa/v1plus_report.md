# V1+ evidence: `accessibility.quantity_stepper_semantics`

## Hidden fixture literal audit

3-model read-only audit completed with no blockers:

- GPT 5.5 xhigh: `/tmp/pickarena_v1plus_gpt_audit.md`
- Opus 4.8 xhigh: `/tmp/pickarena_v1plus_opus_audit.md`
- GLM 5.2 xhigh: `/tmp/pickarena_v1plus_glm_audit.md`

Result: no hidden-only literals or hidden paths were found in `instruction.md`, `baseline/`, or public tests. The deleted/weakened public-test negative is present and rejected.

## Solver attempts

Solvers were run in sanitized `/tmp` workspaces containing only `instruction.md`, `pubspec.yaml`, `lib/quantity_stepper.dart`, and `test/quantity_stepper_test.dart`. Hidden tests, solution files, negative cases, and author notes were not present during solving.

| Solver | Model | Public tests | Hidden tests | Notes |
| --- | --- | --- | --- | --- |
| Kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | pass, 6/6 | fail, 4/9 | Added labels/disabled state, but hidden semantics found labels/actions on the keyed nodes were incomplete. |
| MiniMax | `ollama/minimax-m3:cloud:xhigh` | pass, 6/6 | fail, 3/9 | Added semantic wrappers, but hidden checks found missing tap actions and screen-reader callback routing. |

Solver reports:

- `/tmp/pickarena_solver_accessibility_kimi_report.md`
- `/tmp/pickarena_solver_accessibility_minimax_report.md`

Validation command after injecting hidden tests into each scratch workspace:

```sh
flutter test test/quantity_stepper_test.dart
flutter test test/_hidden/quantity_stepper_semantics_hidden_test.dart
```

Outcome: both fresh solvers passed the public suite but failed hidden semantic p2p checks, confirming the hidden verifier catches public-only or incomplete accessibility fixes.
