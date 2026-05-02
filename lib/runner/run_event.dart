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
    required this.modelByProvider,
    required this.evaluatorConfig,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, String> modelByProvider;
  final EvaluatorConfig evaluatorConfig;
}

class CancelRun extends RunEvent {
  const CancelRun();
}
