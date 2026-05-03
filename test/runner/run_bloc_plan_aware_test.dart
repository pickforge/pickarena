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
