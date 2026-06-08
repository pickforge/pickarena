import 'dart:convert';

import 'package:dart_arena/analytics/benchmark_statistics.dart';
import 'package:dart_arena/analytics/confidence_interval.dart';
import 'package:dart_arena/analytics/cost_estimator.dart';
import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/core/evaluation_status.dart';
import 'package:dart_arena/core/evaluator_classification.dart';
import 'package:dart_arena/core/model_identity.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:crypto/crypto.dart';

enum LeaderboardExportStrategy { aggregateCompatible, latestRun, bestObserved }

const dartArenaBenchmarkVersion = '2026-05-31-master-spec';
const dartArenaEvaluatorSchemaVersion = 1;

extension LeaderboardExportStrategyName on LeaderboardExportStrategy {
  String get kebabName {
    switch (this) {
      case LeaderboardExportStrategy.aggregateCompatible:
        return 'aggregate-compatible';
      case LeaderboardExportStrategy.latestRun:
        return 'latest-run';
      case LeaderboardExportStrategy.bestObserved:
        return 'best-observed';
    }
  }
}

class LeaderboardExportOptions {
  const LeaderboardExportOptions({
    required this.track,
    this.strategy = LeaderboardExportStrategy.aggregateCompatible,
    this.runId,
    this.trialSummaryLimit = 1000,
  });

  final String track;
  final LeaderboardExportStrategy strategy;
  final String? runId;
  final int trialSummaryLimit;
}

Future<Map<String, Object?>> buildLeaderboardExport(
  AppDatabase db, {
  required LeaderboardExportOptions options,
  DateTime Function()? now,
}) async {
  final generatedAt = (now ?? DateTime.now)().toUtc();
  final completedRuns = await (db.select(
    db.runs,
  )..where((run) => run.completedAt.isNotNull())).get();

  final completedRunIds = completedRuns.map((run) => run.id).toList();
  final trackTaskRuns = completedRunIds.isEmpty
      ? const <TaskRun>[]
      : await (db.select(db.taskRuns)
              ..where((taskRun) => taskRun.runId.isIn(completedRunIds))
              ..where(
                (taskRun) => taskRun.benchmarkTrack.equals(options.track),
              ))
            .get();

  final taskRunsByRunId = <String, List<TaskRun>>{};
  for (final taskRun in trackTaskRuns) {
    taskRunsByRunId.putIfAbsent(taskRun.runId, () => <TaskRun>[]).add(taskRun);
  }

  final runsById = {for (final run in completedRuns) run.id: run};
  final warnings = <String>[];
  final selected = _selectTaskRuns(
    options: options,
    completedRuns: completedRuns,
    runsById: runsById,
    taskRunsByRunId: taskRunsByRunId,
    warnings: warnings,
  );

  final sortedRunIds = selected.sourceRunIds.toList()..sort();
  final selectedRuns = [
    for (final runId in sortedRunIds)
      if (runsById[runId] != null) runsById[runId]!,
  ];
  final taskKeys = selected.taskRuns.map(_taskKey).toSet();
  final modelKeys = selected.taskRuns
      .map((taskRun) => '${taskRun.providerId}:${taskRun.modelId}')
      .toSet();
  final runProvenance = _SourceRunProvenanceSummary.fromRuns(selectedRuns);
  final modelConfigIndex = ModelConfigIndex.fromRunProvenanceJsons(
    selectedRuns.map((run) => run.provenanceJson),
  );
  warnings.addAll(modelConfigIndex.warningMessages);

  if (selected.taskRuns.isEmpty) {
    warnings.add(
      'No completed task runs matched track "${options.track}" and the selected scope.',
    );
  }

  final evaluationsByTaskRunId = await _loadEvaluationsByTaskRunId(
    db,
    selected.taskRuns,
  );
  final judgeOverhead = _JudgeOverheadSummary.fromTaskRuns(
    selected.taskRuns,
    evaluationsByTaskRunId,
  );
  final models = _buildModelRows(
    selected.taskRuns,
    warnings,
    evaluationsByTaskRunId,
    modelConfigIndex,
  );
  final tasks = _buildTaskRows(
    selected.taskRuns,
    warnings,
    evaluationsByTaskRunId,
  );
  final taskModelCells = _buildTaskModelCells(
    selected.taskRuns,
    evaluationsByTaskRunId,
    modelConfigIndex,
  );
  final trialSummaries = _buildTrialSummaries(
    selected.taskRuns,
    evaluationsByTaskRunId,
    modelConfigIndex: modelConfigIndex,
    limit: options.trialSummaryLimit,
  );

  return <String, Object?>{
    'schemaVersion': 1,
    'generatedAt': generatedAt.toIso8601String(),
    'benchmark': <String, Object?>{
      'name': 'PickArena',
      'brand': 'Pickforge Studio',
      'title': 'PickArena by Pickforge Studio',
      'version': dartArenaBenchmarkVersion,
      'taskSetId': _taskSetId(taskKeys),
      'evaluatorSchemaVersion': dartArenaEvaluatorSchemaVersion,
      'track': options.track,
      'dataPolicy': options.strategy.kebabName,
    },
    'source': <String, Object?>{
      'anchorRunId': selected.anchorRunId,
      'runIds': sortedRunIds,
      'taskCount': taskKeys.length,
      'taskRunCount': selected.taskRuns.length,
      'modelCount': modelKeys.length,
      'trialSummaryCount': trialSummaries.length,
      'trialSummaryTotalCount': selected.taskRuns.length,
      'trialSummaryTruncated': trialSummaries.length < selected.taskRuns.length,
      'trialSummaryLimit': options.trialSummaryLimit,
      'warnings': warnings.toSet().toList()..sort(),
      'judgeOverhead': judgeOverhead.toJson(),
      'runProvenance': runProvenance.toJson(),
    },
    'scoring': _scoringMetadataJson(),
    'pricingRegistry': pricingRegistryProvenance(),
    'models': models,
    'tasks': tasks,
    'taskModelCells': taskModelCells,
    'trialSummaries': trialSummaries,
  };
}

_SelectedTaskRuns _selectTaskRuns({
  required LeaderboardExportOptions options,
  required List<Run> completedRuns,
  required Map<String, Run> runsById,
  required Map<String, List<TaskRun>> taskRunsByRunId,
  required List<String> warnings,
}) {
  switch (options.strategy) {
    case LeaderboardExportStrategy.aggregateCompatible:
      final anchorRun = _anchorRun(
        options: options,
        completedRuns: completedRuns,
        taskRunsByRunId: taskRunsByRunId,
      );
      if (anchorRun == null) {
        return const _SelectedTaskRuns(taskRuns: [], anchorRunId: null);
      }
      final anchorSignature = _RunCompatibilitySignature.fromTaskRuns(
        taskRunsByRunId[anchorRun.id] ?? const <TaskRun>[],
      );
      final anchorWeights = _parseEvaluatorWeights(anchorRun);
      final warningKeys = <String>{};
      final selected = <TaskRun>[];
      for (final entry in taskRunsByRunId.entries) {
        final candidateRun = runsById[entry.key];
        if (candidateRun == null) continue;
        final candidateSignature = _RunCompatibilitySignature.fromTaskRuns(
          entry.value,
        );
        if (candidateSignature != anchorSignature) continue;

        final candidateWeights = _parseEvaluatorWeights(candidateRun);
        if (anchorWeights.weights != null && candidateWeights.weights != null) {
          if (!_mapEquals(anchorWeights.weights!, candidateWeights.weights!)) {
            continue;
          }
        } else {
          _addProvenanceWarning(
            anchorWeights,
            warningKeys: warningKeys,
            warnings: warnings,
          );
          _addProvenanceWarning(
            candidateWeights,
            warningKeys: warningKeys,
            warnings: warnings,
          );
        }
        selected.addAll(entry.value);
      }
      return _SelectedTaskRuns(
        taskRuns: selected,
        anchorRunId: anchorRun.id,
        sourceRunIds: selected.map((taskRun) => taskRun.runId).toSet(),
      );
    case LeaderboardExportStrategy.latestRun:
      final anchorRun = _anchorRun(
        options: options,
        completedRuns: completedRuns,
        taskRunsByRunId: taskRunsByRunId,
      );
      if (anchorRun == null) {
        return const _SelectedTaskRuns(taskRuns: [], anchorRunId: null);
      }
      return _SelectedTaskRuns(
        taskRuns: List<TaskRun>.of(
          taskRunsByRunId[anchorRun.id] ?? const <TaskRun>[],
        ),
        anchorRunId: anchorRun.id,
        sourceRunIds: <String>{anchorRun.id},
      );
    case LeaderboardExportStrategy.bestObserved:
      final scopedRunIds = options.runId == null
          ? taskRunsByRunId.keys.toSet()
          : <String>{options.runId!};
      final scopedTaskRuns = <TaskRun>[
        for (final runId in scopedRunIds)
          ...taskRunsByRunId[runId] ?? const <TaskRun>[],
      ];
      return _SelectedTaskRuns(
        taskRuns: _selectBestObserved(scopedTaskRuns),
        anchorRunId: options.runId,
        sourceRunIds: scopedTaskRuns.map((taskRun) => taskRun.runId).toSet(),
      );
  }
}

Run? _anchorRun({
  required LeaderboardExportOptions options,
  required List<Run> completedRuns,
  required Map<String, List<TaskRun>> taskRunsByRunId,
}) {
  if (options.runId != null) {
    for (final run in completedRuns) {
      if (run.id == options.runId && taskRunsByRunId.containsKey(run.id)) {
        return run;
      }
    }
    return null;
  }

  final matchingRuns = completedRuns
      .where((run) => taskRunsByRunId.containsKey(run.id))
      .toList();
  if (matchingRuns.isEmpty) return null;
  matchingRuns.sort((a, b) {
    final completedCompare = b.completedAt!.compareTo(a.completedAt!);
    if (completedCompare != 0) return completedCompare;
    return a.id.compareTo(b.id);
  });
  return matchingRuns.first;
}

List<TaskRun> _selectBestObserved(List<TaskRun> taskRuns) {
  final groups = <String, List<TaskRun>>{};
  for (final taskRun in taskRuns) {
    groups
        .putIfAbsent(
          '${taskRun.providerId}:${taskRun.modelId}:${_taskKey(taskRun)}',
          () => <TaskRun>[],
        )
        .add(taskRun);
  }
  return [
    for (final group in groups.values)
      (group..sort(_compareBestObservedTaskRuns)).first,
  ];
}

int _compareBestObservedTaskRuns(TaskRun a, TaskRun b) {
  final passCompare = _passRank(
    b.primaryPass,
  ).compareTo(_passRank(a.primaryPass));
  if (passCompare != 0) return passCompare;
  final scoreCompare = b.aggregateScore.compareTo(a.aggregateScore);
  if (scoreCompare != 0) return scoreCompare;
  final latencyCompare = a.latencyMs.compareTo(b.latencyMs);
  if (latencyCompare != 0) return latencyCompare;
  final completedCompare = b.completedAt.compareTo(a.completedAt);
  if (completedCompare != 0) return completedCompare;
  return a.id.compareTo(b.id);
}

int _passRank(bool? value) => value == true
    ? 2
    : value == false
    ? 1
    : 0;

List<Map<String, Object?>> _buildModelRows(
  List<TaskRun> taskRuns,
  List<String> warnings,
  Map<String, List<Evaluation>> evaluationsByTaskRunId,
  ModelConfigIndex modelConfigIndex,
) {
  final groups = <String, List<TaskRun>>{};
  for (final taskRun in taskRuns) {
    groups
        .putIfAbsent(
          '${taskRun.providerId}:${taskRun.modelId}',
          () => <TaskRun>[],
        )
        .add(taskRun);
  }

  final rows = <_ModelRow>[];
  for (final group in groups.values) {
    group.sort((a, b) => a.id.compareTo(b.id));
    final metrics = buildRankingMetrics(group);
    if (metrics.primaryPassSampleCount == 0) {
      warnings.add(
        'Model ${group.first.providerId}:${group.first.modelId} has no primary-pass samples.',
      );
    }
    rows.add(
      _ModelRow.fromMetrics(
        group.first,
        metrics,
        _PassSplit.fromTaskRuns(group, evaluationsByTaskRunId),
        _BlockedSummary.fromTaskRuns(group, evaluationsByTaskRunId),
        _PassAtKSummary.fromTaskRuns(group, groupKey: _taskKey),
        _TraceMetricSummary.fromTaskRuns(group, evaluationsByTaskRunId),
        _TokenUsageCoverage.fromTaskRuns(group),
        modelConfigIndex,
      ),
    );
  }
  rows.sort(_compareModelRows);

  return [for (var i = 0; i < rows.length; i++) rows[i].toJson(rank: i + 1)];
}

int _compareModelRows(_ModelRow a, _ModelRow b) {
  final scoreCompare = b.score.compareTo(a.score);
  if (scoreCompare != 0) return scoreCompare;
  final lowerCompare = b.confidenceLower.compareTo(a.confidenceLower);
  if (lowerCompare != 0) return lowerCompare;
  final sampleCompare = b.sampleCount.compareTo(a.sampleCount);
  if (sampleCompare != 0) return sampleCompare;
  final costCompare = _compareNullableIntAsc(
    a.medianEstimatedCostMicros,
    b.medianEstimatedCostMicros,
  );
  if (costCompare != 0) return costCompare;
  final latencyCompare = _compareNullableIntAsc(
    a.medianLatencyMs,
    b.medianLatencyMs,
  );
  if (latencyCompare != 0) return latencyCompare;
  final providerCompare = a.providerId.compareTo(b.providerId);
  if (providerCompare != 0) return providerCompare;
  return a.modelId.compareTo(b.modelId);
}

List<Map<String, Object?>> _buildTaskRows(
  List<TaskRun> taskRuns,
  List<String> warnings,
  Map<String, List<Evaluation>> evaluationsByTaskRunId,
) {
  final groups = <String, List<TaskRun>>{};
  for (final taskRun in taskRuns) {
    groups.putIfAbsent(_taskKey(taskRun), () => <TaskRun>[]).add(taskRun);
  }

  final rows = <Map<String, Object?>>[];
  for (final group in groups.values) {
    group.sort((a, b) => a.id.compareTo(b.id));
    final passCount = group
        .where((taskRun) => taskRun.primaryPass == true)
        .length;
    final sampleCount = group
        .where((taskRun) => taskRun.primaryPass != null)
        .length;
    final confidenceInterval = wilsonPassRateInterval(
      successes: passCount,
      samples: sampleCount,
    );
    if (sampleCount == 0) {
      warnings.add(
        'Task ${_taskKey(group.first)} has no primary-pass samples.',
      );
    }
    final modelCount = group
        .map((taskRun) => '${taskRun.providerId}:${taskRun.modelId}')
        .toSet()
        .length;
    final passSplit = _PassSplit.fromTaskRuns(group, evaluationsByTaskRunId);
    final blockedSummary = _BlockedSummary.fromTaskRuns(
      group,
      evaluationsByTaskRunId,
    );
    final traceMetrics = _TraceMetricSummary.fromTaskRuns(
      group,
      evaluationsByTaskRunId,
    );
    final tokenUsageCoverage = _TokenUsageCoverage.fromTaskRuns(group);
    rows.add(<String, Object?>{
      'taskId': group.first.taskId,
      'taskVersion': group.first.taskVersion,
      'benchmarkTrack': group.first.benchmarkTrack,
      'trialCount': sampleCount,
      'sampleCount': sampleCount,
      'modelCount': modelCount,
      'passRate': sampleCount == 0 ? 0.0 : passCount / sampleCount,
      'confidenceInterval': _confidenceIntervalJson(confidenceInterval),
      'passAtK': _PassAtKSummary.fromTaskRuns(
        group,
        groupKey: (taskRun) => '${taskRun.providerId}:${taskRun.modelId}',
      ).toJson(),
      'medianStepCount': traceMetrics.medianStepCount,
      'medianPeakContextTokens': traceMetrics.medianPeakContextTokens,
      'traceMetricCoverage': traceMetrics.coverageJson(),
      'tokenUsageCoverage': tokenUsageCoverage.toJson(),
      ...passSplit.toJson(),
      ...blockedSummary.toJson(),
    });
  }

  rows.sort((a, b) {
    final taskCompare = (a['taskId']! as String).compareTo(
      b['taskId']! as String,
    );
    if (taskCompare != 0) return taskCompare;
    final versionCompare = (a['taskVersion']! as int).compareTo(
      b['taskVersion']! as int,
    );
    if (versionCompare != 0) return versionCompare;
    return (a['benchmarkTrack']! as String).compareTo(
      b['benchmarkTrack']! as String,
    );
  });
  return rows;
}

List<Map<String, Object?>> _buildTaskModelCells(
  List<TaskRun> taskRuns,
  Map<String, List<Evaluation>> evaluationsByTaskRunId,
  ModelConfigIndex modelConfigIndex,
) {
  final groups = <String, List<TaskRun>>{};
  for (final taskRun in taskRuns) {
    groups
        .putIfAbsent(
          '${taskRun.providerId}:${taskRun.modelId}:${_taskKey(taskRun)}',
          () => <TaskRun>[],
        )
        .add(taskRun);
  }

  final rows = <Map<String, Object?>>[];
  for (final group in groups.values) {
    group.sort((a, b) => a.id.compareTo(b.id));
    final metrics = buildRankingMetrics(group);
    final passRate = metrics.primaryPassSampleCount == 0
        ? null
        : metrics.primaryPassCount / metrics.primaryPassSampleCount;
    final passSplit = _PassSplit.fromTaskRuns(group, evaluationsByTaskRunId);
    final blockedSummary = _BlockedSummary.fromTaskRuns(
      group,
      evaluationsByTaskRunId,
    );
    final traceMetrics = _TraceMetricSummary.fromTaskRuns(
      group,
      evaluationsByTaskRunId,
    );
    final tokenUsageCoverage = _TokenUsageCoverage.fromTaskRuns(group);
    final sortedFailures = Map<String, int>.fromEntries(
      metrics.failureBreakdown.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final errorCount = sortedFailures.entries
        .where((entry) => entry.key != 'pass')
        .fold<int>(0, (sum, entry) => sum + entry.value);
    rows.add(<String, Object?>{
      'providerId': group.first.providerId,
      'modelId': group.first.modelId,
      ...modelConfigIndex.exportJsonFor(
        providerId: group.first.providerId,
        modelId: group.first.modelId,
      ),
      'taskId': group.first.taskId,
      'taskVersion': group.first.taskVersion,
      'benchmarkTrack': group.first.benchmarkTrack,
      'trialCount': metrics.primaryPassSampleCount,
      'passCount': metrics.primaryPassCount,
      'sampleCount': metrics.primaryPassSampleCount,
      'passRate': passRate,
      'confidenceInterval': _confidenceIntervalJson(
        metrics.primaryPassInterval,
      ),
      'errorCount': errorCount,
      'passAtK': _PassAtKSummary.fromTaskRuns(
        group,
        groupKey: _taskKey,
      ).toJson(),
      'medianStepCount': traceMetrics.medianStepCount,
      'medianPeakContextTokens': traceMetrics.medianPeakContextTokens,
      'traceMetricCoverage': traceMetrics.coverageJson(),
      'tokenUsageCoverage': tokenUsageCoverage.toJson(),
      ...passSplit.toJson(),
      ...blockedSummary.toJson(),
      'medianLatencyMs': metrics.medianLatencyMs,
      'medianPromptTokens': metrics.medianPromptTokens,
      'medianCompletionTokens': metrics.medianCompletionTokens,
      'medianEstimatedCostMicros': metrics.medianEstimatedCostMicros,
      'knownEstimatedCostCount': metrics.knownEstimatedCostCount,
      'unknownEstimatedCostCount': metrics.unknownEstimatedCostCount,
      'failureBreakdown': sortedFailures,
    });
  }

  rows.sort((a, b) {
    final providerCompare = (a['providerId']! as String).compareTo(
      b['providerId']! as String,
    );
    if (providerCompare != 0) return providerCompare;
    final modelCompare = (a['modelId']! as String).compareTo(
      b['modelId']! as String,
    );
    if (modelCompare != 0) return modelCompare;
    final taskCompare = (a['taskId']! as String).compareTo(
      b['taskId']! as String,
    );
    if (taskCompare != 0) return taskCompare;
    final versionCompare = (a['taskVersion']! as int).compareTo(
      b['taskVersion']! as int,
    );
    if (versionCompare != 0) return versionCompare;
    return (a['benchmarkTrack']! as String).compareTo(
      b['benchmarkTrack']! as String,
    );
  });

  return rows;
}

List<Map<String, Object?>> _buildTrialSummaries(
  List<TaskRun> taskRuns,
  Map<String, List<Evaluation>> evaluationsByTaskRunId, {
  required ModelConfigIndex modelConfigIndex,
  required int limit,
}) {
  if (limit <= 0) return const [];
  final sorted = taskRuns.toList()..sort(_compareTrialSummaries);
  const costEstimator = CostEstimator();
  return [
    for (final taskRun in sorted.take(limit))
      _trialSummaryJson(
        taskRun,
        evaluationsByTaskRunId[taskRun.id] ?? const <Evaluation>[],
        costEstimator,
        modelConfigIndex,
      ),
  ];
}

Map<String, Object?> _trialSummaryJson(
  TaskRun taskRun,
  List<Evaluation> evaluations,
  CostEstimator costEstimator,
  ModelConfigIndex modelConfigIndex,
) {
  final evaluationSummary = _TrialEvaluationSummary.fromEvaluations(
    evaluations,
  );
  final traceMetrics = _TraceMetrics.fromEvaluations(evaluations);
  final tokenUsageStatus = _TokenUsageStatus.fromTaskRun(taskRun);
  return <String, Object?>{
    'trialId': _publicTrialId(taskRun.id),
    'runId': taskRun.runId,
    'providerId': taskRun.providerId,
    'modelId': taskRun.modelId,
    ...modelConfigIndex.exportJsonFor(
      providerId: taskRun.providerId,
      modelId: taskRun.modelId,
    ),
    'taskId': taskRun.taskId,
    'taskVersion': taskRun.taskVersion,
    'benchmarkTrack': taskRun.benchmarkTrack,
    'trialIndex': taskRun.trialIndex,
    'completedAt': taskRun.completedAt.toUtc().toIso8601String(),
    'primaryPass': taskRun.primaryPass,
    'failureTag': taskRun.primaryPass == true
        ? 'pass'
        : normalizeFailureTag(taskRun.failureTag),
    'aggregateScore': taskRun.aggregateScore,
    'publicPassed': evaluationSummary.publicPassed,
    'hiddenPassed': evaluationSummary.hiddenPassed,
    'blockedEvaluationCount': evaluationSummary.blockedEvaluationCount,
    'stepCount': traceMetrics.stepCount,
    'peakContextTokens': traceMetrics.peakContextTokens,
    'traceMetricStatus': traceMetrics.statusJson(),
    'latencyMs': taskRun.latencyMs,
    'promptTokens': taskRun.promptTokens,
    'completionTokens': taskRun.completionTokens,
    'tokenUsageStatus': tokenUsageStatus.toJson(),
    'estimatedCostMicros': costEstimator.estimateMicros(
      providerId: taskRun.providerId,
      modelId: taskRun.modelId,
      promptTokens: taskRun.promptTokens,
      completionTokens: taskRun.completionTokens,
    ),
  };
}

int _compareTrialSummaries(TaskRun a, TaskRun b) {
  final providerCompare = a.providerId.compareTo(b.providerId);
  if (providerCompare != 0) return providerCompare;
  final modelCompare = a.modelId.compareTo(b.modelId);
  if (modelCompare != 0) return modelCompare;
  final taskCompare = a.taskId.compareTo(b.taskId);
  if (taskCompare != 0) return taskCompare;
  final versionCompare = a.taskVersion.compareTo(b.taskVersion);
  if (versionCompare != 0) return versionCompare;
  final trackCompare = a.benchmarkTrack.compareTo(b.benchmarkTrack);
  if (trackCompare != 0) return trackCompare;
  final trialCompare = a.trialIndex.compareTo(b.trialIndex);
  if (trialCompare != 0) return trialCompare;
  final completedCompare = a.completedAt.compareTo(b.completedAt);
  if (completedCompare != 0) return completedCompare;
  return a.id.compareTo(b.id);
}

String _publicTrialId(String taskRunId) =>
    sha256.convert(utf8.encode(taskRunId)).toString().substring(0, 12);

String _taskKey(TaskRun taskRun) =>
    '${taskRun.taskId}@${taskRun.taskVersion}@${taskRun.benchmarkTrack}';

String _taskSetId(Set<String> taskKeys) {
  final sorted = taskKeys.toList()..sort();
  if (sorted.isEmpty) return 'taskset-empty';
  final digest = sha256.convert(utf8.encode(sorted.join('\n'))).toString();
  return 'taskset-${digest.substring(0, 16)}';
}

Map<String, Object?> _confidenceIntervalJson(ConfidenceInterval? interval) => {
  'lower': interval?.lower ?? 0.0,
  'upper': interval?.upper ?? 0.0,
};

Map<String, Object?> _scoringMetadataJson() => {
  'schemaVersion': 1,
  'primaryMetric': 'primary_pass',
  'rankingMetric': 'primary_pass_rate',
  'confidenceInterval': 'wilson_95',
  'llmJudgePolicy': 'diagnostic_only',
  'objectiveEvaluatorIds': objectiveEvaluatorIds.toList()..sort(),
  'secondaryEvaluatorIds': secondaryEvaluatorIds.toList()..sort(),
  'hiddenVerifierPattern': '*_hidden',
  'failureTags': supportedFailureTags,
  'objectiveFailureCaps': {
    'compile': 0.20,
    'analyze': 0.35,
    'public_test': 0.60,
    'hidden_verifier': 0.60,
  },
  'defaultEvaluatorWeights': Map<String, double>.fromEntries(
    defaultEvaluatorWeights.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key)),
  ),
};

Future<Map<String, List<Evaluation>>> _loadEvaluationsByTaskRunId(
  AppDatabase db,
  List<TaskRun> taskRuns,
) async {
  final ids = taskRuns.map((taskRun) => taskRun.id).toList();
  if (ids.isEmpty) return const {};
  final evaluations = await (db.select(
    db.evaluations,
  )..where((evaluation) => evaluation.taskRunId.isIn(ids))).get();
  final grouped = <String, List<Evaluation>>{};
  for (final evaluation in evaluations) {
    grouped
        .putIfAbsent(evaluation.taskRunId, () => <Evaluation>[])
        .add(evaluation);
  }
  return grouped;
}

int _compareNullableIntAsc(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

void _addProvenanceWarning(
  _EvaluatorWeightsParse parse, {
  required Set<String> warningKeys,
  required List<String> warnings,
}) {
  final warning = parse.warning;
  if (warning == null || !warningKeys.add(warning)) return;
  warnings.add(warning);
}

_EvaluatorWeightsParse _parseEvaluatorWeights(Run run) {
  final provenanceJson = run.provenanceJson;
  if (provenanceJson == null || provenanceJson.trim().isEmpty) {
    return _EvaluatorWeightsParse.warning(
      'Run ${run.id} has no evaluator weights provenance; skipped evaluator-weight compatibility check.',
    );
  }
  try {
    final decoded = jsonDecode(provenanceJson);
    if (decoded is! Map<String, Object?>) {
      return _EvaluatorWeightsParse.warning(
        'Run ${run.id} has malformed provenance; skipped evaluator-weight compatibility check.',
      );
    }
    final config = decoded['config'];
    if (config is! Map<String, Object?>) {
      return _EvaluatorWeightsParse.warning(
        'Run ${run.id} has no evaluator weights provenance; skipped evaluator-weight compatibility check.',
      );
    }
    final weights = config['evaluatorWeights'];
    if (weights is! Map<String, Object?>) {
      return _EvaluatorWeightsParse.warning(
        'Run ${run.id} has no evaluator weights provenance; skipped evaluator-weight compatibility check.',
      );
    }
    final normalized = <String, Object?>{};
    for (final entry in weights.entries) {
      final value = entry.value;
      if (value is num) {
        normalized[entry.key] = value.toDouble();
      } else {
        return _EvaluatorWeightsParse.warning(
          'Run ${run.id} has malformed evaluator weights; skipped evaluator-weight compatibility check.',
        );
      }
    }
    return _EvaluatorWeightsParse(weights: normalized);
  } on Object {
    return _EvaluatorWeightsParse.warning(
      'Run ${run.id} has malformed provenance; skipped evaluator-weight compatibility check.',
    );
  }
}

class _ModelRow {
  const _ModelRow({
    required this.providerId,
    required this.modelId,
    required this.score,
    required this.passCount,
    required this.sampleCount,
    required this.passSplit,
    required this.confidenceLower,
    required this.confidenceUpper,
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
    required this.blockedSummary,
    required this.passAtK,
    required this.traceMetrics,
    required this.tokenUsageCoverage,
    required this.modelIdentity,
  });

  factory _ModelRow.fromMetrics(
    TaskRun first,
    RankingMetrics metrics,
    _PassSplit passSplit,
    _BlockedSummary blockedSummary,
    _PassAtKSummary passAtK,
    _TraceMetricSummary traceMetrics,
    _TokenUsageCoverage tokenUsageCoverage,
    ModelConfigIndex modelConfigIndex,
  ) {
    final passRate = metrics.primaryPassSampleCount == 0
        ? 0.0
        : metrics.primaryPassCount / metrics.primaryPassSampleCount;
    return _ModelRow(
      providerId: first.providerId,
      modelId: first.modelId,
      score: passRate,
      passCount: metrics.primaryPassCount,
      sampleCount: metrics.primaryPassSampleCount,
      passSplit: passSplit,
      confidenceLower: metrics.primaryPassInterval?.lower ?? 0.0,
      confidenceUpper: metrics.primaryPassInterval?.upper ?? 0.0,
      lowSample: metrics.lowSample,
      medianLatencyMs: metrics.medianLatencyMs,
      medianPromptTokens: metrics.medianPromptTokens,
      medianCompletionTokens: metrics.medianCompletionTokens,
      medianEstimatedCostMicros: metrics.medianEstimatedCostMicros,
      knownEstimatedCostCount: metrics.knownEstimatedCostCount,
      unknownEstimatedCostCount: metrics.unknownEstimatedCostCount,
      totalEstimatedCostMicros: metrics.totalEstimatedCostMicros,
      costPerSolvedTaskMicros: metrics.costPerSolvedTaskMicros,
      cheapestPassingEstimatedCostMicros:
          metrics.cheapestPassingEstimatedCostMicros,
      failureBreakdown: metrics.failureBreakdown,
      blockedSummary: blockedSummary,
      passAtK: passAtK,
      traceMetrics: traceMetrics,
      tokenUsageCoverage: tokenUsageCoverage,
      modelIdentity: modelConfigIndex.exportJsonFor(
        providerId: first.providerId,
        modelId: first.modelId,
      ),
    );
  }

  final String providerId;
  final String modelId;
  final double score;
  final int passCount;
  final int sampleCount;
  final _PassSplit passSplit;
  final double confidenceLower;
  final double confidenceUpper;
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
  final _BlockedSummary blockedSummary;
  final _PassAtKSummary passAtK;
  final _TraceMetricSummary traceMetrics;
  final _TokenUsageCoverage tokenUsageCoverage;
  final Map<String, Object?> modelIdentity;

  Map<String, Object?> toJson({required int rank}) {
    final sortedFailures = Map<String, int>.fromEntries(
      failureBreakdown.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return <String, Object?>{
      'providerId': providerId,
      'modelId': modelId,
      ...modelIdentity,
      'rank': rank,
      'score': score,
      'passRate': score,
      'trialCount': sampleCount,
      'passCount': passCount,
      'sampleCount': sampleCount,
      'passAtK': passAtK.toJson(),
      'medianStepCount': traceMetrics.medianStepCount,
      'medianPeakContextTokens': traceMetrics.medianPeakContextTokens,
      'traceMetricCoverage': traceMetrics.coverageJson(),
      'tokenUsageCoverage': tokenUsageCoverage.toJson(),
      ...passSplit.toJson(),
      'confidenceInterval': <String, Object?>{
        'lower': confidenceLower,
        'upper': confidenceUpper,
      },
      'lowSample': lowSample,
      'medianLatencyMs': medianLatencyMs,
      'medianPromptTokens': medianPromptTokens,
      'medianCompletionTokens': medianCompletionTokens,
      'medianEstimatedCostMicros': medianEstimatedCostMicros,
      'knownEstimatedCostCount': knownEstimatedCostCount,
      'unknownEstimatedCostCount': unknownEstimatedCostCount,
      'totalEstimatedCostMicros': totalEstimatedCostMicros,
      'costPerSolvedTaskMicros': costPerSolvedTaskMicros,
      'cheapestPassingEstimatedCostMicros': cheapestPassingEstimatedCostMicros,
      'failureBreakdown': sortedFailures,
      ...blockedSummary.toJson(),
    };
  }
}

class _SelectedTaskRuns {
  const _SelectedTaskRuns({
    required this.taskRuns,
    required this.anchorRunId,
    this.sourceRunIds = const <String>{},
  });

  final List<TaskRun> taskRuns;
  final String? anchorRunId;
  final Set<String> sourceRunIds;
}

class _SourceRunProvenanceSummary {
  const _SourceRunProvenanceSummary({
    required this.runCount,
    required this.embeddedRunCount,
    required this.sandboxEnforcedRunCount,
    required this.taskExecutionPolicyRunCount,
    required this.networkDisabledTaskPolicyRunCount,
    required this.taskResourceLimitRunCount,
    required this.sdkVersionRunCount,
    required this.dependencySnapshotRunCount,
    required this.pricingRegistryRunCount,
    required this.generatedCodeSandboxBackends,
    required this.dartVersions,
    required this.flutterVersions,
    required this.environmentIds,
    required this.warnings,
  });

  factory _SourceRunProvenanceSummary.fromRuns(List<Run> runs) {
    final sortedRuns = runs.toList()..sort((a, b) => a.id.compareTo(b.id));
    var embeddedRunCount = 0;
    var sandboxEnforcedRunCount = 0;
    var taskExecutionPolicyRunCount = 0;
    var networkDisabledTaskPolicyRunCount = 0;
    var taskResourceLimitRunCount = 0;
    var sdkVersionRunCount = 0;
    var dependencySnapshotRunCount = 0;
    var pricingRegistryRunCount = 0;
    final generatedCodeSandboxBackends = <String>{};
    final dartVersions = <String>{};
    final flutterVersions = <String>{};
    final environmentIds = <String>{};
    final warnings = <String>{};

    for (final run in sortedRuns) {
      final provenance = _decodeRunProvenance(run.provenanceJson);
      if (provenance == null) {
        warnings.add('Run ${run.id} has no usable run provenance.');
        continue;
      }
      embeddedRunCount++;

      final config = _objectMap(provenance['config']);
      final sandbox = _objectMap(config['generatedCodeSandbox']);
      final sandboxBackend = _nonEmptyString(sandbox['backend']);
      if (sandbox['enforced'] == true && sandboxBackend != null) {
        sandboxEnforcedRunCount++;
        generatedCodeSandboxBackends.add(sandboxBackend);
      } else {
        warnings.add(
          'Run ${run.id} does not record generated-code sandbox enforcement.',
        );
      }

      final tasks = _objectList(provenance['tasks']);
      if (tasks.isNotEmpty && tasks.every(_hasTaskExecutionPolicy)) {
        taskExecutionPolicyRunCount++;
      } else {
        warnings.add(
          'Run ${run.id} has incomplete task execution policy provenance.',
        );
      }
      if (tasks.isNotEmpty && tasks.every(_hasNetworkDisabledTaskPolicy)) {
        networkDisabledTaskPolicyRunCount++;
      } else {
        warnings.add(
          'Run ${run.id} does not record network-disabled task execution policy.',
        );
      }
      if (tasks.isNotEmpty && tasks.every(_hasTaskResourceLimits)) {
        taskResourceLimitRunCount++;
      } else {
        warnings.add(
          'Run ${run.id} has incomplete or unenforced task resource limit provenance.',
        );
      }

      final environment = _objectMap(provenance['environment']);
      final dartVersion = _sdkVersion(environment['dartVersion']);
      final flutterVersion = _sdkVersion(environment['flutterVersion']);
      if (dartVersion != null && flutterVersion != null) {
        sdkVersionRunCount++;
        dartVersions.add(dartVersion);
        flutterVersions.add(flutterVersion);
      } else {
        warnings.add('Run ${run.id} has incomplete SDK version provenance.');
      }

      final environmentId = _environmentId(environment);
      if (environmentId != null) environmentIds.add(environmentId);

      if (_hasDependencySnapshot(environment)) {
        dependencySnapshotRunCount++;
      } else {
        warnings.add(
          'Run ${run.id} has incomplete dependency lockfile provenance.',
        );
      }

      final pricingRegistry = _objectMap(config['pricingRegistry']);
      if (_hasPricingRegistry(pricingRegistry)) {
        pricingRegistryRunCount++;
      } else {
        warnings.add(
          'Run ${run.id} has incomplete pricing registry provenance.',
        );
      }
    }

    return _SourceRunProvenanceSummary(
      runCount: sortedRuns.length,
      embeddedRunCount: embeddedRunCount,
      sandboxEnforcedRunCount: sandboxEnforcedRunCount,
      taskExecutionPolicyRunCount: taskExecutionPolicyRunCount,
      networkDisabledTaskPolicyRunCount: networkDisabledTaskPolicyRunCount,
      taskResourceLimitRunCount: taskResourceLimitRunCount,
      sdkVersionRunCount: sdkVersionRunCount,
      dependencySnapshotRunCount: dependencySnapshotRunCount,
      pricingRegistryRunCount: pricingRegistryRunCount,
      generatedCodeSandboxBackends: generatedCodeSandboxBackends.toList()
        ..sort(),
      dartVersions: dartVersions.toList()..sort(),
      flutterVersions: flutterVersions.toList()..sort(),
      environmentIds: environmentIds.toList()..sort(),
      warnings: warnings.toList()..sort(),
    );
  }

  final int runCount;
  final int embeddedRunCount;
  final int sandboxEnforcedRunCount;
  final int taskExecutionPolicyRunCount;
  final int networkDisabledTaskPolicyRunCount;
  final int taskResourceLimitRunCount;
  final int sdkVersionRunCount;
  final int dependencySnapshotRunCount;
  final int pricingRegistryRunCount;
  final List<String> generatedCodeSandboxBackends;
  final List<String> dartVersions;
  final List<String> flutterVersions;
  final List<String> environmentIds;
  final List<String> warnings;

  Map<String, Object?> toJson() => {
    'runCount': runCount,
    'embeddedRunCount': embeddedRunCount,
    'sandboxEnforcedRunCount': sandboxEnforcedRunCount,
    'taskExecutionPolicyRunCount': taskExecutionPolicyRunCount,
    'networkDisabledTaskPolicyRunCount': networkDisabledTaskPolicyRunCount,
    'taskResourceLimitRunCount': taskResourceLimitRunCount,
    'sdkVersionRunCount': sdkVersionRunCount,
    'dependencySnapshotRunCount': dependencySnapshotRunCount,
    'pricingRegistryRunCount': pricingRegistryRunCount,
    'generatedCodeSandboxBackends': generatedCodeSandboxBackends,
    'dartVersions': dartVersions,
    'flutterVersions': flutterVersions,
    'environmentIds': environmentIds,
    'warnings': warnings,
  };
}

Map<String, Object?>? _decodeRunProvenance(String? provenanceJson) {
  if (provenanceJson == null || provenanceJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(provenanceJson);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    return null;
  } on Object {
    return null;
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return const {};
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final entry in value)
      if (entry is Map) _objectMap(entry),
  ];
}

bool _hasTaskExecutionPolicy(Map<String, Object?> task) {
  final policy = _objectMap(task['executionPolicy']);
  return policy['allowInternet'] is bool && policy['resources'] is Map;
}

bool _hasNetworkDisabledTaskPolicy(Map<String, Object?> task) {
  final policy = _objectMap(task['executionPolicy']);
  return policy['allowInternet'] == false;
}

bool _hasTaskResourceLimits(Map<String, Object?> task) {
  final policy = _objectMap(task['executionPolicy']);
  final resources = _objectMap(policy['resources']);
  return _positiveNumber(resources['cpus']) &&
      _positiveNumber(resources['memoryMb']) &&
      _positiveNumber(resources['maxProcesses']) &&
      _positiveNumber(resources['maxOutputBytes']) &&
      _hasTaskResourceEnforcement(policy);
}

bool _hasTaskResourceEnforcement(Map<String, Object?> policy) {
  final enforcement = _objectMap(policy['resourceEnforcement']);
  for (final key in const [
    'cpus',
    'memoryMb',
    'maxProcesses',
    'maxOutputBytes',
  ]) {
    final field = _objectMap(enforcement[key]);
    if (field['enforced'] != true) return false;
    final mechanism = _nonEmptyString(field['mechanism']);
    if (mechanism == null) return false;
    if (field['kernelEnforced'] is! bool) return false;
  }
  return true;
}

bool _positiveNumber(Object? value) => value is num && value > 0;

String? _sdkVersion(Object? value) {
  final version = _nonEmptyString(value);
  if (version == null || version == 'unknown') return null;
  return version.split(RegExp(r'\s+')).first;
}

String? _environmentId(Map<String, Object?> environment) {
  final dartVersion = _sdkVersion(environment['dartVersion']);
  final flutterVersion = _sdkVersion(environment['flutterVersion']);
  final lockfile = _dependencyLockfile(environment);
  final hostPlatform = _nonEmptyString(environment['hostPlatform']);
  if (dartVersion == null &&
      flutterVersion == null &&
      lockfile == null &&
      hostPlatform == null) {
    return null;
  }

  final encoded = jsonEncode({
    'dartVersion': dartVersion,
    'flutterVersion': flutterVersion,
    'hostPlatform': hostPlatform,
    'pubspecLockSha256': lockfile == null
        ? null
        : _nonEmptyString(lockfile['sha256']),
  });
  return sha256.convert(utf8.encode(encoded)).toString().substring(0, 12);
}

bool _hasDependencySnapshot(Map<String, Object?> environment) {
  final snapshot = _objectMap(environment['dependencySnapshot']);
  if (snapshot['status'] != 'present') return false;
  final lockfile = _dependencyLockfile(environment);
  final digest = lockfile == null ? null : _nonEmptyString(lockfile['sha256']);
  return digest != null;
}

Map<String, Object?>? _dependencyLockfile(Map<String, Object?> environment) {
  final snapshot = _objectMap(environment['dependencySnapshot']);
  final files = _objectMap(snapshot['files']);
  final lockfile = _objectMap(files['pubspec.lock']);
  return lockfile.isEmpty ? null : lockfile;
}

bool _hasPricingRegistry(Map<String, Object?> pricingRegistry) {
  return _nonEmptyString(pricingRegistry['version']) != null &&
      _nonEmptyString(pricingRegistry['currency']) != null &&
      pricingRegistry['modelCount'] is int;
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _RunCompatibilitySignature {
  const _RunCompatibilitySignature({
    required this.taskKeys,
    required this.harnessIds,
  });

  factory _RunCompatibilitySignature.fromTaskRuns(List<TaskRun> taskRuns) {
    return _RunCompatibilitySignature(
      taskKeys: (taskRuns.map((taskRun) => _taskKey(taskRun)).toSet().toList()
        ..sort()),
      harnessIds:
          (taskRuns
              .map((taskRun) => taskRun.harnessId)
              .whereType<String>()
              .toSet()
              .toList()
            ..sort()),
    );
  }

  final List<String> taskKeys;
  final List<String> harnessIds;

  @override
  bool operator ==(Object other) {
    return other is _RunCompatibilitySignature &&
        _listEquals(taskKeys, other.taskKeys) &&
        _listEquals(harnessIds, other.harnessIds);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(taskKeys), Object.hashAll(harnessIds));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _PassSplit {
  const _PassSplit({
    required this.publicPassCount,
    required this.publicSampleCount,
    required this.hiddenPassCount,
    required this.hiddenSampleCount,
  });

  factory _PassSplit.fromTaskRuns(
    List<TaskRun> taskRuns,
    Map<String, List<Evaluation>> evaluationsByTaskRunId,
  ) {
    var publicPassCount = 0;
    var publicSampleCount = 0;
    var hiddenPassCount = 0;
    var hiddenSampleCount = 0;

    for (final taskRun in taskRuns) {
      final evaluations = evaluationsByTaskRunId[taskRun.id] ?? const [];
      final publicEvaluations = evaluations
          .where((evaluation) => _countsForPublicPassSplit(evaluation))
          .toList(growable: false);
      final hiddenEvaluations = evaluations
          .where((evaluation) => _countsForHiddenPassSplit(evaluation))
          .toList(growable: false);

      if (publicEvaluations.isNotEmpty) {
        publicSampleCount++;
        if (publicEvaluations.every((evaluation) => evaluation.passed)) {
          publicPassCount++;
        }
      }
      if (hiddenEvaluations.isNotEmpty) {
        hiddenSampleCount++;
        if (hiddenEvaluations.every((evaluation) => evaluation.passed)) {
          hiddenPassCount++;
        }
      }
    }

    return _PassSplit(
      publicPassCount: publicPassCount,
      publicSampleCount: publicSampleCount,
      hiddenPassCount: hiddenPassCount,
      hiddenSampleCount: hiddenSampleCount,
    );
  }

  final int publicPassCount;
  final int publicSampleCount;
  final int hiddenPassCount;
  final int hiddenSampleCount;

  Map<String, Object?> toJson() => {
    'publicPassCount': publicPassCount,
    'publicSampleCount': publicSampleCount,
    'publicPassRate': publicSampleCount == 0
        ? null
        : publicPassCount / publicSampleCount,
    'hiddenPassCount': hiddenPassCount,
    'hiddenSampleCount': hiddenSampleCount,
    'hiddenPassRate': hiddenSampleCount == 0
        ? null
        : hiddenPassCount / hiddenSampleCount,
  };
}

class _PassAtKSummary {
  const _PassAtKSummary(this.entries);

  static const defaultKValues = [1, 2, 3, 5, 10];

  factory _PassAtKSummary.fromTaskRuns(
    List<TaskRun> taskRuns, {
    required String Function(TaskRun taskRun) groupKey,
  }) {
    final groups = <String, List<TaskRun>>{};
    for (final taskRun in taskRuns.where(
      (taskRun) => taskRun.primaryPass != null,
    )) {
      groups.putIfAbsent(groupKey(taskRun), () => <TaskRun>[]).add(taskRun);
    }
    for (final group in groups.values) {
      group.sort(_comparePassAtKTaskRuns);
    }

    final entries = <int, _PassAtKEntry>{};
    for (final k in defaultKValues) {
      var sampleCount = 0;
      var passCount = 0;
      for (final group in groups.values) {
        if (group.length < k) continue;
        sampleCount++;
        if (group.take(k).any((taskRun) => taskRun.primaryPass == true)) {
          passCount++;
        }
      }
      if (sampleCount == 0) continue;
      entries[k] = _PassAtKEntry(
        k: k,
        passCount: passCount,
        sampleCount: sampleCount,
      );
    }
    return _PassAtKSummary(entries);
  }

  final Map<int, _PassAtKEntry> entries;

  Map<String, Object?> toJson() => {
    for (final entry in entries.entries) '${entry.key}': entry.value.toJson(),
  };
}

class _PassAtKEntry {
  const _PassAtKEntry({
    required this.k,
    required this.passCount,
    required this.sampleCount,
  });

  final int k;
  final int passCount;
  final int sampleCount;

  Map<String, Object?> toJson() => {
    'k': k,
    'passCount': passCount,
    'sampleCount': sampleCount,
    'passRate': sampleCount == 0 ? null : passCount / sampleCount,
  };
}

int _comparePassAtKTaskRuns(TaskRun a, TaskRun b) {
  final trialCompare = a.trialIndex.compareTo(b.trialIndex);
  if (trialCompare != 0) return trialCompare;
  final completedCompare = a.completedAt.compareTo(b.completedAt);
  if (completedCompare != 0) return completedCompare;
  return a.id.compareTo(b.id);
}

class _TrialEvaluationSummary {
  const _TrialEvaluationSummary({
    required this.publicPassed,
    required this.hiddenPassed,
    required this.blockedEvaluationCount,
  });

  factory _TrialEvaluationSummary.fromEvaluations(
    List<Evaluation> evaluations,
  ) {
    final publicEvaluations = evaluations
        .where((evaluation) => _countsForPublicPassSplit(evaluation))
        .toList(growable: false);
    final hiddenEvaluations = evaluations
        .where((evaluation) => _countsForHiddenPassSplit(evaluation))
        .toList(growable: false);
    return _TrialEvaluationSummary(
      publicPassed: publicEvaluations.isEmpty
          ? null
          : publicEvaluations.every((evaluation) => evaluation.passed),
      hiddenPassed: hiddenEvaluations.isEmpty
          ? null
          : hiddenEvaluations.every((evaluation) => evaluation.passed),
      blockedEvaluationCount: evaluations.where(_isBlocked).length,
    );
  }

  final bool? publicPassed;
  final bool? hiddenPassed;
  final int blockedEvaluationCount;
}

class _TraceMetricSummary {
  const _TraceMetricSummary({
    required this.medianStepCount,
    required this.medianPeakContextTokens,
    required this.sampleCount,
    required this.stepCountKnownCount,
    required this.peakContextTokensKnownCount,
    required this.completeTraceMetricCount,
  });

  factory _TraceMetricSummary.fromTaskRuns(
    List<TaskRun> taskRuns,
    Map<String, List<Evaluation>> evaluationsByTaskRunId,
  ) {
    final metrics = [
      for (final taskRun in taskRuns)
        _TraceMetrics.fromEvaluations(
          evaluationsByTaskRunId[taskRun.id] ?? const <Evaluation>[],
        ),
    ];
    final stepCountKnownCount = metrics
        .where((metric) => metric.stepCount != null)
        .length;
    final peakContextTokensKnownCount = metrics
        .where((metric) => metric.peakContextTokens != null)
        .length;
    return _TraceMetricSummary(
      medianStepCount: medianInt(metrics.map((metric) => metric.stepCount)),
      medianPeakContextTokens: medianInt(
        metrics.map((metric) => metric.peakContextTokens),
      ),
      sampleCount: metrics.length,
      stepCountKnownCount: stepCountKnownCount,
      peakContextTokensKnownCount: peakContextTokensKnownCount,
      completeTraceMetricCount: metrics
          .where(
            (metric) =>
                metric.stepCount != null && metric.peakContextTokens != null,
          )
          .length,
    );
  }

  final int? medianStepCount;
  final int? medianPeakContextTokens;
  final int sampleCount;
  final int stepCountKnownCount;
  final int peakContextTokensKnownCount;
  final int completeTraceMetricCount;

  Map<String, Object?> coverageJson() => {
    'sampleCount': sampleCount,
    'stepCountKnownCount': stepCountKnownCount,
    'stepCountUnknownCount': sampleCount - stepCountKnownCount,
    'peakContextTokensKnownCount': peakContextTokensKnownCount,
    'peakContextTokensUnknownCount': sampleCount - peakContextTokensKnownCount,
    'completeTraceMetricCount': completeTraceMetricCount,
  };
}

class _TraceMetrics {
  const _TraceMetrics({this.stepCount, this.peakContextTokens});

  factory _TraceMetrics.fromEvaluations(List<Evaluation> evaluations) {
    final harnessEvaluations = evaluations.where(
      (evaluation) => evaluation.evaluatorId == 'agent_harness',
    );
    for (final evaluation in harnessEvaluations) {
      final details = decodeEvaluationDetailsJson(evaluation.detailsJson);
      final stepCount = _firstIntMetric(details, const [
        'step_count',
        'stepCount',
        'steps',
        'tool_call_count',
        'toolCallCount',
      ]);
      final peakContextTokens = _firstIntMetric(details, const [
        'peak_context_tokens',
        'peakContextTokens',
        'peak_context',
        'peakContext',
        'context_tokens',
        'contextTokens',
        'context_window_tokens',
        'contextWindowTokens',
      ]);
      if (stepCount != null || peakContextTokens != null) {
        return _TraceMetrics(
          stepCount: stepCount,
          peakContextTokens: peakContextTokens,
        );
      }
    }
    return const _TraceMetrics();
  }

  final int? stepCount;
  final int? peakContextTokens;

  Map<String, Object?> statusJson() => {
    'stepCount': stepCount == null ? 'unknown' : 'reported',
    'peakContextTokens': peakContextTokens == null ? 'unknown' : 'reported',
  };
}

class _TokenUsageCoverage {
  const _TokenUsageCoverage({
    required this.sampleCount,
    required this.promptTokensKnownCount,
    required this.completionTokensKnownCount,
    required this.completeTokenUsageCount,
  });

  factory _TokenUsageCoverage.fromTaskRuns(List<TaskRun> taskRuns) {
    return _TokenUsageCoverage(
      sampleCount: taskRuns.length,
      promptTokensKnownCount: taskRuns
          .where((taskRun) => taskRun.promptTokens != null)
          .length,
      completionTokensKnownCount: taskRuns
          .where((taskRun) => taskRun.completionTokens != null)
          .length,
      completeTokenUsageCount: taskRuns
          .where(
            (taskRun) =>
                taskRun.promptTokens != null &&
                taskRun.completionTokens != null,
          )
          .length,
    );
  }

  final int sampleCount;
  final int promptTokensKnownCount;
  final int completionTokensKnownCount;
  final int completeTokenUsageCount;

  Map<String, Object?> toJson() => {
    'sampleCount': sampleCount,
    'promptTokensKnownCount': promptTokensKnownCount,
    'promptTokensUnknownCount': sampleCount - promptTokensKnownCount,
    'completionTokensKnownCount': completionTokensKnownCount,
    'completionTokensUnknownCount': sampleCount - completionTokensKnownCount,
    'completeTokenUsageCount': completeTokenUsageCount,
  };
}

class _TokenUsageStatus {
  const _TokenUsageStatus({
    required this.promptTokens,
    required this.completionTokens,
  });

  factory _TokenUsageStatus.fromTaskRun(TaskRun taskRun) => _TokenUsageStatus(
    promptTokens: taskRun.promptTokens == null ? 'unknown' : 'reported',
    completionTokens: taskRun.completionTokens == null ? 'unknown' : 'reported',
  );

  final String promptTokens;
  final String completionTokens;

  Map<String, Object?> toJson() => {
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
  };
}

int? _firstIntMetric(Map<String, Object?> details, List<String> keys) {
  final direct = _firstIntMetricFrom(details, keys);
  if (direct != null) return direct;
  for (final nestedKey in const ['usage', 'token_usage', 'metadata']) {
    final nested = details[nestedKey];
    if (nested is Map<String, Object?>) {
      final metric = _firstIntMetricFrom(nested, keys);
      if (metric != null) return metric;
    } else if (nested is Map) {
      final normalized = nested.map((key, value) => MapEntry('$key', value));
      final metric = _firstIntMetricFrom(normalized, keys);
      if (metric != null) return metric;
    }
  }
  return null;
}

int? _firstIntMetricFrom(Map<String, Object?> source, List<String> keys) {
  for (final key in keys) {
    final metric = _intMetric(source[key]);
    if (metric != null) return metric;
  }
  return null;
}

int? _intMetric(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value.isFinite && value >= 0) return value.round();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed >= 0) return parsed;
  }
  if (value is List) return value.length;
  return null;
}

class _BlockedSummary {
  const _BlockedSummary({
    required this.blockedEvaluationCount,
    required this.blockedTaskRunCount,
  });

  factory _BlockedSummary.fromTaskRuns(
    List<TaskRun> taskRuns,
    Map<String, List<Evaluation>> evaluationsByTaskRunId,
  ) {
    var blockedEvaluationCount = 0;
    var blockedTaskRunCount = 0;
    for (final taskRun in taskRuns) {
      final evaluations = evaluationsByTaskRunId[taskRun.id] ?? const [];
      final blockedForTaskRun = evaluations.where(_isBlocked).length;
      blockedEvaluationCount += blockedForTaskRun;
      if (blockedForTaskRun > 0) blockedTaskRunCount++;
    }
    return _BlockedSummary(
      blockedEvaluationCount: blockedEvaluationCount,
      blockedTaskRunCount: blockedTaskRunCount,
    );
  }

  final int blockedEvaluationCount;
  final int blockedTaskRunCount;

  Map<String, Object?> toJson() => {
    'blockedEvaluationCount': blockedEvaluationCount,
    'blockedTaskRunCount': blockedTaskRunCount,
  };
}

class _JudgeOverheadSummary {
  const _JudgeOverheadSummary({
    required this.evaluationCount,
    required this.promptTokens,
    required this.completionTokens,
    required this.knownEstimatedCostCount,
    required this.unknownEstimatedCostCount,
    required this.totalEstimatedCostMicros,
    required this.pricingStatusCounts,
  });

  factory _JudgeOverheadSummary.fromTaskRuns(
    List<TaskRun> taskRuns,
    Map<String, List<Evaluation>> evaluationsByTaskRunId,
  ) {
    var evaluationCount = 0;
    var promptTokens = 0;
    var completionTokens = 0;
    var knownEstimatedCostCount = 0;
    var unknownEstimatedCostCount = 0;
    var totalEstimatedCostMicros = 0;
    final pricingStatusCounts = <String, int>{};

    for (final taskRun in taskRuns) {
      final evaluations = evaluationsByTaskRunId[taskRun.id] ?? const [];
      for (final evaluation in evaluations) {
        if (evaluation.evaluatorId != 'llm_judge') continue;
        final details = decodeEvaluationDetailsJson(evaluation.detailsJson);
        final overhead = details['judge_overhead'];
        if (overhead is! Map) continue;

        evaluationCount++;
        final prompt = overhead['prompt_tokens'];
        if (prompt is int) promptTokens += prompt;
        final completion = overhead['completion_tokens'];
        if (completion is int) completionTokens += completion;
        final cost = overhead['estimated_cost_micros'];
        if (cost is int) {
          knownEstimatedCostCount++;
          totalEstimatedCostMicros += cost;
        } else {
          unknownEstimatedCostCount++;
        }
        final status = overhead['pricing_status'];
        final statusKey = status is String && status.isNotEmpty
            ? status
            : 'unknown';
        pricingStatusCounts[statusKey] =
            (pricingStatusCounts[statusKey] ?? 0) + 1;
      }
    }

    return _JudgeOverheadSummary(
      evaluationCount: evaluationCount,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      knownEstimatedCostCount: knownEstimatedCostCount,
      unknownEstimatedCostCount: unknownEstimatedCostCount,
      totalEstimatedCostMicros: totalEstimatedCostMicros,
      pricingStatusCounts: pricingStatusCounts,
    );
  }

  final int evaluationCount;
  final int promptTokens;
  final int completionTokens;
  final int knownEstimatedCostCount;
  final int unknownEstimatedCostCount;
  final int totalEstimatedCostMicros;
  final Map<String, int> pricingStatusCounts;

  Map<String, Object?> toJson() => {
    'evaluationCount': evaluationCount,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'knownEstimatedCostCount': knownEstimatedCostCount,
    'unknownEstimatedCostCount': unknownEstimatedCostCount,
    'totalEstimatedCostMicros': totalEstimatedCostMicros,
    'pricingStatusCounts': Map<String, int>.fromEntries(
      pricingStatusCounts.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    ),
  };
}

bool _countsForPublicPassSplit(Evaluation evaluation) {
  return isPublicTestEvaluatorId(evaluation.evaluatorId) &&
      !_isIgnoredSkippedOrBlocked(evaluation);
}

bool _countsForHiddenPassSplit(Evaluation evaluation) {
  return isHiddenVerifierEvaluatorId(evaluation.evaluatorId) &&
      !_isIgnoredSkippedOrBlocked(evaluation);
}

bool _isIgnoredSkippedOrBlocked(Evaluation evaluation) {
  final details = decodeEvaluationDetailsJson(evaluation.detailsJson);
  return details['ignored'] == true ||
      details['skipped'] == true ||
      details['blocked'] == true;
}

bool _isBlocked(Evaluation evaluation) {
  final details = decodeEvaluationDetailsJson(evaluation.detailsJson);
  return details['blocked'] == true;
}

class _EvaluatorWeightsParse {
  const _EvaluatorWeightsParse({this.weights, this.warning});

  factory _EvaluatorWeightsParse.warning(String warning) {
    return _EvaluatorWeightsParse(warning: warning);
  }

  final Map<String, Object?>? weights;
  final String? warning;
}
