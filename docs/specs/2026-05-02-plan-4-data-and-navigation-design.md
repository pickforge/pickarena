# Plan 4 — Data & Navigation: Design Spec

**Status:** Design approved (sections 1-5). Ready to be turned into an implementation plan.
**Date:** 2026-05-02
**Predecessors:** Plan 1 (foundation + first slice), Plan 2 (cloud providers), Plan 3 (evaluators + scoring) — all implemented.
**Successors (roadmap stubs in `docs/roadmap/`):** Plan 5 (benchmark content), Plan 6 (analytics), Plan 7 (polish).

---

## 1. Goal & scope

### Goal

Make the benchmark data already accumulating in SQLite **reachable and shareable**. After Plan 4, a user can:

- Select multiple tasks per run and optionally label the run.
- Browse their entire run history.
- Drill from a run into any single task-run's full evidence: raw output, extracted code, unified diff, per-evaluator breakdown, original prompt.
- Export a run as CSV (spreadsheet) or Markdown (standalone `.md`).
- Publish the latest run's results into the project `README.md` between marker comments, with a preview before write.

### In scope

1. Multi-task selection on `NewRunPage` with full cross-product execution semantics (tasks × providers/models).
2. Optional run label set at run creation; small Drift schema migration adding `runs.name TEXT NULL`.
3. **RunHistoryPage** — list of runs, sort by date, search by label.
4. **RunDetailsPage** — replaces today's stub. Summary matrix of task-runs with three actions: Export CSV, Export Markdown, Publish to README.
5. **TaskRunDetailsPage** — header + score strip + 4 tabs (Output / Diff / Evaluations / Prompt).
6. CSV export per run (one row per task-run, evaluator scores as columns; native save dialog via `file_picker`).
7. Markdown export per run (standalone `.md` file; native save dialog).
8. "Publish to README" — replaces content between `<!-- BENCHMARK_RESULTS:START --> … <!-- BENCHMARK_RESULTS:END -->` markers in a user-configured README path; preview before write; manual button only.

### Out of scope (deferred)

| Item | Where it lands |
|---|---|
| 9 new benchmark tasks across the 5 categories | Plan 5 |
| Dashboard / leaderboard / `fl_chart` visualizations | Plan 6 |
| Rich filters on history (provider/task/score-range), saved presets | Plan 6 |
| Auto-publish on run completion | Future |
| Aggregate / leaderboard-style README content | Plan 6 |
| Evaluator-weights editor in Settings | Plan 7 |
| `NewRunPage` provider DI refactor | Plan 7 |

### Success criteria

- `flutter analyze` clean.
- `flutter test` — all existing tests plus all new unit and widget tests pass.
- `flutter build linux --debug` succeeds.
- Manual smoke: a user can run a benchmark with 2+ tasks, see it in history, drill in, export CSV/MD, and publish to a `README.md` containing the markers (verified by file diff).

---

## 2. Data layer

### 2.1 Drift schema migration v1 → v2

Single change: add a nullable `name` column to the `runs` table for the optional user label.

```dart
// lib/storage/database.dart
class Runs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get judgeModel => text().nullable()();
  TextColumn get name => text().nullable()();   // NEW

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Runs, TaskRuns, Evaluations])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(runs, runs.name);
          }
        },
      );
}
```

Code generation refresh required: `dart run build_runner build --delete-conflicting-outputs`.

### 2.2 `SettingsRepository` additions

New key + accessors for the configurable README path:

```dart
static const _readmePath = 'readme_path';

Future<String?> getReadmePath() => _storage.read(key: _readmePath);

Future<void> setReadmePath(String? value) async {
  if (value == null || value.isEmpty) {
    await _storage.delete(key: _readmePath);
  } else {
    await _storage.write(key: _readmePath, value: value);
  }
}
```

### 2.3 `RunDao` additions

Already exists from Plans 1 and 3: `startRun`, `finishRun`, `persistTaskRun`, `taskRunsForRun`, `evaluationsForTaskRun`, `recentRuns`.

Modified — `startRun` now accepts an optional `name`:

```dart
Future<void> startRun({
  required String runId,
  required DateTime startedAt,
  String? name,
}) {
  return _db.into(_db.runs).insert(
        RunsCompanion.insert(
          id: runId,
          startedAt: startedAt,
          name: Value(name),
        ),
      );
}
```

New — overload `recentRuns` with optional label search:

```dart
Future<List<Run>> recentRuns({int limit = 100, String? labelQuery}) {
  final q = _db.select(_db.runs)
    ..orderBy([(r) => OrderingTerm.desc(r.startedAt)])
    ..limit(limit);
  if (labelQuery != null && labelQuery.isNotEmpty) {
    q.where((r) => r.name.like('%$labelQuery%'));
  }
  return q.get();
}
```

New — single-row lookups:

```dart
Future<Run?> runById(String id) =>
    (_db.select(_db.runs)..where((r) => r.id.equals(id))).getSingleOrNull();

Future<TaskRun?> taskRunById(String id) =>
    (_db.select(_db.taskRuns)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
```

### 2.4 `StartRun` event addition

```dart
class StartRun extends RunEvent {
  const StartRun({
    required this.tasks,
    required this.providers,
    required this.modelByProvider,
    required this.evaluatorConfig,
    this.name,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, String> modelByProvider;
  final EvaluatorConfig evaluatorConfig;
  final String? name;
}
```

`RunBloc._onStart` propagates `event.name` into `runDao.startRun(...)`. No other bloc behavior changes.

### 2.5 `RunSummary` value object

The single read shape consumed by `RunDetailsPage`, the CSV exporter, the MD exporter, and the README publisher.

```dart
// lib/runner/run_summary.dart
class RunSummary extends Equatable {
  const RunSummary({
    required this.run,
    required this.taskRuns,
    required this.evaluationsByTaskRunId,
  });

  final Run run;
  final List<TaskRun> taskRuns;
  final Map<String, List<Evaluation>> evaluationsByTaskRunId;

  @override
  List<Object?> get props => [run, taskRuns, evaluationsByTaskRunId];
}

extension RunSummaryLoader on RunDao {
  Future<RunSummary?> loadSummary(String runId) async {
    final run = await runById(runId);
    if (run == null) return null;
    final trs = await taskRunsForRun(runId);
    final evals = <String, List<Evaluation>>{};
    for (final tr in trs) {
      evals[tr.id] = await evaluationsForTaskRun(tr.id);
    }
    return RunSummary(run: run, taskRuns: trs, evaluationsByTaskRunId: evals);
  }
}
```

---

## 3. Pure services & exporters

All four output paths (CSV, Markdown, README publish, diff view) are pure functions over `RunSummary` plus one I/O wrapper for the README publisher. Pure → trivially testable with golden strings.

### 3.1 File map

```
lib/export/
  csv_exporter.dart            // String runSummaryToCsv(RunSummary)
  md_exporter.dart             // String runSummaryToMarkdown(RunSummary)
  readme_publisher.dart        // class ReadmePublisher
lib/core/
  unified_diff.dart            // List<DiffLine> computeUnifiedDiff(String a, String b)
```

### 3.2 `csv_exporter.dart`

```dart
const _evaluatorIds = ['compile', 'analyze', 'test',
                       'widget_tree', 'llm_judge', 'diff_size'];

String runSummaryToCsv(RunSummary s) {
  final headers = [
    'run_id', 'run_name', 'started_at', 'task_id',
    'provider_id', 'model_id',
    'aggregate_score',
    ..._evaluatorIds.map((e) => 'score_$e'),
    'latency_ms', 'prompt_tokens', 'completion_tokens',
  ];
  final rows = <List<String>>[headers];
  for (final tr in s.taskRuns) {
    final evals = {
      for (final e in s.evaluationsByTaskRunId[tr.id] ?? const <Evaluation>[])
        e.evaluatorId: e.score,
    };
    rows.add([
      tr.runId,
      s.run.name ?? '',
      s.run.startedAt.toIso8601String(),
      tr.taskId,
      tr.providerId,
      tr.modelId,
      tr.aggregateScore.toStringAsFixed(4),
      ..._evaluatorIds.map((id) => (evals[id] ?? 0).toStringAsFixed(4)),
      tr.latencyMs.toString(),
      (tr.promptTokens ?? '').toString(),
      (tr.completionTokens ?? '').toString(),
    ]);
  }
  return rows.map(_csvLine).join('\n');
}

String _csvLine(List<String> cells) => cells.map(_csvCell).join(',');

String _csvCell(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}
```

### 3.3 `md_exporter.dart`

```dart
String runSummaryToMarkdown(RunSummary s) {
  final buf = StringBuffer();
  final ts = s.run.startedAt.toIso8601String();
  buf.writeln('# Benchmark run');
  if (s.run.name != null) buf.writeln('**${s.run.name}**');
  buf.writeln('Started: `$ts`  ·  Task-runs: ${s.taskRuns.length}');
  buf.writeln();

  buf.writeln(
    '| Task | Provider | Model | Aggregate | compile | analyze | test '
    '| widget_tree | llm_judge | diff_size | Latency |',
  );
  buf.writeln(
    '|------|----------|-------|-----------|---------|---------|------'
    '|-------------|-----------|-----------|---------|',
  );
  for (final tr in s.taskRuns) {
    final evals = {
      for (final e in s.evaluationsByTaskRunId[tr.id] ?? const <Evaluation>[])
        e.evaluatorId: e.score,
    };
    String fmt(String id) => (evals[id] ?? 0).toStringAsFixed(2);
    buf.writeln(
      '| ${tr.taskId} | ${tr.providerId} | ${tr.modelId} '
      '| **${tr.aggregateScore.toStringAsFixed(2)}** '
      '| ${fmt('compile')} | ${fmt('analyze')} | ${fmt('test')} '
      '| ${fmt('widget_tree')} | ${fmt('llm_judge')} | ${fmt('diff_size')} '
      '| ${tr.latencyMs}ms |',
    );
  }
  return buf.toString();
}
```

### 3.4 `readme_publisher.dart`

```dart
sealed class PublishResult {
  const PublishResult();
}
class PublishOk extends PublishResult {
  const PublishOk(this.path);
  final String path;
}
class PublishFailed extends PublishResult {
  const PublishFailed(this.reason);
  final String reason;
}

class ReadmePublisher {
  static const startMarker = '<!-- BENCHMARK_RESULTS:START -->';
  static const endMarker   = '<!-- BENCHMARK_RESULTS:END -->';

  Future<PublishResult> publish({
    required String readmePath,
    required String generatedMarkdown,
  }) async {
    final result = await _splice(readmePath, generatedMarkdown);
    if (result is _SpliceOk) {
      await File(readmePath).writeAsString(result.updated);
      return PublishOk(readmePath);
    }
    return PublishFailed((result as _SpliceFailed).reason);
  }

  /// Pure preview — returns what the file would look like without writing.
  Future<ReadmePreview> preview({
    required String readmePath,
    required String generatedMarkdown,
  }) async {
    final result = await _splice(readmePath, generatedMarkdown);
    if (result is _SpliceOk) return PreviewOk(result.updated);
    return PreviewFailed((result as _SpliceFailed).reason);
  }

  Future<_SpliceResult> _splice(String path, String generatedMarkdown) async {
    final file = File(path);
    if (!await file.exists()) {
      return _SpliceFailed('README not found at $path');
    }
    final original = await file.readAsString();
    final startIdx = original.indexOf(startMarker);
    final endIdx = original.indexOf(endMarker);
    if (startIdx < 0 || endIdx < 0 || endIdx < startIdx) {
      return _SpliceFailed(
        'Markers not found. Add\n  $startMarker\n  $endMarker\n'
        'to your README where the results should appear.',
      );
    }
    final before = original.substring(0, startIdx + startMarker.length);
    final after = original.substring(endIdx);
    return _SpliceOk('$before\n$generatedMarkdown\n$after');
  }
}

sealed class _SpliceResult {}
class _SpliceOk extends _SpliceResult {
  _SpliceOk(this.updated);
  final String updated;
}
class _SpliceFailed extends _SpliceResult {
  _SpliceFailed(this.reason);
  final String reason;
}

sealed class ReadmePreview {
  const ReadmePreview();
}
class PreviewOk extends ReadmePreview {
  const PreviewOk(this.updatedContent);
  final String updatedContent;
}
class PreviewFailed extends ReadmePreview {
  const PreviewFailed(this.reason);
  final String reason;
}
```

`publish` and `preview` share the `_splice` helper but return different sealed types: `PublishResult` carries the side-effect outcome (file written or not), while `ReadmePreview` carries the would-be content for dry-run UI.

### 3.5 `unified_diff.dart`

Used by both `DiffSizeEvaluator` (existing — refactored to share) and the new diff-view widget.

```dart
enum DiffLineKind { context, added, removed }

class DiffLine extends Equatable {
  const DiffLine(this.kind, this.text);
  final DiffLineKind kind;
  final String text;
  @override
  List<Object?> get props => [kind, text];
}

List<DiffLine> computeUnifiedDiff(String original, String generated) {
  // Uses diff_match_patch's line-mode workflow:
  //   1. linesToChars(original, generated) -> (char1, char2, lineArray)
  //   2. diff_main on the char strings
  //   3. diff_charsToLines(diffs, lineArray)
  // Then iterate the resulting List<Diff> and emit one DiffLine per
  // newline-terminated chunk, mapping Operation.equal -> context,
  // Operation.insert -> added, Operation.delete -> removed.
  //
  // Existing line-level diff loop in DiffSizeEvaluator is extracted here;
  // DiffSizeEvaluator becomes a consumer of computeUnifiedDiff (its
  // numeric score is then derived from counts of added/removed lines).
}
```

### 3.6 New dependency: `file_picker`

```yaml
dependencies:
  file_picker: ^8.1.2
```

The only new dependency Plan 4 introduces. Used by:
- `RunDetailsPage` "Export CSV" / "Export Markdown" buttons (`FilePicker.platform.saveFile`).
- `SettingsPage` "Browse..." next to the README path field (`FilePicker.platform.pickFiles`).

### 3.7 Save flow (illustrative)

```dart
Future<void> _saveCsv(BuildContext context, RunSummary s) async {
  final csv = runSummaryToCsv(s);
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save run as CSV',
    fileName: 'run-${s.run.id}.csv',
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );
  if (path == null) return;
  await File(path).writeAsString(csv);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $path')),
    );
  }
}
```

---

## 4. UI surfaces & routing

### 4.1 Routes (`lib/app.dart`)

| Path | Existing? | Page |
|---|---|---|
| `/` | yes | HomePage (modified — adds "View history" button) |
| `/new-run` | yes | NewRunPage (modified — task picker + label field) |
| `/run` | yes | RunProgressPage (no change) |
| `/runs` | **NEW** | RunHistoryPage |
| `/runs/:runId` | replaces stub | RunDetailsPage |
| `/runs/:runId/task-runs/:taskRunId` | **NEW** | TaskRunDetailsPage |
| `/settings` | yes | SettingsPage (modified — README path field) |

```dart
GoRoute(path: '/runs', builder: (_, __) => const RunHistoryPage()),
GoRoute(
  path: '/runs/:runId',
  builder: (c, state) =>
      RunDetailsPage(runId: state.pathParameters['runId']!),
),
GoRoute(
  path: '/runs/:runId/task-runs/:taskRunId',
  builder: (c, state) => TaskRunDetailsPage(
    runId: state.pathParameters['runId']!,
    taskRunId: state.pathParameters['taskRunId']!,
  ),
),
```

Pages instantiate their own `AppDatabase` / `RunDao` / `SettingsRepository` in `initState`, matching Plan 1's pattern. Cleaning that up is Plan 7 (DI refactor); explicitly out of scope here.

### 4.2 NewRunPage modifications

Above the existing provider list (from Plan 2), insert two new sections:

1. **Run label** — `TextField`, label "Label this run (optional)", bound to `_label`. Default empty → run identified by timestamp in history.
2. **Task picker** — built from `TaskRegistry.instance.all()`, grouped by `Category`. One section per category with the category label and a "Select all" toggle. Each task is a `CheckboxListTile`. Today's only task (`bug.off_by_one_pagination`) is pre-selected so existing flows don't break.

State additions:

```dart
final Set<String> _selectedTaskIds = {'bug.off_by_one_pagination'};
String _label = '';
```

Run button validation now also requires `_selectedTaskIds.isNotEmpty`.

```dart
final selectedTasks = registry.all()
    .where((t) => _selectedTaskIds.contains(t.id))
    .toList();
bloc.add(StartRun(
  tasks: selectedTasks,
  providers: selectedProviders,
  modelByProvider: modelMap,
  evaluatorConfig: cfg,
  name: _label.isEmpty ? null : _label,
));
```

### 4.3 HomePage modifications

Add a third primary button alongside "New Run" and "Settings": **"View history"** → `context.push('/runs')`.

### 4.4 RunHistoryPage (new)

Layout:

```
┌───────────────────────────────────────────┐
│  Runs                                     │  AppBar
├───────────────────────────────────────────┤
│  Filter by label  [_______________]       │
├───────────────────────────────────────────┤
│  "deepseek vs claude"                     │
│  2026-05-02 14:23 · 5 tasks · 4 models    │
│  avg aggregate: 0.74                      │
├───────────────────────────────────────────┤
│  Run 1714607823                           │  ← unlabeled fallback
│  2026-05-02 11:08 · 1 task · 1 model      │
│  avg aggregate: 1.00                      │
└───────────────────────────────────────────┘
```

- Loads via `RunDao.recentRuns(limit: 100, labelQuery: _query)`.
- For each run, computes display fields by querying its task-runs (single extra query per row via `taskRunsForRun(run.id)`, fine at this volume).
- **Display fields per row**:
  - Title = `run.name ?? 'Run ${run.id}'`.
  - Subtitle = `<formatted startedAt> · <distinct task count> tasks · <distinct (provider, model) pair count> models`.
  - **avg aggregate** = arithmetic mean of `taskRun.aggregateScore` across that run's task-runs (rendered to 2 decimals; `—` if zero task-runs).
- Tap row → `context.push('/runs/${run.id}')`.
- Empty state: friendly message + "Run a benchmark" CTA.
- In-progress runs (`completedAt == null`): show a spinner badge. v1 strategy: pull-to-refresh; no live stream subscription required.

### 4.5 RunDetailsPage (replaces stub)

Layout:

```
┌────────────────────────────────────────────────────────────┐
│ ← Back                  [CSV] [MD] [Publish to README]     │
├────────────────────────────────────────────────────────────┤
│ "deepseek vs claude"                                       │
│ Started 2026-05-02 14:23 · Completed 14:31 · 20 task-runs  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│        deepseek/v3   anthropic/sonnet   openai/gpt-5  ...  │
│  ─────────────────────────────────────────────────────     │
│  bug.off_by_one    0.92          1.00            0.84      │
│  state.counter     0.71          0.95            1.00      │
│  refactor.god      0.43          0.81            0.62      │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

- Matrix: rows = task ids, columns = `<providerId>/<modelId>` pairs.
- Cells show aggregate score with color tint (green ≥ 0.8, yellow 0.5–0.8, red < 0.5).
- Empty cells (combo didn't run, or in-progress) → `—` or spinner.
- Tap cell → `context.push('/runs/${runId}/task-runs/${taskRunId}')`.
- Horizontally scrollable when many providers; vertically when many tasks.

**Action bar (top right):** three buttons.

- **Export CSV** → `runSummaryToCsv` → `FilePicker.saveFile`.
- **Export Markdown** → `runSummaryToMarkdown` → `FilePicker.saveFile`.
- **Publish to README** → opens a dialog showing the markdown preview (the same markdown that would be exported). Two action buttons: "Copy" and "Publish". "Publish" calls `ReadmePublisher.publish(...)` against `SettingsRepository.getReadmePath()`. If that path is unset, the button is disabled with tooltip "Set README path in Settings".

### 4.6 TaskRunDetailsPage (new)

Layout:

```
┌─────────────────────────────────────────────────────────┐
│ ← Back     deepseek / v3 / bug.off_by_one_pagination    │  sticky
│            2026-05-02 14:23 · agg 0.92 · 1.4s · 312tk   │
├─────────────────────────────────────────────────────────┤
│ [compile 1.0] [analyze 0.9] [test 1.0] [widget_tree —]  │  score strip
│ [llm_judge 0.85] [diff_size 0.93]                       │
├─────────────────────────────────────────────────────────┤
│ [Output] [Diff] [Evaluations] [Prompt]                  │  TabBar
├─────────────────────────────────────────────────────────┤
│   tab body                                              │
└─────────────────────────────────────────────────────────┘
```

**Output tab:** `SegmentedButton` toggle between "Extracted code" (default, syntax-highlighted via `flutter_highlight` `dart` mode) and "Raw output" (plain mono). Copy button top right.

**Diff tab:** `computeUnifiedDiff(original, extracted)` rendered as a vertically scrollable list of color-coded lines. Empty state ("Task has no original at this path to diff against") if the task's `generatedCodePath` doesn't appear in `task.fixtures`. Copy diff button top right.

**Evaluations tab:** one `Card` per evaluator. Header: pass/fail badge + score. Body: rationale (if any) and an `ExpansionTile` containing pretty-printed `details` JSON.

**Prompt tab:** read-only display of `task.prompt`, then below (collapsed by default) `task.judgeRubric` if non-null.

### 4.7 SettingsPage modifications

Insert a new section "README publishing" between the Judge Model section (Plan 3) and the Factory Droid section (Plan 2):

```
README publishing
─────────────────
README path  [_____________________________]  [Browse...]

The "Publish to README" button replaces content between
  <!-- BENCHMARK_RESULTS:START -->
  <!-- BENCHMARK_RESULTS:END -->
markers in the file above. Add these markers manually
to your README before publishing.
```

`Browse...` uses `FilePicker.platform.pickFiles(allowedExtensions: ['md'])`.

### 4.8 New widgets

Each is small enough to widget-test in isolation.

- `lib/ui/widgets/diff_view.dart` — renders `List<DiffLine>` as colored lines.
- `lib/ui/widgets/score_chip.dart` — chip used in TaskRunDetailsPage's score strip.
- `lib/ui/widgets/run_matrix.dart` — task × model matrix in RunDetailsPage.
- `lib/ui/widgets/evaluator_card.dart` — per-evaluator card in the Evaluations tab.

---

## 5. Failure modes & testing

### 5.1 Failure modes

1. **README path unset** → "Publish to README" disabled with tooltip "Set README path in Settings".
2. **README file missing at the configured path** → `PublishFailed('README not found at <path>')`. Dialog shows error, no destructive action taken.
3. **README markers missing or malformed** (end before start, only one present) → `PublishFailed('Markers not found. Add ... to your README ...')`. Dialog shows the error and offers a "Copy markers" button so the user can paste them in. No write happens.
4. **README write fails** (permissions, disk full) → caught, surfaced as `PublishFailed('IO error: <message>')`. Original file untouched in practice; we read first, build new content in memory, then write.
5. **Run with zero completed task-runs** (e.g., bloc threw early before any task completed) → still appears in history. RunDetailsPage shows an empty matrix and a banner "Run failed before any task completed". CSV export of such a run is the headers row only. MD export shows the title and the empty table.
6. **In-progress run** (`completedAt == null`) → history list shows a spinner badge. RunDetailsPage shows a banner "Run still in progress; results will appear as task-runs complete." Export buttons disabled while in progress.
7. **Schema migration on existing v1 DB** → `MigrationStrategy.onUpgrade` adds the `name` column. Old runs end up with `name = NULL`, rendering as the timestamp fallback in the history list.
8. **Task-run with very large raw output** (e.g., 100 KB) → Output tab uses `SingleChildScrollView` with no truncation; `flutter_highlight` handles large blocks; copy works. Not paginated in v1.
9. **Diff against a fixture path the task didn't ship** → Diff tab empty state; no crash.
10. **User picks zero tasks on NewRunPage** → Run button disabled; SnackBar on attempted submit.
11. **Task removed from registry between runs** (developer deleted the file) → history page still shows the run. RunDetailsPage shows the task id in the matrix even though no `BenchmarkTask` instance is registered. TaskRunDetailsPage's Diff and Prompt tabs show empty states (they need `task.fixtures` and `task.prompt`); Output and Evaluations tabs work fully (they only need DB data).

### 5.2 Tests

| Layer | Test type | What's covered |
|---|---|---|
| `csv_exporter` | Unit (golden string) | Full row generation; CSV escaping (commas, quotes, newlines); missing evaluator → 0; empty task-runs |
| `md_exporter` | Unit (golden string) | Table rendering; null label vs set label; empty task-runs |
| `unified_diff` | Unit | Identical inputs → all-context; line additions/removals; empty file edge case |
| `ReadmePublisher` | Unit (real temp files) | Happy publish; missing file; missing markers; malformed markers (end before start); preserves content outside markers; preview path returns updated content without writing |
| `RunDao` additions | Unit (in-memory Drift) | `recentRuns` with `labelQuery` (LIKE match); `runById` / `taskRunById` happy + miss; `loadSummary` extension with multiple task-runs |
| Drift migration v1→v2 | Migration test | Open v1 DB, run upgrade, assert `runs.name` column exists, old rows are NULL |
| `SettingsRepository` | Unit | `getReadmePath` / `setReadmePath` roundtrip; null clears the value |
| `StartRun` event | Unit | Constructor accepts optional `name`; defaults to null; equality preserved |
| `RunBloc` | Existing test extended | Asserts `name` gets persisted via `runDao.startRun(name: ...)` |
| `RunHistoryPage` | Widget | Renders empty state; renders rows from a stub DAO; label search filters list |
| `RunDetailsPage` | Widget | Renders matrix from a stub `RunSummary`; tap on a cell pushes correct route; export buttons disabled during in-progress; "Publish to README" disabled when path unset |
| `TaskRunDetailsPage` | Widget | Tab switching; Output toggle Extracted/Raw; Diff tab empty state when no fixture; Evaluations tab renders per evaluator |
| `NewRunPage` | Widget | Task picker renders by category; Run disabled with no tasks selected; label propagates into `StartRun` |

No new integration tests for `flutter test --tags integration` — Plan 4 is all unit + widget. The export pipeline gets exercised end-to-end through widget tests on the buttons.

### 5.3 Verification gate

- `flutter analyze` clean.
- `flutter test` — all existing + new tests pass.
- `flutter build linux --debug` succeeds.
- Manual smoke: run a benchmark with at least 2 tasks selected and a label set; verify it appears in history; drill into the run; tap a cell to drill into a task-run; switch through all 4 tabs; export CSV and MD via dialog; configure a README path with the markers in `README.md`; publish; visually diff the file to confirm only marker content changed.

---

## 6. Recap

- **Section 1** — goal, what's in/out.
- **Section 2** — schema (`runs.name`), DAO additions, settings (`readmePath`), `RunSummary` value object.
- **Section 3** — pure exporters (`csv`, `md`, `unified_diff`), `ReadmePublisher` (the only file mutation), one new dep (`file_picker`).
- **Section 4** — six routes (3 new, 3 modified), four new pages, four new widgets.
- **Section 5** — 11 failure modes designed-for, 13 test surfaces.

The implementation plan derived from this design will follow the repository's pattern: `docs/plans/2026-05-02-data-and-navigation.md`, with task-by-task TDD steps, broken into small commits.
