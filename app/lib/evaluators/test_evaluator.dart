import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/_test_reporter_parser.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

class TestEvaluator implements Evaluator {
  TestEvaluator({this.testPath});

  /// If provided, only this path is passed to `<tool> test`. When null, the
  /// runner runs the default test set (the entire `test/` directory).
  final String? testPath;

  @override
  String get id => 'test';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final exe = ctx.task.isFlutter ? 'flutter' : 'dart';
    final args = <String>[
      'test',
      if (testPath != null) testPath!,
      '--reporter=json',
    ];
    final res = await Process.run(
      exe,
      args,
      workingDirectory: ctx.workDir.path,
      environment: benchmarkSubprocessEnvironment(
        additionalDeniedKeys: ctx.deniedEnvironmentKeys,
      ),
      includeParentEnvironment: false,
    );
    final summary = parseTestReporterJson(res.stdout.toString());

    return EvaluationResult(
      evaluatorId: id,
      passed: summary.allPassed,
      score: summary.score,
      rationale: summary.total == 0
          ? 'no tests found'
          : '${summary.passed}/${summary.total} tests passed',
      details: {
        'total': summary.total,
        'passed': summary.passed,
        'failed': summary.failed,
        'errored': summary.errored,
        'failures': summary.failures,
        'exit_code': res.exitCode,
        'tool': exe,
        if (testPath != null) 'test_path': testPath,
      },
    );
  }
}
