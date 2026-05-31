import 'package:dart_arena/analytics/benchmark_statistics.dart';
import 'package:dart_arena/analytics/confidence_interval.dart';
import 'package:dart_arena/analytics/cost_estimator.dart';
import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';

class ModelRanking extends Equatable {
  const ModelRanking({
    required this.providerId,
    required this.modelId,
    required this.dimensions,
    required this.taskRunCount,
    this.primaryPassCount = 0,
    this.primaryPassSampleCount = 0,
    this.primaryPassInterval,
    this.lowSample = false,
    this.medianLatencyMs,
    this.medianPromptTokens,
    this.medianCompletionTokens,
    this.medianEstimatedCostMicros,
    this.costPerSolvedTaskMicros,
    this.failureBreakdown = const {},
  });

  final String providerId;
  final String modelId;
  final Dimensions dimensions;
  final int taskRunCount;
  final int primaryPassCount;
  final int primaryPassSampleCount;
  final ConfidenceInterval? primaryPassInterval;
  final bool lowSample;
  final int? medianLatencyMs;
  final int? medianPromptTokens;
  final int? medianCompletionTokens;
  final int? medianEstimatedCostMicros;
  final int? costPerSolvedTaskMicros;
  final Map<String, int> failureBreakdown;

  String get key => '$providerId:$modelId';
  double? get primaryPassRate => primaryPassSampleCount == 0
      ? null
      : primaryPassCount / primaryPassSampleCount;
  bool get hasMeasuredPrimaryPass => primaryPassSampleCount > 0;

  @override
  List<Object?> get props => [
    providerId,
    modelId,
    dimensions,
    taskRunCount,
    primaryPassCount,
    primaryPassSampleCount,
    primaryPassInterval,
    lowSample,
    medianLatencyMs,
    medianPromptTokens,
    medianCompletionTokens,
    medianEstimatedCostMicros,
    costPerSolvedTaskMicros,
    failureBreakdown,
  ];
}

class PerTaskScore extends Equatable {
  const PerTaskScore({
    required this.taskId,
    this.category,
    required this.aggregateScore,
    required this.lastRunId,
    required this.lastTaskRunId,
    this.taskRunCount = 1,
    this.primaryPassCount = 0,
    this.primaryPassSampleCount = 0,
    this.primaryPassInterval,
  });

  final String taskId;
  final Category? category;
  final double aggregateScore;
  final String? lastRunId;
  final String? lastTaskRunId;
  final int taskRunCount;
  final int primaryPassCount;
  final int primaryPassSampleCount;
  final ConfidenceInterval? primaryPassInterval;

  double? get primaryPassRate => primaryPassSampleCount == 0
      ? null
      : primaryPassCount / primaryPassSampleCount;
  double get displayScore => primaryPassRate ?? aggregateScore;

  @override
  List<Object?> get props => [
    taskId,
    category,
    aggregateScore,
    lastRunId,
    lastTaskRunId,
    taskRunCount,
    primaryPassCount,
    primaryPassSampleCount,
    primaryPassInterval,
  ];
}

class ModelDetail extends Equatable {
  const ModelDetail({required this.ranking, required this.perTask});
  final ModelRanking ranking;
  final List<PerTaskScore> perTask;

  @override
  List<Object?> get props => [ranking, perTask];
}

class LeaderboardRepository {
  LeaderboardRepository(
    this._db, {
    DateTime Function()? now,
    CostEstimator costEstimator = const CostEstimator(),
  }) : _now = now ?? DateTime.now,
       _costEstimator = costEstimator;
  final AppDatabase _db;
  final DateTime Function() _now;
  final CostEstimator _costEstimator;

  Future<List<ModelRanking>> rank({
    required LeaderboardFilter filter,
    Set<String>? taskIdsForCategory,
    Set<String>? taskIdsForFilter,
  }) async {
    final taskRuns = await _filteredTaskRuns(
      filter,
      taskIdsForFilter ?? taskIdsForCategory,
    );
    if (taskRuns.isEmpty) return const [];
    final evals = await _evaluationsByTaskRunId(taskRuns.map((t) => t.id));
    final groups = <String, List<TaskRun>>{};
    for (final tr in taskRuns) {
      groups
          .putIfAbsent('${tr.providerId}:${tr.modelId}', () => <TaskRun>[])
          .add(tr);
    }
    final out = <ModelRanking>[];
    groups.forEach((_, rs) {
      out.add(_rankingForTaskRuns(rs, evals));
    });
    out.sort((a, b) => _compareRankings(a, b, filter.dimension));
    return out;
  }

  Future<ModelDetail> detail({
    required String providerId,
    required String modelId,
    required LeaderboardFilter filter,
    Set<String>? taskIdsForCategory,
    Set<String>? taskIdsForFilter,
    Map<String, Category>? categoryByTaskId,
  }) async {
    final scoped = filter.copyWith(providerId: providerId);
    final taskRuns =
        (await _filteredTaskRuns(
              scoped,
              taskIdsForFilter ?? taskIdsForCategory,
            ))
            .where((t) => t.providerId == providerId && t.modelId == modelId)
            .toList();
    final evals = taskRuns.isEmpty
        ? const <String, List<Evaluation>>{}
        : await _evaluationsByTaskRunId(taskRuns.map((t) => t.id));
    final ranking = taskRuns.isEmpty
        ? ModelRanking(
            providerId: providerId,
            modelId: modelId,
            dimensions: Dimensions.zero,
            taskRunCount: 0,
            lowSample: true,
          )
        : _rankingForTaskRuns(taskRuns, evals);

    final byTask = <String, List<TaskRun>>{};
    for (final tr in taskRuns) {
      byTask.putIfAbsent(tr.taskId, () => <TaskRun>[]).add(tr);
    }
    final perTask = <PerTaskScore>[];
    byTask.forEach((taskId, rs) {
      rs.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      final latest = rs.first;
      final metrics = buildRankingMetrics(rs, costEstimator: _costEstimator);
      perTask.add(
        PerTaskScore(
          taskId: taskId,
          category: categoryByTaskId?[taskId],
          aggregateScore: latest.aggregateScore,
          lastRunId: latest.runId,
          lastTaskRunId: latest.id,
          taskRunCount: metrics.taskRunCount,
          primaryPassCount: metrics.primaryPassCount,
          primaryPassSampleCount: metrics.primaryPassSampleCount,
          primaryPassInterval: metrics.primaryPassInterval,
        ),
      );
    });
    perTask.sort((a, b) => b.displayScore.compareTo(a.displayScore));
    return ModelDetail(ranking: ranking, perTask: perTask);
  }

  ModelRanking _rankingForTaskRuns(
    List<TaskRun> taskRuns,
    Map<String, List<Evaluation>> evals,
  ) {
    final metrics = buildRankingMetrics(
      taskRuns,
      costEstimator: _costEstimator,
    );
    return ModelRanking(
      providerId: taskRuns.first.providerId,
      modelId: taskRuns.first.modelId,
      dimensions: Dimensions.fromTaskRuns(taskRuns, evals),
      taskRunCount: metrics.taskRunCount,
      primaryPassCount: metrics.primaryPassCount,
      primaryPassSampleCount: metrics.primaryPassSampleCount,
      primaryPassInterval: metrics.primaryPassInterval,
      lowSample: metrics.lowSample,
      medianLatencyMs: metrics.medianLatencyMs,
      medianPromptTokens: metrics.medianPromptTokens,
      medianCompletionTokens: metrics.medianCompletionTokens,
      medianEstimatedCostMicros: metrics.medianEstimatedCostMicros,
      costPerSolvedTaskMicros: metrics.costPerSolvedTaskMicros,
      failureBreakdown: metrics.failureBreakdown,
    );
  }

  Future<List<TaskRun>> _filteredTaskRuns(
    LeaderboardFilter filter,
    Set<String>? taskIdsForCategory,
  ) async {
    final q = _db.select(_db.taskRuns);
    final from = filter.dateRange.fromForNow(_now());
    final to = filter.dateRange.toForNow(_now());
    if (from != null) q.where((t) => t.completedAt.isBiggerOrEqualValue(from));
    if (to != null) q.where((t) => t.completedAt.isSmallerOrEqualValue(to));
    if (filter.providerId != null) {
      q.where((t) => t.providerId.equals(filter.providerId!));
    }
    if (filter.track != null) {
      q.where((t) => t.benchmarkTrack.equals(filter.track!.name));
    }
    if (filter.hasTaskMetadataFilter && taskIdsForCategory != null) {
      if (taskIdsForCategory.isEmpty) return const [];
      q.where((t) => t.taskId.isIn(taskIdsForCategory));
    }
    return q.get();
  }

  Future<Map<String, List<Evaluation>>> _evaluationsByTaskRunId(
    Iterable<String> ids,
  ) async {
    final rows = await (_db.select(
      _db.evaluations,
    )..where((e) => e.taskRunId.isIn(ids))).get();
    final out = <String, List<Evaluation>>{};
    for (final r in rows) {
      out.putIfAbsent(r.taskRunId, () => <Evaluation>[]).add(r);
    }
    return out;
  }
}

int _compareRankings(ModelRanking a, ModelRanking b, ScoreDimension dimension) {
  if (dimension != ScoreDimension.overall) {
    return _compareLegacyRankings(a, b, dimension);
  }
  final measured = _compareBoolDesc(
    a.hasMeasuredPrimaryPass,
    b.hasMeasuredPrimaryPass,
  );
  if (measured != 0) return measured;
  if (!a.hasMeasuredPrimaryPass && !b.hasMeasuredPrimaryPass) {
    return _compareLegacyRankings(a, b, dimension);
  }
  final lower = _compareNullableDoubleDesc(
    a.primaryPassInterval?.lower,
    b.primaryPassInterval?.lower,
  );
  if (lower != 0) return lower;
  final rate = _compareNullableDoubleDesc(a.primaryPassRate, b.primaryPassRate);
  if (rate != 0) return rate;
  final samples = b.primaryPassSampleCount.compareTo(a.primaryPassSampleCount);
  if (samples != 0) return samples;
  final cost = _compareNullableIntAsc(
    a.medianEstimatedCostMicros,
    b.medianEstimatedCostMicros,
  );
  if (cost != 0) return cost;
  final duration = _compareNullableIntAsc(a.medianLatencyMs, b.medianLatencyMs);
  if (duration != 0) return duration;
  return a.key.compareTo(b.key);
}

int _compareLegacyRankings(
  ModelRanking a,
  ModelRanking b,
  ScoreDimension dimension,
) {
  final measured = _compareBoolDesc(
    a.hasMeasuredPrimaryPass,
    b.hasMeasuredPrimaryPass,
  );
  if (measured != 0) return measured;
  final score = b.dimensions
      .byDimension(dimension)
      .compareTo(a.dimensions.byDimension(dimension));
  if (score != 0) return score;
  return a.key.compareTo(b.key);
}

int _compareBoolDesc(bool a, bool b) {
  if (a == b) return 0;
  return a ? -1 : 1;
}

int _compareNullableDoubleDesc(double? a, double? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

int _compareNullableIntAsc(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
