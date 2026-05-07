import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/providers/model_provider.dart';

class StartRunConfig {
  const StartRunConfig({
    required this.tasks,
    required this.providers,
    required this.modelsByProvider,
    required this.evaluatorConfig,
    required this.weights,
    this.useReferencePlan = false,
    this.name,
    this.maxConcurrency = 4,
    this.existingRunId,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, List<String>> modelsByProvider;
  final EvaluatorConfig evaluatorConfig;
  final Map<String, double> weights;
  final bool useReferencePlan;
  final String? name;
  final int maxConcurrency;
  final String? existingRunId;
}
