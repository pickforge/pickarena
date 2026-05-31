import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class CoverageEvaluator implements Evaluator {
  @override
  String get id => 'coverage';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    return EvaluationResult(
      evaluatorId: id,
      passed: true,
      score: 0.5,
      rationale: 'coverage evaluation',
    );
  }
}
