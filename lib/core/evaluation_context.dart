import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/model_response.dart';

class EvaluationContext {
  EvaluationContext({
    required this.workDir,
    required this.response,
    required this.task,
  });

  final Directory workDir;
  final ModelResponse response;
  final BenchmarkTask task;
}
