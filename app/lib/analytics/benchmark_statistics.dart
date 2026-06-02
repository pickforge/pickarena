import 'package:dart_arena/analytics/confidence_interval.dart';
import 'package:dart_arena/analytics/cost_estimator.dart';
import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:equatable/equatable.dart';

class RankingMetrics extends Equatable {
  const RankingMetrics({
    required this.taskRunCount,
    required this.primaryPassCount,
    required this.primaryPassSampleCount,
    required this.primaryPassInterval,
    required this.lowSample,
    required this.medianLatencyMs,
    required this.medianPromptTokens,
    required this.medianCompletionTokens,
    required this.medianEstimatedCostMicros,
    required this.knownEstimatedCostCount,
    required this.unknownEstimatedCostCount,
    required this.totalEstimatedCostMicros,
    required this.costPerSolvedTaskMicros,
    required this.cheapestPassingEstimatedCostMicros,
    required this.failureBreakdown,
  });

  final int taskRunCount;
  final int primaryPassCount;
  final int primaryPassSampleCount;
  final ConfidenceInterval? primaryPassInterval;
  final bool lowSample;
  final int? medianLatencyMs;
  final int? medianPromptTokens;
  final int? medianCompletionTokens;
  final int? medianEstimatedCostMicros;
  final int knownEstimatedCostCount;
  final int unknownEstimatedCostCount;
  final int? totalEstimatedCostMicros;
  final int? costPerSolvedTaskMicros;
  final int? cheapestPassingEstimatedCostMicros;
  final Map<String, int> failureBreakdown;

  double? get primaryPassRate => primaryPassSampleCount == 0
      ? null
      : primaryPassCount / primaryPassSampleCount;

  @override
  List<Object?> get props => [
    taskRunCount,
    primaryPassCount,
    primaryPassSampleCount,
    primaryPassInterval,
    lowSample,
    medianLatencyMs,
    medianPromptTokens,
    medianCompletionTokens,
    medianEstimatedCostMicros,
    knownEstimatedCostCount,
    unknownEstimatedCostCount,
    totalEstimatedCostMicros,
    costPerSolvedTaskMicros,
    cheapestPassingEstimatedCostMicros,
    failureBreakdown,
  ];
}

RankingMetrics buildRankingMetrics(
  List<TaskRun> taskRuns, {
  CostEstimator costEstimator = const CostEstimator(),
}) {
  final primaryPassCount = taskRuns.where((t) => t.primaryPass == true).length;
  final primaryPassSampleCount = taskRuns
      .where((t) => t.primaryPass != null)
      .length;
  final estimatedCosts = [
    for (final t in taskRuns)
      costEstimator.estimateMicros(
        providerId: t.providerId,
        modelId: t.modelId,
        promptTokens: t.promptTokens,
        completionTokens: t.completionTokens,
      ),
  ];
  final knownEstimatedCostCount = estimatedCosts.whereType<int>().length;
  final unknownEstimatedCostCount = taskRuns.length - knownEstimatedCostCount;
  final allCostsKnown = taskRuns.isNotEmpty && unknownEstimatedCostCount == 0;
  final totalCostMicros = allCostsKnown
      ? estimatedCosts.cast<int>().fold<int>(0, (sum, cost) => sum + cost)
      : null;
  final passingCosts = <int>[
    for (var i = 0; i < taskRuns.length; i++)
      if (taskRuns[i].primaryPass == true && estimatedCosts[i] != null)
        estimatedCosts[i]!,
  ]..sort();
  return RankingMetrics(
    taskRunCount: taskRuns.length,
    primaryPassCount: primaryPassCount,
    primaryPassSampleCount: primaryPassSampleCount,
    primaryPassInterval: wilsonPassRateInterval(
      successes: primaryPassCount,
      samples: primaryPassSampleCount,
    ),
    lowSample: isLowSample(primaryPassSampleCount),
    medianLatencyMs: medianInt(taskRuns.map((t) => t.latencyMs)),
    medianPromptTokens: medianInt(taskRuns.map((t) => t.promptTokens)),
    medianCompletionTokens: medianInt(taskRuns.map((t) => t.completionTokens)),
    medianEstimatedCostMicros: medianInt(estimatedCosts),
    knownEstimatedCostCount: knownEstimatedCostCount,
    unknownEstimatedCostCount: unknownEstimatedCostCount,
    totalEstimatedCostMicros: totalCostMicros,
    costPerSolvedTaskMicros: totalCostMicros == null || primaryPassCount == 0
        ? null
        : (totalCostMicros / primaryPassCount).round(),
    cheapestPassingEstimatedCostMicros: passingCosts.isEmpty
        ? null
        : passingCosts.first,
    failureBreakdown: buildFailureBreakdown(taskRuns),
  );
}

int? medianInt(Iterable<int?> values) {
  final sorted = values.whereType<int>().toList()..sort();
  if (sorted.isEmpty) return null;
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return ((sorted[middle - 1] + sorted[middle]) / 2).round();
}

Map<String, int> buildFailureBreakdown(Iterable<TaskRun> taskRuns) {
  final out = <String, int>{};
  for (final taskRun in taskRuns) {
    final tag = taskRun.primaryPass == true
        ? 'pass'
        : normalizeFailureTag(taskRun.failureTag);
    out[tag] = (out[tag] ?? 0) + 1;
  }
  return out;
}
