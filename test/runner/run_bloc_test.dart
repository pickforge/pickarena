import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_failure_policy.dart';
import 'package:dart_arena/runner/run_progress_snapshot.dart';
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
  }) async => const ModelResponse(
    rawText: '```dart\nint answer() => 42;\n```',
    extractedCode: null,
    promptTokens: 1,
    completionTokens: 2,
    latency: Duration(milliseconds: 1),
  );
}

class _FailingProvider implements ModelProvider {
  @override
  String get id => 'fail';
  @override
  String get displayName => 'Failing';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<String>> listModels() async => ['fail-1'];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => throw Exception('provider unavailable');
}

class _FailsOnceProvider implements ModelProvider {
  var calls = 0;

  @override
  String get id => 'flaky';
  @override
  String get displayName => 'Flaky';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<String>> listModels() async => ['flaky-1'];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    calls++;
    if (calls == 1) throw Exception('temporary 504');
    return const ModelResponse(
      rawText: '```dart\nint answer() => 42;\n```',
      extractedCode: null,
      promptTokens: 1,
      completionTokens: 2,
      latency: Duration(milliseconds: 1),
    );
  }
}

class _SecondFakeProvider implements ModelProvider {
  @override
  String get id => 'fake2';
  @override
  String get displayName => 'Fake2';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<String>> listModels() async => ['fake2-1', 'fake2-2'];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => const ModelResponse(
    rawText: '```dart\nint answer() => 42;\n```',
    extractedCode: null,
    promptTokens: 1,
    completionTokens: 2,
    latency: Duration(milliseconds: 1),
  );
}

class _StreamingProvider implements StreamingModelProvider {
  @override
  String get id => 'stream';
  @override
  String get displayName => 'Streaming';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  final Stream<ModelStreamEvent> _stream;

  _StreamingProvider(List<ModelStreamEvent> events)
    : _stream = Stream.fromIterable(events);

  @override
  Future<List<String>> listModels() async => ['s1'];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => const ModelResponse(
    rawText: '',
    extractedCode: null,
    promptTokens: null,
    completionTokens: null,
    latency: Duration.zero,
  );

  @override
  Stream<ModelStreamEvent> generateStream({
    required String prompt,
    required String model,
    Duration? timeout,
  }) => _stream;
}

class _ConcurrencyRecordingProvider implements ModelProvider {
  int _inFlight = 0;
  int _peak = 0;

  int get peak => _peak;

  @override
  String get id => 'con';
  @override
  String get displayName => 'Concurrency';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<String>> listModels() async => List.generate(10, (i) => 'm$i');
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    _inFlight++;
    if (_inFlight > _peak) _peak = _inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _inFlight--;
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

class _AlwaysLow implements Evaluator {
  @override
  String get id => 'low';
  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async =>
      const EvaluationResult(evaluatorId: 'low', passed: false, score: 0.2);
}

class _TwoEvaluatorTask extends _StubTask {
  _TwoEvaluatorTask(this._evals);
  final List<Evaluator> _evals;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => _evals;
}

void main() {
  test('happy path emits RunCompleted with aggregate 1.0', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_ok_');
    final db = AppDatabase(NativeDatabase.memory());
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      now: () => DateTime.now(),
      idGenerator: () => 'run-test',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [_StubTask()],
        providers: [_FakeProvider()],
        modelsByProvider: const {
          'fake': ['fake-1'],
        },
        evaluatorConfig: const EvaluatorConfig(),
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunCompleted>());
    final completed = states.last as RunCompleted;
    expect(completed.results.first.aggregateScore, 1.0);

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test(
    'prepare failure produces synthetic per-evaluator results',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_bloc_prep_',
      );
      final db = AppDatabase(NativeDatabase.memory());
      final bloc = RunBloc(
        workdirManager: WorkdirManager(root: tmp),
        runDao: RunDao(db),
        now: () => DateTime.now(),
        idGenerator: () => 'run-test',
      );

      final states = <RunState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(
        StartRun(
          tasks: [_BrokenPubspecTask()],
          providers: [_FakeProvider()],
          modelsByProvider: const {
            'fake': ['fake-1'],
          },
          evaluatorConfig: const EvaluatorConfig(),
        ),
      );

      await Future<void>.delayed(const Duration(seconds: 2));
      expect(states.last, isA<RunCompleted>());
      final completed = states.last as RunCompleted;
      final r = completed.results.single;
      expect(r.evaluations, hasLength(1));
      expect(r.evaluations.single.passed, isFalse);
      expect(r.evaluations.single.rationale, 'prepare failed');
      expect(r.aggregateScore, 0.0);

      await sub.cancel();
      await bloc.close();
      await db.close();
      tmp.deleteSync(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

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

    bloc.add(
      StartRun(
        tasks: [_StubTask()],
        providers: [_FakeProvider()],
        modelsByProvider: const {
          'fake': ['fake-1'],
        },
        evaluatorConfig: const EvaluatorConfig(),
        name: 'experiment-7',
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 1));
    expect(states.last, isA<RunCompleted>());

    final row = await dao.runById('run-named');
    expect(row, isNotNull);
    expect(row!.name, 'experiment-7');

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('custom weights propagate to aggregate', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_w_');
    final db = AppDatabase(NativeDatabase.memory());

    final passEval = _AlwaysPass();
    final lowEval = _AlwaysLow();

    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-w',
      weights: const {'pass': 4.0, 'low': 1.0},
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [
          _TwoEvaluatorTask([passEval, lowEval]),
        ],
        providers: [_FakeProvider()],
        modelsByProvider: const {
          'fake': ['fake-1'],
        },
        evaluatorConfig: const EvaluatorConfig(),
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunCompleted>());
    final completed = states.last as RunCompleted;
    expect(completed.results.single.aggregateScore, closeTo(0.84, 1e-9));

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('many-models-one-provider produces N task_runs per task', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_many_');
    final db = AppDatabase(NativeDatabase.memory());
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-many',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [_StubTask(), _StubTask()],
        providers: [_FakeProvider()],
        modelsByProvider: const {
          'fake': ['fake-1', 'fake-2', 'fake-3'],
        },
        evaluatorConfig: const EvaluatorConfig(),
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 3));
    expect(states.last, isA<RunCompleted>());
    final completed = states.last as RunCompleted;
    expect(completed.results.length, 6);

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('many-providers + many-models matrix counts correct', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_bloc_matrix_',
    );
    final db = AppDatabase(NativeDatabase.memory());
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-matrix',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [_StubTask()],
        providers: [_FakeProvider(), _SecondFakeProvider()],
        modelsByProvider: const {
          'fake': ['fake-1'],
          'fake2': ['fake2-1', 'fake2-2'],
        },
        evaluatorConfig: const EvaluatorConfig(),
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 3));
    expect(states.last, isA<RunCompleted>());
    final completed = states.last as RunCompleted;
    expect(completed.results.length, 3);

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('duplicate/blank model ids normalized, empty emits RunFailed', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_empty_');
    final db = AppDatabase(NativeDatabase.memory());
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-empty',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [_StubTask()],
        providers: [_FakeProvider()],
        modelsByProvider: const {'fake': []},
        evaluatorConfig: const EvaluatorConfig(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(states.last, isA<RunFailed>());
    final failed = states.last as RunFailed;
    expect(failed.error, contains('No models selected'));

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('failFast emits RunFailed for first error, no finishRun', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_ff_');
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: dao,
      now: DateTime.now,
      idGenerator: () => 'run-ff',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [_StubTask()],
        providers: [_FailingProvider()],
        modelsByProvider: const {
          'fail': ['fail-1'],
        },
        evaluatorConfig: const EvaluatorConfig(),
        onFailure: RunFailurePolicy.failFast,
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunFailed>());
    final failed = states.last as RunFailed;
    expect(failed.error, contains('provider unavailable'));
    expect(failed.retry, isNotNull);

    final run = await dao.runById('run-ff');
    expect(run!.completedAt, isNull);

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('retry from RunFailed appends result to existing run', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_retry_');
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    final provider = _FailsOnceProvider();
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: dao,
      now: DateTime.now,
      idGenerator: () => 'run-retry',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [_StubTask()],
        providers: [provider],
        modelsByProvider: const {
          'flaky': ['flaky-1'],
        },
        evaluatorConfig: const EvaluatorConfig(),
        onFailure: RunFailurePolicy.failFast,
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    final failed = states.last as RunFailed;
    expect(failed.retry, isNotNull);
    expect((await dao.taskRunsForRun('run-retry')), isEmpty);

    bloc.add(failed.retry!);

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunCompleted>());
    final rows = await dao.taskRunsForRun('run-retry');
    expect(rows, hasLength(1));
    expect(provider.calls, 2);
    expect((await dao.runById('run-retry'))!.completedAt, isNotNull);

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test(
    'skipAndContinue records synthetic failed TaskRunResult with combo_failure',
    () async {
      final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_sc_');
      final db = AppDatabase(NativeDatabase.memory());
      final bloc = RunBloc(
        workdirManager: WorkdirManager(root: tmp),
        runDao: RunDao(db),
        now: DateTime.now,
        idGenerator: () => 'run-sc',
      );

      final states = <RunState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(
        StartRun(
          tasks: [_StubTask()],
          providers: [_FailingProvider()],
          modelsByProvider: const {
            'fail': ['fail-1'],
          },
          evaluatorConfig: const EvaluatorConfig(),
          onFailure: RunFailurePolicy.skipAndContinue,
        ),
      );

      await Future<void>.delayed(const Duration(seconds: 2));
      expect(states.last, isA<RunCompleted>());
      final completed = states.last as RunCompleted;
      expect(completed.results.length, 1);
      final r = completed.results.single;
      expect(r.response.rawText, '<error>');
      expect(r.aggregateScore, 0.0);
      expect(r.evaluations.length, 1);
      expect(r.evaluations.single.evaluatorId, 'combo_failure');
      expect(r.evaluations.single.score, 0.0);

      await sub.cancel();
      await bloc.close();
      await db.close();
      tmp.deleteSync(recursive: true);
    },
  );

  test('concurrency cap respects maxConcurrency', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_conc_');
    final db = AppDatabase(NativeDatabase.memory());
    final provider = _ConcurrencyRecordingProvider();
    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-conc',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [_StubTask()],
        providers: [provider],
        modelsByProvider: {'con': List.generate(8, (i) => 'm$i')},
        evaluatorConfig: const EvaluatorConfig(),
        maxConcurrency: 3,
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 5));
    expect(states.last, isA<RunCompleted>());
    expect(provider.peak, lessThanOrEqualTo(3));

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  group('streaming progress', () {
    test('non-streaming provider emits phase snapshots', () async {
      final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_ns_');
      final db = AppDatabase(NativeDatabase.memory());
      final bloc = RunBloc(
        workdirManager: WorkdirManager(root: tmp),
        runDao: RunDao(db),
        now: DateTime.now,
        idGenerator: () => 'run-ns',
      );

      final states = <RunState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(
        StartRun(
          tasks: [_StubTask()],
          providers: [_FakeProvider()],
          modelsByProvider: const {
            'fake': ['fake-1'],
          },
          evaluatorConfig: const EvaluatorConfig(),
          maxConcurrency: 1,
        ),
      );

      await Future<void>.delayed(const Duration(seconds: 2));
      expect(states.last, isA<RunCompleted>());

      final progressStates = states.whereType<RunInProgress>();
      final allActive = progressStates.expand((s) => s.active).toList();
      expect(allActive, isNotEmpty, reason: 'No active snapshots emitted');
      final phases = allActive.map((s) => s.phase).toSet();
      expect(phases, contains(RunComboPhase.requestingModel));
      expect(phases, contains(RunComboPhase.extractingCode));

      final completed = states.last as RunCompleted;
      expect(completed.results.single.response.rawText, contains('```dart'));
      expect(
        completed.results.single.response.rawText,
        contains('int answer() => 42;'),
      );

      await sub.cancel();
      await bloc.close();
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    test(
      'streaming provider emits RunInProgress.active with reasoning and answer previews',
      () async {
        final tmp = await Directory.systemTemp.createTemp(
          'dart_arena_bloc_st_',
        );
        final db = AppDatabase(NativeDatabase.memory());
        final bloc = RunBloc(
          workdirManager: WorkdirManager(root: tmp),
          runDao: RunDao(db),
          now: DateTime.now,
          idGenerator: () => 'run-st',
        );

        final provider = _StreamingProvider([
          const ModelStreamStarted(),
          const ModelStreamReasoningDelta('Let me think...'),
          const ModelStreamContentDelta('```dart'),
          const ModelStreamContentDelta('\nint answer() => 42;\n'),
          const ModelStreamContentDelta('```'),
          const ModelStreamUsage(promptTokens: 10, completionTokens: 5),
          const ModelStreamCompleted(),
        ]);

        final states = <RunState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(
          StartRun(
            tasks: [_StubTask()],
            providers: [provider],
            modelsByProvider: const {
              'stream': ['s1'],
            },
            evaluatorConfig: const EvaluatorConfig(),
            maxConcurrency: 1,
          ),
        );

        await Future<void>.delayed(const Duration(seconds: 5));
        expect(states.last, isA<RunCompleted>());

        final progressStates = states.whereType<RunInProgress>();
        final allActive = progressStates.expand((s) => s.active).toList();

        final reasoningSnapshots = allActive.where(
          (s) => s.reasoningPreview.isNotEmpty,
        );
        expect(
          reasoningSnapshots,
          isNotEmpty,
          reason: 'Should have reasoning previews',
        );
        expect(
          reasoningSnapshots.last.reasoningPreview,
          contains('Let me think...'),
          reason: 'Reasoning preview missing',
        );

        final answerSnapshots = allActive.where(
          (s) => s.answerPreview.isNotEmpty,
        );
        expect(
          answerSnapshots,
          isNotEmpty,
          reason: 'Should have answer previews',
        );
        final answerText = answerSnapshots.last.answerPreview;
        expect(
          answerText,
          contains('int answer() => 42;'),
          reason: 'Answer preview missing code',
        );

        final tokenSnapshots = allActive.where(
          (s) => s.promptTokens != null || s.completionTokens != null,
        );
        expect(tokenSnapshots, isNotEmpty, reason: 'Should have token info');

        final completed = states.last as RunCompleted;
        final result = completed.results.single;
        expect(result.response.rawText, contains('int answer() => 42;'));
        expect(result.response.rawText, isNot(contains('Let me think...')));
        expect(result.response.promptTokens, 10);
        expect(result.response.completionTokens, 5);

        await sub.cancel();
        await bloc.close();
        await db.close();
        tmp.deleteSync(recursive: true);
      },
    );
  });
}
