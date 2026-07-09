# Pure-Dart migration blockers

Step 1 converted only tests that load under plain `dart test`.

| file | blocker | clears in |
| --- | --- | --- |
| `app/test/providers/provider_factory_test.dart` | `provider_factory.dart` -> `storage/settings.dart` -> `flutter_secure_storage` -> Flutter | step 2 |
| `app/test/review/review_repository_test.dart` | `review_repository.dart` -> `storage/settings.dart` -> `flutter_secure_storage` -> Flutter | step 2 |
| `app/test/storage/settings_test.dart` | direct `storage/settings.dart` / `flutter_secure_storage` coverage | step 2 |
| `app/test/storage/settings_readme_test.dart` | direct `storage/settings.dart` / `flutter_secure_storage` coverage | step 2 |
| `app/test/storage/settings_judge_test.dart` | direct `storage/settings.dart` / `flutter_secure_storage` coverage | step 2 |
| `app/test/core/fixture_loader_test.dart` | Flutter asset loader path uses `rootBundle` | step 3 |
| `app/test/core/plan_loader_test.dart` | Flutter plan loader path uses `rootBundle` | step 3 |
| `app/test/core/task_registry_test.dart` | default catalog still loads bundled corpus assets through Flutter bindings | step 3 |
| `app/test/runner/corpus_task_qa_test.dart` | corpus QA still depends on bundled Flutter asset loading | step 3 |
| `app/test/runner/task_qa_runner_test.dart` | legacy task QA fixtures still load through bundled Flutter assets | step 3 |
| `app/test/tasks/counter_bloc_benchmark_correctness_test.dart` | task fixtures still load through bundled Flutter assets | step 3 |
| `app/test/tasks/off_by_one_pagination_test.dart` | task fixtures still load through bundled Flutter assets | step 3 |
| `app/test/tasks/official_file_backed_task_test.dart` | official corpus regression still runs on the Flutter-bound corpus path | step 3 |
| `app/test/tasks/planning_and_execution/add_evaluator_type_judge_test.dart` | reference plan / rubric loading still uses Flutter asset bindings | step 3 |
| `app/test/tasks/planning_and_execution/add_filter_dimension_judge_test.dart` | reference plan / rubric loading still uses Flutter asset bindings | step 3 |
| `app/test/runner/agentic_run_orchestrator_test.dart` | file imports `runner/run_bloc.dart`, which imports `flutter_bloc` | step 6 |
| `app/test/runner/run_bloc_test.dart` | direct `RunBloc` coverage depends on `flutter_bloc` | step 6 |
| `app/test/runner/run_bloc_plan_aware_test.dart` | direct `RunBloc` coverage depends on `flutter_bloc` | step 6 |
| `app/test/evaluators/widget_tree_evaluator_test.dart` | no Flutter import chain in the evaluator itself; left in the flutter suite this pass, convert with the step 6 cleanup | step 6 |
| `app/test/headless/headless_cli_runner_test.dart` | no Flutter imports, but plain `dart test` (Dart 3.11.4) segfaults in its CLI timeout/sqlite subprocess path; runs under `flutter test` only until the VM issue is understood | step 6 |

Counts: step 2 = 5, step 3 = 10, step 6 = 5.
