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
      now: () => DateTime.now(),
      idGenerator: () => 'run-test',
    );

    final states = <RunState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(StartRun(
      tasks: [_StubTask()],
      providers: [_FakeProvider()],
      modelByProvider: const {'fake': 'fake-1'},
    ));

    await Future<void>.delayed(const Duration(seconds: 1));
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
