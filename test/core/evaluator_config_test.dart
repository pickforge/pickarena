import 'package:dart_arena/core/evaluator_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasJudge false when both null', () {
    const c = EvaluatorConfig();
    expect(c.hasJudge, isFalse);
  });

  test('hasJudge false when only one set', () {
    expect(
      const EvaluatorConfig(judgeModel: 'gpt-4o-mini').hasJudge,
      isFalse,
    );
  });
}
