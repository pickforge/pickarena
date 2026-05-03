import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/providers/model_provider.dart';

class StartRunConfig {
  const StartRunConfig({
    required this.tasks,
    required this.providers,
    required this.modelByProvider,
    required this.evaluatorConfig,
    required this.weights,
    this.useReferencePlan = false,
    this.name,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, String> modelByProvider;
  final EvaluatorConfig evaluatorConfig;
  final Map<String, double> weights;
  final bool useReferencePlan;
  final String? name;
}
