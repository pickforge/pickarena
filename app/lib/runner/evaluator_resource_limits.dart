import 'dart:math' as math;

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/evaluators/test_author_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/evaluators/widget_tree_evaluator.dart';

List<Evaluator> applyTaskResourceLimitsToEvaluators(
  Iterable<Evaluator> evaluators,
  BenchmarkTask task,
) {
  return [
    for (final evaluator in evaluators)
      applyResourceLimitsToEvaluator(evaluator, task.effectiveResourceLimits),
  ];
}

Evaluator applyResourceLimitsToEvaluator(
  Evaluator evaluator,
  TaskResourceLimits limits,
) {
  final taskMaxOutputBytes = limits.maxOutputBytes;
  final maxProcesses = limits.maxProcesses;
  final maxMemoryMb = limits.memoryMb;
  if (taskMaxOutputBytes == null &&
      maxProcesses == null &&
      maxMemoryMb == null) {
    return evaluator;
  }

  return switch (evaluator) {
    TestEvaluator(
      testPath: final testPath,
      timeout: final timeout,
      maxOutputBytes: final evaluatorMaxOutputBytes,
      maxProcesses: final evaluatorMaxProcesses,
      maxMemoryMb: final evaluatorMaxMemoryMb,
      dartExecutable: final dartExecutable,
      flutterExecutable: final flutterExecutable,
      readOnlyPaths: final readOnlyPaths,
    ) =>
      TestEvaluator(
        testPath: testPath,
        timeout: timeout,
        maxOutputBytes: _effectiveMaxOutputBytes(
          evaluatorMaxOutputBytes,
          taskMaxOutputBytes,
        ),
        maxProcesses: _effectiveMaxProcesses(
          evaluatorMaxProcesses,
          maxProcesses,
        ),
        maxMemoryMb: _effectiveMaxMemoryMb(evaluatorMaxMemoryMb, maxMemoryMb),
        dartExecutable: dartExecutable,
        flutterExecutable: flutterExecutable,
        readOnlyPaths: readOnlyPaths,
      ),
    HiddenTestEvaluator(
      verifier: final verifier,
      timeout: final timeout,
      maxOutputBytes: final evaluatorMaxOutputBytes,
      maxProcesses: final evaluatorMaxProcesses,
      maxMemoryMb: final evaluatorMaxMemoryMb,
    ) =>
      HiddenTestEvaluator(
        verifier,
        timeout: timeout,
        maxOutputBytes: _effectiveMaxOutputBytes(
          evaluatorMaxOutputBytes,
          taskMaxOutputBytes,
        ),
        maxProcesses: _effectiveMaxProcesses(
          evaluatorMaxProcesses,
          maxProcesses,
        ),
        maxMemoryMb: _effectiveMaxMemoryMb(evaluatorMaxMemoryMb, maxMemoryMb),
      ),
    AnalyzeEvaluator(
      timeout: final timeout,
      maxOutputBytes: final evaluatorMaxOutputBytes,
      maxProcesses: final evaluatorMaxProcesses,
      maxMemoryMb: final evaluatorMaxMemoryMb,
      dartExecutable: final dartExecutable,
      flutterExecutable: final flutterExecutable,
    ) =>
      AnalyzeEvaluator(
        timeout: timeout,
        maxOutputBytes: _effectiveMaxOutputBytes(
          evaluatorMaxOutputBytes,
          taskMaxOutputBytes,
        ),
        maxProcesses: _effectiveMaxProcesses(
          evaluatorMaxProcesses,
          maxProcesses,
        ),
        maxMemoryMb: _effectiveMaxMemoryMb(evaluatorMaxMemoryMb, maxMemoryMb),
        dartExecutable: dartExecutable,
        flutterExecutable: flutterExecutable,
      ),
    CompileEvaluator(
      timeout: final timeout,
      maxOutputBytes: final evaluatorMaxOutputBytes,
      maxProcesses: final evaluatorMaxProcesses,
      maxMemoryMb: final evaluatorMaxMemoryMb,
      dartExecutable: final dartExecutable,
      flutterExecutable: final flutterExecutable,
    ) =>
      CompileEvaluator(
        timeout: timeout,
        maxOutputBytes: _effectiveMaxOutputBytes(
          evaluatorMaxOutputBytes,
          taskMaxOutputBytes,
        ),
        maxProcesses: _effectiveMaxProcesses(
          evaluatorMaxProcesses,
          maxProcesses,
        ),
        maxMemoryMb: _effectiveMaxMemoryMb(evaluatorMaxMemoryMb, maxMemoryMb),
        dartExecutable: dartExecutable,
        flutterExecutable: flutterExecutable,
      ),
    WidgetTreeEvaluator(
      testDir: final testDir,
      timeout: final timeout,
      maxOutputBytes: final evaluatorMaxOutputBytes,
      maxProcesses: final evaluatorMaxProcesses,
      maxMemoryMb: final evaluatorMaxMemoryMb,
      flutterExecutable: final flutterExecutable,
    ) =>
      WidgetTreeEvaluator(
        testDir: testDir,
        timeout: timeout,
        maxOutputBytes: _effectiveMaxOutputBytes(
          evaluatorMaxOutputBytes,
          taskMaxOutputBytes,
        ),
        maxProcesses: _effectiveMaxProcesses(
          evaluatorMaxProcesses,
          maxProcesses,
        ),
        maxMemoryMb: _effectiveMaxMemoryMb(evaluatorMaxMemoryMb, maxMemoryMb),
        flutterExecutable: flutterExecutable,
      ),
    TestAuthorEvaluator(
      testPath: final testPath,
      mutants: final mutants,
      timeout: final timeout,
      maxOutputBytes: final evaluatorMaxOutputBytes,
      maxProcesses: final evaluatorMaxProcesses,
      maxMemoryMb: final evaluatorMaxMemoryMb,
      dartExecutable: final dartExecutable,
      flutterExecutable: final flutterExecutable,
    ) =>
      TestAuthorEvaluator(
        testPath: testPath,
        mutants: mutants,
        timeout: timeout,
        maxOutputBytes: _effectiveMaxOutputBytes(
          evaluatorMaxOutputBytes,
          taskMaxOutputBytes,
        ),
        maxProcesses: _effectiveMaxProcesses(
          evaluatorMaxProcesses,
          maxProcesses,
        ),
        maxMemoryMb: _effectiveMaxMemoryMb(evaluatorMaxMemoryMb, maxMemoryMb),
        dartExecutable: dartExecutable,
        flutterExecutable: flutterExecutable,
      ),
    _ => evaluator,
  };
}

int _effectiveMaxOutputBytes(int evaluatorMax, int? taskMax) {
  if (taskMax == null) return evaluatorMax;
  if (evaluatorMax == TestEvaluator.defaultMaxOutputBytes) return taskMax;
  return math.min(evaluatorMax, taskMax);
}

int? _effectiveMaxProcesses(int? evaluatorMax, int? taskMax) {
  if (evaluatorMax == null) return taskMax;
  if (taskMax == null) return evaluatorMax;
  return math.min(evaluatorMax, taskMax);
}

int? _effectiveMaxMemoryMb(int? evaluatorMax, int? taskMax) {
  if (evaluatorMax == null) return taskMax;
  if (taskMax == null) return evaluatorMax;
  return math.min(evaluatorMax, taskMax);
}
