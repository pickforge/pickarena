import 'package:dart_arena/storage/database.dart';
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

  double get overall =>
      (intelligence + speed + elegance + reliability) / 4.0;

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
  List<Object?> get props =>
      [intelligence, speed, elegance, reliability, problems];
}

Dimensions _computeDimensions(
  List<TaskRun> taskRuns,
  Map<String, List<Evaluation>> evalsByTaskRunId,
) {
  final reliabilityPasses =
      taskRuns.where((t) => t.aggregateScore >= Dimensions.reliabilityThreshold).length;
  final reliability = reliabilityPasses / taskRuns.length;
  return Dimensions(
    intelligence: 0,
    speed: 0,
    elegance: 0,
    reliability: reliability,
    problems: 0,
  );
}
