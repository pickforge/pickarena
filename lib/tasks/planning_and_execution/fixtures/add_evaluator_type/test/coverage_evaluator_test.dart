import 'package:test/test.dart';
import '../lib/coverage_evaluator.dart';
import '../lib/evaluator.dart';

void main() {
  test('CoverageEvaluator implements Evaluator', () {
    final e = CoverageEvaluator();
    expect(e, isA<Evaluator>());
  });

  test('CoverageEvaluator id is "coverage"', () {
    expect(CoverageEvaluator().id, 'coverage');
  });

  test('CoverageEvaluator returns a score in [0, 1]', () async {
    final e = CoverageEvaluator();
    final result = await e.evaluate(EvaluationContext(workDir: '/tmp'));
    expect(result.id, 'coverage');
    expect(result.score, inInclusiveRange(0.0, 1.0));
  });
}
