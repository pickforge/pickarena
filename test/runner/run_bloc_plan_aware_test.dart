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
  Future<List<ModelInfo>> listModels() async => [const ModelInfo(id: 'rec-1')];
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

class _PerCallRecordingProvider implements ModelProvider {
  final calls = <({String prompt, String model})>[];
  @override
  String get id => 'rec2';
  @override
  String get displayName => 'Rec2';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<ModelInfo>> listModels() async => [const ModelInfo(id: 'rec2-1')];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    calls.add((prompt: prompt, model: model));
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
    'pubspec.yaml': 'name: tmp\nenvironment:\n  sdk: ">=3.5.0 <4.0.0"\n',
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

class _PlanCarryingTaskB extends BenchmarkTask {
  @override
  String get id => 'plan-task-b';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'do other thing';
  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': 'name: tmp\nenvironment:\n  sdk: ">=3.5.0 <4.0.0"\n',
  };
  @override
  String get generatedCodePath => 'lib/answer.dart';
  @override
  String? get judgeRubric => null;
  @override
  ReferencePlan? get referencePlan =>
      const ReferencePlan(version: 2, markdown: 'OTHER:\n1. do\n2. code');
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [_AlwaysPass()];
}

void main() {
  test(
    'useReferencePlan = true injects plan into prompt and persists planId',
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

      bloc.add(
        StartRun(
          tasks: [_PlanCarryingTask()],
          providers: [provider],
          modelsByProvider: const {
            'rec': ['rec-1'],
          },
          evaluatorConfig: const EvaluatorConfig(),
          useReferencePlan: true,
        ),
      );

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
    },
  );

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

    bloc.add(
      StartRun(
        tasks: [_PlanCarryingTask()],
        providers: [provider],
        modelsByProvider: const {
          'rec': ['rec-1'],
        },
        evaluatorConfig: const EvaluatorConfig(),
      ),
    );

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

  test('multiple models for one task share planId', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_plan_multi_');
    final db = AppDatabase(NativeDatabase.memory());
    final provider = _RecordingProvider();

    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      planDao: PlanDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-plan-multi',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [_PlanCarryingTask()],
        providers: [provider],
        modelsByProvider: const {
          'rec': ['rec-1', 'rec-2'],
        },
        evaluatorConfig: const EvaluatorConfig(),
        useReferencePlan: true,
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunCompleted>());

    final completed = states.last as RunCompleted;
    expect(completed.results.length, 2);
    final planIds = completed.results.map((r) => r.planId).toSet();
    expect(planIds.length, 1);
    expect(planIds.single, startsWith('ref-plan-task-v1'));

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('two tasks each get their own reference plan', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_plan_two_');
    final db = AppDatabase(NativeDatabase.memory());
    final provider = _PerCallRecordingProvider();

    final bloc = RunBloc(
      workdirManager: WorkdirManager(root: tmp),
      runDao: RunDao(db),
      planDao: PlanDao(db),
      now: DateTime.now,
      idGenerator: () => 'run-plan-two',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(
      StartRun(
        tasks: [_PlanCarryingTask(), _PlanCarryingTaskB()],
        providers: [provider],
        modelsByProvider: const {
          'rec2': ['rec2-1'],
        },
        evaluatorConfig: const EvaluatorConfig(),
        useReferencePlan: true,
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states.last, isA<RunCompleted>());

    final completed = states.last as RunCompleted;
    expect(completed.results.length, 2);

    final resultA = completed.results.firstWhere(
      (r) => r.taskId == 'plan-task',
    );
    final resultB = completed.results.firstWhere(
      (r) => r.taskId == 'plan-task-b',
    );
    expect(resultA.planId, startsWith('ref-plan-task-v1'));
    expect(resultB.planId, startsWith('ref-plan-task-b-v2'));

    final callA = provider.calls.firstWhere(
      (c) => c.prompt.contains('do thing'),
    );
    final callB = provider.calls.firstWhere(
      (c) => c.prompt.contains('do other thing'),
    );
    expect(callA.prompt, contains('1. think'));
    expect(callA.prompt, contains('REFERENCE PLAN'));
    expect(callB.prompt, contains('1. do'));
    expect(callB.prompt, contains('REFERENCE PLAN'));

    await sub.cancel();
    await bloc.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });
}
