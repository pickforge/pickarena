import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:equatable/equatable.dart';

class TaskRunResult extends Equatable {
  const TaskRunResult({
    required this.runId,
    required this.providerId,
    required this.modelId,
    required this.taskId,
    required this.response,
    required this.evaluations,
    required this.aggregateScore,
    required this.completedAt,
    this.planId,
  });

  final String runId;
  final String providerId;
  final String modelId;
  final String taskId;
  final ModelResponse response;
  final List<EvaluationResult> evaluations;
  final double aggregateScore;
  final DateTime completedAt;
  final String? planId;

  @override
  List<Object?> get props => [
        runId,
        providerId,
        modelId,
        taskId,
        response,
        evaluations,
        aggregateScore,
        completedAt,
        planId,
      ];
}
