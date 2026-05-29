# Phase 3 — Flutter-Specific Task Corpus Implementation Plan

> **Status:** Draft plan.
> **Parent spec:** `docs/specs/2026-05-29-flutter-benchmark-v2-design.md`
> **Dependencies:** Phase 1 hidden verifiers; Phase 2 agentic track for multi-file tasks.

## Goal

Build a high-quality original task corpus that reflects real Flutter development work rather than small single-file exercises.

## Success criteria

- At least 25 v2 tasks exist, with a path to 50–100.
- Tasks cover multiple Flutter domains: UI, state, navigation, testing, platform/build, performance, and maintainability.
- Each task has hidden behavioral verification and a reference solution.
- Each task passes the Phase 1 QA gate.
- Tasks are grouped by difficulty and category for leaderboard filtering.
- The initial seed corpus has at least 10 reviewed tasks before scaling to 25+.

## Current code anchors

- Current task definitions live under `lib/tasks/**` and are registered in `lib/tasks/task_catalog.dart`.
- Existing categories are limited to `uiFromSpec`, `stateManagement`, `bugFix`, `refactor`, `widgetTesting`, and `planningAndExecution`.
- Fixtures are currently loaded through `FixtureLoader` from asset paths listed in `pubspec.yaml`.
- Codegen tasks currently assume one `generatedCodePath`; tasks that need multi-file edits should be marked agentic and wait for Phase 2.

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
    solution.patch
    notes.md
  author_review.md
```

If the repo keeps Dart-defined tasks during transition, mirror this structure in code and assets.

During the transition, prefer Dart-defined tasks for the first seed corpus so the runner can execute them without a manifest loader. File-based artifacts can be introduced after the metadata and QA model stabilizes.

## Task 1: Create authoring guidelines

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

Create 10 initial tasks before scaling:

- [ ] auth redirect with `go_router`;
- [ ] BLoC debounce/cancellation bug;
- [ ] Riverpod stale cache bug;
- [ ] responsive profile screen with golden tests;
- [ ] localization + RTL widget behavior;
- [ ] build_runner generated model migration;
- [ ] platform-channel mock bug;
- [ ] flaky widget test repair;
- [ ] large screen refactor preserving behavior;
- [ ] performance/rebuild reduction task.

Each task must include:

- [ ] natural prompt;
- [ ] visible workspace;
- [ ] public smoke tests;
- [ ] hidden behavioral tests;
- [ ] reference solution;
- [ ] QA report.

Track assignment:

- Codegen-suitable seed tasks should have a single `generatedCodePath` and can be added immediately after Phase 1.
- Agentic seed tasks may include multiple changed files, generated code workflows, or package migrations and should wait for Phase 2.
- Do not force naturally multi-file work into the codegen track only to fit the old runner.

## Task 4: Add corpus QA automation

- [ ] Run Phase 1 task QA over every corpus task.
- [ ] Produce a local report sorted by task/category/difficulty.
- [ ] Fail CI or local validation when any task is broken/flaky.
- [ ] Track baseline fail/reference pass status.
- [ ] Store QA report artifacts outside agent workspaces and exclude them from task fixtures.
- [ ] Mark golden and platform-sensitive tasks with platform requirements so they can be skipped or filtered when unsupported.

## Task 5: Add corpus documentation in-app

- [ ] Show task category, tags, difficulty, track, and version in task selection.
- [ ] Add category/difficulty filters in `NewRunPage`.
- [ ] Show task metadata in run details and leaderboard drill-down.
- [ ] Show clear labels for `Codegen` vs `Agentic` tasks so users do not compare tracks accidentally.

## Task 6: Scale to 25+ tasks

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
