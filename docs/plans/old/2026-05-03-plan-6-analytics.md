# dart_arena — Plan 6: Analytics (Dashboard + Leaderboard)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stub `HomePage` with a `DashboardPage` (in-progress banner + per-category showcase strip + recent activity), add a new `LeaderboardPage` (`/leaderboard`) answering "which model wins?" via a ranked list + radar/bar detail pane, and introduce a single pure mapping (`Dimensions`) that folds raw evaluator scores into four interpretable axes — Intelligence / Speed / Elegance / Reliability.

**Architecture:** New top-level `lib/analytics/` module owns the pure dimension math (`Dimensions`), the filter value object (`LeaderboardFilter`), and a read-only repository (`LeaderboardRepository`) that aggregates on-demand from the existing `runs` × `task_runs` × `evaluations` tables. Two new `go_router` routes plus seven small focused widgets compose the two new pages. No schema migration. No rollup table. All filter & selection state is mirrored to URL query params for deep-linkability.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, flutter_bloc (existing), drift (existing), go_router (existing), `fl_chart ^0.69.0` (already in `pubspec.yaml` since Plan 1 — no new deps).

**Predecessors:** Plan 1 (foundation), Plan 2 (cloud providers), Plan 3 (evaluators + scoring), Plan 4 (data & navigation), Plan 5 (benchmark content) — all implemented.

**Spec:** `docs/specs/2026-05-03-plan-6-analytics-design.md`.

---

## File map (this plan)

### Created

- `lib/analytics/dimensions.dart` — `Dimensions`, `ScoreDimension`, formulas
- `lib/analytics/leaderboard_filter.dart` — `LeaderboardFilter`, `DateRange`
- `lib/analytics/leaderboard_repository.dart` — `LeaderboardRepository`, `ModelRanking`, `ModelDetail`, `PerTaskScore`
- `lib/ui/widgets/run_row.dart` — extracted from `RunHistoryPage._RunTile`
- `lib/ui/widgets/dimension_radar.dart` — `fl_chart` radar wrapper
- `lib/ui/widgets/per_task_bar_chart.dart` — `fl_chart` bar wrapper, taps drill down
- `lib/ui/widgets/leaderboard_filters.dart` — header strip widget
- `lib/ui/widgets/ranked_models_list.dart` — left-pane list widget
- `lib/ui/widgets/showcase_card.dart` — per-category top-model card
- `lib/ui/widgets/in_progress_banner.dart` — dashboard banner widget
- `lib/ui/widgets/recent_runs_strip.dart` — recent activity widget
- `lib/ui/pages/leaderboard_page.dart` — new
- `lib/ui/pages/dashboard_page.dart` — replaces `home_page.dart`
- `test/analytics/dimensions_test.dart`
- `test/analytics/leaderboard_repository_test.dart`
- `test/ui/widgets/run_row_test.dart`
- `test/ui/widgets/dimension_radar_test.dart`
- `test/ui/widgets/per_task_bar_chart_test.dart`
- `test/ui/widgets/leaderboard_filters_test.dart`
- `test/ui/widgets/ranked_models_list_test.dart`
- `test/ui/widgets/showcase_card_test.dart`
- `test/ui/widgets/in_progress_banner_test.dart`
- `test/ui/widgets/recent_runs_strip_test.dart`
- `test/ui/pages/leaderboard_page_test.dart`
- `test/ui/pages/dashboard_page_test.dart`

### Modified

- `lib/app.dart` — replace `HomePage` import with `DashboardPage`, add `/leaderboard` route
- `lib/ui/pages/run_history_page.dart` — replace inline `_RunTile` with shared `RunRow` widget

### Deleted

- `lib/ui/pages/home_page.dart`

### Untouched

- `lib/storage/database.dart` (no schema change)
- `lib/storage/dao/run_dao.dart` (analytics reads through new repository, not DAO)
- All evaluator, provider, task, and runner code

---

## Task 1: `Dimensions` value object + dimension enum (failing test scaffold)

**Files:**
- Create: `lib/analytics/dimensions.dart`
- Create: `test/analytics/dimensions_test.dart`

This task only puts the type and constants in place so later tasks can fill in the per-formula logic test-by-test.

- [ ] **Step 1: Write the type-shape test**

Create `test/analytics/dimensions_test.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dimensions.empty returns all-zero', () {
    final d = Dimensions.fromTaskRuns(const [], const {});
    expect(d.intelligence, 0.0);
    expect(d.speed, 0.0);
    expect(d.elegance, 0.0);
    expect(d.reliability, 0.0);
    expect(d.overall, 0.0);
    expect(d.problems, 0);
  });

  test('ScoreDimension enum exposes the four axes plus overall', () {
    expect(ScoreDimension.values, [
      ScoreDimension.overall,
      ScoreDimension.intelligence,
      ScoreDimension.speed,
      ScoreDimension.elegance,
      ScoreDimension.reliability,
    ]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/analytics/dimensions_test.dart`
Expected: FAIL ("Target of URI doesn't exist: package:dart_arena/analytics/dimensions.dart").

- [ ] **Step 3: Implement the minimal type to make the empty-input test pass**

Create `lib/analytics/dimensions.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:equatable/equatable.dart';

enum ScoreDimension {
  overall,
  intelligence,
  speed,
  elegance,
  reliability;

  String get label => switch (this) {
        ScoreDimension.overall => 'Overall',
        ScoreDimension.intelligence => 'Intelligence',
        ScoreDimension.speed => 'Speed',
        ScoreDimension.elegance => 'Elegance',
        ScoreDimension.reliability => 'Reliability',
      };
}

class Dimensions extends Equatable {
  const Dimensions({
    required this.intelligence,
    required this.speed,
    required this.elegance,
    required this.reliability,
    required this.problems,
  });

  final double intelligence;
  final double speed;
  final double elegance;
  final double reliability;
  final int problems;

  // Floor: a model that responds in ~2s is fully fast.
  static const double latencyLoMs = 2000;
  // Ceiling: a model that takes ~60s is fully slow (typical agent-mode cap).
  static const double latencyHiMs = 60000;
  // Aggregate score above which a task counts as "passed" for reliability.
  static const double reliabilityThreshold = 0.5;

  double get overall =>
      (intelligence + speed + elegance + reliability) / 4.0;

  double byDimension(ScoreDimension d) => switch (d) {
        ScoreDimension.overall => overall,
        ScoreDimension.intelligence => intelligence,
        ScoreDimension.speed => speed,
        ScoreDimension.elegance => elegance,
        ScoreDimension.reliability => reliability,
      };

  static const Dimensions zero = Dimensions(
    intelligence: 0,
    speed: 0,
    elegance: 0,
    reliability: 0,
    problems: 0,
  );

  static Dimensions fromTaskRuns(
    List<TaskRun> taskRuns,
    Map<String, List<Evaluation>> evalsByTaskRunId,
  ) {
    if (taskRuns.isEmpty) return Dimensions.zero;
    return _computeDimensions(taskRuns, evalsByTaskRunId);
  }

  @override
  List<Object?> get props =>
      [intelligence, speed, elegance, reliability, problems];
}

Dimensions _computeDimensions(
  List<TaskRun> taskRuns,
  Map<String, List<Evaluation>> evalsByTaskRunId,
) {
  // Filled in by subsequent tasks; for now return zero so the shape compiles.
  return Dimensions.zero;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/analytics/dimensions_test.dart`
Expected: PASS, both tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/analytics/dimensions.dart test/analytics/dimensions_test.dart
git commit -m "feat(analytics): scaffold Dimensions + ScoreDimension"
```

---

## Task 2: `Dimensions.fromTaskRuns` — Reliability formula

**Files:**
- Modify: `lib/analytics/dimensions.dart`
- Modify: `test/analytics/dimensions_test.dart`

Reliability is the simplest formula and a good starting pin.

- [ ] **Step 1: Add a helper for building fake `TaskRun` rows in tests**

Open `test/analytics/dimensions_test.dart` and add at the bottom of the file (above `void main`):

```dart
import 'package:dart_arena/storage/database.dart';

TaskRun _tr({
  required String id,
  required double aggregate,
  int latencyMs = 5000,
}) =>
    TaskRun(
      id: id,
      runId: 'r1',
      providerId: 'p',
      modelId: 'm',
      taskId: 't',
      responseText: '',
      promptTokens: null,
      completionTokens: null,
      latencyMs: latencyMs,
      aggregateScore: aggregate,
      completedAt: DateTime(2026, 5, 3),
    );
```

(Move the existing `import 'package:dart_arena/storage/database.dart';` line up to the import block at the top if it isn't already there.)

- [ ] **Step 2: Add the failing test**

Add inside `main`:

```dart
  group('reliability', () {
    test('100% pass when all task runs >= threshold', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 0.9),
        _tr(id: '2', aggregate: 0.5),
      ], const {});
      expect(d.reliability, 1.0);
    });

    test('50% pass when half are below threshold', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 0.8),
        _tr(id: '2', aggregate: 0.49),
      ], const {});
      expect(d.reliability, 0.5);
    });
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/analytics/dimensions_test.dart`
Expected: FAIL — both new tests fail with `expected: 1.0  actual: 0.0`.

- [ ] **Step 4: Implement reliability inside `_computeDimensions`**

Replace the body of `_computeDimensions` in `lib/analytics/dimensions.dart`:

```dart
Dimensions _computeDimensions(
  List<TaskRun> taskRuns,
  Map<String, List<Evaluation>> evalsByTaskRunId,
) {
  final reliabilityPasses =
      taskRuns.where((t) => t.aggregateScore >= Dimensions.reliabilityThreshold).length;
  final reliability = reliabilityPasses / taskRuns.length;
  return Dimensions(
    intelligence: 0,
    speed: 0,
    elegance: 0,
    reliability: reliability,
    problems: 0,
  );
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/analytics/dimensions_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 6: Commit**

```bash
git add lib/analytics/dimensions.dart test/analytics/dimensions_test.dart
git commit -m "feat(analytics): Dimensions.reliability formula"
```

---

## Task 3: `Dimensions.fromTaskRuns` — Speed formula

**Files:**
- Modify: `lib/analytics/dimensions.dart`
- Modify: `test/analytics/dimensions_test.dart`

- [ ] **Step 1: Add the failing tests**

Add to `main`:

```dart
  group('speed', () {
    test('latency at floor produces speed = 1.0', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: Dimensions.latencyLoMs.toInt()),
      ], const {});
      expect(d.speed, 1.0);
    });

    test('latency at ceiling produces speed = 0.0', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: Dimensions.latencyHiMs.toInt()),
      ], const {});
      expect(d.speed, 0.0);
    });

    test('latency above ceiling clamps to 0.0', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: 120000),
      ], const {});
      expect(d.speed, 0.0);
    });

    test('latency below floor clamps to 1.0', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: 500),
      ], const {});
      expect(d.speed, 1.0);
    });

    test('uses median across task runs', () {
      // medians: 5000ms -> normalized = 1 - (5000-2000)/(60000-2000) ≈ 0.948
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: 1000),
        _tr(id: '2', aggregate: 1.0, latencyMs: 5000),
        _tr(id: '3', aggregate: 1.0, latencyMs: 50000),
      ], const {});
      expect(d.speed, closeTo(0.948, 0.01));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/analytics/dimensions_test.dart -p chrome,vm`
Expected: FAIL — speed tests fail with `expected: 1.0  actual: 0.0`.

- [ ] **Step 3: Add the speed computation to `_computeDimensions`**

Edit `lib/analytics/dimensions.dart`. Replace the body of `_computeDimensions`:

```dart
Dimensions _computeDimensions(
  List<TaskRun> taskRuns,
  Map<String, List<Evaluation>> evalsByTaskRunId,
) {
  final reliabilityPasses = taskRuns
      .where((t) => t.aggregateScore >= Dimensions.reliabilityThreshold)
      .length;
  final reliability = reliabilityPasses / taskRuns.length;

  final latencies = taskRuns.map((t) => t.latencyMs.toDouble()).toList()
    ..sort();
  final median = latencies[latencies.length ~/ 2];
  final span = Dimensions.latencyHiMs - Dimensions.latencyLoMs;
  final raw = 1 - (median - Dimensions.latencyLoMs) / span;
  final speed = raw.clamp(0.0, 1.0).toDouble();

  return Dimensions(
    intelligence: 0,
    speed: speed,
    elegance: 0,
    reliability: reliability,
    problems: 0,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/analytics/dimensions_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/analytics/dimensions.dart test/analytics/dimensions_test.dart
git commit -m "feat(analytics): Dimensions.speed via median latency"
```

---

## Task 4: `Dimensions.fromTaskRuns` — Intelligence formula

**Files:**
- Modify: `lib/analytics/dimensions.dart`
- Modify: `test/analytics/dimensions_test.dart`

Intelligence = weighted mean of `compile`, `analyze`, `test`, `test_author`, `widget_tree` evaluator scores using the existing `defaultEvaluatorWeights`. We import `lib/core/scoring.dart` to keep weights centralised.

- [ ] **Step 1: Add a helper for building fake `Evaluation` rows in tests**

Add to the helpers area in `test/analytics/dimensions_test.dart`:

```dart
Evaluation _ev({
  required String taskRunId,
  required String evaluatorId,
  required double score,
  bool? passed,
}) =>
    Evaluation(
      id: '$taskRunId-$evaluatorId',
      taskRunId: taskRunId,
      evaluatorId: evaluatorId,
      passed: passed ?? (score >= 0.5),
      score: score,
      rationale: null,
      detailsJson: '{}',
    );
```

- [ ] **Step 2: Add failing tests**

```dart
  group('intelligence', () {
    test('mean of correctness evaluators across all task runs', () {
      // Two task runs, each with compile=1.0 and test=0.5.
      // weights: compile=0.5, test=1.0 -> num=(1*0.5 + 0.5*1.0)*2 = 2.0; den=(0.5+1.0)*2 = 3.0; mean=2/3 ≈ 0.667
      final tr1 = _tr(id: '1', aggregate: 1.0);
      final tr2 = _tr(id: '2', aggregate: 0.5);
      final d = Dimensions.fromTaskRuns([tr1, tr2], {
        '1': [
          _ev(taskRunId: '1', evaluatorId: 'compile', score: 1.0),
          _ev(taskRunId: '1', evaluatorId: 'test', score: 0.5),
        ],
        '2': [
          _ev(taskRunId: '2', evaluatorId: 'compile', score: 1.0),
          _ev(taskRunId: '2', evaluatorId: 'test', score: 0.5),
        ],
      });
      expect(d.intelligence, closeTo(2.0 / 3.0, 0.01));
    });

    test('ignores non-correctness evaluators (judge, diff_size)', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns([tr], {
        '1': [
          _ev(taskRunId: '1', evaluatorId: 'compile', score: 1.0),
          _ev(taskRunId: '1', evaluatorId: 'llm_judge', score: 0.0),
          _ev(taskRunId: '1', evaluatorId: 'diff_size', score: 0.0),
        ],
      });
      // Only compile (1.0) folds into intelligence.
      expect(d.intelligence, 1.0);
    });

    test('no correctness evaluators present yields 0.0', () {
      final tr = _tr(id: '1', aggregate: 0.0);
      final d = Dimensions.fromTaskRuns([tr], {
        '1': [
          _ev(taskRunId: '1', evaluatorId: 'llm_judge', score: 1.0),
        ],
      });
      expect(d.intelligence, 0.0);
    });
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/analytics/dimensions_test.dart`
Expected: FAIL — intelligence tests get `0.0`.

- [ ] **Step 4: Implement intelligence**

In `lib/analytics/dimensions.dart`, add the import:

```dart
import 'package:dart_arena/core/scoring.dart';
```

Add a private constant near the top:

```dart
const _correctnessEvaluatorIds = {
  'compile',
  'analyze',
  'test',
  'test_author',
  'widget_tree',
};
```

Replace `_computeDimensions`:

```dart
Dimensions _computeDimensions(
  List<TaskRun> taskRuns,
  Map<String, List<Evaluation>> evalsByTaskRunId,
) {
  final reliabilityPasses = taskRuns
      .where((t) => t.aggregateScore >= Dimensions.reliabilityThreshold)
      .length;
  final reliability = reliabilityPasses / taskRuns.length;

  final latencies = taskRuns.map((t) => t.latencyMs.toDouble()).toList()
    ..sort();
  final median = latencies[latencies.length ~/ 2];
  final span = Dimensions.latencyHiMs - Dimensions.latencyLoMs;
  final speed = (1 - (median - Dimensions.latencyLoMs) / span)
      .clamp(0.0, 1.0)
      .toDouble();

  var intelligenceNum = 0.0;
  var intelligenceDen = 0.0;
  for (final tr in taskRuns) {
    for (final e in evalsByTaskRunId[tr.id] ?? const <Evaluation>[]) {
      if (!_correctnessEvaluatorIds.contains(e.evaluatorId)) continue;
      final w = defaultEvaluatorWeights[e.evaluatorId] ?? 1.0;
      intelligenceNum += e.score * w;
      intelligenceDen += w;
    }
  }
  final intelligence =
      intelligenceDen == 0 ? 0.0 : intelligenceNum / intelligenceDen;

  return Dimensions(
    intelligence: intelligence,
    speed: speed,
    elegance: 0,
    reliability: reliability,
    problems: 0,
  );
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/analytics/dimensions_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/analytics/dimensions.dart test/analytics/dimensions_test.dart
git commit -m "feat(analytics): Dimensions.intelligence weighted mean"
```

---

## Task 5: `Dimensions.fromTaskRuns` — Elegance formula and Problems counter

**Files:**
- Modify: `lib/analytics/dimensions.dart`
- Modify: `test/analytics/dimensions_test.dart`

Elegance = arithmetic mean of `llm_judge` and `diff_size` scores across all evaluations in scope, **using only the evaluators that are present**. Problems = count of evaluations where `passed == false`.

- [ ] **Step 1: Add failing tests**

```dart
  group('elegance + problems', () {
    test('mean of llm_judge and diff_size when both present', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns([tr], {
        '1': [
          _ev(taskRunId: '1', evaluatorId: 'llm_judge', score: 0.8),
          _ev(taskRunId: '1', evaluatorId: 'diff_size', score: 0.2),
        ],
      });
      expect(d.elegance, closeTo(0.5, 0.0001));
    });

    test('uses only judge when diff_size missing', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns([tr], {
        '1': [
          _ev(taskRunId: '1', evaluatorId: 'llm_judge', score: 0.8),
        ],
      });
      expect(d.elegance, 0.8);
    });

    test('zero when neither judge nor diff_size present', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns([tr], {
        '1': [_ev(taskRunId: '1', evaluatorId: 'compile', score: 1.0)],
      });
      expect(d.elegance, 0.0);
    });

    test('problems counts failed evaluations across all task runs', () {
      final tr1 = _tr(id: '1', aggregate: 1.0);
      final tr2 = _tr(id: '2', aggregate: 0.0);
      final d = Dimensions.fromTaskRuns([tr1, tr2], {
        '1': [
          _ev(taskRunId: '1', evaluatorId: 'compile', score: 1.0, passed: true),
          _ev(taskRunId: '1', evaluatorId: 'analyze', score: 0.0, passed: false),
        ],
        '2': [
          _ev(taskRunId: '2', evaluatorId: 'compile', score: 0.0, passed: false),
          _ev(taskRunId: '2', evaluatorId: 'test', score: 0.0, passed: false),
        ],
      });
      expect(d.problems, 3);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/analytics/dimensions_test.dart`
Expected: FAIL — elegance and problems tests fail with `0.0` and `0`.

- [ ] **Step 3: Update `_computeDimensions` to add elegance and problems**

Append inside the existing accumulator loop in `_computeDimensions` (and add new accumulators above the loop):

```dart
  var eleganceSum = 0.0;
  var eleganceCount = 0;
  var problems = 0;
  for (final tr in taskRuns) {
    for (final e in evalsByTaskRunId[tr.id] ?? const <Evaluation>[]) {
      if (!e.passed) problems++;
      if (e.evaluatorId == 'llm_judge' || e.evaluatorId == 'diff_size') {
        eleganceSum += e.score;
        eleganceCount++;
      }
      if (!_correctnessEvaluatorIds.contains(e.evaluatorId)) continue;
      final w = defaultEvaluatorWeights[e.evaluatorId] ?? 1.0;
      intelligenceNum += e.score * w;
      intelligenceDen += w;
    }
  }
  final intelligence =
      intelligenceDen == 0 ? 0.0 : intelligenceNum / intelligenceDen;
  final elegance = eleganceCount == 0 ? 0.0 : eleganceSum / eleganceCount;
```

Then update the `return` to use the new values:

```dart
  return Dimensions(
    intelligence: intelligence,
    speed: speed,
    elegance: elegance,
    reliability: reliability,
    problems: problems,
  );
```

(Replace the previous loop that only computed intelligence; the new loop subsumes it.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/analytics/dimensions_test.dart`
Expected: PASS — all dimensions tests green.

- [ ] **Step 5: Add a final integration sanity test**

```dart
  test('overall is mean of the four dimensions', () {
    final d = Dimensions(
      intelligence: 1.0,
      speed: 0.6,
      elegance: 0.4,
      reliability: 0.0,
      problems: 0,
    );
    expect(d.overall, 0.5);
  });

  test('byDimension dispatches correctly', () {
    const d = Dimensions(
      intelligence: 0.1,
      speed: 0.2,
      elegance: 0.3,
      reliability: 0.4,
      problems: 5,
    );
    expect(d.byDimension(ScoreDimension.intelligence), 0.1);
    expect(d.byDimension(ScoreDimension.speed), 0.2);
    expect(d.byDimension(ScoreDimension.elegance), 0.3);
    expect(d.byDimension(ScoreDimension.reliability), 0.4);
    expect(d.byDimension(ScoreDimension.overall), closeTo(0.25, 0.0001));
  });
```

Run again: `flutter test test/analytics/dimensions_test.dart` — Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/analytics/dimensions.dart test/analytics/dimensions_test.dart
git commit -m "feat(analytics): Dimensions.elegance + problems counter"
```

---

## Task 6: `LeaderboardFilter` and `DateRange` value objects

**Files:**
- Create: `lib/analytics/leaderboard_filter.dart`
- Create: `test/analytics/leaderboard_filter_test.dart`

These are pure value objects shared by the repository, the page state, and URL serialization.

- [ ] **Step 1: Write the test first**

Create `test/analytics/leaderboard_filter_test.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/core/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default filter matches all data', () {
    const f = LeaderboardFilter();
    expect(f.category, isNull);
    expect(f.providerId, isNull);
    expect(f.dateRange, DateRange.allTime);
    expect(f.dimension, ScoreDimension.overall);
  });

  test('DateRange.last7d.from is 7 days before now', () {
    final now = DateTime(2026, 5, 3);
    expect(DateRange.last7d.fromForNow(now), DateTime(2026, 4, 26));
    expect(DateRange.last7d.toForNow(now), DateTime(2026, 5, 3));
  });

  test('DateRange.allTime has null bounds', () {
    expect(DateRange.allTime.fromForNow(DateTime.now()), isNull);
    expect(DateRange.allTime.toForNow(DateTime.now()), isNull);
  });

  test('DateRange.custom uses the configured bounds', () {
    final from = DateTime(2026, 4, 1);
    final to = DateTime(2026, 5, 1);
    final r = DateRange.custom(from: from, to: to);
    expect(r.fromForNow(DateTime.now()), from);
    expect(r.toForNow(DateTime.now()), to);
  });

  test('LeaderboardFilter.copyWith preserves untouched fields', () {
    const f = LeaderboardFilter();
    final f2 = f.copyWith(category: Category.bugFix);
    expect(f2.category, Category.bugFix);
    expect(f2.providerId, isNull);
    expect(f2.dateRange, DateRange.allTime);
    expect(f2.dimension, ScoreDimension.overall);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/analytics/leaderboard_filter_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Implement the value objects**

Create `lib/analytics/leaderboard_filter.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/core/category.dart';
import 'package:equatable/equatable.dart';

class DateRange extends Equatable {
  const DateRange._({this.kind = _Kind.allTime, this.from, this.to});
  final _Kind kind;
  final DateTime? from;
  final DateTime? to;

  static const DateRange allTime = DateRange._();
  static const DateRange last7d = DateRange._(kind: _Kind.last7d);
  static const DateRange last30d = DateRange._(kind: _Kind.last30d);

  factory DateRange.custom({required DateTime from, required DateTime to}) =>
      DateRange._(kind: _Kind.custom, from: from, to: to);

  DateTime? fromForNow(DateTime now) => switch (kind) {
        _Kind.allTime => null,
        _Kind.last7d => now.subtract(const Duration(days: 7)),
        _Kind.last30d => now.subtract(const Duration(days: 30)),
        _Kind.custom => from,
      };

  DateTime? toForNow(DateTime now) => switch (kind) {
        _Kind.allTime => null,
        _Kind.last7d => now,
        _Kind.last30d => now,
        _Kind.custom => to,
      };

  String toQueryParam() => switch (kind) {
        _Kind.allTime => 'all',
        _Kind.last7d => '7d',
        _Kind.last30d => '30d',
        _Kind.custom => '${from!.toIso8601String()}..${to!.toIso8601String()}',
      };

  static DateRange fromQueryParam(String? raw) {
    if (raw == null || raw == 'all') return DateRange.allTime;
    if (raw == '7d') return DateRange.last7d;
    if (raw == '30d') return DateRange.last30d;
    final parts = raw.split('..');
    if (parts.length == 2) {
      final f = DateTime.tryParse(parts[0]);
      final t = DateTime.tryParse(parts[1]);
      if (f != null && t != null) return DateRange.custom(from: f, to: t);
    }
    return DateRange.allTime;
  }

  @override
  List<Object?> get props => [kind, from, to];
}

enum _Kind { allTime, last7d, last30d, custom }

class LeaderboardFilter extends Equatable {
  const LeaderboardFilter({
    this.category,
    this.providerId,
    this.dateRange = DateRange.allTime,
    this.dimension = ScoreDimension.overall,
  });

  final Category? category;
  final String? providerId;
  final DateRange dateRange;
  final ScoreDimension dimension;

  LeaderboardFilter copyWith({
    Category? category,
    bool clearCategory = false,
    String? providerId,
    bool clearProviderId = false,
    DateRange? dateRange,
    ScoreDimension? dimension,
  }) =>
      LeaderboardFilter(
        category: clearCategory ? null : (category ?? this.category),
        providerId: clearProviderId ? null : (providerId ?? this.providerId),
        dateRange: dateRange ?? this.dateRange,
        dimension: dimension ?? this.dimension,
      );

  @override
  List<Object?> get props => [category, providerId, dateRange, dimension];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/analytics/leaderboard_filter_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/analytics/leaderboard_filter.dart test/analytics/leaderboard_filter_test.dart
git commit -m "feat(analytics): LeaderboardFilter + DateRange value objects"
```

---

## Task 7: `LeaderboardRepository.rank` — minimal happy path

**Files:**
- Create: `lib/analytics/leaderboard_repository.dart`
- Create: `test/analytics/leaderboard_repository_test.dart`

The repository is read-only over `AppDatabase`. We start with `rank` for the all-time, no-filter case, then layer filters in subsequent tasks.

- [ ] **Step 1: Write the failing test**

Create `test/analytics/leaderboard_repository_test.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({AppDatabase db, RunDao dao})> _seed() async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
  await dao.persistTaskRun(TaskRunResult(
    runId: 'r1',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'bug.off_by_one_pagination',
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration(milliseconds: 5000),
    ),
    evaluations: const [
      EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
      EvaluationResult(evaluatorId: 'test', passed: true, score: 1.0),
    ],
    aggregateScore: 1.0,
    completedAt: DateTime(2026, 5, 1, 0, 5),
  ));
  await dao.persistTaskRun(TaskRunResult(
    runId: 'r1',
    providerId: 'anthropic',
    modelId: 'claude-opus-4.7',
    taskId: 'bug.off_by_one_pagination',
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration(milliseconds: 5000),
    ),
    evaluations: const [
      EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
      EvaluationResult(evaluatorId: 'test', passed: false, score: 0.0),
    ],
    aggregateScore: 0.5,
    completedAt: DateTime(2026, 5, 1, 0, 6),
  ));
  await dao.finishRun('r1', DateTime(2026, 5, 1, 0, 10));
  return (db: db, dao: dao);
}

void main() {
  test('rank returns one ModelRanking per (provider, model) pair', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);

    final rows = await repo.rank(filter: const LeaderboardFilter());

    expect(rows.length, 2);
    final providers = rows.map((r) => r.providerId).toSet();
    expect(providers, {'openai', 'anthropic'});
  });

  test('rank sorts descending by current dimension', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);

    final overall = await repo.rank(
      filter: const LeaderboardFilter(),
    );
    expect(overall.first.modelId, 'gpt-5');
    expect(overall.last.modelId, 'claude-opus-4.7');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/analytics/leaderboard_repository_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Implement `LeaderboardRepository.rank`**

Create `lib/analytics/leaderboard_repository.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';

class ModelRanking extends Equatable {
  const ModelRanking({
    required this.providerId,
    required this.modelId,
    required this.dimensions,
    required this.taskRunCount,
  });

  final String providerId;
  final String modelId;
  final Dimensions dimensions;
  final int taskRunCount;

  String get key => '$providerId:$modelId';

  @override
  List<Object?> get props => [providerId, modelId, dimensions, taskRunCount];
}

class PerTaskScore extends Equatable {
  const PerTaskScore({
    required this.taskId,
    this.category,
    required this.aggregateScore,
    required this.lastRunId,
    required this.lastTaskRunId,
  });

  final String taskId;
  final Category? category;
  final double aggregateScore;
  final String? lastRunId;
  final String? lastTaskRunId;

  @override
  List<Object?> get props =>
      [taskId, category, aggregateScore, lastRunId, lastTaskRunId];
}

class ModelDetail extends Equatable {
  const ModelDetail({required this.ranking, required this.perTask});
  final ModelRanking ranking;
  final List<PerTaskScore> perTask;

  @override
  List<Object?> get props => [ranking, perTask];
}

class LeaderboardRepository {
  LeaderboardRepository(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final AppDatabase _db;
  final DateTime Function() _now;

  Future<List<ModelRanking>> rank({
    required LeaderboardFilter filter,
    Set<String>? taskIdsForCategory,
  }) async {
    final taskRuns = await _filteredTaskRuns(filter, taskIdsForCategory);
    if (taskRuns.isEmpty) return const [];
    final evals = await _evaluationsByTaskRunId(taskRuns.map((t) => t.id));
    final groups = <String, List<TaskRun>>{};
    for (final tr in taskRuns) {
      groups
          .putIfAbsent('${tr.providerId}:${tr.modelId}', () => <TaskRun>[])
          .add(tr);
    }
    final out = <ModelRanking>[];
    groups.forEach((key, rs) {
      out.add(ModelRanking(
        providerId: rs.first.providerId,
        modelId: rs.first.modelId,
        dimensions: Dimensions.fromTaskRuns(rs, evals),
        taskRunCount: rs.length,
      ));
    });
    out.sort((a, b) => b.dimensions
        .byDimension(filter.dimension)
        .compareTo(a.dimensions.byDimension(filter.dimension)));
    return out;
  }

  Future<List<TaskRun>> _filteredTaskRuns(
    LeaderboardFilter filter,
    Set<String>? taskIdsForCategory,
  ) async {
    final q = _db.select(_db.taskRuns);
    final from = filter.dateRange.fromForNow(_now());
    final to = filter.dateRange.toForNow(_now());
    if (from != null) q.where((t) => t.completedAt.isBiggerOrEqualValue(from));
    if (to != null) q.where((t) => t.completedAt.isSmallerOrEqualValue(to));
    if (filter.providerId != null) {
      q.where((t) => t.providerId.equals(filter.providerId!));
    }
    if (filter.category != null && taskIdsForCategory != null) {
      q.where((t) => t.taskId.isIn(taskIdsForCategory));
    }
    return q.get();
  }

  Future<Map<String, List<Evaluation>>> _evaluationsByTaskRunId(
    Iterable<String> ids,
  ) async {
    final rows = await (_db.select(_db.evaluations)
          ..where((e) => e.taskRunId.isIn(ids)))
        .get();
    final out = <String, List<Evaluation>>{};
    for (final r in rows) {
      out.putIfAbsent(r.taskRunId, () => <Evaluation>[]).add(r);
    }
    return out;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/analytics/leaderboard_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/analytics/leaderboard_repository.dart test/analytics/leaderboard_repository_test.dart
git commit -m "feat(analytics): LeaderboardRepository.rank — happy path"
```

---

## Task 8: `LeaderboardRepository.rank` — filter coverage

**Files:**
- Modify: `test/analytics/leaderboard_repository_test.dart`

We've already implemented filter logic in `_filteredTaskRuns`; this task adds coverage tests for each filter dimension.

- [ ] **Step 1: Add filter tests**

Inside `main()`, add:

```dart
  test('provider filter narrows the list', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);
    final rows = await repo.rank(
      filter: const LeaderboardFilter(providerId: 'openai'),
    );
    expect(rows.length, 1);
    expect(rows.single.providerId, 'openai');
  });

  test('date range filter excludes runs outside the window', () async {
    final s = await _seed();
    // last7d as of 2026-04-01 should exclude the seeded task runs from May 1.
    final repo = LeaderboardRepository(
      s.db,
      now: () => DateTime(2026, 4, 1),
    );
    final rows = await repo.rank(
      filter: const LeaderboardFilter(dateRange: DateRange.last7d),
    );
    expect(rows, isEmpty);
  });

  test('category filter intersects with provided taskIdsForCategory', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);
    // Pretend `bug.off_by_one_pagination` is in bugFix; pass it through.
    final rows = await repo.rank(
      filter: const LeaderboardFilter(category: Category.bugFix),
      taskIdsForCategory: {'bug.off_by_one_pagination'},
    );
    expect(rows.length, 2);

    // Different category -> no matching task ids -> empty result.
    final rows2 = await repo.rank(
      filter: const LeaderboardFilter(category: Category.uiFromSpec),
      taskIdsForCategory: {'ui.profile_card'},
    );
    expect(rows2, isEmpty);
  });

  test('rank by speed sorts by latency, not aggregateScore', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
    Future<void> seedTr(String provider, int latencyMs) =>
        dao.persistTaskRun(TaskRunResult(
          runId: 'r1',
          providerId: provider,
          modelId: 'm',
          taskId: 'bug.x',
          response: ModelResponse(
            rawText: '',
            extractedCode: null,
            promptTokens: null,
            completionTokens: null,
            latency: Duration(milliseconds: latencyMs),
          ),
          evaluations: const [
            EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
          ],
          aggregateScore: 1.0,
          completedAt: DateTime(2026, 5, 1, 0, 5),
        ));
    await seedTr('fast', 2000);
    await seedTr('slow', 50000);

    final repo = LeaderboardRepository(db);
    final rows = await repo.rank(
      filter: const LeaderboardFilter(dimension: ScoreDimension.speed),
    );
    expect(rows.first.providerId, 'fast');
  });
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/analytics/leaderboard_repository_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/analytics/leaderboard_repository_test.dart
git commit -m "test(analytics): LeaderboardRepository.rank filter coverage"
```

---

## Task 9: `LeaderboardRepository.detail` — per-task breakdown

**Files:**
- Modify: `lib/analytics/leaderboard_repository.dart`
- Modify: `test/analytics/leaderboard_repository_test.dart`

`detail` returns the selected model's `ModelRanking` plus `PerTaskScore` rows for the per-task bar chart, with `lastRunId` / `lastTaskRunId` for drill-down navigation.

- [ ] **Step 1: Write the failing tests**

Add to `main`:

```dart
  test('detail returns one PerTaskScore per task within filter', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);
    final detail = await repo.detail(
      providerId: 'openai',
      modelId: 'gpt-5',
      filter: const LeaderboardFilter(),
    );
    expect(detail.ranking.providerId, 'openai');
    expect(detail.perTask.length, 1);
    expect(detail.perTask.single.taskId, 'bug.off_by_one_pagination');
    expect(detail.perTask.single.aggregateScore, 1.0);
    expect(detail.perTask.single.lastRunId, 'r1');
    expect(detail.perTask.single.lastTaskRunId, isNotNull);
  });

  test('detail picks the most recent task-run per (model, task)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
    Future<void> seed(DateTime when, double agg) => dao.persistTaskRun(
          TaskRunResult(
            runId: 'r1',
            providerId: 'p',
            modelId: 'm',
            taskId: 'bug.x',
            response: ModelResponse(
              rawText: '',
              extractedCode: null,
              promptTokens: null,
              completionTokens: null,
              latency: const Duration(milliseconds: 5000),
            ),
            evaluations: const [
              EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
            ],
            aggregateScore: agg,
            completedAt: when,
          ),
        );
    await seed(DateTime(2026, 5, 1, 0, 5), 0.4);
    await seed(DateTime(2026, 5, 1, 0, 10), 0.9);
    final repo = LeaderboardRepository(db);
    final detail = await repo.detail(
      providerId: 'p',
      modelId: 'm',
      filter: const LeaderboardFilter(),
    );
    expect(detail.perTask.single.aggregateScore, 0.9); // most recent
  });

  test('detail returns empty perTask when filter excludes all', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(
      s.db,
      now: () => DateTime(2026, 4, 1),
    );
    final detail = await repo.detail(
      providerId: 'openai',
      modelId: 'gpt-5',
      filter: const LeaderboardFilter(dateRange: DateRange.last7d),
    );
    expect(detail.perTask, isEmpty);
    expect(detail.ranking.dimensions, Dimensions.zero);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/analytics/leaderboard_repository_test.dart`
Expected: FAIL — `detail` is not yet implemented.

- [ ] **Step 3: Implement `detail`**

Add to `LeaderboardRepository`:

```dart
  Future<ModelDetail> detail({
    required String providerId,
    required String modelId,
    required LeaderboardFilter filter,
    Set<String>? taskIdsForCategory,
    Map<String, Category>? categoryByTaskId,
  }) async {
    final scoped = filter.copyWith(providerId: providerId);
    final taskRuns =
        (await _filteredTaskRuns(scoped, taskIdsForCategory)).where(
      (t) => t.providerId == providerId && t.modelId == modelId,
    ).toList();
    final evals = taskRuns.isEmpty
        ? const <String, List<Evaluation>>{}
        : await _evaluationsByTaskRunId(taskRuns.map((t) => t.id));
    final ranking = ModelRanking(
      providerId: providerId,
      modelId: modelId,
      dimensions: Dimensions.fromTaskRuns(taskRuns, evals),
      taskRunCount: taskRuns.length,
    );

    final byTask = <String, List<TaskRun>>{};
    for (final tr in taskRuns) {
      byTask.putIfAbsent(tr.taskId, () => <TaskRun>[]).add(tr);
    }
    final perTask = <PerTaskScore>[];
    byTask.forEach((taskId, rs) {
      rs.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      final latest = rs.first;
      perTask.add(PerTaskScore(
        taskId: taskId,
        category: categoryByTaskId?[taskId],
        aggregateScore: latest.aggregateScore,
        lastRunId: latest.runId,
        lastTaskRunId: latest.id,
      ));
    });
    perTask.sort((a, b) => b.aggregateScore.compareTo(a.aggregateScore));
    return ModelDetail(ranking: ranking, perTask: perTask);
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/analytics/leaderboard_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/analytics/leaderboard_repository.dart test/analytics/leaderboard_repository_test.dart
git commit -m "feat(analytics): LeaderboardRepository.detail — per-task breakdown"
```

---

## Task 10: Extract shared `RunRow` widget

**Files:**
- Create: `lib/ui/widgets/run_row.dart`
- Create: `test/ui/widgets/run_row_test.dart`
- Modify: `lib/ui/pages/run_history_page.dart`

`RunHistoryPage` currently has an inline `_RunTile`. We extract it so the dashboard's recent-runs strip renders rows identically. Behavior is identical; existing `run_history_page_test.dart` continues to pass.

- [ ] **Step 1: Write the widget test for the extracted component**

Create `test/ui/widgets/run_row_test.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/run_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Run _r({String? name}) => Run(
      id: 'r1',
      startedAt: DateTime(2026, 5, 2, 10),
      completedAt: DateTime(2026, 5, 2, 10, 5),
      judgeModel: null,
      name: name,
    );

TaskRun _tr(double agg) => TaskRun(
      id: 'tr-${agg.toStringAsFixed(2)}',
      runId: 'r1',
      providerId: 'p',
      modelId: 'm',
      taskId: 't',
      responseText: '',
      promptTokens: null,
      completionTokens: null,
      latencyMs: 1000,
      aggregateScore: agg,
      completedAt: DateTime(2026, 5, 2, 10, 4),
    );

void main() {
  testWidgets('renders run name when present', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunRow(
          run: _r(name: 'experiment-1'),
          taskRuns: [_tr(0.8)],
          onTap: () {},
        ),
      ),
    ));
    expect(find.text('experiment-1'), findsOneWidget);
  });

  testWidgets('falls back to "Run <id>" when name is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunRow(
          run: _r(name: null),
          taskRuns: [_tr(0.8)],
          onTap: () {},
        ),
      ),
    ));
    expect(find.text('Run r1'), findsOneWidget);
  });

  testWidgets('shows progress indicator when run is in progress',
      (tester) async {
    final inProgress = Run(
      id: 'r1',
      startedAt: DateTime(2026, 5, 2),
      completedAt: null,
      judgeModel: null,
      name: null,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunRow(run: inProgress, taskRuns: const [], onTap: () {}),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('tapping invokes onTap callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunRow(
          run: _r(name: 'x'),
          taskRuns: [_tr(0.5)],
          onTap: () => taps++,
        ),
      ),
    ));
    await tester.tap(find.byType(ListTile));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run the test (expect failure)**

Run: `flutter test test/ui/widgets/run_row_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Create the `RunRow` widget**

Create `lib/ui/widgets/run_row.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:flutter/material.dart';

class RunRow extends StatelessWidget {
  const RunRow({
    super.key,
    required this.run,
    required this.taskRuns,
    required this.onTap,
  });

  final Run run;
  final List<TaskRun> taskRuns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = run.name ?? 'Run ${run.id}';
    final taskCount = taskRuns.map((t) => t.taskId).toSet().length;
    final modelCount = taskRuns
        .map((t) => '${t.providerId}/${t.modelId}')
        .toSet()
        .length;
    final avg = taskRuns.isEmpty
        ? null
        : taskRuns.map((t) => t.aggregateScore).reduce((a, b) => a + b) /
            taskRuns.length;
    final ts = run.startedAt.toIso8601String();
    return ListTile(
      title: Text(title),
      subtitle: Text(
        '$ts \u00b7 $taskCount tasks \u00b7 $modelCount models'
        '${avg == null ? '' : ' \u00b7 avg ${avg.toStringAsFixed(2)}'}',
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

- [ ] **Step 4: Run the test (expect pass)**

Run: `flutter test test/ui/widgets/run_row_test.dart`
Expected: PASS.

- [ ] **Step 5: Replace `_RunTile` in `RunHistoryPage`**

Open `lib/ui/pages/run_history_page.dart`. At the top, add:

```dart
import 'package:dart_arena/ui/widgets/run_row.dart';
```

Inside the `ListView.separated`'s `itemBuilder`, replace the `_RunTile(...)` invocation with:

```dart
                  itemBuilder: (context, i) => RunRow(
                    run: rows[i].run,
                    taskRuns: rows[i].taskRuns,
                    onTap: () => context.push('/runs/${rows[i].run.id}'),
                  ),
```

Then **delete the entire `class _RunTile extends StatelessWidget {…}` declaration** at the bottom of the file. The `_RunRowData` private class stays (it's still used by `_load`).

- [ ] **Step 6: Run the existing history-page test to verify regression-free**

Run: `flutter test test/ui/pages/run_history_page_test.dart`
Expected: PASS.

- [ ] **Step 7: Run full analyze to catch any leftover unused imports**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Commit**

```bash
git add lib/ui/widgets/run_row.dart \
        test/ui/widgets/run_row_test.dart \
        lib/ui/pages/run_history_page.dart
git commit -m "refactor(ui): extract RunRow widget for reuse on dashboard"
```

---

## Task 11: `DimensionRadar` widget (fl_chart)

**Files:**
- Create: `lib/ui/widgets/dimension_radar.dart`
- Create: `test/ui/widgets/dimension_radar_test.dart`

Four-spoke radar (Intelligence, Speed, Elegance, Reliability). Selected polygon solid, optional pinned overlay translucent.

- [ ] **Step 1: Write the widget test**

Create `test/ui/widgets/dimension_radar_test.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/ui/widgets/dimension_radar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sample = Dimensions(
    intelligence: 0.8,
    speed: 0.6,
    elegance: 0.4,
    reliability: 1.0,
    problems: 0,
  );

  testWidgets('renders a RadarChart with the four dimension labels',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: DimensionRadar(selected: sample, selectedLabel: 'gpt-5'),
        ),
      ),
    ));
    expect(find.byType(RadarChart), findsOneWidget);
    expect(find.text('Intelligence'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Elegance'), findsOneWidget);
    expect(find.text('Reliability'), findsOneWidget);
  });

  testWidgets('renders an overlay polygon when pinned is provided',
      (tester) async {
    const pinned = Dimensions(
      intelligence: 0.5,
      speed: 0.5,
      elegance: 0.5,
      reliability: 0.5,
      problems: 0,
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: DimensionRadar(
            selected: sample,
            pinned: pinned,
            selectedLabel: 'gpt-5',
            pinnedLabel: 'opus',
          ),
        ),
      ),
    ));
    final chart = tester.widget<RadarChart>(find.byType(RadarChart));
    expect(chart.data.dataSets.length, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/widgets/dimension_radar_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Implement the widget**

Create `lib/ui/widgets/dimension_radar.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DimensionRadar extends StatelessWidget {
  const DimensionRadar({
    super.key,
    required this.selected,
    this.pinned,
    this.selectedLabel,
    this.pinnedLabel,
  });

  final Dimensions selected;
  final Dimensions? pinned;
  final String? selectedLabel;
  final String? pinnedLabel;

  static const _titles = ['Intelligence', 'Speed', 'Elegance', 'Reliability'];

  List<double> _values(Dimensions d) =>
      [d.intelligence, d.speed, d.elegance, d.reliability];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dataSets = <RadarDataSet>[
      RadarDataSet(
        fillColor: scheme.primary.withValues(alpha: 0.4),
        borderColor: scheme.primary,
        entryRadius: 3,
        dataEntries: _values(selected)
            .map((v) => RadarEntry(value: v))
            .toList(),
      ),
      if (pinned != null)
        RadarDataSet(
          fillColor: scheme.secondary.withValues(alpha: 0.25),
          borderColor: scheme.secondary,
          entryRadius: 3,
          dataEntries:
              _values(pinned!).map((v) => RadarEntry(value: v)).toList(),
        ),
    ];

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        tickCount: 4,
        ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
        radarBorderData: BorderSide(color: scheme.outlineVariant),
        gridBorderData: BorderSide(color: scheme.outlineVariant, width: 0.5),
        tickBorderData: BorderSide(color: scheme.outlineVariant, width: 0.5),
        titleTextStyle: Theme.of(context).textTheme.bodySmall,
        getTitle: (i, angle) =>
            RadarChartTitle(text: _titles[i], angle: 0),
        dataSets: dataSets,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/widgets/dimension_radar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/dimension_radar.dart test/ui/widgets/dimension_radar_test.dart
git commit -m "feat(ui): DimensionRadar widget"
```

---

## Task 12: `PerTaskBarChart` widget (fl_chart, tap-to-drill)

**Files:**
- Create: `lib/ui/widgets/per_task_bar_chart.dart`
- Create: `test/ui/widgets/per_task_bar_chart_test.dart`

Horizontal-ish bar chart, one bar per task, sorted descending. Tapping a bar invokes `onTap(score)` so the page can navigate to the run-details deep link.

- [ ] **Step 1: Write the widget test**

Create `test/ui/widgets/per_task_bar_chart_test.dart`:

```dart
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/ui/widgets/per_task_bar_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PerTaskScore _s(String taskId, double v, {Category? c}) => PerTaskScore(
      taskId: taskId,
      category: c,
      aggregateScore: v,
      lastRunId: 'r',
      lastTaskRunId: 'tr-$taskId',
    );

void main() {
  testWidgets('renders one bar per score', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: PerTaskBarChart(
            scores: [
              _s('a', 0.9),
              _s('b', 0.5),
              _s('c', 0.2),
            ],
            onTap: (_) {},
          ),
        ),
      ),
    ));
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.length, 3);
  });

  testWidgets('shows empty-state text when scores list is empty',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PerTaskBarChart(scores: const [], onTap: (_) {}),
      ),
    ));
    expect(find.textContaining('No task data'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test (expect fail)**

Run: `flutter test test/ui/widgets/per_task_bar_chart_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Implement the widget**

Create `lib/ui/widgets/per_task_bar_chart.dart`:

```dart
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PerTaskBarChart extends StatelessWidget {
  const PerTaskBarChart({
    super.key,
    required this.scores,
    required this.onTap,
  });

  final List<PerTaskScore> scores;
  final void Function(PerTaskScore) onTap;

  Color _tint(double v, ColorScheme s) {
    if (v >= 0.8) return Colors.green.shade700;
    if (v >= 0.5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const Center(child: Text('No task data for this filter.'));
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.0,
          minY: 0.0,
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (event is FlTapUpEvent) {
                final spot = response?.spot;
                if (spot == null) return;
                onTap(scores[spot.touchedBarGroupIndex]);
              }
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= scores.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      scores[i].taskId.split('.').last,
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: [
            for (var i = 0; i < scores.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: scores[i].aggregateScore,
                    color: _tint(scores[i].aggregateScore, scheme),
                    width: 16,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test (expect pass)**

Run: `flutter test test/ui/widgets/per_task_bar_chart_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/per_task_bar_chart.dart test/ui/widgets/per_task_bar_chart_test.dart
git commit -m "feat(ui): PerTaskBarChart widget with tap-to-drill"
```

---

## Task 13: `LeaderboardFilters` header strip widget

**Files:**
- Create: `lib/ui/widgets/leaderboard_filters.dart`
- Create: `test/ui/widgets/leaderboard_filters_test.dart`

A row containing four controls: Category dropdown, Provider dropdown, Date-range chips, Dimension dropdown. Pure widget — emits a new `LeaderboardFilter` via `onChanged`.

- [ ] **Step 1: Write the widget test**

Create `test/ui/widgets/leaderboard_filters_test.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/ui/widgets/leaderboard_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('emits new filter when dimension is changed', (tester) async {
    LeaderboardFilter? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LeaderboardFilters(
          filter: const LeaderboardFilter(),
          providerOptions: const ['openai', 'anthropic'],
          onChanged: (f) => captured = f,
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('dim-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speed').last);
    await tester.pumpAndSettle();
    expect(captured?.dimension, ScoreDimension.speed);
  });

  testWidgets('emits new filter when category is set then cleared',
      (tester) async {
    LeaderboardFilter? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return LeaderboardFilters(
            filter: captured ?? const LeaderboardFilter(),
            providerOptions: const ['openai'],
            onChanged: (f) => setState(() => captured = f),
          );
        }),
      ),
    ));
    await tester.tap(find.byKey(const Key('category-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bug fix').last);
    await tester.pumpAndSettle();
    expect(captured?.category, Category.bugFix);
  });

  testWidgets('emits new filter when last 7d chip is tapped', (tester) async {
    LeaderboardFilter? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LeaderboardFilters(
          filter: const LeaderboardFilter(),
          providerOptions: const [],
          onChanged: (f) => captured = f,
        ),
      ),
    ));
    await tester.tap(find.text('7d'));
    await tester.pumpAndSettle();
    expect(captured?.dateRange, DateRange.last7d);
  });
}
```

- [ ] **Step 2: Run test (expect fail)**

Run: `flutter test test/ui/widgets/leaderboard_filters_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Implement the widget**

Create `lib/ui/widgets/leaderboard_filters.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/core/category.dart';
import 'package:flutter/material.dart';

class LeaderboardFilters extends StatelessWidget {
  const LeaderboardFilters({
    super.key,
    required this.filter,
    required this.providerOptions,
    required this.onChanged,
  });

  final LeaderboardFilter filter;
  final List<String> providerOptions;
  final ValueChanged<LeaderboardFilter> onChanged;

  Future<void> _pickCustomRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: filter.dateRange.from != null && filter.dateRange.to != null
          ? DateTimeRange(
              start: filter.dateRange.from!,
              end: filter.dateRange.to!,
            )
          : null,
    );
    if (picked != null) {
      onChanged(filter.copyWith(
        dateRange: DateRange.custom(from: picked.start, to: picked.end),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<Category?>(
            key: const Key('category-dropdown'),
            value: filter.category,
            hint: const Text('All categories'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All categories')),
              for (final c in Category.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (c) => onChanged(filter.copyWith(
              category: c,
              clearCategory: c == null,
            )),
          ),
          DropdownButton<String?>(
            key: const Key('provider-dropdown'),
            value: filter.providerId,
            hint: const Text('All providers'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All providers')),
              for (final p in providerOptions)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (p) => onChanged(filter.copyWith(
              providerId: p,
              clearProviderId: p == null,
            )),
          ),
          _RangeChips(
            range: filter.dateRange,
            onPick: (r) => onChanged(filter.copyWith(dateRange: r)),
            onCustom: () => _pickCustomRange(context),
          ),
          DropdownButton<ScoreDimension>(
            key: const Key('dim-dropdown'),
            value: filter.dimension,
            items: [
              for (final d in ScoreDimension.values)
                DropdownMenuItem(value: d, child: Text(d.label)),
            ],
            onChanged: (d) => d == null
                ? null
                : onChanged(filter.copyWith(dimension: d)),
          ),
        ],
      ),
    );
  }
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({
    required this.range,
    required this.onPick,
    required this.onCustom,
  });
  final DateRange range;
  final ValueChanged<DateRange> onPick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, DateRange value, {VoidCallback? onTapOverride}) {
      return ChoiceChip(
        label: Text(label),
        selected: range == value,
        onSelected: (_) => onTapOverride != null ? onTapOverride() : onPick(value),
      );
    }

    return Wrap(
      spacing: 6,
      children: [
        chip('7d', DateRange.last7d),
        chip('30d', DateRange.last30d),
        chip('All time', DateRange.allTime),
        chip('Custom…', range, onTapOverride: onCustom),
      ],
    );
  }
}
```

(`DateRange.from` and `.to` need to be public — they already are in Task 6. Verify.)

- [ ] **Step 4: Run test (expect pass)**

Run: `flutter test test/ui/widgets/leaderboard_filters_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/leaderboard_filters.dart test/ui/widgets/leaderboard_filters_test.dart
git commit -m "feat(ui): LeaderboardFilters header strip"
```

---

## Task 14: `RankedModelsList` widget

**Files:**
- Create: `lib/ui/widgets/ranked_models_list.dart`
- Create: `test/ui/widgets/ranked_models_list_test.dart`

Left-pane widget. Renders rows of `(rank, model, score, pin)`. Selecting a row → `onSelect`. Tapping pin → `onTogglePin`.

- [ ] **Step 1: Write the test**

Create `test/ui/widgets/ranked_models_list_test.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/ui/widgets/ranked_models_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ModelRanking _r(String model, double overall) => ModelRanking(
      providerId: 'p',
      modelId: model,
      dimensions: Dimensions(
        intelligence: overall,
        speed: overall,
        elegance: overall,
        reliability: overall,
        problems: 0,
      ),
      taskRunCount: 1,
    );

void main() {
  testWidgets('renders one row per ranking with rank index', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RankedModelsList(
          rankings: [_r('alpha', 0.9), _r('beta', 0.5)],
          dimension: ScoreDimension.overall,
          selectedKey: 'p:alpha',
          pinnedKey: null,
          onSelect: (_) {},
          onTogglePin: (_) {},
        ),
      ),
    ));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
  });

  testWidgets('shows score by current dimension', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RankedModelsList(
          rankings: [_r('alpha', 0.9)],
          dimension: ScoreDimension.intelligence,
          selectedKey: null,
          pinnedKey: null,
          onSelect: (_) {},
          onTogglePin: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('0.90'), findsOneWidget);
  });

  testWidgets('renders empty-state text when rankings is empty',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RankedModelsList(
          rankings: const [],
          dimension: ScoreDimension.overall,
          selectedKey: null,
          pinnedKey: null,
          onSelect: (_) {},
          onTogglePin: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('No models match'), findsOneWidget);
  });

  testWidgets('tapping a row calls onSelect with model key', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RankedModelsList(
          rankings: [_r('alpha', 0.9)],
          dimension: ScoreDimension.overall,
          selectedKey: null,
          pinnedKey: null,
          onSelect: (k) => selected = k,
          onTogglePin: (_) {},
        ),
      ),
    ));
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();
    expect(selected, 'p:alpha');
  });
}
```

- [ ] **Step 2: Run test (expect fail)**

Run: `flutter test test/ui/widgets/ranked_models_list_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Implement the widget**

Create `lib/ui/widgets/ranked_models_list.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:flutter/material.dart';

class RankedModelsList extends StatelessWidget {
  const RankedModelsList({
    super.key,
    required this.rankings,
    required this.dimension,
    required this.selectedKey,
    required this.pinnedKey,
    required this.onSelect,
    required this.onTogglePin,
  });

  final List<ModelRanking> rankings;
  final ScoreDimension dimension;
  final String? selectedKey;
  final String? pinnedKey;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onTogglePin;

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No models match this filter — try widening the date range.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: rankings.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rankings[i];
        final score = r.dimensions.byDimension(dimension);
        final isSelected = r.key == selectedKey;
        final isPinned = r.key == pinnedKey;
        return ListTile(
          selected: isSelected,
          leading: SizedBox(
            width: 24,
            child: Text('${i + 1}', textAlign: TextAlign.right),
          ),
          title: Text(r.modelId),
          subtitle: Text(r.providerId),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                ),
                onPressed: () => onTogglePin(r.key),
              ),
            ],
          ),
          onTap: () => onSelect(r.key),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test (expect pass)**

Run: `flutter test test/ui/widgets/ranked_models_list_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/ranked_models_list.dart test/ui/widgets/ranked_models_list_test.dart
git commit -m "feat(ui): RankedModelsList widget"
```

---

## Task 15: `LeaderboardPage` + `/leaderboard` route + URL state

**Files:**
- Create: `lib/ui/pages/leaderboard_page.dart`
- Create: `test/ui/pages/leaderboard_page_test.dart`
- Modify: `lib/app.dart`

The page wires `LeaderboardFilters` + `RankedModelsList` (left ~55%) + `DimensionRadar` + `PerTaskBarChart` (right ~45%). Filters and selection mirror to query params via `go_router`. The page accepts the filter state from query params at construction; updating filters does `context.go('/leaderboard?...')`.

- [ ] **Step 1: Write the page test**

Create `test/ui/pages/leaderboard_page_test.dart`:

```dart
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/pages/leaderboard_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({AppDatabase db, LeaderboardRepository repo})> _seed() async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
  await dao.persistTaskRun(TaskRunResult(
    runId: 'r1',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'bug.off_by_one_pagination',
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration(milliseconds: 5000),
    ),
    evaluations: const [
      EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
    ],
    aggregateScore: 1.0,
    completedAt: DateTime(2026, 5, 1, 0, 5),
  ));
  await dao.finishRun('r1', DateTime(2026, 5, 1, 0, 10));
  return (db: db, repo: LeaderboardRepository(db));
}

void main() {
  testWidgets('shows the seeded model in the ranked list', (tester) async {
    final s = await _seed();
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }
    await tester.pumpWidget(MaterialApp(
      home: LeaderboardPage(
        repository: s.repo,
        registry: registry,
        initialQuery: const {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('gpt-5'), findsOneWidget);
  });

  testWidgets('initialQuery applies dimension filter', (tester) async {
    final s = await _seed();
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }
    await tester.pumpWidget(MaterialApp(
      home: LeaderboardPage(
        repository: s.repo,
        registry: registry,
        initialQuery: const {'dim': 'speed'},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Speed'), findsWidgets);
  });

  testWidgets('shows empty-state on the right pane when nothing matches',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LeaderboardRepository(db);
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }
    await tester.pumpWidget(MaterialApp(
      home: LeaderboardPage(
        repository: repo,
        registry: registry,
        initialQuery: const {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No models match'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test (expect fail)**

Run: `flutter test test/ui/pages/leaderboard_page_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Implement the page**

Create `lib/ui/pages/leaderboard_page.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/dimension_radar.dart';
import 'package:dart_arena/ui/widgets/leaderboard_filters.dart';
import 'package:dart_arena/ui/widgets/per_task_bar_chart.dart';
import 'package:dart_arena/ui/widgets/ranked_models_list.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({
    super.key,
    required this.registry,
    required this.initialQuery,
    this.repository,
  });

  final TaskRegistry registry;
  final Map<String, String> initialQuery;
  final LeaderboardRepository? repository;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  LeaderboardRepository? _repo;
  AppDatabase? _ownedDb;
  late LeaderboardFilter _filter;
  String? _selectedKey;
  String? _pinnedKey;
  Future<List<ModelRanking>>? _rankFuture;
  Future<ModelDetail?>? _detailFuture;

  @override
  void initState() {
    super.initState();
    if (widget.repository == null) {
      _ownedDb = AppDatabase();
      _repo = LeaderboardRepository(_ownedDb!);
    } else {
      _repo = widget.repository;
    }
    _filter = _filterFromQuery(widget.initialQuery);
    _selectedKey = widget.initialQuery['sel'];
    _pinnedKey = widget.initialQuery['pin'];
    _refresh();
  }

  @override
  void dispose() {
    _ownedDb?.close();
    super.dispose();
  }

  LeaderboardFilter _filterFromQuery(Map<String, String> q) {
    return LeaderboardFilter(
      category: q['category'] == null
          ? null
          : Category.values.firstWhere(
              (c) => c.name == q['category'],
              orElse: () => Category.bugFix,
            ),
      providerId: q['provider'],
      dateRange: DateRange.fromQueryParam(q['since']),
      dimension: ScoreDimension.values.firstWhere(
        (d) => d.name == q['dim'],
        orElse: () => ScoreDimension.overall,
      ),
    );
  }

  Set<String>? _taskIdsForCurrentCategory() {
    if (_filter.category == null) return null;
    return widget.registry
        .byCategory(_filter.category!)
        .map((t) => t.id)
        .toSet();
  }

  Map<String, Category> _categoryByTaskId() => {
        for (final t in widget.registry.all()) t.id: t.category,
      };

  void _refresh() {
    final taskIds = _taskIdsForCurrentCategory();
    setState(() {
      _rankFuture =
          _repo!.rank(filter: _filter, taskIdsForCategory: taskIds);
    });
    _rankFuture!.then((rs) {
      if (!mounted) return;
      // Default selection to top row when current selection is missing.
      final newSelection = rs.any((r) => r.key == _selectedKey)
          ? _selectedKey
          : rs.isEmpty
              ? null
              : rs.first.key;
      if (newSelection != _selectedKey) {
        setState(() => _selectedKey = newSelection);
      }
      _refreshDetail();
    });
  }

  void _refreshDetail() {
    if (_selectedKey == null) {
      setState(() => _detailFuture = Future.value(null));
      return;
    }
    final parts = _selectedKey!.split(':');
    final taskIds = _taskIdsForCurrentCategory();
    final categoryByTaskId = _categoryByTaskId();
    setState(() {
      _detailFuture = _repo!.detail(
        providerId: parts[0],
        modelId: parts[1],
        filter: _filter,
        taskIdsForCategory: taskIds,
        categoryByTaskId: categoryByTaskId,
      );
    });
  }

  void _updateUrl() {
    final qp = <String, String>{};
    if (_filter.category != null) qp['category'] = _filter.category!.name;
    if (_filter.providerId != null) qp['provider'] = _filter.providerId!;
    if (_filter.dateRange != DateRange.allTime) {
      qp['since'] = _filter.dateRange.toQueryParam();
    }
    if (_filter.dimension != ScoreDimension.overall) {
      qp['dim'] = _filter.dimension.name;
    }
    if (_selectedKey != null) qp['sel'] = _selectedKey!;
    if (_pinnedKey != null) qp['pin'] = _pinnedKey!;
    GoRouter.of(context).go(Uri(path: '/leaderboard', queryParameters: qp).toString());
  }

  void _onFilterChanged(LeaderboardFilter f) {
    setState(() => _filter = f);
    _refresh();
    _updateUrl();
  }

  void _onSelect(String key) {
    setState(() => _selectedKey = key);
    _refreshDetail();
    _updateUrl();
  }

  void _onTogglePin(String key) {
    setState(() => _pinnedKey = _pinnedKey == key ? null : key);
    _updateUrl();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: FutureBuilder<List<ModelRanking>>(
        future: _rankFuture,
        builder: (context, snap) {
          final rows = snap.data ?? const [];
          final providerOptions = rows.map((r) => r.providerId).toSet().toList()
            ..sort();
          return Column(
            children: [
              LeaderboardFilters(
                filter: _filter,
                providerOptions: providerOptions,
                onChanged: _onFilterChanged,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 55,
                      child: RankedModelsList(
                        rankings: rows,
                        dimension: _filter.dimension,
                        selectedKey: _selectedKey,
                        pinnedKey: _pinnedKey,
                        onSelect: _onSelect,
                        onTogglePin: _onTogglePin,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 45,
                      child: _DetailPane(
                        detailFuture: _detailFuture,
                        rankings: rows,
                        pinnedKey: _pinnedKey,
                        onTaskTap: (s) => context.push(
                          '/runs/${s.lastRunId}/task-runs/${s.lastTaskRunId}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.detailFuture,
    required this.rankings,
    required this.pinnedKey,
    required this.onTaskTap,
  });

  final Future<ModelDetail?>? detailFuture;
  final List<ModelRanking> rankings;
  final String? pinnedKey;
  final void Function(PerTaskScore) onTaskTap;

  @override
  Widget build(BuildContext context) {
    if (detailFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<ModelDetail?>(
      future: detailFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final detail = snap.data;
        if (detail == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No models match this filter — try widening the date range.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final pinned = pinnedKey == null
            ? null
            : rankings
                .where((r) => r.key == pinnedKey)
                .map((r) => r.dimensions)
                .firstOrNull;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 240,
                child: DimensionRadar(
                  selected: detail.ranking.dimensions,
                  pinned: pinned,
                  selectedLabel: detail.ranking.modelId,
                  pinnedLabel: pinnedKey,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: PerTaskBarChart(
                scores: detail.perTask,
                onTap: onTaskTap,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${detail.ranking.taskRunCount} task-runs · '
                '${detail.ranking.dimensions.problems} problems',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: Add the route**

Open `lib/app.dart`. Add an import:

```dart
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/pages/leaderboard_page.dart';
```

Build a registry once at module scope (next to `_router`):

```dart
final TaskRegistry _registry = buildDefaultTaskRegistry();
```

Add the route inside the `routes:` list (after `/runs/:runId/task-runs/:taskRunId`):

```dart
    GoRoute(
      path: '/leaderboard',
      builder: (context, state) => LeaderboardPage(
        registry: _registry,
        initialQuery: state.uri.queryParameters,
      ),
    ),
```

- [ ] **Step 5: Run page test (expect pass)**

Run: `flutter test test/ui/pages/leaderboard_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Run analyze**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/ui/pages/leaderboard_page.dart \
        test/ui/pages/leaderboard_page_test.dart \
        lib/app.dart
git commit -m "feat(ui): LeaderboardPage + /leaderboard route + URL state"
```

---

## Task 16: `ShowcaseCard` widget

**Files:**
- Create: `lib/ui/widgets/showcase_card.dart`
- Create: `test/ui/widgets/showcase_card_test.dart`

A small card showing per-category top-model summary: category label, model name, overall score, and a tiny 4-axis radar.

- [ ] **Step 1: Write the test**

Create `test/ui/widgets/showcase_card_test.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/ui/widgets/showcase_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders category, model, and score', (tester) async {
    const ranking = ModelRanking(
      providerId: 'openai',
      modelId: 'gpt-5',
      dimensions: Dimensions(
        intelligence: 0.9,
        speed: 0.6,
        elegance: 0.7,
        reliability: 1.0,
        problems: 0,
      ),
      taskRunCount: 3,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          height: 220,
          child: ShowcaseCard(
            category: Category.bugFix,
            top: ranking,
            onTap: () {},
          ),
        ),
      ),
    ));
    expect(find.text('Bug fix'), findsOneWidget);
    expect(find.text('gpt-5'), findsOneWidget);
    expect(find.textContaining('0.80'), findsOneWidget);
  });

  testWidgets('renders empty placeholder when top is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          height: 220,
          child: ShowcaseCard(
            category: Category.bugFix,
            top: null,
            onTap: () {},
          ),
        ),
      ),
    ));
    expect(find.textContaining('No data'), findsOneWidget);
  });

  testWidgets('tapping invokes onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShowcaseCard(
          category: Category.bugFix,
          top: null,
          onTap: () => taps++,
        ),
      ),
    ));
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run test (expect fail)**

Run: `flutter test test/ui/widgets/showcase_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the widget**

Create `lib/ui/widgets/showcase_card.dart`:

```dart
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/ui/widgets/dimension_radar.dart';
import 'package:flutter/material.dart';

class ShowcaseCard extends StatelessWidget {
  const ShowcaseCard({
    super.key,
    required this.category,
    required this.top,
    required this.onTap,
  });

  final Category category;
  final ModelRanking? top;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category.label,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (top == null)
                const Expanded(
                  child: Center(
                    child: Text('No data', style: TextStyle(fontSize: 12)),
                  ),
                )
              else ...[
                Text(
                  top!.modelId,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  top!.providerId,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  top!.dimensions.overall.toStringAsFixed(2),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: DimensionRadar(
                    selected: top!.dimensions,
                    selectedLabel: top!.modelId,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test (expect pass)**

Run: `flutter test test/ui/widgets/showcase_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/showcase_card.dart test/ui/widgets/showcase_card_test.dart
git commit -m "feat(ui): ShowcaseCard widget for dashboard top-per-category"
```

---

## Task 17: `InProgressBanner` widget

**Files:**
- Create: `lib/ui/widgets/in_progress_banner.dart`
- Create: `test/ui/widgets/in_progress_banner_test.dart`

Minimal banner shown only when there's at least one run with `completedAt == null`. Tapping navigates to `/runs/<runId>` (the existing `RunDetailsPage` already handles in-progress state).

- [ ] **Step 1: Write the test**

Create `test/ui/widgets/in_progress_banner_test.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/in_progress_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Run _r(String id, {DateTime? completedAt}) => Run(
      id: id,
      startedAt: DateTime(2026, 5, 3),
      completedAt: completedAt,
      judgeModel: null,
      name: id,
    );

void main() {
  testWidgets('renders when one in-flight run is provided', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InProgressBanner(
          inFlight: [_r('a')],
          onTap: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('a'), findsOneWidget);
  });

  testWidgets('shows count badge when multiple are in flight', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InProgressBanner(
          inFlight: [_r('a'), _r('b'), _r('c')],
          onTap: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('3 runs'), findsOneWidget);
  });

  testWidgets('renders nothing when inFlight is empty', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InProgressBanner(inFlight: const [], onTap: (_) {}),
      ),
    ));
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('tapping calls onTap with the most-recent run', (tester) async {
    String? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InProgressBanner(
          inFlight: [_r('a'), _r('b')],
          onTap: (r) => tapped = r.id,
        ),
      ),
    ));
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
  });
}
```

- [ ] **Step 2: Run test (expect fail)**

Run: `flutter test test/ui/widgets/in_progress_banner_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the widget**

Create `lib/ui/widgets/in_progress_banner.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:flutter/material.dart';

class InProgressBanner extends StatelessWidget {
  const InProgressBanner({
    super.key,
    required this.inFlight,
    required this.onTap,
  });

  final List<Run> inFlight;
  final void Function(Run) onTap;

  @override
  Widget build(BuildContext context) {
    if (inFlight.isEmpty) return const SizedBox.shrink();
    final latest = inFlight.reduce(
      (a, b) => a.startedAt.isAfter(b.startedAt) ? a : b,
    );
    final extra = inFlight.length > 1 ? ' · ${inFlight.length} runs in flight' : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(latest),
          child: ListTile(
            leading: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text(latest.name ?? 'Run ${latest.id}'),
            subtitle: Text('In progress$extra'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test (expect pass)**

Run: `flutter test test/ui/widgets/in_progress_banner_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/in_progress_banner.dart test/ui/widgets/in_progress_banner_test.dart
git commit -m "feat(ui): InProgressBanner widget for dashboard"
```

---

## Task 18: `RecentRunsStrip` widget

**Files:**
- Create: `lib/ui/widgets/recent_runs_strip.dart`
- Create: `test/ui/widgets/recent_runs_strip_test.dart`

A vertical list of up to 5 `RunRow`s plus a "View all →" header link.

- [ ] **Step 1: Write the test**

Create `test/ui/widgets/recent_runs_strip_test.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/recent_runs_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Run _r(String id) => Run(
      id: id,
      startedAt: DateTime(2026, 5, 3),
      completedAt: DateTime(2026, 5, 3, 0, 5),
      judgeModel: null,
      name: id,
    );

void main() {
  testWidgets('shows up to 5 rows even when more are provided',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecentRunsStrip(
          runs: [
            for (var i = 0; i < 8; i++) (_r('run-$i'), const <TaskRun>[])
          ],
          onTapRow: (_) {},
          onViewAll: () {},
        ),
      ),
    ));
    expect(find.textContaining('run-'), findsNWidgets(5));
  });

  testWidgets('shows empty-state message when runs is empty', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecentRunsStrip(
          runs: const [],
          onTapRow: (_) {},
          onViewAll: () {},
        ),
      ),
    ));
    expect(find.textContaining('No runs yet'), findsOneWidget);
  });

  testWidgets('tapping View all triggers onViewAll', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecentRunsStrip(
          runs: [(_r('a'), const <TaskRun>[])],
          onTapRow: (_) {},
          onViewAll: () => taps++,
        ),
      ),
    ));
    await tester.tap(find.text('View all'));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run test (expect fail)**

Run: `flutter test test/ui/widgets/recent_runs_strip_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the widget**

Create `lib/ui/widgets/recent_runs_strip.dart`:

```dart
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/run_row.dart';
import 'package:flutter/material.dart';

class RecentRunsStrip extends StatelessWidget {
  const RecentRunsStrip({
    super.key,
    required this.runs,
    required this.onTapRow,
    required this.onViewAll,
    this.maxRows = 5,
  });

  final List<(Run, List<TaskRun>)> runs;
  final ValueChanged<Run> onTapRow;
  final VoidCallback onViewAll;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Text('Recent runs',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(onPressed: onViewAll, child: const Text('View all')),
            ],
          ),
        ),
        if (runs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No runs yet — start one with the New Run button.'),
          )
        else
          for (final r in runs.take(maxRows))
            RunRow(run: r.$1, taskRuns: r.$2, onTap: () => onTapRow(r.$1)),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test (expect pass)**

Run: `flutter test test/ui/widgets/recent_runs_strip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/recent_runs_strip.dart test/ui/widgets/recent_runs_strip_test.dart
git commit -m "feat(ui): RecentRunsStrip widget"
```

---

## Task 19: `DashboardPage` + replace `HomePage` route

**Files:**
- Create: `lib/ui/pages/dashboard_page.dart`
- Create: `test/ui/pages/dashboard_page_test.dart`
- Modify: `lib/app.dart`
- Delete: `lib/ui/pages/home_page.dart`

Composes the three sections (banner, showcase strip, recent runs) over `RunDao` + `LeaderboardRepository`. `HomePage` is removed.

- [ ] **Step 1: Write the page test**

Create `test/ui/pages/dashboard_page_test.dart`:

```dart
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/pages/dashboard_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({RunDao dao, LeaderboardRepository repo, AppDatabase db})> _seed({
  bool inProgress = false,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
  await dao.persistTaskRun(TaskRunResult(
    runId: 'r1',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'bug.off_by_one_pagination',
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration(milliseconds: 5000),
    ),
    evaluations: const [
      EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
    ],
    aggregateScore: 1.0,
    completedAt: DateTime(2026, 5, 1, 0, 5),
  ));
  if (!inProgress) {
    await dao.finishRun('r1', DateTime(2026, 5, 1, 0, 10));
  }
  return (dao: dao, repo: LeaderboardRepository(db), db: db);
}

void main() {
  testWidgets('shows showcase strip + recent run when data exists',
      (tester) async {
    final s = await _seed();
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }
    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(
        dao: s.dao,
        repository: s.repo,
        registry: registry,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bug fix'), findsOneWidget);
    expect(find.text('gpt-5'), findsWidgets);
    expect(find.text('Recent runs'), findsOneWidget);
  });

  testWidgets('shows in-progress banner when applicable', (tester) async {
    final s = await _seed(inProgress: true);
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }
    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(
        dao: s.dao,
        repository: s.repo,
        registry: registry,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('In progress'), findsOneWidget);
  });

  testWidgets('shows fresh-install empty state when no runs', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }
    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(
        dao: RunDao(db),
        repository: LeaderboardRepository(db),
        registry: registry,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Run your first benchmark'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test (expect fail)**

Run: `flutter test test/ui/pages/dashboard_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the page**

Create `lib/ui/pages/dashboard_page.dart`:

```dart
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/in_progress_banner.dart';
import 'package:dart_arena/ui/widgets/recent_runs_strip.dart';
import 'package:dart_arena/ui/widgets/showcase_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.registry,
    this.dao,
    this.repository,
  });

  final TaskRegistry registry;
  final RunDao? dao;
  final LeaderboardRepository? repository;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final RunDao _dao;
  late final LeaderboardRepository _repo;
  AppDatabase? _ownedDb;
  Future<_DashboardData>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.dao == null || widget.repository == null) {
      _ownedDb = AppDatabase();
      _dao = widget.dao ?? RunDao(_ownedDb!);
      _repo = widget.repository ?? LeaderboardRepository(_ownedDb!);
    } else {
      _dao = widget.dao!;
      _repo = widget.repository!;
    }
    _future = _load();
  }

  @override
  void dispose() {
    _ownedDb?.close();
    super.dispose();
  }

  Future<_DashboardData> _load() async {
    final recentRuns = await _dao.recentRuns(limit: 10);
    final withTaskRuns = <(Run, List<TaskRun>)>[];
    for (final r in recentRuns) {
      withTaskRuns.add((r, await _dao.taskRunsForRun(r.id)));
    }
    final inFlight = recentRuns.where((r) => r.completedAt == null).toList();

    final tops = <Category, ModelRanking?>{};
    for (final cat in Category.values) {
      final taskIds = widget.registry.byCategory(cat).map((t) => t.id).toSet();
      if (taskIds.isEmpty) {
        tops[cat] = null;
        continue;
      }
      final ranks = await _repo.rank(
        filter: LeaderboardFilter(category: cat),
        taskIdsForCategory: taskIds,
      );
      tops[cat] = ranks.isEmpty ? null : ranks.first;
    }

    return _DashboardData(
      recentRuns: withTaskRuns,
      inFlight: inFlight,
      topPerCategory: tops,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('dart_arena'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Run history',
            onPressed: () => context.push('/runs'),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Leaderboard',
            onPressed: () => context.push('/leaderboard'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.play_arrow),
        label: const Text('New Run'),
        onPressed: () => context.push('/new-run'),
      ),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.recentRuns.isEmpty) return const _FreshInstall();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InProgressBanner(
                  inFlight: data.inFlight,
                  onTap: (r) => context.push('/runs/${r.id}'),
                ),
                _ShowcaseStrip(
                  topPerCategory: data.topPerCategory,
                  onCategoryTap: (cat) => context.push(
                    '/leaderboard?category=${cat.name}',
                  ),
                ),
                RecentRunsStrip(
                  runs: data.recentRuns,
                  onTapRow: (r) => context.push('/runs/${r.id}'),
                  onViewAll: () => context.push('/runs'),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.recentRuns,
    required this.inFlight,
    required this.topPerCategory,
  });
  final List<(Run, List<TaskRun>)> recentRuns;
  final List<Run> inFlight;
  final Map<Category, ModelRanking?> topPerCategory;
}

class _ShowcaseStrip extends StatelessWidget {
  const _ShowcaseStrip({
    required this.topPerCategory,
    required this.onCategoryTap,
  });

  final Map<Category, ModelRanking?> topPerCategory;
  final void Function(Category) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Top model per category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                for (final cat in Category.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 200,
                      child: ShowcaseCard(
                        category: cat,
                        top: topPerCategory[cat],
                        onTap: () => onCategoryTap(cat),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreshInstall extends StatelessWidget {
  const _FreshInstall();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Run your first benchmark',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Once you have data, this dashboard will show top models per '
              'category and your most recent runs.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update `lib/app.dart` — replace `HomePage` with `DashboardPage`**

Replace the `HomePage` import:

```dart
// before
import 'package:dart_arena/ui/pages/home_page.dart';
// after
import 'package:dart_arena/ui/pages/dashboard_page.dart';
```

Update the root route:

```dart
// before
GoRoute(path: '/', builder: (_, __) => const HomePage()),
// after
GoRoute(
  path: '/',
  builder: (_, __) => DashboardPage(registry: _registry),
),
```

- [ ] **Step 5: Delete `lib/ui/pages/home_page.dart`**

```bash
git rm lib/ui/pages/home_page.dart
```

- [ ] **Step 6: Run analyze + dashboard tests**

```bash
flutter analyze
flutter test test/ui/pages/dashboard_page_test.dart
```

Expected: analyze clean, dashboard tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/pages/dashboard_page.dart \
        test/ui/pages/dashboard_page_test.dart \
        lib/app.dart
git commit -m "feat(ui): DashboardPage replaces HomePage; add /leaderboard nav"
```

---

## Task 20: Final verification gate

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full test suite**

```bash
flutter test
```

Expected: PASS — all suites green. If any test from Plan 1–5 fails, investigate before proceeding.

- [ ] **Step 2: Run analyze on the whole project**

```bash
flutter analyze
```

Expected: "No issues found!".

- [ ] **Step 3: Linux desktop smoke run**

```bash
flutter run -d linux
```

Manually verify, in this order:

1. App launches into the dashboard at `/`.
2. With an empty database (fresh start): "Run your first benchmark" empty state is visible. No showcase strip. No recent activity.
3. Tap "+ New Run" → starts a small run (one provider, one task) and returns. The dashboard now shows the in-progress banner.
4. After the run completes: dashboard shows the showcase strip with at least one populated category card; the recent runs strip shows the run.
5. Tap a showcase card → navigates to `/leaderboard?category=<cat>` with that category pre-filtered.
6. On the leaderboard: change Dimension dropdown → list re-sorts. Pin a row → radar shows the overlay polygon. Tap a bar in the per-task chart → navigates to `/runs/<id>/task-runs/<id>`.
7. Browser back/forward (or `flutter run` hot reload after editing the URL) preserves filter state via `?category=...&dim=...`.
8. Empty filter (e.g., narrow date range to "Last 7d" before any runs in that window) → right pane shows "No models match this filter…" empty state and ranked list shows "No models match…".

- [ ] **Step 4: Confirm no untracked files remain**

```bash
git status
```

Expected: working tree clean (no leftover throwaway files).

- [ ] **Step 5: Commit nothing — just close out the plan**

If the plan was implemented across feature branches, this is where you'd open a PR. Otherwise the verification gate is informational only.

---

## Out of scope reminder (from the spec)

If you find yourself reaching for any of the following, **stop** — they belong to a follow-up plan, not this one:

- Trend lines / sparklines (per-model score over time).
- CSV export of the leaderboard view.
- Saved filter presets (URL-state covers the realistic use).
- Per-task radar (one mini-radar per task).
- Provider-group aggregation.
- Multi-select category / multi-select provider filters.
- Schema migrations or derived rollup tables.
- New tasks, evaluators, providers.
- Real-time / streaming charts.
- Documentation / README updates.

---

## Self-review notes

- Spec coverage:
  - Section 3.1 (Dimensions) ✅ — Tasks 1–5 build the type and all four formulas + problems counter.
  - Section 3.2 (LeaderboardRepository) ✅ — Tasks 6, 7, 8, 9 (filter object, `rank` happy path, filter coverage, `detail`).
  - Section 3.3 (Routing & URL-state) ✅ — Task 15 wires URL-state in `LeaderboardPage`; Task 19 adds the dashboard at `/`.
  - Section 3.4.1 (Dashboard layout) ✅ — Tasks 16–19.
  - Section 3.4.2 (Leaderboard layout) ✅ — Tasks 13, 14, 15.
  - Section 3.5 (Charts) ✅ — Tasks 11 (radar), 12 (bar chart with drill-down).
  - Section 3.6 (Wiring) ✅ — Task 10 extracts `RunRow`, Task 15/19 update `app.dart`.
  - Section 5 (Testing) ✅ — every task pairs implementation with widget/unit tests; Task 20 is the verification gate.
- Type consistency: `ModelRanking.key`, `Dimensions.byDimension`, `LeaderboardFilter.copyWith`, `PerTaskScore.last{Run,TaskRun}Id` are defined in early tasks and reused identically downstream.
- No placeholders remain.
