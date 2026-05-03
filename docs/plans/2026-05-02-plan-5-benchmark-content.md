# Plan 5 — Benchmark Content (9 New Tasks) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grow the benchmark suite from 1 task to 10 by adding 9 new `BenchmarkTask` implementations across the 5 categories, plus a small shared-infra layer that makes Flutter fixtures actually executable end-to-end.

**Architecture:** Each task ships a self-contained fixture project (its own pubspec, source, tests). A `FixtureLoader` helper kills the asset-loading boilerplate. A new `BenchmarkTask.isFlutter` flag is read by `WorkdirManager.prepare`, `CompileEvaluator`, and `TestEvaluator` so they invoke `flutter` instead of `dart` for Flutter fixtures. Three grading shapes are used (oracle, regression, test-author) — see the spec at `docs/specs/2026-05-02-plan-5-benchmark-content-design.md`.

**Tech Stack:** Dart 3, Flutter, `flutter_bloc`/`bloc`, `flutter_test`, `test`, `mocktail`, `fake_async`. Existing evaluators: `compile`, `analyze`, `test`, `widget_tree`, `llm_judge`, `diff_size`.

---

## File Map

### New files (shared infra)

- `lib/core/fixture_loader.dart` — asset-loading helper.

### Modified files (shared infra)

- `lib/core/benchmark_task.dart` — add `ensureLoaded()` default method, add `isFlutter` getter.
- `lib/runner/workdir_manager.dart` — `prepare()` uses `flutter pub get` when task is Flutter.
- `lib/evaluators/compile_evaluator.dart` — dispatch on `ctx.task.isFlutter`.
- `lib/evaluators/test_evaluator.dart` — dispatch on `ctx.task.isFlutter`.
- `lib/main.dart` — replace ad-hoc `OffByOnePaginationTask.loadAssets()` with iterating `registry.all` and `await task.ensureLoaded()`.
- `lib/tasks/bug_fix/off_by_one_pagination.dart` — migrate to `FixtureLoader`.
- `lib/tasks/task_catalog.dart` — register all 10 tasks.
- `pubspec.yaml` — add asset entries for each new fixture.

### New task classes (one per task)

- `lib/tasks/state_management/counter_bloc.dart`
- `lib/tasks/state_management/shopping_cart_bloc.dart`
- `lib/tasks/ui_from_spec/profile_card.dart`
- `lib/tasks/ui_from_spec/expandable_list_tile.dart`
- `lib/tasks/refactor/god_widget.dart`
- `lib/tasks/refactor/callback_hell.dart`
- `lib/tasks/widget_testing/todo_input.dart`
- `lib/tasks/widget_testing/form_validation.dart`
- `lib/tasks/bug_fix/async_race_condition.dart`

### New fixture trees (one per task)

Each under `lib/tasks/<category>/fixtures/<task_id>/` containing `pubspec.yaml`, `lib/`, and `test/` (and `test/_reference/` for test-author tasks). Full file contents are defined in each task below.

### Modified runner test (existing)

- `test/runner/workdir_manager_test.dart` — exists or doesn't, will be updated/created in Task 1.

---

## Task 1: Shared infrastructure

**Files:**
- Create: `lib/core/fixture_loader.dart`
- Modify: `lib/core/benchmark_task.dart`
- Modify: `lib/runner/workdir_manager.dart`
- Modify: `lib/evaluators/compile_evaluator.dart`
- Modify: `lib/evaluators/test_evaluator.dart`
- Modify: `lib/main.dart`
- Modify: `lib/tasks/bug_fix/off_by_one_pagination.dart`
- Test: `test/core/fixture_loader_test.dart` (new)
- Test: `test/runner/workdir_manager_dispatch_test.dart` (new)

### Step 1.1: Add `isFlutter` and `ensureLoaded` to `BenchmarkTask`

- [ ] Edit `lib/core/benchmark_task.dart` — full new content:

```dart
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

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
}
```

- [ ] Run `flutter analyze` — expect zero errors (the existing `OffByOnePaginationTask` doesn't need to override the new members; they have defaults).

- [ ] Commit:

```bash
git add lib/core/benchmark_task.dart
git commit -m "feat(core): add isFlutter flag and ensureLoaded hook to BenchmarkTask"
```

### Step 1.2: Write the failing test for `FixtureLoader`

- [ ] Create `test/core/fixture_loader_test.dart`:

```dart
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FixtureLoader loads listed asset files keyed by relative path',
      () async {
    const root = 'lib/tasks/bug_fix/fixtures/off_by_one_pagination';
    final loader = FixtureLoader(
      assetRoot: root,
      files: const [
        'pubspec.yaml',
        'lib/pagination.dart',
        'test/pagination_test.dart',
      ],
    );

    final map = await loader.load();

    expect(map.keys, {
      'pubspec.yaml',
      'lib/pagination.dart',
      'test/pagination_test.dart',
    });
    expect(map['pubspec.yaml'], isNotEmpty);
    expect(map['pubspec.yaml'], contains('off_by_one_pagination'));
  });

  test('FixtureLoader throws when an asset is missing', () async {
    final loader = FixtureLoader(
      assetRoot: 'no/such/root',
      files: const ['pubspec.yaml'],
    );
    expect(() => loader.load(), throwsA(isA<FlutterError>()));
  });
}
```

- [ ] Run `flutter test test/core/fixture_loader_test.dart` — expect FAIL (`FixtureLoader` not defined).

### Step 1.3: Implement `FixtureLoader`

- [ ] Create `lib/core/fixture_loader.dart`:

```dart
import 'package:flutter/services.dart';

class FixtureLoader {
  FixtureLoader({required this.assetRoot, required this.files});

  final String assetRoot;
  final List<String> files;

  Future<Map<String, String>> load() async {
    final out = <String, String>{};
    for (final rel in files) {
      out[rel] = await rootBundle.loadString('$assetRoot/$rel');
    }
    return out;
  }
}
```

- [ ] Run `flutter test test/core/fixture_loader_test.dart` — expect PASS.

- [ ] Commit:

```bash
git add lib/core/fixture_loader.dart test/core/fixture_loader_test.dart
git commit -m "feat(core): add FixtureLoader for asset-backed fixtures"
```

### Step 1.4: Migrate `OffByOnePaginationTask` to `FixtureLoader` + `ensureLoaded`

- [ ] Replace the contents of `lib/tasks/bug_fix/off_by_one_pagination.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class OffByOnePaginationTask extends BenchmarkTask {
  static const _root = 'lib/tasks/bug_fix/fixtures/off_by_one_pagination';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/pagination.dart',
      'test/pagination_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'bug.off_by_one_pagination';

  @override
  Category get category => Category.bugFix;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given a Dart class `Paginator<T>` in `lib/pagination.dart` that has off-by-one bugs.
There are tests in `test/pagination_test.dart` that currently fail.

Return ONLY the corrected contents of `lib/pagination.dart` inside a single ```dart fenced block.
Do not include explanatory text outside the block. Do not change the public API.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/pagination.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted Paginator implementation on a 0.0-1.0 scale on these axes:
- Correctness of pageCount and page() boundaries (most important).
- Idiomatic Dart (use of generics, avoiding off-by-one re-introductions).
- Minimal, surgical change vs. the broken original.
- Readability and absence of dead code.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
        DiffSizeEvaluator(originalFixturePath: 'lib/pagination.dart'),
      ];
}
```

- [ ] Update `lib/main.dart`:

```dart
import 'package:dart_arena/app.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final registry = buildDefaultTaskRegistry();
  for (final task in registry.all) {
    await task.ensureLoaded();
  }
  runApp(const App());
}
```

> Note: this leaves the registry built twice (once in `main`, once wherever the run page builds it). That is acceptable for this plan. A future refactor can hoist the registry into a singleton/inherited widget.

- [ ] Run `flutter analyze` — expect no errors.
- [ ] Run `flutter test` — expect all existing tests to pass.

- [ ] Commit:

```bash
git add lib/tasks/bug_fix/off_by_one_pagination.dart lib/main.dart
git commit -m "refactor(core): migrate OffByOnePaginationTask to FixtureLoader+ensureLoaded"
```

### Step 1.5: Write the failing test for runner dispatch on `isFlutter`

- [ ] Create `test/runner/workdir_manager_dispatch_test.dart`:

```dart
import 'dart:io';

import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wm_dispatch_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('prepare uses dart pub get for non-Flutter projects', () async {
    final wd = Directory(p.join(tmp.path, 'plain'));
    await wd.create(recursive: true);
    await File(p.join(wd.path, 'pubspec.yaml')).writeAsString('''
name: plain
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
    final mgr = WorkdirManager(root: tmp);
    final res = await mgr.prepare(wd, isFlutter: false);
    expect(res, isA<PrepareOk>());
  });
}
```

- [ ] Run `flutter test test/runner/workdir_manager_dispatch_test.dart` — expect FAIL (`prepare` does not accept `isFlutter:` named parameter).

### Step 1.6: Update `WorkdirManager.prepare` to accept `isFlutter`

- [ ] Replace `prepare()` in `lib/runner/workdir_manager.dart`:

```dart
Future<PrepareResult> prepare(Directory workDir, {required bool isFlutter}) async {
  final exe = isFlutter ? 'flutter' : 'dart';
  final offline = await Process.run(
    exe,
    ['pub', 'get', '--offline'],
    workingDirectory: workDir.path,
  );
  if (offline.exitCode == 0) return const PrepareOk();

  final online = await Process.run(
    exe,
    ['pub', 'get'],
    workingDirectory: workDir.path,
  );
  if (online.exitCode == 0) return const PrepareOk();

  return PrepareFailed(
    online.stderr.toString().isEmpty
        ? offline.stderr.toString()
        : online.stderr.toString(),
  );
}
```

- [ ] Update the call site in `lib/runner/run_bloc.dart`. Find the line:

```dart
final prepResult = await workdirManager.prepare(dir);
```

Replace with:

```dart
final prepResult = await workdirManager.prepare(dir, isFlutter: task.isFlutter);
```

- [ ] Run `flutter test test/runner/workdir_manager_dispatch_test.dart` — expect PASS.
- [ ] Run `flutter analyze` — expect no errors.

- [ ] Commit:

```bash
git add lib/runner/workdir_manager.dart lib/runner/run_bloc.dart test/runner/workdir_manager_dispatch_test.dart
git commit -m "feat(runner): WorkdirManager.prepare dispatches dart vs flutter on isFlutter"
```

### Step 1.7: Update `CompileEvaluator` and `TestEvaluator` to dispatch on `isFlutter`

- [ ] Replace `lib/evaluators/compile_evaluator.dart`:

```dart
import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class CompileEvaluator implements Evaluator {
  @override
  String get id => 'compile';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final exe = ctx.task.isFlutter ? 'flutter' : 'dart';
    final analyze = await Process.run(
      exe,
      ['analyze', '--fatal-infos'],
      workingDirectory: ctx.workDir.path,
    );

    final passed = analyze.exitCode == 0;
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
      rationale: passed ? 'compiles cleanly' : 'analysis errors present',
      details: {
        'exitCode': analyze.exitCode,
        'stdout': analyze.stdout.toString(),
        'stderr': analyze.stderr.toString(),
        'tool': exe,
      },
    );
  }
}
```

- [ ] Replace `lib/evaluators/test_evaluator.dart`:

```dart
import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/_test_reporter_parser.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class TestEvaluator implements Evaluator {
  TestEvaluator({this.testPath});

  /// If provided, only this path is passed to `<tool> test`. When null, the
  /// runner runs the default test set (the entire `test/` directory).
  final String? testPath;

  @override
  String get id => 'test';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final exe = ctx.task.isFlutter ? 'flutter' : 'dart';
    final args = <String>[
      'test',
      if (testPath != null) testPath!,
      '--reporter=json',
    ];
    final res = await Process.run(
      exe,
      args,
      workingDirectory: ctx.workDir.path,
    );
    final summary = parseTestReporterJson(res.stdout.toString());

    return EvaluationResult(
      evaluatorId: id,
      passed: summary.allPassed,
      score: summary.score,
      rationale: summary.total == 0
          ? 'no tests found'
          : '${summary.passed}/${summary.total} tests passed',
      details: {
        'total': summary.total,
        'passed': summary.passed,
        'failed': summary.failed,
        'errored': summary.errored,
        'failures': summary.failures,
        'exit_code': res.exitCode,
        'tool': exe,
        if (testPath != null) 'test_path': testPath,
      },
    );
  }
}
```

> Existing usages of `TestEvaluator()` (no args) are unaffected. The test-author tasks (Tasks 8 and 9) pass `testPath: ctx.task.generatedCodePath` so `flutter test` runs ONLY the model's test file and never descends into `test/_reference/`.

- [ ] Run `flutter analyze` — expect no errors.
- [ ] Run `flutter test` — expect all existing tests pass.

- [ ] Commit:

```bash
git add lib/evaluators/compile_evaluator.dart lib/evaluators/test_evaluator.dart
git commit -m "feat(evaluators): CompileEvaluator and TestEvaluator dispatch on isFlutter"
```

### Step 1.8: End-to-end smoke of existing task

- [ ] Manually run the app: pick `bug.off_by_one_pagination` as the only task, run with one cheap provider, confirm the score is identical to a pre-Plan-5 run (no behavior regression).
- [ ] If a stored historical score isn't available, capture the current score now as the baseline before adding new tasks.

---

## Task 2: `state.counter_bloc`

Pure-Dart fixture (no Flutter dependency). Regression-graded.

**Files:**
- Create: `lib/tasks/state_management/counter_bloc.dart`
- Create: `lib/tasks/state_management/fixtures/counter_bloc/pubspec.yaml`
- Create: `lib/tasks/state_management/fixtures/counter_bloc/lib/counter_bloc.dart`
- Create: `lib/tasks/state_management/fixtures/counter_bloc/test/counter_bloc_test.dart`
- Modify: `lib/tasks/task_catalog.dart`
- Modify: `pubspec.yaml`

### Step 2.1: Write the fixture pubspec

- [ ] Create `lib/tasks/state_management/fixtures/counter_bloc/pubspec.yaml`:

```yaml
name: counter_bloc_fixture
description: Fixture project for state.counter_bloc task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"

dependencies:
  bloc: ^8.1.4

dev_dependencies:
  test: ^1.25.0
  bloc_test: ^9.1.7
```

### Step 2.2: Write the broken/skeleton SUT

- [ ] Create `lib/tasks/state_management/fixtures/counter_bloc/lib/counter_bloc.dart`:

```dart
import 'package:bloc/bloc.dart';

sealed class CounterEvent {
  const CounterEvent();
}

class Increment extends CounterEvent {
  const Increment();
}

class Decrement extends CounterEvent {
  const Decrement();
}

class Reset extends CounterEvent {
  const Reset();
}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    // TODO: register event handlers so that:
    // - Increment increases value by 1
    // - Decrement decreases value by 1, but never below 0
    // - Reset sets value back to 0
  }
}
```

### Step 2.3: Write the oracle test (this is what the model must satisfy)

- [ ] Create `lib/tasks/state_management/fixtures/counter_bloc/test/counter_bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:counter_bloc_fixture/counter_bloc.dart';
import 'package:test/test.dart';

void main() {
  group('CounterBloc', () {
    blocTest<CounterBloc, int>(
      'starts at 0',
      build: CounterBloc.new,
      verify: (bloc) => expect(bloc.state, 0),
    );

    blocTest<CounterBloc, int>(
      'Increment emits 1',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(const Increment()),
      expect: () => [1],
    );

    blocTest<CounterBloc, int>(
      'Increment x3 emits 1, 2, 3',
      build: CounterBloc.new,
      act: (bloc) => bloc
        ..add(const Increment())
        ..add(const Increment())
        ..add(const Increment()),
      expect: () => [1, 2, 3],
    );

    blocTest<CounterBloc, int>(
      'Decrement at 0 stays at 0 (no emission)',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(const Decrement()),
      expect: () => <int>[],
    );

    blocTest<CounterBloc, int>(
      'Increment then Decrement returns to 0',
      build: CounterBloc.new,
      act: (bloc) => bloc
        ..add(const Increment())
        ..add(const Decrement()),
      expect: () => [1, 0],
    );

    blocTest<CounterBloc, int>(
      'Reset after increments emits 0 once',
      build: CounterBloc.new,
      act: (bloc) => bloc
        ..add(const Increment())
        ..add(const Increment())
        ..add(const Reset()),
      expect: () => [1, 2, 0],
    );
  });
}
```

> Important: `Decrement at 0 stays at 0 (no emission)` requires the implementation to *not* emit when the value would not change. A correct implementation either short-circuits or relies on bloc's default deduplication only if same state is emitted — but bloc emits whatever the handler emits. The model must explicitly skip emission when value is already 0.

### Step 2.4: Verify fixture state by hand

- [ ] Materialize the fixture into a scratch directory and run its tests:

```bash
mkdir -p /tmp/cbf && cp -r lib/tasks/state_management/fixtures/counter_bloc/. /tmp/cbf/
cd /tmp/cbf && dart pub get && dart test
```

Expected: tests **fail** (the SUT has empty handlers; states don't change).

- [ ] Sanity-check the reference solution. Replace `/tmp/cbf/lib/counter_bloc.dart` with:

```dart
import 'package:bloc/bloc.dart';

sealed class CounterEvent {
  const CounterEvent();
}

class Increment extends CounterEvent {
  const Increment();
}

class Decrement extends CounterEvent {
  const Decrement();
}

class Reset extends CounterEvent {
  const Reset();
}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((_, emit) => emit(state + 1));
    on<Decrement>((_, emit) {
      if (state > 0) emit(state - 1);
    });
    on<Reset>((_, emit) => emit(0));
  }
}
```

Run `dart test` again — expect **all green**. Then `rm -rf /tmp/cbf` (do not commit it).

### Step 2.5: Add fixture assets to host pubspec

- [ ] Edit `pubspec.yaml`. Under `flutter > assets:`, append:

```yaml
    - lib/tasks/state_management/fixtures/counter_bloc/pubspec.yaml
    - lib/tasks/state_management/fixtures/counter_bloc/lib/counter_bloc.dart
    - lib/tasks/state_management/fixtures/counter_bloc/test/counter_bloc_test.dart
```

### Step 2.6: Write the BenchmarkTask class

- [ ] Create `lib/tasks/state_management/counter_bloc.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class CounterBlocTask extends BenchmarkTask {
  static const _root = 'lib/tasks/state_management/fixtures/counter_bloc';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/counter_bloc.dart',
      'test/counter_bloc_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'state.counter_bloc';

  @override
  Category get category => Category.stateManagement;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given a `CounterBloc` skeleton in `lib/counter_bloc.dart`. Tests in `test/counter_bloc_test.dart` define the required behavior:
- `Increment` increases the state by 1.
- `Decrement` decreases the state by 1 but never below 0; if state is already 0, no new state is emitted.
- `Reset` sets the state back to 0.

Return ONLY the corrected contents of `lib/counter_bloc.dart` inside a single ```dart fenced block.
Do not include explanatory text outside the block. Do not change the public API.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/counter_bloc.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted CounterBloc on a 0.0-1.0 scale on these axes:
- Correct event handler registration for Increment, Decrement, Reset (most important).
- Proper enforcement of the non-negative invariant on Decrement, with no emission when state is already 0.
- Idiomatic Dart and bloc usage (use of `on<Event>`, no superfluous logic).
- Minimal, readable code; no dead branches.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
        DiffSizeEvaluator(originalFixturePath: 'lib/counter_bloc.dart'),
      ];
}
```

### Step 2.7: Register the task

- [ ] Edit `lib/tasks/task_catalog.dart`:

```dart
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:dart_arena/tasks/state_management/counter_bloc.dart';

TaskRegistry buildDefaultTaskRegistry() {
  final registry = TaskRegistry();
  registry.register(OffByOnePaginationTask());
  registry.register(CounterBlocTask());
  return registry;
}
```

### Step 2.8: Verify and commit

- [ ] Run `flutter analyze` — expect no errors.
- [ ] Run `flutter test` — expect existing tests still pass; new fixture-loader test still passes.
- [ ] Manually run the app, pick `state.counter_bloc`, run against one provider — expect a non-null score and no exceptions.

- [ ] Commit:

```bash
git add lib/tasks/state_management/ pubspec.yaml lib/tasks/task_catalog.dart
git commit -m "feat(tasks): add state.counter_bloc benchmark task"
```

---

## Task 3: `state.shopping_cart_bloc`

Pure-Dart fixture. Oracle-graded.

**Files:**
- Create: `lib/tasks/state_management/shopping_cart_bloc.dart`
- Create: `lib/tasks/state_management/fixtures/shopping_cart_bloc/pubspec.yaml`
- Create: `lib/tasks/state_management/fixtures/shopping_cart_bloc/lib/cart_bloc.dart`
- Create: `lib/tasks/state_management/fixtures/shopping_cart_bloc/test/cart_bloc_test.dart`
- Modify: `lib/tasks/task_catalog.dart`
- Modify: `pubspec.yaml`

### Step 3.1: Fixture pubspec

- [ ] Create `lib/tasks/state_management/fixtures/shopping_cart_bloc/pubspec.yaml`:

```yaml
name: shopping_cart_bloc_fixture
description: Fixture project for state.shopping_cart_bloc task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"

dependencies:
  bloc: ^8.1.4
  equatable: ^2.0.5

dev_dependencies:
  test: ^1.25.0
  bloc_test: ^9.1.7
```

### Step 3.2: Skeleton SUT

- [ ] Create `lib/tasks/state_management/fixtures/shopping_cart_bloc/lib/cart_bloc.dart`:

```dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class CartLine extends Equatable {
  const CartLine({required this.id, required this.unitPriceCents, required this.quantity});

  final String id;
  final int unitPriceCents;
  final int quantity;

  int get subtotalCents => unitPriceCents * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(id: id, unitPriceCents: unitPriceCents, quantity: quantity ?? this.quantity);

  @override
  List<Object?> get props => [id, unitPriceCents, quantity];
}

class CartState extends Equatable {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
  int get subtotalCents => lines.fold(0, (sum, l) => sum + l.subtotalCents);

  CartState copyWith({List<CartLine>? lines}) => CartState(lines: lines ?? this.lines);

  @override
  List<Object?> get props => [lines];
}

sealed class CartEvent {
  const CartEvent();
}

class AddItem extends CartEvent {
  const AddItem({required this.id, required this.unitPriceCents, this.quantity = 1});
  final String id;
  final int unitPriceCents;
  final int quantity;
}

class RemoveItem extends CartEvent {
  const RemoveItem(this.id);
  final String id;
}

class UpdateQuantity extends CartEvent {
  const UpdateQuantity({required this.id, required this.quantity});
  final String id;
  final int quantity;
}

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    // TODO: register handlers for AddItem, RemoveItem, UpdateQuantity such that:
    // - Adding an existing id increments its quantity (does not duplicate the line).
    // - Adding a new id appends a CartLine.
    // - RemoveItem drops the matching line; no-op if not present.
    // - UpdateQuantity sets a line's quantity; quantity 0 removes the line.
  }
}
```

### Step 3.3: Oracle tests

- [ ] Create `lib/tasks/state_management/fixtures/shopping_cart_bloc/test/cart_bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:shopping_cart_bloc_fixture/cart_bloc.dart';
import 'package:test/test.dart';

void main() {
  group('CartBloc', () {
    blocTest<CartBloc, CartState>(
      'starts empty',
      build: CartBloc.new,
      verify: (bloc) {
        expect(bloc.state.lines, isEmpty);
        expect(bloc.state.itemCount, 0);
        expect(bloc.state.subtotalCents, 0);
      },
    );

    blocTest<CartBloc, CartState>(
      'AddItem appends new line',
      build: CartBloc.new,
      act: (bloc) => bloc.add(const AddItem(id: 'a', unitPriceCents: 100)),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.lines.single.id, 'a');
        expect(bloc.state.lines.single.quantity, 1);
        expect(bloc.state.subtotalCents, 100);
      },
    );

    blocTest<CartBloc, CartState>(
      'AddItem with same id merges (increments quantity, no duplicate line)',
      build: CartBloc.new,
      act: (bloc) => bloc
        ..add(const AddItem(id: 'a', unitPriceCents: 100))
        ..add(const AddItem(id: 'a', unitPriceCents: 100, quantity: 2)),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.lines.single.quantity, 3);
        expect(bloc.state.subtotalCents, 300);
      },
    );

    blocTest<CartBloc, CartState>(
      'AddItem with different id appends second line',
      build: CartBloc.new,
      act: (bloc) => bloc
        ..add(const AddItem(id: 'a', unitPriceCents: 100))
        ..add(const AddItem(id: 'b', unitPriceCents: 250)),
      verify: (bloc) {
        expect(bloc.state.lines.map((l) => l.id), ['a', 'b']);
        expect(bloc.state.itemCount, 2);
        expect(bloc.state.subtotalCents, 350);
      },
    );

    blocTest<CartBloc, CartState>(
      'RemoveItem drops the line',
      build: CartBloc.new,
      seed: () => const CartState(lines: [
        CartLine(id: 'a', unitPriceCents: 100, quantity: 2),
        CartLine(id: 'b', unitPriceCents: 250, quantity: 1),
      ]),
      act: (bloc) => bloc.add(const RemoveItem('a')),
      verify: (bloc) {
        expect(bloc.state.lines.map((l) => l.id), ['b']);
      },
    );

    blocTest<CartBloc, CartState>(
      'RemoveItem is a no-op when id missing',
      build: CartBloc.new,
      seed: () => const CartState(lines: [
        CartLine(id: 'a', unitPriceCents: 100, quantity: 1),
      ]),
      act: (bloc) => bloc.add(const RemoveItem('nope')),
      expect: () => <CartState>[],
    );

    blocTest<CartBloc, CartState>(
      'UpdateQuantity sets new quantity',
      build: CartBloc.new,
      seed: () => const CartState(lines: [
        CartLine(id: 'a', unitPriceCents: 100, quantity: 1),
      ]),
      act: (bloc) => bloc.add(const UpdateQuantity(id: 'a', quantity: 5)),
      verify: (bloc) {
        expect(bloc.state.lines.single.quantity, 5);
        expect(bloc.state.subtotalCents, 500);
      },
    );

    blocTest<CartBloc, CartState>(
      'UpdateQuantity to 0 removes the line',
      build: CartBloc.new,
      seed: () => const CartState(lines: [
        CartLine(id: 'a', unitPriceCents: 100, quantity: 3),
        CartLine(id: 'b', unitPriceCents: 250, quantity: 1),
      ]),
      act: (bloc) => bloc.add(const UpdateQuantity(id: 'a', quantity: 0)),
      verify: (bloc) {
        expect(bloc.state.lines.map((l) => l.id), ['b']);
      },
    );
  });
}
```

### Step 3.4: Verify fixture state

- [ ] Materialize and run:

```bash
mkdir -p /tmp/scbf && cp -r lib/tasks/state_management/fixtures/shopping_cart_bloc/. /tmp/scbf/
cd /tmp/scbf && dart pub get && dart test
```

Expected: tests **fail** (handlers are TODO).

- [ ] Drop in a reference solution and confirm green:

```dart
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<AddItem>((event, emit) {
      final lines = [...state.lines];
      final idx = lines.indexWhere((l) => l.id == event.id);
      if (idx == -1) {
        lines.add(CartLine(
          id: event.id,
          unitPriceCents: event.unitPriceCents,
          quantity: event.quantity,
        ));
      } else {
        lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity + event.quantity);
      }
      emit(state.copyWith(lines: lines));
    });
    on<RemoveItem>((event, emit) {
      final next = state.lines.where((l) => l.id != event.id).toList();
      if (next.length == state.lines.length) return;
      emit(state.copyWith(lines: next));
    });
    on<UpdateQuantity>((event, emit) {
      final lines = [...state.lines];
      final idx = lines.indexWhere((l) => l.id == event.id);
      if (idx == -1) return;
      if (event.quantity <= 0) {
        lines.removeAt(idx);
      } else {
        lines[idx] = lines[idx].copyWith(quantity: event.quantity);
      }
      emit(state.copyWith(lines: lines));
    });
  }
}
```

(Replace just the `CartBloc` class body in `/tmp/scbf/lib/cart_bloc.dart`, keep imports and the rest.) Run `dart test`. Expect all green. Then `rm -rf /tmp/scbf`.

### Step 3.5: Asset entries

- [ ] Append to `pubspec.yaml` `flutter > assets:`:

```yaml
    - lib/tasks/state_management/fixtures/shopping_cart_bloc/pubspec.yaml
    - lib/tasks/state_management/fixtures/shopping_cart_bloc/lib/cart_bloc.dart
    - lib/tasks/state_management/fixtures/shopping_cart_bloc/test/cart_bloc_test.dart
```

### Step 3.6: BenchmarkTask class

- [ ] Create `lib/tasks/state_management/shopping_cart_bloc.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class ShoppingCartBlocTask extends BenchmarkTask {
  static const _root = 'lib/tasks/state_management/fixtures/shopping_cart_bloc';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/cart_bloc.dart',
      'test/cart_bloc_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'state.shopping_cart_bloc';

  @override
  Category get category => Category.stateManagement;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given a `CartBloc` skeleton in `lib/cart_bloc.dart` along with `CartLine`, `CartState`, and the `CartEvent` family. Tests in `test/cart_bloc_test.dart` define the required behavior:
- `AddItem` with a new id appends a new line; with an existing id, increments that line's quantity (no duplicate lines).
- `RemoveItem` removes the matching line; no-op if absent (no state emission).
- `UpdateQuantity` sets the line's quantity; quantity <= 0 removes the line.
- State exposes `lines`, `itemCount`, `subtotalCents` consistently.

Return ONLY the corrected contents of `lib/cart_bloc.dart` inside a single ```dart fenced block.
Do not include explanatory text outside the block. Do not change the public API.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/cart_bloc.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted CartBloc on a 0.0-1.0 scale on these axes:
- Correctness across all event handlers (most important).
- Edge case handling: duplicate adds merge; quantity 0 removes; absent ids on RemoveItem/UpdateQuantity do not emit.
- Immutability of state (no in-place mutation of `state.lines`).
- Idiomatic Dart, no superfluous logic.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
        DiffSizeEvaluator(originalFixturePath: 'lib/cart_bloc.dart'),
      ];
}
```

### Step 3.7: Register and verify

- [ ] Edit `lib/tasks/task_catalog.dart` to add `registry.register(ShoppingCartBlocTask());` (with import).
- [ ] Run `flutter analyze` — clean.
- [ ] Run `flutter test` — green.
- [ ] App smoke: pick `state.shopping_cart_bloc`, run, verify non-null score.

- [ ] Commit:

```bash
git add lib/tasks/state_management/shopping_cart_bloc.dart lib/tasks/state_management/fixtures/shopping_cart_bloc/ pubspec.yaml lib/tasks/task_catalog.dart
git commit -m "feat(tasks): add state.shopping_cart_bloc benchmark task"
```

---

## Task 4: `ui.profile_card`

Flutter fixture (`isFlutter == true`). Oracle-graded.

**Files:**
- Create: `lib/tasks/ui_from_spec/profile_card.dart`
- Create: `lib/tasks/ui_from_spec/fixtures/profile_card/pubspec.yaml`
- Create: `lib/tasks/ui_from_spec/fixtures/profile_card/lib/profile_card.dart`
- Create: `lib/tasks/ui_from_spec/fixtures/profile_card/test/profile_card_test.dart`
- Modify: `lib/tasks/task_catalog.dart`
- Modify: `pubspec.yaml`

### Step 4.1: Fixture pubspec

- [ ] Create `lib/tasks/ui_from_spec/fixtures/profile_card/pubspec.yaml`:

```yaml
name: profile_card_fixture
description: Fixture project for ui.profile_card task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Step 4.2: Skeleton SUT

- [ ] Create `lib/tasks/ui_from_spec/fixtures/profile_card/lib/profile_card.dart`:

```dart
import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.name,
    required this.handle,
    this.bio,
    this.avatarUrl,
    required this.onFollowPressed,
    required this.isFollowing,
  });

  final String name;
  final String handle;
  final String? bio;
  final String? avatarUrl;
  final VoidCallback onFollowPressed;
  final bool isFollowing;

  @override
  Widget build(BuildContext context) {
    // TODO: build a card matching the spec.
    return const SizedBox.shrink();
  }
}
```

### Step 4.3: Oracle widget tests

- [ ] Create `lib/tasks/ui_from_spec/fixtures/profile_card/test/profile_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_card_fixture/profile_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders name and handle', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada Lovelace',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('@ada'), findsOneWidget);
  });

  testWidgets('shows CircleAvatar leading', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      avatarUrl: 'https://example.com/a.png',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('omits bio when null', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    // No spec text widgets beyond name and handle should be Text widgets with text.
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    expect(texts, containsAll(<String>['Ada', '@ada']));
    expect(texts.where((t) => t != null && t!.contains('bio')), isEmpty);
  });

  testWidgets('shows bio when provided', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      bio: 'Mathematician.',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(find.text('Mathematician.'), findsOneWidget);
  });

  testWidgets('follow button shows Follow when not following', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('follow button shows Following when following', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: true,
    )));
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('tapping follow button fires callback', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () => pressed++,
      isFollowing: false,
    )));
    await tester.tap(find.text('Follow'));
    await tester.pump();
    expect(pressed, 1);
  });

  testWidgets('exposes Semantics label for the card', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(
      find.bySemanticsLabel(RegExp(r'Ada.*@ada')),
      findsWidgets,
    );
  });
}
```

### Step 4.4: Verify fixture state

- [ ] Materialize and run:

```bash
mkdir -p /tmp/pcf && cp -r lib/tasks/ui_from_spec/fixtures/profile_card/. /tmp/pcf/
cd /tmp/pcf && flutter pub get && flutter test
```

Expected: tests **fail** (skeleton returns `SizedBox.shrink()`).

- [ ] Drop in a reference solution and confirm green. Replace `lib/profile_card.dart` body with:

```dart
@override
Widget build(BuildContext context) {
  return Semantics(
    label: '$name $handle',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null ? Text(name.isNotEmpty ? name[0] : '?') : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name),
                  Text(handle),
                  if (bio != null) Text(bio!),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onFollowPressed,
              child: Text(isFollowing ? 'Following' : 'Follow'),
            ),
          ],
        ),
      ),
    ),
  );
}
```

Run `flutter test`. Expect all green. Then `rm -rf /tmp/pcf`.

### Step 4.5: Asset entries

- [ ] Append to `pubspec.yaml` `flutter > assets:`:

```yaml
    - lib/tasks/ui_from_spec/fixtures/profile_card/pubspec.yaml
    - lib/tasks/ui_from_spec/fixtures/profile_card/lib/profile_card.dart
    - lib/tasks/ui_from_spec/fixtures/profile_card/test/profile_card_test.dart
```

### Step 4.6: BenchmarkTask class

- [ ] Create `lib/tasks/ui_from_spec/profile_card.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class ProfileCardTask extends BenchmarkTask {
  static const _root = 'lib/tasks/ui_from_spec/fixtures/profile_card';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/profile_card.dart',
      'test/profile_card_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'ui.profile_card';

  @override
  Category get category => Category.uiFromSpec;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given a `ProfileCard` widget skeleton in `lib/profile_card.dart`. Build a stateless Material widget matching this spec:

- Layout: a `Card` with horizontal `Row`. Leading `CircleAvatar` (uses `avatarUrl` when provided, else shows the first letter of `name`). Center column with `name`, `handle`, and optional `bio`. Trailing `ElevatedButton` showing 'Follow' when `isFollowing == false`, 'Following' otherwise; pressing fires `onFollowPressed`.
- Accessibility: wrap the card in `Semantics(label: "<name> <handle>", ...)`.
- Do NOT change the public API (constructor parameters and types).

Tests in `test/profile_card_test.dart` enforce this contract.

Return ONLY the corrected contents of `lib/profile_card.dart` inside a single ```dart fenced block.
Do not include explanatory text outside the block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/profile_card.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted ProfileCard on a 0.0-1.0 scale on these axes:
- Spec coverage point-by-point (avatar, name, handle, optional bio, follow button text/state, callback).
- Idiomatic Flutter composition and use of Material widgets.
- Accessibility (Semantics label, sensible widget tree for screen readers).
- Minimal, readable code with no extraneous decoration.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
        DiffSizeEvaluator(originalFixturePath: 'lib/profile_card.dart'),
      ];
}
```

### Step 4.7: Register and verify

- [ ] Edit `lib/tasks/task_catalog.dart` to add `registry.register(ProfileCardTask());` (with import).
- [ ] Run `flutter analyze` — clean.
- [ ] Run `flutter test` — green.
- [ ] App smoke: pick `ui.profile_card`, run, verify non-null score and that the runner used `flutter` not `dart` (check `tool` in evaluator details).

- [ ] Commit:

```bash
git add lib/tasks/ui_from_spec/profile_card.dart lib/tasks/ui_from_spec/fixtures/profile_card/ pubspec.yaml lib/tasks/task_catalog.dart
git commit -m "feat(tasks): add ui.profile_card benchmark task"
```

---

## Task 5: `ui.expandable_list_tile`

Flutter fixture. Oracle-graded. Stateful widget with animation.

**Files:**
- Create: `lib/tasks/ui_from_spec/expandable_list_tile.dart`
- Create: `lib/tasks/ui_from_spec/fixtures/expandable_list_tile/pubspec.yaml`
- Create: `lib/tasks/ui_from_spec/fixtures/expandable_list_tile/lib/expandable_list_tile.dart`
- Create: `lib/tasks/ui_from_spec/fixtures/expandable_list_tile/test/expandable_list_tile_test.dart`
- Modify: `lib/tasks/task_catalog.dart`
- Modify: `pubspec.yaml`

### Step 5.1: Fixture pubspec

- [ ] Create `lib/tasks/ui_from_spec/fixtures/expandable_list_tile/pubspec.yaml`:

```yaml
name: expandable_list_tile_fixture
description: Fixture project for ui.expandable_list_tile task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Step 5.2: Skeleton SUT

- [ ] Create `lib/tasks/ui_from_spec/fixtures/expandable_list_tile/lib/expandable_list_tile.dart`:

```dart
import 'package:flutter/material.dart';

class ExpandableListTile extends StatefulWidget {
  const ExpandableListTile({
    super.key,
    required this.title,
    required this.details,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  final Widget title;
  final Widget details;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<ExpandableListTile> createState() => _ExpandableListTileState();
}

class _ExpandableListTileState extends State<ExpandableListTile> {
  @override
  Widget build(BuildContext context) {
    // TODO: build a tile that:
    // - Always shows `title` and a trailing chevron icon.
    // - Tapping the row toggles expansion.
    // - Rotates the chevron 180 degrees on expand using a RotationTransition (or similar).
    // - When expanded, shows `details` below the title row.
    // - Calls `onExpansionChanged` whenever the expanded state flips.
    return const SizedBox.shrink();
  }
}
```

### Step 5.3: Oracle widget tests

- [ ] Create `lib/tasks/ui_from_spec/fixtures/expandable_list_tile/test/expandable_list_tile_test.dart`:

```dart
import 'package:expandable_list_tile_fixture/expandable_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('starts collapsed by default', (tester) async {
    await tester.pumpWidget(_wrap(const ExpandableListTile(
      title: Text('Section'),
      details: Text('Details body'),
    )));
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Details body'), findsNothing);
  });

  testWidgets('starts expanded when initiallyExpanded is true', (tester) async {
    await tester.pumpWidget(_wrap(const ExpandableListTile(
      title: Text('Section'),
      details: Text('Details body'),
      initiallyExpanded: true,
    )));
    expect(find.text('Details body'), findsOneWidget);
  });

  testWidgets('tapping the title toggles expansion', (tester) async {
    await tester.pumpWidget(_wrap(const ExpandableListTile(
      title: Text('Section'),
      details: Text('Details body'),
    )));
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Details body'), findsOneWidget);
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Details body'), findsNothing);
  });

  testWidgets('fires onExpansionChanged with new value', (tester) async {
    final emitted = <bool>[];
    await tester.pumpWidget(_wrap(ExpandableListTile(
      title: const Text('Section'),
      details: const Text('Details body'),
      onExpansionChanged: emitted.add,
    )));
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(emitted, [true, false]);
  });

  testWidgets('uses RotationTransition for chevron', (tester) async {
    await tester.pumpWidget(_wrap(const ExpandableListTile(
      title: Text('Section'),
      details: Text('Details body'),
    )));
    expect(find.byType(RotationTransition), findsAtLeastNWidgets(1));
  });
}
```

### Step 5.4: Verify fixture state

- [ ] Materialize and run:

```bash
mkdir -p /tmp/eltf && cp -r lib/tasks/ui_from_spec/fixtures/expandable_list_tile/. /tmp/eltf/
cd /tmp/eltf && flutter pub get && flutter test
```

Expected: tests **fail** (empty SUT).

- [ ] Reference solution to verify acceptance: replace the `_ExpandableListTileState` body with:

```dart
class _ExpandableListTileState extends State<ExpandableListTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
    value: widget.initiallyExpanded ? 1 : 0,
  );
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
    widget.onExpansionChanged?.call(_expanded);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: widget.title),
                RotationTransition(
                  turns: Tween<double>(begin: 0, end: 0.5).animate(_ctrl),
                  child: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) Padding(padding: const EdgeInsets.all(12), child: widget.details),
      ],
    );
  }
}
```

Run `flutter test` — expect all green. Then `rm -rf /tmp/eltf`.

### Step 5.5: Asset entries

- [ ] Append to `pubspec.yaml`:

```yaml
    - lib/tasks/ui_from_spec/fixtures/expandable_list_tile/pubspec.yaml
    - lib/tasks/ui_from_spec/fixtures/expandable_list_tile/lib/expandable_list_tile.dart
    - lib/tasks/ui_from_spec/fixtures/expandable_list_tile/test/expandable_list_tile_test.dart
```

### Step 5.6: BenchmarkTask class

- [ ] Create `lib/tasks/ui_from_spec/expandable_list_tile.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class ExpandableListTileTask extends BenchmarkTask {
  static const _root = 'lib/tasks/ui_from_spec/fixtures/expandable_list_tile';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/expandable_list_tile.dart',
      'test/expandable_list_tile_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'ui.expandable_list_tile';

  @override
  Category get category => Category.uiFromSpec;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given a stateful `ExpandableListTile` widget skeleton. Build a widget matching this spec:

- Always shows `title` plus a trailing chevron icon (Icons.keyboard_arrow_down).
- Tapping the title row toggles expansion.
- Chevron rotates 180 degrees on expand, using a `RotationTransition` driven by an `AnimationController` (~200ms).
- When expanded, `details` is displayed below the title row.
- Calls `onExpansionChanged` with the new value whenever expanded state flips.
- `initiallyExpanded` controls the initial value; default false.

Tests in `test/expandable_list_tile_test.dart` enforce this. Do not change the public API.

Return ONLY the corrected contents of `lib/expandable_list_tile.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/expandable_list_tile.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted ExpandableListTile on a 0.0-1.0 scale on these axes:
- Correct stateful behavior: initial state, toggle on tap, callback firing with right value.
- Use of RotationTransition + AnimationController, with proper dispose in dispose().
- Idiomatic widget composition; no unnecessary widgets.
- Minimal, readable code.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
        DiffSizeEvaluator(originalFixturePath: 'lib/expandable_list_tile.dart'),
      ];
}
```

### Step 5.7: Register and verify

- [ ] Add `registry.register(ExpandableListTileTask());` to `task_catalog.dart`.
- [ ] `flutter analyze` clean; `flutter test` green; app smoke run.

- [ ] Commit:

```bash
git add lib/tasks/ui_from_spec/expandable_list_tile.dart lib/tasks/ui_from_spec/fixtures/expandable_list_tile/ pubspec.yaml lib/tasks/task_catalog.dart
git commit -m "feat(tasks): add ui.expandable_list_tile benchmark task"
```

---

## Task 6: `refactor.god_widget`

Flutter fixture. Regression-graded. The fixture ships a working-but-smelly widget plus behavior-pinning tests.

**Files:**
- Create: `lib/tasks/refactor/god_widget.dart`
- Create: `lib/tasks/refactor/fixtures/god_widget/pubspec.yaml`
- Create: `lib/tasks/refactor/fixtures/god_widget/lib/god_widget.dart`
- Create: `lib/tasks/refactor/fixtures/god_widget/test/god_widget_test.dart`
- Modify: `lib/tasks/task_catalog.dart`
- Modify: `pubspec.yaml`

### Step 6.1: Fixture pubspec

- [ ] Create `lib/tasks/refactor/fixtures/god_widget/pubspec.yaml`:

```yaml
name: god_widget_fixture
description: Fixture project for refactor.god_widget task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Step 6.2: The god widget (working-but-smelly)

- [ ] Create `lib/tasks/refactor/fixtures/god_widget/lib/god_widget.dart`:

```dart
import 'package:flutter/material.dart';

class TodoEntry {
  TodoEntry({required this.title, this.done = false});
  String title;
  bool done;
}

class GodWidget extends StatefulWidget {
  const GodWidget({super.key});
  @override
  State<GodWidget> createState() => _GodWidgetState();
}

class _GodWidgetState extends State<GodWidget> {
  final List<TodoEntry> _items = [];
  final TextEditingController _controller = TextEditingController();
  String _filter = 'all';
  String _sort = 'created';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<TodoEntry> get _filteredAndSorted {
    final filtered = _items.where((e) {
      if (_filter == 'open') return !e.done;
      if (_filter == 'done') return e.done;
      return true;
    }).toList();
    if (_sort == 'title') {
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return filtered;
  }

  String _statusText() {
    final total = _items.length;
    final done = _items.where((e) => e.done).length;
    return '$done of $total done';
  }

  void _addFromController() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _items.add(TodoEntry(title: t));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'New todo',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addFromController(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addFromController,
                child: const Text('Add'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Text('Filter:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v ?? 'all'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'done', child: Text('Done')),
                ],
              ),
              const SizedBox(width: 16),
              const Text('Sort:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sort,
                onChanged: (v) => setState(() => _sort = v ?? 'created'),
                items: const [
                  DropdownMenuItem(value: 'created', child: Text('Created')),
                  DropdownMenuItem(value: 'title', child: Text('Title')),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredAndSorted.length,
            itemBuilder: (context, index) {
              final entry = _filteredAndSorted[index];
              return CheckboxListTile(
                value: entry.done,
                onChanged: (v) => setState(() => entry.done = v ?? false),
                title: Text(
                  entry.title,
                  style: TextStyle(
                    decoration: entry.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => _items.remove(entry)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _statusText(),
            key: const Key('status'),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
```

### Step 6.3: Behavior-pinning tests

- [ ] Create `lib/tasks/refactor/fixtures/god_widget/test/god_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:god_widget_fixture/god_widget.dart';

Widget _wrap() => const MaterialApp(home: Scaffold(body: GodWidget()));

void main() {
  testWidgets('initial status is 0 of 0 done', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const Key('status')), findsOneWidget);
    expect(find.text('0 of 0 done'), findsOneWidget);
  });

  testWidgets('Add button appends a todo', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('0 of 1 done'), findsOneWidget);
  });

  testWidgets('checking a todo updates status text', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text('1 of 1 done'), findsOneWidget);
  });

  testWidgets('filter Open hides done todos', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'B');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').last);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('sort by Title reorders alphabetically', (tester) async {
    await tester.pumpWidget(_wrap());
    for (final t in const ['banana', 'apple', 'cherry']) {
      await tester.enterText(find.byType(TextField), t);
      await tester.tap(find.text('Add'));
      await tester.pump();
    }
    await tester.tap(find.text('Created'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title').last);
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<Text>(find.descendant(of: find.byType(CheckboxListTile), matching: find.byType(Text)))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    final order = ['apple', 'banana', 'cherry']
        .map((s) => titles.indexOf(s))
        .toList();
    expect(order, [0, 1, 2]);
  });

  testWidgets('delete button removes a todo', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('0 of 0 done'), findsOneWidget);
  });

  testWidgets('Add ignores empty/whitespace input', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('0 of 0 done'), findsOneWidget);
  });
}
```

### Step 6.4: Verify fixture state

- [ ] Materialize and run:

```bash
mkdir -p /tmp/gwf && cp -r lib/tasks/refactor/fixtures/god_widget/. /tmp/gwf/
cd /tmp/gwf && flutter pub get && flutter test
```

Expected: **all tests pass** against the smelly-but-working SUT (this is regression-graded — the model must keep them green after refactor).

- [ ] As a sanity check, intentionally break the SUT (e.g. swap `_filter == 'open'` to `_filter == 'all'`), re-run tests, confirm they fail. Then revert the change.

- [ ] `rm -rf /tmp/gwf`.

### Step 6.5: Asset entries

- [ ] Append:

```yaml
    - lib/tasks/refactor/fixtures/god_widget/pubspec.yaml
    - lib/tasks/refactor/fixtures/god_widget/lib/god_widget.dart
    - lib/tasks/refactor/fixtures/god_widget/test/god_widget_test.dart
```

### Step 6.6: BenchmarkTask class

- [ ] Create `lib/tasks/refactor/god_widget.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class GodWidgetTask extends BenchmarkTask {
  static const _root = 'lib/tasks/refactor/fixtures/god_widget';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/god_widget.dart',
      'test/god_widget_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'refactor.god_widget';

  @override
  Category get category => Category.refactor;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given `lib/god_widget.dart`, a stateful Flutter `GodWidget` that mixes UI, business logic, and state in one large class. Refactor it within the same file into smaller, focused widgets and pure helper functions/classes. Tests in `test/god_widget_test.dart` must continue to pass.

Constraints:
- Public API: only `GodWidget` (StatefulWidget) and `TodoEntry` are publicly observed externally.
- Behavior must be preserved exactly. Do not add or remove user-visible behavior.
- Output must be a single Dart file replacing `lib/god_widget.dart`.

Return ONLY the refactored contents of `lib/god_widget.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/god_widget.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted refactor on a 0.0-1.0 scale on these axes:
- Behavior preservation (most important): the public API of `GodWidget` and `TodoEntry` is unchanged and tests still pass.
- Separation of concerns: extracted smaller widgets (e.g., input row, filter/sort row, list, status footer) and pure helpers.
- No leakage: helper widgets and types are private (underscore-prefixed) where appropriate.
- Naming and readability; absence of dead code; idiomatic Flutter.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
        DiffSizeEvaluator(originalFixturePath: 'lib/god_widget.dart'),
      ];
}
```

### Step 6.7: Register and verify

- [ ] Add `registry.register(GodWidgetTask());` to `task_catalog.dart`.
- [ ] `flutter analyze` clean; `flutter test` green; app smoke.

- [ ] Commit:

```bash
git add lib/tasks/refactor/god_widget.dart lib/tasks/refactor/fixtures/god_widget/ pubspec.yaml lib/tasks/task_catalog.dart
git commit -m "feat(tasks): add refactor.god_widget benchmark task"
```

---

## Task 7: `refactor.callback_hell`

Pure-Dart fixture. Regression-graded. Refactor nested `.then` chains into `async`/`await`.

**Files:**
- Create: `lib/tasks/refactor/callback_hell.dart`
- Create: `lib/tasks/refactor/fixtures/callback_hell/pubspec.yaml`
- Create: `lib/tasks/refactor/fixtures/callback_hell/lib/data_pipeline.dart`
- Create: `lib/tasks/refactor/fixtures/callback_hell/test/data_pipeline_test.dart`
- Modify: `lib/tasks/task_catalog.dart`
- Modify: `pubspec.yaml`

### Step 7.1: Fixture pubspec

- [ ] Create `lib/tasks/refactor/fixtures/callback_hell/pubspec.yaml`:

```yaml
name: callback_hell_fixture
description: Fixture project for refactor.callback_hell task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"

dev_dependencies:
  test: ^1.25.0
```

### Step 7.2: The callback hell SUT (working-but-smelly)

- [ ] Create `lib/tasks/refactor/fixtures/callback_hell/lib/data_pipeline.dart`:

```dart
import 'dart:async';

typedef Fetcher<T> = Future<T> Function();

class PipelineRecord {
  PipelineRecord({required this.userId, required this.userName, required this.orderCount, required this.firstOrderId});
  final String userId;
  final String userName;
  final int orderCount;
  final String firstOrderId;
}

class DataPipeline {
  DataPipeline({
    required this.fetchUserId,
    required this.fetchUserName,
    required this.fetchOrderIds,
    required this.fetchOrderTotal,
  });

  final Fetcher<String> fetchUserId;
  final Future<String> Function(String userId) fetchUserName;
  final Future<List<String>> Function(String userId) fetchOrderIds;
  final Future<int> Function(String orderId) fetchOrderTotal;

  Future<PipelineRecord> run() {
    return fetchUserId().then((userId) {
      return fetchUserName(userId).then((userName) {
        return fetchOrderIds(userId).then((orderIds) {
          if (orderIds.isEmpty) {
            return PipelineRecord(
              userId: userId,
              userName: userName,
              orderCount: 0,
              firstOrderId: '',
            );
          }
          return fetchOrderTotal(orderIds.first).then((_) {
            return PipelineRecord(
              userId: userId,
              userName: userName,
              orderCount: orderIds.length,
              firstOrderId: orderIds.first,
            );
          });
        });
      });
    });
  }
}
```

### Step 7.3: Behavior tests

- [ ] Create `lib/tasks/refactor/fixtures/callback_hell/test/data_pipeline_test.dart`:

```dart
import 'package:callback_hell_fixture/data_pipeline.dart';
import 'package:test/test.dart';

void main() {
  test('happy path returns aggregated record', () async {
    final pipeline = DataPipeline(
      fetchUserId: () async => 'u1',
      fetchUserName: (id) async => 'Alice ($id)',
      fetchOrderIds: (id) async => ['o1', 'o2', 'o3'],
      fetchOrderTotal: (oid) async => 100,
    );
    final r = await pipeline.run();
    expect(r.userId, 'u1');
    expect(r.userName, 'Alice (u1)');
    expect(r.orderCount, 3);
    expect(r.firstOrderId, 'o1');
  });

  test('empty orders returns count 0 and blank firstOrderId', () async {
    final pipeline = DataPipeline(
      fetchUserId: () async => 'u2',
      fetchUserName: (_) async => 'Bob',
      fetchOrderIds: (_) async => <String>[],
      fetchOrderTotal: (_) async => fail('should not be called'),
    );
    final r = await pipeline.run();
    expect(r.userId, 'u2');
    expect(r.orderCount, 0);
    expect(r.firstOrderId, '');
  });

  test('error in fetchUserId propagates', () async {
    final pipeline = DataPipeline(
      fetchUserId: () async => throw StateError('boom'),
      fetchUserName: (_) async => '',
      fetchOrderIds: (_) async => <String>[],
      fetchOrderTotal: (_) async => 0,
    );
    expect(pipeline.run(), throwsA(isA<StateError>()));
  });

  test('error in fetchOrderTotal propagates', () async {
    final pipeline = DataPipeline(
      fetchUserId: () async => 'u3',
      fetchUserName: (_) async => 'C',
      fetchOrderIds: (_) async => ['o1'],
      fetchOrderTotal: (_) async => throw StateError('total fail'),
    );
    expect(pipeline.run(), throwsA(isA<StateError>()));
  });

  test('calls happen in correct order', () async {
    final calls = <String>[];
    final pipeline = DataPipeline(
      fetchUserId: () async {
        calls.add('id');
        return 'u';
      },
      fetchUserName: (_) async {
        calls.add('name');
        return '';
      },
      fetchOrderIds: (_) async {
        calls.add('orders');
        return ['o1'];
      },
      fetchOrderTotal: (_) async {
        calls.add('total');
        return 0;
      },
    );
    await pipeline.run();
    expect(calls, ['id', 'name', 'orders', 'total']);
  });
}
```

### Step 7.4: Verify fixture state

- [ ] Materialize and run:

```bash
mkdir -p /tmp/chf && cp -r lib/tasks/refactor/fixtures/callback_hell/. /tmp/chf/
cd /tmp/chf && dart pub get && dart test
```

Expected: **all tests pass** against the existing callback-chained code.

- [ ] `rm -rf /tmp/chf`.

### Step 7.5: Asset entries

- [ ] Append:

```yaml
    - lib/tasks/refactor/fixtures/callback_hell/pubspec.yaml
    - lib/tasks/refactor/fixtures/callback_hell/lib/data_pipeline.dart
    - lib/tasks/refactor/fixtures/callback_hell/test/data_pipeline_test.dart
```

### Step 7.6: BenchmarkTask class

- [ ] Create `lib/tasks/refactor/callback_hell.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class CallbackHellTask extends BenchmarkTask {
  static const _root = 'lib/tasks/refactor/fixtures/callback_hell';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/data_pipeline.dart',
      'test/data_pipeline_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'refactor.callback_hell';

  @override
  Category get category => Category.refactor;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given `lib/data_pipeline.dart` containing a `DataPipeline.run()` method whose body is a deeply nested `.then` chain. Refactor `run()` to use `async`/`await` while:

- Preserving the public API (signatures of `DataPipeline`, its constructor, and the `PipelineRecord` class).
- Preserving observable behavior: ordering of fetcher calls, the empty-orders short-circuit (no call to `fetchOrderTotal`), and error propagation.

Return ONLY the refactored contents of `lib/data_pipeline.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/data_pipeline.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted refactor on a 0.0-1.0 scale on these axes:
- Use of `async`/`await` throughout `run()`, no remaining `.then` chains.
- Preservation of behavior: ordering, empty-orders short-circuit, error propagation.
- Idiomatic Dart, minimal/readable code.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
        DiffSizeEvaluator(originalFixturePath: 'lib/data_pipeline.dart'),
      ];
}
```

### Step 7.7: Register and verify

- [ ] Add `registry.register(CallbackHellTask());` to `task_catalog.dart`.
- [ ] `flutter analyze` clean; `flutter test` green; app smoke.

- [ ] Commit:

```bash
git add lib/tasks/refactor/callback_hell.dart lib/tasks/refactor/fixtures/callback_hell/ pubspec.yaml lib/tasks/task_catalog.dart
git commit -m "feat(tasks): add refactor.callback_hell benchmark task"
```

---

## Task 8: `test.todo_input`

Flutter fixture. Test-author shape. Ships a working SUT plus a hidden `test/_reference/` suite.

**Files:**
- Create: `lib/tasks/widget_testing/todo_input.dart`
- Create: `lib/tasks/widget_testing/fixtures/todo_input/pubspec.yaml`
- Create: `lib/tasks/widget_testing/fixtures/todo_input/lib/todo_input.dart`
- Create: `lib/tasks/widget_testing/fixtures/todo_input/test/_reference/todo_input_reference_test.dart`
- (Note: NO file at `test/todo_input_test.dart` — that's the model's output path.)
- Modify: `lib/tasks/task_catalog.dart`
- Modify: `pubspec.yaml`

### Step 8.1: Fixture pubspec

- [ ] Create `lib/tasks/widget_testing/fixtures/todo_input/pubspec.yaml`:

```yaml
name: todo_input_fixture
description: Fixture project for test.todo_input task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Step 8.2: The working SUT (do not modify)

- [ ] Create `lib/tasks/widget_testing/fixtures/todo_input/lib/todo_input.dart`:

```dart
import 'package:flutter/material.dart';

class TodoInput extends StatefulWidget {
  const TodoInput({
    super.key,
    required this.onSubmit,
    this.maxLength = 80,
  });

  final ValueChanged<String> onSubmit;
  final int maxLength;

  @override
  State<TodoInput> createState() => _TodoInputState();
}

class _TodoInputState extends State<TodoInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            maxLength: widget.maxLength,
            decoration: const InputDecoration(
              labelText: 'Todo',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: canSubmit ? _submit : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
```

### Step 8.3: Hidden reference test suite (regression net)

- [ ] Create `lib/tasks/widget_testing/fixtures/todo_input/test/_reference/todo_input_reference_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_input_fixture/todo_input.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('Submit is disabled with empty input', (tester) async {
    await tester.pumpWidget(_wrap(TodoInput(onSubmit: (_) {})));
    final button = tester.widget<ElevatedButton>(
      find.byWidgetPredicate((w) => w is ElevatedButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Submit enables once text is entered', (tester) async {
    await tester.pumpWidget(_wrap(TodoInput(onSubmit: (_) {})));
    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();
    final button = tester.widget<ElevatedButton>(
      find.byWidgetPredicate((w) => w is ElevatedButton),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Tapping Submit fires onSubmit and clears the field', (tester) async {
    final received = <String>[];
    await tester.pumpWidget(_wrap(TodoInput(onSubmit: received.add)));
    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(received, ['Buy milk']);
    expect(find.text('Buy milk'), findsNothing);
  });

  testWidgets('respects maxLength', (tester) async {
    await tester.pumpWidget(_wrap(TodoInput(onSubmit: (_) {}, maxLength: 5)));
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.maxLength, 5);
  });
}
```

### Step 8.4: Verify fixture state

- [ ] Materialize and run the reference suite to confirm it passes against the unmodified SUT:

```bash
mkdir -p /tmp/tif && cp -r lib/tasks/widget_testing/fixtures/todo_input/. /tmp/tif/
cd /tmp/tif && flutter pub get && flutter test test/_reference
```

Expected: **all reference tests pass**.

- [ ] Run `flutter test` (no path) — expect no tests to be collected (since the model's output dir `test/` has no top-level files yet, and `flutter test` will skip empty `test/_reference/` only if invoked without path; with `test/_reference` it runs them). To avoid the empty-tests issue at runtime:
  - Confirm: `flutter test test/_reference` passes.
  - The model's submission populates `test/todo_input_test.dart`; when present, `flutter test` (no path) picks it up and the reference suite via `flutter test test/_reference` separately.

- [ ] `rm -rf /tmp/tif`.

### Step 8.5: Asset entries

- [ ] Append:

```yaml
    - lib/tasks/widget_testing/fixtures/todo_input/pubspec.yaml
    - lib/tasks/widget_testing/fixtures/todo_input/lib/todo_input.dart
    - lib/tasks/widget_testing/fixtures/todo_input/test/_reference/todo_input_reference_test.dart
```

### Step 8.6: BenchmarkTask class

- [ ] Create `lib/tasks/widget_testing/todo_input.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/evaluators/widget_tree_evaluator.dart';

class TodoInputTestTask extends BenchmarkTask {
  static const _root = 'lib/tasks/widget_testing/fixtures/todo_input';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/todo_input.dart',
      'test/_reference/todo_input_reference_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'test.todo_input';

  @override
  Category get category => Category.widgetTesting;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given a working `TodoInput` widget in `lib/todo_input.dart`. Write a widget-test suite at `test/todo_input_test.dart` covering this behavior:

- Submit button is disabled when the input is empty (or only whitespace).
- Typing non-empty text enables the Submit button.
- Tapping Submit calls `onSubmit` with the trimmed value and clears the text field.
- `maxLength` is respected (the underlying TextField uses it).
- Pressing Enter (`onSubmitted`) submits the same way as tapping Submit.

Use `flutter_test` and `MaterialApp(home: Scaffold(body: ...))` to host the widget. DO NOT modify `lib/todo_input.dart`.

Return ONLY the contents of `test/todo_input_test.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'test/todo_input_test.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted widget-test suite on a 0.0-1.0 scale on these axes:
- Coverage of each spec bullet (empty/whitespace disable, non-empty enable, submit fires + clears, maxLength, Enter submit).
- Correct use of `pumpWidget`, `enterText`, `tap`, and finders; no flaky patterns (e.g., relying on undefined ordering).
- Tests are self-contained, well-named, and isolated.
- No unjustified `pumpAndSettle` loops or sleeps.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(testPath: 'test/todo_input_test.dart'),
        WidgetTreeEvaluator(testDir: 'test/_reference'),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
      ];
}
```

> `DiffSizeEvaluator` is omitted because the fixture has no original at `test/todo_input_test.dart` (model is authoring it). Re-add only if `DiffSizeEvaluator` is updated to handle missing originals gracefully — out of scope for this plan.

### Step 8.7: Register and verify

- [ ] Add `registry.register(TodoInputTestTask());` to `task_catalog.dart`.
- [ ] `flutter analyze` clean; `flutter test` green.
- [ ] App smoke: pick `test.todo_input`, run, verify:
  - Reference suite is invoked via `WidgetTreeEvaluator` and passes.
  - The model's test (`TestEvaluator`) is invoked and produces a real score.
  - If the model's test file is missing or empty, evaluators should still produce results without crashing.

- [ ] Commit:

```bash
git add lib/tasks/widget_testing/todo_input.dart lib/tasks/widget_testing/fixtures/todo_input/ pubspec.yaml lib/tasks/task_catalog.dart
git commit -m "feat(tasks): add test.todo_input benchmark task"
```

---

## Task 9: `test.form_validation`

Same shape as Task 8, different SUT and reference suite.

**Files:**
- Create: `lib/tasks/widget_testing/form_validation.dart`
- Create: `lib/tasks/widget_testing/fixtures/form_validation/pubspec.yaml`
- Create: `lib/tasks/widget_testing/fixtures/form_validation/lib/signup_form.dart`
- Create: `lib/tasks/widget_testing/fixtures/form_validation/test/_reference/signup_form_reference_test.dart`
- Modify: `lib/tasks/task_catalog.dart`
- Modify: `pubspec.yaml`

### Step 9.1: Fixture pubspec

- [ ] Create `lib/tasks/widget_testing/fixtures/form_validation/pubspec.yaml`:

```yaml
name: form_validation_fixture
description: Fixture project for test.form_validation task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Step 9.2: Working SUT

- [ ] Create `lib/tasks/widget_testing/fixtures/form_validation/lib/signup_form.dart`:

```dart
import 'package:flutter/material.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key, required this.onSubmit});

  final void Function({required String email, required String password}) onSubmit;

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_revalidate);
    _passwordCtrl.addListener(_revalidate);
  }

  void _revalidate() {
    final ok = SignupForm.validateEmail(_emailCtrl.text) == null &&
        SignupForm.validatePassword(_passwordCtrl.text) == null;
    if (ok != _valid) setState(() => _valid = ok);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          TextFormField(
            key: const Key('email'),
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: SignupForm.validateEmail,
          ),
          TextFormField(
            key: const Key('password'),
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: SignupForm.validatePassword,
          ),
          ElevatedButton(
            key: const Key('submit'),
            onPressed: _valid ? _submit : null,
            child: const Text('Sign up'),
          ),
        ],
      ),
    );
  }
}
```

### Step 9.3: Reference suite

- [ ] Create `lib/tasks/widget_testing/fixtures/form_validation/test/_reference/signup_form_reference_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_validation_fixture/signup_form.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('submit disabled until both fields valid', (tester) async {
    await tester.pumpWidget(_wrap(SignupForm(onSubmit: ({required email, required password}) {})));
    final initial = tester.widget<ElevatedButton>(find.byKey(const Key('submit')));
    expect(initial.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('email')), 'a@b.com');
    await tester.pump();
    final emailOnly = tester.widget<ElevatedButton>(find.byKey(const Key('submit')));
    expect(emailOnly.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('password')), 'longenough');
    await tester.pump();
    final both = tester.widget<ElevatedButton>(find.byKey(const Key('submit')));
    expect(both.onPressed, isNotNull);
  });

  testWidgets('valid submit fires onSubmit with values', (tester) async {
    String? capturedEmail;
    String? capturedPwd;
    await tester.pumpWidget(_wrap(SignupForm(
      onSubmit: ({required email, required password}) {
        capturedEmail = email;
        capturedPwd = password;
      },
    )));
    await tester.enterText(find.byKey(const Key('email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('password')), 'longenough');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();
    expect(capturedEmail, 'a@b.com');
    expect(capturedPwd, 'longenough');
  });

  testWidgets('invalid email shows error message', (tester) async {
    await tester.pumpWidget(_wrap(SignupForm(onSubmit: ({required email, required password}) {})));
    await tester.enterText(find.byKey(const Key('email')), 'nope');
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('short password shows error message', (tester) async {
    await tester.pumpWidget(_wrap(SignupForm(onSubmit: ({required email, required password}) {})));
    await tester.enterText(find.byKey(const Key('password')), 'short');
    await tester.pump();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });
}
```

### Step 9.4: Verify fixture state

- [ ] Materialize and run `flutter test test/_reference` — expect green. `rm -rf /tmp/fvf`.

### Step 9.5: Asset entries

- [ ] Append:

```yaml
    - lib/tasks/widget_testing/fixtures/form_validation/pubspec.yaml
    - lib/tasks/widget_testing/fixtures/form_validation/lib/signup_form.dart
    - lib/tasks/widget_testing/fixtures/form_validation/test/_reference/signup_form_reference_test.dart
```

### Step 9.6: BenchmarkTask class

- [ ] Create `lib/tasks/widget_testing/form_validation.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/evaluators/widget_tree_evaluator.dart';

class FormValidationTestTask extends BenchmarkTask {
  static const _root = 'lib/tasks/widget_testing/fixtures/form_validation';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/signup_form.dart',
      'test/_reference/signup_form_reference_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'test.form_validation';

  @override
  Category get category => Category.widgetTesting;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given a working `SignupForm` in `lib/signup_form.dart`. Write a widget-test suite at `test/signup_form_test.dart` covering:

- Submit button is disabled until both email and password are valid.
- Invalid email shows "Enter a valid email" error message.
- Empty email shows "Email is required" error message.
- Empty password shows "Password is required" error message.
- Password shorter than 8 characters shows "Password must be at least 8 characters".
- Tapping Submit with valid inputs calls `onSubmit` with the trimmed email and the password.

DO NOT modify `lib/signup_form.dart`. Use `Key('email')`, `Key('password')`, `Key('submit')` for finders.

Return ONLY the contents of `test/signup_form_test.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'test/signup_form_test.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted widget-test suite on a 0.0-1.0 scale on these axes:
- Coverage of each spec bullet (each error message, each disabled/enabled transition, the valid submit path).
- Correct use of `Form`, `TextFormField`, finders by Key, and `enterText` + `pump`.
- Tests are independent and self-contained.
- No flakiness patterns.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(testPath: 'test/signup_form_test.dart'),
        WidgetTreeEvaluator(testDir: 'test/_reference'),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
      ];
}
```

> `DiffSizeEvaluator` is omitted as in Task 8 (no original to diff against).

### Step 9.7: Register and verify

- [ ] Add `registry.register(FormValidationTestTask());` to `task_catalog.dart`.
- [ ] `flutter analyze` clean; `flutter test` green; app smoke.

- [ ] Commit:

```bash
git add lib/tasks/widget_testing/form_validation.dart lib/tasks/widget_testing/fixtures/form_validation/ pubspec.yaml lib/tasks/task_catalog.dart
git commit -m "feat(tasks): add test.form_validation benchmark task"
```

---

## Task 10: `bug.async_race_condition`

Pure-Dart fixture. Regression-graded. The trickiest fixture (deterministic race). Uses `fake_async`.

**Files:**
- Create: `lib/tasks/bug_fix/async_race_condition.dart`
- Create: `lib/tasks/bug_fix/fixtures/async_race_condition/pubspec.yaml`
- Create: `lib/tasks/bug_fix/fixtures/async_race_condition/lib/search_controller.dart`
- Create: `lib/tasks/bug_fix/fixtures/async_race_condition/test/search_controller_test.dart`
- Modify: `lib/tasks/task_catalog.dart`
- Modify: `pubspec.yaml`

### Step 10.1: Fixture pubspec

- [ ] Create `lib/tasks/bug_fix/fixtures/async_race_condition/pubspec.yaml`:

```yaml
name: async_race_condition_fixture
description: Fixture project for bug.async_race_condition task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"

dev_dependencies:
  test: ^1.25.0
  fake_async: ^1.3.1
```

### Step 10.2: Broken SUT (race condition)

- [ ] Create `lib/tasks/bug_fix/fixtures/async_race_condition/lib/search_controller.dart`:

```dart
import 'dart:async';

typedef Searcher = Future<List<String>> Function(String query);

class SearchController {
  SearchController({required this.search});

  final Searcher search;
  final StreamController<List<String>> _results = StreamController<List<String>>.broadcast();

  Stream<List<String>> get results => _results.stream;

  void onQueryChanged(String query) {
    // BUG: each call kicks off a fetch that writes to _results when it completes,
    // regardless of whether a newer query has been issued in the meantime.
    search(query).then((value) {
      if (_results.isClosed) return;
      _results.add(value);
    });
  }

  Future<void> dispose() async {
    await _results.close();
  }
}
```

### Step 10.3: Failing tests

- [ ] Create `lib/tasks/bug_fix/fixtures/async_race_condition/test/search_controller_test.dart`:

```dart
import 'dart:async';

import 'package:async_race_condition_fixture/search_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

void main() {
  test('only the latest query result is emitted when calls overlap', () {
    fakeAsync((async) {
      final emitted = <List<String>>[];

      final ctrl = SearchController(
        search: (q) async {
          // First query is slow; later queries are fast.
          if (q == 'slow') {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return ['slow-result'];
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return ['$q-result'];
        },
      );
      ctrl.results.listen(emitted.add);

      ctrl.onQueryChanged('slow');
      async.elapse(const Duration(milliseconds: 5));
      ctrl.onQueryChanged('fast');

      async.elapse(const Duration(milliseconds: 200));

      expect(emitted, [['fast-result']]);
      ctrl.dispose();
    });
  });

  test('non-overlapping queries each emit', () {
    fakeAsync((async) {
      final emitted = <List<String>>[];
      final ctrl = SearchController(
        search: (q) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return ['$q-result'];
        },
      );
      ctrl.results.listen(emitted.add);

      ctrl.onQueryChanged('a');
      async.elapse(const Duration(milliseconds: 50));
      ctrl.onQueryChanged('b');
      async.elapse(const Duration(milliseconds: 50));

      expect(emitted, [['a-result'], ['b-result']]);
      ctrl.dispose();
    });
  });

  test('three rapidly successive queries: only last emits', () {
    fakeAsync((async) {
      final emitted = <List<String>>[];
      final ctrl = SearchController(
        search: (q) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return [q];
        },
      );
      ctrl.results.listen(emitted.add);

      ctrl.onQueryChanged('first');
      async.elapse(const Duration(milliseconds: 5));
      ctrl.onQueryChanged('second');
      async.elapse(const Duration(milliseconds: 5));
      ctrl.onQueryChanged('third');
      async.elapse(const Duration(milliseconds: 200));

      expect(emitted, [['third']]);
      ctrl.dispose();
    });
  });
}
```

### Step 10.4: Verify fixture state

- [ ] Materialize and run:

```bash
mkdir -p /tmp/arcf && cp -r lib/tasks/bug_fix/fixtures/async_race_condition/. /tmp/arcf/
cd /tmp/arcf && dart pub get && dart test
```

Expected: tests **fail** (the broken SUT emits stale results).

- [ ] Drop in a reference fix to confirm acceptance. Replace the body of `onQueryChanged` and add a request-generation field:

```dart
class SearchController {
  SearchController({required this.search});

  final Searcher search;
  final StreamController<List<String>> _results = StreamController<List<String>>.broadcast();
  int _generation = 0;

  Stream<List<String>> get results => _results.stream;

  void onQueryChanged(String query) {
    final myGen = ++_generation;
    search(query).then((value) {
      if (_results.isClosed) return;
      if (myGen != _generation) return;
      _results.add(value);
    });
  }

  Future<void> dispose() async {
    await _results.close();
  }
}
```

Run `dart test` again — expect **all green deterministically across 10 runs**:

```bash
for i in 1 2 3 4 5 6 7 8 9 10; do dart test || break; done
```

- [ ] `rm -rf /tmp/arcf`.

### Step 10.5: Asset entries

- [ ] Append:

```yaml
    - lib/tasks/bug_fix/fixtures/async_race_condition/pubspec.yaml
    - lib/tasks/bug_fix/fixtures/async_race_condition/lib/search_controller.dart
    - lib/tasks/bug_fix/fixtures/async_race_condition/test/search_controller_test.dart
```

### Step 10.6: BenchmarkTask class

- [ ] Create `lib/tasks/bug_fix/async_race_condition.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class AsyncRaceConditionTask extends BenchmarkTask {
  static const _root = 'lib/tasks/bug_fix/fixtures/async_race_condition';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/search_controller.dart',
      'test/search_controller_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'bug.async_race_condition';

  @override
  Category get category => Category.bugFix;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given `lib/search_controller.dart` containing `SearchController.onQueryChanged(String query)`. There is a race condition: rapid query changes can cause stale results to overwrite fresh ones. Failing tests in `test/search_controller_test.dart` (using `fake_async`) demonstrate the bug.

Fix the controller so only the latest query's results are emitted. Constraints:
- Preserve the public API (constructor, `results` stream, `onQueryChanged`, `dispose`).
- Keep the stream-based control flow.
- No busy-waiting or polling.

Return ONLY the corrected contents of `lib/search_controller.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/search_controller.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted SearchController fix on a 0.0-1.0 scale on these axes:
- Correctness of the fix (most important): only the latest query's results are emitted in all overlap scenarios.
- Minimal, surgical change vs. the broken original.
- Idiomatic cancellation/generation pattern; no busy-waiting; no polling.
- Readability and absence of dead code.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestEvaluator(),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
        DiffSizeEvaluator(originalFixturePath: 'lib/search_controller.dart'),
      ];
}
```

### Step 10.7: Register and verify

- [ ] Add `registry.register(AsyncRaceConditionTask());` to `task_catalog.dart`. Final `task_catalog.dart`:

```dart
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/tasks/bug_fix/async_race_condition.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
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
  return registry;
}
```

- [ ] `flutter analyze` clean; `flutter test` green.
- [ ] App smoke: pick `bug.async_race_condition`, run, verify non-null score.

- [ ] Commit:

```bash
git add lib/tasks/bug_fix/async_race_condition.dart lib/tasks/bug_fix/fixtures/async_race_condition/ pubspec.yaml lib/tasks/task_catalog.dart
git commit -m "feat(tasks): add bug.async_race_condition benchmark task"
```

---

## Final verification (Plan 5 acceptance)

- [ ] Run `flutter analyze` — zero errors, zero warnings.
- [ ] Run `flutter test` — all green.
- [ ] App: `buildDefaultTaskRegistry()` returns 10 tasks. Verify in NewRunPage's task picker that all 10 appear, grouped by category.
- [ ] Run all 10 tasks end-to-end against one cheap candidate provider plus one judge provider. Verify:
  - Each completes without exceptions.
  - Each produces a non-null aggregate score.
  - Per-evaluator details show the correct tool (`flutter` for `isFlutter == true` tasks; `dart` for the rest).
- [ ] For each task, hand-write a known-correct reference solution and submit it manually (not via a model — paste into the model output mechanism, or run a quick unit test that calls the runner directly with a stub provider returning the reference solution). Score must be ≥ 0.9.
- [ ] For each task, submit a deliberately weak/empty output (e.g., just `class Foo {}`) and verify score < 0.3 with no evaluator crashes.
- [ ] Reference suite for both `test.*` tasks passes against the unmodified SUT (already verified in §8.4 and §9.4).

- [ ] Commit any small fixes from the verification pass. No README/docs updates.

---

## Self-Review Notes

**Spec coverage:**
- §3.1 FixtureLoader → Task 1.
- §3.1 ensureLoaded hook → Task 1.
- §3.1 isFlutter dispatch (added late) → Task 1.5–1.7.
- §3.2 uniform task layout → applied per Task.
- §3.3 three grading shapes → mapped per Task.
- §3.4 single-file output → enforced by all `generatedCodePath` declarations.
- §4.1–4.10 per-task contracts → Tasks 1–10.
- §5.1 implementation order → matches Tasks 1–10.
- §5.2 registry wiring → final state in §10.7.
- §5.3 asset registration → per-file lines added per Task.
- §6 acceptance criteria → final verification section.

**Open follow-ups (not blocking Plan 5):**
- `DiffSizeEvaluator` is omitted from test-author tasks because the fixture has no original at the model's `generatedCodePath`. A future small change can extend `DiffSizeEvaluator` to treat a missing original as size 0, which would let test-author tasks include it for the diff signal.
- The model is told not to write under `test/_reference/`, but nothing structurally prevents it. If a model maliciously or accidentally writes there, only `WidgetTreeEvaluator` (which runs that exact dir) would be affected, and it would surface as a passing-but-suspicious result. Acceptable risk for this plan.
