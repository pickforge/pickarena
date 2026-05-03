# dart_arena — Plan 4: Data & Navigation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make accumulated benchmark data reachable and shareable. Adds multi-task selection to NewRunPage, optional run labels, a run history list, run details (summary matrix), task-run details (heavy drill-in with 4 tabs), CSV export, Markdown export, and "Publish to README" with marker-comment splicing and preview.

**Architecture:** Schema migration v1→v2 adds `runs.name`. New `RunSummary` value object is the single read shape consumed by the new pages and exporters. Pure exporters (`csv_exporter`, `md_exporter`, `unified_diff`) plus one I/O wrapper (`ReadmePublisher`) keep file mutation isolated. Four new pages and four small focused widgets land behind three new GoRoutes; existing pages get small additive changes only.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, flutter_bloc, drift, dio, flutter_secure_storage, mocktail (tests). NEW: `file_picker ^8.1.2` for native save/open dialogs.

**Predecessors:** Plan 1 (foundation), Plan 2 (cloud providers), Plan 3 (evaluators + scoring) — all implemented.

**Spec:** `docs/specs/2026-05-02-plan-4-data-and-navigation-design.md`.

---

## File map (this plan)

### Created

- `lib/storage/run_summary.dart` — `RunSummary` value object + `loadSummary` extension on `RunDao`
- `lib/core/unified_diff.dart` — `DiffLine`, `DiffLineKind`, `computeUnifiedDiff`
- `lib/export/csv_exporter.dart` — `runSummaryToCsv`
- `lib/export/md_exporter.dart` — `runSummaryToMarkdown`
- `lib/export/readme_publisher.dart` — `ReadmePublisher`, `PublishResult`, `ReadmePreview`
- `lib/tasks/task_catalog.dart` — `buildDefaultTaskRegistry()`
- `lib/ui/widgets/score_chip.dart`
- `lib/ui/widgets/evaluator_card.dart`
- `lib/ui/widgets/diff_view.dart`
- `lib/ui/widgets/run_matrix.dart`
- `lib/ui/pages/run_history_page.dart`
- `lib/ui/pages/run_details_page.dart` — currently a stub
- `lib/ui/pages/task_run_details_page.dart`
- Tests in `test/` mirroring each new file

### Modified

- `pubspec.yaml` — add `file_picker: ^8.1.2`
- `lib/storage/database.dart` — `Runs.name` column, `schemaVersion: 2`, `MigrationStrategy`
- `lib/storage/database.g.dart` — regenerated (drift)
- `lib/storage/settings.dart` — add `getReadmePath` / `setReadmePath`
- `lib/storage/dao/run_dao.dart` — add `runById`, `taskRunById`, label-search overload of `recentRuns`, `name` parameter on `startRun`
- `lib/runner/run_event.dart` — `StartRun` adds optional `name`
- `lib/runner/run_bloc.dart` — propagate `event.name` into `runDao.startRun`
- `lib/ui/pages/new_run_page.dart` — task picker + run label + `TaskRegistry` injection
- `lib/ui/pages/home_page.dart` — add "View history" button
- `lib/ui/pages/settings_page.dart` — add README path section
- `lib/app.dart` — add three new routes (`/runs`, `/runs/:runId`, `/runs/:runId/task-runs/:taskRunId`)
- `test/runner/run_bloc_test.dart` — extend for `name` propagation
- `test/storage/run_dao_test.dart` — extend for new lookups + label search

---

## Task 1: Add `file_picker` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Edit `pubspec.yaml`. Add to `dependencies:` block in alphabetical order, between `equatable` and `diff_match_patch`:**

```yaml
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5
  file_picker: ^8.1.2
  diff_match_patch: ^0.4.1
```

- [ ] **Step 2: Fetch deps**

```bash
flutter pub get
```

Expected: success, `file_picker 8.1.2` (or compatible) resolves.

- [ ] **Step 3: Smoke-check analyze still clean**

```bash
flutter analyze
```

Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add file_picker dependency for CSV/MD save dialogs"
```

---

## Task 2: Drift schema migration v1 → v2 (add `runs.name`)

**Files:**
- Modify: `lib/storage/database.dart`
- Generated: `lib/storage/database.g.dart`
- Test: `test/storage/database_migration_test.dart`

- [ ] **Step 1: Write a failing test that exercises the new column**

Create `test/storage/database_migration_test.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs.name is writable and readable', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db.into(db.runs).insert(
          RunsCompanion.insert(
            id: 'r1',
            startedAt: DateTime(2026, 5, 2),
            name: const Value('my-run'),
          ),
        );

    final all = await db.select(db.runs).get();
    expect(all, hasLength(1));
    expect(all.first.id, 'r1');
    expect(all.first.name, 'my-run');

    await db.close();
  });

  test('runs.name is nullable (existing rows have no name)', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db.into(db.runs).insert(
          RunsCompanion.insert(
            id: 'r2',
            startedAt: DateTime(2026, 5, 2),
          ),
        );

    final row = await (db.select(db.runs)
          ..where((r) => r.id.equals('r2')))
        .getSingle();
    expect(row.name, isNull);

    await db.close();
  });

  test('schemaVersion is 2', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 2);
    await db.close();
  });
}
```

- [ ] **Step 2: Run, verify fail (compile error: `name` not on `Runs`)**

```bash
flutter test test/storage/database_migration_test.dart
```

Expected: FAIL — `Runs.name` does not exist; `RunsCompanion.insert` does not accept `name`.

- [ ] **Step 3: Modify `lib/storage/database.dart` — add the column, bump version, add migration**

Replace the `Runs` table class and `AppDatabase` class with:

```dart
class Runs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get judgeModel => text().nullable()();
  TextColumn get name => text().nullable()();

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

(Leave `Runs` table imports alone — `Table`, `Column`, etc. already imported.)

- [ ] **Step 4: Regenerate the .g.dart**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: writes `lib/storage/database.g.dart` with `name` column included.

- [ ] **Step 5: Run, verify pass**

```bash
flutter test test/storage/database_migration_test.dart
flutter test test/storage/database_test.dart
```

Expected: PASS for both. The pre-existing `database_test.dart` continues to pass because `name` is nullable.

- [ ] **Step 6: Commit**

```bash
git add lib/storage/database.dart lib/storage/database.g.dart test/storage/database_migration_test.dart
git commit -m "feat(storage): add runs.name column with v1->v2 migration"
```

---

## Task 3: SettingsRepository — README path

**Files:**
- Modify: `lib/storage/settings.dart`
- Test: `test/storage/settings_readme_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/storage/settings_readme_test.dart`:

```dart
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('readme path defaults to null', () async {
    final repo = SettingsRepository();
    expect(await repo.getReadmePath(), isNull);
  });

  test('readme path roundtrips', () async {
    final repo = SettingsRepository();
    await repo.setReadmePath('/tmp/README.md');
    expect(await repo.getReadmePath(), '/tmp/README.md');
  });

  test('setting null clears the value', () async {
    final repo = SettingsRepository();
    await repo.setReadmePath('/tmp/README.md');
    await repo.setReadmePath(null);
    expect(await repo.getReadmePath(), isNull);
  });

  test('setting empty string clears the value', () async {
    final repo = SettingsRepository();
    await repo.setReadmePath('/tmp/README.md');
    await repo.setReadmePath('');
    expect(await repo.getReadmePath(), isNull);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/storage/settings_readme_test.dart
```

Expected: FAIL — methods undefined.

- [ ] **Step 3: Modify `lib/storage/settings.dart`**

Inside the `SettingsRepository` class, add the constant alongside the existing constants:

```dart
  static const _readmePath = 'readme_path';
```

Then add these methods inside the class (anywhere after the existing methods):

```dart
  Future<String?> getReadmePath() => _storage.read(key: _readmePath);

  Future<void> setReadmePath(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _readmePath);
    } else {
      await _storage.write(key: _readmePath, value: value);
    }
  }
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/storage/settings_readme_test.dart
flutter test test/storage/
```

Expected: PASS for the new test and for all pre-existing settings tests.

- [ ] **Step 5: Commit**

```bash
git add lib/storage/settings.dart test/storage/settings_readme_test.dart
git commit -m "feat(storage): add README path setting"
```

---

## Task 4: RunDao — `runById`, `taskRunById`, label-search `recentRuns`, `startRun(name)`

**Files:**
- Modify: `lib/storage/dao/run_dao.dart`
- Modify: `test/storage/run_dao_test.dart`

- [ ] **Step 1: Write failing tests by appending to `test/storage/run_dao_test.dart`**

Open `test/storage/run_dao_test.dart` and append the following inside `void main() { ... }` after the existing test:

```dart
  test('startRun persists optional name', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(
      runId: 'r1',
      startedAt: DateTime(2026, 5, 2),
      name: 'experiment-1',
    );
    final row = await dao.runById('r1');
    expect(row, isNotNull);
    expect(row!.name, 'experiment-1');
    await db.close();
  });

  test('runById returns null for unknown id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    expect(await dao.runById('nope'), isNull);
    await db.close();
  });

  test('taskRunById returns the matching task run', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 2));
    await dao.persistTaskRun(
      TaskRunResult(
        runId: 'r1',
        providerId: 'fake',
        modelId: 'm',
        taskId: 't',
        response: const ModelResponse(
          rawText: 'x',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        evaluations: const [],
        aggregateScore: 0.5,
        completedAt: DateTime(2026, 5, 2, 12),
      ),
    );
    final all = await dao.taskRunsForRun('r1');
    expect(all, hasLength(1));
    final fetched = await dao.taskRunById(all.first.id);
    expect(fetched, isNotNull);
    expect(fetched!.taskId, 't');
    await db.close();
  });

  test('recentRuns(labelQuery) filters by LIKE on name', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(
      runId: 'a',
      startedAt: DateTime(2026, 5, 1),
      name: 'deepseek vs claude',
    );
    await dao.startRun(
      runId: 'b',
      startedAt: DateTime(2026, 5, 2),
      name: 'gpt sweep',
    );
    await dao.startRun(runId: 'c', startedAt: DateTime(2026, 5, 3));

    final all = await dao.recentRuns();
    expect(all, hasLength(3));

    final filtered = await dao.recentRuns(labelQuery: 'deepseek');
    expect(filtered, hasLength(1));
    expect(filtered.first.id, 'a');

    final empty = await dao.recentRuns(labelQuery: 'nomatch');
    expect(empty, isEmpty);

    await db.close();
  });

  test('recentRuns ignores empty labelQuery', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'a', startedAt: DateTime(2026, 5, 1));
    final all = await dao.recentRuns(labelQuery: '');
    expect(all, hasLength(1));
    await db.close();
  });
```

If any imports referenced in these tests (`TaskRunResult`, `ModelResponse`) aren't already imported in the test file, add at the top:

```dart
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/storage/run_dao_test.dart
```

Expected: FAIL — `runById` / `taskRunById` undefined; `startRun` doesn't accept `name`; `recentRuns` doesn't accept `labelQuery`.

- [ ] **Step 3: Modify `lib/storage/dao/run_dao.dart`**

Replace the `startRun` method with:

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

Replace the `recentRuns` method with:

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

Add these two new methods anywhere after the existing methods inside the class:

```dart
  Future<Run?> runById(String id) {
    return (_db.select(_db.runs)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  Future<TaskRun?> taskRunById(String id) {
    return (_db.select(_db.taskRuns)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/storage/run_dao_test.dart
```

Expected: PASS for all (existing + new).

- [ ] **Step 5: Commit**

```bash
git add lib/storage/dao/run_dao.dart test/storage/run_dao_test.dart
git commit -m "feat(storage): RunDao adds runById, taskRunById, label search, startRun(name)"
```

---

## Task 5: `RunSummary` value object + `loadSummary` extension

**Files:**
- Create: `lib/storage/run_summary.dart`
- Test: `test/storage/run_summary_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/storage/run_summary_test.dart`:

```dart
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loadSummary returns null for unknown run', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    expect(await dao.loadSummary('nope'), isNull);
    await db.close();
  });

  test('loadSummary aggregates run, task runs, and evaluations', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(
      runId: 'r1',
      startedAt: DateTime(2026, 5, 2),
      name: 'demo',
    );
    await dao.persistTaskRun(
      TaskRunResult(
        runId: 'r1',
        providerId: 'fake',
        modelId: 'm',
        taskId: 't',
        response: const ModelResponse(
          rawText: 'x',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        evaluations: const [
          EvaluationResult(
            evaluatorId: 'compile',
            passed: true,
            score: 1.0,
          ),
          EvaluationResult(
            evaluatorId: 'test',
            passed: true,
            score: 0.8,
          ),
        ],
        aggregateScore: 0.9,
        completedAt: DateTime(2026, 5, 2, 12),
      ),
    );

    final summary = await dao.loadSummary('r1');
    expect(summary, isNotNull);
    expect(summary!.run.id, 'r1');
    expect(summary.run.name, 'demo');
    expect(summary.taskRuns, hasLength(1));
    final taskRunId = summary.taskRuns.first.id;
    expect(summary.evaluationsByTaskRunId[taskRunId], hasLength(2));
    final evalIds = summary
        .evaluationsByTaskRunId[taskRunId]!
        .map((e) => e.evaluatorId)
        .toSet();
    expect(evalIds, equals({'compile', 'test'}));

    await db.close();
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/storage/run_summary_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Create `lib/storage/run_summary.dart`**

```dart
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:equatable/equatable.dart';

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
    return RunSummary(
      run: run,
      taskRuns: trs,
      evaluationsByTaskRunId: evals,
    );
  }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/storage/run_summary_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/storage/run_summary.dart test/storage/run_summary_test.dart
git commit -m "feat(storage): add RunSummary value object and loadSummary extension"
```

---

## Task 6: `StartRun.name` + `RunBloc` propagation

**Files:**
- Modify: `lib/runner/run_event.dart`
- Modify: `lib/runner/run_bloc.dart`
- Modify: `test/runner/run_bloc_test.dart`

- [ ] **Step 1: Add a failing test by appending to `test/runner/run_bloc_test.dart`**

Open `test/runner/run_bloc_test.dart`. Append inside `void main() { ... }` after the existing test:

```dart
  test('StartRun.name is persisted via runDao.startRun', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_name_');
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: dao,
      now: DateTime.now,
      idGenerator: () => 'run-named',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(StartRun(
      tasks: [_StubTask()],
      providers: [_FakeProvider()],
      modelByProvider: const {'fake': 'fake-1'},
      evaluatorConfig: const EvaluatorConfig(),
      name: 'experiment-7',
    ));

    await Future.delayed(const Duration(seconds: 1));
    expect(states.last, isA<RunCompleted>());

    final row = await dao.runById('run-named');
    expect(row, isNotNull);
    expect(row!.name, 'experiment-7');

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/runner/run_bloc_test.dart
```

Expected: FAIL — `StartRun` constructor doesn't accept `name`.

- [ ] **Step 3: Modify `lib/runner/run_event.dart`**

Replace the `StartRun` class with:

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

  @override
  List<Object?> get props =>
      [tasks, providers, modelByProvider, evaluatorConfig, name];
}
```

- [ ] **Step 4: Modify `lib/runner/run_bloc.dart`**

Locate this line near the top of `_onStart`:

```dart
    await runDao.startRun(runId: runId, startedAt: now());
```

Replace with:

```dart
    await runDao.startRun(runId: runId, startedAt: now(), name: event.name);
```

No other bloc changes needed.

- [ ] **Step 5: Run, verify pass**

```bash
flutter test test/runner/run_bloc_test.dart
```

Expected: PASS for new test and existing test (existing test calls `StartRun` without `name`, which is allowed since `name` is optional).

- [ ] **Step 6: Commit**

```bash
git add lib/runner/run_event.dart lib/runner/run_bloc.dart test/runner/run_bloc_test.dart
git commit -m "feat(runner): StartRun carries optional name; RunBloc persists it"
```

---

## Task 7: `unified_diff.dart` (pure)

**Files:**
- Create: `lib/core/unified_diff.dart`
- Test: `test/core/unified_diff_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/core/unified_diff_test.dart`:

```dart
import 'package:dart_arena/core/unified_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeUnifiedDiff', () {
    test('identical inputs produce only context lines', () {
      const a = 'foo\nbar\nbaz\n';
      final result = computeUnifiedDiff(a, a);
      expect(result.every((l) => l.kind == DiffLineKind.context), isTrue);
      expect(result.map((l) => l.text).join(), a);
    });

    test('addition produces an added line', () {
      const a = 'foo\nbar\n';
      const b = 'foo\nbar\nbaz\n';
      final result = computeUnifiedDiff(a, b);
      final added = result.where((l) => l.kind == DiffLineKind.added).toList();
      expect(added, hasLength(1));
      expect(added.first.text, 'baz\n');
    });

    test('removal produces a removed line', () {
      const a = 'foo\nbar\nbaz\n';
      const b = 'foo\nbaz\n';
      final result = computeUnifiedDiff(a, b);
      final removed =
          result.where((l) => l.kind == DiffLineKind.removed).toList();
      expect(removed, hasLength(1));
      expect(removed.first.text, 'bar\n');
    });

    test('replace produces both removed and added', () {
      const a = 'foo\nbar\n';
      const b = 'foo\nBAZ\n';
      final result = computeUnifiedDiff(a, b);
      final removed = result.where((l) => l.kind == DiffLineKind.removed);
      final added = result.where((l) => l.kind == DiffLineKind.added);
      expect(removed.map((l) => l.text), contains('bar\n'));
      expect(added.map((l) => l.text), contains('BAZ\n'));
    });

    test('empty original to non-empty produces all-added', () {
      const a = '';
      const b = 'x\ny\n';
      final result = computeUnifiedDiff(a, b);
      expect(result.every((l) => l.kind == DiffLineKind.added), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/core/unified_diff_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `lib/core/unified_diff.dart`**

```dart
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:equatable/equatable.dart';

enum DiffLineKind { context, added, removed }

class DiffLine extends Equatable {
  const DiffLine(this.kind, this.text);

  final DiffLineKind kind;
  final String text;

  @override
  List<Object?> get props => [kind, text];
}

List<DiffLine> computeUnifiedDiff(String original, String generated) {
  final dmp = DiffMatchPatch();
  final lineArray = <String>[''];
  final lineHash = <String, int>{};

  String linesToChars(String text) {
    final chars = StringBuffer();
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final isLast = i == lines.length - 1;
      final line = isLast ? lines[i] : '${lines[i]}\n';
      if (line.isEmpty && isLast) continue;
      final existing = lineHash[line];
      if (existing != null) {
        chars.writeCharCode(existing);
      } else {
        lineArray.add(line);
        lineHash[line] = lineArray.length - 1;
        chars.writeCharCode(lineArray.length - 1);
      }
    }
    return chars.toString();
  }

  final aChars = linesToChars(original);
  final bChars = linesToChars(generated);
  final diffs = dmp.diff(aChars, bChars);
  dmp.diffCleanupSemantic(diffs);

  final out = <DiffLine>[];
  for (final d in diffs) {
    final kind = switch (d.operation) {
      DIFF_EQUAL => DiffLineKind.context,
      DIFF_INSERT => DiffLineKind.added,
      DIFF_DELETE => DiffLineKind.removed,
      _ => DiffLineKind.context,
    };
    for (final unit in d.text.runes) {
      out.add(DiffLine(kind, lineArray[unit]));
    }
  }
  return out;
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/core/unified_diff_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/unified_diff.dart test/core/unified_diff_test.dart
git commit -m "feat(core): add computeUnifiedDiff line-mode pure helper"
```

---

## Task 8: `csv_exporter.dart`

**Files:**
- Create: `lib/export/csv_exporter.dart`
- Test: `test/export/csv_exporter_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/export/csv_exporter_test.dart`:

```dart
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/export/csv_exporter.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:flutter_test/flutter_test.dart';

RunSummary _summary({String? name}) {
  final run = Run(
    id: 'r1',
    startedAt: DateTime.utc(2026, 5, 2, 14, 23),
    completedAt: DateTime.utc(2026, 5, 2, 14, 31),
    judgeModel: null,
    name: name,
  );
  final taskRun = TaskRun(
    id: 'tr1',
    runId: 'r1',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'bug.off_by_one',
    responseText: 'raw',
    promptTokens: 10,
    completionTokens: 20,
    latencyMs: 1500,
    aggregateScore: 0.85,
    completedAt: DateTime.utc(2026, 5, 2, 14, 24),
  );
  return RunSummary(
    run: run,
    taskRuns: [taskRun],
    evaluationsByTaskRunId: {
      'tr1': const [
        EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
        EvaluationResult(evaluatorId: 'analyze', passed: true, score: 0.9),
        EvaluationResult(evaluatorId: 'test', passed: true, score: 1.0),
      ],
    },
  );
}

void main() {
  test('header row contains all expected columns', () {
    final csv = runSummaryToCsv(_summary());
    final firstLine = csv.split('\n').first;
    expect(firstLine, startsWith('run_id,run_name,started_at,task_id'));
    expect(firstLine, contains('score_compile,score_analyze,score_test'));
    expect(firstLine, endsWith('latency_ms,prompt_tokens,completion_tokens'));
  });

  test('writes one row per task run with named run', () {
    final csv = runSummaryToCsv(_summary(name: 'demo'));
    final lines = csv.split('\n');
    expect(lines, hasLength(2));
    final values = lines[1].split(',');
    expect(values[0], 'r1');
    expect(values[1], 'demo');
    expect(values[3], 'bug.off_by_one');
    expect(values[4], 'openai');
    expect(values[5], 'gpt-5');
    expect(values[6], '0.8500');
    expect(values[7], '1.0000'); // compile
    expect(values[8], '0.9000'); // analyze
    expect(values[9], '1.0000'); // test
  });

  test('null run name renders as empty cell', () {
    final csv = runSummaryToCsv(_summary());
    final values = csv.split('\n')[1].split(',');
    expect(values[1], '');
  });

  test('missing evaluator score defaults to 0.0000', () {
    final s = _summary();
    final csv = runSummaryToCsv(s);
    final values = csv.split('\n')[1].split(',');
    // widget_tree, llm_judge, diff_size are missing; should be 0.0000
    expect(values[10], '0.0000');
    expect(values[11], '0.0000');
    expect(values[12], '0.0000');
  });

  test('CSV cells with commas are quoted', () {
    final s = _summary(name: 'one, two');
    final csv = runSummaryToCsv(s);
    expect(csv, contains('"one, two"'));
  });

  test('CSV cells with quotes have quotes doubled', () {
    final s = _summary(name: 'a "b" c');
    final csv = runSummaryToCsv(s);
    expect(csv, contains('"a ""b"" c"'));
  });

  test('empty task-runs produces only the header row', () {
    final empty = RunSummary(
      run: Run(
        id: 'r0',
        startedAt: DateTime.utc(2026, 5, 2),
        completedAt: null,
        judgeModel: null,
        name: null,
      ),
      taskRuns: const [],
      evaluationsByTaskRunId: const {},
    );
    final csv = runSummaryToCsv(empty);
    expect(csv.split('\n'), hasLength(1));
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/export/csv_exporter_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Create `lib/export/csv_exporter.dart`**

```dart
import 'package:dart_arena/storage/run_summary.dart';

const _evaluatorIds = <String>[
  'compile',
  'analyze',
  'test',
  'widget_tree',
  'llm_judge',
  'diff_size',
];

String runSummaryToCsv(RunSummary s) {
  final headers = <String>[
    'run_id',
    'run_name',
    'started_at',
    'task_id',
    'provider_id',
    'model_id',
    'aggregate_score',
    ..._evaluatorIds.map((e) => 'score_$e'),
    'latency_ms',
    'prompt_tokens',
    'completion_tokens',
  ];

  final rows = <List<String>>[headers];
  for (final tr in s.taskRuns) {
    final evals = <String, double>{};
    for (final e in s.evaluationsByTaskRunId[tr.id] ?? const []) {
      evals[e.evaluatorId] = e.score;
    }
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

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/export/csv_exporter_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/export/csv_exporter.dart test/export/csv_exporter_test.dart
git commit -m "feat(export): add runSummaryToCsv pure exporter"
```

---

## Task 9: `md_exporter.dart`

**Files:**
- Create: `lib/export/md_exporter.dart`
- Test: `test/export/md_exporter_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/export/md_exporter_test.dart`:

```dart
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/export/md_exporter.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:flutter_test/flutter_test.dart';

RunSummary _summary({String? name}) {
  final run = Run(
    id: 'r1',
    startedAt: DateTime.utc(2026, 5, 2, 14, 23),
    completedAt: DateTime.utc(2026, 5, 2, 14, 31),
    judgeModel: null,
    name: name,
  );
  final taskRun = TaskRun(
    id: 'tr1',
    runId: 'r1',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'bug.off_by_one',
    responseText: 'raw',
    promptTokens: 10,
    completionTokens: 20,
    latencyMs: 1500,
    aggregateScore: 0.85,
    completedAt: DateTime.utc(2026, 5, 2, 14, 24),
  );
  return RunSummary(
    run: run,
    taskRuns: [taskRun],
    evaluationsByTaskRunId: {
      'tr1': const [
        EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
        EvaluationResult(evaluatorId: 'analyze', passed: true, score: 0.9),
        EvaluationResult(evaluatorId: 'test', passed: true, score: 1.0),
      ],
    },
  );
}

void main() {
  test('renders heading, label, and metadata line', () {
    final md = runSummaryToMarkdown(_summary(name: 'demo'));
    expect(md, contains('# Benchmark run'));
    expect(md, contains('**demo**'));
    expect(md, contains('Started:'));
    expect(md, contains('Task-runs: 1'));
  });

  test('omits label line when name is null', () {
    final md = runSummaryToMarkdown(_summary());
    expect(md.contains('**'), isFalse);
  });

  test('renders a markdown table with one data row', () {
    final md = runSummaryToMarkdown(_summary());
    expect(md, contains('| Task | Provider | Model |'));
    expect(md, contains('|------|'));
    expect(md, contains('| bug.off_by_one | openai | gpt-5'));
    expect(md, contains('**0.85**'));
  });

  test('missing evaluator score renders as 0.00', () {
    final md = runSummaryToMarkdown(_summary());
    final dataLine = md
        .split('\n')
        .firstWhere((l) => l.contains('bug.off_by_one'));
    // widget_tree, llm_judge, diff_size missing => 0.00
    final zeroOccurrences = '0.00'.allMatches(dataLine).length;
    expect(zeroOccurrences, greaterThanOrEqualTo(3));
  });

  test('empty task-runs renders heading + empty table header', () {
    final empty = RunSummary(
      run: Run(
        id: 'r0',
        startedAt: DateTime.utc(2026, 5, 2),
        completedAt: null,
        judgeModel: null,
        name: null,
      ),
      taskRuns: const [],
      evaluationsByTaskRunId: const {},
    );
    final md = runSummaryToMarkdown(empty);
    expect(md, contains('# Benchmark run'));
    expect(md, contains('Task-runs: 0'));
    expect(md, contains('| Task |'));
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/export/md_exporter_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Create `lib/export/md_exporter.dart`**

```dart
import 'package:dart_arena/storage/run_summary.dart';

const _evaluatorIds = <String>[
  'compile',
  'analyze',
  'test',
  'widget_tree',
  'llm_judge',
  'diff_size',
];

String runSummaryToMarkdown(RunSummary s) {
  final buf = StringBuffer();
  final ts = s.run.startedAt.toIso8601String();
  buf.writeln('# Benchmark run');
  if (s.run.name != null) {
    buf.writeln('**${s.run.name}**');
  }
  buf.writeln('Started: `$ts`  ·  Task-runs: ${s.taskRuns.length}');
  buf.writeln();

  buf.writeln(
    '| Task | Provider | Model | Aggregate '
    '| compile | analyze | test | widget_tree | llm_judge | diff_size '
    '| Latency |',
  );
  buf.writeln(
    '|------|----------|-------|-----------'
    '|---------|---------|------|-------------|-----------|-----------'
    '|---------|',
  );
  for (final tr in s.taskRuns) {
    final evals = <String, double>{};
    for (final e in s.evaluationsByTaskRunId[tr.id] ?? const []) {
      evals[e.evaluatorId] = e.score;
    }
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

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/export/md_exporter_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/export/md_exporter.dart test/export/md_exporter_test.dart
git commit -m "feat(export): add runSummaryToMarkdown pure exporter"
```

---

## Task 10: `ReadmePublisher`

**Files:**
- Create: `lib/export/readme_publisher.dart`
- Test: `test/export/readme_publisher_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/export/readme_publisher_test.dart`:

```dart
import 'dart:io';

import 'package:dart_arena/export/readme_publisher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _markers = '''
# My Project

Some prose.

<!-- BENCHMARK_RESULTS:START -->
old content
<!-- BENCHMARK_RESULTS:END -->

More prose.
''';

void main() {
  late Directory tmp;
  late String readmePath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dart_arena_readme_');
    readmePath = p.join(tmp.path, 'README.md');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('publish replaces content between markers', () async {
    File(readmePath).writeAsStringSync(_markers);

    final pub = ReadmePublisher();
    final result = await pub.publish(
      readmePath: readmePath,
      generatedMarkdown: 'NEW CONTENT',
    );

    expect(result, isA<PublishOk>());
    final updated = File(readmePath).readAsStringSync();
    expect(updated, contains('# My Project'));
    expect(updated, contains('Some prose.'));
    expect(updated, contains('More prose.'));
    expect(updated, contains('NEW CONTENT'));
    expect(updated, isNot(contains('old content')));
  });

  test('publish preserves text before start and after end markers', () async {
    File(readmePath).writeAsStringSync(_markers);

    await ReadmePublisher().publish(
      readmePath: readmePath,
      generatedMarkdown: 'X',
    );

    final updated = File(readmePath).readAsStringSync();
    expect(updated.split('\n').first, '# My Project');
    expect(updated.trim().endsWith('More prose.'), isTrue);
  });

  test('publish fails when README does not exist', () async {
    final result = await ReadmePublisher().publish(
      readmePath: '/no/such/file.md',
      generatedMarkdown: 'X',
    );
    expect(result, isA<PublishFailed>());
    expect((result as PublishFailed).reason, contains('not found'));
  });

  test('publish fails when markers are missing', () async {
    File(readmePath).writeAsStringSync('# Just a README\n\nNo markers here.\n');
    final result = await ReadmePublisher().publish(
      readmePath: readmePath,
      generatedMarkdown: 'X',
    );
    expect(result, isA<PublishFailed>());
    expect((result as PublishFailed).reason, contains('Markers not found'));
  });

  test('publish fails when end marker comes before start marker', () async {
    File(readmePath).writeAsStringSync('''
<!-- BENCHMARK_RESULTS:END -->
backwards
<!-- BENCHMARK_RESULTS:START -->
''');
    final result = await ReadmePublisher().publish(
      readmePath: readmePath,
      generatedMarkdown: 'X',
    );
    expect(result, isA<PublishFailed>());
  });

  test('preview returns updated content without writing the file', () async {
    File(readmePath).writeAsStringSync(_markers);

    final preview = await ReadmePublisher().preview(
      readmePath: readmePath,
      generatedMarkdown: 'PREVIEW',
    );

    expect(preview, isA<PreviewOk>());
    expect((preview as PreviewOk).updatedContent, contains('PREVIEW'));

    // File on disk is untouched.
    final unchanged = File(readmePath).readAsStringSync();
    expect(unchanged, contains('old content'));
    expect(unchanged, isNot(contains('PREVIEW')));
  });

  test('preview surfaces missing file as PreviewFailed', () async {
    final preview = await ReadmePublisher().preview(
      readmePath: '/no/such/file.md',
      generatedMarkdown: 'X',
    );
    expect(preview, isA<PreviewFailed>());
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/export/readme_publisher_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Create `lib/export/readme_publisher.dart`**

```dart
import 'dart:io';

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

class ReadmePublisher {
  static const startMarker = '<!-- BENCHMARK_RESULTS:START -->';
  static const endMarker = '<!-- BENCHMARK_RESULTS:END -->';

  Future<PublishResult> publish({
    required String readmePath,
    required String generatedMarkdown,
  }) async {
    final result = await _splice(readmePath, generatedMarkdown);
    return switch (result) {
      _SpliceOk(:final updated) => () async {
          await File(readmePath).writeAsString(updated);
          return PublishOk(readmePath);
        }(),
      _SpliceFailed(:final reason) => PublishFailed(reason),
    };
  }

  Future<ReadmePreview> preview({
    required String readmePath,
    required String generatedMarkdown,
  }) async {
    final result = await _splice(readmePath, generatedMarkdown);
    return switch (result) {
      _SpliceOk(:final updated) => PreviewOk(updated),
      _SpliceFailed(:final reason) => PreviewFailed(reason),
    };
  }

  Future<_SpliceResult> _splice(
    String path,
    String generatedMarkdown,
  ) async {
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

sealed class _SpliceResult {
  const _SpliceResult();
}

class _SpliceOk extends _SpliceResult {
  const _SpliceOk(this.updated);
  final String updated;
}

class _SpliceFailed extends _SpliceResult {
  const _SpliceFailed(this.reason);
  final String reason;
}
```

The `publish` arm uses an immediately-invoked async closure to keep the file write inside the `switch`. If your Dart version rejects that pattern, use a plain `if`:

```dart
if (result is _SpliceOk) {
  await File(readmePath).writeAsString(result.updated);
  return PublishOk(readmePath);
}
return PublishFailed((result as _SpliceFailed).reason);
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/export/readme_publisher_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/export/readme_publisher.dart test/export/readme_publisher_test.dart
git commit -m "feat(export): add ReadmePublisher with marker splice and dry-run preview"
```

---

## Task 11: `ScoreChip` widget

**Files:**
- Create: `lib/ui/widgets/score_chip.dart`
- Test: `test/ui/widgets/score_chip_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/widgets/score_chip_test.dart`:

```dart
import 'package:dart_arena/ui/widgets/score_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders evaluator id and 2-decimal score', (tester) async {
    await tester.pumpWidget(_wrap(const ScoreChip(
      evaluatorId: 'compile',
      score: 0.875,
    )));
    expect(find.text('compile'), findsOneWidget);
    expect(find.text('0.88'), findsOneWidget);
  });

  testWidgets('null score renders as em-dash', (tester) async {
    await tester.pumpWidget(_wrap(const ScoreChip(
      evaluatorId: 'widget_tree',
      score: null,
    )));
    expect(find.text('—'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/ui/widgets/score_chip_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `lib/ui/widgets/score_chip.dart`**

```dart
import 'package:flutter/material.dart';

class ScoreChip extends StatelessWidget {
  const ScoreChip({
    super.key,
    required this.evaluatorId,
    required this.score,
  });

  final String evaluatorId;
  final double? score;

  Color _bg() {
    final s = score;
    if (s == null) return Colors.grey.shade700;
    if (s >= 0.8) return Colors.green.shade700;
    if (s >= 0.5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final label = score == null ? '—' : score!.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            evaluatorId,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/ui/widgets/score_chip_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/score_chip.dart test/ui/widgets/score_chip_test.dart
git commit -m "feat(ui): add ScoreChip widget"
```

---

## Task 12: `EvaluatorCard` widget

**Files:**
- Create: `lib/ui/widgets/evaluator_card.dart`
- Test: `test/ui/widgets/evaluator_card_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/widgets/evaluator_card_test.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/evaluator_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

Evaluation _eval({
  required String id,
  required bool passed,
  required double score,
  String? rationale,
  String detailsJson = '{}',
}) =>
    Evaluation(
      id: 'e1',
      taskRunId: 'tr1',
      evaluatorId: id,
      passed: passed,
      score: score,
      rationale: rationale,
      detailsJson: detailsJson,
    );

void main() {
  testWidgets('renders evaluator id, score, pass badge, rationale',
      (tester) async {
    await tester.pumpWidget(_wrap(EvaluatorCard(
      evaluation: _eval(
        id: 'compile',
        passed: true,
        score: 1.0,
        rationale: 'compiles cleanly',
      ),
    )));
    expect(find.text('compile'), findsOneWidget);
    expect(find.text('1.00'), findsOneWidget);
    expect(find.text('PASS'), findsOneWidget);
    expect(find.text('compiles cleanly'), findsOneWidget);
  });

  testWidgets('renders FAIL badge when passed is false', (tester) async {
    await tester.pumpWidget(_wrap(EvaluatorCard(
      evaluation: _eval(id: 'test', passed: false, score: 0.0),
    )));
    expect(find.text('FAIL'), findsOneWidget);
  });

  testWidgets('details JSON appears when expansion tile is tapped',
      (tester) async {
    await tester.pumpWidget(_wrap(EvaluatorCard(
      evaluation: _eval(
        id: 'analyze',
        passed: true,
        score: 0.9,
        detailsJson: '{"warnings": 1}',
      ),
    )));
    expect(find.textContaining('warnings'), findsNothing);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('warnings'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/ui/widgets/evaluator_card_test.dart
```

- [ ] **Step 3: Implement `lib/ui/widgets/evaluator_card.dart`**

```dart
import 'dart:convert';

import 'package:dart_arena/storage/database.dart';
import 'package:flutter/material.dart';

class EvaluatorCard extends StatelessWidget {
  const EvaluatorCard({super.key, required this.evaluation});

  final Evaluation evaluation;

  String _prettyJson() {
    try {
      final decoded = jsonDecode(evaluation.detailsJson);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } on FormatException {
      return evaluation.detailsJson;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  evaluation.evaluatorId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                _PassBadge(passed: evaluation.passed),
                const Spacer(),
                Text(evaluation.score.toStringAsFixed(2)),
              ],
            ),
            if (evaluation.rationale != null) ...[
              const SizedBox(height: 8),
              Text(evaluation.rationale!),
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Details'),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      _prettyJson(),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PassBadge extends StatelessWidget {
  const _PassBadge({required this.passed});
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: passed ? Colors.green.shade700 : Colors.red.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        passed ? 'PASS' : 'FAIL',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/ui/widgets/evaluator_card_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/evaluator_card.dart test/ui/widgets/evaluator_card_test.dart
git commit -m "feat(ui): add EvaluatorCard widget"
```

---

## Task 13: `DiffView` widget

**Files:**
- Create: `lib/ui/widgets/diff_view.dart`
- Test: `test/ui/widgets/diff_view_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/widgets/diff_view_test.dart`:

```dart
import 'package:dart_arena/core/unified_diff.dart';
import 'package:dart_arena/ui/widgets/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders one row per DiffLine with kind-based prefix',
      (tester) async {
    await tester.pumpWidget(_wrap(const DiffView(
      lines: [
        DiffLine(DiffLineKind.context, ' foo\n'),
        DiffLine(DiffLineKind.removed, 'bar\n'),
        DiffLine(DiffLineKind.added, 'BAR\n'),
      ],
    )));
    expect(find.textContaining('foo'), findsOneWidget);
    expect(find.textContaining('-'), findsWidgets);
    expect(find.textContaining('+'), findsWidgets);
    expect(find.textContaining('BAR'), findsOneWidget);
  });

  testWidgets('renders empty state for empty input', (tester) async {
    await tester.pumpWidget(_wrap(const DiffView(lines: [])));
    expect(find.text('No diff to show.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/ui/widgets/diff_view_test.dart
```

- [ ] **Step 3: Implement `lib/ui/widgets/diff_view.dart`**

```dart
import 'package:dart_arena/core/unified_diff.dart';
import 'package:flutter/material.dart';

class DiffView extends StatelessWidget {
  const DiffView({super.key, required this.lines});

  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Center(child: Text('No diff to show.'));
    }
    return ListView.builder(
      itemCount: lines.length,
      itemBuilder: (context, i) => _DiffLineRow(line: lines[i]),
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({required this.line});
  final DiffLine line;

  Color _bg(BuildContext context) {
    switch (line.kind) {
      case DiffLineKind.added:
        return Colors.green.withValues(alpha: 0.2);
      case DiffLineKind.removed:
        return Colors.red.withValues(alpha: 0.2);
      case DiffLineKind.context:
        return Colors.transparent;
    }
  }

  String _prefix() {
    switch (line.kind) {
      case DiffLineKind.added:
        return '+ ';
      case DiffLineKind.removed:
        return '- ';
      case DiffLineKind.context:
        return '  ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _bg(context),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: SelectableText(
        '${_prefix()}${line.text.replaceAll('\n', '')}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/ui/widgets/diff_view_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/diff_view.dart test/ui/widgets/diff_view_test.dart
git commit -m "feat(ui): add DiffView widget"
```

---

## Task 14: `RunMatrix` widget

**Files:**
- Create: `lib/ui/widgets/run_matrix.dart`
- Test: `test/ui/widgets/run_matrix_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/widgets/run_matrix_test.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/run_matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TaskRun _tr(String taskId, String providerId, String modelId, double score) =>
    TaskRun(
      id: '$taskId-$providerId-$modelId',
      runId: 'r1',
      providerId: providerId,
      modelId: modelId,
      taskId: taskId,
      responseText: '',
      promptTokens: null,
      completionTokens: null,
      latencyMs: 1,
      aggregateScore: score,
      completedAt: DateTime(2026, 5, 2),
    );

void main() {
  testWidgets('renders one row per task and one column per provider/model',
      (tester) async {
    final taskRuns = [
      _tr('bug.a', 'openai', 'gpt-5', 0.9),
      _tr('bug.a', 'anthropic', 'sonnet', 0.7),
      _tr('state.b', 'openai', 'gpt-5', 1.0),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunMatrix(
          taskRuns: taskRuns,
          onCellTap: (_) {},
        ),
      ),
    ));

    expect(find.text('bug.a'), findsOneWidget);
    expect(find.text('state.b'), findsOneWidget);
    expect(find.text('openai/gpt-5'), findsOneWidget);
    expect(find.text('anthropic/sonnet'), findsOneWidget);
    expect(find.text('0.90'), findsOneWidget);
    expect(find.text('1.00'), findsOneWidget);
  });

  testWidgets('cell tap invokes callback with the right task run',
      (tester) async {
    final taskRuns = [_tr('bug.a', 'openai', 'gpt-5', 0.9)];
    TaskRun? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunMatrix(
          taskRuns: taskRuns,
          onCellTap: (tr) => tapped = tr,
        ),
      ),
    ));
    await tester.tap(find.text('0.90'));
    expect(tapped, isNotNull);
    expect(tapped!.taskId, 'bug.a');
  });

  testWidgets('renders em-dash for missing cells', (tester) async {
    final taskRuns = [
      _tr('bug.a', 'openai', 'gpt-5', 0.9),
      _tr('state.b', 'anthropic', 'sonnet', 1.0),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunMatrix(taskRuns: taskRuns, onCellTap: (_) {}),
      ),
    ));
    // bug.a x anthropic/sonnet and state.b x openai/gpt-5 are missing.
    expect(find.text('—'), findsNWidgets(2));
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/ui/widgets/run_matrix_test.dart
```

- [ ] **Step 3: Implement `lib/ui/widgets/run_matrix.dart`**

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:flutter/material.dart';

typedef RunMatrixCellTap = void Function(TaskRun taskRun);

class RunMatrix extends StatelessWidget {
  const RunMatrix({
    super.key,
    required this.taskRuns,
    required this.onCellTap,
  });

  final List<TaskRun> taskRuns;
  final RunMatrixCellTap onCellTap;

  List<String> get _taskIds {
    final seen = <String>{};
    final out = <String>[];
    for (final tr in taskRuns) {
      if (seen.add(tr.taskId)) out.add(tr.taskId);
    }
    return out;
  }

  List<String> get _columnKeys {
    final seen = <String>{};
    final out = <String>[];
    for (final tr in taskRuns) {
      final k = '${tr.providerId}/${tr.modelId}';
      if (seen.add(k)) out.add(k);
    }
    return out;
  }

  Color _tint(double s) {
    if (s >= 0.8) return Colors.green.withValues(alpha: 0.25);
    if (s >= 0.5) return Colors.orange.withValues(alpha: 0.25);
    return Colors.red.withValues(alpha: 0.25);
  }

  TaskRun? _cell(String taskId, String columnKey) {
    for (final tr in taskRuns) {
      if (tr.taskId == taskId &&
          '${tr.providerId}/${tr.modelId}' == columnKey) {
        return tr;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final taskIds = _taskIds;
    final columns = _columnKeys;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Task')),
            ...columns.map((c) => DataColumn(label: Text(c))),
          ],
          rows: [
            for (final taskId in taskIds)
              DataRow(cells: [
                DataCell(Text(taskId)),
                ...columns.map((c) {
                  final tr = _cell(taskId, c);
                  if (tr == null) {
                    return const DataCell(Text('—'));
                  }
                  return DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _tint(tr.aggregateScore),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(tr.aggregateScore.toStringAsFixed(2)),
                    ),
                    onTap: () => onCellTap(tr),
                  );
                }),
              ]),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/ui/widgets/run_matrix_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/run_matrix.dart test/ui/widgets/run_matrix_test.dart
git commit -m "feat(ui): add RunMatrix task x model widget"
```

---

## Task 15: `RunHistoryPage` + route

**Files:**
- Create: `lib/ui/pages/run_history_page.dart`
- Modify: `lib/app.dart`
- Test: `test/ui/pages/run_history_page_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/pages/run_history_page_test.dart`:

```dart
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/pages/run_history_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RunDao> _seed({String? labelA, String? labelB}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(
    runId: 'a',
    startedAt: DateTime(2026, 5, 2, 10),
    name: labelA,
  );
  await dao.persistTaskRun(TaskRunResult(
    runId: 'a',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'bug.a',
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    ),
    evaluations: const [
      EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
    ],
    aggregateScore: 1.0,
    completedAt: DateTime(2026, 5, 2, 10, 5),
  ));
  await dao.startRun(
    runId: 'b',
    startedAt: DateTime(2026, 5, 1),
    name: labelB,
  );
  return dao;
}

void main() {
  testWidgets('shows empty state when no runs', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(MaterialApp(
      home: RunHistoryPage(dao: RunDao(db)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No runs yet'), findsOneWidget);
  });

  testWidgets('lists runs with labels and timestamp fallback',
      (tester) async {
    final dao = await _seed(labelA: 'experiment-1');
    await tester.pumpWidget(MaterialApp(
      home: RunHistoryPage(dao: dao),
    ));
    await tester.pumpAndSettle();
    expect(find.text('experiment-1'), findsOneWidget);
    expect(find.text('Run b'), findsOneWidget);
  });

  testWidgets('label search filters the list', (tester) async {
    final dao = await _seed(labelA: 'deepseek vs claude', labelB: 'gpt sweep');
    await tester.pumpWidget(MaterialApp(
      home: RunHistoryPage(dao: dao),
    ));
    await tester.pumpAndSettle();
    expect(find.text('deepseek vs claude'), findsOneWidget);
    expect(find.text('gpt sweep'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'deepseek');
    await tester.pumpAndSettle();

    expect(find.text('deepseek vs claude'), findsOneWidget);
    expect(find.text('gpt sweep'), findsNothing);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/ui/pages/run_history_page_test.dart
```

- [ ] **Step 3: Create `lib/ui/pages/run_history_page.dart`**

```dart
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RunHistoryPage extends StatefulWidget {
  const RunHistoryPage({super.key, this.dao});

  final RunDao? dao;

  @override
  State<RunHistoryPage> createState() => _RunHistoryPageState();
}

class _RunHistoryPageState extends State<RunHistoryPage> {
  late final RunDao _dao;
  AppDatabase? _ownedDb;
  String _query = '';
  Future<List<_RunRowData>>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.dao == null) {
      _ownedDb = AppDatabase();
      _dao = RunDao(_ownedDb!);
    } else {
      _dao = widget.dao!;
    }
    _refresh();
  }

  @override
  void dispose() {
    _ownedDb?.close();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<List<_RunRowData>> _load() async {
    final runs = await _dao.recentRuns(labelQuery: _query);
    final out = <_RunRowData>[];
    for (final run in runs) {
      final taskRuns = await _dao.taskRunsForRun(run.id);
      out.add(_RunRowData(run: run, taskRuns: taskRuns));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Runs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Filter by label',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                _query = v;
                _refresh();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<_RunRowData>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('No runs yet — start one from the home page.'),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _RunTile(
                    data: rows[i],
                    onTap: () => context.push('/runs/${rows[i].run.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RunRowData {
  const _RunRowData({required this.run, required this.taskRuns});
  final Run run;
  final List<TaskRun> taskRuns;
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.data, required this.onTap});

  final _RunRowData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final run = data.run;
    final title = run.name ?? 'Run ${run.id}';
    final taskCount = data.taskRuns.map((t) => t.taskId).toSet().length;
    final modelCount = data.taskRuns
        .map((t) => '${t.providerId}/${t.modelId}')
        .toSet()
        .length;
    final avg = data.taskRuns.isEmpty
        ? null
        : data.taskRuns.map((t) => t.aggregateScore).reduce((a, b) => a + b) /
            data.taskRuns.length;
    final ts = run.startedAt.toIso8601String();
    return ListTile(
      title: Text(title),
      subtitle: Text(
        '$ts · $taskCount tasks · $modelCount models'
        '${avg == null ? '' : ' · avg ${avg.toStringAsFixed(2)}'}',
      ),
      trailing: run.completedAt == null
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Add the route to `lib/app.dart`**

In the `_router` `routes:` list, add the entry between `'/run'` and `'/settings'`:

```dart
    GoRoute(path: '/runs', builder: (_, __) => const RunHistoryPage()),
```

Add the import at the top of the file:

```dart
import 'package:dart_arena/ui/pages/run_history_page.dart';
```

- [ ] **Step 5: Run, verify pass and analyze clean**

```bash
flutter test test/ui/pages/run_history_page_test.dart
flutter analyze
```

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/run_history_page.dart lib/app.dart test/ui/pages/run_history_page_test.dart
git commit -m "feat(ui): add RunHistoryPage with date sort and label search"
```

---

## Task 16: `RunDetailsPage` (replaces stub) + route

**Files:**
- Create / Replace: `lib/ui/pages/run_details_page.dart`
- Modify: `lib/app.dart`
- Test: `test/ui/pages/run_details_page_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/pages/run_details_page_test.dart`:

```dart
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/ui/pages/run_details_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RunDao> _seedRun() async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(
    runId: 'r1',
    startedAt: DateTime(2026, 5, 2, 14, 23),
    name: 'demo',
  );
  await dao.persistTaskRun(TaskRunResult(
    runId: 'r1',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'bug.a',
    response: const ModelResponse(
      rawText: 'x',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    ),
    evaluations: const [
      EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
    ],
    aggregateScore: 0.92,
    completedAt: DateTime(2026, 5, 2, 14, 24),
  ));
  await dao.finishRun('r1', DateTime(2026, 5, 2, 14, 31));
  return dao;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders title, header, and matrix score', (tester) async {
    final dao = await _seedRun();
    await tester.pumpWidget(MaterialApp(
      home: RunDetailsPage(runId: 'r1', dao: dao),
    ));
    await tester.pumpAndSettle();
    expect(find.text('demo'), findsOneWidget);
    expect(find.text('bug.a'), findsOneWidget);
    expect(find.text('openai/gpt-5'), findsOneWidget);
    expect(find.text('0.92'), findsOneWidget);
  });

  testWidgets('publish to README disabled when path unset', (tester) async {
    final dao = await _seedRun();
    await tester.pumpWidget(MaterialApp(
      home: RunDetailsPage(runId: 'r1', dao: dao),
    ));
    await tester.pumpAndSettle();
    final btn = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Publish to README'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('shows missing-run banner for unknown id', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(MaterialApp(
      home: RunDetailsPage(runId: 'nope', dao: RunDao(db)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Run not found'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/ui/pages/run_details_page_test.dart
```

- [ ] **Step 3: Create `lib/ui/pages/run_details_page.dart`** (this replaces any earlier stub at the same path)

```dart
import 'dart:io';

import 'package:dart_arena/export/csv_exporter.dart';
import 'package:dart_arena/export/md_exporter.dart';
import 'package:dart_arena/export/readme_publisher.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/ui/widgets/run_matrix.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RunDetailsPage extends StatefulWidget {
  const RunDetailsPage({
    super.key,
    required this.runId,
    this.dao,
    this.settings,
    this.publisher,
  });

  final String runId;
  final RunDao? dao;
  final SettingsRepository? settings;
  final ReadmePublisher? publisher;

  @override
  State<RunDetailsPage> createState() => _RunDetailsPageState();
}

class _RunDetailsPageState extends State<RunDetailsPage> {
  late final RunDao _dao;
  late final SettingsRepository _settings;
  late final ReadmePublisher _publisher;
  AppDatabase? _ownedDb;
  Future<RunSummary?>? _future;
  String? _readmePath;

  @override
  void initState() {
    super.initState();
    if (widget.dao == null) {
      _ownedDb = AppDatabase();
      _dao = RunDao(_ownedDb!);
    } else {
      _dao = widget.dao!;
    }
    _settings = widget.settings ?? SettingsRepository();
    _publisher = widget.publisher ?? ReadmePublisher();
    _future = _dao.loadSummary(widget.runId);
    _settings.getReadmePath().then((p) {
      if (mounted) setState(() => _readmePath = p);
    });
  }

  @override
  void dispose() {
    _ownedDb?.close();
    super.dispose();
  }

  Future<void> _saveCsv(RunSummary s) async {
    final csv = runSummaryToCsv(s);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save run as CSV',
      fileName: 'run-${s.run.id}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;
    await File(path).writeAsString(csv);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $path')),
    );
  }

  Future<void> _saveMd(RunSummary s) async {
    final md = runSummaryToMarkdown(s);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save run as Markdown',
      fileName: 'run-${s.run.id}.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
    );
    if (path == null) return;
    await File(path).writeAsString(md);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $path')),
    );
  }

  Future<void> _publishToReadme(RunSummary s) async {
    if (_readmePath == null) return;
    final md = runSummaryToMarkdown(s);
    final preview = await _publisher.preview(
      readmePath: _readmePath!,
      generatedMarkdown: md,
    );
    if (!mounted) return;

    if (preview is PreviewFailed) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot publish'),
          content: SingleChildScrollView(child: Text(preview.reason)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final updated = (preview as PreviewOk).updatedContent;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Publish to README'),
        content: SizedBox(
          width: 700,
          height: 500,
          child: SingleChildScrollView(
            child: SelectableText(
              updated,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _publisher.publish(
      readmePath: _readmePath!,
      generatedMarkdown: md,
    );
    if (!mounted) return;
    final msg = result is PublishOk
        ? 'Published to ${result.path}'
        : 'Failed: ${(result as PublishFailed).reason}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run details')),
      body: FutureBuilder<RunSummary?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = snap.data;
          if (summary == null) {
            return const Center(child: Text('Run not found.'));
          }
          final inProgress = summary.run.completedAt == null;
          final canPublish = _readmePath != null && !inProgress;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.run.name ?? 'Run ${summary.run.id}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Started ${summary.run.startedAt.toIso8601String()} '
                            '· ${inProgress ? 'in progress' : 'completed ${summary.run.completedAt!.toIso8601String()}'} '
                            '· ${summary.taskRuns.length} task-runs',
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: inProgress ? null : () => _saveCsv(summary),
                          child: const Text('Export CSV'),
                        ),
                        TextButton(
                          onPressed: inProgress ? null : () => _saveMd(summary),
                          child: const Text('Export Markdown'),
                        ),
                        Tooltip(
                          message: _readmePath == null
                              ? 'Set README path in Settings'
                              : '',
                          child: TextButton(
                            onPressed: canPublish
                                ? () => _publishToReadme(summary)
                                : null,
                            child: const Text('Publish to README'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (inProgress)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Color(0xFF333333),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Run still in progress; results will appear as task-runs complete.',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: summary.taskRuns.isEmpty
                    ? const Center(
                        child: Text(
                          'Run failed before any task completed.',
                        ),
                      )
                    : RunMatrix(
                        taskRuns: summary.taskRuns,
                        onCellTap: (tr) => context.push(
                          '/runs/${summary.run.id}/task-runs/${tr.id}',
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Add the route to `lib/app.dart`**

In the `_router` `routes:` list, add (after the `/runs` route):

```dart
    GoRoute(
      path: '/runs/:runId',
      builder: (c, state) =>
          RunDetailsPage(runId: state.pathParameters['runId']!),
    ),
```

Add the import:

```dart
import 'package:dart_arena/ui/pages/run_details_page.dart';
```

- [ ] **Step 5: Run, verify pass**

```bash
flutter test test/ui/pages/run_details_page_test.dart
flutter analyze
```

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/run_details_page.dart lib/app.dart test/ui/pages/run_details_page_test.dart
git commit -m "feat(ui): RunDetailsPage with summary matrix, CSV/MD export, README publish"
```

---

## Task 17: `TaskRunDetailsPage` + route

**Files:**
- Create: `lib/ui/pages/task_run_details_page.dart`
- Modify: `lib/app.dart`
- Test: `test/ui/pages/task_run_details_page_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/pages/task_run_details_page_test.dart`:

```dart
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/pages/task_run_details_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubTask extends BenchmarkTask {
  @override
  String get id => 'stub.task';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'fix it';
  @override
  Map<String, String> get fixtures => const {
        'lib/orig.dart': 'int answer() => 41;\n',
      };
  @override
  String get generatedCodePath => 'lib/orig.dart';
  @override
  String? get judgeRubric => 'be strict';
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<({RunDao dao, String taskRunId})> _seed() async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 2));
  await dao.persistTaskRun(TaskRunResult(
    runId: 'r1',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'stub.task',
    response: const ModelResponse(
      rawText: '```dart\nint answer() => 42;\n```',
      extractedCode: 'int answer() => 42;\n',
      promptTokens: 10,
      completionTokens: 5,
      latency: Duration(milliseconds: 1500),
    ),
    evaluations: const [
      EvaluationResult(
        evaluatorId: 'compile',
        passed: true,
        score: 1.0,
        rationale: 'compiles',
      ),
    ],
    aggregateScore: 0.95,
    completedAt: DateTime(2026, 5, 2, 12),
  ));
  final all = await dao.taskRunsForRun('r1');
  return (dao: dao, taskRunId: all.first.id);
}

void main() {
  testWidgets('header shows provider/model/task and aggregate score',
      (tester) async {
    final seeded = await _seed();
    final reg = TaskRegistry()..register(_StubTask());
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: reg,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('openai'), findsWidgets);
    expect(find.textContaining('gpt-5'), findsWidgets);
    expect(find.textContaining('stub.task'), findsWidgets);
    expect(find.text('0.95'), findsWidgets);
  });

  testWidgets('switching to Diff tab renders diff lines', (tester) async {
    final seeded = await _seed();
    final reg = TaskRegistry()..register(_StubTask());
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: reg,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diff'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+ '), findsWidgets);
    expect(find.textContaining('- '), findsWidgets);
  });

  testWidgets('Diff tab shows empty state when task has no fixture at path',
      (tester) async {
    final seeded = await _seed();
    final emptyReg = TaskRegistry();
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: emptyReg,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diff'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no original'), findsOneWidget);
  });

  testWidgets('Evaluations tab renders one card per evaluator',
      (tester) async {
    final seeded = await _seed();
    final reg = TaskRegistry()..register(_StubTask());
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: reg,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evaluations'));
    await tester.pumpAndSettle();
    expect(find.text('compile'), findsOneWidget);
    expect(find.text('PASS'), findsOneWidget);
  });

  testWidgets('Prompt tab shows task prompt and rubric', (tester) async {
    final seeded = await _seed();
    final reg = TaskRegistry()..register(_StubTask());
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: reg,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prompt'));
    await tester.pumpAndSettle();
    expect(find.text('fix it'), findsOneWidget);
    expect(find.text('be strict'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/ui/pages/task_run_details_page_test.dart
```

- [ ] **Step 3: Create `lib/ui/pages/task_run_details_page.dart`**

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/core/unified_diff.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/diff_view.dart';
import 'package:dart_arena/ui/widgets/evaluator_card.dart';
import 'package:dart_arena/ui/widgets/score_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TaskRunDetailsPage extends StatefulWidget {
  const TaskRunDetailsPage({
    super.key,
    required this.runId,
    required this.taskRunId,
    this.dao,
    this.registry,
  });

  final String runId;
  final String taskRunId;
  final RunDao? dao;
  final TaskRegistry? registry;

  @override
  State<TaskRunDetailsPage> createState() => _TaskRunDetailsPageState();
}

class _TaskRunDetailsPageState extends State<TaskRunDetailsPage> {
  late final RunDao _dao;
  late final TaskRegistry _registry;
  AppDatabase? _ownedDb;
  Future<_TaskRunBundle?>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.dao == null) {
      _ownedDb = AppDatabase();
      _dao = RunDao(_ownedDb!);
    } else {
      _dao = widget.dao!;
    }
    _registry = widget.registry ?? TaskRegistry();
    _future = _load();
  }

  @override
  void dispose() {
    _ownedDb?.close();
    super.dispose();
  }

  Future<_TaskRunBundle?> _load() async {
    final tr = await _dao.taskRunById(widget.taskRunId);
    if (tr == null) return null;
    final evals = await _dao.evaluationsForTaskRun(tr.id);
    final task = _registry.byId(tr.taskId);
    return _TaskRunBundle(taskRun: tr, evaluations: evals, task: task);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task run')),
      body: FutureBuilder<_TaskRunBundle?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snap.data;
          if (bundle == null) {
            return const Center(child: Text('Task run not found.'));
          }
          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                _Header(bundle: bundle),
                _ScoreStrip(evaluations: bundle.evaluations),
                const TabBar(
                  tabs: [
                    Tab(text: 'Output'),
                    Tab(text: 'Diff'),
                    Tab(text: 'Evaluations'),
                    Tab(text: 'Prompt'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OutputTab(taskRun: bundle.taskRun),
                      _DiffTab(bundle: bundle),
                      _EvaluationsTab(evaluations: bundle.evaluations),
                      _PromptTab(task: bundle.task),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskRunBundle {
  const _TaskRunBundle({
    required this.taskRun,
    required this.evaluations,
    required this.task,
  });
  final TaskRun taskRun;
  final List<Evaluation> evaluations;
  final BenchmarkTask? task;
}

class _Header extends StatelessWidget {
  const _Header({required this.bundle});
  final _TaskRunBundle bundle;

  @override
  Widget build(BuildContext context) {
    final tr = bundle.taskRun;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tr.providerId} / ${tr.modelId} / ${tr.taskId}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${tr.completedAt.toIso8601String()} '
            '· agg ${tr.aggregateScore.toStringAsFixed(2)} '
            '· ${tr.latencyMs}ms '
            '· ${tr.promptTokens ?? '?'}/${tr.completionTokens ?? '?'} tokens',
          ),
        ],
      ),
    );
  }
}

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({required this.evaluations});
  final List<Evaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: evaluations
            .map(
              (e) => ScoreChip(evaluatorId: e.evaluatorId, score: e.score),
            )
            .toList(),
      ),
    );
  }
}

class _OutputTab extends StatefulWidget {
  const _OutputTab({required this.taskRun});
  final TaskRun taskRun;

  @override
  State<_OutputTab> createState() => _OutputTabState();
}

class _OutputTabState extends State<_OutputTab> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final tr = widget.taskRun;
    final raw = tr.responseText;
    final extracted = _extractDart(raw) ?? raw;
    final shown = _showRaw ? raw : extracted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Extracted code')),
                  ButtonSegment(value: true, label: Text('Raw output')),
                ],
                selected: {_showRaw},
                onSelectionChanged: (s) =>
                    setState(() => _showRaw = s.first),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shown));
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: SelectableText(
              shown,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  String? _extractDart(String raw) {
    final dart = RegExp(r'```dart\s*\n([\s\S]*?)\n```').firstMatch(raw);
    if (dart != null) return '${dart.group(1)!}\n';
    final any = RegExp(r'```\s*\n([\s\S]*?)\n```').firstMatch(raw);
    if (any != null) return '${any.group(1)!}\n';
    return null;
  }
}

class _DiffTab extends StatelessWidget {
  const _DiffTab({required this.bundle});
  final _TaskRunBundle bundle;

  @override
  Widget build(BuildContext context) {
    final task = bundle.task;
    if (task == null) {
      return const Center(
        child: Text('Task no longer registered; no original to diff against.'),
      );
    }
    final original = task.fixtures[task.generatedCodePath];
    if (original == null) {
      return const Center(
        child: Text(
          'Task has no original at this path to diff against.',
        ),
      );
    }
    final extracted = _extractDart(bundle.taskRun.responseText) ??
        bundle.taskRun.responseText;
    final lines = computeUnifiedDiff(original, extracted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy diff',
            onPressed: () {
              final buf = StringBuffer();
              for (final l in lines) {
                final prefix = switch (l.kind) {
                  DiffLineKind.added => '+',
                  DiffLineKind.removed => '-',
                  DiffLineKind.context => ' ',
                };
                buf.write('$prefix ${l.text}');
              }
              Clipboard.setData(ClipboardData(text: buf.toString()));
            },
          ),
        ),
        Expanded(child: DiffView(lines: lines)),
      ],
    );
  }

  String? _extractDart(String raw) {
    final dart = RegExp(r'```dart\s*\n([\s\S]*?)\n```').firstMatch(raw);
    if (dart != null) return '${dart.group(1)!}\n';
    final any = RegExp(r'```\s*\n([\s\S]*?)\n```').firstMatch(raw);
    if (any != null) return '${any.group(1)!}\n';
    return null;
  }
}

class _EvaluationsTab extends StatelessWidget {
  const _EvaluationsTab({required this.evaluations});
  final List<Evaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    if (evaluations.isEmpty) {
      return const Center(child: Text('No evaluations recorded.'));
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: evaluations
          .map((e) => EvaluatorCard(evaluation: e))
          .toList(),
    );
  }
}

class _PromptTab extends StatelessWidget {
  const _PromptTab({required this.task});
  final BenchmarkTask? task;

  @override
  Widget build(BuildContext context) {
    if (task == null) {
      return const Center(
        child: Text('Task no longer registered; prompt unavailable.'),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prompt',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText(task!.prompt),
          if (task!.judgeRubric != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Judge rubric'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SelectableText(task!.judgeRubric!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Add the route to `lib/app.dart`**

In the `_router` `routes:` list, add (after the `/runs/:runId` route):

```dart
    GoRoute(
      path: '/runs/:runId/task-runs/:taskRunId',
      builder: (c, state) => TaskRunDetailsPage(
        runId: state.pathParameters['runId']!,
        taskRunId: state.pathParameters['taskRunId']!,
      ),
    ),
```

Add the import:

```dart
import 'package:dart_arena/ui/pages/task_run_details_page.dart';
```

- [ ] **Step 5: Run, verify pass**

```bash
flutter test test/ui/pages/task_run_details_page_test.dart
flutter analyze
```

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/task_run_details_page.dart lib/app.dart test/ui/pages/task_run_details_page_test.dart
git commit -m "feat(ui): TaskRunDetailsPage with header, score strip, and 4 tabs"
```

---

## Task 18: `task_catalog.dart` + `NewRunPage` modifications (label + task picker)

**Files:**
- Create: `lib/tasks/task_catalog.dart`
- Modify: `lib/ui/pages/new_run_page.dart`
- Test: `test/ui/pages/new_run_page_test.dart`

- [ ] **Step 1: Create the catalog**

`lib/tasks/task_catalog.dart`:

```dart
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';

TaskRegistry buildDefaultTaskRegistry() {
  final registry = TaskRegistry();
  registry.register(OffByOnePaginationTask());
  return registry;
}
```

- [ ] **Step 2: Write a failing widget test**

Create `test/ui/pages/new_run_page_test.dart`:

```dart
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/ui/pages/new_run_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubTaskA extends BenchmarkTask {
  @override
  String get id => 'bug.a';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/x.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

class _StubTaskB extends BenchmarkTask {
  @override
  String get id => 'state.b';
  @override
  Category get category => Category.stateManagement;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/x.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders task picker with category groups', (tester) async {
    final reg = TaskRegistry()
      ..register(_StubTaskA())
      ..register(_StubTaskB());

    await tester.pumpWidget(MaterialApp(
      home: NewRunPage(
        registry: reg,
        providers: const [],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bug fix'), findsOneWidget);
    expect(find.text('State management'), findsOneWidget);
    expect(find.text('bug.a'), findsOneWidget);
    expect(find.text('state.b'), findsOneWidget);
  });

  testWidgets('label TextField is present', (tester) async {
    final reg = TaskRegistry()..register(_StubTaskA());
    await tester.pumpWidget(MaterialApp(
      home: NewRunPage(registry: reg, providers: const []),
    ));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Label this run (optional)'),
        findsOneWidget);
  });

  testWidgets('Run button is disabled when no tasks selected',
      (tester) async {
    final reg = TaskRegistry()..register(_StubTaskA());
    await tester.pumpWidget(MaterialApp(
      home: NewRunPage(registry: reg, providers: const []),
    ));
    await tester.pumpAndSettle();
    // First, deselect the pre-selected task.
    await tester.tap(find.text('bug.a'));
    await tester.pumpAndSettle();
    final btn =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Run'));
    expect(btn.onPressed, isNull);
  });
}
```

This test asserts a constructor signature `NewRunPage({required TaskRegistry registry, required List<ModelProvider> providers, ...})`. Step 3 implements that.

- [ ] **Step 3: Run, verify fail**

```bash
flutter test test/ui/pages/new_run_page_test.dart
```

- [ ] **Step 4: Replace `lib/ui/pages/new_run_page.dart`**

```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/provider_factory.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NewRunPage extends StatefulWidget {
  const NewRunPage({super.key, this.registry, this.providers});

  final TaskRegistry? registry;
  final List<ModelProvider>? providers;

  @override
  State<NewRunPage> createState() => _NewRunPageState();
}

class _NewRunPageState extends State<NewRunPage> {
  late final TaskRegistry _registry;
  List<ModelProvider> _providers = [];
  final Map<String, bool> _checkedProvider = {};
  final Map<String, String> _models = {};
  final Set<String> _selectedTaskIds = {};
  String _label = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _registry = widget.registry ?? buildDefaultTaskRegistry();
    for (final t in _registry.all()) {
      _selectedTaskIds.add(t.id);
    }
    if (widget.providers != null) {
      _providers = widget.providers!;
      _loading = false;
    } else {
      _loadProviders();
    }
  }

  Future<void> _loadProviders() async {
    final p = await buildEnabledProviders(SettingsRepository());
    if (!mounted) return;
    setState(() {
      _providers = p;
      _loading = false;
    });
  }

  bool get _canRun {
    if (_selectedTaskIds.isEmpty) return false;
    final selectedProviders =
        _providers.where((p) => _checkedProvider[p.id] == true).toList();
    if (selectedProviders.isEmpty) return false;
    for (final pr in selectedProviders) {
      final m = _models[pr.id];
      if (m == null || m.trim().isEmpty) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Run')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _LabelField(onChanged: (v) => _label = v),
                      const SizedBox(height: 16),
                      _TaskPicker(
                        registry: _registry,
                        selected: _selectedTaskIds,
                        onChanged: (id, v) => setState(() {
                          if (v) {
                            _selectedTaskIds.add(id);
                          } else {
                            _selectedTaskIds.remove(id);
                          }
                        }),
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Providers',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      ..._providers.map(
                        (provider) => _ProviderRow(
                          provider: provider,
                          checked: _checkedProvider[provider.id] ?? false,
                          onChecked: (v) => setState(
                              () => _checkedProvider[provider.id] = v),
                          onModelChanged: (v) =>
                              setState(() => _models[provider.id] = v),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canRun ? _startRun : null,
                      child: const Text('Run'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _startRun() async {
    final selectedProviders =
        _providers.where((p) => _checkedProvider[p.id] == true).toList();
    final modelMap = {
      for (final p in selectedProviders) p.id: _models[p.id] ?? '',
    };
    final selectedTasks = _registry
        .all()
        .where((t) => _selectedTaskIds.contains(t.id))
        .toList();

    final docs = await getApplicationSupportDirectory();
    final root = Directory(p.join(docs.path, 'workdirs'))
      ..createSync(recursive: true);
    final db = AppDatabase();
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: root),
      runDao: RunDao(db),
      now: () => DateTime.now(),
      idGenerator: () => 'run-${DateTime.now().millisecondsSinceEpoch}',
    );

    final settings = SettingsRepository();
    final judgeProviderId = await settings.getJudgeProviderId();
    final judgeModelId = await settings.getJudgeModelId();
    ModelProvider? judgeProvider;
    if (judgeProviderId != null && judgeModelId != null) {
      for (final candidate in _providers) {
        if (candidate.id == judgeProviderId) {
          judgeProvider = candidate;
          break;
        }
      }
    }
    final evaluatorConfig = EvaluatorConfig(
      judgeProvider: judgeProvider,
      judgeModel: judgeProvider == null ? null : judgeModelId,
    );

    bloc.add(StartRun(
      tasks: selectedTasks,
      providers: selectedProviders,
      modelByProvider: modelMap,
      evaluatorConfig: evaluatorConfig,
      name: _label.trim().isEmpty ? null : _label.trim(),
    ));

    if (!mounted) return;
    final goRouter = GoRouter.of(context);
    goRouter.push('/run', extra: bloc);
  }
}

class _LabelField extends StatelessWidget {
  const _LabelField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Label this run (optional)',
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _TaskPicker extends StatelessWidget {
  const _TaskPicker({
    required this.registry,
    required this.selected,
    required this.onChanged,
  });

  final TaskRegistry registry;
  final Set<String> selected;
  final void Function(String taskId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final byCategory = <Category, List<BenchmarkTask>>{};
    for (final t in registry.all()) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tasks',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final category in byCategory.keys) ...[
          Text(
            category.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final t in byCategory[category]!)
            CheckboxListTile(
              value: selected.contains(t.id),
              title: Text(t.id),
              onChanged: (v) => onChanged(t.id, v ?? false),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ProviderRow extends StatefulWidget {
  const _ProviderRow({
    required this.provider,
    required this.checked,
    required this.onChecked,
    required this.onModelChanged,
  });
  final ModelProvider provider;
  final bool checked;
  final ValueChanged<bool> onChecked;
  final ValueChanged<String> onModelChanged;

  @override
  State<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends State<_ProviderRow> {
  Future<List<String>>? _modelsFuture;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          title: Text(widget.provider.displayName),
          value: widget.checked,
          onChanged: (v) {
            setState(() {
              widget.onChecked(v ?? false);
              _modelsFuture ??= widget.provider.listModels();
            });
          },
        ),
        if (widget.checked)
          Padding(
            padding:
                const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: FutureBuilder<List<String>>(
              future: _modelsFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError ||
                    snap.data == null ||
                    snap.data!.isEmpty) {
                  return TextField(
                    decoration: const InputDecoration(
                      labelText: 'Model id',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: widget.onModelChanged,
                  );
                }
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                  items: snap.data!
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) widget.onModelChanged(v);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run, verify pass**

```bash
flutter test test/ui/pages/new_run_page_test.dart
flutter analyze
```

Expected: PASS. The "Run button disabled with no tasks" test confirms the validation; the picker test confirms grouping.

- [ ] **Step 6: Commit**

```bash
git add lib/tasks/task_catalog.dart lib/ui/pages/new_run_page.dart test/ui/pages/new_run_page_test.dart
git commit -m "feat(ui): NewRunPage adds task picker by category and run label"
```

---

## Task 19: `HomePage` — add "View history" button

**Files:**
- Modify: `lib/ui/pages/home_page.dart`

This change is small, additive, and not unit-tested in isolation (covered by manual smoke; widget test for it would be redundant given trivial logic).

- [ ] **Step 1: Replace `lib/ui/pages/home_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('dart_arena'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => context.push('/new-run'),
              child: const Text('New Run'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.push('/runs'),
              child: const Text('View history'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Smoke**

```bash
flutter analyze
flutter test
```

Expected: clean, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pages/home_page.dart
git commit -m "feat(ui): HomePage adds View history button"
```

---

## Task 20: `SettingsPage` — README path field

**Files:**
- Modify: `lib/ui/pages/settings_page.dart`

- [ ] **Step 1: Modify `lib/ui/pages/settings_page.dart`**

Add a `_ReadmeSection` widget at the bottom of the file (outside any existing class), and insert it into the `ListView` in `_SettingsPageState.build`.

First, append this class at the end of the file:

```dart
class _ReadmeSection extends StatefulWidget {
  const _ReadmeSection({required this.repo});
  final SettingsRepository repo;

  @override
  State<_ReadmeSection> createState() => _ReadmeSectionState();
}

class _ReadmeSectionState extends State<_ReadmeSection> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.repo.getReadmePath().then((v) {
      if (!mounted) return;
      setState(() => _controller.text = v ?? '');
    });
  }

  Future<void> _browse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md'],
      dialogTitle: 'Select README.md',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _controller.text = path);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'README publishing',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'README path',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _browse,
              child: const Text('Browse...'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'The "Publish to README" button replaces content between\n'
          '  <!-- BENCHMARK_RESULTS:START -->\n'
          '  <!-- BENCHMARK_RESULTS:END -->\n'
          'markers in the file above. Add these markers manually to your '
          'README before publishing.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            await widget.repo.setReadmePath(
              _controller.text.trim().isEmpty ? null : _controller.text.trim(),
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('README path saved')),
            );
          },
          child: const Text('Save README path'),
        ),
      ],
    );
  }
}
```

Then add the `file_picker` import at the top of the file:

```dart
import 'package:file_picker/file_picker.dart';
```

Then in `_SettingsPageState.build`, insert the new section between the Anthropic section and the Factory Droid `ListTile`. Find this block:

```dart
          _ApiKeySection(
            repo: _repo,
            providerId: 'anthropic',
            label: 'Anthropic',
          ),
          const Divider(),
          const ListTile(
            title: Text('Factory Droid'),
            subtitle: Text('Uses local droid CLI; no key needed in app.'),
          ),
```

Replace with:

```dart
          _ApiKeySection(
            repo: _repo,
            providerId: 'anthropic',
            label: 'Anthropic',
          ),
          const Divider(),
          _ReadmeSection(repo: _repo),
          const Divider(),
          const ListTile(
            title: Text('Factory Droid'),
            subtitle: Text('Uses local droid CLI; no key needed in app.'),
          ),
```

- [ ] **Step 2: Verify analyze and test suite**

```bash
flutter analyze
flutter test
```

Expected: clean; all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pages/settings_page.dart
git commit -m "feat(ui): Settings page adds README publishing path section"
```

---

## Task 21: Final verification gate

This task does no new code; it confirms the plan is done.

- [ ] **Step 1: Run the full test suite**

```bash
flutter analyze
flutter test
```

Expected: `flutter analyze` clean; every test passes.

- [ ] **Step 2: Build the desktop app**

```bash
flutter build linux --debug
```

Expected: build succeeds; output bundle at `build/linux/x64/debug/bundle/dart_arena`.

- [ ] **Step 3: Manual smoke (gate on user confirmation, not assistant claim)**

Run the app and confirm each step:

```bash
flutter run -d linux
```

- [ ] **3.1** From the Home page, click "New Run".
- [ ] **3.2** On NewRunPage, type a label such as `smoke-plan-4`.
- [ ] **3.3** Confirm the "Tasks" section shows `bug.off_by_one_pagination` under "Bug fix" with a checkbox (pre-selected).
- [ ] **3.4** Pick at least one provider and a model.
- [ ] **3.5** Click Run and wait for RunProgress to reach 1/1 → RunCompleted.
- [ ] **3.6** Navigate back to Home → click "View history". Confirm the run appears with the label `smoke-plan-4`.
- [ ] **3.7** Click the row → RunDetailsPage shows a 1-row matrix with the score.
- [ ] **3.8** Tap the cell → TaskRunDetailsPage opens; verify Output tab shows extracted code, Diff tab renders a diff (or shows the empty state if `bug.off_by_one_pagination` has no fixture at the generated path — it does, so a diff should render), Evaluations tab shows the `compile` card, Prompt tab shows the task prompt.
- [ ] **3.9** Back on RunDetailsPage, click "Export CSV" → save dialog → confirm a `.csv` file is written and contains the expected header + 1 data row.
- [ ] **3.10** Click "Export Markdown" → save → confirm a `.md` file with the table.
- [ ] **3.11** In Settings, set "README path" to a real file (e.g., the project's own `README.md`) that you've manually annotated with:

```markdown
<!-- BENCHMARK_RESULTS:START -->
<!-- BENCHMARK_RESULTS:END -->
```

- [ ] **3.12** Back on RunDetailsPage, click "Publish to README" → preview dialog appears with the would-be content → click Publish → SnackBar `Published to <path>`.
- [ ] **3.13** Verify by `git diff README.md` that only content between markers changed.

- [ ] **Step 4: If 3.1–3.13 pass, mark plan complete**

No commit needed; this task is the gate.

---

## Verification gate (before declaring this plan complete)

- [ ] `flutter analyze` clean.
- [ ] `flutter test` — every test passes (new + existing).
- [ ] `flutter build linux --debug` succeeds.
- [ ] User has confirmed the manual smoke at Task 21.

---

## Out of scope reminder (from the spec)

- 9 new benchmark tasks → Plan 5 (`docs/roadmap/2026-05-02-plan-5-benchmark-content.md`).
- Dashboard / leaderboard with `fl_chart` → Plan 6 (`docs/roadmap/2026-05-02-plan-6-analytics.md`).
- Evaluator-weights editor + DI refactor → Plan 7 (`docs/roadmap/2026-05-02-plan-7-polish.md`).
