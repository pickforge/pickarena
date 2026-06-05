import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/_test_reporter_parser.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/evaluator_process.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

class WidgetTreeEvaluator implements Evaluator {
  WidgetTreeEvaluator({
    this.testDir = 'test/widget',
    this.timeout = defaultEvaluatorProcessTimeout,
    this.maxOutputChars = defaultEvaluatorMaxOutputChars,
    this.maxProcesses,
    this.maxMemoryMb,
    this.flutterExecutable = 'flutter',
  });

  final String testDir;
  final Duration? timeout;
  final int maxOutputChars;
  final int? maxProcesses;
  final int? maxMemoryMb;
  final String flutterExecutable;

  @override
  String get id => 'widget_tree';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final res = await runEvaluatorProcess(
      flutterExecutable,
      ['test', testDir, '--reporter=json'],
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
          ? 'widget test process timed out'
          : res.processLimitExceeded
          ? 'widget test process limit exceeded'
          : res.memoryLimitExceeded
          ? 'widget test memory limit exceeded'
          : res.outputLimitExceeded
          ? 'widget test output limit exceeded'
          : summary.total == 0
          ? 'no widget tests found'
          : '${summary.passed}/${summary.total} widget tests passed',
      details: {
        'test_dir': testDir,
        'total': summary.total,
        'passed': summary.passed,
        'failed': summary.failed,
        'errored': summary.errored,
        'failures': summary.failures,
        'exit_code': res.exitCode,
        if (res.stderr.isNotEmpty) 'stderr': res.stderr,
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
        'tool': flutterExecutable,
      },
    );
  }
}
