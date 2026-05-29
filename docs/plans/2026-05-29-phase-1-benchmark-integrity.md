# Phase 1 — Benchmark Integrity Implementation Plan

> **Status:** Draft plan.
> **Parent spec:** `docs/specs/2026-05-29-flutter-benchmark-v2-design.md`

## Goal

Make existing and future tasks trustworthy by adding hidden behavioral verifiers, reference-solution QA, flake checks, and clearer task metadata.

This phase should improve reliability without requiring a full agentic harness yet.

## Success criteria

- Tasks can define visible files separately from hidden verifier files.
- Hidden tests are not present in the model workspace before grading.
- The evaluator can inject hidden verifier files during evaluation.
- A task QA runner can verify:
  - baseline fails hidden verifier;
  - reference solution passes;
  - verifier passes repeated flake runs.
- At least 2 existing tasks are converted as examples.
- Existing tasks with no hidden verifier metadata still run exactly as they do today.

## MVP slice

Keep the first implementation small and shippable:

1. Add additive metadata to `BenchmarkTask`.
2. Add `HiddenTestEvaluator`.
3. Add reference full-file replacement support.
4. Add a task QA runner with baseline-fail/reference-pass/3x hidden-pass checks.
5. Convert exactly two current codegen tasks first:
   - `ui.profile_card`
   - `bug.async_race_condition`

Convert `test.todo_input` only after the MVP works, because test-authoring tasks have different success semantics than generated-source tasks.

## Current code anchors

- `lib/core/benchmark_task.dart` currently exposes `fixtures`, `generatedCodePath`, `isFlutter`, `judgeRubric`, and `evaluatorsFor`.
- `lib/runner/workdir_manager.dart` writes `task.fixtures` and the generated code into a workdir; hidden files must not be added to `fixtures`.
- `lib/runner/run_bloc.dart` currently performs the codegen flow inline: prompt, extract Dart, create workdir, prepare, evaluate, persist.
- `lib/evaluators/test_evaluator.dart` already supports a targeted `testPath`; reuse that behavior where possible.
- `lib/storage/database.dart` is Drift-backed and currently at schema version `3`.

## Architecture

Introduce an explicit task integrity layer around the current `BenchmarkTask` model:

```text
BenchmarkTask
  visible fixtures
  hidden verifier fixtures
  reference solution
  verifier config
```

Keep the current single-shot flow intact:

```text
prompt model -> generated code -> visible workspace -> inject hidden tests -> evaluate
```

## File structure

Likely files to create:

- `lib/core/task_verifier.dart`
- `lib/core/reference_solution.dart`
- `lib/evaluators/hidden_test_evaluator.dart`
- `lib/runner/task_qa_runner.dart`
- `test/evaluators/hidden_test_evaluator_test.dart`
- `test/runner/task_qa_runner_test.dart`

Likely files to modify:

- `lib/core/benchmark_task.dart`
- `lib/runner/workdir_manager.dart`
- `lib/runner/run_bloc.dart`
- selected task files under `lib/tasks/**`
- selected fixture asset declarations in `pubspec.yaml`

## Task 1: Extend task metadata

- [ ] Add optional hidden-verifier fields to `BenchmarkTask`.
- [ ] Keep defaults empty so existing tasks continue to work.
- [ ] Add a task `version` field with default `1`.
- [ ] Add a task `track` or `mode` field with default `codegen`.
- [ ] Add tests proving old tasks still work with defaults.

Suggested shape:

```dart
enum BenchmarkTrack { codegen, agentic }

class VerifierFixture {
  const VerifierFixture({
    required this.files,
    required this.testPath,
    this.id = 'hidden_test',
  });

  final String id;
  final Map<String, String> files;
  final String testPath;
}

sealed class ReferenceSolution {
  const ReferenceSolution();
}

class ReferenceFileSolution extends ReferenceSolution {
  const ReferenceFileSolution(this.files);
  final Map<String, String> files;
}
```

Add defaults on `BenchmarkTask`:

```dart
int get version => 1;
BenchmarkTrack get track => BenchmarkTrack.codegen;
List<VerifierFixture> get hiddenVerifiers => const [];
ReferenceSolution? get referenceSolution => null;
```

Do not remove or rename the existing `ReferencePlan`; it serves planning prompts, not executable reference solutions.

## Task 2: Add hidden test evaluator

- [ ] Create `HiddenTestEvaluator`.
- [ ] Copy hidden verifier files into the workdir immediately before evaluation.
- [ ] Run `dart test` or `flutter test` against the hidden test path.
- [ ] Return structured details: total, passed, failed, failures, exit code, injected file list.
- [ ] Ensure hidden files are not written by `WorkdirManager.createTaskWorkdir`.
- [ ] Do not include hidden file contents in evaluator details, logs, prompts, exports, or UI summaries.
- [ ] Clean up injected hidden files after evaluation when practical; if cleanup is skipped, document that injection happens only after model execution.

Implementation notes:

- Prefer composing or wrapping `TestEvaluator(testPath: verifier.testPath)` after injecting files, so JSON reporter parsing stays in one place.
- Use the same `ctx.task.isFlutter ? 'flutter' : 'dart'` command choice as the existing test evaluator.
- Ensure every injected relative path stays inside `ctx.workDir` and reject absolute paths or `..` traversal.

## Task 3: Add reference solution support

- [ ] Add a `ReferenceSolution` representation.
- [ ] Support either:
  - full replacement files for codegen tasks;
  - patch files for future agentic tasks.
- [ ] Add helper logic to prepare a reference workspace.
- [ ] Run existing evaluators and hidden evaluators against reference workspaces.
- [ ] For the Phase 1 MVP, implement full replacement files first and leave patch application behind an explicit TODO for Phase 2.

Reference workspace sequence:

1. create workdir from visible fixtures only;
2. apply reference replacement files;
3. run `WorkdirManager.prepare`;
4. run public evaluators;
5. inject hidden verifiers and run hidden evaluators.

## Task 4: Add task QA runner

- [ ] Create a task QA service callable from tests or a dev-only UI path.
- [ ] For each task:
  - prepare baseline workspace;
  - confirm hidden verifier fails or exposes missing behavior;
  - apply reference solution;
  - confirm all verifier checks pass;
  - repeat hidden verifier at least 3 times.
- [ ] Return a structured report with per-task QA status.
- [ ] Expose failures as normal test assertions in `test/runner/task_qa_runner_test.dart` for converted tasks.

Suggested report fields:

```dart
class TaskQaReport {
  final String taskId;
  final int taskVersion;
  final bool baselineHiddenFailed;
  final bool referencePassed;
  final int hiddenFlakeRuns;
  final List<String> failureMessages;
}
```

## Task 5: Convert initial tasks

Convert the MVP tasks first:

- [ ] `ui.profile_card`
- [ ] `bug.async_race_condition`
- [ ] `test.todo_input` after the MVP evaluator path is stable

For each converted task:

- [ ] keep public smoke tests visible;
- [ ] move stronger behavioral checks to hidden verifier files;
- [ ] add a reference solution;
- [ ] add task QA expectations.

## Task 6: Storage/reporting updates

- [ ] Add hidden-verifier evaluator IDs to CSV/Markdown export score columns.
- [ ] Include hidden-verifier evaluator output in run details.
- [ ] Show hidden verifier as a primary correctness evaluator in the task run page.
- [ ] Keep database migration for task version/track optional in Phase 1; Phase 4 makes these persistent leaderboard dimensions.

## Validation

Run:

```sh
flutter analyze
flutter test
```

Also run targeted tests during development:

```sh
flutter test test/evaluators/hidden_test_evaluator_test.dart
flutter test test/runner/task_qa_runner_test.dart
```

## Risks

- Hidden tests stored as Flutter assets are still in the repo, so this improves runtime hiding but not public contamination.
- Some current prompts explicitly mention visible tests; converted tasks should become more behavior-focused.
- Hidden verifier failures must be easy to inspect without leaking hidden test source into model prompts.
- Asset declarations in `pubspec.yaml` can reveal hidden file paths; this is acceptable for the local MVP but should be called out in task QA output.
- The current `CompileEvaluator` uses `analyze --fatal-infos`, so hidden verifier compile failures should be surfaced through `HiddenTestEvaluator` details rather than relying on compile-only results.

## Exit criteria

Phase 1 is complete when converted tasks can be run normally, hidden tests are injected only during grading, and task QA catches broken baseline/reference/verifier states.

Rollback/compatibility:

- Because all `BenchmarkTask` additions are default getters, legacy tasks can be restored by removing hidden verifier/reference overrides from converted task classes.
- If hidden evaluator rollout causes issues, remove `HiddenTestEvaluator` from converted tasks while leaving the additive metadata in place.
