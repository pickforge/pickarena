import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class ReferencePlan {
  const ReferencePlan({required this.version, required this.markdown});

  final int version;
  final String markdown;
}

abstract class BenchmarkTask {
  String get id;
  Category get category;
  String get prompt;
  Map<String, String> get fixtures;
  String? get judgeRubric;
  String get generatedCodePath;
  bool get isFlutter => false;
  Future<void> ensureLoaded() async {}
  List<Evaluator> evaluatorsFor(EvaluatorConfig config);

  ReferencePlan? get referencePlan => null;

  bool get hasReferencePlan => referencePlan != null;
}
