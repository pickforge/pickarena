# dart_arena — Plan 1: Foundation + First End-to-End Slice

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the dart_arena Flutter desktop app and ship a working end-to-end slice: from clicking "New Run" with one selected model (Ollama Local) and one task (off-by-one pagination bug fix), through executing a `CompileEvaluator`, to persisting and viewing the result.

**Architecture:** Flutter desktop (Linux primary) using flutter_bloc, drift (SQLite), dio (HTTP), flutter_secure_storage. Layered by responsibility: `core/`, `providers/`, `tasks/`, `evaluators/`, `runner/`, `storage/`, `ui/`. Each provider/evaluator/task is a small file conforming to a tight interface, registered into a runtime registry.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, flutter_bloc, drift, dio, flutter_secure_storage, path, path_provider, equatable, build_runner, drift_dev, mocktail (tests).

---

## File map (this plan)

Created in this plan:

- `pubspec.yaml` — package manifest
- `analysis_options.yaml` — lints
- `lib/main.dart` — entry point
- `lib/app.dart` — root MaterialApp
- `lib/core/category.dart` — `Category` enum
- `lib/core/benchmark_task.dart` — `BenchmarkTask` abstract class
- `lib/core/model_response.dart` — `ModelResponse` value object
- `lib/core/evaluation_result.dart` — `EvaluationResult` value object
- `lib/core/task_run_result.dart` — `TaskRunResult` value object
- `lib/core/evaluation_context.dart` — `EvaluationContext` value object
- `lib/core/task_registry.dart` — global task registry
- `lib/core/code_extractor.dart` — extracts Dart code blocks from raw model output
- `lib/providers/model_provider.dart` — `ModelProvider` interface
- `lib/providers/ollama_provider.dart` — Ollama (local + cloud) implementation
- `lib/providers/provider_registry.dart` — runtime provider registry
- `lib/tasks/bug_fix/off_by_one_pagination.dart` — first task definition
- `lib/tasks/bug_fix/fixtures/off_by_one_pagination/lib/pagination.dart` — broken source
- `lib/tasks/bug_fix/fixtures/off_by_one_pagination/test/pagination_test.dart` — failing test the model must make pass
- `lib/tasks/bug_fix/fixtures/off_by_one_pagination/pubspec.yaml` — fixture pubspec
- `lib/evaluators/evaluator.dart` — `Evaluator` interface
- `lib/evaluators/compile_evaluator.dart` — runs `dart pub get && dart analyze && dart test`
- `lib/runner/workdir_manager.dart` — creates and tears down workdirs
- `lib/runner/run_event.dart` / `run_state.dart` / `run_bloc.dart` — Bloc lifecycle
- `lib/storage/database.dart` — Drift database + tables
- `lib/storage/dao/run_dao.dart` — DAO for runs/task_runs/evaluations
- `lib/ui/theme.dart` — Material theme
- `lib/ui/pages/home_page.dart`
- `lib/ui/pages/settings_page.dart`
- `lib/ui/pages/new_run_page.dart`
- `lib/ui/pages/run_progress_page.dart`
- `lib/ui/pages/run_details_page.dart`
- `test/...` matching tests for each unit

---

## Task 1: Scaffold Flutter project

**Files:**
- Create: project at `/home/dev/Development/Personal/dart_arena` (project root files)

- [ ] **Step 1: Run `flutter create` over the existing directory**

Run from inside the existing dart_arena dir (which already has docs/ and .git/):

```bash
cd /home/dev/Development/Personal/dart_arena
flutter create --project-name dart_arena --platforms=linux,macos,windows --org com.elberte .
```

Expected: creates `lib/`, `test/`, `linux/`, `macos/`, `windows/`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore` etc. without removing `docs/` or `.git/`.

- [ ] **Step 2: Verify Linux desktop is enabled and project builds**

```bash
flutter config --enable-linux-desktop
flutter doctor -v
flutter build linux --debug
```

Expected: build succeeds, output binary at `build/linux/x64/debug/bundle/dart_arena`.

- [ ] **Step 3: Commit scaffold**

```bash
git add .
git commit -m "chore: scaffold Flutter desktop project"
```

---

## Task 2: Add dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Replace dependencies block in pubspec.yaml**

Replace the existing `dependencies:` and `dev_dependencies:` sections with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5
  dio: ^5.7.0
  drift: ^2.20.3
  sqlite3_flutter_libs: ^0.5.24
  flutter_secure_storage: ^9.2.2
  path: ^1.9.0
  path_provider: ^2.1.4
  go_router: ^14.6.2
  fl_chart: ^0.69.0
  flutter_highlight: ^0.7.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.13
  drift_dev: ^2.20.3
  mocktail: ^1.0.4
```

- [ ] **Step 2: Fetch dependencies**

```bash
flutter pub get
```

Expected: no errors. If any package needs a different SDK constraint, adjust `environment.sdk` to `'>=3.5.0 <4.0.0'` in pubspec.yaml.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add core dependencies"
```

---

## Task 3: Lint configuration

**Files:**
- Modify: `analysis_options.yaml`

- [ ] **Step 1: Replace analysis_options.yaml contents**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "lib/storage/database.g.dart"
    - "**/*.g.dart"
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - prefer_single_quotes
    - require_trailing_commas
    - avoid_print
    - prefer_const_constructors
    - prefer_final_locals
```

- [ ] **Step 2: Run analyze, expect clean**

```bash
flutter analyze
```

Expected: "No issues found!" (the default `lib/main.dart` may need a trailing comma; if so, fix it before committing).

- [ ] **Step 3: Commit**

```bash
git add analysis_options.yaml lib/main.dart
git commit -m "chore: configure lints"
```

---

## Task 4: Core domain types — Category, ModelResponse, EvaluationResult

**Files:**
- Create: `lib/core/category.dart`
- Create: `lib/core/model_response.dart`
- Create: `lib/core/evaluation_result.dart`
- Test: `test/core/model_response_test.dart`

- [ ] **Step 1: Write failing test for ModelResponse equality**

`test/core/model_response_test.dart`:
```dart
import 'package:dart_arena/core/model_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelResponse', () {
    test('values with same fields are equal', () {
      const a = ModelResponse(
        rawText: 'hi',
        extractedCode: null,
        promptTokens: 1,
        completionTokens: 2,
        latency: Duration(milliseconds: 10),
      );
      const b = ModelResponse(
        rawText: 'hi',
        extractedCode: null,
        promptTokens: 1,
        completionTokens: 2,
        latency: Duration(milliseconds: 10),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

```bash
flutter test test/core/model_response_test.dart
```

Expected: FAIL — ModelResponse undefined.

- [ ] **Step 3: Implement Category**

`lib/core/category.dart`:
```dart
enum Category {
  uiFromSpec,
  stateManagement,
  bugFix,
  refactor,
  widgetTesting;

  String get label => switch (this) {
        Category.uiFromSpec => 'UI from spec',
        Category.stateManagement => 'State management',
        Category.bugFix => 'Bug fix',
        Category.refactor => 'Refactor',
        Category.widgetTesting => 'Widget testing',
      };
}
```

- [ ] **Step 4: Implement ModelResponse**

`lib/core/model_response.dart`:
```dart
import 'package:equatable/equatable.dart';

class ModelResponse extends Equatable {
  const ModelResponse({
    required this.rawText,
    required this.extractedCode,
    required this.promptTokens,
    required this.completionTokens,
    required this.latency,
  });

  final String rawText;
  final String? extractedCode;
  final int? promptTokens;
  final int? completionTokens;
  final Duration latency;

  @override
  List<Object?> get props => [
        rawText,
        extractedCode,
        promptTokens,
        completionTokens,
        latency,
      ];
}
```

- [ ] **Step 5: Implement EvaluationResult**

`lib/core/evaluation_result.dart`:
```dart
import 'package:equatable/equatable.dart';

class EvaluationResult extends Equatable {
  const EvaluationResult({
    required this.evaluatorId,
    required this.passed,
    required this.score,
    this.rationale,
    this.details = const {},
  });

  final String evaluatorId;
  final bool passed;
  final double score;
  final String? rationale;
  final Map<String, dynamic> details;

  @override
  List<Object?> get props => [evaluatorId, passed, score, rationale, details];
}
```

- [ ] **Step 6: Re-run test, verify pass**

```bash
flutter test test/core/model_response_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core test/core/model_response_test.dart
git commit -m "feat(core): add Category, ModelResponse, EvaluationResult"
```

---

## Task 5: Core domain — BenchmarkTask, EvaluationContext, TaskRunResult, TaskRegistry

**Files:**
- Create: `lib/core/benchmark_task.dart`
- Create: `lib/core/evaluation_context.dart`
- Create: `lib/core/task_run_result.dart`
- Create: `lib/core/task_registry.dart`
- Test: `test/core/task_registry_test.dart`

- [ ] **Step 1: Write failing test for TaskRegistry**

`test/core/task_registry_test.dart`:
```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubTask extends BenchmarkTask {
  @override
  String get id => 'stub.one';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'do nothing';
  @override
  Map<String, String> get fixtures => const {};
  @override
  List<Evaluator> get evaluators => const [];
  @override
  String? get judgeRubric => null;
}

void main() {
  test('register and lookup', () {
    final registry = TaskRegistry();
    registry.register(_StubTask());
    expect(registry.byId('stub.one'), isA<_StubTask>());
    expect(registry.byCategory(Category.bugFix), hasLength(1));
  });

  test('duplicate id throws', () {
    final registry = TaskRegistry();
    registry.register(_StubTask());
    expect(() => registry.register(_StubTask()), throwsStateError);
  });
}
```

- [ ] **Step 2: Run test, verify it fails to compile**

```bash
flutter test test/core/task_registry_test.dart
```

Expected: FAIL — undefined symbols.

- [ ] **Step 3: Implement EvaluationContext**

`lib/core/evaluation_context.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/model_response.dart';

class EvaluationContext {
  EvaluationContext({
    required this.workDir,
    required this.response,
    required this.task,
  });

  final Directory workDir;
  final ModelResponse response;
  final BenchmarkTask task;
}
```

- [ ] **Step 4: Implement BenchmarkTask**

`lib/core/benchmark_task.dart`:
```dart
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

abstract class BenchmarkTask {
  String get id;
  Category get category;
  String get prompt;
  Map<String, String> get fixtures;
  List<Evaluator> get evaluators;
  String? get judgeRubric;
}
```

- [ ] **Step 5: Implement TaskRunResult**

`lib/core/task_run_result.dart`:
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
  });

  final String runId;
  final String providerId;
  final String modelId;
  final String taskId;
  final ModelResponse response;
  final List<EvaluationResult> evaluations;
  final double aggregateScore;
  final DateTime completedAt;

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
      ];
}
```

- [ ] **Step 6: Implement TaskRegistry**

`lib/core/task_registry.dart`:
```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';

class TaskRegistry {
  final Map<String, BenchmarkTask> _byId = {};

  void register(BenchmarkTask task) {
    if (_byId.containsKey(task.id)) {
      throw StateError('Duplicate task id: ${task.id}');
    }
    _byId[task.id] = task;
  }

  BenchmarkTask? byId(String id) => _byId[id];

  Iterable<BenchmarkTask> all() => _byId.values;

  Iterable<BenchmarkTask> byCategory(Category c) =>
      _byId.values.where((t) => t.category == c);
}
```

- [ ] **Step 7: Re-run test, verify pass (Evaluator interface still missing — write minimal stub before)**

Add the stub interface so this task's test compiles. Will be expanded in Task 7.

`lib/evaluators/evaluator.dart`:
```dart
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';

abstract class Evaluator {
  String get id;
  Future<EvaluationResult> evaluate(EvaluationContext ctx);
}
```

```bash
flutter test test/core/task_registry_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core lib/evaluators/evaluator.dart test/core/task_registry_test.dart
git commit -m "feat(core): add BenchmarkTask, TaskRegistry, EvaluationContext, Evaluator interface"
```

---

## Task 6: Code extractor (parses Dart code blocks from model output)

**Files:**
- Create: `lib/core/code_extractor.dart`
- Test: `test/core/code_extractor_test.dart`

- [ ] **Step 1: Write failing tests**

`test/core/code_extractor_test.dart`:
```dart
import 'package:dart_arena/core/code_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractDartCode', () {
    test('returns content of first ```dart fenced block', () {
      const raw = '''
Some preamble.
```dart
void main() {
  print('hi');
}
```
Trailing.
''';
      expect(
        extractDartCode(raw),
        'void main() {\n  print(\'hi\');\n}\n',
      );
    });

    test('falls back to bare ``` block if dart not specified', () {
      const raw = '''
```
class X {}
```
''';
      expect(extractDartCode(raw), 'class X {}\n');
    });

    test('returns null when no fenced block exists', () {
      expect(extractDartCode('just prose, no code'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/core/code_extractor_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement extractor**

`lib/core/code_extractor.dart`:
```dart
String? extractDartCode(String raw) {
  final dartFence = RegExp(r'```dart\s*\n([\s\S]*?)\n```');
  final dartMatch = dartFence.firstMatch(raw);
  if (dartMatch != null) return '${dartMatch.group(1)!}\n';

  final anyFence = RegExp(r'```\s*\n([\s\S]*?)\n```');
  final anyMatch = anyFence.firstMatch(raw);
  if (anyMatch != null) return '${anyMatch.group(1)!}\n';

  return null;
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/core/code_extractor_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/code_extractor.dart test/core/code_extractor_test.dart
git commit -m "feat(core): add Dart code extractor"
```

---

## Task 7: ModelProvider interface and OllamaProvider

**Files:**
- Create: `lib/providers/model_provider.dart`
- Create: `lib/providers/ollama_provider.dart`
- Create: `lib/providers/provider_registry.dart`
- Test: `test/providers/ollama_provider_test.dart`

- [ ] **Step 1: Write failing test for OllamaProvider with a fake Dio**

`test/providers/ollama_provider_test.dart`:
```dart
import 'package:dart_arena/providers/ollama_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Options());
  });

  test('generate posts to /api/generate and parses response', () async {
    final dio = _MockDio();
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/generate'),
        statusCode: 200,
        data: const {
          'model': 'llama3',
          'response': 'hello',
          'done': true,
          'prompt_eval_count': 5,
          'eval_count': 7,
        },
      ),
    );

    final provider = OllamaProvider(
      id: 'ollama_local',
      displayName: 'Ollama Local',
      baseUrl: 'http://localhost:11434',
      apiKey: null,
      dio: dio,
    );

    final response = await provider.generate(
      prompt: 'hi',
      model: 'llama3',
    );

    expect(response.rawText, 'hello');
    expect(response.promptTokens, 5);
    expect(response.completionTokens, 7);
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/providers/ollama_provider_test.dart
```

Expected: FAIL — undefined symbols.

- [ ] **Step 3: Implement ModelProvider interface**

`lib/providers/model_provider.dart`:
```dart
import 'package:dart_arena/core/model_response.dart';

enum ProviderMode { rawApi, agent }

abstract class ModelProvider {
  String get id;
  String get displayName;
  ProviderMode get mode;
  Future<List<String>> listModels();
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  });
}
```

- [ ] **Step 4: Implement OllamaProvider**

`lib/providers/ollama_provider.dart`:
```dart
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dio/dio.dart';

class OllamaProvider implements ModelProvider {
  OllamaProvider({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.apiKey,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  final String id;
  @override
  final String displayName;
  final String baseUrl;
  final String? apiKey;
  final Dio _dio;

  @override
  ProviderMode get mode => ProviderMode.rawApi;

  Map<String, String> _headers() => {
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  @override
  Future<List<String>> listModels() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/api/tags',
      options: Options(headers: _headers()),
    );
    final models = (res.data?['models'] as List<dynamic>? ?? [])
        .map((m) => (m as Map<String, dynamic>)['name'] as String)
        .toList();
    return models;
  }

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final res = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/api/generate',
      data: {
        'model': model,
        'prompt': prompt,
        'stream': false,
      },
      options: Options(
        headers: _headers(),
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    stopwatch.stop();

    final data = res.data ?? const <String, dynamic>{};
    return ModelResponse(
      rawText: (data['response'] as String?) ?? '',
      extractedCode: null,
      promptTokens: data['prompt_eval_count'] as int?,
      completionTokens: data['eval_count'] as int?,
      latency: stopwatch.elapsed,
    );
  }
}
```

- [ ] **Step 5: Implement minimal ProviderRegistry**

`lib/providers/provider_registry.dart`:
```dart
import 'package:dart_arena/providers/model_provider.dart';

class ProviderRegistry {
  final Map<String, ModelProvider> _byId = {};

  void register(ModelProvider provider) {
    _byId[provider.id] = provider;
  }

  ModelProvider? byId(String id) => _byId[id];

  Iterable<ModelProvider> all() => _byId.values;
}
```

- [ ] **Step 6: Run, verify pass**

```bash
flutter test test/providers/ollama_provider_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/providers test/providers
git commit -m "feat(providers): add ModelProvider interface and OllamaProvider"
```

---

## Task 8: Bug-fix task fixtures (off-by-one pagination)

**Files:**
- Create: `lib/tasks/bug_fix/fixtures/off_by_one_pagination/pubspec.yaml`
- Create: `lib/tasks/bug_fix/fixtures/off_by_one_pagination/lib/pagination.dart`
- Create: `lib/tasks/bug_fix/fixtures/off_by_one_pagination/test/pagination_test.dart`

These files are bundled as **assets** so they can be copied into the workdir at runtime.

- [ ] **Step 1: Create the fixture pubspec**

`lib/tasks/bug_fix/fixtures/off_by_one_pagination/pubspec.yaml`:
```yaml
name: off_by_one_pagination
description: Fixture project for off-by-one bug fix task.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.5.0 <4.0.0"

dev_dependencies:
  test: ^1.25.0
```

- [ ] **Step 2: Create the broken source file**

`lib/tasks/bug_fix/fixtures/off_by_one_pagination/lib/pagination.dart`:
```dart
class Paginator<T> {
  Paginator(this.items, {this.pageSize = 10});

  final List<T> items;
  final int pageSize;

  int get pageCount => (items.length / pageSize).floor();

  List<T> page(int index) {
    final start = index * pageSize;
    final end = start + pageSize;
    return items.sublist(start, end > items.length ? items.length - 1 : end);
  }
}
```

- [ ] **Step 3: Create the failing test the model must satisfy**

`lib/tasks/bug_fix/fixtures/off_by_one_pagination/test/pagination_test.dart`:
```dart
import 'package:off_by_one_pagination/pagination.dart';
import 'package:test/test.dart';

void main() {
  group('Paginator', () {
    test('25 items / pageSize 10 yields 3 pages with correct boundaries', () {
      final p = Paginator(List<int>.generate(25, (i) => i));
      expect(p.pageCount, 3);
      expect(p.page(0), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(p.page(1), [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]);
      expect(p.page(2), [20, 21, 22, 23, 24]);
    });

    test('exact multiple does not produce empty trailing page', () {
      final p = Paginator(List<int>.generate(20, (i) => i));
      expect(p.pageCount, 2);
      expect(p.page(1), [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]);
    });
  });
}
```

- [ ] **Step 4: Wire fixtures as Flutter assets so they ship in the bundle**

Modify `pubspec.yaml`, add under `flutter:`:
```yaml
flutter:
  uses-material-design: true
  assets:
    - lib/tasks/bug_fix/fixtures/off_by_one_pagination/pubspec.yaml
    - lib/tasks/bug_fix/fixtures/off_by_one_pagination/lib/pagination.dart
    - lib/tasks/bug_fix/fixtures/off_by_one_pagination/test/pagination_test.dart
```

- [ ] **Step 5: Verify analyze + commit**

```bash
flutter analyze
git add lib/tasks pubspec.yaml
git commit -m "feat(tasks): add off-by-one pagination fixture files"
```

---

## Task 9: Off-by-one pagination task class

**Files:**
- Create: `lib/tasks/bug_fix/off_by_one_pagination.dart`
- Test: `test/tasks/off_by_one_pagination_test.dart`

- [ ] **Step 1: Write failing test**

`test/tasks/off_by_one_pagination_test.dart`:
```dart
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OffByOnePaginationTask metadata is correct', () async {
    await OffByOnePaginationTask.loadAssets();
    final task = OffByOnePaginationTask();
    expect(task.id, 'bug.off_by_one_pagination');
    expect(task.category, Category.bugFix);
    expect(task.prompt, contains('Paginator'));
    expect(task.fixtures.keys, contains('lib/pagination.dart'));
    expect(task.fixtures.keys, contains('test/pagination_test.dart'));
    expect(task.fixtures.keys, contains('pubspec.yaml'));
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
flutter test test/tasks/off_by_one_pagination_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement the task**

`lib/tasks/bug_fix/off_by_one_pagination.dart`:
```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
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
  List<Evaluator> get evaluators => [CompileEvaluator()];

  @override
  String? get judgeRubric => null;
}
```

Note: this test loads assets because `fixtures` is populated from Flutter assets at runtime.

- [ ] **Step 4: Stub CompileEvaluator so this compiles**

`lib/evaluators/compile_evaluator.dart`:
```dart
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class CompileEvaluator implements Evaluator {
  @override
  String get id => 'compile';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    throw UnimplementedError('Implemented in Task 10');
  }
}
```

- [ ] **Step 5: Run, verify pass**

```bash
flutter test test/tasks/off_by_one_pagination_test.dart
```

Expected: PASS after assets load successfully.

- [ ] **Step 6: Commit**

```bash
git add lib/tasks/bug_fix/off_by_one_pagination.dart lib/evaluators/compile_evaluator.dart test/tasks/off_by_one_pagination_test.dart
git commit -m "feat(tasks): add OffByOnePaginationTask"
```

---

## Task 10: CompileEvaluator (real implementation)

**Files:**
- Modify: `lib/evaluators/compile_evaluator.dart`
- Test: `test/evaluators/compile_evaluator_test.dart`

- [ ] **Step 1: Write integration test using a real temp dir**

`test/evaluators/compile_evaluator_test.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
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
  List<Evaluator> get evaluators => const [];
  @override
  String? get judgeRubric => null;
}

void main() {
  test('passes for clean Dart code', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_eval_');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart'))
        .writeAsStringSync('int answer() => 42;\n');
    Directory(p.join(dir.path, 'test')).createSync();
    File(p.join(dir.path, 'test', 'tmp_test.dart')).writeAsStringSync('''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('answer', () {
    expect(answer(), 42);
  });
}
''');

    final result = await CompileEvaluator().evaluate(
      EvaluationContext(
        workDir: dir,
        response: const ModelResponse(
          rawText: '',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        task: _DummyTask(),
      ),
    );

    expect(result.passed, isTrue);
    expect(result.score, 1.0);
    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('fails for code with syntax errors', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_eval_');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart'))
        .writeAsStringSync('int answer( => 42;');

    final result = await CompileEvaluator().evaluate(
      EvaluationContext(
        workDir: dir,
        response: const ModelResponse(
          rawText: '',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        task: _DummyTask(),
      ),
    );

    expect(result.passed, isFalse);
    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('fails when tests fail', () async {
    final dir = await Directory.systemTemp.createTemp('dart_arena_eval_');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');
    Directory(p.join(dir.path, 'lib')).createSync();
    File(p.join(dir.path, 'lib', 'tmp.dart'))
        .writeAsStringSync('int answer() => 41;\n');
    Directory(p.join(dir.path, 'test')).createSync();
    File(p.join(dir.path, 'test', 'tmp_test.dart')).writeAsStringSync('''
import 'package:test/test.dart';
import 'package:tmp/tmp.dart';

void main() {
  test('answer', () {
    expect(answer(), 42);
  });
}
''');

    final result = await CompileEvaluator().evaluate(
      EvaluationContext(
        workDir: dir,
        response: const ModelResponse(
          rawText: '',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        task: _DummyTask(),
      ),
    );

    expect(result.passed, isFalse);
    expect(result.rationale, 'tests failed');
    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

- [ ] **Step 2: Implement CompileEvaluator**

`lib/evaluators/compile_evaluator.dart` (replace stub):
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
    final pubGet = await Process.run(
      'dart',
      ['pub', 'get', '--offline'],
      workingDirectory: ctx.workDir.path,
    );
    if (pubGet.exitCode != 0) {
      final retry = await Process.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: ctx.workDir.path,
      );
      if (retry.exitCode != 0) {
        return EvaluationResult(
          evaluatorId: id,
          passed: false,
          score: 0,
          rationale: 'pub get failed',
          details: {'stderr': retry.stderr.toString()},
        );
      }
    }

    final analyze = await Process.run(
      'dart',
      ['analyze', '--fatal-infos'],
      workingDirectory: ctx.workDir.path,
    );

    if (analyze.exitCode != 0) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'analysis errors present',
        details: {
          'phase': 'analyze',
          'exitCode': analyze.exitCode,
          'stdout': analyze.stdout.toString(),
          'stderr': analyze.stderr.toString(),
        },
      );
    }

    final test = await Process.run(
      'dart',
      ['test'],
      workingDirectory: ctx.workDir.path,
    );

    final passed = test.exitCode == 0;
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
      rationale: passed ? 'analysis and tests clean' : 'tests failed',
      details: {
        'phase': 'test',
        'exitCode': test.exitCode,
        'stdout': test.stdout.toString(),
        'stderr': test.stderr.toString(),
      },
    );
  }
}
```

- [ ] **Step 3: Run tests, verify pass**

```bash
flutter test test/evaluators/compile_evaluator_test.dart
```

Expected: PASS (slow — these are integration tests that spawn `dart pub get`).

- [ ] **Step 4: Commit**

```bash
git add lib/evaluators/compile_evaluator.dart test/evaluators/compile_evaluator_test.dart
git commit -m "feat(evaluators): implement CompileEvaluator"
```

---

## Task 11: WorkdirManager

**Files:**
- Create: `lib/runner/workdir_manager.dart`
- Test: `test/runner/workdir_manager_test.dart`

- [ ] **Step 1: Write failing tests**

`test/runner/workdir_manager_test.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('createTaskWorkdir writes fixtures and splices generated code', () async {
    final root = await Directory.systemTemp.createTemp('dart_arena_root_');
    final mgr = WorkdirManager(root: root);

    final dir = await mgr.createTaskWorkdir(
      runId: 'r1',
      providerId: 'ollama_local',
      modelId: 'm',
      taskId: 't',
      fixtures: const {
        'pubspec.yaml': 'name: tmp\nenvironment:\n  sdk: ">=3.5.0 <4.0.0"\n',
        'lib/pagination.dart': '// broken',
      },
      generatedCode: 'int answer() => 42;\n',
      generatedCodePath: 'lib/pagination.dart',
    );

    expect(File(p.join(dir.path, 'pubspec.yaml')).existsSync(), isTrue);
    expect(
      File(p.join(dir.path, 'lib', 'pagination.dart')).readAsStringSync(),
      'int answer() => 42;\n',
    );

    root.deleteSync(recursive: true);
  });
}
```

- [ ] **Step 2: Implement WorkdirManager**

`lib/runner/workdir_manager.dart`:
```dart
import 'dart:io';

import 'package:path/path.dart' as p;

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
}
```

- [ ] **Step 3: Run, verify pass**

```bash
flutter test test/runner/workdir_manager_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/runner/workdir_manager.dart test/runner/workdir_manager_test.dart
git commit -m "feat(runner): add WorkdirManager"
```

---

## Task 12: Drift database setup

**Files:**
- Create: `lib/storage/database.dart`
- Generated: `lib/storage/database.g.dart`
- Test: `test/storage/database_test.dart`

- [ ] **Step 1: Define schema**

`lib/storage/database.dart`:
```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Runs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get judgeModel => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Evaluations extends Table {
  TextColumn get id => text()();
  TextColumn get taskRunId => text().references(TaskRuns, #id)();
  TextColumn get evaluatorId => text()();
  BoolColumn get passed => boolean()();
  RealColumn get score => real()();
  TextColumn get rationale => text().nullable()();
  TextColumn get detailsJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Runs, TaskRuns, Evaluations])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return NativeDatabase(File(p.join(dir.path, 'dart_arena.sqlite')));
  });
}
```

- [ ] **Step 2: Generate the .g.dart**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: writes `lib/storage/database.g.dart`. Commit it (we already excluded it from analyzer).

- [ ] **Step 3: Write a smoke test**

`test/storage/database_test.dart`:
```dart
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('insert and read a Run', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db.into(db.runs).insert(
          RunsCompanion.insert(
            id: 'r1',
            startedAt: DateTime(2026, 5, 2),
          ),
        );
    final all = await db.select(db.runs).get();
    expect(all, hasLength(1));
    expect(all.first.id, 'r1');

    await db.close();
  });
}
```

- [ ] **Step 4: Run, verify pass**

```bash
flutter test test/storage/database_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/storage/database.dart lib/storage/database.g.dart test/storage/database_test.dart
git commit -m "feat(storage): add Drift schema for runs/task_runs/evaluations"
```

---

## Task 13: RunDao — persist a TaskRunResult

**Files:**
- Create: `lib/storage/dao/run_dao.dart`
- Test: `test/storage/run_dao_test.dart`

- [ ] **Step 1: Write failing test**

`test/storage/run_dao_test.dart`:
```dart
import 'dart:convert';

import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists a TaskRunResult and its evaluations', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);

    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 2));
    await dao.persistTaskRun(
      TaskRunResult(
        runId: 'r1',
        providerId: 'ollama_local',
        modelId: 'llama3',
        taskId: 'bug.off_by_one_pagination',
        response: const ModelResponse(
          rawText: 'hi',
          extractedCode: 'code',
          promptTokens: 1,
          completionTokens: 2,
          latency: Duration(milliseconds: 50),
        ),
        evaluations: const [
          EvaluationResult(
            evaluatorId: 'compile',
            passed: true,
            score: 1.0,
          ),
        ],
        aggregateScore: 1.0,
        completedAt: DateTime(2026, 5, 2),
      ),
    );

    final loaded = await dao.taskRunsForRun('r1');
    expect(loaded, hasLength(1));
    expect(loaded.first.aggregateScore, 1.0);
    expect(jsonDecode((await dao.evaluationsForTaskRun(loaded.first.id)).first.detailsJson), isMap);

    await db.close();
  });
}
```

- [ ] **Step 2: Implement RunDao**

`lib/storage/dao/run_dao.dart`:
```dart
import 'dart:convert';

import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';

class RunDao {
  RunDao(this._db);
  final AppDatabase _db;

  Future<void> startRun({required String runId, required DateTime startedAt}) {
    return _db.into(_db.runs).insert(
          RunsCompanion.insert(id: runId, startedAt: startedAt),
        );
  }

  Future<void> finishRun(String runId, DateTime completedAt) {
    return (_db.update(_db.runs)..where((r) => r.id.equals(runId))).write(
      RunsCompanion(completedAt: Value(completedAt)),
    );
  }

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

  Future<List<TaskRun>> taskRunsForRun(String runId) {
    return (_db.select(_db.taskRuns)..where((t) => t.runId.equals(runId))).get();
  }

  Future<List<Evaluation>> evaluationsForTaskRun(String taskRunId) {
    return (_db.select(_db.evaluations)
          ..where((e) => e.taskRunId.equals(taskRunId)))
        .get();
  }

  Future<List<Run>> recentRuns({int limit = 20}) {
    return (_db.select(_db.runs)
          ..orderBy([(r) => OrderingTerm.desc(r.startedAt)])
          ..limit(limit))
        .get();
  }
}
```

- [ ] **Step 3: Run, verify pass**

```bash
flutter test test/storage/run_dao_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/storage/dao test/storage/run_dao_test.dart
git commit -m "feat(storage): add RunDao for persisting task runs"
```

---

## Task 14: Run BLoC (orchestrates one slice end-to-end)

**Files:**
- Create: `lib/runner/run_event.dart`
- Create: `lib/runner/run_state.dart`
- Create: `lib/runner/run_bloc.dart`
- Test: `test/runner/run_bloc_test.dart`

- [ ] **Step 1: Define events**

`lib/runner/run_event.dart`:
```dart
import 'package:dart_arena/core/benchmark_task.dart';
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
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, String> modelByProvider; // providerId -> modelId
}

class CancelRun extends RunEvent {
  const CancelRun();
}
```

- [ ] **Step 2: Define states**

`lib/runner/run_state.dart`:
```dart
import 'package:dart_arena/core/task_run_result.dart';
import 'package:equatable/equatable.dart';

sealed class RunState extends Equatable {
  const RunState();
  @override
  List<Object?> get props => [];
}

class RunIdle extends RunState {
  const RunIdle();
}

class RunInProgress extends RunState {
  const RunInProgress({
    required this.runId,
    required this.completed,
    required this.total,
    required this.results,
    this.currentLabel,
  });

  final String runId;
  final int completed;
  final int total;
  final List<TaskRunResult> results;
  final String? currentLabel;

  @override
  List<Object?> get props => [runId, completed, total, results, currentLabel];
}

class RunCompleted extends RunState {
  const RunCompleted({required this.runId, required this.results});

  final String runId;
  final List<TaskRunResult> results;

  @override
  List<Object?> get props => [runId, results];
}

class RunFailed extends RunState {
  const RunFailed(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}
```

- [ ] **Step 3: Implement bloc**

`lib/runner/run_bloc.dart`:
```dart
import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
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
  }) : super(const RunIdle()) {
    on<StartRun>(_onStart);
  }

  final WorkdirManager workdirManager;
  final RunDao runDao;
  final DateTime Function() now;
  final String Function() idGenerator;

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
          final responseWithCode = copyWithCode(response, extracted);

          final dir = await workdirManager.createTaskWorkdir(
            runId: runId,
            providerId: provider.id,
            modelId: modelId,
            taskId: task.id,
            fixtures: task.fixtures,
            generatedCode: extracted,
            generatedCodePath: 'lib/pagination.dart',
          );

          final evaluations = <EvaluationResult>[];
          for (final evaluator in task.evaluators) {
            final result = await evaluator.evaluate(
              EvaluationContext(
                workDir: dir,
                response: responseWithCode,
                task: task,
              ),
            );
            evaluations.add(result);
          }

          final aggregate = evaluations.isEmpty
              ? 0.0
              : evaluations.map((e) => e.score).reduce((a, b) => a + b) /
                  evaluations.length;

          final result = TaskRunResult(
            runId: runId,
            providerId: provider.id,
            modelId: modelId,
            taskId: task.id,
            response: responseWithCode,
            evaluations: evaluations,
            aggregateScore: aggregate,
            completedAt: now(),
          );
          results.add(result);
          await runDao.persistTaskRun(result);
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

// Helper: returns a copy of the response with extractedCode populated.
ModelResponse copyWithCode(ModelResponse r, String? code) => ModelResponse(
      rawText: r.rawText,
      extractedCode: code,
      promptTokens: r.promptTokens,
      completionTokens: r.completionTokens,
      latency: r.latency,
    );
```

- [ ] **Step 4: Write a fake-driven bloc test**

`test/runner/run_bloc_test.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
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

class _AlwaysPassEvaluator implements Evaluator {
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
        'pubspec.yaml': 'name: tmp\nenvironment:\n  sdk: ">=3.5.0 <4.0.0"\n',
      };
  @override
  List<Evaluator> get evaluators => [_AlwaysPassEvaluator()];
  @override
  String? get judgeRubric => null;
}

void main() {
  test('happy path: one model x one task -> RunCompleted with score 1.0',
      () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_');
    final db = AppDatabase(NativeDatabase.memory());
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-test',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(StartRun(
      tasks: [_StubTask()],
      providers: [_FakeProvider()],
      modelByProvider: const {'fake': 'fake-1'},
    ));

    await Future.delayed(const Duration(seconds: 1));
    expect(states.last, isA<RunCompleted>());
    final completed = states.last as RunCompleted;
    expect(completed.results, hasLength(1));
    expect(completed.results.first.aggregateScore, 1.0);

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });
}
```

- [ ] **Step 5: Run, verify pass**

```bash
flutter test test/runner/run_bloc_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/runner test/runner/run_bloc_test.dart
git commit -m "feat(runner): add RunBloc orchestrating end-to-end task runs"
```

---

## Task 15: Settings persistence (Ollama base URL)

**Files:**
- Create: `lib/storage/settings.dart`
- Test: `test/storage/settings_test.dart`

- [ ] **Step 1: Define a Settings repository using flutter_secure_storage**

`lib/storage/settings.dart`:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsRepository {
  SettingsRepository([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _ollamaBaseUrl = 'ollama_base_url';

  Future<String> getOllamaBaseUrl() async =>
      (await _storage.read(key: _ollamaBaseUrl)) ?? 'http://localhost:11434';

  Future<void> setOllamaBaseUrl(String value) =>
      _storage.write(key: _ollamaBaseUrl, value: value);
}
```

- [ ] **Step 2: Write a test using a fake FlutterSecureStorage**

`test/storage/settings_test.dart`:
```dart
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('default Ollama URL is localhost:11434', () async {
    final repo = SettingsRepository();
    expect(await repo.getOllamaBaseUrl(), 'http://localhost:11434');
  });

  test('setOllamaBaseUrl roundtrips', () async {
    final repo = SettingsRepository();
    await repo.setOllamaBaseUrl('http://example.com:11434');
    expect(await repo.getOllamaBaseUrl(), 'http://example.com:11434');
  });
}
```

- [ ] **Step 3: Run, verify pass**

```bash
flutter test test/storage/settings_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/storage/settings.dart test/storage/settings_test.dart
git commit -m "feat(storage): add SettingsRepository for Ollama URL"
```

---

## Task 16: Minimal UI — Theme + GoRouter shell

**Files:**
- Create: `lib/ui/theme.dart`
- Replace: `lib/main.dart`
- Create: `lib/app.dart`

- [ ] **Step 1: Theme**

`lib/ui/theme.dart`:
```dart
import 'package:flutter/material.dart';

ThemeData buildAppTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    );
```

- [ ] **Step 2: App shell with GoRouter**

`lib/app.dart`:
```dart
import 'package:dart_arena/ui/pages/home_page.dart';
import 'package:dart_arena/ui/pages/new_run_page.dart';
import 'package:dart_arena/ui/pages/run_progress_page.dart';
import 'package:dart_arena/ui/pages/settings_page.dart';
import 'package:dart_arena/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/new-run', builder: (_, __) => const NewRunPage()),
    GoRoute(path: '/run', builder: (_, __) => const RunProgressPage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
  ],
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'dart_arena',
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
```

- [ ] **Step 3: main.dart**

`lib/main.dart`:
```dart
import 'package:dart_arena/app.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OffByOnePaginationTask.loadAssets();
  runApp(const App());
}
```

- [ ] **Step 4: Commit (pages still pending — next task)**

Pages will be created in Task 17. We commit a stubbed import path — but let's create empty page stubs first to keep the project compilable.

`lib/ui/pages/home_page.dart`:
```dart
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home')));
}
```

Repeat that skeleton for `new_run_page.dart`, `run_progress_page.dart`, and `settings_page.dart`; Task 17 replaces each stub with the real page implementation.

```bash
flutter analyze
git add lib
git commit -m "feat(ui): add theme, GoRouter shell, page stubs"
```

---

## Task 17: Pages — Settings, NewRun, RunProgress, Home

**Files:**
- Modify: `lib/ui/pages/settings_page.dart`
- Modify: `lib/ui/pages/new_run_page.dart`
- Modify: `lib/ui/pages/run_progress_page.dart`
- Modify: `lib/ui/pages/home_page.dart`

The UI uses `BlocProvider` to inject the `RunBloc` at the route level. Since this is the first slice, we only support running ONE selected task against ONE Ollama model.

- [ ] **Step 1: Settings page (Ollama URL)**

`lib/ui/pages/settings_page.dart`:
```dart
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repo = SettingsRepository();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo.getOllamaBaseUrl().then((v) {
      setState(() => _controller.text = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ollama Local base URL'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await _repo.setOllamaBaseUrl(_controller.text);
                if (mounted) context.pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: HomePage**

`lib/ui/pages/home_page.dart`:
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
        child: FilledButton(
          onPressed: () => context.push('/new-run'),
          child: const Text('New Run'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: NewRunPage**

`lib/ui/pages/new_run_page.dart`:
```dart
import 'dart:io';

import 'package:dart_arena/providers/ollama_provider.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NewRunPage extends StatefulWidget {
  const NewRunPage({super.key});
  @override
  State<NewRunPage> createState() => _NewRunPageState();
}

class _NewRunPageState extends State<NewRunPage> {
  final _modelController = TextEditingController(text: 'qwen2.5-coder:7b');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Run')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provider: Ollama Local'),
            const SizedBox(height: 8),
            const Text('Task: bug.off_by_one_pagination'),
            const SizedBox(height: 16),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Ollama model',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final settings = SettingsRepository();
                final base = await settings.getOllamaBaseUrl();
                final docs = await getApplicationSupportDirectory();
                final root = Directory(p.join(docs.path, 'workdirs'))
                  ..createSync(recursive: true);
                final db = AppDatabase();
                final bloc = RunBloc(
                  workdirManager: WorkdirManager(root: root),
                  runDao: RunDao(db),
                  now: DateTime.now,
                  idGenerator: () =>
                      'run-${DateTime.now().millisecondsSinceEpoch}',
                );
                final provider = OllamaProvider(
                  id: 'ollama_local',
                  displayName: 'Ollama Local',
                  baseUrl: base,
                  apiKey: null,
                );
                bloc.add(StartRun(
                  tasks: [OffByOnePaginationTask()],
                  providers: [provider],
                  modelByProvider: {'ollama_local': _modelController.text},
                ));
                if (mounted) {
                  context.push('/run', extra: bloc);
                }
              },
              child: const Text('Run'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: this is wired up directly for simplicity in the slice. Plan 4 will refactor this with proper provider DI.

- [ ] **Step 4: RunProgressPage receives the bloc via `extra`**

Modify `lib/app.dart` route for /run to accept extra:

```dart
GoRoute(
  path: '/run',
  builder: (context, state) => RunProgressPage(bloc: state.extra! as RunBloc),
),
```

`lib/ui/pages/run_progress_page.dart`:
```dart
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RunProgressPage extends StatelessWidget {
  const RunProgressPage({required this.bloc, super.key});
  final RunBloc bloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Run')),
        body: BlocBuilder<RunBloc, RunState>(
          builder: (context, state) {
            return switch (state) {
              RunIdle() => const Center(child: Text('idle')),
              RunInProgress(:final completed, :final total, :final currentLabel) =>
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$completed / $total'),
                      const SizedBox(height: 8),
                      Text(currentLabel ?? ''),
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ),
                ),
              RunCompleted(:final results) => ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final r = results[i];
                    return ListTile(
                      title: Text('${r.providerId} / ${r.modelId} / ${r.taskId}'),
                      subtitle: Text('Score: ${r.aggregateScore.toStringAsFixed(2)}'),
                    );
                  },
                ),
              RunFailed(:final error) =>
                Center(child: Text('Failed: $error')),
            };
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify it builds**

```bash
flutter analyze
flutter build linux --debug
```

- [ ] **Step 6: Commit**

```bash
git add lib/ui lib/app.dart lib/main.dart
git commit -m "feat(ui): add Settings, NewRun, RunProgress pages for first slice"
```

---

## Task 18: Manual end-to-end smoke

**Goal:** Make sure a real Ollama Local invocation produces a real persisted run.

- [ ] **Step 1: Pull a small coder model in Ollama**

```bash
ollama pull qwen2.5-coder:7b
```

(skip if already present)

- [ ] **Step 2: Run the app**

```bash
flutter run -d linux
```

- [ ] **Step 3: Manually verify**

Click `New Run` -> ensure model field reads `qwen2.5-coder:7b` -> click `Run`. Wait. The Run Progress page should:

- Show progress 0/1 -> 1/1
- Move to RunCompleted state
- Display a result tile with a non-trivial aggregate score (1.0 if the model actually fixes the bug, 0.0 otherwise)

If anything fails, the bloc emits `RunFailed`; the error message will help debug.

- [ ] **Step 4: Verify persistence**

```bash
sqlite3 ~/.local/share/dart_arena/dart_arena.sqlite \
  'select run_id, task_id, aggregate_score from task_runs;'
```

Expected: at least one row matching the run. This path matches the explicit `AppDatabase` connection in Task 12 on Linux.

- [ ] **Step 5: Commit any final tweaks if you discovered issues**

If the smoke surfaced bugs, fix them in small commits.

---

## Done criteria for Plan 1

- `flutter analyze` passes with strict-casts/strict-inference
- `flutter test` passes all tests
- `flutter build linux --debug` succeeds
- Manual smoke run completes against Ollama Local with a persisted result
- All commits land on `master`

After Plan 1 ships, we'll move to Plan 2 (rest of the evaluators + tasks).

## Self-review notes

- Spec coverage: BLoC ✅, Drift ✅, secure storage ✅, ModelProvider iface ✅, OllamaProvider ✅, BenchmarkTask ✅, evaluators (CompileEvaluator only, others deferred to Plan 2 by design), workdir manager ✅, fixture loading ✅, Run lifecycle ✅, persistence ✅, minimal UI ✅. Other providers / tasks / evaluators / charts / leaderboard are explicitly deferred to Plans 2-4 per the slice strategy.
- No placeholders remain (the bloc helper text was inline-fixed).
- Type signatures align across tasks.

---

## Future plans (outline — will be authored after Plan 1 ships)

### Plan 2: Remaining evaluators + tasks
- **9 more tasks** across the 5 categories (ui.profile_card, ui.expandable_list_tile, state.counter_bloc, state.shopping_cart_bloc, bug.async_race_condition, refactor.god_widget, refactor.callback_hell, test.todo_input, test.form_validation)
- **5 more evaluators**: AnalyzeEvaluator, TestEvaluator, WidgetTreeEvaluator, LlmJudgeEvaluator, DiffSizeEvaluator
- **LlmJudgeEvaluator** adds elegance/idiomatic scoring dimension; per-run judge model selection
- Aggregate scoring with category-specific evaluator weights

### Plan 3: Remaining providers
- **7 more providers**: OpenCodeZenProvider, OllamaProvider (cloud config), DroidExecProvider, OpenRouterProvider, OpenAIProvider, AnthropicProvider, DeepSeekProvider
- API key management via Settings page (all providers)
- Agent-mode vs raw-API toggle on leaderboard for fair comparisons

### Plan 4: UI polish — dashboard, leaderboard, run details
- Dashboard with recent runs and quick-glance top models per category
- Leaderboard with `fl_chart` bar charts / radar charts, filtered by category/provider/date
- Run details page: raw model output, evaluator breakdown, judge rationale, diff view
- Intelligence / Speed / Elegance / Problems multi-dimensional score display
- Proper provider DI (refactor NewRunPage wiring)
