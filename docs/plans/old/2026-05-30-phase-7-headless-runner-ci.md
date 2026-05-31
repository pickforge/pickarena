# Phase 7 — Headless Runner and CI Smoke Implementation Plan

> **Status:** Draft plan.
> **Parent spec:** `docs/specs/2026-05-29-flutter-benchmark-v2-design.md`
> **Dependencies:** Builds on Phase 6 run provenance and reproducible export bundles.

## Goal

Add a non-GUI smoke path that exercises the benchmark runner, provenance capture, persistence, and Phase 6 bundle export in a CI-friendly way.

Phase 7 should answer:

> Can this repository validate a tiny benchmark run end-to-end without launching the desktop UI, using no external API keys, no network, and no real Factory Droid execution?

## Success criteria

- A headless smoke runner can execute a deterministic local benchmark run without opening the app UI.
- The smoke path uses a fake/local provider and a tiny codegen task; it never calls network APIs or `droid`.
- The run persists task-run rows, evaluator rows, and a non-null run provenance snapshot.
- The run exports a Phase 6 bundle with `manifest.json`, `run_results.v1.json`, `results.csv`, `report.md`, `checksums.json`, and response artifacts.
- The bundle manifest embeds provenance and has no legacy-provenance warning.
- The smoke command is CI-friendly and deterministic.
- Existing UI flows, real provider runs, and agentic Droid runs are unchanged.

## Current code anchors

- `lib/runner/run_bloc.dart` already drives benchmark execution and captures Phase 6 provenance before workers start.
- `lib/runner/run_event.dart` and `lib/runner/start_run_config.dart` model run inputs.
- `lib/storage/dao/run_dao.dart` and `lib/storage/run_summary.dart` persist and reload completed runs.
- `lib/export/artifact_bundle.dart` exports deterministic bundles.
- `test/runner/run_bloc_test.dart` already contains fake providers/tasks that prove `RunBloc` can be used without UI.
- `test/export/artifact_bundle_test.dart` already proves bundle shape/checksum behavior.

## Important constraint

Do not add a standalone `dart run` CLI in the MVP.

The current package graph imports Flutter-only libraries through `RunBloc`, `AppDatabase`, `path_provider`, and UI dependencies, so a plain Dart VM command cannot safely import the runner stack. Phase 7 should expose a reusable headless runner service and validate it through a `flutter test` smoke command. A pure-Dart CLI can be a later phase after storage/export code is split from Flutter plugin imports.

## Scope

Use Phase 7 for:

- local CI smoke validation;
- proving benchmark execution works without the desktop UI;
- proving provenance and bundle export work together;
- giving contributors one narrow command to run when changing runner/export code.

Do not use Phase 7 for:

- real Factory Droid agentic benchmark execution in CI;
- web benchmark execution;
- hosted benchmark orchestration;
- a public leaderboard;
- long corpus runs;
- network/API-provider validation.

## Task 1: Add headless runner service

- [ ] Create `lib/headless/headless_benchmark_runner.dart`.
- [ ] Define `HeadlessBenchmarkConfig` with:
  - run ID/name;
  - tasks;
  - providers;
  - models by provider;
  - evaluator config;
  - evaluator weights;
  - max concurrency;
  - trials per task;
  - database/DAO dependencies;
  - injectable `WorkdirManager` or prepare hook, so tests can use a no-op prepare path instead of `dart/flutter pub get`;
  - bundle output parent directory;
  - clock and ID generator hooks for deterministic tests;
  - deterministic provenance/export hooks: `RunProvenanceEnvironmentProvider`, export `environmentProvider`, export `appVersionProvider`, and explicit `allowedTrajectoryRoots`.
- [ ] Define `HeadlessBenchmarkResult` with:
  - run ID;
  - final `RunSummary`;
  - exported bundle directory;
  - bundle warning count;
  - total task-run/evaluation counts.
- [ ] Internally drive `RunBloc` with `StartRun`; listen to `RunBloc.stream` before dispatch, capture the terminal state, enforce a timeout, and close the bloc after completion or failure.
- [ ] Treat `RunInProgress` with `failed.isNotEmpty`, `pending == 0`, and `active.isEmpty` as a headless failure; surface the failed combo error and do not export a bundle.
- [ ] After `RunCompleted`, call `runDao.loadSummary(runId)` and fail if it returns null.
- [ ] Export the completed `RunSummary` using `exportRunBundle` to `Directory(p.join(bundleOutputParent.path, runBundleDirectoryName(runId)))`.
- [ ] Pass explicit `allowedTrajectoryRoots`, `environmentProvider`, and `appVersionProvider` to `exportRunBundle` in the headless path; smoke tests must not rely on default `path_provider`, `git`, or `flutter --version` capture.
- [ ] Keep the service injectable; do not construct real provider settings or API-backed providers inside it.
- [ ] Dispose/close `RunBloc` after completion.

## Task 2: Add deterministic smoke fixtures

- [ ] Add test-only fake provider and no-op-prepare workdir manager under `test/support/`, with the smoke task/test under `test/headless/`.
- [ ] The fake provider returns one deterministic Dart code block and static token/latency metadata.
- [ ] The smoke task uses a minimal fixture and pure in-process evaluators that pass only when the generated code is present.
- [ ] The smoke task, evaluators, and prepare path must not run `flutter`, `dart`, network, or external processes.
- [ ] Use an in-memory Drift database, temporary workdir/output directories, fixed provenance/export providers, fixed app version, and explicit allowed trajectory roots.

## Task 3: Add headless smoke test

- [ ] Create `test/headless/headless_benchmark_runner_test.dart`.
- [ ] Run the headless service with one task, one fake provider, one model, one trial.
- [ ] Assert:
  - result state completed;
  - final `RunSummary` is loaded and non-null;
  - one task run persisted;
  - evaluator rows persisted;
  - run provenance is non-null and includes normalized model/task/provider data;
  - bundle directory exists at `p.join(outputParent.path, runBundleDirectoryName(runId))`;
  - bundle manifest includes provenance and no `missing_run_provenance` warning;
  - response artifact exists;
  - bundle checksums include `manifest.json`, `run_results.v1.json`, `results.csv`, `report.md`, and the response artifact;
  - no absolute trajectory path appears in CSV/Markdown/manifest normal fields.
- [ ] Keep test runtime small enough for every PR.

## Task 4: Add CI smoke workflow

- [ ] Create `.github/workflows/ci.yml`.
- [ ] Use Flutter stable setup.
- [ ] Run:
  - `flutter pub get`;
  - `dart format --set-exit-if-changed lib/headless test/headless test/support .github/workflows`;
  - `flutter analyze`;
  - `flutter test test/headless/headless_benchmark_runner_test.dart`.
- [ ] Do not run real providers, real Droid, or long full-suite jobs in this first CI workflow.
- [ ] Keep the workflow dependency-free except for Flutter setup and repository checkout.

## Task 5: Add tests and guardrails

- [ ] Unit-test headless runner success.
- [ ] Unit-test headless runner failure, including failed-combo `RunInProgress`, surfaces a useful error and does not export a misleading bundle.
- [ ] Unit-test fake provider is deterministic and does not require settings/API keys.
- [ ] Unit-test output parent collisions are handled by Phase 6 no-overwrite behavior.
- [ ] Add a small test or assertion documenting why plain `dart run` CLI is out of scope until Flutter plugin imports are split.

## Out of scope for MVP

- Plain `dart run` CLI.
- Shell wrapper scripts.
- Real Droid/agentic CI runs.
- Running the full Phase 3 corpus in CI.
- Benchmark result comparison thresholds across commits.
- Uploading bundles as CI artifacts.
- GitHub Pages/public leaderboard publishing.
- Refactoring `AppDatabase`/export code to be pure Dart.

## Validation

Required:

```sh
flutter pub get
dart format --set-exit-if-changed lib/headless test/headless test/support .github/workflows
flutter analyze
flutter test test/headless/headless_benchmark_runner_test.dart
flutter test test/runner/run_bloc_test.dart
flutter test test/export/
flutter test
```

## Risks and mitigations

- **False confidence from fake smoke.** Keep this explicitly as a smoke test, not a substitute for full benchmark runs.
- **CI cost/time creep.** Run only the headless smoke test in workflow MVP; full suite remains local/pre-merge validation.
- **Flutter-only imports block plain Dart CLI.** Defer CLI until storage/export/runner dependencies are split from Flutter plugins.
- **Temporary artifact leakage.** Use temp directories and assert no hidden/reference/workspace files are exported.
- **Bundle overwrite risk.** Reuse Phase 6 no-overwrite behavior and test collisions.
