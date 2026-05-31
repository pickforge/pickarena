import 'evaluator.dart';

class CoverageEvaluator implements Evaluator {
  @override
  String get id => 'coverage';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    return EvaluationResult(id: id, score: 0.5);
  }
}
