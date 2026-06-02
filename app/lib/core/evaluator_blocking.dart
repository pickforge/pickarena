import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_classification.dart';

const blockedDetailKey = 'blocked';
const blockedByDetailKey = 'blocked_by';

bool isBlockedEvaluation(EvaluationResult result) =>
    result.details[blockedDetailKey] == true;

EvaluationResult? blockedEvaluationFor({
  required String evaluatorId,
  required List<EvaluationResult> previousResults,
}) {
  final blockedBy = blockedByEvaluatorIdFor(
    evaluatorId: evaluatorId,
    previousResults: previousResults,
  );
  if (blockedBy == null) return null;
  return EvaluationResult(
    evaluatorId: evaluatorId,
    passed: false,
    score: 0.0,
    rationale: 'blocked by $blockedBy',
    details: const {},
  ).copyWithBlocked(blockedBy: blockedBy);
}

String? blockedByEvaluatorIdFor({
  required String evaluatorId,
  required List<EvaluationResult> previousResults,
}) {
  if (!isObjectiveEvaluatorId(evaluatorId)) return null;

  final harnessFailure = _lastWhereOrNull(
    previousResults,
    _isHardHarnessFailure,
  );
  if (harnessFailure != null) return harnessFailure.evaluatorId;

  final compileFailure = _lastWhereOrNull(
    previousResults,
    _isHardCompileFailure,
  );
  if (compileFailure != null && _isRuntimeEvaluator(evaluatorId)) {
    return compileFailure.evaluatorId;
  }

  return null;
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
  EvaluationResult copyWithBlocked({required String blockedBy}) {
    return EvaluationResult(
      evaluatorId: evaluatorId,
      passed: passed,
      score: score,
      rationale: rationale,
      details: {
        ...details,
        blockedDetailKey: true,
        blockedByDetailKey: blockedBy,
        'skipped': true,
        'reason': 'blocked by $blockedBy',
      },
    );
  }
}
