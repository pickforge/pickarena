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

    bloc.add(StartRun(
      tasks: [_StubTask()],
      providers: [_FakeProvider()],
      modelByProvider: const {'fake': 'fake-1'},
      evaluatorConfig: const EvaluatorConfig(),
    ));

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunCompleted>());
    final completed = states.last as RunCompleted;
    expect(completed.results.first.aggregateScore, 1.0);

    await sub.cancel();
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
      now: () => DateTime.now(),
      idGenerator: () => 'run-test',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(StartRun(
      tasks: [_BrokenPubspecTask()],
      providers: [_FakeProvider()],
      modelByProvider: const {'fake': 'fake-1'},
      evaluatorConfig: const EvaluatorConfig(),
    ));

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
  }, timeout: const Timeout(Duration(minutes: 2)));

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

    bloc.add(StartRun(
      tasks: [_TwoEvaluatorTask([passEval, lowEval])],
      providers: [_FakeProvider()],
      modelByProvider: const {'fake': 'fake-1'},
      evaluatorConfig: const EvaluatorConfig(),
    ));

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunCompleted>());
    final completed = states.last as RunCompleted;
    // (1.0 * 4 + 0.2 * 1) / (4 + 1) = 4.2 / 5 = 0.84
    expect(completed.results.single.aggregateScore, closeTo(0.84, 1e-9));

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });
}
