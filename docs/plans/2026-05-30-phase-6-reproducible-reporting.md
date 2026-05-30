# Phase 6 — Run Provenance and Reproducible Reporting Implementation Plan

> **Status:** Draft plan.
> **Parent spec:** `docs/specs/2026-05-29-flutter-benchmark-v2-design.md`
> **Dependencies:** Builds on Phases 1–5 evidence capture, reliable leaderboard metrics, and human review exports.

## Goal

Add run-level provenance capture plus a local, deterministic reporting bundle that makes a benchmark run auditable after the fact.

Phase 6 should answer:

> Can a completed run explain exactly what was benchmarked, how it was configured, and what artifacts support the reported scores without relying on the app database?

## Success criteria

- New runs persist a versioned, redacted run-level provenance snapshot.
- Provenance captures normalized run config, selected tasks/providers/models, evaluator weights, judge config, combo matrix, and best-effort environment metadata.
- A completed run can be exported as a directory bundle from Run Details.
- The bundle has a stable layout and versioned `manifest.json`.
- The bundle includes persisted provenance when available and warns for legacy runs without it.
- CSV and Markdown reports are included through bundle-safe exporter paths that reuse existing export logic while keeping standalone CSV/Markdown behavior unchanged.
- Task-run/evaluation data is emitted as stable machine-readable JSON.
- Patch/response/trajectory artifacts are copied when safely available.
- Missing or truncated artifacts become manifest warnings, not export failures.
- Checksums are emitted for all generated bundle files.
- Hidden verifier sources, reference solutions, and task authoring notes are not exported.
- Existing correctness, reliable leaderboard, and human-review behavior are unchanged.

## Current code anchors

- `lib/storage/run_summary.dart` loads a run plus task runs and evaluations.
- `lib/runner/start_run_config.dart` carries selected tasks/providers/models, evaluator config, weights, reference-plan mode, concurrency, and trial count.
- `lib/runner/run_bloc.dart` normalizes models and expands the authoritative task/provider/model/trial combo matrix in `_onStart`.
- `lib/storage/database.dart` currently has `Runs` schema version 6 and is the right place for nullable run-level provenance.
- `lib/storage/dao/run_dao.dart` creates runs through `startRun`.
- `lib/export/csv_exporter.dart` and `lib/export/md_exporter.dart` already serialize run summaries.
- `lib/export/run_summary_leaderboard_summary.dart` already computes reliable aggregate rows for exports.
- `lib/ui/pages/run_details_page.dart` already exposes CSV/Markdown export actions.
- `lib/storage/database.dart` stores task-run evidence including task version, track, harness, primary pass, failure tag, bounded `patchText`, and `trajectoryLogPath`.
- `lib/runner/agentic_run_orchestrator.dart` and `lib/core/patch_capture.dart` capture agentic patches.

## Scope

Phase 6 is local provenance and reporting/export infrastructure. It is not a benchmark execution backend.

Use it for:

- sharing reproducible run evidence;
- auditing run configuration after settings or task metadata change;
- auditing rankings and failure tags;
- preserving the exact exported view of a run;
- comparing exported reports outside the app.

Do not use it for:

- hosted benchmark execution;
- browser-based agent runs;
- remote artifact upload;
- rerunning benchmarks from a manifest;
- archiving full workspaces;
- exporting hidden tests, reference solutions, or private authoring assets.

## Run provenance snapshot v1

Persist one redacted JSON snapshot on `Runs.provenanceJson`.

Capture in `RunBloc._onStart`, before workers start, in this order:

1. normalize/dedupe selected models and expand the task/provider/model/trial combo matrix;
2. ensure all selected tasks are loaded;
3. resolve/upsert reference plans and rebuild combos with final `planId`/`planMarkdown`;
4. build and persist the provenance snapshot;
5. enqueue workers and start task execution.

New run rows may be created before or after the snapshot is built, but if `startRun` happens first then `RunDao.updateRunProvenance` must complete before workers are queued. For `existingRunId`, preserve an existing non-null provenance snapshot; if it is null, backfill the snapshot before new workers start. The snapshot should be run-level only; do not add per-task-run provenance in the MVP.

Recommended shape:

```json
{
  "schemaVersion": 1,
  "capturedAt": "2026-05-30T00:00:00.000Z",
  "runId": "run-123",
  "config": {
    "name": "local smoke",
    "maxConcurrency": 4,
    "trialsPerTask": 3,
    "useReferencePlan": false,
    "existingRunId": null,
    "modelsByProvider": {
      "droid": ["factory-droid"]
    },
    "evaluatorWeights": {
      "compile": 0.2,
      "hidden_test": 1.0
    },
    "judge": {
      "providerId": "openai",
      "modelId": "gpt-5.5"
    }
  },
  "providers": [
    {
      "id": "droid",
      "displayName": "Droid",
      "mode": "agent",
      "secretsRedacted": true
    }
  ],
  "tasks": [
    {
      "id": "flutter.some_task",
      "version": 1,
      "category": "bugFix",
      "track": "agentic",
      "tags": ["bug", "state"],
      "difficulty": "medium",
      "timeoutMs": 1800000,
      "platformRequirements": ["linux"],
      "generatedCodePath": "lib/example.dart",
      "isFlutter": true,
      "promptSha256": "...",
      "publicFixtureDigests": {
        "pubspec.yaml": "..."
      },
      "hiddenAssetsExcluded": true
    }
  ],
  "combos": [
    {
      "index": 0,
      "taskId": "flutter.some_task",
      "providerId": "droid",
      "modelId": "factory-droid",
      "trialIndex": 0,
      "planId": null
    }
  ],
  "environment": {
    "hostPlatform": "linux",
    "dartVersion": "unknown",
    "flutterVersion": "unknown",
    "gitCommit": "unknown",
    "gitDirty": null
  }
}
```

Rules:

- Persist hashes for prompts and public fixtures, not hidden verifier/reference contents.
- Include provider IDs/display names/modes and selected model IDs, never API keys or secret header values.
- Snapshot judge config only as `evaluatorConfig.judgeProvider?.id` and `evaluatorConfig.judgeModel`; never serialize a `ModelProvider`.
- Collect environment metadata with cached/best-effort calls and short timeouts; if unavailable, store `unknown`/`null` and continue.
- Legacy runs with null provenance remain valid but export with a warning.

## Bundle layout

Create one directory per exported run:

```text
dart_arena_run_<run_id>/
  manifest.json
  run_results.v1.json
  results.csv
  report.md
  checksums.json
  artifacts/
    responses/<task_run_id>.txt
    patches/<task_run_id>.patch
    trajectories/<task_run_id>.log
```

Rules:

- File names must be deterministic, sanitized, and collision-resistant; use a stable sanitized task-run ID plus a short digest when needed, and record the final relative path in the manifest.
- Rows and JSON arrays must use stable sorting, preferably task-run ID then evaluator ID. Apply the same sorted view before generating bundle CSV/Markdown.
- If an artifact cannot be emitted, keep exporting and record a warning.
- Do not include absolute local paths except in warnings where needed to explain missing user-local artifacts.

## Manifest v1

Add a versioned manifest model with:

- `schemaVersion`: `1`;
- `generatedAt`;
- run ID, name, started/completed timestamps;
- app/package version from `pubspec.yaml` or a build-time fallback;
- Drift schema version;
- export tool version/name;
- git commit and dirty flag when available;
- Flutter/Dart version when cheaply available;
- host OS and locale basics;
- task IDs, task versions, benchmark tracks, harness IDs, trial indexes;
- provider/model/task-run counts;
- evaluator IDs and aggregate pass/failure summaries;
- artifact file references;
- checksum file reference;
- warnings.

The manifest should include the persisted provenance snapshot when present, but scoring remains derived from persisted task runs and evaluations.

## Task 1: Add run provenance storage

- [ ] Add nullable `provenanceJson` to `Runs`; the table definition must include it for fresh databases.
- [ ] Bump Drift `schemaVersion` from 6 to 7.
- [ ] Add migration:
  - `if (from < 7) await m.addColumn(runs, runs.provenanceJson);`
- [ ] Regenerate `lib/storage/database.g.dart` with build runner.
- [ ] Update `RunDao.startRun` to accept optional provenance JSON.
- [ ] Add a `RunDao.updateRunProvenance` helper for post-`startRun` capture and `existingRunId` backfill.
- [ ] Add migration and DAO tests.

## Task 2: Build provenance capture

- [ ] Create `lib/runner/run_provenance.dart`.
- [ ] Build a pure provenance builder that accepts:
  - run ID;
  - `StartRun` event data;
  - normalized models;
  - expanded combos after reference-plan IDs are resolved;
  - evaluator weights from `RunBloc.weights`;
  - reference-plan mode;
  - best-effort environment provider.
- [ ] Capture after normalization, task loading, reference-plan resolution, and combo rebuilding, but before task execution starts.
- [ ] Hash task prompts and public fixture contents with SHA-256.
- [ ] Snapshot safe task metadata: ID, version, category, track, tags, difficulty, timeout, platform requirements, generated path, Flutter flag.
- [ ] Snapshot safe provider metadata: ID, display name, mode, selected models, and `secretsRedacted: true`.
- [ ] Snapshot judge provider/model from `EvaluatorConfig` as `judgeProvider?.id` and `judgeModel`, without serializing provider objects or secret data.
- [ ] Add tests proving API keys, extra header values, hidden verifier contents, and reference solution contents are not persisted.

## Task 3: Add bundle/export primitives

- [ ] Create `lib/export/run_manifest.dart`.
- [ ] Create `lib/export/json_exporter.dart`.
- [ ] Create `lib/export/artifact_bundle.dart`.
- [ ] Define immutable data structures for:
  - bundle result;
  - bundle warning;
  - manifest v1;
  - artifact descriptors.
- [ ] Reuse `RunSummary`, CSV, Markdown, and leaderboard summary code through a bundle-safe export path.
- [ ] Bundle CSV/Markdown must sort rows deterministically and replace raw `trajectoryLogPath` values with emitted relative artifact references or blanks; standalone CSV/Markdown exports must remain unchanged.
- [ ] Emit `run_results.v1.json` with task runs and evaluations in stable order.
- [ ] Include parsed run provenance in `manifest.json` when available.
- [ ] If `provenanceJson` is malformed, warn and continue exporting without embedding it.
- [ ] Warn when exporting a legacy run with no provenance.
- [ ] Add `crypto` as a direct dependency for SHA-256 hashing.

## Task 4: Implement artifact emission

- [ ] Write model responses to `artifacts/responses/<task_run_id>.txt` when available.
- [ ] Write bounded patch text to `artifacts/patches/<task_run_id>.patch` when available.
- [ ] Copy `trajectoryLogPath` to `artifacts/trajectories/<task_run_id>.log` only after canonicalizing the path and verifying it is a readable regular file under an allowlisted app-controlled run/log root.
- [ ] Reject symlinks, out-of-root paths, directories, and traversal attempts with warnings instead of copying.
- [ ] Record warnings for:
  - missing response text;
  - missing patch text for agentic runs;
  - unreadable trajectory paths;
  - suspected truncated patch text;
  - unsupported artifact kinds.
- [ ] Do not traverse directories from stored paths.
- [ ] Never copy hidden verifier files, reference solutions, fixtures, or full workspaces.

## Task 5: Add checksums

- [ ] Write all payload files and `manifest.json` first; `manifest.json` should reference only the checksum file path (`checksums.json`), not individual digest values.
- [ ] Compute SHA-256 for every emitted file except `checksums.json` after payloads and manifest are final.
- [ ] Include sorted relative paths and hex digests in `checksums.json`.
- [ ] Keep checksum ordering deterministic.
- [ ] Add tests that corrupting an expected digest would be detectable by comparing the digest in test code.

## Task 6: Wire Run Details UI

- [ ] Add `Export Bundle` beside CSV and Markdown on `RunDetailsPage`.
- [ ] Use `FilePicker.platform.getDirectoryPath()` to select a parent directory, then create `dart_arena_run_<run_id>` inside it.
- [ ] If the picker is cancelled, do nothing; if the target directory already exists, do not merge or overwrite it and show an error.
- [ ] Disable bundle export while a run is still in progress.
- [ ] Show success and warning counts in the snackbar.
- [ ] Keep CSV/Markdown behavior unchanged.

## Task 7: Add tests

- [ ] Unit-test provenance schema shape and redaction.
- [ ] Unit-test `RunBloc` provenance capture order for task loading, reference-plan IDs, normalized models, trials, weights, judge config, and task metadata.
- [ ] Unit-test `existingRunId` preserves existing provenance and backfills only when it is null.
- [ ] Unit-test Drift migration v7 and `RunDao.startRun` provenance persistence.
- [ ] Unit-test manifest v1 shape and stable ordering.
- [ ] Unit-test manifest includes provenance when present and warns when absent.
- [ ] Unit-test malformed provenance warns and does not fail bundle export.
- [ ] Unit-test JSON export for task runs/evaluations.
- [ ] Unit-test bundle CSV/Markdown use stable order and do not expose raw trajectory paths.
- [ ] Unit-test artifact bundle writes expected files.
- [ ] Unit-test checksum output.
- [ ] Unit-test missing, unreadable, symlink, and out-of-root trajectory paths produce warnings.
- [ ] Unit-test hidden/reference paths are not exported.
- [ ] Widget-test `RunDetailsPage` exposes `Export Bundle` only for completed runs.

## Out of scope for MVP

- Per-task-run rendered prompt snapshots.
- Full provider request-body parameter snapshots.
- Provider API keys, secret header values, tokens, or credentials.
- Retry/attempt history preservation.
- CLI/headless export command.
- CI workflow files.
- Remote upload or public leaderboard publishing.
- Reconstructing/rerunning benchmarks from exported manifests.
- Golden/screenshot artifacts unless they become persisted task-run evidence later.
- Bradley-Terry/Elo report integration beyond existing Phase 5 quality ranking UI.

## Validation

Required:

```sh
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed lib/runner lib/storage lib/export test/runner test/storage test/export test/ui/pages/run_details_page_test.dart
flutter analyze
flutter test test/storage/database_migration_test.dart
flutter test test/storage/run_dao_test.dart
flutter test test/runner/run_bloc_test.dart
flutter test test/export/
flutter test test/ui/pages/run_details_page_test.dart
flutter test
```

## Risks and mitigations

- **Artifact paths may be stale.** Treat missing paths as warnings and keep the bundle valid.
- **Patch text can be bounded.** Mark suspected truncation in the manifest so consumers do not treat it as a full patch.
- **Environment metadata can be slow or unavailable.** Gather it best-effort and record `unknown` rather than failing export.
- **Local paths can leak private machine details.** Store relative bundle paths for emitted artifacts; keep original absolute paths out of normal manifest fields.
- **Provider settings can contain secrets.** Capture only safe provider metadata and selected model IDs; never serialize API keys or header values.
- **Hidden verifier leakage would undermine benchmark integrity.** Export only persisted run/evaluation outputs and explicit response/patch/trajectory artifacts.
