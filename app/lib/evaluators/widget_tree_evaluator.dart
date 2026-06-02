import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/_test_reporter_parser.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

class WidgetTreeEvaluator implements Evaluator {
  WidgetTreeEvaluator({this.testDir = 'test/widget'});

  final String testDir;

  @override
  String get id => 'widget_tree';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final res = await Process.run(
      'flutter',
      ['test', testDir, '--reporter=json'],
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
        'tool': 'flutter',
      },
    );
  }
}
