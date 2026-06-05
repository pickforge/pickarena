import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/providers/model_provider.dart';
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
    this.existingRunId,
    this.trialsPerTask = 1,
    this.generatedCodeSandboxRequired = false,
    this.generatedCodeSandboxEnforced = false,
    this.generatedCodeSandboxBackend,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, List<String>> modelsByProvider;
  final EvaluatorConfig evaluatorConfig;
  final bool useReferencePlan;
  final String? name;
  final int maxConcurrency;
  final String? existingRunId;
  final int trialsPerTask;
  final bool generatedCodeSandboxRequired;
  final bool generatedCodeSandboxEnforced;
  final String? generatedCodeSandboxBackend;

  @override
  List<Object?> get props => [
    tasks,
    providers,
    modelsByProvider,
    evaluatorConfig,
    useReferencePlan,
    name,
    maxConcurrency,
    existingRunId,
    trialsPerTask,
    generatedCodeSandboxRequired,
    generatedCodeSandboxEnforced,
    generatedCodeSandboxBackend,
  ];
}

class CancelRun extends RunEvent {
  const CancelRun();
}

class RetryCombo extends RunEvent {
  const RetryCombo({required this.runId, required this.failedIndex});

  final String runId;
  final int failedIndex;

  @override
  List<Object?> get props => [runId, failedIndex];
}

class FinishRun extends RunEvent {
  const FinishRun(this.runId);

  final String runId;

  @override
  List<Object?> get props => [runId];
}
