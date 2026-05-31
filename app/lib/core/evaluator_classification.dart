import 'package:dart_arena/core/evaluation_result.dart';

const objectiveEvaluatorIds = <String>{
  'compile',
  'analyze',
  'test',
  'test_author',
  'widget_tree',
  'hidden_test',
};

const secondaryEvaluatorIds = <String>{'llm_judge', 'diff_size'};

bool isObjectiveEvaluatorId(String evaluatorId) {
  return objectiveEvaluatorIds.contains(evaluatorId) ||
      evaluatorId.endsWith('_hidden');
}

bool isSecondaryEvaluatorId(String evaluatorId) {
  return secondaryEvaluatorIds.contains(evaluatorId);
}

bool isHiddenVerifierEvaluatorId(String evaluatorId) {
  return evaluatorId == 'hidden_test' || evaluatorId.endsWith('_hidden');
}

bool isPublicTestEvaluatorId(String evaluatorId) {
  return evaluatorId == 'test' ||
      evaluatorId == 'test_author' ||
      evaluatorId == 'widget_tree';
}

bool isIgnoredOrSkipped(EvaluationResult result) {
  return result.details['ignored'] == true || result.details['skipped'] == true;
}

bool isObjectiveFailure(EvaluationResult result) {
  return isObjectiveEvaluatorId(result.evaluatorId) && !result.passed;
}

double? objectiveFailureCap(EvaluationResult result) {
  if (!isObjectiveFailure(result)) return null;
  return switch (result.evaluatorId) {
    'compile' => 0.20,
    'analyze' => 0.35,
    _
        when isPublicTestEvaluatorId(result.evaluatorId) ||
            isHiddenVerifierEvaluatorId(result.evaluatorId) =>
      0.60,
    _ => null,
  };
}
