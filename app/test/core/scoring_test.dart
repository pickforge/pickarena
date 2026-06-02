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
      expect(
        aggregate([a, b], const {'compile': 0.5, 'test': 1.0}),
        closeTo(1.0 / 3.0, 1e-9),
      );
    });

    test('missing weight defaults to 1.0', () {
      const a = EvaluationResult(evaluatorId: 'foo', passed: true, score: 1.0);
      const b = EvaluationResult(evaluatorId: 'bar', passed: true, score: 0.0);
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

    test('compile failure caps high secondary scores', () {
      const results = [
        EvaluationResult(evaluatorId: 'compile', passed: false, score: 0.0),
        EvaluationResult(evaluatorId: 'llm_judge', passed: true, score: 1.0),
        EvaluationResult(evaluatorId: 'diff_size', passed: true, score: 1.0),
      ];

      expect(aggregate(results, defaultEvaluatorWeights), 0.20);
    });

    test('analyze failure caps high secondary scores', () {
      const results = [
        EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
        EvaluationResult(evaluatorId: 'analyze', passed: false, score: 0.0),
        EvaluationResult(evaluatorId: 'llm_judge', passed: true, score: 1.0),
      ];

      expect(aggregate(results, defaultEvaluatorWeights), 0.35);
    });

    test('test correctness failures cap aggregate at 0.60', () {
      const results = [
        EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
        EvaluationResult(evaluatorId: 'analyze', passed: true, score: 1.0),
        EvaluationResult(evaluatorId: 'test', passed: false, score: 0.0),
        EvaluationResult(evaluatorId: 'llm_judge', passed: true, score: 1.0),
      ];

      expect(
        aggregate(results, defaultEvaluatorWeights),
        lessThanOrEqualTo(0.60),
      );
    });

    test('multiple objective failures apply the lowest cap', () {
      const results = [
        EvaluationResult(evaluatorId: 'compile', passed: false, score: 0.0),
        EvaluationResult(evaluatorId: 'test', passed: false, score: 0.0),
        EvaluationResult(evaluatorId: 'llm_judge', passed: true, score: 1.0),
      ];

      expect(aggregate(results, defaultEvaluatorWeights), 0.20);
    });

    test('custom hidden verifier ids ending in _hidden cap aggregate', () {
      const results = [
        EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
        EvaluationResult(evaluatorId: 'analyze', passed: true, score: 1.0),
        EvaluationResult(
          evaluatorId: 'reference_hidden',
          passed: false,
          score: 0.0,
        ),
        EvaluationResult(evaluatorId: 'llm_judge', passed: true, score: 1.0),
        EvaluationResult(evaluatorId: 'diff_size', passed: true, score: 1.0),
      ];

      expect(aggregate(results, defaultEvaluatorWeights), 0.60);
    });

    test(
      'ignored and skipped secondary results have zero effective weight',
      () {
        const results = [
          EvaluationResult(evaluatorId: 'compile', passed: true, score: 0.5),
          EvaluationResult(
            evaluatorId: 'llm_judge',
            passed: false,
            score: 1.0,
            details: {'ignored': true, 'reason': 'objective_failure'},
          ),
          EvaluationResult(
            evaluatorId: 'diff_size',
            passed: true,
            score: 1.0,
            details: {'skipped': true},
          ),
        ];

        expect(aggregate(results, defaultEvaluatorWeights), 0.5);
      },
    );

    test('blocked evaluators have zero effective weight', () {
      const results = [
        EvaluationResult(evaluatorId: 'compile', passed: false, score: 0.0),
        EvaluationResult(evaluatorId: 'analyze', passed: true, score: 1.0),
        EvaluationResult(
          evaluatorId: 'test',
          passed: false,
          score: 0.0,
          details: {'blocked': true, 'blocked_by': 'compile'},
        ),
      ];

      expect(aggregate(results, defaultEvaluatorWeights), 0.20);
    });

    test('non-objective failures are not aggregate cap reasons', () {
      const results = [
        EvaluationResult(
          evaluatorId: 'agent_harness',
          passed: false,
          score: 0.0,
        ),
        EvaluationResult(evaluatorId: 'llm_judge', passed: true, score: 1.0),
      ];

      expect(
        aggregate(results, const {'agent_harness': 1, 'llm_judge': 1}),
        0.5,
      );
    });
  });

  test('defaultEvaluatorWeights covers all built-in evaluators', () {
    expect(
      defaultEvaluatorWeights.keys,
      containsAll(<String>[
        'compile',
        'analyze',
        'test',
        'hidden_test',
        'widget_tree',
        'llm_judge',
        'diff_size',
      ]),
    );
  });
}
