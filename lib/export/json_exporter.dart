import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';

String runResultsToJson(
  RunSummary summary, {
  Map<String, String> responseArtifactsByTaskRunId = const {},
  Map<String, String> patchArtifactsByTaskRunId = const {},
  Map<String, String> trajectoryArtifactsByTaskRunId = const {},
}) {
  return const JsonEncoder.withIndent('  ').convert(
    runResultsToMap(
      summary,
      responseArtifactsByTaskRunId: responseArtifactsByTaskRunId,
      patchArtifactsByTaskRunId: patchArtifactsByTaskRunId,
      trajectoryArtifactsByTaskRunId: trajectoryArtifactsByTaskRunId,
    ),
  );
}

Map<String, Object?> runResultsToMap(
  RunSummary summary, {
  Map<String, String> responseArtifactsByTaskRunId = const {},
  Map<String, String> patchArtifactsByTaskRunId = const {},
  Map<String, String> trajectoryArtifactsByTaskRunId = const {},
}) {
  final taskRuns = summary.taskRuns.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return {
    'schemaVersion': 1,
    'run': {
      'id': summary.run.id,
      'name': summary.run.name,
      'startedAt': summary.run.startedAt.toUtc().toIso8601String(),
      'completedAt': summary.run.completedAt?.toUtc().toIso8601String(),
    },
    'taskRuns': [
      for (final taskRun in taskRuns)
        _taskRunJson(
          taskRun,
          _sortedEvaluations(
            summary.evaluationsByTaskRunId[taskRun.id] ?? const <Evaluation>[],
          ),
          responseArtifactsByTaskRunId: responseArtifactsByTaskRunId,
          patchArtifactsByTaskRunId: patchArtifactsByTaskRunId,
          trajectoryArtifactsByTaskRunId: trajectoryArtifactsByTaskRunId,
        ),
    ],
  };
}

Map<String, Object?> _taskRunJson(
  TaskRun taskRun,
  List<Evaluation> evaluations, {
  required Map<String, String> responseArtifactsByTaskRunId,
  required Map<String, String> patchArtifactsByTaskRunId,
  required Map<String, String> trajectoryArtifactsByTaskRunId,
}) {
  return {
    'id': taskRun.id,
    'runId': taskRun.runId,
    'taskId': taskRun.taskId,
    'providerId': taskRun.providerId,
    'modelId': taskRun.modelId,
    'trialIndex': taskRun.trialIndex,
    'taskVersion': taskRun.taskVersion,
    'benchmarkTrack': taskRun.benchmarkTrack,
    'harnessId': taskRun.harnessId,
    'primaryPass': taskRun.primaryPass,
    'failureTag': taskRun.failureTag,
    'aggregateScore': taskRun.aggregateScore,
    'completedAt': taskRun.completedAt.toUtc().toIso8601String(),
    'latencyMs': taskRun.latencyMs,
    'promptTokens': taskRun.promptTokens,
    'completionTokens': taskRun.completionTokens,
    'responseTextSha256': _sha256(taskRun.responseText),
    'responseTextBytes': utf8.encode(taskRun.responseText).length,
    'patchTextSha256': taskRun.patchText == null
        ? null
        : _sha256(taskRun.patchText!),
    'patchTextBytes': taskRun.patchText == null
        ? null
        : utf8.encode(taskRun.patchText!).length,
    'artifacts': {
      if (responseArtifactsByTaskRunId[taskRun.id] != null)
        'response': responseArtifactsByTaskRunId[taskRun.id],
      if (patchArtifactsByTaskRunId[taskRun.id] != null)
        'patch': patchArtifactsByTaskRunId[taskRun.id],
      if (trajectoryArtifactsByTaskRunId[taskRun.id] != null)
        'trajectory': trajectoryArtifactsByTaskRunId[taskRun.id],
    },
    'evaluations': [
      for (final evaluation in evaluations)
        {
          'id': evaluation.id,
          'evaluatorId': evaluation.evaluatorId,
          'passed': evaluation.passed,
          'score': evaluation.score,
          'rationale': evaluation.rationale,
          'detailsJsonSha256': _sha256(evaluation.detailsJson),
          'detailsJsonBytes': utf8.encode(evaluation.detailsJson).length,
        },
    ],
  };
}

List<Evaluation> _sortedEvaluations(List<Evaluation> evaluations) {
  return evaluations.toList()..sort((a, b) {
    final evaluator = a.evaluatorId.compareTo(b.evaluatorId);
    if (evaluator != 0) return evaluator;
    return a.id.compareTo(b.id);
  });
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();
