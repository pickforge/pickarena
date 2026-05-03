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
  });

  final String providerId;
  final String modelId;
  final Dimensions dimensions;
  final int taskRunCount;

  String get key => '$providerId:$modelId';

  @override
  List<Object?> get props => [providerId, modelId, dimensions, taskRunCount];
}

class PerTaskScore extends Equatable {
  const PerTaskScore({
    required this.taskId,
    this.category,
    required this.aggregateScore,
    required this.lastRunId,
    required this.lastTaskRunId,
  });

  final String taskId;
  final Category? category;
  final double aggregateScore;
  final String? lastRunId;
  final String? lastTaskRunId;

  @override
  List<Object?> get props =>
      [taskId, category, aggregateScore, lastRunId, lastTaskRunId];
}

class ModelDetail extends Equatable {
  const ModelDetail({required this.ranking, required this.perTask});
  final ModelRanking ranking;
  final List<PerTaskScore> perTask;

  @override
  List<Object?> get props => [ranking, perTask];
}

class LeaderboardRepository {
  LeaderboardRepository(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final AppDatabase _db;
  final DateTime Function() _now;

  Future<List<ModelRanking>> rank({
    required LeaderboardFilter filter,
    Set<String>? taskIdsForCategory,
  }) async {
    final taskRuns = await _filteredTaskRuns(filter, taskIdsForCategory);
    if (taskRuns.isEmpty) return const [];
    final evals = await _evaluationsByTaskRunId(taskRuns.map((t) => t.id));
    final groups = <String, List<TaskRun>>{};
    for (final tr in taskRuns) {
      groups
          .putIfAbsent('${tr.providerId}:${tr.modelId}', () => <TaskRun>[])
          .add(tr);
    }
    final out = <ModelRanking>[];
    groups.forEach((key, rs) {
      out.add(ModelRanking(
        providerId: rs.first.providerId,
        modelId: rs.first.modelId,
        dimensions: Dimensions.fromTaskRuns(rs, evals),
        taskRunCount: rs.length,
      ));
    });
    out.sort((a, b) => b.dimensions
        .byDimension(filter.dimension)
        .compareTo(a.dimensions.byDimension(filter.dimension)));
    return out;
  }

  Future<ModelDetail> detail({
    required String providerId,
    required String modelId,
    required LeaderboardFilter filter,
    Set<String>? taskIdsForCategory,
    Map<String, Category>? categoryByTaskId,
  }) async {
    final scoped = filter.copyWith(providerId: providerId);
    final taskRuns =
        (await _filteredTaskRuns(scoped, taskIdsForCategory)).where(
      (t) => t.providerId == providerId && t.modelId == modelId,
    ).toList();
    final evals = taskRuns.isEmpty
        ? const <String, List<Evaluation>>{}
        : await _evaluationsByTaskRunId(taskRuns.map((t) => t.id));
    final ranking = ModelRanking(
      providerId: providerId,
      modelId: modelId,
      dimensions: Dimensions.fromTaskRuns(taskRuns, evals),
      taskRunCount: taskRuns.length,
    );

    final byTask = <String, List<TaskRun>>{};
    for (final tr in taskRuns) {
      byTask.putIfAbsent(tr.taskId, () => <TaskRun>[]).add(tr);
    }
    final perTask = <PerTaskScore>[];
    byTask.forEach((taskId, rs) {
      rs.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      final latest = rs.first;
      perTask.add(PerTaskScore(
        taskId: taskId,
        category: categoryByTaskId?[taskId],
        aggregateScore: latest.aggregateScore,
        lastRunId: latest.runId,
        lastTaskRunId: latest.id,
      ));
    });
    perTask.sort((a, b) => b.aggregateScore.compareTo(a.aggregateScore));
    return ModelDetail(ranking: ranking, perTask: perTask);
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
    if (filter.category != null && taskIdsForCategory != null) {
      q.where((t) => t.taskId.isIn(taskIdsForCategory));
    }
    return q.get();
  }

  Future<Map<String, List<Evaluation>>> _evaluationsByTaskRunId(
    Iterable<String> ids,
  ) async {
    final rows = await (_db.select(_db.evaluations)
          ..where((e) => e.taskRunId.isIn(ids)))
        .get();
    final out = <String, List<Evaluation>>{};
    for (final r in rows) {
      out.putIfAbsent(r.taskRunId, () => <Evaluation>[]).add(r);
    }
    return out;
  }
}
