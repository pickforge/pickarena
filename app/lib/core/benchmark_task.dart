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

class TaskNegativeCase {
  const TaskNegativeCase({
    required this.id,
    required this.description,
    required this.solution,
  });

  final String id;
  final String description;
  final ReferenceSolution solution;
}

enum BenchmarkTrack { codegen, agentic }

extension BenchmarkTrackLabel on BenchmarkTrack {
  String get label => switch (this) {
    BenchmarkTrack.codegen => 'Codegen',
    BenchmarkTrack.agentic => 'Agentic',
  };
}

enum TaskTag {
  ui,
  stateBloc,
  stateRiverpod,
  navigation,
  testing,
  golden,
  accessibility,
  localization,
  platform,
  buildCodegen,
  performance,
  refactor,
  bugfix,
  planning,
  codeReview,
}

extension TaskTagLabel on TaskTag {
  String get slug => switch (this) {
    TaskTag.ui => 'ui',
    TaskTag.stateBloc => 'state_bloc',
    TaskTag.stateRiverpod => 'state_riverpod',
    TaskTag.navigation => 'navigation',
    TaskTag.testing => 'testing',
    TaskTag.golden => 'golden',
    TaskTag.accessibility => 'accessibility',
    TaskTag.localization => 'localization',
    TaskTag.platform => 'platform',
    TaskTag.buildCodegen => 'build_codegen',
    TaskTag.performance => 'performance',
    TaskTag.refactor => 'refactor',
    TaskTag.bugfix => 'bugfix',
    TaskTag.planning => 'planning',
    TaskTag.codeReview => 'code_review',
  };

  String get label => switch (this) {
    TaskTag.ui => 'UI',
    TaskTag.stateBloc => 'BLoC',
    TaskTag.stateRiverpod => 'Riverpod',
    TaskTag.navigation => 'Navigation',
    TaskTag.testing => 'Testing',
    TaskTag.golden => 'Golden',
    TaskTag.accessibility => 'Accessibility',
    TaskTag.localization => 'Localization',
    TaskTag.platform => 'Platform',
    TaskTag.buildCodegen => 'Build/codegen',
    TaskTag.performance => 'Performance',
    TaskTag.refactor => 'Refactor',
    TaskTag.bugfix => 'Bug fix',
    TaskTag.planning => 'Planning',
    TaskTag.codeReview => 'Code review',
  };
}

enum TaskDifficulty { unspecified, easy, medium, hard }

extension TaskDifficultyLabel on TaskDifficulty {
  String get label => switch (this) {
    TaskDifficulty.unspecified => 'Unspecified',
    TaskDifficulty.easy => 'Easy',
    TaskDifficulty.medium => 'Medium',
    TaskDifficulty.hard => 'Hard',
  };
}

enum TaskPlatform { linux, macos, windows, web, android, ios }

extension TaskPlatformLabel on TaskPlatform {
  String get label => switch (this) {
    TaskPlatform.linux => 'Linux',
    TaskPlatform.macos => 'macOS',
    TaskPlatform.windows => 'Windows',
    TaskPlatform.web => 'Web',
    TaskPlatform.android => 'Android',
    TaskPlatform.ios => 'iOS',
  };
}

abstract class BenchmarkTask {
  String get id;
  int get version => 1;
  Category get category;
  BenchmarkTrack get track => BenchmarkTrack.codegen;
  Set<TaskTag> get tags => const {};
  TaskDifficulty get difficulty => TaskDifficulty.unspecified;
  Duration? get timeout => null;
  Set<TaskPlatform> get platformRequirements => const {};
  String get prompt;
  Map<String, String> get fixtures;
  TaskWorkspace get workspace =>
      TaskWorkspace.fromFixtures(fixtures, instruction: prompt);
  List<VerifierFixture> get hiddenVerifiers => const [];
  ReferenceSolution? get referenceSolution => null;
  List<TaskNegativeCase> get negativeCases => const [];
  String? get judgeRubric;
  String get generatedCodePath;
  bool get isFlutter => false;
  Future<void> ensureLoaded() async {}
  List<Evaluator> evaluatorsFor(EvaluatorConfig config);

  ReferencePlan? get referencePlan => null;

  bool get hasReferencePlan => referencePlan != null;
}
