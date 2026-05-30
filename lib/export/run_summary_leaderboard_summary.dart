import 'package:dart_arena/analytics/benchmark_statistics.dart';
import 'package:dart_arena/analytics/cost_estimator.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:equatable/equatable.dart';

class RunSummaryLeaderboardRow extends Equatable {
  const RunSummaryLeaderboardRow({
    required this.providerId,
    required this.modelId,
    required this.metrics,
  });

  final String providerId;
  final String modelId;
  final RankingMetrics metrics;

  @override
  List<Object?> get props => [providerId, modelId, metrics];
}

List<RunSummaryLeaderboardRow> runSummaryLeaderboardRows(
  RunSummary summary, {
  CostEstimator costEstimator = const CostEstimator(),
}) {
  final groups = <String, List<TaskRun>>{};
  for (final taskRun in summary.taskRuns) {
    groups
        .putIfAbsent(
          '${taskRun.providerId}\u0000${taskRun.modelId}',
          () => <TaskRun>[],
        )
        .add(taskRun);
  }
  final rows = [
    for (final taskRuns in groups.values)
      RunSummaryLeaderboardRow(
        providerId: taskRuns.first.providerId,
        modelId: taskRuns.first.modelId,
        metrics: buildRankingMetrics(taskRuns, costEstimator: costEstimator),
      ),
  ];
  rows.sort((a, b) {
    final provider = a.providerId.compareTo(b.providerId);
    if (provider != 0) return provider;
    return a.modelId.compareTo(b.modelId);
  });
  return rows;
}

String exportRate(double? value) {
  return value == null ? '' : value.toStringAsFixed(4);
}

String exportCostDollars(int? micros) {
  return micros == null ? '' : (micros / 1000000).toStringAsFixed(6);
}

String exportInt(int? value) {
  return value == null ? '' : value.toString();
}
