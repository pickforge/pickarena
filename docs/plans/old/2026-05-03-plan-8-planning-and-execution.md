# dart_arena — Plan 8: Planning + Execution Benchmark (Phase B, single-file slice)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land Phase B (reference-plan execution) of the Planning + Execution benchmark in a single-file output slice. A new `Category.planningAndExecution` ships with two tasks; each carries a frozen, in-repo reference plan. When the user toggles "Use reference plan" in `NewRunPage`, the plan markdown is injected into the executor prompt and the chosen `planId` is persisted on every `TaskRunResult`. Schema migrates to `v3` with a `Plans` table and a nullable `planId` FK on `TaskRuns`. Stage-combination scaffolding (`combineStages`, `StageCombine` enum) ships inert so Phase A doesn't have to migrate scoring later.

**Scope deliberately reduced from the spec.** Multi-file output (`MultiFileBenchmarkTask`, `extractDartFiles`, `WorkdirManager.createMultiFileTaskWorkdir`, hidden acceptance tests) is **deferred to Plan 8b**. The third "stub" task (`refactor_run_bloc_cancellation`) is **dropped**. `referencePlan` goes directly onto `BenchmarkTask` with default `null`, no new mixin. The single-file slice is enough to validate plan injection end-to-end and unblock Phase A.

**Architecture:** Plan artifacts live in a new `Plans` table (`id`, `taskId`, `plannerModelId NULLABLE`, `referenceVersion NULLABLE`, `artifact`, `createdAt`). Reference plans are upserted at first read, idempotent on `(taskId, referenceVersion)`. `BenchmarkTask` gains a synchronous `hasReferencePlan` capability flag plus an optional lazy-loaded `referencePlan` getter; tasks without a plan return `false` / `null` and are unaffected by the toggle. `RunBloc` calls `buildPromptWithPlan(...)` to merge plan markdown into the task prompt (no-op when plan is null) and resolves `planId` per task before persisting. `StartRunConfig.useReferencePlan` (`bool`, default `false`) carries the toggle through `state.extra`. `NewRunPage` exposes a `SwitchListTile` whose label dynamically reads "Use reference plan (X of Y selected tasks)" so users see scope before clicking Run.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, `drift ^2.20.3` (schema migration), `drift_dev` + `build_runner` (codegen), `flutter_bloc ^8.1.6` (existing), `go_router ^14.6.2` (existing), `flutter_secure_storage` (existing). No new dependencies.

**Predecessors:** Plan 1 (foundation), Plan 2 (cloud providers), Plan 3 (evaluators + scoring), Plan 4 (data & navigation), Plan 5 (benchmark content), Plan 6 (analytics), Plan 7 (DI + weights editor) — all implemented.

**Spec:** `docs/specs/2026-05-03-plan-8-planning-and-execution-design.md`.

**What this plan does NOT ship** (deferred):

- Multi-file output and the `MultiFileBenchmarkTask` mixin (Plan 8b).
- `extractDartFiles`, `WorkdirManager.createMultiFileTaskWorkdir`, hidden acceptance tests (Plan 8b).
- The stub `refactor_run_bloc_cancellation` task (dropped).
- Phase A (self-plan execution, plan judge, judge-validation harness) — design-level only in the spec; separate mini-spec to follow.
- Phase C (cross-model planner × executor pairings, pairing-matrix view, cost preview) — directional sketch only in the spec.
- Any change to `lib/analytics/*` (existing leaderboards filter by category and will simply omit `Category.planningAndExecution` until a Phase 8 view ships).

---

## File map (this plan)

### Created

- `lib/core/plan_loader.dart` — asset-backed `ReferencePlan` loader.
- `lib/runner/prompts/plan_aware_prompt.dart` — pure formatter `buildPromptWithPlan`.
- `lib/storage/dao/plan_dao.dart` — DAO for the `Plans` table (upsert reference, insert model plan, lookup).
- `lib/tasks/planning_and_execution/add_evaluator_type.dart` — first task (full implementation).
- `lib/tasks/planning_and_execution/add_filter_dimension.dart` — second task (pattern repeat).
- `lib/tasks/planning_and_execution/fixtures/add_evaluator_type/pubspec.yaml`
- `lib/tasks/planning_and_execution/fixtures/add_evaluator_type/lib/evaluator.dart`
- `lib/tasks/planning_and_execution/fixtures/add_evaluator_type/test/coverage_evaluator_test.dart`
- `lib/tasks/planning_and_execution/fixtures/add_filter_dimension/pubspec.yaml`
- `lib/tasks/planning_and_execution/fixtures/add_filter_dimension/lib/filter.dart`
- `lib/tasks/planning_and_execution/fixtures/add_filter_dimension/test/category_filter_test.dart`
- `lib/tasks/planning_and_execution/plans/add_evaluator_type.v1.md`
- `lib/tasks/planning_and_execution/plans/add_filter_dimension.v1.md`
- `test/core/plan_loader_test.dart`
- `test/core/scoring_combine_test.dart`
- `test/runner/prompts/plan_aware_prompt_test.dart`
- `test/runner/run_bloc_plan_aware_test.dart`
- `test/storage/plans_dao_test.dart`
- `test/ui/pages/new_run_page_plan_toggle_test.dart`

### Modified

- `lib/core/benchmark_task.dart` — add `ReferencePlan` value class, lazy-safe `hasReferencePlan` capability flag, and `referencePlan` getter (default `null`).
- `lib/core/category.dart` — add `Category.planningAndExecution`.
- `lib/core/scoring.dart` — add `combineStages(...)` + `StageCombine` enum (inert in Phase B).
- `lib/core/task_run_result.dart` — add nullable `planId` field; update `props`.
- `lib/runner/run_event.dart` — `StartRun` gains `useReferencePlan: bool` (default `false`); update `props`.
- `lib/runner/start_run_config.dart` — add `useReferencePlan: bool` field.
- `lib/runner/run_bloc.dart` — inject reference plan into prompt via `buildPromptWithPlan`; resolve `planId` per task via `PlanDao`; persist via `runDao.persistTaskRun(planId: planId)`.
- `lib/storage/database.dart` — new `Plans` table; nullable `planId` column on `TaskRuns`; `schemaVersion: 3`; new migration step.
- `lib/storage/database.g.dart` — regenerated by Drift.
- `lib/storage/dao/run_dao.dart` — `persistTaskRun` accepts optional `planId` parameter, persists when non-null.
- `lib/tasks/task_catalog.dart` — register both new tasks.
- `lib/ui/pages/new_run_page.dart` — `SwitchListTile` for "Use reference plan"; dynamic "X of Y" label; propagate into `StartRunConfig.useReferencePlan`.
- `pubspec.yaml` — add fixture and plan asset entries.
- `test/runner/run_bloc_test.dart` — extend `StartRun` constructor calls with `useReferencePlan: false` where they assert on `props`.
- `test/storage/database_migration_test.dart` — update schema-version assertion from `2` to `3`.
- `test/storage/run_dao_test.dart` — add a round-trip case for `planId`.

### Untouched

- `lib/runner/workdir_manager.dart` — single-file path is unchanged; multi-file extension is Plan 8b.
- `lib/core/code_extractor.dart` — single-file extractor stays; multi-file extractor is Plan 8b.
- `lib/evaluators/*` — no new evaluators in Phase B (`plan_judge` / `plan_structure` are Phase A).
- `lib/analytics/*` — Phase 8 leaderboard view is deferred to Phase C.
- `lib/ui/pages/leaderboard_page.dart`, `lib/ui/pages/dashboard_page.dart`, `lib/ui/pages/run_progress_page.dart`, `lib/ui/pages/settings_page.dart` — no Phase B changes.

---

## Commit plan summary

| # | Title                                                        | Tasks   |
|---|--------------------------------------------------------------|---------|
| 1 | Schema migration v3: Plans table + planId FK                 | 1       |
| 2 | PlanDao + tests                                              | 2       |
| 3 | ReferencePlan + BenchmarkTask.hasReferencePlan/referencePlan | 3       |
| 4 | combineStages scaffolding (inert)                            | 4       |
| 5 | PlanLoader + tests                                           | 5       |
| 6 | buildPromptWithPlan + RunEvent / StartRunConfig fields       | 6       |
| 7 | RunBloc plan injection + RunDao planId                       | 7       |
| 8 | First task: add_evaluator_type                               | 8       |
| 9 | Second task: add_filter_dimension                            | 9       |
| 10 | Category enum + task catalog registration                    | 10      |
| 11 | NewRunPage toggle                                            | 11      |
| 12 | Final verification                                           | 12      |

Each commit is independently shippable. Commits 1–7 are pure infrastructure with zero behavior change at the UI level (no task uses `referencePlan` yet). Commit 8 introduces the first runnable plan-aware task; commit 11 makes it reachable from the UI.

---

## Task 1: Schema migration v3 — `Plans` table + `planId` FK on `TaskRuns`

**Files:**
- Modify: `lib/storage/database.dart`
- Modify: `lib/storage/database.g.dart` (regenerated)
- Modify: `test/storage/database_migration_test.dart`

The migration is additive: new table, new nullable column. Existing rows are unaffected. Bumps `schemaVersion` from `2` to `3` and adds a `from < 3` block to the migration strategy.

- [ ] **Step 1: Add the `Plans` table and `planId` column**

Edit `lib/storage/database.dart`. Add a new `Plans` table class **above** the existing `Evaluations` class, and add a `planId` column to `TaskRuns`:

```dart
class TaskRuns extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text().references(Runs, #id)();
  TextColumn get providerId => text()();
  TextColumn get modelId => text()();
  TextColumn get taskId => text()();
  TextColumn get responseText => text()();
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  IntColumn get latencyMs => integer()();
  RealColumn get aggregateScore => real()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get planId => text().nullable().references(Plans, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get plannerModelId => text().nullable()();
  IntColumn get referenceVersion => integer().nullable()();
  TextColumn get artifact => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Update the `@DriftDatabase` annotation on `AppDatabase` to include `Plans`:

```dart
@DriftDatabase(tables: [Runs, TaskRuns, Evaluations, Plans])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(runs, runs.name);
          }
          if (from < 3) {
            await m.createTable(plans);
            await m.addColumn(taskRuns, taskRuns.planId);
          }
        },
      );
}
```

- [ ] **Step 2: Regenerate Drift code**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`
Expected: `lib/storage/database.g.dart` is updated. New `$PlansTable`, `Plan`, `PlansCompanion`, and a `plans` getter on `AppDatabase` appear; `TaskRunsCompanion` gains a `planId` field.

- [ ] **Step 3: Update the schema-version test**

Edit `test/storage/database_migration_test.dart`. Replace the existing schema-version test with:

```dart
  test('schemaVersion is 3', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 3);
    await db.close();
  });
```

Run: `flutter test test/storage/database_migration_test.dart`
Expected: PASS. This protects the intended v3 bump and prevents the full suite from failing on the old `schemaVersion == 2` assertion.

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues. (The analyzer may briefly complain that `runDao.persistTaskRun` doesn't pass `planId` — it doesn't *need* to; `planId` is nullable and defaults to absent. If you see an error here, double-check that the column declaration uses `.nullable()` before `.references(...)`.)

- [ ] **Step 5: Run tests**

Run: `flutter test`
Expected: PASS for all existing tests. Existing tests use `NativeDatabase.memory()` so the migration path isn't exercised, but the schema must compile and round-trip a `TaskRunsCompanion.insert(...)` without `planId` set.

- [ ] **Step 6: Commit**

```bash
git add lib/storage/database.dart lib/storage/database.g.dart test/storage/database_migration_test.dart
git commit -m "feat(storage): add Plans table and TaskRuns.planId FK; bump schema to v3"
```

---

## Task 2: `PlanDao` + tests

**Files:**
- Create: `lib/storage/dao/plan_dao.dart`
- Create: `test/storage/plans_dao_test.dart`

Three operations, all small: upsert a reference plan (idempotent on `(taskId, referenceVersion)`), insert a model-generated plan (always a new row), and `planById` lookup.

- [ ] **Step 1: Write the failing tests**

Create `test/storage/plans_dao_test.dart`:

```dart
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PlanDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = PlanDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertReferencePlan is idempotent on (taskId, referenceVersion)',
      () async {
    final id1 = await dao.upsertReferencePlan(
      taskId: 't1',
      version: 1,
      artifact: 'first',
    );
    final id2 = await dao.upsertReferencePlan(
      taskId: 't1',
      version: 1,
      artifact: 'first',
    );
    expect(id1, id2);

    final all = await db.select(db.plans).get();
    expect(all, hasLength(1));
    expect(all.single.artifact, 'first');
  });

  test('upsertReferencePlan with a different version creates a second row',
      () async {
    await dao.upsertReferencePlan(
      taskId: 't1',
      version: 1,
      artifact: 'first',
    );
    await dao.upsertReferencePlan(
      taskId: 't1',
      version: 2,
      artifact: 'second',
    );
    final all = await db.select(db.plans).get();
    expect(all, hasLength(2));
  });

  test('insertModelPlan creates a fresh row each call', () async {
    final id1 = await dao.insertModelPlan(
      taskId: 't1',
      plannerModelId: 'm1',
      artifact: 'plan A',
    );
    final id2 = await dao.insertModelPlan(
      taskId: 't1',
      plannerModelId: 'm1',
      artifact: 'plan B',
    );
    expect(id1, isNot(id2));
    final all = await db.select(db.plans).get();
    expect(all, hasLength(2));
  });

  test('planById returns null for unknown id', () async {
    final p = await dao.planById('nope');
    expect(p, isNull);
  });

  test('TaskRuns.planId round-trips via FK', () async {
    final planId = await dao.upsertReferencePlan(
      taskId: 't1',
      version: 1,
      artifact: 'plan',
    );

    await db.into(db.runs).insert(
          RunsCompanion.insert(
            id: 'r1',
            startedAt: DateTime(2026, 1, 1),
          ),
        );
    await db.into(db.taskRuns).insert(
          TaskRunsCompanion.insert(
            id: 'tr1',
            runId: 'r1',
            providerId: 'p',
            modelId: 'm',
            taskId: 't1',
            responseText: '',
            latencyMs: 0,
            aggregateScore: 1.0,
            completedAt: DateTime(2026, 1, 1, 0, 1),
            planId: Value(planId),
          ),
        );
    final row = await (db.select(db.taskRuns)
          ..where((t) => t.id.equals('tr1')))
        .getSingle();
    expect(row.planId, planId);
  });
}
```

Run: `flutter test test/storage/plans_dao_test.dart`
Expected: FAIL (compile error — `package:dart_arena/storage/dao/plan_dao.dart` does not exist).

- [ ] **Step 2: Implement `PlanDao`**

Create `lib/storage/dao/plan_dao.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';

class PlanDao {
  PlanDao(this._db);

  final AppDatabase _db;

  /// Insert a reference plan if no row exists for `(taskId, version)`,
  /// or return the existing row's id otherwise. Editing the artifact
  /// without bumping `version` is a no-op (existing row wins).
  Future<String> upsertReferencePlan({
    required String taskId,
    required int version,
    required String artifact,
  }) async {
    final existing = await (_db.select(_db.plans)
          ..where((p) =>
              p.taskId.equals(taskId) & p.referenceVersion.equals(version))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final id = 'ref-$taskId-v$version';
    await _db.into(_db.plans).insert(
          PlansCompanion.insert(
            id: id,
            taskId: taskId,
            artifact: artifact,
            createdAt: DateTime.now(),
            referenceVersion: Value(version),
          ),
        );
    return id;
  }

  Future<String> insertModelPlan({
    required String taskId,
    required String plannerModelId,
    required String artifact,
  }) async {
    final id =
        'mp-$taskId-$plannerModelId-${DateTime.now().microsecondsSinceEpoch}';
    await _db.into(_db.plans).insert(
          PlansCompanion.insert(
            id: id,
            taskId: taskId,
            artifact: artifact,
            createdAt: DateTime.now(),
            plannerModelId: Value(plannerModelId),
          ),
        );
    return id;
  }

  Future<Plan?> planById(String id) {
    return (_db.select(_db.plans)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }
}
```

Run: `flutter test test/storage/plans_dao_test.dart`
Expected: PASS for all five tests.

- [ ] **Step 3: Commit**

```bash
git add lib/storage/dao/plan_dao.dart test/storage/plans_dao_test.dart
git commit -m "feat(storage): PlanDao with idempotent reference upsert and model-plan insert"
```

---

## Task 3: `ReferencePlan` value class + `BenchmarkTask.hasReferencePlan` / `referencePlan`

**Files:**
- Modify: `lib/core/benchmark_task.dart`

`hasReferencePlan` and `referencePlan` are non-breaking additions. Existing tasks need no change; lazy-loaded planning tasks override `hasReferencePlan` to `true` so the UI can enable the toggle before `ensureLoaded()` runs.

- [ ] **Step 1: Update `BenchmarkTask`**

Replace `lib/core/benchmark_task.dart` with:

```dart
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class ReferencePlan {
  const ReferencePlan({
    required this.version,
    required this.markdown,
  });

  /// Bumping invalidates historical plan-aware runs against this task.
  /// Hard rule: never edit a published plan in place — bump version + ship a new row.
  final int version;

  /// The plan body (markdown). Not asset-loaded here; tasks construct
  /// this from a string they obtained via [PlanLoader] in [ensureLoaded].
  final String markdown;
}

abstract class BenchmarkTask {
  String get id;
  Category get category;
  String get prompt;
  Map<String, String> get fixtures;
  String? get judgeRubric;
  String get generatedCodePath;
  bool get isFlutter => false;
  Future<void> ensureLoaded() async {}
  List<Evaluator> evaluatorsFor(EvaluatorConfig config);

  /// Reference plan for plan-aware runs. `null` means this task does not
  /// participate in `StartRunConfig.useReferencePlan`.
  ReferencePlan? get referencePlan => null;

  /// Synchronous capability flag for UI and catalog filtering. Tasks whose
  /// plan is loaded lazily in [ensureLoaded] must override this to `true`.
  bool get hasReferencePlan => referencePlan != null;
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues. Existing `BenchmarkTask` subclasses inherit the default `null` getter.

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/core/benchmark_task.dart
git commit -m "feat(core): add ReferencePlan capability to BenchmarkTask"
```

---

## Task 4: Stage-combination scaffolding (`combineStages` + `StageCombine`)

**Files:**
- Modify: `lib/core/scoring.dart`
- Create: `test/core/scoring_combine_test.dart`

Lands inert in Phase B (no caller invokes it yet). Phase A wires it into `aggregateScore`. Pinning the function shape now means Phase A is a one-line change at the call site.

- [ ] **Step 1: Write the failing tests**

Create `test/core/scoring_combine_test.dart`:

```dart
import 'package:dart_arena/core/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('combineStages', () {
    test('geometric mean of equal stages equals each stage', () {
      expect(
        combineStages(planScore: 0.8, executeScore: 0.8),
        closeTo(0.8, 1e-9),
      );
    });

    test('geometric mean of (0.5, 0.9) ~ 0.6708', () {
      expect(
        combineStages(planScore: 0.5, executeScore: 0.9),
        closeTo(0.6708203932, 1e-9),
      );
    });

    test('floor-clamp prevents zero from collapsing the score', () {
      // sqrt(0.01 * 0.9) = sqrt(0.009) ~ 0.0949
      expect(
        combineStages(planScore: 0.0, executeScore: 0.9),
        closeTo(0.0948683298, 1e-9),
      );
    });

    test('product mode multiplies clamped values', () {
      expect(
        combineStages(
          planScore: 0.5,
          executeScore: 0.5,
          mode: StageCombine.product,
        ),
        closeTo(0.25, 1e-9),
      );
    });

    test('weightedSum mode is 0.5 * plan + 0.5 * execute', () {
      expect(
        combineStages(
          planScore: 0.4,
          executeScore: 1.0,
          mode: StageCombine.weightedSum,
        ),
        closeTo(0.7, 1e-9),
      );
    });

    test('values above 1.0 are clamped to 1.0', () {
      expect(
        combineStages(planScore: 2.0, executeScore: 1.0),
        closeTo(1.0, 1e-9),
      );
    });
  });
}
```

Run: `flutter test test/core/scoring_combine_test.dart`
Expected: FAIL (compile error — `combineStages` not found).

- [ ] **Step 2: Implement `combineStages` + `StageCombine`**

Edit `lib/core/scoring.dart`. Add `dart:math` import at the top, then append below the existing `aggregate` function:

```dart
import 'dart:math' show sqrt;
```

(Place this with the other imports at the top of the file.)

Append at the bottom:

```dart
enum StageCombine { geometricMean, product, weightedSum }

/// Combines a plan-stage score and an execute-stage score into a final score.
/// Inputs are clamped to `[0.01, 1.0]` before combining, so a complete
/// extraction failure (`0.0`) becomes `0.01` and the other stage still
/// contributes. Pure-zero is reserved for "model produced no output."
double combineStages({
  required double planScore,
  required double executeScore,
  StageCombine mode = StageCombine.geometricMean,
}) {
  final p = planScore.clamp(0.01, 1.0);
  final e = executeScore.clamp(0.01, 1.0);
  return switch (mode) {
    StageCombine.geometricMean => sqrt(p * e),
    StageCombine.product => p * e,
    StageCombine.weightedSum => 0.5 * p + 0.5 * e,
  };
}
```

Run: `flutter test test/core/scoring_combine_test.dart`
Expected: PASS for all six tests.

- [ ] **Step 3: Run full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/core/scoring.dart test/core/scoring_combine_test.dart
git commit -m "feat(scoring): combineStages with StageCombine enum (geometric mean default, inert in Phase B)"
```

---

## Task 5: `PlanLoader` (asset-backed) + tests

**Files:**
- Create: `lib/core/plan_loader.dart`
- Create: `test/core/plan_loader_test.dart`

Mirror of `FixtureLoader`'s shape. Tasks call this in `ensureLoaded()` to build their `ReferencePlan`.

- [ ] **Step 1: Write the failing test**

Create `test/core/plan_loader_test.dart`:

```dart
import 'package:dart_arena/core/plan_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'PlanLoader.load returns a ReferencePlan with the loaded asset text',
      (tester) async {
    // Reuse an existing registered asset so this test can pass before the
    // planning-and-execution assets are added later in this plan.
    final plan = await PlanLoader.load(
      assetPath:
          'lib/tasks/bug_fix/fixtures/off_by_one_pagination/pubspec.yaml',
      version: 1,
    );
    expect(plan.version, 1);
    expect(plan.markdown, isNotEmpty);
    expect(plan.markdown, contains('off_by_one_pagination'));
  });

  testWidgets('PlanLoader throws when the asset path is missing',
      (tester) async {
    expect(
      () => PlanLoader.load(
        assetPath: 'lib/tasks/planning_and_execution/plans/missing.md',
        version: 1,
      ),
      throwsA(isA<FlutterError>()),
    );
  });
}
```

This test intentionally uses an existing registered fixture asset, not a future planning asset, so the full suite remains green between Tasks 5 and 10.

- [ ] **Step 2: Implement `PlanLoader`**

Create `lib/core/plan_loader.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:flutter/services.dart';

class PlanLoader {
  static Future<ReferencePlan> load({
    required String assetPath,
    required int version,
  }) async {
    final markdown = await rootBundle.loadString(assetPath);
    return ReferencePlan(version: version, markdown: markdown);
  }
}
```

- [ ] **Step 3: Run the PlanLoader test**

Run: `flutter test test/core/plan_loader_test.dart`
Expected: PASS for both tests.

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 5: Run full suite**

Run: `flutter test`
Expected: PASS. This must pass before Task 6 starts; do not leave an asset-dependent failing test in the tree.

- [ ] **Step 6: Commit**

```bash
git add lib/core/plan_loader.dart test/core/plan_loader_test.dart
git commit -m "feat(core): PlanLoader for asset-backed reference plans"
```

---

## Task 6: `buildPromptWithPlan` + `RunEvent.useReferencePlan` + `StartRunConfig.useReferencePlan`

**Files:**
- Create: `lib/runner/prompts/plan_aware_prompt.dart`
- Create: `test/runner/prompts/plan_aware_prompt_test.dart`
- Modify: `lib/runner/run_event.dart`
- Modify: `lib/runner/start_run_config.dart`
- Modify: `test/runner/run_bloc_test.dart`

Pure formatter. The bloc consumes it in Task 7.

- [ ] **Step 1: Write the failing tests for the formatter**

Create `test/runner/prompts/plan_aware_prompt_test.dart`:

```dart
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('null plan returns the prompt unchanged', () {
    final out = buildPromptWithPlan(
      taskPrompt: 'do thing',
      planMarkdown: null,
    );
    expect(out, 'do thing');
  });

  test('non-null plan injects a fenced ```plan block exactly once', () {
    final out = buildPromptWithPlan(
      taskPrompt: 'do thing',
      planMarkdown: '1. step one\n2. step two',
    );
    expect(out.contains('do thing'), isTrue);
    expect(
      RegExp(r'```plan').allMatches(out).length,
      1,
      reason: 'plan fence opener should appear exactly once',
    );
    expect(out.contains('1. step one'), isTrue);
    expect(out.contains('2. step two'), isTrue);
  });

  test('null plan is the only no-op case', () {
    final out = buildPromptWithPlan(
      taskPrompt: 'unrelated input',
      planMarkdown: null,
    );
    expect(out, 'unrelated input');
    expect(out.contains('REFERENCE PLAN'), isFalse);
  });
}
```

Run: `flutter test test/runner/prompts/plan_aware_prompt_test.dart`
Expected: FAIL (compile error — `buildPromptWithPlan` not found).

- [ ] **Step 2: Implement `buildPromptWithPlan`**

Create `lib/runner/prompts/plan_aware_prompt.dart`:

```dart
String buildPromptWithPlan({
  required String taskPrompt,
  required String? planMarkdown,
}) {
  if (planMarkdown == null) return taskPrompt;
  return '''$taskPrompt

REFERENCE PLAN:
The following plan was authored by a human and describes the intended implementation approach. You should follow it; deviations are penalized.

```plan
$planMarkdown
```''';
}
```

Run: `flutter test test/runner/prompts/plan_aware_prompt_test.dart`
Expected: PASS.

- [ ] **Step 3: Add `useReferencePlan` to `StartRun` event**

Edit `lib/runner/run_event.dart`. Replace the `StartRun` class with:

```dart
class StartRun extends RunEvent {
  const StartRun({
    required this.tasks,
    required this.providers,
    required this.modelByProvider,
    required this.evaluatorConfig,
    this.useReferencePlan = false,
    this.name,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, String> modelByProvider;
  final EvaluatorConfig evaluatorConfig;
  final bool useReferencePlan;
  final String? name;

  @override
  List<Object?> get props => [
        tasks,
        providers,
        modelByProvider,
        evaluatorConfig,
        useReferencePlan,
        name,
      ];
}
```

- [ ] **Step 4: Add `useReferencePlan` to `StartRunConfig`**

Edit `lib/runner/start_run_config.dart`. Replace with:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/providers/model_provider.dart';

class StartRunConfig {
  const StartRunConfig({
    required this.tasks,
    required this.providers,
    required this.modelByProvider,
    required this.evaluatorConfig,
    required this.weights,
    this.useReferencePlan = false,
    this.name,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, String> modelByProvider;
  final EvaluatorConfig evaluatorConfig;
  final Map<String, double> weights;
  final bool useReferencePlan;
  final String? name;
}
```

- [ ] **Step 5: Verify existing `StartRun` call sites still compile**

The new `useReferencePlan` parameter has a default, so all existing call sites in `lib/` and `test/` continue to compile unchanged. The bloc test file currently constructs `StartRun(...)` without `useReferencePlan` — that's the expected default-`false` behavior.

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 6: Run tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/runner/prompts/plan_aware_prompt.dart test/runner/prompts/plan_aware_prompt_test.dart lib/runner/run_event.dart lib/runner/start_run_config.dart
git commit -m "feat(runner): plan-aware prompt formatter and useReferencePlan flag on StartRun/StartRunConfig"
```

---

## Task 7: `RunBloc` plan injection + `RunDao.persistTaskRun(planId)`

**Files:**
- Modify: `lib/storage/dao/run_dao.dart`
- Modify: `lib/core/task_run_result.dart`
- Modify: `lib/runner/run_bloc.dart`
- Create: `test/runner/run_bloc_plan_aware_test.dart`
- Modify: `test/storage/run_dao_test.dart`

This is the central wiring task. Three small changes — `TaskRunResult.planId`, `RunDao.persistTaskRun(planId:)`, and `RunBloc._onStart` calling `buildPromptWithPlan` and resolving `planId` via `PlanDao` — and one new test for the bloc-level integration.

- [ ] **Step 1: Add `planId` to `TaskRunResult`**

Edit `lib/core/task_run_result.dart`. Replace with:

```dart
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:equatable/equatable.dart';

class TaskRunResult extends Equatable {
  const TaskRunResult({
    required this.runId,
    required this.providerId,
    required this.modelId,
    required this.taskId,
    required this.response,
    required this.evaluations,
    required this.aggregateScore,
    required this.completedAt,
    this.planId,
  });

  final String runId;
  final String providerId;
  final String modelId;
  final String taskId;
  final ModelResponse response;
  final List<EvaluationResult> evaluations;
  final double aggregateScore;
  final DateTime completedAt;
  final String? planId;

  @override
  List<Object?> get props => [
        runId,
        providerId,
        modelId,
        taskId,
        response,
        evaluations,
        aggregateScore,
        completedAt,
        planId,
      ];
}
```

- [ ] **Step 2: Update `RunDao.persistTaskRun` to accept and store `planId`**

Edit `lib/storage/dao/run_dao.dart`. Replace the `persistTaskRun` method with:

```dart
Future<void> persistTaskRun(TaskRunResult r) async {
  final taskRunId =
      '${r.runId}-${r.providerId}-${r.modelId}-${r.taskId}-${r.completedAt.microsecondsSinceEpoch}';
  await _db.into(_db.taskRuns).insert(
        TaskRunsCompanion.insert(
          id: taskRunId,
          runId: r.runId,
          providerId: r.providerId,
          modelId: r.modelId,
          taskId: r.taskId,
          responseText: r.response.rawText,
          promptTokens: Value(r.response.promptTokens),
          completionTokens: Value(r.response.completionTokens),
          latencyMs: r.response.latency.inMilliseconds,
          aggregateScore: r.aggregateScore,
          completedAt: r.completedAt,
          planId: Value(r.planId),
        ),
      );
  for (var i = 0; i < r.evaluations.length; i++) {
    final e = r.evaluations[i];
    await _db.into(_db.evaluations).insert(
          EvaluationsCompanion.insert(
            id: '$taskRunId-${e.evaluatorId}-$i',
            taskRunId: taskRunId,
            evaluatorId: e.evaluatorId,
            passed: e.passed,
            score: e.score,
            rationale: Value(e.rationale),
            detailsJson: jsonEncode(e.details),
          ),
        );
  }
}
```

(The signature is source-compatible — `TaskRunResult.planId` defaults to `null`. Existing call sites do not change.)

- [ ] **Step 3: Update `RunBloc._onStart` to inject the plan and resolve `planId`**

Edit `lib/runner/run_bloc.dart`. Add imports at the top:

```dart
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
```

Add a constructor parameter for the optional `PlanDao`:

```dart
class RunBloc extends Bloc<RunEvent, RunState> {
  RunBloc({
    required this.workdirManager,
    required this.runDao,
    required this.now,
    required this.idGenerator,
    this.weights = defaultEvaluatorWeights,
    this.planDao,
  }) : super(const RunIdle()) {
    on<StartRun>(_onStart);
  }

  final WorkdirManager workdirManager;
  final RunDao runDao;
  final DateTime Function() now;
  final String Function() idGenerator;
  final Map<String, double> weights;
  final PlanDao? planDao;
```

(`planDao` is optional so existing tests that build `RunBloc` directly continue to compile. When `useReferencePlan = true` and `planDao` is `null`, the bloc skips plan injection silently with a `debugPrint`. In production, `planDao` is always wired by the `/run` route — see Task 11.)

Inside `_onStart`, find the existing `for (final task in event.tasks)` loop and add a per-task plan resolution **before** the inner provider loop:

```dart
for (final task in event.tasks) {
  await task.ensureLoaded();

  String? planId;
  String? planMarkdown;
  if (event.useReferencePlan && task.referencePlan != null) {
    planMarkdown = task.referencePlan!.markdown;
    if (planDao != null) {
      planId = await planDao!.upsertReferencePlan(
        taskId: task.id,
        version: task.referencePlan!.version,
        artifact: task.referencePlan!.markdown,
      );
    }
  }

  for (final provider in event.providers) {
    final modelId = event.modelByProvider[provider.id]!;
    // ... existing emit + label code unchanged ...

    final response = await provider.generate(
      prompt: buildPromptWithPlan(
        taskPrompt: task.prompt,
        planMarkdown: planMarkdown,
      ),
      model: modelId,
    );
    // ... rest of the inner body unchanged ...

    final taskResult = TaskRunResult(
      runId: runId,
      providerId: provider.id,
      modelId: modelId,
      taskId: task.id,
      response: responseWithCode,
      evaluations: evaluations,
      aggregateScore: aggregateScore,
      completedAt: now(),
      planId: planId,
    );
    results.add(taskResult);
    await runDao.persistTaskRun(taskResult);
    completed++;
    // ... existing emit unchanged ...
  }
}
```

(Concretely: change the line `prompt: task.prompt,` to `prompt: buildPromptWithPlan(taskPrompt: task.prompt, planMarkdown: planMarkdown),` and add `planId: planId,` to the `TaskRunResult` constructor call. Insert the `String? planId; String? planMarkdown; if (...) { ... }` block above the `for (final provider in event.providers)` loop.)

- [ ] **Step 4: Write the bloc-level integration test**

Create `test/runner/run_bloc_plan_aware_test.dart`:

```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingProvider implements ModelProvider {
  String? lastPrompt;
  @override
  String get id => 'rec';
  @override
  String get displayName => 'Rec';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<String>> listModels() async => ['rec-1'];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    lastPrompt = prompt;
    return const ModelResponse(
      rawText: '```dart\nint answer() => 42;\n```',
      extractedCode: null,
      promptTokens: 1,
      completionTokens: 2,
      latency: Duration(milliseconds: 1),
    );
  }
}

class _AlwaysPass implements Evaluator {
  @override
  String get id => 'pass';
  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async =>
      const EvaluationResult(evaluatorId: 'pass', passed: true, score: 1.0);
}

class _PlanCarryingTask extends BenchmarkTask {
  @override
  String get id => 'plan-task';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'do thing';
  @override
  Map<String, String> get fixtures => const {
        'pubspec.yaml':
            'name: tmp\nenvironment:\n  sdk: ">=3.5.0 <4.0.0"\n',
      };
  @override
  String get generatedCodePath => 'lib/answer.dart';
  @override
  String? get judgeRubric => null;
  @override
  ReferencePlan? get referencePlan =>
      const ReferencePlan(version: 1, markdown: 'STEPS:\n1. think\n2. type');
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [_AlwaysPass()];
}

void main() {
  test('useReferencePlan = true injects plan into prompt and persists planId',
      () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_plan_on_');
    final db = AppDatabase(NativeDatabase.memory());
    final provider = _RecordingProvider();

    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      planDao: PlanDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-plan',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(StartRun(
      tasks: [_PlanCarryingTask()],
      providers: [provider],
      modelByProvider: const {'rec': 'rec-1'},
      evaluatorConfig: const EvaluatorConfig(),
      useReferencePlan: true,
    ));

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunCompleted>());

    expect(provider.lastPrompt, contains('do thing'));
    expect(provider.lastPrompt, contains('REFERENCE PLAN'));
    expect(provider.lastPrompt, contains('1. think'));

    final completed = states.last as RunCompleted;
    expect(completed.results.single.planId, isNotNull);
    expect(completed.results.single.planId, startsWith('ref-plan-task-v1'));

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('useReferencePlan = false leaves the prompt unchanged', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_plan_off_');
    final db = AppDatabase(NativeDatabase.memory());
    final provider = _RecordingProvider();

    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      planDao: PlanDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-plan-off',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(StartRun(
      tasks: [_PlanCarryingTask()],
      providers: [provider],
      modelByProvider: const {'rec': 'rec-1'},
      evaluatorConfig: const EvaluatorConfig(),
    ));

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunCompleted>());

    expect(provider.lastPrompt, 'do thing');
    final completed = states.last as RunCompleted;
    expect(completed.results.single.planId, isNull);

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });
}
```

Run: `flutter test test/runner/run_bloc_plan_aware_test.dart`
Expected: PASS.

- [ ] **Step 5: Smoke-check `RunDao` round-trip with `planId`**

Edit `test/storage/run_dao_test.dart`. Append a new test:

```dart
test('persistTaskRun stores planId when set on TaskRunResult', () async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  final planDao = PlanDao(db);
  await dao.startRun(runId: 'r-pid', startedAt: DateTime(2026, 1, 1));
  final planId = await planDao.upsertReferencePlan(
    taskId: 'task-x',
    version: 1,
    artifact: 'plan',
  );
  await dao.persistTaskRun(TaskRunResult(
    runId: 'r-pid',
    providerId: 'p',
    modelId: 'm',
    taskId: 'task-x',
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: 0,
      completionTokens: 0,
      latency: Duration.zero,
    ),
    evaluations: const [],
    aggregateScore: 1.0,
    completedAt: DateTime(2026, 1, 1, 0, 1),
    planId: planId,
  ));

  final rows = await dao.taskRunsForRun('r-pid');
  expect(rows.single.planId, planId);

  await db.close();
});
```

(If the file lacks the necessary imports, add `package:dart_arena/storage/dao/plan_dao.dart`, `package:dart_arena/core/task_run_result.dart`, and `package:dart_arena/core/model_response.dart`.)

- [ ] **Step 6: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 7: Run full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core/task_run_result.dart lib/storage/dao/run_dao.dart lib/runner/run_bloc.dart test/runner/run_bloc_plan_aware_test.dart
git add test/storage/run_dao_test.dart
git commit -m "feat(runner): RunBloc injects reference plan into prompt and persists planId"
```

---

## Task 8: First task — `add_evaluator_type` (full implementation)

**Files:**
- Create: `lib/tasks/planning_and_execution/fixtures/add_evaluator_type/pubspec.yaml`
- Create: `lib/tasks/planning_and_execution/fixtures/add_evaluator_type/lib/evaluator.dart`
- Create: `lib/tasks/planning_and_execution/fixtures/add_evaluator_type/test/coverage_evaluator_test.dart`
- Create: `lib/tasks/planning_and_execution/plans/add_evaluator_type.v1.md`

Single-file output: the model writes `lib/coverage_evaluator.dart`. Fixtures provide the `Evaluator` interface to implement and a test that validates shape. Reference plan tells the model what to write.

The task class is **not created yet** — that lands in Task 10 after `Category.planningAndExecution` exists.

- [ ] **Step 1: Create the fixture pubspec**

Create `lib/tasks/planning_and_execution/fixtures/add_evaluator_type/pubspec.yaml`:

```yaml
name: coverage_task
environment:
  sdk: ">=3.5.0 <4.0.0"

dev_dependencies:
  test: ^1.25.0
```

- [ ] **Step 2: Create the fixture `Evaluator` interface**

Create `lib/tasks/planning_and_execution/fixtures/add_evaluator_type/lib/evaluator.dart`:

```dart
abstract class Evaluator {
  String get id;
  Future<EvaluationResult> evaluate(EvaluationContext ctx);
}

class EvaluationResult {
  EvaluationResult({required this.id, required this.score});
  final String id;
  final double score;
}

class EvaluationContext {
  EvaluationContext({required this.workDir});
  final String workDir;
}
```

- [ ] **Step 3: Create the acceptance test**

Create `lib/tasks/planning_and_execution/fixtures/add_evaluator_type/test/coverage_evaluator_test.dart`:

```dart
import 'package:test/test.dart';
import '../lib/coverage_evaluator.dart';
import '../lib/evaluator.dart';

void main() {
  test('CoverageEvaluator implements Evaluator', () {
    final e = CoverageEvaluator();
    expect(e, isA<Evaluator>());
  });

  test('CoverageEvaluator id is "coverage"', () {
    expect(CoverageEvaluator().id, 'coverage');
  });

  test('CoverageEvaluator returns a score in [0, 1]', () async {
    final e = CoverageEvaluator();
    final result = await e.evaluate(EvaluationContext(workDir: '/tmp'));
    expect(result.id, 'coverage');
    expect(result.score, inInclusiveRange(0.0, 1.0));
  });
}
```

- [ ] **Step 4: Create the reference plan**

Create `lib/tasks/planning_and_execution/plans/add_evaluator_type.v1.md`:

```markdown
# Plan — Add `coverage` Evaluator

## Files to create

1. `lib/coverage_evaluator.dart` — the implementation file. Single output.

## Implementation steps

1. Import the `Evaluator` interface and supporting types from `lib/evaluator.dart`.
2. Define `class CoverageEvaluator implements Evaluator`.
3. Override the `id` getter to return the string `'coverage'`.
4. Override `evaluate(EvaluationContext ctx)`:
   - For this Phase B slice, return a deterministic `EvaluationResult(id: 'coverage', score: 0.5)`.
   - Do not shell out to `dart test --coverage` yet. A future iteration can parse `lcov.info`; the deterministic score is enough to satisfy the acceptance contract.
5. Make the class exportable: top-level (no `_` prefix), no required constructor arguments.

## Tests to satisfy

`test/coverage_evaluator_test.dart` (already provided) asserts:

- `CoverageEvaluator` is assignable to `Evaluator`.
- `CoverageEvaluator().id == 'coverage'`.
- `evaluate(...)` returns an `EvaluationResult` with `id == 'coverage'` and `score` in `[0, 1]`.

## Output format

Return ONLY the contents of `lib/coverage_evaluator.dart` inside a single fenced Dart code block. Do not include any other files.
```

- [ ] **Step 5: Defer the task class**

Do **not** create `lib/tasks/planning_and_execution/add_evaluator_type.dart` in this task. That file references `Category.planningAndExecution`, which is added in Task 10. Task 10 includes the exact task-class code and commits it with the enum and catalog registration so the worktree never contains a non-compiling Dart file.

- [ ] **Step 6: Register fixture and plan assets in `pubspec.yaml`**

Edit `pubspec.yaml`. Append to the `flutter.assets:` list:

```yaml
    - lib/tasks/planning_and_execution/fixtures/add_evaluator_type/pubspec.yaml
    - lib/tasks/planning_and_execution/fixtures/add_evaluator_type/lib/evaluator.dart
    - lib/tasks/planning_and_execution/fixtures/add_evaluator_type/test/coverage_evaluator_test.dart
    - lib/tasks/planning_and_execution/plans/add_evaluator_type.v1.md
```

- [ ] **Step 7: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues. Only fixtures, plan markdown, and `pubspec.yaml` changed in this task; no Dart task class is created yet.

(Reordering reminder for the executor: Task 10's `Category` enum addition is a one-line change. If `flutter analyze` blocks here, jump to Task 10 Step 1, then return.)

- [ ] **Step 8: Note — task class compilation happens in Task 10**

The task class is created in Task 10 after `Category.planningAndExecution` exists.

- [ ] **Step 9: Commit just the fixtures, plan, and asset entries (not the task class yet)**

```bash
git add lib/tasks/planning_and_execution/fixtures/add_evaluator_type lib/tasks/planning_and_execution/plans/add_evaluator_type.v1.md pubspec.yaml
git commit -m "feat(tasks): add_evaluator_type fixtures and reference plan v1"
```

(The task class is committed in Task 10 along with the `Category` enum addition.)

---

## Task 9: Second task — `add_filter_dimension` (pattern repeat)

**Files:**
- Create: `lib/tasks/planning_and_execution/fixtures/add_filter_dimension/pubspec.yaml`
- Create: `lib/tasks/planning_and_execution/fixtures/add_filter_dimension/lib/filter.dart`
- Create: `lib/tasks/planning_and_execution/fixtures/add_filter_dimension/test/category_filter_test.dart`
- Create: `lib/tasks/planning_and_execution/plans/add_filter_dimension.v1.md`

Same shape as Task 8. Different premise: extend a small `Filter` interface to support a new `category` dimension. The task class is not created until Task 10 after the enum value exists.

- [ ] **Step 1: Create the fixture pubspec**

Create `lib/tasks/planning_and_execution/fixtures/add_filter_dimension/pubspec.yaml`:

```yaml
name: filter_task
environment:
  sdk: ">=3.5.0 <4.0.0"

dev_dependencies:
  test: ^1.25.0
```

- [ ] **Step 2: Create the fixture filter interface**

Create `lib/tasks/planning_and_execution/fixtures/add_filter_dimension/lib/filter.dart`:

```dart
class Item {
  Item({required this.id, required this.category});
  final String id;
  final String category;
}

abstract class Filter {
  bool matches(Item item);
}
```

- [ ] **Step 3: Create the acceptance test**

Create `lib/tasks/planning_and_execution/fixtures/add_filter_dimension/test/category_filter_test.dart`:

```dart
import 'package:test/test.dart';
import '../lib/category_filter.dart';
import '../lib/filter.dart';

void main() {
  test('CategoryFilter implements Filter', () {
    expect(CategoryFilter(category: 'a'), isA<Filter>());
  });

  test('matches returns true when item.category equals the filter category',
      () {
    final f = CategoryFilter(category: 'red');
    expect(f.matches(Item(id: '1', category: 'red')), isTrue);
    expect(f.matches(Item(id: '2', category: 'blue')), isFalse);
  });

  test('empty category filter matches everything', () {
    final f = CategoryFilter(category: '');
    expect(f.matches(Item(id: '1', category: 'red')), isTrue);
    expect(f.matches(Item(id: '2', category: 'blue')), isTrue);
  });
}
```

- [ ] **Step 4: Create the reference plan**

Create `lib/tasks/planning_and_execution/plans/add_filter_dimension.v1.md`:

```markdown
# Plan — Add `category` Filter Dimension

## Files to create

1. `lib/category_filter.dart` — single output file.

## Implementation steps

1. Import `Filter` and `Item` from `lib/filter.dart`.
2. Define `class CategoryFilter implements Filter`.
3. Constructor: `CategoryFilter({required this.category})`. Field: `final String category`.
4. Implement `bool matches(Item item)`:
   - If `category` is empty (length 0), return `true` (acts as a pass-through).
   - Otherwise return `item.category == category`.

## Tests to satisfy

`test/category_filter_test.dart` (already provided) asserts:

- `CategoryFilter` is a `Filter`.
- `matches` returns `true` for matching categories, `false` for non-matching.
- Empty `category` filter matches every item.

## Output format

Return ONLY the contents of `lib/category_filter.dart` inside a single fenced Dart code block. Do not include any other files.
```

- [ ] **Step 5: Defer the task class**

Do **not** create `lib/tasks/planning_and_execution/add_filter_dimension.dart` in this task. That file references `Category.planningAndExecution`, which is added in Task 10. Task 10 includes the exact task-class code and commits it with the enum and catalog registration so the worktree never contains a non-compiling Dart file.

- [ ] **Step 6: Register fixture and plan assets in `pubspec.yaml`**

Edit `pubspec.yaml`. Append to the `flutter.assets:` list:

```yaml
    - lib/tasks/planning_and_execution/fixtures/add_filter_dimension/pubspec.yaml
    - lib/tasks/planning_and_execution/fixtures/add_filter_dimension/lib/filter.dart
    - lib/tasks/planning_and_execution/fixtures/add_filter_dimension/test/category_filter_test.dart
    - lib/tasks/planning_and_execution/plans/add_filter_dimension.v1.md
```

- [ ] **Step 7: Commit fixtures + plan + asset entries**

```bash
git add lib/tasks/planning_and_execution/fixtures/add_filter_dimension lib/tasks/planning_and_execution/plans/add_filter_dimension.v1.md pubspec.yaml
git commit -m "feat(tasks): add_filter_dimension fixtures and reference plan v1"
```

(Task class file is not created yet; it lands in Task 10 with the enum value.)

---

## Task 10: `Category.planningAndExecution` enum + task catalog registration

**Files:**
- Modify: `lib/core/category.dart`
- Create: `lib/tasks/planning_and_execution/add_evaluator_type.dart`
- Create: `lib/tasks/planning_and_execution/add_filter_dimension.dart`
- Modify: `lib/tasks/task_catalog.dart`

This task makes Tasks 8 and 9's task classes compile.

- [ ] **Step 1: Add the enum value**

Edit `lib/core/category.dart`. Replace with:

```dart
enum Category {
  uiFromSpec,
  stateManagement,
  bugFix,
  refactor,
  widgetTesting,
  planningAndExecution;

  String get label => switch (this) {
        Category.uiFromSpec => 'UI from spec',
        Category.stateManagement => 'State management',
        Category.bugFix => 'Bug fix',
        Category.refactor => 'Refactor',
        Category.widgetTesting => 'Widget testing',
        Category.planningAndExecution => 'Planning & execution',
      };
}
```

- [ ] **Step 2: Create `AddEvaluatorTypeTask`**

Create `lib/tasks/planning_and_execution/add_evaluator_type.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/core/plan_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class AddEvaluatorTypeTask extends BenchmarkTask {
  static const _root =
      'lib/tasks/planning_and_execution/fixtures/add_evaluator_type';
  static const _planAsset =
      'lib/tasks/planning_and_execution/plans/add_evaluator_type.v1.md';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/evaluator.dart',
      'test/coverage_evaluator_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};
  ReferencePlan? _plan;

  @override
  String get id => 'planning_and_execution.add_evaluator_type';

  @override
  Category get category => Category.planningAndExecution;

  @override
  bool get isFlutter => false;

  @override
  bool get hasReferencePlan => true;

  @override
  String get prompt => '''
You are given a small Dart package that defines an `Evaluator` interface in `lib/evaluator.dart` and an acceptance test in `test/coverage_evaluator_test.dart`.

Create `lib/coverage_evaluator.dart` containing a class `CoverageEvaluator` that implements `Evaluator`. The class must:

- Have `id` returning the string `'coverage'`.
- Implement `evaluate(EvaluationContext ctx)` returning an `EvaluationResult` with `id: 'coverage'` and a `score` in `[0, 1]`.

The provided acceptance test must pass.

Return ONLY the contents of `lib/coverage_evaluator.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isEmpty) {
      _fixtures = await _loader.load();
    }
    _plan ??= await PlanLoader.load(assetPath: _planAsset, version: 1);
  }

  @override
  String get generatedCodePath => 'lib/coverage_evaluator.dart';

  @override
  String? get judgeRubric => null;

  @override
  ReferencePlan? get referencePlan => _plan;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
      ];
}
```

- [ ] **Step 3: Create `AddFilterDimensionTask`**

Create `lib/tasks/planning_and_execution/add_filter_dimension.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/core/plan_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class AddFilterDimensionTask extends BenchmarkTask {
  static const _root =
      'lib/tasks/planning_and_execution/fixtures/add_filter_dimension';
  static const _planAsset =
      'lib/tasks/planning_and_execution/plans/add_filter_dimension.v1.md';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/filter.dart',
      'test/category_filter_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};
  ReferencePlan? _plan;

  @override
  String get id => 'planning_and_execution.add_filter_dimension';

  @override
  Category get category => Category.planningAndExecution;

  @override
  bool get isFlutter => false;

  @override
  bool get hasReferencePlan => true;

  @override
  String get prompt => '''
You are given a small Dart package that defines `Filter` and `Item` types in `lib/filter.dart` and an acceptance test in `test/category_filter_test.dart`.

Create `lib/category_filter.dart` containing a class `CategoryFilter` that implements `Filter`. The constructor takes a single named argument `category` of type `String`. The `matches(Item)` method must:

- Return `true` for any item if the filter's `category` is empty.
- Otherwise return `true` iff `item.category == filter.category`.

The provided acceptance test must pass.

Return ONLY the contents of `lib/category_filter.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isEmpty) {
      _fixtures = await _loader.load();
    }
    _plan ??= await PlanLoader.load(assetPath: _planAsset, version: 1);
  }

  @override
  String get generatedCodePath => 'lib/category_filter.dart';

  @override
  String? get judgeRubric => null;

  @override
  ReferencePlan? get referencePlan => _plan;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
      ];
}
```

- [ ] **Step 4: Register both new tasks in the catalog**

Edit `lib/tasks/task_catalog.dart`. Replace with:

```dart
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/tasks/bug_fix/async_race_condition.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:dart_arena/tasks/planning_and_execution/add_evaluator_type.dart';
import 'package:dart_arena/tasks/planning_and_execution/add_filter_dimension.dart';
import 'package:dart_arena/tasks/refactor/callback_hell.dart';
import 'package:dart_arena/tasks/refactor/god_widget.dart';
import 'package:dart_arena/tasks/state_management/counter_bloc.dart';
import 'package:dart_arena/tasks/state_management/shopping_cart_bloc.dart';
import 'package:dart_arena/tasks/ui_from_spec/expandable_list_tile.dart';
import 'package:dart_arena/tasks/ui_from_spec/profile_card.dart';
import 'package:dart_arena/tasks/widget_testing/form_validation.dart';
import 'package:dart_arena/tasks/widget_testing/todo_input.dart';

TaskRegistry buildDefaultTaskRegistry() {
  final registry = TaskRegistry();
  registry.register(OffByOnePaginationTask());
  registry.register(CounterBlocTask());
  registry.register(ShoppingCartBlocTask());
  registry.register(ProfileCardTask());
  registry.register(ExpandableListTileTask());
  registry.register(GodWidgetTask());
  registry.register(CallbackHellTask());
  registry.register(TodoInputTestTask());
  registry.register(FormValidationTestTask());
  registry.register(AsyncRaceConditionTask());
  registry.register(AddEvaluatorTypeTask());
  registry.register(AddFilterDimensionTask());
  return registry;
}
```

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues. The two new task classes now compile because `Category.planningAndExecution` exists and both classes are created in this task.

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS — including the two new task classes' test paths via the registry. (No dedicated per-task test file is shipped in this plan; the smoke check is "registry builds without throwing" which is exercised whenever any test boots `App`.)

- [ ] **Step 7: Commit**

```bash
git add lib/core/category.dart lib/tasks/task_catalog.dart lib/tasks/planning_and_execution/add_evaluator_type.dart lib/tasks/planning_and_execution/add_filter_dimension.dart
git commit -m "feat(tasks): register Category.planningAndExecution and the two new tasks in the catalog"
```

---

## Task 11: `NewRunPage` toggle for "Use reference plan"

**Files:**
- Modify: `lib/ui/pages/new_run_page.dart`
- Modify: `lib/app.dart` (wire `PlanDao` into the `/run` route)
- Create: `test/ui/pages/new_run_page_plan_toggle_test.dart`

The toggle is a `SwitchListTile` placed below the existing task picker. Disabled when no selected task has `hasReferencePlan == true`. Enabled label dynamically reads "Use reference plan (X of Y selected tasks)".

- [ ] **Step 1: Add the toggle state and UI to `NewRunPage`**

Edit `lib/ui/pages/new_run_page.dart`. Add a state field on `_NewRunPageState`:

```dart
bool _useReferencePlan = false;
```

In `build()`, just below the closing parenthesis of `_TaskPicker(...)` and **above** the `Divider(height: 32)`, insert a new `_PlanToggle` widget:

```dart
const SizedBox(height: 8),
_PlanToggle(
  registry: _registry,
  selectedTaskIds: _selectedTaskIds,
  value: _useReferencePlan,
  onChanged: (v) => setState(() => _useReferencePlan = v),
),
```

In `_startRun`, change the `goRouter.push(...)` `extra:` argument to include `useReferencePlan`:

```dart
extra: StartRunConfig(
  tasks: selectedTasks,
  providers: selectedProviders,
  modelByProvider: modelMap,
  evaluatorConfig: evaluatorConfig,
  weights: weights,
  useReferencePlan: _useReferencePlan,
  name: _label.trim().isEmpty ? null : _label.trim(),
),
```

At the bottom of the file, add the `_PlanToggle` widget:

```dart
class _PlanToggle extends StatelessWidget {
  const _PlanToggle({
    required this.registry,
    required this.selectedTaskIds,
    required this.value,
    required this.onChanged,
  });

  final TaskRegistry registry;
  final Set<String> selectedTaskIds;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected =
        registry.all().where((t) => selectedTaskIds.contains(t.id)).toList();
    final withPlan =
        selected.where((t) => t.hasReferencePlan).length;
    final canEnable = withPlan > 0;
    final label = canEnable
        ? 'Use reference plan ($withPlan of ${selected.length} selected tasks)'
        : 'Use reference plan';
    return SwitchListTile(
      title: Text(label),
      subtitle: canEnable
          ? const Text(
              'Inject a curated plan into the prompt to isolate execution skill from planning skill.',
              style: TextStyle(fontSize: 12),
            )
          : const Text(
              'Select a planning task to enable.',
              style: TextStyle(fontSize: 12),
            ),
      value: canEnable && value,
      onChanged: canEnable ? onChanged : null,
    );
  }
}
```

- [ ] **Step 2: Wire `PlanDao` into the `/run` route**

Edit `lib/app.dart`. Add an import:

```dart
import 'package:dart_arena/storage/dao/plan_dao.dart';
```

In the `MultiRepositoryProvider` providers list, add a new entry alongside `RunDao`:

```dart
RepositoryProvider<PlanDao>(
  create: (ctx) => PlanDao(ctx.read<AppDatabase>()),
),
```

In the `/run` route's `BlocProvider.create`, pass `planDao` to `RunBloc`:

```dart
final bloc = RunBloc(
  workdirManager: ctx.read<WorkdirManager>(),
  runDao: ctx.read<RunDao>(),
  planDao: ctx.read<PlanDao>(),
  weights: cfg.weights,
  now: () => DateTime.now(),
  idGenerator: () => 'run-${DateTime.now().millisecondsSinceEpoch}',
);
bloc.add(StartRun(
  tasks: cfg.tasks,
  providers: cfg.providers,
  modelByProvider: cfg.modelByProvider,
  evaluatorConfig: cfg.evaluatorConfig,
  useReferencePlan: cfg.useReferencePlan,
  name: cfg.name,
));
```

- [ ] **Step 3: Write the toggle widget test**

Create `test/ui/pages/new_run_page_plan_toggle_test.dart`:

```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/start_run_config.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/ui/pages/new_run_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _NoPlanTask extends BenchmarkTask {
  @override
  String get id => 'no-plan';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'no plan';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/x.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [];
}

class _PlanTask extends BenchmarkTask {
  @override
  String get id => 'with-plan';
  @override
  Category get category => Category.planningAndExecution;
  @override
  String get prompt => 'plan';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/y.dart';
  @override
  String? get judgeRubric => null;
  @override
  bool get hasReferencePlan => true;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [];
}

Future<Widget> _wrap(Widget child) async {
  final tmp = await Directory.systemTemp.createTemp('dart_arena_toggle_');
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AppDatabase>.value(value: db),
      RepositoryProvider<WorkdirManager>.value(value: WorkdirManager(root: tmp)),
      RepositoryProvider<SettingsRepository>.value(value: SettingsRepository()),
      RepositoryProvider<RunDao>(create: (ctx) => RunDao(ctx.read<AppDatabase>())),
      RepositoryProvider<PlanDao>(create: (ctx) => PlanDao(ctx.read<AppDatabase>())),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('toggle disabled when no selected task hasReferencePlan',
      (tester) async {
    final reg = TaskRegistry()..register(_NoPlanTask());
    await tester.pumpWidget(await _wrap(
      NewRunPage(registry: reg, providers: const []),
    ));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.onChanged, isNull);
    expect(find.text('Select a planning task to enable.'), findsOneWidget);
  });

  testWidgets('toggle enabled when at least one selected task hasReferencePlan',
      (tester) async {
    final reg = TaskRegistry()
      ..register(_PlanTask())
      ..register(_NoPlanTask());
    await tester.pumpWidget(await _wrap(
      NewRunPage(registry: reg, providers: const []),
    ));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.onChanged, isNotNull);
    expect(
      find.textContaining('1 of 2 selected tasks'),
      findsOneWidget,
    );
  });

  testWidgets('toggling propagates useReferencePlan into StartRunConfig',
      (tester) async {
    final reg = TaskRegistry()..register(_PlanTask());

    Object? capturedExtra;
    final router = GoRouter(
      initialLocation: '/new-run',
      routes: [
        GoRoute(
          path: '/new-run',
          builder: (_, __) => NewRunPage(
            registry: reg,
            providers: const [_FakeProvider()],
          ),
        ),
        GoRoute(
          path: '/run',
          builder: (context, state) {
            capturedExtra = state.extra;
            return const Scaffold(body: Text('captured'));
          },
        ),
      ],
    );

    final tmp = await Directory.systemTemp.createTemp('dart_arena_toggle_2_');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppDatabase>.value(value: db),
        RepositoryProvider<WorkdirManager>.value(value: WorkdirManager(root: tmp)),
        RepositoryProvider<SettingsRepository>.value(value: SettingsRepository()),
        RepositoryProvider<RunDao>(create: (ctx) => RunDao(ctx.read<AppDatabase>())),
        RepositoryProvider<PlanDao>(create: (ctx) => PlanDao(ctx.read<AppDatabase>())),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    // Flip the toggle on.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // Check the provider and provide a model id.
    await tester.tap(find.text('Fake'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Model id'),
      'fake-1',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Run'));
    await tester.pumpAndSettle();

    expect(capturedExtra, isA<StartRunConfig>());
    expect((capturedExtra! as StartRunConfig).useReferencePlan, isTrue);
  });
}

class _FakeProvider implements ModelProvider {
  const _FakeProvider();
  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<String>> listModels() async => const [];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => throw UnimplementedError();
}
```

- [ ] **Step 4: Run the toggle test**

Run: `flutter test test/ui/pages/new_run_page_plan_toggle_test.dart`
Expected: PASS for all three tests.

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 6: Run full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/pages/new_run_page.dart lib/app.dart test/ui/pages/new_run_page_plan_toggle_test.dart
git commit -m "feat(new-run): SwitchListTile to toggle reference-plan injection per run"
```

---

## Task 12: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Lint, analyze, and test**

Run in sequence:

```bash
flutter analyze
flutter test
```

Expected: `flutter analyze` reports 0 issues. `flutter test` reports all tests passing — including the new test files added in Tasks 2, 4, 5, 6, 7, and 11.

- [ ] **Step 2: Manual smoke check (optional but recommended)**

Run: `flutter run -d linux`

- New Run → confirm "Planning & execution" category appears with both tasks.
- Confirm the "Use reference plan" `SwitchListTile` is **disabled** with "Select a planning task to enable." when no `Category.planningAndExecution` task is selected.
- Select one of the two new tasks → toggle becomes **enabled**, label reads "Use reference plan (1 of N selected tasks)".
- Toggle ON → start a Run with a real provider → run completes; the executor's prompt logged in the dev tools (or in the `currentRawResponse` payload during progress) contains the `REFERENCE PLAN` block.
- Toggle OFF → re-run → `currentRawResponse` does not contain a `REFERENCE PLAN` block.
- Open Settings → no regression to existing weights editor / API key sections (Plan 7 is untouched).

- [ ] **Step 3: No commit needed for this task** (verification only).

---

## Self-review notes (post-write)

**Spec coverage check** (every Phase B requirement in `docs/specs/2026-05-03-plan-8-planning-and-execution-design.md` mapped to a task or explicitly deferred):

- §2.1 `Category.planningAndExecution` → Task 10.
- §2.1 `MultiFileBenchmarkTask` mixin → **deferred** to Plan 8b. Replaced by `hasReferencePlan` + `referencePlan` on `BenchmarkTask` directly (Task 3).
- §2.1 Three new tasks → **two ship in this plan** (Tasks 8, 9); the stub third task is **dropped** (see scope-reduction note in header).
- §2.1 `Plans` table + `planId` FK + `schemaVersion: 3` → Task 1.
- §2.1 `StartRunConfig.useReferencePlan` → Task 6.
- §2.1 `RunBloc` consumes plan, persists `planId` → Task 7.
- §2.1 `NewRunPage` toggle → Task 11.
- §2.1 Reference-plan upsert idempotent on `(taskId, version)` → Task 2 (`PlanDao.upsertReferencePlan`).
- §2.1 Geometric-mean stage combine, scaffolded inert → Task 4.
- §2.1 `extractDartFiles` multi-file extractor → **deferred** to Plan 8b.
- §2.1 `WorkdirManager.createMultiFileTaskWorkdir` → **deferred** to Plan 8b.
- §2.1 Hidden-test pattern (§6.3 of spec) → **deferred** to Plan 8b (no multi-file tasks ship in this plan; the single-file acceptance tests in Tasks 8/9 are model-visible by necessity, which is acceptable for v1).
- §2.2 Phase A pinned-but-deferred decisions (plan format = fenced ` ```plan ` block, judge gate, two-stage shape) → respected: `buildPromptWithPlan` in Task 6 uses ` ```plan ` and the inert `combineStages` in Task 4 fixes the combination function before Phase A starts.
- §2.3 Phase C directional sketch → respected: `Plans.plannerModelId` column ships in Task 1 and `PlanDao.insertModelPlan` in Task 2, even though no caller in this plan uses them.
- §6.2 "never edit a published plan in place" → encoded in `PlanDao.upsertReferencePlan` (Task 2): if a row exists for `(taskId, version)`, the new artifact is silently ignored. Authors must bump `version` to ship a change.
- §6.4 Toggle UX showing "X of Y" → Task 11's `_PlanToggle` widget.
- §7 commit plan ordering — preserved as 12 commits (`writing-plans` produced one extra split for the 2nd task as a follow-the-pattern repetition vs the spec's lump).

**Type consistency check**: `StartRunConfig.useReferencePlan` ↔ `StartRun.useReferencePlan` ↔ `RunBloc._onStart`'s `event.useReferencePlan` ↔ `_NewRunPageState._useReferencePlan` — all `bool`, default `false`. `BenchmarkTask.hasReferencePlan` is synchronous UI metadata; `ReferencePlan.markdown` remains lazy-loaded and flows from `BenchmarkTask.referencePlan!.markdown` after `ensureLoaded()` to `buildPromptWithPlan(planMarkdown:)` to the model. `planId: String?` is consistent on `PlanDao.upsertReferencePlan` (return), `TaskRunResult.planId`, and `TaskRuns.planId` (Drift column).

**Placeholder scan**: no TODO / TBD / "implement later" / "similar to Task N" / "add error handling" patterns left in code-changing steps. Every step contains the actual code or a precise diff instruction.

**Asset-loading reminder**: `pubspec.yaml` asset registration is split across Tasks 8 and 9. `flutter run` and `flutter test` automatically pick up the new entries; no `flutter pub get` is required after editing `pubspec.yaml` because the existing dev environment already has the dependencies installed.

**Order-dependency note**: Tasks 8 and 9 create only fixtures, plan markdown, and asset entries. Task classes are created in Task 10 after `Category.planningAndExecution` is added, so the worktree never contains a Dart file that references a missing enum value.
