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
    this.kind = TaskNegativeCaseKind.custom,
    this.rootPath,
  });

  final String id;
  final String description;
  final ReferenceSolution solution;
  final TaskNegativeCaseKind kind;
  final String? rootPath;
}

enum TaskNegativeCaseKind { noop, apiBreaking, overfit, minimalBad, custom }

extension TaskNegativeCaseKindLabel on TaskNegativeCaseKind {
  String get wireName => switch (this) {
    TaskNegativeCaseKind.noop => 'noop',
    TaskNegativeCaseKind.apiBreaking => 'api_breaking',
    TaskNegativeCaseKind.overfit => 'overfit',
    TaskNegativeCaseKind.minimalBad => 'minimal_bad',
    TaskNegativeCaseKind.custom => 'custom',
  };

  static TaskNegativeCaseKind fromWireName(String value) {
    return switch (value.trim()) {
      'noop' => TaskNegativeCaseKind.noop,
      'api_breaking' ||
      'api-breaking' ||
      'apiBreaking' => TaskNegativeCaseKind.apiBreaking,
      'overfit' => TaskNegativeCaseKind.overfit,
      'minimal_bad' ||
      'minimal-bad' ||
      'minimalBad' => TaskNegativeCaseKind.minimalBad,
      'custom' => TaskNegativeCaseKind.custom,
      final unknown => throw FormatException(
        'Unsupported negative case kind: $unknown',
      ),
    };
  }
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

enum TaskCorpus { publicDiagnostic, privateOfficial }

extension TaskCorpusLabel on TaskCorpus {
  String get wireName => switch (this) {
    TaskCorpus.publicDiagnostic => 'public_diagnostic',
    TaskCorpus.privateOfficial => 'private_official',
  };

  static TaskCorpus fromWireName(String value) {
    return switch (value.trim()) {
      'public_diagnostic' ||
      'public-diagnostic' ||
      'publicDiagnostic' => TaskCorpus.publicDiagnostic,
      'private_official' ||
      'private-official' ||
      'privateOfficial' => TaskCorpus.privateOfficial,
      final unknown => throw FormatException(
        'Unsupported task corpus: $unknown',
      ),
    };
  }
}

enum TaskReleaseStatus { active, retired }

extension TaskReleaseStatusLabel on TaskReleaseStatus {
  String get wireName => switch (this) {
    TaskReleaseStatus.active => 'active',
    TaskReleaseStatus.retired => 'retired',
  };

  static TaskReleaseStatus fromWireName(String value) {
    return switch (value.trim()) {
      'active' => TaskReleaseStatus.active,
      'retired' => TaskReleaseStatus.retired,
      final unknown => throw FormatException(
        'Unsupported task release status: $unknown',
      ),
    };
  }
}

class TaskReleaseMetadata {
  const TaskReleaseMetadata({
    this.corpus = TaskCorpus.publicDiagnostic,
    this.status = TaskReleaseStatus.active,
    this.releaseCycle,
  });

  final TaskCorpus corpus;
  final TaskReleaseStatus status;
  final String? releaseCycle;

  Map<String, Object?> toJson() => {
    'corpus': corpus.wireName,
    'status': status.wireName,
    if (releaseCycle != null) 'releaseCycle': releaseCycle,
  };
}

class TaskResourceLimits {
  const TaskResourceLimits({
    this.cpus,
    this.memoryMb,
    this.maxProcesses,
    this.maxOutputBytes,
  });

  final int? cpus;
  final int? memoryMb;
  final int? maxProcesses;
  final int? maxOutputBytes;

  TaskResourceLimits withDefaults(TaskResourceLimits defaults) {
    return TaskResourceLimits(
      cpus: cpus ?? defaults.cpus,
      memoryMb: memoryMb ?? defaults.memoryMb,
      maxProcesses: maxProcesses ?? defaults.maxProcesses,
      maxOutputBytes: maxOutputBytes ?? defaults.maxOutputBytes,
    );
  }

  Map<String, Object?> toJson() => {
    if (cpus != null) 'cpus': cpus,
    if (memoryMb != null) 'memoryMb': memoryMb,
    if (maxProcesses != null) 'maxProcesses': maxProcesses,
    if (maxOutputBytes != null) 'maxOutputBytes': maxOutputBytes,
  };
}

const defaultTaskResourceLimits = TaskResourceLimits(
  cpus: 2,
  memoryMb: 8192,
  maxProcesses: 64,
  maxOutputBytes: 1024 * 1024,
);

abstract class BenchmarkTask {
  String get id;
  int get version => 1;
  Category get category;
  BenchmarkTrack get track => BenchmarkTrack.codegen;
  Set<TaskTag> get tags => const {};
  TaskDifficulty get difficulty => TaskDifficulty.unspecified;
  Duration? get timeout => null;
  Set<TaskPlatform> get platformRequirements => const {};
  TaskReleaseMetadata get releaseMetadata => const TaskReleaseMetadata();
  bool get allowInternet => false;
  TaskResourceLimits get resourceLimits => const TaskResourceLimits();
  TaskResourceLimits get effectiveResourceLimits =>
      resourceLimits.withDefaults(defaultTaskResourceLimits);
  String get prompt;
  Map<String, String> get fixtures;
  TaskWorkspace get workspace =>
      TaskWorkspace.fromFixtures(fixtures, instruction: prompt);
  List<VerifierFixture> get hiddenVerifiers => const [];
  ReferenceSolution? get referenceSolution => null;
  List<TaskNegativeCase> get negativeCases => const [];
  Set<TaskNegativeCaseKind> get requiredNegativeCaseKinds => const {
    TaskNegativeCaseKind.noop,
    TaskNegativeCaseKind.apiBreaking,
  };
  String? get judgeRubric;
  String get generatedCodePath;
  bool get isFlutter => false;
  Future<void> ensureLoaded() async {}
  List<Evaluator> evaluatorsFor(EvaluatorConfig config);

  ReferencePlan? get referencePlan => null;

  bool get hasReferencePlan => referencePlan != null;
}
