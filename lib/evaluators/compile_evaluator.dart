import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class CompileEvaluator implements Evaluator {
  @override
  String get id => 'compile';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final exe = ctx.task.isFlutter ? 'flutter' : 'dart';
    final analyze = await Process.run(
      exe,
      ['analyze', '--fatal-infos'],
      workingDirectory: ctx.workDir.path,
    );

    final passed = analyze.exitCode == 0;
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
      rationale: passed ? 'compiles cleanly' : 'analysis errors present',
      details: {
        'exitCode': analyze.exitCode,
        'stdout': analyze.stdout.toString(),
        'stderr': analyze.stderr.toString(),
        'tool': exe,
      },
    );
  }
}
