import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/_test_reporter_parser.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/evaluator_process.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';
import 'package:path/path.dart' as p;

class TestMutant {
  const TestMutant({
    required this.name,
    required this.sourcePath,
    required this.find,
    required this.replace,
  });

  final String name;
  final String sourcePath;
  final String find;
  final String replace;
}

class TestAuthorEvaluator implements Evaluator {
  TestAuthorEvaluator({
    required this.testPath,
    required this.mutants,
    this.timeout = defaultEvaluatorProcessTimeout,
    this.maxOutputBytes = defaultEvaluatorMaxOutputBytes,
    this.maxProcesses,
    this.maxMemoryMb,
    this.dartExecutable = 'dart',
    this.flutterExecutable = 'flutter',
  });

  final String testPath;
  final List<TestMutant> mutants;
  final Duration? timeout;
  final int maxOutputBytes;
  final int? maxProcesses;
  final int? maxMemoryMb;
  final String dartExecutable;
  final String flutterExecutable;

  @override
  String get id => 'test_author';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final exe = ctx.task.isFlutter ? flutterExecutable : dartExecutable;
    final originalRun = await _runTests(
      exe,
      ctx.workDir.path,
      deniedEnvironmentKeys: ctx.deniedEnvironmentKeys,
      allowReentrantFlutterTool:
          ctx.allowReentrantFlutterTool && ctx.task.isFlutter,
      homeDirectory: ctx.workDir.path,
      generatedCodeSandbox: ctx.generatedCodeSandbox,
      allowInternet: ctx.task.allowInternet,
      maxCpuCores: ctx.task.effectiveResourceLimits.cpus,
    );
    final originalSummary = parseTestReporterJson(originalRun.stdout);
    if (originalRun.timedOut ||
        originalRun.outputLimitExceeded ||
        originalRun.processLimitExceeded ||
        originalRun.memoryLimitExceeded ||
        originalRun.exitCode != 0 ||
        !originalSummary.allPassed) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: originalRun.timedOut
            ? 'generated tests timed out'
            : originalRun.processLimitExceeded
            ? 'generated tests process limit exceeded'
            : originalRun.memoryLimitExceeded
            ? 'generated tests memory limit exceeded'
            : originalRun.outputLimitExceeded
            ? 'generated tests output limit exceeded'
            : originalSummary.total == 0
            ? 'generated tests did not run'
            : 'generated tests fail on the correct implementation',
        details: {
          'tool': exe,
          'test_path': testPath,
          'original_exit_code': originalRun.exitCode,
          'original_total': originalSummary.total,
          'original_passed': originalSummary.passed,
          'original_failures': originalSummary.failures,
          if (originalRun.stderr.isNotEmpty) 'stderr': originalRun.stderr,
          if (originalRun.timedOut) 'timed_out': true,
          if (originalRun.timedOut && timeout != null)
            'timeout_ms': timeout!.inMilliseconds,
          if (originalRun.outputLimitExceeded) 'output_limit_exceeded': true,
          if (originalRun.outputLimitExceeded)
            'max_output_bytes': maxOutputBytes,
          if (originalRun.processLimitExceeded) 'process_limit_exceeded': true,
          if (originalRun.processLimitExceeded && maxProcesses != null)
            'max_processes': maxProcesses,
          if (originalRun.observedProcessCount != null)
            'observed_processes': originalRun.observedProcessCount,
          if (originalRun.memoryLimitExceeded) 'memory_limit_exceeded': true,
          if (originalRun.memoryLimitExceeded && maxMemoryMb != null)
            'max_memory_mb': maxMemoryMb,
          if (originalRun.observedMemoryMb != null)
            'observed_memory_mb': originalRun.observedMemoryMb,
        },
      );
    }

    final survived = <String>[];
    final setupFailures = <String>[];
    var killed = 0;

    for (final mutant in mutants) {
      final sourceFile = File(p.join(ctx.workDir.path, mutant.sourcePath));
      if (!sourceFile.existsSync()) {
        setupFailures.add('${mutant.name}: source missing');
        continue;
      }

      final originalSource = await sourceFile.readAsString();
      if (!originalSource.contains(mutant.find)) {
        setupFailures.add('${mutant.name}: find text missing');
        continue;
      }

      await sourceFile.writeAsString(
        originalSource.replaceFirst(mutant.find, mutant.replace),
      );
      try {
        final mutantRun = await _runTests(
          exe,
          ctx.workDir.path,
          deniedEnvironmentKeys: ctx.deniedEnvironmentKeys,
          allowReentrantFlutterTool:
              ctx.allowReentrantFlutterTool && ctx.task.isFlutter,
          homeDirectory: ctx.workDir.path,
          generatedCodeSandbox: ctx.generatedCodeSandbox,
          allowInternet: ctx.task.allowInternet,
          maxCpuCores: ctx.task.effectiveResourceLimits.cpus,
        );
        if (mutantRun.timedOut ||
            mutantRun.outputLimitExceeded ||
            mutantRun.processLimitExceeded ||
            mutantRun.memoryLimitExceeded ||
            mutantRun.exitCode != 0) {
          killed++;
        } else {
          survived.add(mutant.name);
        }
      } finally {
        await sourceFile.writeAsString(originalSource);
      }
    }

    final total = mutants.length;
    final score = total == 0 ? 0.0 : killed / total;
    final passed = setupFailures.isEmpty && total > 0 && killed == total;
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: score,
      rationale: 'killed=$killed/$total mutants',
      details: {
        'tool': exe,
        'test_path': testPath,
        'killed': killed,
        'total': total,
        'survived': survived,
        'setup_failures': setupFailures,
      },
    );
  }

  Future<EvaluatorProcessResult> _runTests(
    String exe,
    String workDir, {
    required Iterable<String> deniedEnvironmentKeys,
    required bool allowReentrantFlutterTool,
    required String homeDirectory,
    required GeneratedCodeSandbox? generatedCodeSandbox,
    required bool allowInternet,
    required int? maxCpuCores,
  }) {
    return runEvaluatorProcess(
      exe,
      ['test', testPath, '--reporter=json'],
      workingDirectory: workDir,
      environment: benchmarkSubprocessEnvironment(
        additionalDeniedKeys: deniedEnvironmentKeys,
        allowReentrantFlutterTool: allowReentrantFlutterTool,
        homeDirectory: homeDirectory,
      ),
      includeParentEnvironment: false,
      timeout: timeout,
      maxOutputBytes: maxOutputBytes,
      maxCpuCores: maxCpuCores,
      maxProcesses: maxProcesses,
      maxMemoryMb: maxMemoryMb,
      generatedCodeSandbox: generatedCodeSandbox,
      allowInternet: allowInternet,
    );
  }
}
