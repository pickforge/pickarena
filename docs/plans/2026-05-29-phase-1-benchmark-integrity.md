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
- Hidden verifier and reference-solution paths are validated as workspace-relative paths; absolute paths and `..` traversal are rejected before any write.
- Converted task QA tests prove the current baseline fails hidden verification, the reference solution passes, and hidden verification passes 3 repeated runs.

## MVP slice

Keep the first implementation small and shippable:

1. Add additive metadata to `BenchmarkTask`.
2. Add `HiddenTestEvaluator`.
3. Add reference full-file replacement support.
4. Add a task QA runner with baseline-fail/reference-pass/3x hidden-pass checks.
5. Convert exactly two current codegen tasks first:
   - `ui.profile_card`
   - `bug.async_race_condition`

Leave `test.todo_input` for after the MVP works, because test-authoring tasks have different success semantics than generated-source tasks; do not convert it in this Phase 1 MVP.

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
- `lib/tasks/ui_from_spec/fixtures/profile_card/test/_hidden/profile_card_hidden_test.dart`
- `lib/tasks/ui_from_spec/fixtures/profile_card/reference/lib/profile_card.dart`
- `lib/tasks/bug_fix/fixtures/async_race_condition/test/_hidden/search_controller_hidden_test.dart`
- `lib/tasks/bug_fix/fixtures/async_race_condition/reference/lib/search_controller.dart`
- `test/evaluators/hidden_test_evaluator_test.dart`
- `test/runner/task_qa_runner_test.dart`

Likely files to modify:

- `lib/core/benchmark_task.dart`
- `lib/runner/workdir_manager.dart`
- selected task files under `lib/tasks/**`
- selected fixture asset declarations in `pubspec.yaml`
- `lib/export/csv_exporter.dart`
- `lib/export/md_exporter.dart`
- `lib/analytics/dimensions.dart`

No `RunBloc` control-flow change should be needed for the MVP: converted tasks can add `HiddenTestEvaluator` through `evaluatorsFor`, and the existing evaluator loop should persist its result like any other evaluator.

## Task 1: Extend task metadata

- [ ] Add optional hidden-verifier fields to `BenchmarkTask`.
- [ ] Keep defaults empty so existing tasks continue to work.
- [ ] Add a task `version` field with default `1`.
- [ ] Add a task `track` or `mode` field with default `codegen`.
- [ ] Add tests proving old tasks still work with defaults.
- [ ] Keep hidden verifier files and reference files out of `fixtures`; they must be loaded through separate task metadata so `WorkdirManager.createTaskWorkdir` writes only the visible workspace.

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

Add one small path-safety helper used by hidden verifier injection and reference replacement. It should normalize each target path under `ctx.workDir`, reject absolute paths, reject any path containing `..`, and verify the resolved path is still inside the workdir before writing.

## Task 2: Add hidden test evaluator

- [ ] Create `HiddenTestEvaluator`.
- [ ] Copy hidden verifier files into the workdir immediately before evaluation.
- [ ] Run `dart test` or `flutter test` against the hidden test path.
- [ ] Return structured details: total, passed, failed, failures, exit code, injected file list.
- [ ] Ensure hidden files are not written by `WorkdirManager.createTaskWorkdir`.
- [ ] Do not include hidden file contents in evaluator details, logs, prompts, exports, or UI summaries.
- [ ] Treat injected file paths as post-run diagnostic metadata only; never include hidden file contents or hidden verifier source in prompts, model-visible workspaces, CSV/Markdown exports, or persisted details.
- [ ] Clean up injected hidden files after evaluation when practical; if cleanup is skipped, document that injection happens only after model execution.

Implementation notes:

- Prefer composing or wrapping `TestEvaluator(testPath: verifier.testPath)` after injecting files, so JSON reporter parsing stays in one place.
- Use the same `ctx.task.isFlutter ? 'flutter' : 'dart'` command choice as the existing test evaluator.
- Ensure every injected relative path stays inside `ctx.workDir` and reject absolute paths or `..` traversal.
- For the MVP, use one hidden verifier per converted task and expose it as evaluator ID `hidden_test`. If multiple hidden verifiers are added later, make evaluator IDs unique before widening usage.

## Task 3: Add reference solution support

- [ ] Add a `ReferenceSolution` representation.
- [ ] Support either:
  - full replacement files for codegen tasks;
  - patch files for future agentic tasks.
- [ ] Add helper logic to prepare a reference workspace.
- [ ] Run existing evaluators and hidden evaluators against reference workspaces.
- [ ] For the Phase 1 MVP, implement full replacement files first and leave patch application behind an explicit TODO for Phase 2.
- [ ] Apply the same workspace-relative path-safety checks to reference replacement file targets.
- [ ] For converted codegen tasks, make the visible `generatedCodePath` fixture an intentionally incomplete or buggy baseline, and store the current known-good implementation as the full-file `ReferenceFileSolution`.
- [ ] When QA needs "public evaluators", partition `task.evaluatorsFor(config)` to exclude `HiddenTestEvaluator`/`hidden_test`; run hidden verifiers explicitly from `task.hiddenVerifiers` after the public evaluator pass.

Reference workspace sequence:

1. create workdir from visible fixtures only;
2. apply reference replacement files;
3. run `WorkdirManager.prepare`;
4. run public evaluators, excluding `HiddenTestEvaluator`;
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
- [ ] Use `WorkdirManager.createTaskWorkdir(..., generatedCode: null, ...)` for the baseline workspace so QA validates the visible fixture baseline before any model output.

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

For each converted task:

- [ ] keep public smoke tests visible;
- [ ] move stronger behavioral checks to hidden verifier files;
- [ ] add a reference solution;
- [ ] add task QA expectations.
- [ ] append `HiddenTestEvaluator` to `evaluatorsFor` only for the converted task after `TestEvaluator`, leaving all legacy task evaluator lists unchanged.

Specific conversion notes:

- `ui.profile_card`
  - Visible fixture `lib/profile_card.dart` should be a skeleton or incomplete implementation that fails the hidden verifier without model output.
  - Preserve a small visible smoke test in `test/profile_card_test.dart` for rendering the name/handle and the follow button.
  - Add hidden tests in `test/_hidden/profile_card_hidden_test.dart` for the full behavior: `Card`/horizontal layout shape, fallback avatar initial when `avatarUrl` is absent, `NetworkImage` use when present, optional bio rendering/omission, follow/following button text and callback, and `Semantics(label: "<name> <handle>")`.
  - Store the current complete implementation as the reference replacement for target path `lib/profile_card.dart`.
- `bug.async_race_condition`
  - Visible fixture `lib/search_controller.dart` should be the buggy baseline that allows stale async search results to overwrite fresh ones.
  - Preserve a small visible smoke test in `test/search_controller_test.dart` for a simple non-overlapping query result.
  - Add hidden tests in `test/_hidden/search_controller_hidden_test.dart` for slow-then-fast overlap, three rapid successive queries, non-overlapping emissions, and disposal before an in-flight search completes.
  - Store the current generation-token implementation as the reference replacement for target path `lib/search_controller.dart`.

## Task 6: MVP storage/reporting integration

- [ ] Add `hidden_test` to hard-coded CSV/Markdown export score columns.
- [ ] Include hidden-verifier evaluator output in run details.
- [ ] Show hidden verifier as a primary correctness evaluator in the task run page.
- [ ] Add `hidden_test` to `lib/analytics/dimensions.dart` correctness evaluator IDs so hidden pass/fail contributes to intelligence/reliability views.
- [ ] Keep database migration for task version/track optional in Phase 1; Phase 4 makes these persistent leaderboard dimensions.
- [ ] Do not add a database migration for Phase 1 unless a later implementation step proves it is required; `Evaluations` already stores arbitrary evaluator IDs and JSON details.

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

The task QA test should execute both converted tasks and assert:

- baseline hidden verification fails;
- reference public evaluators pass;
- reference hidden verification passes;
- hidden verification passes 3 repeated runs;
- a legacy task without hidden verifier metadata still has empty hidden/reference defaults and its evaluator list is unchanged.

## Risks

- Hidden tests stored as Flutter assets are still in the repo, so this improves runtime hiding but not public contamination.
- Some current prompts explicitly mention visible tests; converted tasks should become more behavior-focused.
- Hidden verifier failures must be easy to inspect without leaking hidden test source into model prompts.
- Asset declarations in `pubspec.yaml` can reveal hidden file paths; this is acceptable for the local MVP but should be called out in task QA output.
- The current `CompileEvaluator` uses `analyze --fatal-infos`, so hidden verifier compile failures should be surfaced through `HiddenTestEvaluator` details rather than relying on compile-only results.

## Exit criteria

Phase 1 is complete when:

- `ui.profile_card` and `bug.async_race_condition` can be run normally through the existing single-shot flow;
- both converted tasks include `hidden_test` results in stored evaluations, run details, CSV/Markdown exports, and correctness dimensions;
- hidden tests are absent from the initial workdir and injected only during grading or task QA verification;
- path traversal tests cover hidden verifier injection and reference replacement;
- task QA catches broken baseline/reference/verifier states for both converted tasks;
- legacy tasks with no hidden verifier metadata still compile, keep their default metadata, and run with their existing evaluator lists.

Rollback/compatibility:

- Because all `BenchmarkTask` additions are default getters, legacy tasks can be restored by removing hidden verifier/reference overrides from converted task classes.
- If hidden evaluator rollout causes issues, remove `HiddenTestEvaluator` from converted tasks while leaving the additive metadata in place.

## Out of scope / follow-ups

- Convert `test.todo_input` after the MVP evaluator path is stable.
- Add patch-based reference solutions for agentic tasks in Phase 2.
- Move task artifacts out of Flutter assets or out of the public repository for stronger contamination resistance.
