import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

abstract class BenchmarkTask {
  String get id;
  Category get category;
  String get prompt;
  Map<String, String> get fixtures;
  List<Evaluator> get evaluators;
  String? get judgeRubric;
}
