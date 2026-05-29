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
