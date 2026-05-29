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
    this.trialIndex = 0,
    this.taskVersion = 1,
    this.benchmarkTrack = 'codegen',
    this.harnessId,
    this.primaryPass,
    this.failureTag,
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
  final int trialIndex;
  final int taskVersion;
  final String benchmarkTrack;
  final String? harnessId;
  final bool? primaryPass;
  final String? failureTag;
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
    trialIndex,
    taskVersion,
    benchmarkTrack,
    harnessId,
    primaryPass,
    failureTag,
    planId,
  ];
}
