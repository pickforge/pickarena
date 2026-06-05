import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_classification.dart';

const blockedDetailKey = 'blocked';
const blockedByDetailKey = 'blocked_by';
const blockedByRationaleDetailKey = 'blocked_by_rationale';

bool isBlockedEvaluation(EvaluationResult result) =>
    result.details[blockedDetailKey] == true;

EvaluationResult? blockedEvaluationFor({
  required String evaluatorId,
  required List<EvaluationResult> previousResults,
  bool blockAllDownstream = false,
}) {
  final blocker = blockingEvaluationFor(
    evaluatorId: evaluatorId,
    previousResults: previousResults,
    blockAllDownstream: blockAllDownstream,
  );
  if (blocker == null) return null;
  return blockedEvaluation(
    evaluatorId: evaluatorId,
    blockedBy: blocker.evaluatorId,
    blockedByRationale: blocker.rationale,
  );
}

EvaluationResult blockedEvaluation({
  required String evaluatorId,
  required String blockedBy,
  String? blockedByRationale,
}) {
  return EvaluationResult(
    evaluatorId: evaluatorId,
    passed: false,
    score: 0.0,
    rationale: 'blocked by $blockedBy',
    details: const {},
  ).copyWithBlocked(
    blockedBy: blockedBy,
    blockedByRationale: blockedByRationale,
  );
}

EvaluationResult environmentFailureEvaluation({
  required String rationale,
  required String stderr,
  String phase = 'prepare',
}) {
  return EvaluationResult(
    evaluatorId: 'environment',
    passed: false,
    score: 0.0,
    rationale: rationale,
    details: {
      'code': 'environment_error',
      'phase': phase,
      'stderr': stderr,
      if (stderr.toLowerCase().contains('timed out')) 'error': 'timeout',
    },
  );
}

String? blockedByEvaluatorIdFor({
  required String evaluatorId,
  required List<EvaluationResult> previousResults,
  bool blockAllDownstream = false,
}) {
  return blockingEvaluationFor(
    evaluatorId: evaluatorId,
    previousResults: previousResults,
    blockAllDownstream: blockAllDownstream,
  )?.evaluatorId;
}

EvaluationResult? blockingEvaluationFor({
  required String evaluatorId,
  required List<EvaluationResult> previousResults,
  bool blockAllDownstream = false,
}) {
  if (!blockAllDownstream && !isObjectiveEvaluatorId(evaluatorId)) return null;

  final environmentFailure = _lastWhereOrNull(
    previousResults,
    _isHardEnvironmentFailure,
  );
  if (environmentFailure != null) return environmentFailure;

  final harnessFailure = _lastWhereOrNull(
    previousResults,
    _isHardHarnessFailure,
  );
  if (harnessFailure != null) return harnessFailure;

  final compileFailure = _lastWhereOrNull(
    previousResults,
    _isHardCompileFailure,
  );
  if (compileFailure != null && _isRuntimeEvaluator(evaluatorId)) {
    return compileFailure;
  }

  return null;
}

bool hasHardDownstreamBlocker(List<EvaluationResult> results) {
  return results.any(
    (result) =>
        _isHardEnvironmentFailure(result) || _isHardHarnessFailure(result),
  );
}

bool _isHardEnvironmentFailure(EvaluationResult result) {
  if (result.passed || isBlockedEvaluation(result)) return false;
  const environmentEvaluatorIds = {
    'environment',
    'environment_error',
    'infrastructure',
    'infrastructure_error',
  };
  if (environmentEvaluatorIds.contains(result.evaluatorId)) return true;
  final code = result.details['code'] ?? result.details['error_code'];
  return code == 'environment_error' ||
      code == 'infrastructure_error' ||
      code == 'env_error';
}

bool _isHardHarnessFailure(EvaluationResult result) =>
    result.evaluatorId == 'agent_harness' &&
    !result.passed &&
    !isBlockedEvaluation(result);

bool _isHardCompileFailure(EvaluationResult result) =>
    result.evaluatorId == 'compile' &&
    !result.passed &&
    !isBlockedEvaluation(result);

bool _isRuntimeEvaluator(String evaluatorId) =>
    isPublicTestEvaluatorId(evaluatorId) ||
    isHiddenVerifierEvaluatorId(evaluatorId);

EvaluationResult? _lastWhereOrNull(
  List<EvaluationResult> results,
  bool Function(EvaluationResult) predicate,
) {
  for (var i = results.length - 1; i >= 0; i--) {
    final result = results[i];
    if (predicate(result)) return result;
  }
  return null;
}

extension BlockedEvaluationResult on EvaluationResult {
  EvaluationResult copyWithBlocked({
    required String blockedBy,
    String? blockedByRationale,
  }) {
    return EvaluationResult(
      evaluatorId: evaluatorId,
      passed: passed,
      score: score,
      rationale: rationale,
      details: {
        ...details,
        blockedDetailKey: true,
        blockedByDetailKey: blockedBy,
        if (blockedByRationale != null)
          blockedByRationaleDetailKey: blockedByRationale,
        'skipped': true,
        'reason': 'blocked by $blockedBy',
      },
    );
  }
}
