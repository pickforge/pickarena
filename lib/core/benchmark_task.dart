import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_workspace.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class ReferencePlan {
  const ReferencePlan({required this.version, required this.markdown});

  final int version;
  final String markdown;
}

enum BenchmarkTrack { codegen, agentic }

abstract class BenchmarkTask {
  String get id;
  int get version => 1;
  Category get category;
  BenchmarkTrack get track => BenchmarkTrack.codegen;
  String get prompt;
  Map<String, String> get fixtures;
  TaskWorkspace get workspace =>
      TaskWorkspace.fromFixtures(fixtures, instruction: prompt);
  List<VerifierFixture> get hiddenVerifiers => const [];
  ReferenceSolution? get referenceSolution => null;
  String? get judgeRubric;
  String get generatedCodePath;
  bool get isFlutter => false;
  Future<void> ensureLoaded() async {}
  List<Evaluator> evaluatorsFor(EvaluatorConfig config);

  ReferencePlan? get referencePlan => null;

  bool get hasReferencePlan => referencePlan != null;
}
