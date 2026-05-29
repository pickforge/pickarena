import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:equatable/equatable.dart';

enum ScoreDimension {
  overall,
  intelligence,
  speed,
  elegance,
  reliability;

  String get label => switch (this) {
    ScoreDimension.overall => 'Overall',
    ScoreDimension.intelligence => 'Intelligence',
    ScoreDimension.speed => 'Speed',
    ScoreDimension.elegance => 'Elegance',
    ScoreDimension.reliability => 'Reliability',
  };
}

class Dimensions extends Equatable {
  const Dimensions({
    required this.intelligence,
    required this.speed,
    required this.elegance,
    required this.reliability,
    required this.problems,
  });

  final double intelligence;
  final double speed;
  final double elegance;
  final double reliability;
  final int problems;

  static const double latencyLoMs = 2000;
  static const double latencyHiMs = 60000;
  static const double reliabilityThreshold = 0.5;

  double get overall => (intelligence + speed + elegance + reliability) / 4.0;

  double byDimension(ScoreDimension d) => switch (d) {
    ScoreDimension.overall => overall,
    ScoreDimension.intelligence => intelligence,
    ScoreDimension.speed => speed,
    ScoreDimension.elegance => elegance,
    ScoreDimension.reliability => reliability,
  };

  static const Dimensions zero = Dimensions(
    intelligence: 0,
    speed: 0,
    elegance: 0,
    reliability: 0,
    problems: 0,
  );

  static Dimensions fromTaskRuns(
    List<TaskRun> taskRuns,
    Map<String, List<Evaluation>> evalsByTaskRunId,
  ) {
    if (taskRuns.isEmpty) return Dimensions.zero;
    return _computeDimensions(taskRuns, evalsByTaskRunId);
  }

  @override
  List<Object?> get props => [
    intelligence,
    speed,
    elegance,
    reliability,
    problems,
  ];
}

const _correctnessEvaluatorIds = {
  'compile',
  'analyze',
  'test',
  'hidden_test',
  'test_author',
  'widget_tree',
};

Dimensions _computeDimensions(
  List<TaskRun> taskRuns,
  Map<String, List<Evaluation>> evalsByTaskRunId,
) {
  final reliabilityPasses = taskRuns
      .where((t) => t.aggregateScore >= Dimensions.reliabilityThreshold)
      .length;
  final reliability = reliabilityPasses / taskRuns.length;

  final latencies = taskRuns.map((t) => t.latencyMs.toDouble()).toList()
    ..sort();
  final median = latencies[latencies.length ~/ 2];
  const span = Dimensions.latencyHiMs - Dimensions.latencyLoMs;
  final speed = (1 - (median - Dimensions.latencyLoMs) / span)
      .clamp(0.0, 1.0)
      .toDouble();

  var intelligenceNum = 0.0;
  var intelligenceDen = 0.0;
  var eleganceSum = 0.0;
  var eleganceCount = 0;
  var problems = 0;
  for (final tr in taskRuns) {
    for (final e in evalsByTaskRunId[tr.id] ?? const <Evaluation>[]) {
      if (!e.passed) problems++;
      if (e.evaluatorId == 'llm_judge' || e.evaluatorId == 'diff_size') {
        eleganceSum += e.score;
        eleganceCount++;
      }
      if (!_correctnessEvaluatorIds.contains(e.evaluatorId)) continue;
      final w = defaultEvaluatorWeights[e.evaluatorId] ?? 1.0;
      intelligenceNum += e.score * w;
      intelligenceDen += w;
    }
  }
  final intelligence = intelligenceDen == 0
      ? 0.0
      : intelligenceNum / intelligenceDen;
  final elegance = eleganceCount == 0 ? 0.0 : eleganceSum / eleganceCount;

  return Dimensions(
    intelligence: intelligence,
    speed: speed,
    elegance: elegance,
    reliability: reliability,
    problems: problems,
  );
}
