import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class CompileEvaluator implements Evaluator {
  @override
  String get id => 'compile';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final pubGet = await Process.run(
      'dart',
      ['pub', 'get', '--offline'],
      workingDirectory: ctx.workDir.path,
    );
    if (pubGet.exitCode != 0) {
      final retry = await Process.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: ctx.workDir.path,
      );
      if (retry.exitCode != 0) {
        return EvaluationResult(
          evaluatorId: id,
          passed: false,
          score: 0,
          rationale: 'pub get failed',
          details: {'stderr': retry.stderr.toString()},
        );
      }
    }

    final analyze = await Process.run(
      'dart',
      ['analyze', '--fatal-infos'],
      workingDirectory: ctx.workDir.path,
    );

    if (analyze.exitCode != 0) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'analysis errors present',
        details: {
          'phase': 'analyze',
          'exitCode': analyze.exitCode,
          'stdout': analyze.stdout.toString(),
          'stderr': analyze.stderr.toString(),
        },
      );
    }

    final test = await Process.run(
      'dart',
      ['test'],
      workingDirectory: ctx.workDir.path,
    );

    final passed = test.exitCode == 0;
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
      rationale: passed ? 'analysis and tests clean' : 'tests failed',
      details: {
        'phase': 'test',
        'exitCode': test.exitCode,
        'stdout': test.stdout.toString(),
        'stderr': test.stderr.toString(),
      },
    );
  }
}
