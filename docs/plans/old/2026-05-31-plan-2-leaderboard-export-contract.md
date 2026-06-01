# Plan 2 — Leaderboard Export Contract

## Goal

Add a Dart CLI that exports a versioned public `leaderboard.v1.json` file from the app's Drift/sqlite database for the future Svelte landing page. The export must be static-site friendly, reproducible, and safe to publish.

## Success criteria

- A new executable can generate `leaderboard.v1.json` from a database path and output path.
- The default export uses aggregate-compatible results, not best-observed cherry-picking.
- The JSON contract is versioned and contains model rankings, task summaries, source metadata, and public-safe warnings.
- The JSON does not include provider secrets, raw prompts, raw responses, patches, trajectory paths, local absolute paths, hidden verifier content, or private fixture data.
- Existing app behavior, DB schema, and benchmark execution remain unchanged.
- Export logic is unit-tested independently from the Svelte site.

## Current context

- The Flutter/Dart app now lives in `app/`.
- Existing persisted data uses Drift/sqlite tables: `Runs`, `TaskRuns`, `Evaluations`, `Plans`, and `ReviewBattles`.
- Existing analytics helpers already compute pass-rate, Wilson intervals, medians, cost estimates, and failure breakdowns.
- Existing run provenance JSON can include evaluator weights, selected models, task metadata, and redacted provider metadata.
- `sqflite` is not used.

## Proposed changes

### 1. Add a leaderboard export library

Create:

```txt
app/lib/export/leaderboard_exporter.dart
```

Responsibilities:

- Load completed runs and task runs from `AppDatabase`.
- Apply export options.
- Build a stable `Map<String, Object?>` for `leaderboard.v1.json`.
- Reuse existing analytics helpers where possible:
  - `buildRankingMetrics`
  - Wilson confidence intervals
  - `Dimensions.fromTaskRuns`
  - `CostEstimator`
- Sort all public arrays deterministically.
- Keep raw/private task-run fields out of the JSON.

Suggested public API:

```dart
enum LeaderboardExportStrategy {
  aggregateCompatible,
  latestRun,
  bestObserved,
}

class LeaderboardExportOptions {
  const LeaderboardExportOptions({
    required this.track,
    this.strategy = LeaderboardExportStrategy.aggregateCompatible,
    this.runId,
  });

  final String track;
  final LeaderboardExportStrategy strategy;
  final String? runId;
}

Future<Map<String, Object?>> buildLeaderboardExport(
  AppDatabase db, {
  required LeaderboardExportOptions options,
  DateTime Function()? now,
});
```

### 2. Define strategy semantics

All strategies consider only completed runs (`Runs.completedAt != null`) and
task runs matching the selected `benchmarkTrack`.

#### `aggregate-compatible` default

Use the latest completed run for the selected track as the compatibility anchor unless `--run-id` is provided.

Include task runs from completed runs that are compatible with the anchor:

- same selected `benchmarkTrack`
- same sorted `(taskId, taskVersion)` set for that track
- same sorted non-null `harnessId` set, when present
- same evaluator weights when both the anchor and candidate run have parseable
  provenance with `config.evaluatorWeights`

Parse `provenanceJson` with `jsonDecode` guarded by `try`/`catch`. If either
run lacks parseable provenance or `config.evaluatorWeights`, skip only the
evaluator-weight comparison for that pair, keep the task/version/harness
compatibility checks, and add a warning under `source.warnings`.

#### `latest-run`

Export only task runs from the latest completed run for the selected track, or from `--run-id` if provided.

#### `best-observed`

Export a clearly labeled non-default view. The source set is all completed runs
for the selected track; when `--run-id` is provided, restrict the source set to
that completed run rather than expanding to compatible runs. For each
provider/model/task/version group, select the best task run by:

1. `primaryPass == true`
2. higher `aggregateScore`
3. lower `latencyMs`
4. newer `completedAt`

The exported `benchmark.dataPolicy` must be `best-observed` so the Svelte UI can label it honestly.

### 3. JSON contract

Initial contract shape:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-05-31T00:00:00.000Z",
  "benchmark": {
    "name": "Dart Arena",
    "brand": "Pickforge",
    "title": "Dart Arena by Pickforge",
    "track": "agentic",
    "dataPolicy": "aggregate-compatible"
  },
  "source": {
    "anchorRunId": "run-id",
    "runIds": ["run-id"],
    "taskCount": 0,
    "taskRunCount": 0,
    "modelCount": 0,
    "warnings": []
  },
  "models": [],
  "tasks": []
}
```

Contract rules:

- `benchmark.dataPolicy` must be the kebab-case strategy string:
  `aggregate-compatible`, `latest-run`, or `best-observed`.
- If a valid database has no completed runs or task runs matching the selected
  track/scope, emit valid JSON with empty `models` and `tasks`, zero source
  counts, a warning in `source.warnings`, and return CLI exit code `0`.
- `source.taskRunCount` counts selected task runs before primary-pass null
  filtering.

Model rows:

```json
{
  "providerId": "openai",
  "modelId": "gpt-5.5",
  "rank": 1,
  "score": 0.7,
  "passRate": 0.7,
  "passCount": 70,
  "sampleCount": 100,
  "confidenceInterval": {
    "lower": 0.604,
    "upper": 0.781
  },
  "lowSample": false,
  "medianLatencyMs": 123000,
  "medianPromptTokens": 10000,
  "medianCompletionTokens": 20000,
  "medianEstimatedCostMicros": 1200000,
  "costPerSolvedTaskMicros": 1800000,
  "failureBreakdown": {
    "pass": 70,
    "test_failed": 20,
    "unknown": 10
  }
}
```

Model row semantics:

- `passCount` counts selected model task runs where `primaryPass == true`.
- `sampleCount` counts selected model task runs where `primaryPass != null`.
- `passRate` is `passCount / sampleCount`; if `sampleCount == 0`, use `0.0`,
  set `lowSample` to `true`, and add a source warning.
- `score` equals `passRate` for schema v1.
- Sort model rows by `score` descending, Wilson interval `lower` descending,
  `sampleCount` descending, `medianEstimatedCostMicros` ascending with nulls
  last, `medianLatencyMs` ascending with nulls last, then `providerId` and
  `modelId` ascending. Assign sequential 1-indexed `rank` after sorting.

Task rows:

```json
{
  "taskId": "bug.off_by_one_pagination",
  "taskVersion": 1,
  "benchmarkTrack": "agentic",
  "sampleCount": 15,
  "modelCount": 3,
  "passRate": 0.6
}
```

Task row semantics:

- Aggregate by `(taskId, taskVersion, benchmarkTrack)` over the same selected
  task-run set used by the strategy.
- `sampleCount` counts selected task runs for the task group where
  `primaryPass != null`.
- `modelCount` counts distinct `providerId:modelId` pairs in the task group.
- `passRate` is selected task runs with `primaryPass == true` divided by
  selected task runs where `primaryPass != null`; if the denominator is `0`,
  use `0.0` and add a source warning.

Keep all ratios as numbers from `0.0` to `1.0`. Formatting as percentages belongs in the Svelte UI.

### 4. Add CLI runner and executable

Create:

```txt
app/lib/export/leaderboard_cli_runner.dart
app/bin/dart_arena_export_leaderboard.dart
```

Add to `app/pubspec.yaml`:

```yaml
executables:
  dart_arena_headless: dart_arena_headless
  dart_arena_export_leaderboard: dart_arena_export_leaderboard
```

CLI:

```sh
cd app
dart run dart_arena:dart_arena_export_leaderboard \
  --database .dart_arena/dart_arena.sqlite \
  --out ../web/static/data/leaderboard.v1.json \
  --track agentic \
  --strategy aggregate-compatible
```

Arguments:

- `--database <path>` required
- `--out <path>` required
- `--track <codegen|agentic>` required
- `--strategy <aggregate-compatible|latest-run|best-observed>` optional, default `aggregate-compatible`
- `--run-id <id>` optional anchor/scope
- `--help` prints JSON help similar to the existing headless CLI

The CLI should create the output parent directory but must not create or mutate benchmark data.

Database handling:

- Validate that `--database` points to an existing file before creating
  `AppDatabase`.
- Add a small helper in the export CLI layer to open that exact file with a
  read-only Drift/sqlite executor, for example by using `sqlite3.open(path,
  mode: OpenMode.readOnly)` with `NativeDatabase.opened(...,
  enableMigrations: false)` or an equivalent read-only executor.
- If direct `package:sqlite3` APIs are used from `lib/`, move `sqlite3` from
  `dev_dependencies` to `dependencies` so the executable has the runtime API.
- Fail with JSON error output and exit code `1` when the database file is
  missing, unreadable, or has an incompatible `appDatabaseSchemaVersion`.
- Do not create database parent directories, create a new database file, run
  migrations, or otherwise write benchmark data during export.

### 5. Tests

Create tests:

```txt
app/test/export/leaderboard_exporter_test.dart
app/test/export/leaderboard_cli_runner_test.dart
```

Required coverage:

- `aggregate-compatible` aggregates multiple compatible completed runs.
- incompatible task versions or task sets are excluded.
- `latest-run` exports only the latest completed run for the track.
- `best-observed` chooses best task runs and labels the data policy.
- `best-observed` respects `--run-id` by selecting only from that completed run.
- model rows include pass-rate, Wilson interval, sample counts, medians, cost metrics, and failure breakdown.
- model `score` equals `passRate`, and rank ordering follows the contract
  comparator.
- task rows aggregate by `(taskId, taskVersion, benchmarkTrack)`.
- task row `passRate` uses `primaryPass != null` as the denominator.
- output excludes raw response text, prompts, patches, trajectory paths, and local absolute paths.
- malformed or missing provenance emits warnings without crashing and only
  skips evaluator-weight compatibility checks.
- an empty matching result set emits valid empty JSON with a warning and exit
  code `0`.
- CLI fails without creating or migrating a database when `--database` is
  missing or incompatible.
- CLI validates required args and unsupported strategy/track values.
- CLI writes pretty JSON to the requested output path.

## Files touched

Expected:

```txt
app/bin/dart_arena_export_leaderboard.dart
app/lib/export/leaderboard_cli_runner.dart
app/lib/export/leaderboard_exporter.dart
app/pubspec.yaml
app/test/export/leaderboard_cli_runner_test.dart
app/test/export/leaderboard_exporter_test.dart
```

Possibly touched if helper reuse requires it:

```txt
app/lib/analytics/benchmark_statistics.dart
app/lib/analytics/leaderboard_repository.dart
```

## Validation

Run:

```sh
cd app
dart format --set-exit-if-changed bin lib/export test/export
flutter analyze
flutter test test/export
dart run --verbosity=error dart_arena:dart_arena_export_leaderboard --help
```

Before handoff, also run:

```sh
cd app
flutter test
```

## Risks and mitigations

- **Cherry-picking risk:** default to `aggregate-compatible`; keep `best-observed` opt-in and explicitly labeled.
- **Compatibility ambiguity:** use latest completed run or `--run-id` as anchor and emit warnings for malformed/missing provenance.
- **Public data leakage:** add tests that assert sensitive/raw fields are absent from serialized JSON.
- **Over-coupling to UI:** export neutral numeric data; leave display labels, formatting, and chart-specific transformations for Svelte.
- **DB schema coupling:** do not add tables or migrations; export from current schema only.

## Out of scope

- Svelte/SvelteKit app scaffold.
- Web charts or landing page UI.
- Running new benchmarks.
- Reading SQLite from Svelte.
- Deployment or CI publishing of `leaderboard.v1.json`.
