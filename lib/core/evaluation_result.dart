import 'package:equatable/equatable.dart';

class EvaluationResult extends Equatable {
  const EvaluationResult({
    required this.evaluatorId,
    required this.passed,
    required this.score,
    this.rationale,
    this.details = const {},
  });

  final String evaluatorId;
  final bool passed;
  final double score;
  final String? rationale;
  final Map<String, dynamic> details;

  @override
  List<Object?> get props => [evaluatorId, passed, score, rationale, details];
}
