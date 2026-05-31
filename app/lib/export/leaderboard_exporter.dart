import 'dart:convert';

import 'package:dart_arena/analytics/benchmark_statistics.dart';
import 'package:dart_arena/storage/database.dart';

enum LeaderboardExportStrategy { aggregateCompatible, latestRun, bestObserved }

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
  });

  final String track;
  final LeaderboardExportStrategy strategy;
  final String? runId;
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
  final taskKeys = selected.taskRuns.map(_taskKey).toSet();
  final modelKeys = selected.taskRuns
      .map((taskRun) => '${taskRun.providerId}:${taskRun.modelId}')
      .toSet();

  if (selected.taskRuns.isEmpty) {
    warnings.add(
      'No completed task runs matched track "${options.track}" and the selected scope.',
    );
  }

  final models = _buildModelRows(selected.taskRuns, warnings);
  final tasks = _buildTaskRows(selected.taskRuns, warnings);

  return <String, Object?>{
    'schemaVersion': 1,
    'generatedAt': generatedAt.toIso8601String(),
    'benchmark': <String, Object?>{
      'name': 'Dart Arena',
      'brand': 'Pickforge',
      'title': 'Dart Arena by Pickforge',
      'track': options.track,
      'dataPolicy': options.strategy.kebabName,
    },
    'source': <String, Object?>{
      'anchorRunId': selected.anchorRunId,
      'runIds': sortedRunIds,
      'taskCount': taskKeys.length,
      'taskRunCount': selected.taskRuns.length,
      'modelCount': modelKeys.length,
      'warnings': warnings.toSet().toList()..sort(),
    },
    'models': models,
    'tasks': tasks,
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
    rows.add(_ModelRow.fromMetrics(group.first, metrics));
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
    if (sampleCount == 0) {
      warnings.add(
        'Task ${_taskKey(group.first)} has no primary-pass samples.',
      );
    }
    final modelCount = group
        .map((taskRun) => '${taskRun.providerId}:${taskRun.modelId}')
        .toSet()
        .length;
    rows.add(<String, Object?>{
      'taskId': group.first.taskId,
      'taskVersion': group.first.taskVersion,
      'benchmarkTrack': group.first.benchmarkTrack,
      'sampleCount': sampleCount,
      'modelCount': modelCount,
      'passRate': sampleCount == 0 ? 0.0 : passCount / sampleCount,
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

String _taskKey(TaskRun taskRun) =>
    '${taskRun.taskId}@${taskRun.taskVersion}@${taskRun.benchmarkTrack}';

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
    required this.confidenceLower,
    required this.confidenceUpper,
    required this.lowSample,
    required this.medianLatencyMs,
    required this.medianPromptTokens,
    required this.medianCompletionTokens,
    required this.medianEstimatedCostMicros,
    required this.costPerSolvedTaskMicros,
    required this.failureBreakdown,
  });

  factory _ModelRow.fromMetrics(TaskRun first, RankingMetrics metrics) {
    final passRate = metrics.primaryPassSampleCount == 0
        ? 0.0
        : metrics.primaryPassCount / metrics.primaryPassSampleCount;
    return _ModelRow(
      providerId: first.providerId,
      modelId: first.modelId,
      score: passRate,
      passCount: metrics.primaryPassCount,
      sampleCount: metrics.primaryPassSampleCount,
      confidenceLower: metrics.primaryPassInterval?.lower ?? 0.0,
      confidenceUpper: metrics.primaryPassInterval?.upper ?? 0.0,
      lowSample: metrics.lowSample,
      medianLatencyMs: metrics.medianLatencyMs,
      medianPromptTokens: metrics.medianPromptTokens,
      medianCompletionTokens: metrics.medianCompletionTokens,
      medianEstimatedCostMicros: metrics.medianEstimatedCostMicros,
      costPerSolvedTaskMicros: metrics.costPerSolvedTaskMicros,
      failureBreakdown: metrics.failureBreakdown,
    );
  }

  final String providerId;
  final String modelId;
  final double score;
  final int passCount;
  final int sampleCount;
  final double confidenceLower;
  final double confidenceUpper;
  final bool lowSample;
  final int? medianLatencyMs;
  final int? medianPromptTokens;
  final int? medianCompletionTokens;
  final int? medianEstimatedCostMicros;
  final int? costPerSolvedTaskMicros;
  final Map<String, int> failureBreakdown;

  Map<String, Object?> toJson({required int rank}) {
    final sortedFailures = Map<String, int>.fromEntries(
      failureBreakdown.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return <String, Object?>{
      'providerId': providerId,
      'modelId': modelId,
      'rank': rank,
      'score': score,
      'passRate': score,
      'passCount': passCount,
      'sampleCount': sampleCount,
      'confidenceInterval': <String, Object?>{
        'lower': confidenceLower,
        'upper': confidenceUpper,
      },
      'lowSample': lowSample,
      'medianLatencyMs': medianLatencyMs,
      'medianPromptTokens': medianPromptTokens,
      'medianCompletionTokens': medianCompletionTokens,
      'medianEstimatedCostMicros': medianEstimatedCostMicros,
      'costPerSolvedTaskMicros': costPerSolvedTaskMicros,
      'failureBreakdown': sortedFailures,
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

class _EvaluatorWeightsParse {
  const _EvaluatorWeightsParse({this.weights, this.warning});

  factory _EvaluatorWeightsParse.warning(String warning) {
    return _EvaluatorWeightsParse(warning: warning);
  }

  final Map<String, Object?>? weights;
  final String? warning;
}
