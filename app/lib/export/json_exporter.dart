import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/evaluation_status.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:dart_arena/core/model_identity.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';

String runResultsToJson(
  RunSummary summary, {
  Map<String, String> responseArtifactsByTaskRunId = const {},
  Map<String, String> patchArtifactsByTaskRunId = const {},
  Map<String, String> trajectoryArtifactsByTaskRunId = const {},
  Map<String, Map<String, Map<String, Object?>>> artifactMetadataByTaskRunId =
      const {},
}) {
  return const JsonEncoder.withIndent('  ').convert(
    runResultsToMap(
      summary,
      responseArtifactsByTaskRunId: responseArtifactsByTaskRunId,
      patchArtifactsByTaskRunId: patchArtifactsByTaskRunId,
      trajectoryArtifactsByTaskRunId: trajectoryArtifactsByTaskRunId,
      artifactMetadataByTaskRunId: artifactMetadataByTaskRunId,
    ),
  );
}

Map<String, Object?> runResultsToMap(
  RunSummary summary, {
  Map<String, String> responseArtifactsByTaskRunId = const {},
  Map<String, String> patchArtifactsByTaskRunId = const {},
  Map<String, String> trajectoryArtifactsByTaskRunId = const {},
  Map<String, Map<String, Map<String, Object?>>> artifactMetadataByTaskRunId =
      const {},
}) {
  final taskRuns = summary.taskRuns.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final modelConfigIndex = ModelConfigIndex.fromRunProvenanceJson(
    summary.run.provenanceJson,
  );
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
          modelConfigIndex: modelConfigIndex,
          responseArtifactsByTaskRunId: responseArtifactsByTaskRunId,
          patchArtifactsByTaskRunId: patchArtifactsByTaskRunId,
          trajectoryArtifactsByTaskRunId: trajectoryArtifactsByTaskRunId,
          artifactMetadataByTaskRunId: artifactMetadataByTaskRunId,
        ),
    ],
  };
}

Map<String, Object?> _taskRunJson(
  TaskRun taskRun,
  List<Evaluation> evaluations, {
  required ModelConfigIndex modelConfigIndex,
  required Map<String, String> responseArtifactsByTaskRunId,
  required Map<String, String> patchArtifactsByTaskRunId,
  required Map<String, String> trajectoryArtifactsByTaskRunId,
  required Map<String, Map<String, Map<String, Object?>>>
  artifactMetadataByTaskRunId,
}) {
  final artifactMetadata = artifactMetadataByTaskRunId[taskRun.id];
  return {
    'id': taskRun.id,
    'runId': taskRun.runId,
    'taskId': taskRun.taskId,
    'providerId': taskRun.providerId,
    'modelId': taskRun.modelId,
    ...modelConfigIndex.exportJsonFor(
      providerId: taskRun.providerId,
      modelId: taskRun.modelId,
    ),
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
    if (artifactMetadata != null && artifactMetadata.isNotEmpty)
      'artifactMetadata': artifactMetadata,
    'evaluations': [
      for (final evaluation in evaluations) _evaluationJson(evaluation),
    ],
  };
}

Map<String, Object?> _evaluationJson(Evaluation evaluation) {
  final details = decodeEvaluationDetailsJson(evaluation.detailsJson);
  final status = evaluationStatus(passed: evaluation.passed, details: details);
  final blockedBy = details[blockedByDetailKey];
  final agentHarness = _agentHarnessJson(evaluation, details);
  return {
    'id': evaluation.id,
    'evaluatorId': evaluation.evaluatorId,
    'passed': evaluation.passed,
    'score': evaluation.score,
    'status': evaluationStatusName(status),
    'rationale': evaluation.rationale,
    if (status == EvaluationStatus.blocked && blockedBy != null)
      'blockedBy': '$blockedBy',
    if (status == EvaluationStatus.blocked && blockedBy != null)
      'blockedReason': 'blocked by $blockedBy',
    if (_judgeOverheadJson(details) != null)
      'judgeOverhead': _judgeOverheadJson(details),
    if (agentHarness != null) 'agentHarness': agentHarness,
    'detailsJsonSha256': _sha256(evaluation.detailsJson),
    'detailsJsonBytes': utf8.encode(evaluation.detailsJson).length,
  };
}

Map<String, Object?>? _agentHarnessJson(
  Evaluation evaluation,
  Map<String, Object?> details,
) {
  if (evaluation.evaluatorId != 'agent_harness') return null;
  final status = _validAgentHarnessStatus(details['status']);
  if (status == null) return null;
  return {
    'status': status,
    'exitCode': details['exit_code'] is int ? details['exit_code'] : null,
    'stdoutPreviewPresent': _nonEmptyString(details['stdout_preview']) != null,
    'stderrPreviewPresent': _nonEmptyString(details['stderr_preview']) != null,
    'trajectoryLogPresent':
        _nonEmptyString(details['trajectory_log_path']) != null,
  };
}

String? _validAgentHarnessStatus(Object? value) {
  final status = _nonEmptyString(value);
  if (status == null) return null;
  return const {'success', 'failure', 'timeout', 'cancelled'}.contains(status)
      ? status
      : null;
}

Map<String, Object?>? _judgeOverheadJson(Map<String, Object?> details) {
  final overhead = details['judge_overhead'];
  if (overhead is! Map) return null;
  final providerId = overhead['provider_id'];
  final modelId = overhead['model_id'];
  final pricingStatus = overhead['pricing_status'];
  if (providerId is! String || modelId is! String || pricingStatus is! String) {
    return null;
  }
  return {
    'providerId': providerId,
    'modelId': modelId,
    'promptTokens': overhead['prompt_tokens'] is int
        ? overhead['prompt_tokens']
        : null,
    'completionTokens': overhead['completion_tokens'] is int
        ? overhead['completion_tokens']
        : null,
    'estimatedCostMicros': overhead['estimated_cost_micros'] is int
        ? overhead['estimated_cost_micros']
        : null,
    'pricingStatus': pricingStatus,
    if (overhead['pricing_registry_version'] is String)
      'pricingRegistryVersion': overhead['pricing_registry_version'],
    if (overhead['pricing_currency'] is String)
      'pricingCurrency': overhead['pricing_currency'],
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

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
