import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';

class EvaluationContext {
  EvaluationContext({
    required this.workDir,
    required this.response,
    required this.task,
    List<EvaluationResult> previousResults = const [],
    Iterable<String> deniedEnvironmentKeys = const [],
    this.allowReentrantFlutterTool = false,
    this.generatedCodeSandbox,
  }) : previousResults = List.unmodifiable(previousResults),
       deniedEnvironmentKeys = Set.unmodifiable(deniedEnvironmentKeys);

  final Directory workDir;
  final ModelResponse response;
  final BenchmarkTask task;
  final List<EvaluationResult> previousResults;
  final Set<String> deniedEnvironmentKeys;
  final bool allowReentrantFlutterTool;
  final GeneratedCodeSandbox? generatedCodeSandbox;
}
