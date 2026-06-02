import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/codegen_task_executor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/headless_fakes.dart';

void main() {
  test(
    'compile failure blocks runtime evaluators without running them',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'codegen_executor_blocking_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final analyze = _SpyEvaluator('analyze', result: _pass('analyze'));
      final publicTest = _SpyEvaluator('test', result: _pass('test'));
      final hiddenTest = _SpyEvaluator(
        'sample_hidden',
        result: _pass('sample_hidden'),
      );
      final task = _BlockingTask(
        evaluators: [
          const _CompileFailureEvaluator(),
          analyze,
          publicTest,
          hiddenTest,
        ],
      );
      final executor = CodegenTaskExecutor(
        workdirManager: NoOpPrepareWorkdirManager(root: root),
        weights: const {},
        now: () => DateTime.utc(2026, 6, 2),
      );

      final result = await executor.run(
        runId: 'blocking-run',
        task: task,
        provider: DeterministicFakeProvider(
          rawText: '```dart\nString answer() => "generated";\n```',
        ),
        modelId: 'fake-headless-model',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      expect(analyze.calls, 1);
      expect(publicTest.calls, 0);
      expect(hiddenTest.calls, 0);

      final publicTestResult = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'test',
      );
      expect(publicTestResult.passed, isFalse);
      expect(publicTestResult.rationale, 'blocked by compile');
      expect(publicTestResult.details['blocked'], isTrue);
      expect(publicTestResult.details['blocked_by'], 'compile');

      final hiddenResult = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'sample_hidden',
      );
      expect(hiddenResult.details['blocked_by'], 'compile');
      expect(result.failureTag, 'compile_failed');
      expect(result.primaryPass, isFalse);
    },
  );
}

class _BlockingTask extends BenchmarkTask {
  _BlockingTask({required this.evaluators});

  final List<Evaluator> evaluators;

  @override
  String get id => 'phase1.blocking';

  @override
  Category get category => Category.bugFix;

  @override
  String get prompt => 'Generate answer.dart';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': '''
name: phase1_blocking
environment:
  sdk: ">=3.5.0 <4.0.0"
''',
  };

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => evaluators;
}

class _CompileFailureEvaluator implements Evaluator {
  const _CompileFailureEvaluator();

  @override
  String get id => 'compile';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    return const EvaluationResult(
      evaluatorId: 'compile',
      passed: false,
      score: 0.0,
      rationale: 'synthetic compile failure',
    );
  }
}

class _SpyEvaluator implements Evaluator {
  _SpyEvaluator(this.id, {required this.result});

  @override
  final String id;
  final EvaluationResult result;
  var calls = 0;

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    calls++;
    return result;
  }
}

EvaluationResult _pass(String evaluatorId) {
  return EvaluationResult(evaluatorId: evaluatorId, passed: true, score: 1.0);
}
