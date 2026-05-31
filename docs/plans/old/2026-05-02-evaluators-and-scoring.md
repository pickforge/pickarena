# dart_arena — Plan 3: Evaluators, Weighted Scoring, Judge Config

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 5 new evaluators (Analyze, Test, WidgetTree, LlmJudge, DiffSize), weighted aggregate scoring, and per-run judge model configuration so each task run produces a multi-dimensional quality score instead of a single pass/fail compile signal.

**Architecture:** A pre-step `WorkdirManager.prepare(dir)` runs `dart pub get` once per task; each evaluator becomes a thin process wrapper. Tasks declare their evaluators via `evaluatorsFor(EvaluatorConfig)` so the runner can inject the optional judge `ModelProvider` + `judgeModel`. Aggregate scoring lives in a pure function in `core/scoring.dart`. Judge provider/model and evaluator weight overrides persist via `flutter_secure_storage`. No Drift schema changes.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, flutter_bloc, drift, dio, flutter_secure_storage, mocktail (tests). NEW: `diff_match_patch ^0.4.1`.

**Predecessors:** Plan 1 (foundation + first slice) and Plan 2 (cloud providers) are fully implemented.

---

## File map (this plan)

### Created

- `lib/core/scoring.dart` — `defaultEvaluatorWeights`, pure `aggregate(...)` function
- `lib/core/evaluator_config.dart` — `EvaluatorConfig` value object (judge provider + judge model)
- `lib/evaluators/analyze_evaluator.dart` — graded analyze (warnings/infos)
- `lib/evaluators/test_evaluator.dart` — `dart test --reporter=json`, fractional pass rate
- `lib/evaluators/widget_tree_evaluator.dart` — `flutter test`, fractional pass rate
- `lib/evaluators/llm_judge_evaluator.dart` — sends rubric+code to judge, parses JSON score
- `lib/evaluators/diff_size_evaluator.dart` — line-level diff against original fixture
- `lib/evaluators/_test_reporter_parser.dart` — shared JSON test-event parser
- `test/core/scoring_test.dart`
- `test/core/evaluator_config_test.dart`
- `test/core/code_extractor_json_test.dart`
- `test/evaluators/analyze_evaluator_test.dart`
- `test/evaluators/test_evaluator_test.dart`
- `test/evaluators/widget_tree_evaluator_test.dart`
- `test/evaluators/llm_judge_evaluator_test.dart`
- `test/evaluators/diff_size_evaluator_test.dart`
- `test/storage/settings_judge_test.dart`
- `test/runner/workdir_manager_prepare_test.dart`

### Modified

- `pubspec.yaml` — add `diff_match_patch: ^0.4.1`
- `lib/core/benchmark_task.dart` — `evaluators` → `evaluatorsFor(EvaluatorConfig)`; add `generatedCodePath`
- `lib/core/code_extractor.dart` — add `extractJsonBlock`
- `lib/runner/workdir_manager.dart` — add `prepare(Directory)` + `PrepareResult`
- `lib/evaluators/compile_evaluator.dart` — slim to `dart analyze --fatal-infos`
- `lib/runner/run_event.dart` — `StartRun` adds `evaluatorConfig`
- `lib/runner/run_bloc.dart` — call `prepare`; carry `EvaluatorConfig`; use `task.generatedCodePath`; aggregate via `scoring.aggregate`
- `lib/storage/settings.dart` — judge provider/model + evaluator weights accessors
- `lib/tasks/bug_fix/off_by_one_pagination.dart` — implement `evaluatorsFor` + `generatedCodePath` + `judgeRubric`
- `lib/ui/pages/settings_page.dart` — Judge Model section
- `lib/ui/pages/new_run_page.dart` — pass `EvaluatorConfig` through `StartRun`
- `test/runner/run_bloc_test.dart` — extended for prepare-failure path; `EvaluatorConfig` plumbing
- `test/evaluators/compile_evaluator_test.dart` — adjusted to slimmer responsibility

---

## Task 1: Add `diff_match_patch` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Edit `pubspec.yaml`, add to `dependencies:` (alphabetical with existing entries)**

```yaml
  dio: ^5.7.0
  diff_match_patch: ^0.4.1
  drift: ^2.20.3
```

- [ ] **Step 2: Fetch deps**

```bash
flutter pub get
```

Expected: success, `diff_match_patch` resolves to ^0.4.1.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add diff_match_patch dependency for DiffSizeEvaluator"
```

---

## Task 2: `core/scoring.dart` — defaults + `aggregate` pure function

**Files:**
- Create: `lib/core/scoring.dart`
- Test: `test/core/scoring_test.dart`

- [ ] **Step 1: Write failing tests**

`test/core/scoring_test.dart`:
```dart
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aggregate', () {
    test('empty list returns 0.0', () {
      expect(aggregate(const [], const {}), 0.0);
    });

    test('single evaluator returns its own score', () {
      const r = EvaluationResult(
        evaluatorId: 'compile',
        passed: true,
        score: 0.7,
      );
      expect(aggregate([r], const {'compile': 0.5}), closeTo(0.7, 1e-9));
    });

    test('weighted average respects weights', () {
      const a = EvaluationResult(
        evaluatorId: 'compile',
        passed: true,
        score: 1.0,
      );
      const b = EvaluationResult(
        evaluatorId: 'test',
        passed: false,
        score: 0.0,
      );
      // weights: compile=0.5, test=1.0 -> (1*0.5 + 0*1.0) / 1.5 = 0.333...
      expect(
        aggregate([a, b], const {'compile': 0.5, 'test': 1.0}),
        closeTo(1.0 / 3.0, 1e-9),
      );
    });

    test('missing weight defaults to 1.0', () {
      const a = EvaluationResult(
        evaluatorId: 'foo',
        passed: true,
        score: 1.0,
      );
      const b = EvaluationResult(
        evaluatorId: 'bar',
        passed: true,
        score: 0.0,
      );
      // both default to 1.0 -> simple mean = 0.5
      expect(aggregate([a, b], const {}), closeTo(0.5, 1e-9));
    });

    test('zero total weight returns 0.0', () {
      const r = EvaluationResult(
        evaluatorId: 'compile',
        passed: true,
        score: 1.0,
      );
      expect(aggregate([r], const {'compile': 0.0}), 0.0);
    });
  });

  test('defaultEvaluatorWeights covers all built-in evaluators', () {
    expect(defaultEvaluatorWeights.keys, containsAll(<String>[
      'compile',
      'analyze',
      'test',
      'widget_tree',
      'llm_judge',
      'diff_size',
    ]));
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/core/scoring_test.dart
```

Expected: FAIL — `scoring.dart` does not exist.

- [ ] **Step 3: Implement**

`lib/core/scoring.dart`:
```dart
import 'package:dart_arena/core/evaluation_result.dart';

const Map<String, double> defaultEvaluatorWeights = {
  'compile': 0.5,
  'analyze': 0.5,
  'test': 1.0,
  'widget_tree': 1.0,
  'llm_judge': 0.7,
  'diff_size': 0.3,
};

double aggregate(
  List<EvaluationResult> results,
  Map<String, double> weights,
) {
  if (results.isEmpty) return 0.0;
  var num = 0.0;
  var den = 0.0;
  for (final r in results) {
    final w = weights[r.evaluatorId] ?? 1.0;
    num += r.score * w;
    den += w;
  }
  return den == 0 ? 0.0 : num / den;
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/core/scoring_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/scoring.dart test/core/scoring_test.dart
git commit -m "feat(core): add scoring.aggregate and default evaluator weights"
```

---

## Task 3: `core/evaluator_config.dart` — value object

**Files:**
- Create: `lib/core/evaluator_config.dart`
- Test: `test/core/evaluator_config_test.dart`

- [ ] **Step 1: Failing test**

`test/core/evaluator_config_test.dart`:
```dart
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasJudge false when both null', () {
    const c = EvaluatorConfig();
    expect(c.hasJudge, isFalse);
  });

  test('hasJudge false when only one set', () {
    expect(
      const EvaluatorConfig(judgeModel: 'gpt-4o-mini').hasJudge,
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/core/evaluator_config_test.dart
```

- [ ] **Step 3: Implement**

`lib/core/evaluator_config.dart`:
```dart
import 'package:dart_arena/providers/model_provider.dart';

class EvaluatorConfig {
  const EvaluatorConfig({this.judgeProvider, this.judgeModel});

  final ModelProvider? judgeProvider;
  final String? judgeModel;

  bool get hasJudge => judgeProvider != null && judgeModel != null;
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/core/evaluator_config_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/evaluator_config.dart test/core/evaluator_config_test.dart
git commit -m "feat(core): add EvaluatorConfig value object"
```

---

## Task 4: `extractJsonBlock` helper

**Files:**
- Modify: `lib/core/code_extractor.dart`
- Test: `test/core/code_extractor_json_test.dart`

- [ ] **Step 1: Failing tests**

`test/core/code_extractor_json_test.dart`:
```dart
import 'package:dart_arena/core/code_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractJsonBlock', () {
    test('returns content of first ```json fenced block', () {
      const raw = '''
Some text.
```json
{"score": 0.9, "rationale": "ok"}
```
trailing.
''';
      expect(
        extractJsonBlock(raw),
        '{"score": 0.9, "rationale": "ok"}\n',
      );
    });

    test('falls back to bare ``` block when json not labeled', () {
      const raw = '''
```
{"a": 1}
```
''';
      expect(extractJsonBlock(raw), '{"a": 1}\n');
    });

    test('returns null when no fenced block', () {
      expect(extractJsonBlock('no fences here'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/core/code_extractor_json_test.dart
```

- [ ] **Step 3: Add `extractJsonBlock` to `lib/core/code_extractor.dart`**

After the existing `extractDartCode` function, append:

```dart
String? extractJsonBlock(String raw) {
  final jsonFence = RegExp(r'```json\s*\n([\s\S]*?)\n```');
  final jsonMatch = jsonFence.firstMatch(raw);
  if (jsonMatch != null) return '${jsonMatch.group(1)!}\n';

  final anyFence = RegExp(r'```\s*\n([\s\S]*?)\n```');
  final anyMatch = anyFence.firstMatch(raw);
  if (anyMatch != null) return '${anyMatch.group(1)!}\n';

  return null;
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/core/code_extractor_json_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/code_extractor.dart test/core/code_extractor_json_test.dart
git commit -m "feat(core): add extractJsonBlock helper"
```

---

## Task 5: Settings — judge provider/model + evaluator weights

**Files:**
- Modify: `lib/storage/settings.dart`
- Test: `test/storage/settings_judge_test.dart`

- [ ] **Step 1: Failing tests**

`test/storage/settings_judge_test.dart`:
```dart
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('judge provider/model default to null', () async {
    final repo = SettingsRepository();
    expect(await repo.getJudgeProviderId(), isNull);
    expect(await repo.getJudgeModelId(), isNull);
  });

  test('judge provider/model roundtrip', () async {
    final repo = SettingsRepository();
    await repo.setJudgeProviderId('openai');
    await repo.setJudgeModelId('gpt-4o-mini');
    expect(await repo.getJudgeProviderId(), 'openai');
    expect(await repo.getJudgeModelId(), 'gpt-4o-mini');
  });

  test('judge provider/model can be cleared', () async {
    final repo = SettingsRepository();
    await repo.setJudgeProviderId('openai');
    await repo.setJudgeProviderId(null);
    expect(await repo.getJudgeProviderId(), isNull);
  });

  test('evaluator weights returns defaults when no overrides', () async {
    final repo = SettingsRepository();
    final weights = await repo.getEvaluatorWeights();
    expect(weights, equals(defaultEvaluatorWeights));
  });

  test('evaluator weights merges overrides on top of defaults', () async {
    final repo = SettingsRepository();
    await repo.setEvaluatorWeights({'compile': 0.9, 'unknown': 0.1});
    final weights = await repo.getEvaluatorWeights();
    expect(weights['compile'], 0.9);
    expect(weights['test'], defaultEvaluatorWeights['test']);
    expect(weights['unknown'], 0.1);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/storage/settings_judge_test.dart
```

- [ ] **Step 3: Append to `lib/storage/settings.dart`**

Add these imports at the top of the file (or merge into existing imports):

```dart
import 'dart:convert';

import 'package:dart_arena/core/scoring.dart';
```

Inside the `SettingsRepository` class, add the following constants alongside the existing ones:

```dart
  static const _judgeProviderId = 'judge_provider_id';
  static const _judgeModelId = 'judge_model_id';
  static const _evaluatorWeightsJson = 'evaluator_weights_json';
```

Then add these methods inside the class:

```dart
  Future<String?> getJudgeProviderId() =>
      _storage.read(key: _judgeProviderId);

  Future<void> setJudgeProviderId(String? id) async {
    if (id == null) {
      await _storage.delete(key: _judgeProviderId);
    } else {
      await _storage.write(key: _judgeProviderId, value: id);
    }
  }

  Future<String?> getJudgeModelId() => _storage.read(key: _judgeModelId);

  Future<void> setJudgeModelId(String? id) async {
    if (id == null) {
      await _storage.delete(key: _judgeModelId);
    } else {
      await _storage.write(key: _judgeModelId, value: id);
    }
  }

  Future<Map<String, double>> getEvaluatorWeights() async {
    final raw = await _storage.read(key: _evaluatorWeightsJson);
    final overrides = <String, double>{};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final v = entry.value;
        if (v is num) overrides[entry.key] = v.toDouble();
      }
    }
    return {...defaultEvaluatorWeights, ...overrides};
  }

  Future<void> setEvaluatorWeights(Map<String, double> overrides) =>
      _storage.write(
        key: _evaluatorWeightsJson,
        value: jsonEncode(overrides),
      );
```

- [ ] **Step 4: Run all storage tests, verify pass**

```bash
flutter test test/storage/
```

- [ ] **Step 5: Commit**

```bash
git add lib/storage/settings.dart test/storage/settings_judge_test.dart
git commit -m "feat(storage): add judge provider/model and evaluator weights settings"
```

---

## Task 6: `WorkdirManager.prepare` + `PrepareResult`

**Files:**
- Modify: `lib/runner/workdir_manager.dart`
- Test: `test/runner/workdir_manager_prepare_test.dart`

- [ ] **Step 1: Failing tests**

`test/runner/workdir_manager_prepare_test.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('prepare succeeds for a minimal valid pubspec', () async {
    final root = await Directory.systemTemp.createTemp('dart_arena_prep_ok_');
    final dir = Directory(p.join(root.path, 'pkg'))..createSync();
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');

    final result = await WorkdirManager(root: root).prepare(dir);
    expect(result, isA<PrepareOk>());

    root.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('prepare fails for a malformed pubspec', () async {
    final root =
        await Directory.systemTemp.createTemp('dart_arena_prep_fail_');
    final dir = Directory(p.join(root.path, 'pkg'))..createSync();
    File(p.join(dir.path, 'pubspec.yaml'))
        .writeAsStringSync('this is not valid pubspec yaml: : :\n');

    final result = await WorkdirManager(root: root).prepare(dir);
    expect(result, isA<PrepareFailed>());
    expect((result as PrepareFailed).stderr, isNotEmpty);

    root.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/runner/workdir_manager_prepare_test.dart
```

- [ ] **Step 3: Implement in `lib/runner/workdir_manager.dart`**

Replace the file contents with:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

sealed class PrepareResult {
  const PrepareResult();
}

class PrepareOk extends PrepareResult {
  const PrepareOk();
}

class PrepareFailed extends PrepareResult {
  const PrepareFailed(this.stderr);
  final String stderr;
}

class WorkdirManager {
  WorkdirManager({required this.root});

  final Directory root;

  Future<Directory> createTaskWorkdir({
    required String runId,
    required String providerId,
    required String modelId,
    required String taskId,
    required Map<String, String> fixtures,
    required String? generatedCode,
    required String generatedCodePath,
  }) async {
    final dir = Directory(
      p.join(root.path, 'runs', runId, providerId, modelId, taskId),
    );
    await dir.create(recursive: true);

    for (final entry in fixtures.entries) {
      final f = File(p.join(dir.path, entry.key));
      await f.parent.create(recursive: true);
      await f.writeAsString(entry.value);
    }

    if (generatedCode != null) {
      final f = File(p.join(dir.path, generatedCodePath));
      await f.parent.create(recursive: true);
      await f.writeAsString(generatedCode);
    }

    return dir;
  }

  Future<PrepareResult> prepare(Directory workDir) async {
    final offline = await Process.run(
      'dart',
      ['pub', 'get', '--offline'],
      workingDirectory: workDir.path,
    );
    if (offline.exitCode == 0) return const PrepareOk();

    final online = await Process.run(
      'dart',
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
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/runner/workdir_manager_prepare_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/runner/workdir_manager.dart test/runner/workdir_manager_prepare_test.dart
git commit -m "feat(runner): add WorkdirManager.prepare for shared pub get step"
```

---

## Task 7: `BenchmarkTask` interface — `evaluatorsFor` + `generatedCodePath`

**Files:**
- Modify: `lib/core/benchmark_task.dart`
- Modify: `lib/tasks/bug_fix/off_by_one_pagination.dart`
- Modify: `lib/runner/run_bloc.dart` (minimal shim to keep tree compiling)
- Modify: `test/runner/run_bloc_test.dart` (minimal shim)

This is a breaking interface change. To keep the codebase compiling after this task (so subsequent evaluator tasks can `flutter test` cleanly), we apply a minimal shim to `run_bloc.dart` and `run_bloc_test.dart` here. The full RunBloc rewrite (prepare step + real EvaluatorConfig + scoring.aggregate) lands in Task 17.

- [ ] **Step 1: Replace `lib/core/benchmark_task.dart`**

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
  List<Evaluator> evaluatorsFor(EvaluatorConfig config);
}
```

- [ ] **Step 2: Make `OffByOnePaginationTask` compile under the new interface**

Open `lib/tasks/bug_fix/off_by_one_pagination.dart`. Replace its body so the class implements the new interface (final evaluators set lands in Task 15; for now we just need it to compile):

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:flutter/services.dart';

class OffByOnePaginationTask extends BenchmarkTask {
  @override
  String get id => 'bug.off_by_one_pagination';

  @override
  Category get category => Category.bugFix;

  @override
  String get prompt => '''
You are given a Dart class `Paginator<T>` in `lib/pagination.dart` that has off-by-one bugs.
There are tests in `test/pagination_test.dart` that currently fail.

Return ONLY the corrected contents of `lib/pagination.dart` inside a single ```dart fenced block.
Do not include explanatory text outside the block. Do not change the public API.
''';

  @override
  Map<String, String> get fixtures => _fixtures;
  static final Map<String, String> _fixtures = {};

  static Future<void> loadAssets() async {
    if (_fixtures.isNotEmpty) return;
    const base = 'lib/tasks/bug_fix/fixtures/off_by_one_pagination';
    _fixtures['pubspec.yaml'] =
        await rootBundle.loadString('$base/pubspec.yaml');
    _fixtures['lib/pagination.dart'] =
        await rootBundle.loadString('$base/lib/pagination.dart');
    _fixtures['test/pagination_test.dart'] =
        await rootBundle.loadString('$base/test/pagination_test.dart');
  }

  @override
  String get generatedCodePath => 'lib/pagination.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) =>
      [CompileEvaluator()];
}
```

(The full evaluator set + a populated `judgeRubric` lands in Task 15.)

- [ ] **Step 3: Apply minimal shim in `lib/runner/run_bloc.dart`**

Locate the line currently doing the evaluator iteration:

```dart
for (final evaluator in task.evaluators) {
```

Replace with:

```dart
for (final evaluator in task.evaluatorsFor(const EvaluatorConfig())) {
```

Add the import at the top of the file:

```dart
import 'package:dart_arena/core/evaluator_config.dart';
```

Also locate the `WorkdirManager.createTaskWorkdir(...)` call inside the bloc's task loop. The current call passes a hardcoded `generatedCodePath: 'lib/pagination.dart'`. Replace that line with:

```dart
            generatedCodePath: task.generatedCodePath,
```

This is the minimum change to keep the tree compiling under the new interface. Task 17 replaces the whole method.

- [ ] **Step 4: Apply minimal shim in `test/runner/run_bloc_test.dart`**

Find the `_StubTask` class. Replace its body with:

```dart
class _StubTask extends BenchmarkTask {
  @override
  String get id => 'stub';
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
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) =>
      [_AlwaysPassEvaluator()];
}
```

Add the import:

```dart
import 'package:dart_arena/core/evaluator_config.dart';
```

(The full test rewrite — including the prepare-failure case — lands in Task 17.)

- [ ] **Step 5: Run analyzer + smoke tests**

```bash
flutter analyze
flutter test test/runner/run_bloc_test.dart
flutter test test/tasks/off_by_one_pagination_test.dart
```

Expected: analyze clean. The bloc test passes with the minimal shim using the same `_AlwaysPassEvaluator` behavior as before. The off-by-one test still works because `loadAssets()` ran successfully and the metadata assertions all hold under the new interface.

If the off-by-one test references the old `task.evaluators` getter directly, update that line now to call `task.evaluatorsFor(const EvaluatorConfig())`. (Task 15 rewrites this test entirely; for this step, just make it compile.)

- [ ] **Step 6: Commit**

```bash
git add lib/core/benchmark_task.dart lib/tasks/bug_fix/off_by_one_pagination.dart lib/runner/run_bloc.dart test/runner/run_bloc_test.dart
git commit -m "feat(core): BenchmarkTask.evaluatorsFor(EvaluatorConfig) + generatedCodePath (interface change with minimal shim)"
```

---

## Task 8: Slim `CompileEvaluator` to `dart analyze --fatal-infos`

**Files:**
- Modify: `lib/evaluators/compile_evaluator.dart`
- Modify: `test/evaluators/compile_evaluator_test.dart`

- [ ] **Step 1: Replace `lib/evaluators/compile_evaluator.dart`**

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
    final analyze = await Process.run(
      'dart',
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
      },
    );
  }
}
```

- [ ] **Step 2: Update `test/evaluators/compile_evaluator_test.dart`**

The existing test calls `CompileEvaluator().evaluate(...)` directly without running `prepare`. Now that pub-get lives elsewhere, the test must run prepare first. Replace the entire file with:

```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _DummyTask extends BenchmarkTask {
  @override
  String get id => 'dummy';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/tmp.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<EvaluationContext> _ctx(Directory dir) async => EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _DummyTask(),
    );

void main() {
  test('passes for clean Dart code', () async {
    final root = await Directory.systemTemp.createTemp('dart_arena_compile_');
    final dir = Directory(p.join(root.path, 'pkg'))..createSync();
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart'))
        .writeAsStringSync('int answer() => 42;\n');

    expect(
      await WorkdirManager(root: root).prepare(dir),
      isA<PrepareOk>(),
    );
    final result = await CompileEvaluator().evaluate(await _ctx(dir));
    expect(result.passed, isTrue);
    expect(result.score, 1.0);

    root.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('fails for code with syntax errors', () async {
    final root =
        await Directory.systemTemp.createTemp('dart_arena_compile_bad_');
    final dir = Directory(p.join(root.path, 'pkg'))..createSync();
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart'))
        .writeAsStringSync('int answer( => 42;');

    expect(
      await WorkdirManager(root: root).prepare(dir),
      isA<PrepareOk>(),
    );
    final result = await CompileEvaluator().evaluate(await _ctx(dir));
    expect(result.passed, isFalse);
    expect(result.score, 0.0);

    root.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

This test uses Task 7's `BenchmarkTask` interface (`evaluatorsFor` and `generatedCodePath`) and Task 3's `EvaluatorConfig` — both already in place.

- [ ] **Step 3: Run tests, verify pass**

```bash
flutter test test/evaluators/compile_evaluator_test.dart
```

Expected: PASS for both cases (slow — runs `dart pub get` in temp dirs).

- [ ] **Step 4: Commit**

```bash
git add lib/evaluators/compile_evaluator.dart test/evaluators/compile_evaluator_test.dart
git commit -m "refactor(evaluators): slim CompileEvaluator to fatal-infos analyze; pub get lives in WorkdirManager"
```

---

## Task 9: `_test_reporter_parser.dart` — shared JSON event parser

**Files:**
- Create: `lib/evaluators/_test_reporter_parser.dart`

There's no separate test for this helper — it's exercised through `TestEvaluator` and `WidgetTreeEvaluator` in Tasks 11 and 12.

- [ ] **Step 1: Implement**

`lib/evaluators/_test_reporter_parser.dart`:
```dart
import 'dart:convert';

class TestReportSummary {
  TestReportSummary({
    required this.total,
    required this.passed,
    required this.failed,
    required this.errored,
    required this.failures,
  });

  final int total;
  final int passed;
  final int failed;
  final int errored;
  final List<Map<String, String>> failures;

  double get score => total == 0 ? 0.0 : passed / total;
  bool get allPassed => total > 0 && failed == 0 && errored == 0;
}

TestReportSummary parseTestReporterJson(String stdout) {
  final tests = <int, String>{};
  var passed = 0;
  var failed = 0;
  var errored = 0;
  final failures = <Map<String, String>>[];

  for (final line in const LineSplitter().convert(stdout)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
    final Map<String, dynamic> evt;
    try {
      evt = jsonDecode(trimmed) as Map<String, dynamic>;
    } on FormatException {
      continue;
    }

    final type = evt['type'] as String?;
    if (type == 'testStart') {
      final test = evt['test'] as Map<String, dynamic>?;
      final id = test?['id'] as int?;
      final name = test?['name'] as String? ?? '';
      if (id != null) tests[id] = name;
    } else if (type == 'testDone') {
      final hidden = evt['hidden'] as bool? ?? false;
      if (hidden) continue;
      final result = evt['result'] as String?;
      final id = evt['testID'] as int?;
      final name = id != null ? (tests[id] ?? '') : '';
      switch (result) {
        case 'success':
          passed++;
        case 'failure':
          failed++;
          failures.add({'name': name, 'message': 'failure'});
        case 'error':
          errored++;
          failures.add({'name': name, 'message': 'error'});
      }
    } else if (type == 'error') {
      final id = evt['testID'] as int?;
      final name = id != null ? (tests[id] ?? '') : '';
      final msg = (evt['error'] as String?) ?? '';
      failures.add({
        'name': name,
        'message': msg.length > 200 ? msg.substring(0, 200) : msg,
      });
    }
  }

  final total = passed + failed + errored;
  return TestReportSummary(
    total: total,
    passed: passed,
    failed: failed,
    errored: errored,
    failures: failures,
  );
}
```

- [ ] **Step 2: Verify it analyzes cleanly**

```bash
flutter analyze lib/evaluators/_test_reporter_parser.dart
```

Expected: no issues for this file.

- [ ] **Step 3: Commit**

```bash
git add lib/evaluators/_test_reporter_parser.dart
git commit -m "feat(evaluators): add shared JSON test reporter parser"
```

---

## Task 10: `AnalyzeEvaluator`

**Files:**
- Create: `lib/evaluators/analyze_evaluator.dart`
- Test: `test/evaluators/analyze_evaluator_test.dart`

- [ ] **Step 1: Failing test**

`test/evaluators/analyze_evaluator_test.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _DummyTask extends BenchmarkTask {
  @override
  String get id => 'dummy';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/tmp.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<Directory> _scaffold(String fileContents) async {
  final root = await Directory.systemTemp.createTemp('dart_arena_analyze_');
  final dir = Directory(p.join(root.path, 'pkg'))..createSync();
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
  Directory(p.join(dir.path, 'lib')).createSync();
  File(p.join(dir.path, 'lib', 'tmp.dart')).writeAsStringSync(fileContents);
  await WorkdirManager(root: root).prepare(dir);
  return dir;
}

EvaluationContext _ctx(Directory dir) => EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _DummyTask(),
    );

void main() {
  test('clean code scores 1.0 and passes', () async {
    final dir = await _scaffold('int answer() => 42;\n');
    final r = await AnalyzeEvaluator().evaluate(_ctx(dir));
    expect(r.passed, isTrue);
    expect(r.score, 1.0);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('code with errors scores 0.0 and fails', () async {
    final dir = await _scaffold('int answer( => 42;');
    final r = await AnalyzeEvaluator().evaluate(_ctx(dir));
    expect(r.passed, isFalse);
    expect(r.score, 0.0);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('warning-only code scores between 0 and 1', () async {
    // Unused variable typically triggers an "info" diagnostic.
    final dir = await _scaffold('''
int answer() {
  final x = 1;
  return 42;
}
''');
    final r = await AnalyzeEvaluator().evaluate(_ctx(dir));
    expect(r.passed, isTrue);
    expect(r.score, lessThan(1.0));
    expect(r.score, greaterThan(0.0));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/evaluators/analyze_evaluator_test.dart
```

Expected: FAIL — `analyze_evaluator.dart` not present.

- [ ] **Step 3: Implement**

`lib/evaluators/analyze_evaluator.dart`:
```dart
import 'dart:io';
import 'dart:math' as math;

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class AnalyzeEvaluator implements Evaluator {
  @override
  String get id => 'analyze';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final res = await Process.run(
      'dart',
      ['analyze'],
      workingDirectory: ctx.workDir.path,
    );
    final stdout = res.stdout.toString();
    final counts = _countSeverities(stdout);

    if (counts.errors > 0) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale:
            'errors=${counts.errors} warnings=${counts.warnings} infos=${counts.infos}',
        details: {
          'errors': counts.errors,
          'warnings': counts.warnings,
          'infos': counts.infos,
          'raw_stdout': stdout,
        },
      );
    }

    final score =
        math.max(0.0, 1.0 - 0.10 * counts.warnings - 0.02 * counts.infos);
    final clamped = score.clamp(0.0, 1.0);
    return EvaluationResult(
      evaluatorId: id,
      passed: true,
      score: clamped,
      rationale:
          'errors=0 warnings=${counts.warnings} infos=${counts.infos}',
      details: {
        'errors': 0,
        'warnings': counts.warnings,
        'infos': counts.infos,
        'raw_stdout': stdout,
      },
    );
  }

  _Counts _countSeverities(String stdout) {
    var errors = 0, warnings = 0, infos = 0;
    final errorRe = RegExp(r'(?im)^\s*error\b');
    final warningRe = RegExp(r'(?im)^\s*warning\b');
    final infoRe = RegExp(r'(?im)^\s*info\b');
    errors = errorRe.allMatches(stdout).length;
    warnings = warningRe.allMatches(stdout).length;
    infos = infoRe.allMatches(stdout).length;
    return _Counts(errors: errors, warnings: warnings, infos: infos);
  }
}

class _Counts {
  const _Counts({
    required this.errors,
    required this.warnings,
    required this.infos,
  });

  final int errors;
  final int warnings;
  final int infos;
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/evaluators/analyze_evaluator_test.dart
```

Note: the warning-test relies on `dart analyze` reporting at least one info diagnostic for an unused local. If that diagnostic stops being emitted by future SDKs, adjust the fixture to a more durable trigger (e.g. `// ignore: unused_element`).

- [ ] **Step 5: Commit**

```bash
git add lib/evaluators/analyze_evaluator.dart test/evaluators/analyze_evaluator_test.dart
git commit -m "feat(evaluators): add graded AnalyzeEvaluator"
```

---

## Task 11: `TestEvaluator`

**Files:**
- Create: `lib/evaluators/test_evaluator.dart`
- Test: `test/evaluators/test_evaluator_test.dart`

- [ ] **Step 1: Failing test**

`test/evaluators/test_evaluator_test.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _DummyTask extends BenchmarkTask {
  @override
  String get id => 'dummy';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/tmp.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<Directory> _scaffold({
  required String libContents,
  required String testContents,
}) async {
  final root = await Directory.systemTemp.createTemp('dart_arena_test_eval_');
  final dir = Directory(p.join(root.path, 'pkg'))..createSync();
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
  Directory(p.join(dir.path, 'lib')).createSync();
  File(p.join(dir.path, 'lib', 'tmp.dart')).writeAsStringSync(libContents);
  Directory(p.join(dir.path, 'test')).createSync();
  File(p.join(dir.path, 'test', 'tmp_test.dart'))
      .writeAsStringSync(testContents);
  await WorkdirManager(root: root).prepare(dir);
  return dir;
}

EvaluationContext _ctx(Directory dir) => EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _DummyTask(),
    );

void main() {
  test('all-pass scores 1.0', () async {
    final dir = await _scaffold(
      libContents: 'int answer() => 42;\n',
      testContents: '''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('a', () { expect(answer(), 42); });
  test('b', () { expect(answer(), 42); });
}
''',
    );
    final r = await TestEvaluator().evaluate(_ctx(dir));
    expect(r.passed, isTrue);
    expect(r.score, 1.0);
    expect(r.details['total'], 2);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('two of three passing scores ~0.667', () async {
    final dir = await _scaffold(
      libContents: 'int answer() => 41;\n',
      testContents: '''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('a', () { expect(answer(), 41); });
  test('b', () { expect(answer(), 42); });
  test('c', () { expect(answer(), 41); });
}
''',
    );
    final r = await TestEvaluator().evaluate(_ctx(dir));
    expect(r.passed, isFalse);
    expect(r.score, closeTo(2.0 / 3.0, 1e-6));
    expect(r.details['total'], 3);
    expect(r.details['failed'], 1);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/evaluators/test_evaluator_test.dart
```

- [ ] **Step 3: Implement**

`lib/evaluators/test_evaluator.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/_test_reporter_parser.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class TestEvaluator implements Evaluator {
  @override
  String get id => 'test';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final res = await Process.run(
      'dart',
      ['test', '--reporter=json'],
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
      },
    );
  }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/evaluators/test_evaluator_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/evaluators/test_evaluator.dart test/evaluators/test_evaluator_test.dart
git commit -m "feat(evaluators): add TestEvaluator with fractional scoring"
```

---

## Task 12: `WidgetTreeEvaluator`

**Files:**
- Create: `lib/evaluators/widget_tree_evaluator.dart`
- Test: `test/evaluators/widget_tree_evaluator_test.dart`

- [ ] **Step 1: Failing test**

`test/evaluators/widget_tree_evaluator_test.dart`:
```dart
@Tags(['flutter'])
library;

import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/widget_tree_evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _DummyTask extends BenchmarkTask {
  @override
  String get id => 'dummy';
  @override
  Category get category => Category.uiFromSpec;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/tmp.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

void main() {
  test('passing widget test scores 1.0', () async {
    final root =
        await Directory.systemTemp.createTemp('dart_arena_widget_eval_');
    final dir = Directory(p.join(root.path, 'pkg'))..createSync();
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart')).writeAsStringSync('''
import 'package:flutter/material.dart';

class Greeting extends StatelessWidget {
  const Greeting({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: Scaffold(body: Text('hello')));
}
''');
    Directory(p.join(dir.path, 'test', 'widget')).createSync(recursive: true);
    File(p.join(dir.path, 'test', 'widget', 'greeting_test.dart'))
        .writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmp/tmp.dart';

void main() {
  testWidgets('renders hello', (tester) async {
    await tester.pumpWidget(const Greeting());
    expect(find.text('hello'), findsOneWidget);
  });
}
''');

    expect(
      await WorkdirManager(root: root).prepare(dir),
      isA<PrepareOk>(),
    );
    final r = await WidgetTreeEvaluator().evaluate(EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _DummyTask(),
    ));

    expect(r.passed, isTrue);
    expect(r.score, 1.0);

    root.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/evaluators/widget_tree_evaluator_test.dart
```

- [ ] **Step 3: Implement**

`lib/evaluators/widget_tree_evaluator.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/_test_reporter_parser.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class WidgetTreeEvaluator implements Evaluator {
  WidgetTreeEvaluator({this.testDir = 'test/widget'});

  final String testDir;

  @override
  String get id => 'widget_tree';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final res = await Process.run(
      'flutter',
      ['test', testDir, '--reporter=json'],
      workingDirectory: ctx.workDir.path,
    );
    final summary = parseTestReporterJson(res.stdout.toString());

    return EvaluationResult(
      evaluatorId: id,
      passed: summary.allPassed,
      score: summary.score,
      rationale: summary.total == 0
          ? 'no widget tests found'
          : '${summary.passed}/${summary.total} widget tests passed',
      details: {
        'test_dir': testDir,
        'total': summary.total,
        'passed': summary.passed,
        'failed': summary.failed,
        'errored': summary.errored,
        'failures': summary.failures,
        'exit_code': res.exitCode,
      },
    );
  }
}
```

- [ ] **Step 4: Run, verify pass (slow)**

```bash
flutter test --tags flutter test/evaluators/widget_tree_evaluator_test.dart
```

Expected: PASS (~30-90s including pub get + first flutter test cold start).

- [ ] **Step 5: Commit**

```bash
git add lib/evaluators/widget_tree_evaluator.dart test/evaluators/widget_tree_evaluator_test.dart
git commit -m "feat(evaluators): add WidgetTreeEvaluator using flutter test"
```

---

## Task 13: `LlmJudgeEvaluator`

**Files:**
- Create: `lib/evaluators/llm_judge_evaluator.dart`
- Test: `test/evaluators/llm_judge_evaluator_test.dart`

- [ ] **Step 1: Failing test**

`test/evaluators/llm_judge_evaluator_test.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedJudge implements ModelProvider {
  _ScriptedJudge(this._reply);
  final String _reply;

  @override
  String get id => 'fake_judge';
  @override
  String get displayName => 'Fake Judge';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Future<List<String>> listModels() async => ['j1'];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async =>
      ModelResponse(
        rawText: _reply,
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: const Duration(milliseconds: 1),
      );
}

class _Task extends BenchmarkTask {
  _Task({this.rubric});
  final String? rubric;

  @override
  String get id => 'task';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'fix it';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/tmp.dart';
  @override
  String? get judgeRubric => rubric;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

EvaluationContext _ctx(BenchmarkTask task) => EvaluationContext(
      workDir: Directory.systemTemp,
      response: const ModelResponse(
        rawText: 'submission text',
        extractedCode: 'int x = 0;',
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: task,
    );

void main() {
  test('skips with score 1.0 when task has no rubric', () async {
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge('irrelevant'),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task()));
    expect(r.passed, isTrue);
    expect(r.score, 1.0);
    expect(r.rationale, 'no rubric');
  });

  test('parses fenced JSON happy path', () async {
    final reply = '''
```json
{"score": 0.85, "rationale": "good fix"}
```
''';
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge(reply),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task(rubric: 'be strict')));
    expect(r.score, closeTo(0.85, 1e-9));
    expect(r.passed, isTrue);
    expect(r.rationale, contains('good fix'));
  });

  test('regex fallback recovers a score from unfenced text', () async {
    const reply = 'I think the score: 0.4 because ...';
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge(reply),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task(rubric: 'be strict')));
    expect(r.score, closeTo(0.4, 1e-9));
    expect(r.passed, isFalse);
  });

  test('clamps out-of-range score to [0,1]', () async {
    const reply = '```json\n{"score": 1.7, "rationale": "x"}\n```\n';
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge(reply),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task(rubric: 'r')));
    expect(r.score, 1.0);
  });

  test('returns score 0 when no parseable signal', () async {
    const reply = 'I refuse to judge.';
    final ev = LlmJudgeEvaluator(
      judge: _ScriptedJudge(reply),
      judgeModel: 'j1',
    );
    final r = await ev.evaluate(_ctx(_Task(rubric: 'r')));
    expect(r.score, 0.0);
    expect(r.passed, isFalse);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/evaluators/llm_judge_evaluator_test.dart
```

- [ ] **Step 3: Implement**

`lib/evaluators/llm_judge_evaluator.dart`:
```dart
import 'dart:convert';

import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';

class LlmJudgeEvaluator implements Evaluator {
  LlmJudgeEvaluator({required this.judge, required this.judgeModel});

  final ModelProvider judge;
  final String judgeModel;

  @override
  String get id => 'llm_judge';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final rubric = ctx.task.judgeRubric;
    if (rubric == null) {
      return EvaluationResult(
        evaluatorId: id,
        passed: true,
        score: 1.0,
        rationale: 'no rubric',
        details: const {'skipped': true},
      );
    }

    final submission = ctx.response.extractedCode ?? ctx.response.rawText;
    final prompt = '''
You are a strict code reviewer for Dart/Flutter.

TASK PROMPT:
${ctx.task.prompt}

RUBRIC:
$rubric

SUBMISSION:
```dart
$submission
```

Reply with ONLY a fenced ```json block of the form:
{"score": <number 0.0-1.0>, "rationale": "<short reasoning>"}
''';

    final response = await judge.generate(
      prompt: prompt,
      model: judgeModel,
      timeout: const Duration(seconds: 60),
    );
    final raw = response.rawText;

    final parsed = _parse(raw);
    final score = parsed.score.clamp(0.0, 1.0);

    return EvaluationResult(
      evaluatorId: id,
      passed: score >= 0.5,
      score: score,
      rationale: parsed.rationale,
      details: {
        'raw_judge_response':
            raw.length > 4000 ? raw.substring(0, 4000) : raw,
        'judge_model': judgeModel,
        'judge_provider_id': judge.id,
        'parse_strategy': parsed.strategy,
      },
    );
  }

  _ParsedJudgeReply _parse(String raw) {
    final block = extractJsonBlock(raw);
    if (block != null) {
      try {
        final decoded = jsonDecode(block);
        if (decoded is Map<String, dynamic>) {
          final s = decoded['score'];
          final r = decoded['rationale'];
          if (s is num) {
            return _ParsedJudgeReply(
              score: s.toDouble(),
              rationale: r is String ? r : null,
              strategy: 'json',
            );
          }
        }
      } on Object {
        // fall through to regex
      }
    }

    final scoreRe = RegExp(r'(?i)score[:\s]+([0-9]*\.?[0-9]+)');
    final m = scoreRe.firstMatch(raw);
    if (m != null) {
      final v = double.tryParse(m.group(1)!);
      if (v != null) {
        final r = raw.length > 500 ? raw.substring(0, 500) : raw;
        return _ParsedJudgeReply(
          score: v > 1.0 ? v / 100.0 : v,
          rationale: r,
          strategy: 'regex',
        );
      }
    }

    return _ParsedJudgeReply(score: 0.0, rationale: 'unparseable judge reply', strategy: 'fallback');
  }
}

class _ParsedJudgeReply {
  const _ParsedJudgeReply({
    required this.score,
    required this.rationale,
    required this.strategy,
  });

  final double score;
  final String? rationale;
  final String strategy;
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/evaluators/llm_judge_evaluator_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/evaluators/llm_judge_evaluator.dart test/evaluators/llm_judge_evaluator_test.dart
git commit -m "feat(evaluators): add LlmJudgeEvaluator with JSON+regex parsing"
```

---

## Task 14: `DiffSizeEvaluator`

**Files:**
- Create: `lib/evaluators/diff_size_evaluator.dart`
- Test: `test/evaluators/diff_size_evaluator_test.dart`

- [ ] **Step 1: Failing test**

`test/evaluators/diff_size_evaluator_test.dart`:
```dart
import 'dart:io';
import 'dart:math' as math;

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _original = '''
class A {
  int x() => 1;
  int y() => 2;
  int z() => 3;
}
''';

class _Task extends BenchmarkTask {
  _Task(this._fixtures);
  final Map<String, String> _fixtures;

  @override
  String get id => 'task';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => _fixtures;
  @override
  String get generatedCodePath => 'lib/a.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<EvaluationContext> _ctxWith(String workdirContents) async {
  final dir = await Directory.systemTemp.createTemp('dart_arena_diff_');
  Directory(p.join(dir.path, 'lib')).createSync();
  File(p.join(dir.path, 'lib', 'a.dart')).writeAsStringSync(workdirContents);
  return EvaluationContext(
    workDir: dir,
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    ),
    task: _Task({'lib/a.dart': _original}),
  );
}

void main() {
  test('identical contents score 1.0', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(await _ctxWith(_original));
    expect(r.score, closeTo(1.0, 1e-9));
    expect(r.passed, isTrue);
  });

  test('small diff produces score between 0 and 1', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final modified = _original.replaceFirst('=> 1;', '=> 10;');
    final r = await ev.evaluate(await _ctxWith(modified));
    expect(r.score, lessThan(1.0));
    expect(r.score, greaterThan(0.5));
  });

  test('large diff drives score toward 0', () async {
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final modified =
        List.generate(40, (i) => '// new line $i').join('\n') + '\n';
    final r = await ev.evaluate(await _ctxWith(modified));
    expect(r.score, lessThan(math.exp(-1.0))); // < ~0.37
    expect(r.passed, isFalse);
  });

  test('missing splice file -> score 0', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_diff_miss_');
    final ctx = EvaluationContext(
      workDir: dir,
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      task: _Task({'lib/a.dart': _original}),
    );
    final ev = DiffSizeEvaluator(originalFixturePath: 'lib/a.dart');
    final r = await ev.evaluate(ctx);
    expect(r.score, 0.0);
    expect(r.passed, isFalse);
    expect(r.rationale, contains('missing'));
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/evaluators/diff_size_evaluator_test.dart
```

- [ ] **Step 3: Implement**

`lib/evaluators/diff_size_evaluator.dart`:
```dart
import 'dart:io';
import 'dart:math' as math;

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:path/path.dart' as p;

class DiffSizeEvaluator implements Evaluator {
  DiffSizeEvaluator({required this.originalFixturePath, this.k = 20});

  final String originalFixturePath;
  final int k;

  @override
  String get id => 'diff_size';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final original = ctx.task.fixtures[originalFixturePath];
    final newFile = File(p.join(ctx.workDir.path, originalFixturePath));
    if (original == null || !newFile.existsSync()) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'diff source missing',
        details: {
          'original_present': original != null,
          'new_file_present': newFile.existsSync(),
          'path': originalFixturePath,
        },
      );
    }

    final newContents = await newFile.readAsString();
    final changed = _changedLines(original, newContents);
    final score = math.exp(-changed / k);
    final clamped = score.clamp(0.0, 1.0);

    return EvaluationResult(
      evaluatorId: id,
      passed: clamped >= 0.3,
      score: clamped,
      rationale: 'changed_lines=$changed',
      details: {
        'original_lines': '\n'.allMatches(original).length + 1,
        'new_lines': '\n'.allMatches(newContents).length + 1,
        'changed_lines': changed,
        'score_k': k,
      },
    );
  }

  int _changedLines(String a, String b) {
    final dmp = DiffMatchPatch();
    final aLines = a.split('\n');
    final bLines = b.split('\n');
    final lineMap = <String, String>{};
    final encoded = StringBuffer();
    final aEnc = _encode(aLines, lineMap);
    final bEnc = _encode(bLines, lineMap);
    encoded.write('');

    final diffs = dmp.diff(aEnc, bEnc);
    dmp.diffCleanupSemantic(diffs);

    var changed = 0;
    for (final d in diffs) {
      if (d.operation == DIFF_INSERT || d.operation == DIFF_DELETE) {
        changed += d.text.length;
      }
    }
    return changed;
  }

  String _encode(List<String> lines, Map<String, String> map) {
    final buf = StringBuffer();
    for (final line in lines) {
      final existing = map[line];
      if (existing != null) {
        buf.write(existing);
      } else {
        final code = String.fromCharCode(map.length + 1);
        map[line] = code;
        buf.write(code);
      }
    }
    return buf.toString();
  }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/evaluators/diff_size_evaluator_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/evaluators/diff_size_evaluator.dart test/evaluators/diff_size_evaluator_test.dart
git commit -m "feat(evaluators): add DiffSizeEvaluator with line-level scoring"
```

---

## Task 15: Wire `OffByOnePaginationTask`'s full evaluator set + rubric

**Files:**
- Modify: `lib/tasks/bug_fix/off_by_one_pagination.dart`

- [ ] **Step 1: Replace the evaluators+rubric portion of the file**

Replace the body of `OffByOnePaginationTask` to use all five evaluators (with judge conditional) and provide a non-null rubric:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:flutter/services.dart';

class OffByOnePaginationTask extends BenchmarkTask {
  @override
  String get id => 'bug.off_by_one_pagination';

  @override
  Category get category => Category.bugFix;

  @override
  String get prompt => '''
You are given a Dart class `Paginator<T>` in `lib/pagination.dart` that has off-by-one bugs.
There are tests in `test/pagination_test.dart` that currently fail.

Return ONLY the corrected contents of `lib/pagination.dart` inside a single ```dart fenced block.
Do not include explanatory text outside the block. Do not change the public API.
''';

  @override
  Map<String, String> get fixtures => _fixtures;
  static final Map<String, String> _fixtures = {};

  static Future<void> loadAssets() async {
    if (_fixtures.isNotEmpty) return;
    const base = 'lib/tasks/bug_fix/fixtures/off_by_one_pagination';
    _fixtures['pubspec.yaml'] =
        await rootBundle.loadString('$base/pubspec.yaml');
    _fixtures['lib/pagination.dart'] =
        await rootBundle.loadString('$base/lib/pagination.dart');
    _fixtures['test/pagination_test.dart'] =
        await rootBundle.loadString('$base/test/pagination_test.dart');
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

- [ ] **Step 2: Update existing task test**

Open `test/tasks/off_by_one_pagination_test.dart`. Replace its body so it uses the new interface:

```dart
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OffByOnePaginationTask metadata', () async {
    await OffByOnePaginationTask.loadAssets();
    final task = OffByOnePaginationTask();
    expect(task.id, 'bug.off_by_one_pagination');
    expect(task.category, Category.bugFix);
    expect(task.generatedCodePath, 'lib/pagination.dart');
    expect(task.judgeRubric, isNotNull);
    expect(task.fixtures.keys, contains('lib/pagination.dart'));
  });

  test('evaluatorsFor without judge returns 4 evaluators', () {
    final task = OffByOnePaginationTask();
    final evs = task.evaluatorsFor(const EvaluatorConfig());
    expect(evs, hasLength(4));
    expect(
      evs.map((e) => e.id).toList(),
      ['compile', 'analyze', 'test', 'diff_size'],
    );
  });
}
```

- [ ] **Step 3: Run task test**

```bash
flutter test test/tasks/off_by_one_pagination_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/tasks/bug_fix/off_by_one_pagination.dart test/tasks/off_by_one_pagination_test.dart
git commit -m "feat(tasks): wire full evaluator set + judge rubric for OffByOnePaginationTask"
```

---

## Task 16: `RunEvent.StartRun` carries `EvaluatorConfig`

**Files:**
- Modify: `lib/runner/run_event.dart`

- [ ] **Step 1: Replace `lib/runner/run_event.dart`**

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:equatable/equatable.dart';

sealed class RunEvent extends Equatable {
  const RunEvent();
  @override
  List<Object?> get props => [];
}

class StartRun extends RunEvent {
  const StartRun({
    required this.tasks,
    required this.providers,
    required this.modelByProvider,
    required this.evaluatorConfig,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, String> modelByProvider;
  final EvaluatorConfig evaluatorConfig;
}

class CancelRun extends RunEvent {
  const CancelRun();
}
```

- [ ] **Step 2: Verify the file compiles standalone**

```bash
flutter analyze lib/runner/run_event.dart
```

(Other files using `StartRun` will fail until Task 17 — that's expected.)

- [ ] **Step 3: Commit**

```bash
git add lib/runner/run_event.dart
git commit -m "feat(runner): StartRun event carries EvaluatorConfig"
```

---

## Task 17: `RunBloc` integration

**Files:**
- Modify: `lib/runner/run_bloc.dart`
- Modify: `test/runner/run_bloc_test.dart`

- [ ] **Step 1: Replace `lib/runner/run_bloc.dart`**

```dart
import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RunBloc extends Bloc<RunEvent, RunState> {
  RunBloc({
    required this.workdirManager,
    required this.runDao,
    required this.now,
    required this.idGenerator,
    this.weights = defaultEvaluatorWeights,
  }) : super(const RunIdle()) {
    on<StartRun>(_onStart);
  }

  final WorkdirManager workdirManager;
  final RunDao runDao;
  final DateTime Function() now;
  final String Function() idGenerator;
  final Map<String, double> weights;

  Future<void> _onStart(StartRun event, Emitter<RunState> emit) async {
    final runId = idGenerator();
    final total = event.tasks.length * event.providers.length;
    var completed = 0;
    final results = <TaskRunResult>[];

    await runDao.startRun(runId: runId, startedAt: now());
    emit(RunInProgress(
      runId: runId,
      completed: 0,
      total: total,
      results: const [],
    ));

    try {
      for (final task in event.tasks) {
        for (final provider in event.providers) {
          final modelId = event.modelByProvider[provider.id]!;
          emit(RunInProgress(
            runId: runId,
            completed: completed,
            total: total,
            results: List.unmodifiable(results),
            currentLabel: '${provider.displayName} on ${task.id}',
          ));

          final response = await provider.generate(
            prompt: task.prompt,
            model: modelId,
          );
          final extracted =
              extractDartCode(response.rawText) ?? response.rawText;
          final responseWithCode = _copyWithCode(response, extracted);

          emit(RunInProgress(
            runId: runId,
            completed: completed,
            total: total,
            results: List.unmodifiable(results),
            currentLabel:
                'Evaluating ${provider.displayName} on ${task.id}…',
            currentRawResponse: response.rawText,
          ));

          final dir = await workdirManager.createTaskWorkdir(
            runId: runId,
            providerId: provider.id,
            modelId: modelId,
            taskId: task.id,
            fixtures: task.fixtures,
            generatedCode: extracted,
            generatedCodePath: task.generatedCodePath,
          );

          final evaluators = task.evaluatorsFor(event.evaluatorConfig);
          final prepResult = await workdirManager.prepare(dir);
          final evaluations = <EvaluationResult>[];

          if (prepResult is PrepareFailed) {
            for (final evaluator in evaluators) {
              evaluations.add(EvaluationResult(
                evaluatorId: evaluator.id,
                passed: false,
                score: 0.0,
                rationale: 'prepare failed',
                details: {'stderr': prepResult.stderr},
              ));
            }
          } else {
            for (final evaluator in evaluators) {
              final result = await evaluator.evaluate(
                EvaluationContext(
                  workDir: dir,
                  response: responseWithCode,
                  task: task,
                ),
              );
              evaluations.add(result);
            }
          }

          final aggregateScore = aggregate(evaluations, weights);

          final taskResult = TaskRunResult(
            runId: runId,
            providerId: provider.id,
            modelId: modelId,
            taskId: task.id,
            response: responseWithCode,
            evaluations: evaluations,
            aggregateScore: aggregateScore,
            completedAt: now(),
          );
          results.add(taskResult);
          await runDao.persistTaskRun(taskResult);
          completed++;
          emit(RunInProgress(
            runId: runId,
            completed: completed,
            total: total,
            results: List.unmodifiable(results),
          ));
        }
      }
      await runDao.finishRun(runId, now());
      emit(RunCompleted(runId: runId, results: List.unmodifiable(results)));
    } catch (e, _) {
      emit(RunFailed(e.toString()));
    }
  }
}

ModelResponse _copyWithCode(ModelResponse r, String? code) => ModelResponse(
      rawText: r.rawText,
      extractedCode: code,
      promptTokens: r.promptTokens,
      completionTokens: r.completionTokens,
      latency: r.latency,
    );
```

- [ ] **Step 2: Replace `test/runner/run_bloc_test.dart`**

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
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProvider implements ModelProvider {
  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<String>> listModels() async => ['fake-1'];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async =>
      const ModelResponse(
        rawText: '```dart\nint answer() => 42;\n```',
        extractedCode: null,
        promptTokens: 1,
        completionTokens: 2,
        latency: Duration(milliseconds: 1),
      );
}

class _AlwaysPass implements Evaluator {
  @override
  String get id => 'pass';
  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async =>
      const EvaluationResult(evaluatorId: 'pass', passed: true, score: 1.0);
}

class _StubTask extends BenchmarkTask {
  @override
  String get id => 'stub';
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
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [_AlwaysPass()];
}

class _BrokenPubspecTask extends _StubTask {
  @override
  Map<String, String> get fixtures => const {
        'pubspec.yaml': 'this is not valid pubspec yaml: : :\n',
      };
}

void main() {
  test('happy path emits RunCompleted with aggregate 1.0', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_ok_');
    final db = AppDatabase(NativeDatabase.memory());
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-test',
    );

    final completedFuture = bloc.stream
        .firstWhere((s) => s is RunCompleted)
        .timeout(const Duration(minutes: 2));

    bloc.add(StartRun(
      tasks: [_StubTask()],
      providers: [_FakeProvider()],
      modelByProvider: const {'fake': 'fake-1'},
      evaluatorConfig: const EvaluatorConfig(),
    ));

    final completed = await completedFuture as RunCompleted;
    expect(completed.results.first.aggregateScore, 1.0);

    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('prepare failure produces synthetic per-evaluator results',
      () async {
    final tmp =
        await Directory.systemTemp.createTemp('dart_arena_bloc_prep_');
    final db = AppDatabase(NativeDatabase.memory());
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-test',
    );

    final completedFuture = bloc.stream
        .firstWhere((s) => s is RunCompleted)
        .timeout(const Duration(minutes: 2));

    bloc.add(StartRun(
      tasks: [_BrokenPubspecTask()],
      providers: [_FakeProvider()],
      modelByProvider: const {'fake': 'fake-1'},
      evaluatorConfig: const EvaluatorConfig(),
    ));

    final completed = await completedFuture as RunCompleted;
    final r = completed.results.single;
    expect(r.evaluations, hasLength(1));
    expect(r.evaluations.single.passed, isFalse);
    expect(r.evaluations.single.rationale, 'prepare failed');
    expect(r.aggregateScore, 0.0);

    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

- [ ] **Step 3: Run, verify pass**

```bash
flutter test test/runner/run_bloc_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/runner/run_bloc.dart test/runner/run_bloc_test.dart
git commit -m "feat(runner): RunBloc uses prepare step + EvaluatorConfig + weighted aggregate"
```

---

## Task 18: Settings page — Judge Model section

**Files:**
- Modify: `lib/ui/pages/settings_page.dart`

The current Settings page has per-provider sections from Plan 2. We add a Judge Model section above or below them.

- [ ] **Step 1: Read current page to know where to splice**

```bash
flutter analyze lib/ui/pages/settings_page.dart
```

(No code change yet — just orient.)

- [ ] **Step 2: Add a `_JudgeSection` widget and embed it in the page**

Insert this widget near the top of `lib/ui/pages/settings_page.dart` (above the provider sections):

```dart
class _JudgeSection extends StatefulWidget {
  const _JudgeSection({required this.providers});
  final List<String> providers;

  @override
  State<_JudgeSection> createState() => _JudgeSectionState();
}

class _JudgeSectionState extends State<_JudgeSection> {
  final _repo = SettingsRepository();
  final _modelController = TextEditingController();
  String? _providerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = await _repo.getJudgeProviderId();
    final mid = await _repo.getJudgeModelId();
    setState(() {
      _providerId = pid;
      _modelController.text = mid ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Judge Model',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: widget.providers.contains(_providerId)
                  ? _providerId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Judge provider',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('(none — disable judge)'),
                ),
                ...widget.providers.map(
                  (p) => DropdownMenuItem<String?>(value: p, child: Text(p)),
                ),
              ],
              onChanged: (v) => setState(() => _providerId = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Judge model id',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await _repo.setJudgeProviderId(_providerId);
                await _repo.setJudgeModelId(
                  _modelController.text.trim().isEmpty
                      ? null
                      : _modelController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Judge saved')),
                  );
                }
              },
              child: const Text('Save judge'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Then in the page's main `build` method (the part where provider sections are rendered), add `_JudgeSection(providers: <list of provider ids>)` near the top of the column. The exact insertion point depends on the existing structure from Plan 2 — locate the `ListView`/`Column` containing provider sections and insert this widget as the first child, computing the `providers` list from the same data Plan 2 already loads. If the page uses async loading of enabled providers, pass that list down.

If you don't already have an explicit list of provider ids, hardcode the canonical 8:

```dart
const _knownProviderIds = <String>[
  'ollama_local',
  'ollama_cloud',
  'opencode_zen',
  'openai',
  'openrouter',
  'deepseek',
  'anthropic',
  'droid',
];
// then: _JudgeSection(providers: _knownProviderIds)
```

- [ ] **Step 3: Make sure imports include `SettingsRepository` (already present from Plan 2)**

- [ ] **Step 4: Smoke build**

```bash
flutter analyze lib/ui/pages/settings_page.dart
flutter build linux --debug
```

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/settings_page.dart
git commit -m "feat(ui): add Judge Model section to Settings page"
```

---

## Task 19: NewRunPage passes `EvaluatorConfig` and weights through the runner

**Files:**
- Modify: `lib/ui/pages/new_run_page.dart`

- [ ] **Step 1: Update `_startRun` to read judge + evaluator weights from settings**

Locate the `_startRun()` method. Before constructing `RunBloc`, read settings:

```dart
final settings = SettingsRepository();
final evaluatorWeights = await settings.getEvaluatorWeights();
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
```

Then pass `weights: evaluatorWeights` to the `RunBloc(...)` constructor:

```dart
final bloc = RunBloc(
  workdirManager: WorkdirManager(root: root),
  runDao: RunDao(db),
  now: () => DateTime.now(),
  idGenerator: () =>
      'run-${DateTime.now().millisecondsSinceEpoch}',
  weights: evaluatorWeights,
);
```

Also add the imports at the top of the file:

```dart
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/storage/settings.dart';
```

(The Settings import may already exist.)

Update the `bloc.add(StartRun(...))` invocation to include `evaluatorConfig: evaluatorConfig`:

```dart
bloc.add(StartRun(
  tasks: [OffByOnePaginationTask()],
  providers: selected,
  modelByProvider: modelMap,
  evaluatorConfig: evaluatorConfig,
));
```

- [ ] **Step 2: Smoke build**

```bash
flutter analyze
flutter build linux --debug
```

Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pages/new_run_page.dart
git commit -m "feat(ui): NewRunPage threads EvaluatorConfig and weights into runs"
```

---

## Task 20: Full test sweep + manual smoke

- [ ] **Step 1: Run the entire suite**

```bash
flutter analyze
flutter test
flutter test --tags flutter
```

Expected: everything green. Address any straggler analyzer issues (likely missing imports).

- [ ] **Step 2: Manual smoke (Ollama Local + judge)**

1. Set Ollama base URL in Settings (Plan 1 functionality).
2. In Settings, select a Judge provider (e.g. `ollama_local`) and judge model id (e.g. `qwen2.5-coder:7b`). Save.
3. Go to New Run, pick `ollama_local` + the same model. Click Run.
4. On Run Progress, expect a `RunCompleted` state with one `TaskRunResult` whose `evaluations` list has **5 entries**: `compile`, `analyze`, `test`, `llm_judge`, `diff_size`.
5. Verify aggregate is non-zero and reflects per-evaluator scores.

- [ ] **Step 3: Verify persistence**

```bash
sqlite3 ~/.local/share/dart_arena/dart_arena.sqlite \
  "select evaluator_id, passed, score, rationale from evaluations \
   where task_run_id like 'run-%' order by id desc limit 10;"
```

Expected: 5 rows for the most recent run, one per evaluator.

- [ ] **Step 4: Final commit (only if smoke surfaced fixes)**

If the smoke surfaced bugs, fix them in small commits. Otherwise, no-op.

---

## Done criteria for Plan 3

- `flutter analyze` clean (strict-casts/strict-inference still on).
- `flutter test` passes all tests (existing + new evaluator/scoring suites + extended bloc tests).
- `flutter test --tags flutter` passes (`WidgetTreeEvaluator` integration test).
- Manual smoke run on `bug.off_by_one_pagination` produces a `TaskRunResult` with 5 `EvaluationResult`s when a judge is configured (4 otherwise) and a non-zero weighted aggregate score.
- Settings page persists judge provider + model across app restarts.
- All commits land on `master`.

---

## Self-review notes

- Spec coverage: §3 (architecture) → Tasks 6, 17. §3.3 (scoring) → Task 2. §3.4 (interface evolution) → Tasks 3, 8. §4 (5 evaluators) → Tasks 9, 10, 11, 12, 13, 14. §5 (CompileEvaluator slim) → Task 7. §6 (Settings & UI) → Tasks 5, 18, 19. §7 (storage no schema change) → covered by absence. §8 (testing) → tests interleaved into each task.
- No placeholders.
- Type signatures consistent: `EvaluatorConfig` constructor names match across all tasks; `aggregate(results, weights)` and `defaultEvaluatorWeights` match across `scoring.dart` and `RunBloc`; `BenchmarkTask.evaluatorsFor` signature consistent in interface and all implementers/test stubs.

## Future plans (after Plan 3)

### Plan 4: Tasks + multi-task UI + dashboards
- 9 new tasks across the 5 categories (ui.profile_card, ui.expandable_list_tile, state.counter_bloc, state.shopping_cart_bloc, bug.async_race_condition, refactor.god_widget, refactor.callback_hell, test.todo_input, test.form_validation).
- Multi-task selection on NewRunPage (pick subset by category).
- Dashboard (recent runs, top model per category).
- Leaderboard (`fl_chart` bars/radars, filters).
- RunDetails page (raw output, evaluator breakdown, judge rationale, diff view).
- Evaluator-weights editor in Settings.
