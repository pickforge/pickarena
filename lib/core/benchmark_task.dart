import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

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
}
