import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/objective_evaluation.dart';
import 'package:test/test.dart';

void main() {
  group('runObjectiveEvaluators', () {
    test('runs evaluators in order, threading prior results', () async {
      final evaluatorA = _FakeEvaluator('a', result: _pass('a'));
      final evaluatorB = _FakeEvaluator('b', result: _pass('b'));
      final evaluatorC = _FakeEvaluator('c', result: _pass('c'));

      final evaluations = await runObjectiveEvaluators(
        evaluators: [evaluatorA, evaluatorB, evaluatorC],
        evaluations: <EvaluationResult>[],
        contextFor: _contextFor,
      );

      expect(evaluations.map((e) => e.evaluatorId), ['a', 'b', 'c']);
      expect(evaluatorA.observedPreviousResults, isEmpty);
      expect(evaluatorB.observedPreviousResults!.map((e) => e.evaluatorId), [
        'a',
      ]);
      expect(evaluatorC.observedPreviousResults!.map((e) => e.evaluatorId), [
        'a',
        'b',
      ]);
    });

    test('gives every evaluator an immutable snapshot, including blocked '
        'placeholders inserted for prior evaluators', () async {
      final compile = _FakeEvaluator(
        'compile',
        result: const EvaluationResult(
          evaluatorId: 'compile',
          passed: false,
          score: 0.0,
          rationale: 'synthetic compile failure',
        ),
      );
      // 'test' and 'sample_hidden' are objective/runtime evaluator ids, so
      // the compile failure above blocks them without invoking evaluate.
      final publicTest = _FakeEvaluator('test', result: _pass('test'));
      final hiddenTest = _FakeEvaluator(
        'sample_hidden',
        result: _pass('sample_hidden'),
      );
      // 'llm_judge' is not an objective evaluator id, so it still runs and
      // observes the blocked placeholders ahead of it.
      final judge = _FakeEvaluator('llm_judge', result: _pass('llm_judge'));

      final evaluations = await runObjectiveEvaluators(
        evaluators: [compile, publicTest, hiddenTest, judge],
        evaluations: <EvaluationResult>[],
        contextFor: _contextFor,
      );

      expect(publicTest.calls, 0);
      expect(hiddenTest.calls, 0);
      expect(judge.calls, 1);

      final snapshot = judge.observedPreviousResults!;
      expect(snapshot.map((e) => e.evaluatorId), [
        'compile',
        'test',
        'sample_hidden',
      ]);
      expect(snapshot[1].details[blockedByDetailKey], 'compile');
      expect(snapshot[2].details[blockedByDetailKey], 'compile');

      // The snapshot is a defensive copy: mutating the live evaluations
      // list afterwards must not retroactively change what the evaluator
      // observed.
      evaluations.add(_pass('after'));
      expect(snapshot.length, 3);
      expect(() => snapshot.add(_pass('mutate')), throwsUnsupportedError);
    });

    test(
      'cancellation before an evaluator aborts without invoking it',
      () async {
        final evaluatorA = _FakeEvaluator('a', result: _pass('a'));
        final evaluatorB = _FakeEvaluator('b', result: _pass('b'));
        final evaluatorC = _FakeEvaluator('c', result: _pass('c'));
        final evaluations = <EvaluationResult>[];
        var checkCalls = 0;

        await expectLater(
          () => runObjectiveEvaluators(
            evaluators: [evaluatorA, evaluatorB, evaluatorC],
            evaluations: evaluations,
            contextFor: _contextFor,
            cancellationCheck: () {
              checkCalls++;
              // Call 1: before A. Call 2: after A. Call 3: before B - abort.
              if (checkCalls == 3) throw _CancelledException();
            },
          ),
          throwsA(isA<_CancelledException>()),
        );

        expect(evaluatorA.calls, 1);
        expect(evaluatorB.calls, 0);
        expect(evaluatorC.calls, 0);
        expect(evaluations.map((e) => e.evaluatorId), ['a']);
      },
    );

    test(
      'cancellation after an evaluator discards its unrecorded result',
      () async {
        final evaluatorA = _FakeEvaluator('a', result: _pass('a'));
        final evaluatorB = _FakeEvaluator('b', result: _pass('b'));
        final evaluations = <EvaluationResult>[];
        var checkCalls = 0;

        await expectLater(
          () => runObjectiveEvaluators(
            evaluators: [evaluatorA, evaluatorB],
            evaluations: evaluations,
            contextFor: _contextFor,
            cancellationCheck: () {
              checkCalls++;
              // Call 1: before A. Call 2: after A - abort before A is added.
              if (checkCalls == 2) throw _CancelledException();
            },
          ),
          throwsA(isA<_CancelledException>()),
        );

        expect(evaluatorA.calls, 1);
        expect(evaluatorB.calls, 0);
        // A ran but its result was never appended: the after-check aborts
        // before the `evaluations.add(result)` line.
        expect(evaluations, isEmpty);
      },
    );
  });

  group('blockEvaluatorsForHardFailure', () {
    test('dedups a repeated hard failure and keeps blocked placeholders '
        'referencing the earlier blocker', () {
      final evaluations = <EvaluationResult>[];
      final firstFailure = environmentFailureEvaluation(
        rationale: 'first blocker',
        stderr: 'boom once',
      );

      blockEvaluatorsForHardFailure(
        evaluations: evaluations,
        evaluators: [_FakeEvaluator('a', result: _pass('a'))],
        failure: firstFailure,
      );

      final secondFailure = environmentFailureEvaluation(
        rationale: 'second blocker',
        stderr: 'boom twice',
      );
      blockEvaluatorsForHardFailure(
        evaluations: evaluations,
        evaluators: [_FakeEvaluator('b', result: _pass('b'))],
        failure: secondFailure,
      );

      // Only one 'environment' failure is recorded; the second call is a
      // no-op for the failure itself because a hard blocker already exists.
      expect(
        evaluations.where((e) => e.evaluatorId == 'environment').length,
        1,
      );
      expect(
        evaluations
            .singleWhere((e) => e.evaluatorId == 'environment')
            .rationale,
        'first blocker',
      );

      final blockedA = evaluations.singleWhere((e) => e.evaluatorId == 'a');
      final blockedB = evaluations.singleWhere((e) => e.evaluatorId == 'b');
      for (final blocked in [blockedA, blockedB]) {
        expect(blocked.details[blockedByDetailKey], 'environment');
        expect(blocked.details[blockedByRationaleDetailKey], 'first blocker');
      }
    });
  });

  group('finalizeObjectiveEvaluation', () {
    test('derives aggregate/primaryPass/failureTag for a passing run', () {
      final outcome = finalizeObjectiveEvaluation(
        evaluations: [_pass('compile'), _pass('analyze'), _pass('test')],
        weights: const {'compile': 0.5, 'analyze': 0.5, 'test': 1.0},
      );

      expect(outcome.aggregateScore, 1.0);
      expect(outcome.primaryPass, isTrue);
      expect(outcome.failureTag, 'pass');
    });

    test(
      'derives aggregate/primaryPass/failureTag for a public test failure',
      () {
        final outcome = finalizeObjectiveEvaluation(
          evaluations: [
            _pass('compile'),
            _pass('analyze'),
            const EvaluationResult(
              evaluatorId: 'test',
              passed: false,
              score: 0.0,
            ),
          ],
          weights: const {'compile': 0.5, 'analyze': 0.5, 'test': 1.0},
        );

        expect(outcome.aggregateScore, 0.5);
        expect(outcome.primaryPass, isFalse);
        expect(outcome.failureTag, 'public_tests_failed');
      },
    );
  });
}

EvaluationResult _pass(String id) =>
    EvaluationResult(evaluatorId: id, passed: true, score: 1.0);

EvaluationContext _contextFor(List<EvaluationResult> previousResults) {
  return EvaluationContext(
    workDir: Directory('unused'),
    response: const ModelResponse(
      rawText: 'code',
      extractedCode: 'code',
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    ),
    task: _FakeTask(),
    previousResults: previousResults,
  );
}

class _CancelledException implements Exception {}

class _FakeEvaluator implements Evaluator {
  _FakeEvaluator(this.id, {required this.result});

  @override
  final String id;
  final EvaluationResult result;
  var calls = 0;
  List<EvaluationResult>? observedPreviousResults;

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    calls++;
    observedPreviousResults = ctx.previousResults;
    return result;
  }
}

class _FakeTask extends BenchmarkTask {
  @override
  String get id => 'fake.objective_evaluation';

  @override
  Category get category => Category.bugFix;

  @override
  String get prompt => 'unused';

  @override
  Map<String, String> get fixtures => const {};

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}
