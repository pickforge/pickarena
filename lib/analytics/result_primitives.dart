import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';

class ResultPrimitives {
  const ResultPrimitives({required this.primaryPass, required this.failureTag});

  final bool primaryPass;
  final String failureTag;
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
  final hidden = evaluations.where(_isHiddenVerifier).toList();
  if (hidden.isNotEmpty) return hidden.every((e) => e.passed);

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
  if (evaluations.any(_isHarnessError)) return 'harness_error';
  if (evaluations.any((e) => _isHiddenVerifier(e) && !e.passed)) {
    return 'hidden_verifier_failed';
  }
  if (evaluations.any((e) => e.evaluatorId == 'compile' && !e.passed)) {
    return 'compile_failed';
  }
  if (evaluations.any((e) => e.evaluatorId == 'analyze' && !e.passed)) {
    return 'analysis_failed';
  }
  if (evaluations.any((e) => _isPublicTestEvaluator(e) && !e.passed)) {
    return 'public_tests_failed';
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
  return e.evaluatorId == 'hidden_test' || e.evaluatorId.contains('hidden');
}

bool _isCorrectnessEvaluator(EvaluationResult e) {
  return _isPublicTestEvaluator(e) ||
      e.evaluatorId == 'compile' ||
      e.evaluatorId == 'analyze';
}

bool _isPublicTestEvaluator(EvaluationResult e) {
  return e.evaluatorId == 'test' ||
      e.evaluatorId == 'test_author' ||
      e.evaluatorId == 'widget_tree';
}

bool _isHarnessTimeout(EvaluationResult e) {
  return _isHarnessError(e) && _combinedDetails(e).contains('timeout');
}

bool _isHarnessError(EvaluationResult e) {
  if (e.evaluatorId == 'combo_failure') return true;
  if ((e.rationale ?? '').contains('prepare failed')) return true;
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
