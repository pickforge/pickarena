# Pure-Dart migration blockers

Step 2 cleared the settings storage blockers; remaining rows still need later
pure-Dart migration steps.

| file | blocker | clears in |
| --- | --- | --- |
| `app/test/runner/agentic_run_orchestrator_test.dart` | file imports `runner/run_bloc.dart`, which imports `flutter_bloc` | step 6 |
| `app/test/runner/run_bloc_test.dart` | direct `RunBloc` coverage depends on `flutter_bloc` | step 6 |
| `app/test/runner/run_bloc_plan_aware_test.dart` | direct `RunBloc` coverage depends on `flutter_bloc` | step 6 |
| `app/test/evaluators/widget_tree_evaluator_test.dart` | no Flutter import chain in the evaluator itself; left in the flutter suite this pass, convert with the step 6 cleanup | step 6 |
| `app/test/headless/headless_cli_runner_test.dart` | no Flutter imports, but plain `dart test` (Dart 3.11.4) segfaults in its CLI timeout/sqlite subprocess path; runs under `flutter test` only until the VM issue is understood | step 6 |

Counts: step 3 = 0, step 6 = 5.
