import 'dart:math' as math;

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/evaluator_process.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

class AnalyzeEvaluator implements Evaluator {
  const AnalyzeEvaluator({
    this.timeout = defaultEvaluatorProcessTimeout,
    this.maxOutputBytes = defaultEvaluatorMaxOutputBytes,
    this.maxProcesses,
    this.maxMemoryMb,
    this.dartExecutable = 'dart',
    this.flutterExecutable = 'flutter',
  });

  final Duration? timeout;
  final int maxOutputBytes;
  final int? maxProcesses;
  final int? maxMemoryMb;
  final String dartExecutable;
  final String flutterExecutable;

  @override
  String get id => 'analyze';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final exe = ctx.task.isFlutter ? flutterExecutable : dartExecutable;
    final res = await runEvaluatorProcess(
      exe,
      ['analyze'],
      workingDirectory: ctx.workDir.path,
      environment: benchmarkSubprocessEnvironment(
        additionalDeniedKeys: ctx.deniedEnvironmentKeys,
        allowReentrantFlutterTool:
            ctx.allowReentrantFlutterTool && ctx.task.isFlutter,
        homeDirectory: ctx.workDir.path,
      ),
      includeParentEnvironment: false,
      timeout: timeout,
      maxOutputBytes: maxOutputBytes,
      maxCpuCores: ctx.task.effectiveResourceLimits.cpus,
      maxProcesses: maxProcesses,
      maxMemoryMb: maxMemoryMb,
      generatedCodeSandbox: ctx.generatedCodeSandbox,
      allowInternet: ctx.task.allowInternet,
    );
    final stdout = res.stdout;
    final counts = _countSeverities(stdout);

    if (res.timedOut ||
        res.outputLimitExceeded ||
        res.processLimitExceeded ||
        res.memoryLimitExceeded) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: res.timedOut
            ? 'analyze process timed out'
            : res.processLimitExceeded
            ? 'analyze process limit exceeded'
            : res.memoryLimitExceeded
            ? 'analyze memory limit exceeded'
            : 'analyze output limit exceeded',
        details: {
          'errors': counts.errors,
          'warnings': counts.warnings,
          'infos': counts.infos,
          'exit_code': res.exitCode,
          'raw_stdout': stdout,
          if (res.stderr.isNotEmpty) 'stderr': res.stderr,
          if (res.timedOut) 'timed_out': true,
          if (res.timedOut && timeout != null)
            'timeout_ms': timeout!.inMilliseconds,
          if (res.outputLimitExceeded) 'output_limit_exceeded': true,
          if (res.outputLimitExceeded) 'max_output_bytes': maxOutputBytes,
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
        },
      );
    }

    if (counts.errors > 0) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale:
            'errors=${counts.errors} warnings=${counts.warnings} infos=${counts.infos}',
        details: {
          'errors': counts.errors,
          'warnings': counts.warnings,
          'infos': counts.infos,
          'exit_code': res.exitCode,
          'raw_stdout': stdout,
          if (res.stderr.isNotEmpty) 'stderr': res.stderr,
          'tool': exe,
        },
      );
    }

    final score = math.max(
      0.0,
      1.0 - 0.10 * counts.warnings - 0.02 * counts.infos,
    );
    final clamped = score.clamp(0.0, 1.0);
    return EvaluationResult(
      evaluatorId: id,
      passed: true,
      score: clamped,
      rationale: 'errors=0 warnings=${counts.warnings} infos=${counts.infos}',
      details: {
        'errors': 0,
        'warnings': counts.warnings,
        'infos': counts.infos,
        'exit_code': res.exitCode,
        'raw_stdout': stdout,
        if (res.stderr.isNotEmpty) 'stderr': res.stderr,
        'tool': exe,
      },
    );
  }

  _Counts _countSeverities(String stdout) {
    var errors = 0, warnings = 0, infos = 0;
    final errorRe = RegExp(r'^\s*error\b', multiLine: true);
    final warningRe = RegExp(r'^\s*warning\b', multiLine: true);
    final infoRe = RegExp(r'^\s*info\b', multiLine: true);
    errors = errorRe.allMatches(stdout).length;
    warnings = warningRe.allMatches(stdout).length;
    infos = infoRe.allMatches(stdout).length;
    return _Counts(errors: errors, warnings: warnings, infos: infos);
  }
}

class _Counts {
  const _Counts({
    required this.errors,
    required this.warnings,
    required this.infos,
  });

  final int errors;
  final int warnings;
  final int infos;
}
