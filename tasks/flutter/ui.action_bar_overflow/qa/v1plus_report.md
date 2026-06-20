# V1+ evidence: `ui.action_bar_overflow`

## Hidden fixture literal audit and verifier repair

3-model read-only audit completed:

- GPT 5.5 xhigh: `/tmp/pickarena_v1plus_gpt_audit.md`
- Opus 4.8 xhigh: `/tmp/pickarena_v1plus_opus_audit.md`
- GLM 5.2 xhigh: `/tmp/pickarena_v1plus_glm_audit.md`

Result: no hidden-only literals or hidden paths were found in `instruction.md`, `baseline/`, or public tests. The deleted/weakened public-test negative is present and rejected.

Audit finding: the first hidden verifier pinned exact width-440 inline counts from the reference threshold policy. Two fresh solvers passed public tests but failed hidden only on that private exact-count expectation. The verifier was repaired to assert a priority-prefix invariant and overflow complement instead of a private pixel breakpoint/exact inline count.

Repair brief/report:

- `/tmp/pickarena_action_bar_v1plus_repair_brief.md`
- `/tmp/pickarena_action_bar_v1plus_repair_report.md`

Post-repair validation:

- task QA: admitted
- official file-backed regression: passed
- `priority_ignored`, `overfit`, and `text_scale_regression` still fail targeted hidden checks per repair report

## Solver attempts

Solvers were run in sanitized `/tmp` workspaces containing only `instruction.md`, `pubspec.yaml`, `lib/responsive_action_bar.dart`, and `test/responsive_action_bar_test.dart`. Hidden tests, solution files, negative cases, and author notes were not present during solving.

| Solver | Model | Public tests | Hidden tests after repair | Notes |
| --- | --- | --- | --- | --- |
| Kimi | `ollama/kimi-k2.7-code:cloud:xhigh` | pass, 3/3 | pass, 7/7 | Uses a fit-based split; now accepted because priority/reachability contract holds. |
| MiniMax | `ollama/minimax-m3:cloud:xhigh` | pass, 3/3 | fail, 6/7 | Still shows overflow in hidden wide layout, violating the wide-layout requirement. |

Solver reports:

- `/tmp/pickarena_solver_action_bar_kimi_report.md`
- `/tmp/pickarena_solver_action_bar_minimax_report.md`

Validation command after injecting the repaired hidden test into each scratch workspace:

```sh
flutter test test/responsive_action_bar_test.dart
flutter test test/_hidden/action_bar_overflow_hidden_test.dart
```

Outcome: one solver passed public+hidden; one passed public but failed hidden on the wide-layout requirement, confirming the hidden verifier still catches incomplete responsive fixes without relying on exact medium-width private thresholds.
