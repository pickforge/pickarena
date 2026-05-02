import 'dart:io';
import 'dart:math' as math;

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

class AnalyzeEvaluator implements Evaluator {
  @override
  String get id => 'analyze';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final res = await Process.run(
      'dart',
      ['analyze'],
      workingDirectory: ctx.workDir.path,
    );
    final stdout = res.stdout.toString();
    final counts = _countSeverities(stdout);

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
          'raw_stdout': stdout,
        },
      );
    }

    final score =
        math.max(0.0, 1.0 - 0.10 * counts.warnings - 0.02 * counts.infos);
    final clamped = score.clamp(0.0, 1.0);
    return EvaluationResult(
      evaluatorId: id,
      passed: true,
      score: clamped,
      rationale:
          'errors=0 warnings=${counts.warnings} infos=${counts.infos}',
      details: {
        'errors': 0,
        'warnings': counts.warnings,
        'infos': counts.infos,
        'raw_stdout': stdout,
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
