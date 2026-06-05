import 'dart:convert';

import 'package:dart_arena/core/evaluator_blocking.dart';

enum EvaluationStatus { passed, failed, blocked, ignored, skipped }

Map<String, Object?> decodeEvaluationDetailsJson(String detailsJson) {
  try {
    final decoded = jsonDecode(detailsJson);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
  } on FormatException {
    return const {};
  }
  return const {};
}

EvaluationStatus evaluationStatus({
  required bool passed,
  required Map<String, Object?> details,
}) {
  if (details[blockedDetailKey] == true) return EvaluationStatus.blocked;
  if (details['ignored'] == true) return EvaluationStatus.ignored;
  if (details['skipped'] == true) return EvaluationStatus.skipped;
  return passed ? EvaluationStatus.passed : EvaluationStatus.failed;
}

String evaluationStatusName(EvaluationStatus status) {
  return switch (status) {
    EvaluationStatus.passed => 'passed',
    EvaluationStatus.failed => 'failed',
    EvaluationStatus.blocked => 'blocked',
    EvaluationStatus.ignored => 'ignored',
    EvaluationStatus.skipped => 'skipped',
  };
}

String evaluationStatusLabel(EvaluationStatus status) {
  return switch (status) {
    EvaluationStatus.passed => 'PASS',
    EvaluationStatus.failed => 'FAIL',
    EvaluationStatus.blocked => 'BLOCKED',
    EvaluationStatus.ignored => 'IGNORED',
    EvaluationStatus.skipped => 'SKIPPED',
  };
}
