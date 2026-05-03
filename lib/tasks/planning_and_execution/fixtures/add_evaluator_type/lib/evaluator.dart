abstract class Evaluator {
  String get id;
  Future<EvaluationResult> evaluate(EvaluationContext ctx);
}

class EvaluationResult {
  EvaluationResult({required this.id, required this.score});
  final String id;
  final double score;
}

class EvaluationContext {
  EvaluationContext({required this.workDir});
  final String workDir;
}
