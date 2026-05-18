import 'dart:convert';

import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';

class RunDao {
  RunDao(this._db);
  final AppDatabase _db;

  Future<void> startRun({
    required String runId,
    required DateTime startedAt,
    String? name,
  }) {
    return _db
        .into(_db.runs)
        .insert(
          RunsCompanion.insert(
            id: runId,
            startedAt: startedAt,
            name: Value(name),
          ),
        );
  }

  Future<void> finishRun(String runId, DateTime completedAt) {
    return (_db.update(_db.runs)..where((r) => r.id.equals(runId))).write(
      RunsCompanion(completedAt: Value(completedAt)),
    );
  }

  Future<void> markRunCompleted(String runId) {
    return finishRun(runId, DateTime.now());
  }

  Future<void> persistTaskRun(TaskRunResult r) async {
    final taskRunId =
        '${r.runId}-${r.providerId}-${r.modelId}-${r.taskId}-${r.completedAt.microsecondsSinceEpoch}';
    await _db
        .into(_db.taskRuns)
        .insert(
          TaskRunsCompanion.insert(
            id: taskRunId,
            runId: r.runId,
            providerId: r.providerId,
            modelId: r.modelId,
            taskId: r.taskId,
            responseText: r.response.rawText,
            promptTokens: Value(r.response.promptTokens),
            completionTokens: Value(r.response.completionTokens),
            latencyMs: r.response.latency.inMilliseconds,
            aggregateScore: r.aggregateScore,
            completedAt: r.completedAt,
            planId: Value(r.planId),
          ),
        );
    for (var i = 0; i < r.evaluations.length; i++) {
      final e = r.evaluations[i];
      await _db
          .into(_db.evaluations)
          .insert(
            EvaluationsCompanion.insert(
              id: '$taskRunId-${e.evaluatorId}-$i',
              taskRunId: taskRunId,
              evaluatorId: e.evaluatorId,
              passed: e.passed,
              score: e.score,
              rationale: Value(e.rationale),
              detailsJson: jsonEncode(e.details),
            ),
          );
    }
  }

  Future<List<TaskRun>> taskRunsForRun(String runId) {
    return (_db.select(
      _db.taskRuns,
    )..where((t) => t.runId.equals(runId))).get();
  }

  Future<List<Evaluation>> evaluationsForTaskRun(String taskRunId) {
    return (_db.select(
      _db.evaluations,
    )..where((e) => e.taskRunId.equals(taskRunId))).get();
  }

  Future<List<Run>> recentRuns({int limit = 100, String? labelQuery}) {
    final q = _db.select(_db.runs)
      ..orderBy([(r) => OrderingTerm.desc(r.startedAt)])
      ..limit(limit);
    if (labelQuery != null && labelQuery.isNotEmpty) {
      q.where((r) => r.name.like('%$labelQuery%'));
    }
    return q.get();
  }

  Future<Run?> runById(String id) {
    return (_db.select(
      _db.runs,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  Future<TaskRun?> taskRunById(String id) {
    return (_db.select(
      _db.taskRuns,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> deleteRun(String runId) async {
    await _db.transaction(() async {
      final taskRuns = await taskRunsForRun(runId);
      for (final taskRun in taskRuns) {
        await (_db.delete(
          _db.evaluations,
        )..where((e) => e.taskRunId.equals(taskRun.id))).go();
      }
      await (_db.delete(
        _db.taskRuns,
      )..where((t) => t.runId.equals(runId))).go();
      await (_db.delete(_db.runs)..where((r) => r.id.equals(runId))).go();
    });
  }

  Future<List<Run>> inProgressRuns() {
    return (_db.select(_db.runs)
          ..where((r) => r.completedAt.isNull())
          ..orderBy([(r) => OrderingTerm.desc(r.startedAt)]))
        .get();
  }

  Future<void> deleteTaskRunByKey({
    required String runId,
    required String providerId,
    required String modelId,
    required String taskId,
  }) async {
    await _db.transaction(() async {
      final matches =
          await (_db.select(_db.taskRuns)..where(
                (t) =>
                    t.runId.equals(runId) &
                    t.providerId.equals(providerId) &
                    t.modelId.equals(modelId) &
                    t.taskId.equals(taskId),
              ))
              .get();
      for (final tr in matches) {
        await (_db.delete(
          _db.evaluations,
        )..where((e) => e.taskRunId.equals(tr.id))).go();
      }
      await (_db.delete(_db.taskRuns)..where(
            (t) =>
                t.runId.equals(runId) &
                t.providerId.equals(providerId) &
                t.modelId.equals(modelId) &
                t.taskId.equals(taskId),
          ))
          .go();
    });
  }
}
