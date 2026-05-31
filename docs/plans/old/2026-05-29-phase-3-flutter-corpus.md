# Phase 3 — Flutter-Specific Task Corpus Implementation Plan

> **Status:** Draft plan.
> **Parent spec:** `docs/specs/2026-05-29-flutter-benchmark-v2-design.md`
> **Dependencies:** Phase 1 hidden verifiers; Phase 2 agentic track for multi-file tasks.

## Goal

Build a high-quality original task corpus that reflects real Flutter development work rather than small single-file exercises.

## Success criteria

- Phase 3 MVP delivers 10 named, reviewed seed tasks plus the metadata, UI, and QA support needed to run them safely.
- Scaling to 25+ tasks is a post-MVP follow-up under Task 6, with a path to 50–100.
- Tasks cover multiple Flutter domains: UI, state, navigation, testing, platform/build, performance, and maintainability.
- Each task has hidden behavioral verification and a reference solution.
- Each task passes the Phase 1 QA gate.
- Tasks are grouped by difficulty and category for leaderboard filtering.
- The initial seed corpus has all 10 reviewed tasks passing corpus QA before scaling to 25+.

## Current code anchors

- Current task definitions live under `lib/tasks/**` and are registered in `lib/tasks/task_catalog.dart`.
- Existing categories are limited to `uiFromSpec`, `stateManagement`, `bugFix`, `refactor`, `widgetTesting`, and `planningAndExecution`.
- Fixtures are currently loaded through `FixtureLoader` from asset paths listed in `pubspec.yaml`.
- Codegen tasks currently assume one `generatedCodePath`; tasks that need multi-file edits should be marked agentic.
- `ReferencePatchSolution` still throws in the current codebase, so Phase 3 MVP seed tasks must use executable `ReferenceFileSolution` mappings unless patch-reference application is implemented and covered by QA first.

## Task design principles

Tasks should be:

- original, not copied from public fixes;
- natural-language developer requests;
- behavior-focused, not implementation-prescriptive;
- solvable in multiple valid ways;
- realistic enough to require project exploration;
- bounded enough to run locally without fragile external services;
- Flutter-specific enough that generic SWE tasks would miss the skill being measured.

Every task prompt must describe user-visible behavior and constraints, not hidden test implementation details. Verifiers should assert behavior through public APIs, widget trees, semantics, or CLI outcomes rather than private helper names.

## Corpus categories

### UI and widgets

- responsive layout across widths;
- dark/light theme support;
- accessibility semantics;
- RTL/localization behavior;
- golden visual correctness;
- animation behavior;
- widget decomposition without behavior change.

### State management

- BLoC/Cubit event ordering;
- Riverpod async invalidation;
- Provider/ChangeNotifier lifecycle issues;
- optimistic update rollback;
- cancellation/debounce race conditions;
- persistence/cache consistency.

### Navigation

- `go_router` auth redirects;
- deep links;
- nested navigation;
- browser back behavior on web;
- route-scoped state cleanup.

### Testing

- widget test authoring;
- golden test authoring;
- integration-test repair;
- flaky test repair;
- mutation-style test quality checks.

### Platform and build

- `build_runner` generated-code workflows;
- plugin/platform-channel mock behavior;
- Android/iOS permission config;
- flavor/environment config;
- dependency migration.

### Performance and quality

- unnecessary rebuilds;
- list virtualization;
- image loading/caching;
- controller/listener leaks;
- large-widget refactors;
- maintainability-focused code review tasks.

## Task artifact template

Each new task should include:

```text
tasks_v2/<category>/<task_id>/
  task.yaml
  instruction.md
  workspace/
  public_tests/
  hidden_tests/
  reference/
    files/ or solution.patch
    notes.md
  author_review.md
```

If the repo keeps Dart-defined tasks during transition, mirror this structure in code and assets.

During the transition, prefer Dart-defined tasks for the first seed corpus so the runner can execute them without a manifest loader. File-based artifacts can be introduced after the metadata and QA model stabilizes.

For the Phase 3 MVP, every admitted task must expose an executable Dart `referenceSolution`. Use `ReferenceFileSolution` with one or more full-file mappings for seed tasks. Do not admit tasks that only have `solution.patch`/`ReferencePatchSolution` until patch application is implemented and `TaskQaRunner` proves baseline-fail/reference-pass for those tasks.

## Task 1: Create authoring guidelines

This task is documentation-only; it should not require Dart code changes or Dart tests.

- [ ] Define required task metadata.
- [ ] Define prompt style rules.
- [ ] Define verifier style rules.
- [ ] Define reference solution requirements.
- [ ] Define difficulty labels.
- [ ] Define task review checklist.

Likely file:

- `docs/specs/2026-05-29-flutter-task-authoring-guide.md`

Minimum checklist:

- prompt does not mention hidden verifier names or hidden file paths;
- baseline fails the hidden verifier for the intended reason;
- reference solution passes public, hidden, analyze, and task QA checks;
- hidden verifier accepts at least two plausible valid implementation styles when applicable;
- task has a difficulty, track, tags, timeout, and platform requirement.

## Task 2: Add corpus category metadata

- [ ] Expand `Category` or add a richer `TaskTag` model.
- [ ] Support multiple tags per task.
- [ ] Add difficulty and track filters.
- [ ] Update leaderboard filters and task detail views.
- [ ] Keep existing `Category` values stable for old task IDs; add tags/difficulty as additive metadata.
- [ ] Add tests for tag filtering with legacy tasks that have empty/default tags.

MVP metadata model:

- Add `enum TaskTag` using the suggested tag list below.
- Add `enum TaskDifficulty { unspecified, easy, medium, hard }`; legacy tasks default to `unspecified`, and new seed tasks must choose `easy`, `medium`, or `hard`.
- Add `enum TaskPlatform { linux, macos, windows, web, android, ios }`; an empty requirement set means host-agnostic.
- Extend `BenchmarkTask` with safe default getters:
  - `Set<TaskTag> get tags => const {};`
  - `TaskDifficulty get difficulty => TaskDifficulty.unspecified;`
  - `Duration? get timeout => null;`
  - `Set<TaskPlatform> get platformRequirements => const {};`
- Treat tags, difficulty, timeout, and platform requirements as runtime task metadata in the MVP, not new Drift columns. Existing `taskVersion` and `benchmarkTrack` persistence remains authoritative for recorded results; if metadata changes after results are recorded, bump the task `version`.
- Extend `TaskRegistry` with query helpers for tags, difficulty, track, and supported platform. Extend `LeaderboardFilter` with tag and difficulty filters by converting registry matches to task IDs, preserving legacy category filtering as a fallback.

Suggested tags:

```text
ui
state_bloc
state_riverpod
navigation
testing
golden
accessibility
localization
platform
build_codegen
performance
refactor
bugfix
planning
code_review
```

## Task 3: Build seed corpus

Create the 10 named initial tasks before scaling. Land Phase 3a first, then Phase 3b after metadata and corpus QA are working.

| Phase | Suggested ID | Task | Track | Fixture budget | Admission notes |
|---|---|---|---|---|---|
| 3a | `state.bloc_debounce_cancellation` | BLoC debounce/cancellation bug | `codegen` | ≤15 source/test files, ≤300 KB | Single generated BLoC/controller file. |
| 3a | `state.riverpod_stale_cache` | Riverpod stale cache bug | `codegen` | ≤15 files, ≤300 KB | Single provider/repository file when practical. |
| 3a | `ui.responsive_profile_golden` | Responsive profile screen with golden or behavioral layout tests | `codegen` | ≤15 files, ≤300 KB | Mark platform requirements if true golden files are platform-sensitive. |
| 3a | `ui.localization_rtl_behavior` | Localization + RTL widget behavior | `codegen` | ≤15 files, ≤300 KB | Keep ARB/generated localization scaffolding minimal. |
| 3a | `testing.flaky_widget_test_repair` | Flaky widget test repair | `codegen` | ≤15 files, ≤300 KB | Generated path can be the repaired test file. |
| 3a | `performance.rebuild_reduction` | Performance/rebuild reduction task | `codegen` | ≤15 files, ≤300 KB | Verify observable rebuild count/performance smoke behavior. |
| 3b | `navigation.go_router_auth_redirect` | Auth redirect with `go_router` | `agentic` | ≤25 files, ≤500 KB | Multi-file edits allowed; reference must still use `ReferenceFileSolution` until patch refs are supported. |
| 3b | `build.codegen_model_migration` | `build_runner` generated model migration | `agentic` | ≤25 files, ≤500 KB | Required commands include code generation; generated outputs must be covered by the reference solution. |
| 3b | `platform.platform_channel_mock` | Platform-channel mock bug | `agentic` | ≤25 files, ≤500 KB | Prefer mocked host-platform behavior; mark platform requirements if host-sensitive. |
| 3b | `refactor.large_screen_preserve_behavior` | Large screen refactor preserving behavior | `agentic` | ≤25 files, ≤500 KB | Hidden tests should assert behavior, not decomposition style. |

Each task must include:

- [ ] natural prompt;
- [ ] visible workspace;
- [ ] public smoke tests;
- [ ] hidden behavioral tests;
- [ ] reference solution;
- [ ] QA report.

Track assignment:

- Codegen-suitable seed tasks should have a single `generatedCodePath` and can be added immediately after Phase 1.
- Agentic seed tasks may include multiple changed files, generated code workflows, or package migrations and should use the Phase 2 agentic track.
- Every MVP seed task, including agentic tasks, must be admissible by corpus QA with current executable reference support. If a task requires a patch-only reference, defer it to Task 6 or first add patch-reference support with tests.
- Do not force naturally multi-file work into the codegen track only to fit the old runner.

## Task 4: Add corpus QA automation

- [ ] Run Phase 1 task QA over every corpus task.
- [ ] Add `test/runner/corpus_task_qa_test.dart` that iterates the registered v2 corpus tasks and runs `TaskQaRunner` for each task.
- [ ] Produce a local report sorted by task/category/difficulty.
- [ ] Fail CI or local validation when any task is broken/flaky.
- [ ] Track baseline fail/reference pass status.
- [ ] Store QA report artifacts under `build/corpus_qa/`, outside agent workspaces, and exclude them from task fixtures.
- [ ] Mark golden and platform-sensitive tasks with platform requirements so they can be skipped or filtered when unsupported.
- [ ] Apply task `timeout` metadata in QA/evaluator execution where supported; otherwise surface timeout requirements in the QA report.
- [ ] Unsupported-platform skips must be explicit in the QA report and must not hide broken tasks on supported hosts.

## Task 5: Add corpus documentation in-app

- [ ] Show task category, tags, difficulty, track, and version in task selection.
- [ ] Add category/difficulty filters in `NewRunPage`.
- [ ] Show task metadata in run details and leaderboard drill-down.
- [ ] Show clear labels for `Codegen` vs `Agentic` tasks so users do not compare tracks accidentally.

MVP UI scope is limited to existing screens:

- `NewRunPage`: add track, difficulty, and tag filtering for task selection; show disabled/skip labels for unsupported-platform tasks.
- Task selection cards/rows: show category, tags, difficulty, track, version, and slow/platform-sensitive markers.
- Run details and task-run details: show the task metadata snapshot available from the registry for the recorded task ID/version.
- Leaderboard filters: add difficulty and tag controls using registered task IDs; keep existing category and track filters working for legacy results.
- No new in-app documentation pages are required for the MVP.

## Task 6: Scale to 25+ tasks

Post-MVP follow-up after the 10 seed tasks pass corpus QA:

- [ ] Add at least 3–5 tasks per major category.
- [ ] Keep median task runtime reasonable.
- [ ] Avoid over-representing any one state-management library.
- [ ] Include both app-level and package-level tasks.
- [ ] Cap or tag slow tasks so large sweeps can exclude them.
- [ ] Keep task IDs stable once results have been recorded; bump task `version` for behavior/verifier changes.

## Validation

Run:

```sh
flutter analyze
flutter test
```

Corpus QA:

```sh
flutter test test/runner/corpus_task_qa_test.dart
flutter test test/tasks/
```

When task QA CLI exists, run the full corpus QA command defined in Phase 1.

## Risks

- High-quality task authoring is the most labor-intensive part of the benchmark.
- Flutter golden tests can be sensitive to SDK/font/platform differences.
- Realistic workspaces may increase runtime and storage size.
- Public repository-derived tasks can create contamination risk if copied too closely from real issues.
- Overweighting one Flutter architecture or state library can bias rankings toward familiar patterns rather than general Flutter skill.
- Hidden verifiers that are too implementation-specific will undercount valid solutions.

## Exit criteria

Phase 3 is complete when the benchmark has a reviewed seed corpus of realistic Flutter tasks that pass task QA and produce useful separation between models/agents.

Rollback/compatibility:

- New corpus tasks should be registered one category at a time so broken tasks can be removed from `task_catalog.dart` without affecting existing runs.
- Task metadata changes should be additive; if a tag/difficulty filter breaks, legacy category filtering should continue to work.
