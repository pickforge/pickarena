import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/_test_reporter_parser.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/evaluator_process.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

class TestEvaluator implements Evaluator {
  TestEvaluator({
    this.testPath,
    this.timeout,
    this.maxOutputChars = defaultMaxOutputChars,
    this.maxProcesses,
    this.maxMemoryMb,
    this.dartExecutable = 'dart',
    this.flutterExecutable = 'flutter',
    this.readOnlyPaths = const [],
  });

  static const defaultMaxOutputChars = defaultEvaluatorMaxOutputChars;

  /// If provided, only this path is passed to `<tool> test`. When null, the
  /// runner runs the default test set (the entire `test/` directory).
  final String? testPath;
  final Duration? timeout;
  final int maxOutputChars;
  final int? maxProcesses;
  final int? maxMemoryMb;
  final String dartExecutable;
  final String flutterExecutable;
  final List<String> readOnlyPaths;

  @override
  String get id => 'test';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final exe = ctx.task.isFlutter ? flutterExecutable : dartExecutable;
    final args = <String>[
      'test',
      if (testPath != null) testPath!,
      '--reporter=json',
    ];
    final res = await runEvaluatorProcess(
      exe,
      args,
      workingDirectory: ctx.workDir.path,
      environment: benchmarkSubprocessEnvironment(
        additionalDeniedKeys: ctx.deniedEnvironmentKeys,
        allowReentrantFlutterTool:
            ctx.allowReentrantFlutterTool && ctx.task.isFlutter,
        homeDirectory: ctx.workDir.path,
      ),
      includeParentEnvironment: false,
      timeout: timeout,
      maxOutputChars: maxOutputChars,
      maxCpuCores: ctx.task.effectiveResourceLimits.cpus,
      maxProcesses: maxProcesses,
      maxMemoryMb: maxMemoryMb,
      generatedCodeSandbox: ctx.generatedCodeSandbox,
      allowInternet: ctx.task.allowInternet,
      extraReadOnlyPaths: readOnlyPaths,
    );
    final summary = parseTestReporterJson(res.stdout);
    final passed =
        !res.timedOut &&
        !res.outputLimitExceeded &&
        !res.processLimitExceeded &&
        !res.memoryLimitExceeded &&
        summary.allPassed;

    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score:
          (res.outputLimitExceeded ||
              res.processLimitExceeded ||
              res.memoryLimitExceeded)
          ? 0.0
          : summary.score,
      rationale: res.timedOut
          ? 'test process timed out'
          : res.processLimitExceeded
          ? 'test process limit exceeded'
          : res.memoryLimitExceeded
          ? 'test process memory limit exceeded'
          : res.outputLimitExceeded
          ? 'test process output limit exceeded'
          : summary.total == 0
          ? 'no tests found'
          : '${summary.passed}/${summary.total} tests passed',
      details: {
        'total': summary.total,
        'passed': summary.passed,
        'failed': summary.failed,
        'errored': summary.errored,
        'failures': summary.failures,
        'exit_code': res.exitCode,
        if (res.stderr.isNotEmpty) 'stderr': _boundedText(res.stderr),
        if (res.timedOut) 'timed_out': true,
        if (res.timedOut && timeout != null)
          'timeout_ms': timeout!.inMilliseconds,
        if (res.outputLimitExceeded) 'output_limit_exceeded': true,
        if (res.outputLimitExceeded) 'max_output_chars': maxOutputChars,
        if (res.processLimitExceeded) 'process_limit_exceeded': true,
        if (res.processLimitExceeded && maxProcesses != null)
          'max_processes': maxProcesses,
        if (res.observedProcessCount != null)
          'observed_processes': res.observedProcessCount,
        if (res.memoryLimitExceeded) 'memory_limit_exceeded': true,
        if (res.memoryLimitExceeded && maxMemoryMb != null)
          'max_memory_mb': maxMemoryMb,
        if (res.observedMemoryMb != null)
          'observed_memory_mb': res.observedMemoryMb,
        'tool': exe,
        if (testPath != null) 'test_path': testPath,
      },
    );
  }
}

String _boundedText(String value) {
  const maxChars = 4000;
  if (value.length <= maxChars) return value;
  return '${value.substring(0, maxChars)}\n[truncated]';
}
