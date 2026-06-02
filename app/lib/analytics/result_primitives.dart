import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_classification.dart';
import 'package:dart_arena/core/model_response.dart';

class ResultPrimitives {
  const ResultPrimitives({required this.primaryPass, required this.failureTag});

  final bool primaryPass;
  final String failureTag;
}

const supportedFailureTags = <String>[
  'pass',
  'hidden_verifier_failed',
  'public_tests_failed',
  'analysis_failed',
  'compile_failed',
  'harness_timeout',
  'harness_error',
  'no_patch',
  'invalid_output',
  'environment_error',
  'unknown',
];

String normalizeFailureTag(String? tag) {
  if (tag == null || tag.trim().isEmpty) return 'unknown';
  return supportedFailureTags.contains(tag) ? tag : 'unknown';
}

ResultPrimitives determineResultPrimitives({
  required List<EvaluationResult> evaluations,
  required double aggregateScore,
  ModelResponse? response,
}) {
  final primaryPass = determinePrimaryPass(
    evaluations: evaluations,
    aggregateScore: aggregateScore,
  );
  return ResultPrimitives(
    primaryPass: primaryPass,
    failureTag: determineFailureTag(
      primaryPass: primaryPass,
      evaluations: evaluations,
      response: response,
    ),
  );
}

bool determinePrimaryPass({
  required List<EvaluationResult> evaluations,
  required double aggregateScore,
}) {
  if (evaluations.any(_isHarnessError)) return false;

  final correctness = evaluations.where(_isCorrectnessEvaluator).toList();
  if (correctness.isNotEmpty) return correctness.every((e) => e.passed);

  return aggregateScore >= Dimensions.reliabilityThreshold;
}

String determineFailureTag({
  required bool primaryPass,
  required List<EvaluationResult> evaluations,
  ModelResponse? response,
}) {
  if (primaryPass) return 'pass';
  if (evaluations.any(_isHarnessTimeout)) return 'harness_timeout';
  if (evaluations.any(_isEnvironmentError)) return 'environment_error';
  if (evaluations.any(_isHarnessError)) return 'harness_error';
  if (evaluations.any((e) => e.evaluatorId == 'compile' && !e.passed)) {
    return 'compile_failed';
  }
  if (evaluations.any((e) => e.evaluatorId == 'analyze' && !e.passed)) {
    return 'analysis_failed';
  }
  if (evaluations.any((e) => _isPublicTestEvaluator(e) && !e.passed)) {
    return 'public_tests_failed';
  }
  if (evaluations.any((e) => _isHiddenVerifier(e) && !e.passed)) {
    return 'hidden_verifier_failed';
  }
  if (response != null && response.rawText.trim().isEmpty) {
    return 'invalid_output';
  }
  if (response != null && (response.extractedCode?.trim().isEmpty ?? true)) {
    return 'no_patch';
  }
  return 'unknown';
}

bool _isHiddenVerifier(EvaluationResult e) {
  return isHiddenVerifierEvaluatorId(e.evaluatorId);
}

bool _isCorrectnessEvaluator(EvaluationResult e) {
  return isObjectiveEvaluatorId(e.evaluatorId);
}

bool _isPublicTestEvaluator(EvaluationResult e) {
  return isPublicTestEvaluatorId(e.evaluatorId);
}

bool _isHarnessTimeout(EvaluationResult e) {
  if (e.passed) return false;
  final details = _combinedDetails(e);
  return _isHarnessError(e) &&
      (details.contains('timeout') || details.contains('timed out'));
}

bool _isEnvironmentError(EvaluationResult e) {
  if (e.passed) return false;
  const environmentEvaluatorIds = {
    'environment',
    'environment_error',
    'infrastructure',
    'infrastructure_error',
  };
  if (environmentEvaluatorIds.contains(e.evaluatorId)) return true;
  final code = _detailString(e, 'code') ?? _detailString(e, 'error_code');
  return code == 'environment_error' ||
      code == 'infrastructure_error' ||
      code == 'env_error';
}

bool _isHarnessError(EvaluationResult e) {
  if (e.passed) return false;
  if (_isEnvironmentError(e)) return true;
  if (e.evaluatorId == 'combo_failure') return true;
  if (_combinedDetails(e).contains('prepare failed')) return true;
  if (e.evaluatorId.contains('harness')) return true;
  if (isSecondaryEvaluatorId(e.evaluatorId) || _isHiddenVerifier(e)) {
    return false;
  }
  return e.details.containsKey('error') &&
      !_isPublicTestEvaluator(e) &&
      e.evaluatorId != 'compile' &&
      e.evaluatorId != 'analyze';
}

String _combinedDetails(EvaluationResult e) {
  final values = [
    e.evaluatorId,
    if (e.rationale != null) e.rationale!,
    ...e.details.values.map((v) => '$v'),
  ];
  return values.join(' ').toLowerCase();
}

String? _detailString(EvaluationResult e, String key) {
  final value = e.details[key];
  return value == null ? null : '$value'.toLowerCase();
}
