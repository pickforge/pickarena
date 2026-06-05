import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/evaluator_process.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

class CompileEvaluator implements Evaluator {
  const CompileEvaluator({
    this.timeout = defaultEvaluatorProcessTimeout,
    this.maxOutputChars = defaultEvaluatorMaxOutputChars,
    this.maxProcesses,
    this.maxMemoryMb,
    this.dartExecutable = 'dart',
    this.flutterExecutable = 'flutter',
  });

  final Duration? timeout;
  final int maxOutputChars;
  final int? maxProcesses;
  final int? maxMemoryMb;
  final String dartExecutable;
  final String flutterExecutable;

  @override
  String get id => 'compile';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final exe = ctx.task.isFlutter ? flutterExecutable : dartExecutable;
    final analyze = await runEvaluatorProcess(
      exe,
      ['analyze', '--fatal-infos'],
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

    final passed =
        analyze.exitCode == 0 &&
        !analyze.timedOut &&
        !analyze.outputLimitExceeded &&
        !analyze.processLimitExceeded &&
        !analyze.memoryLimitExceeded;
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
      rationale: analyze.timedOut
          ? 'analysis process timed out'
          : analyze.processLimitExceeded
          ? 'analysis process limit exceeded'
          : analyze.memoryLimitExceeded
          ? 'analysis memory limit exceeded'
          : analyze.outputLimitExceeded
          ? 'analysis output limit exceeded'
          : passed
          ? 'compiles cleanly'
          : 'analysis errors present',
      details: {
        'exitCode': analyze.exitCode,
        'stdout': analyze.stdout,
        'stderr': analyze.stderr,
        if (analyze.timedOut) 'timed_out': true,
        if (analyze.timedOut && timeout != null)
          'timeout_ms': timeout!.inMilliseconds,
        if (analyze.outputLimitExceeded) 'output_limit_exceeded': true,
        if (analyze.outputLimitExceeded) 'max_output_chars': maxOutputChars,
        if (analyze.processLimitExceeded) 'process_limit_exceeded': true,
        if (analyze.processLimitExceeded && maxProcesses != null)
          'max_processes': maxProcesses,
        if (analyze.observedProcessCount != null)
          'observed_processes': analyze.observedProcessCount,
        if (analyze.memoryLimitExceeded) 'memory_limit_exceeded': true,
        if (analyze.memoryLimitExceeded && maxMemoryMb != null)
          'max_memory_mb': maxMemoryMb,
        if (analyze.observedMemoryMb != null)
          'observed_memory_mb': analyze.observedMemoryMb,
        'tool': exe,
      },
    );
  }
}
