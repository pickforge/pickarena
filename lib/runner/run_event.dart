import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/run_failure_policy.dart';
import 'package:equatable/equatable.dart';

sealed class RunEvent extends Equatable {
  const RunEvent();
  @override
  List<Object?> get props => [];
}

class StartRun extends RunEvent {
  const StartRun({
    required this.tasks,
    required this.providers,
    required this.modelsByProvider,
    required this.evaluatorConfig,
    this.useReferencePlan = false,
    this.name,
    this.maxConcurrency = 4,
    this.onFailure = RunFailurePolicy.failFast,
    this.existingRunId,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, List<String>> modelsByProvider;
  final EvaluatorConfig evaluatorConfig;
  final bool useReferencePlan;
  final String? name;
  final int maxConcurrency;
  final RunFailurePolicy onFailure;
  final String? existingRunId;

  @override
  List<Object?> get props => [
    tasks,
    providers,
    modelsByProvider,
    evaluatorConfig,
    useReferencePlan,
    name,
    maxConcurrency,
    onFailure,
    existingRunId,
  ];
}

class CancelRun extends RunEvent {
  const CancelRun();
}
