import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';

abstract class Evaluator {
  String get id;
  Future<EvaluationResult> evaluate(EvaluationContext ctx);
}
