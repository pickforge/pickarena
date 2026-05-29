import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/core/workspace_path.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class HiddenTestEvaluator implements Evaluator {
  HiddenTestEvaluator(this.verifier);

  final VerifierFixture verifier;

  @override
  String get id => verifier.id;

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    try {
      resolveWorkspaceFile(ctx.workDir, verifier.testPath);
      for (final path in verifier.files.keys) {
        resolveWorkspaceFile(ctx.workDir, path);
      }
    } on ArgumentError catch (e) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'hidden verifier path rejected',
        details: {
          'error': 'invalid workspace-relative path',
          'path': e.invalidValue?.toString(),
        },
      );
    }

    final injected = <String, File>{};
    try {
      for (final entry in verifier.files.entries) {
        final file = resolveWorkspaceFile(ctx.workDir, entry.key);
        injected[entry.key] = file;
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.value);
      }

      final result = await TestEvaluator(
        testPath: verifier.testPath,
      ).evaluate(ctx);
      final total = result.details['total'] as int? ?? 0;
      final passed = result.details['passed'] as int? ?? 0;
      final failed = result.details['failed'] as int? ?? 0;
      final errored = result.details['errored'] as int? ?? 0;
      return EvaluationResult(
        evaluatorId: id,
        passed: result.passed,
        score: result.score,
        rationale: total == 0
            ? 'no hidden tests found'
            : '$passed/$total hidden tests passed',
        details: {
          'total': total,
          'passed': passed,
          'failed': failed,
          'errored': errored,
          'failures': _sanitizedFailures(failed + errored),
          'exit_code': result.details['exit_code'],
          'tool': result.details['tool'],
          'test_path': verifier.testPath,
          'injected_files': injected.keys.toList(growable: false),
        },
      );
    } on Object catch (e) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'hidden verifier failed to run',
        details: {
          'error': e.toString(),
          'test_path': verifier.testPath,
          'injected_files': injected.keys.toList(growable: false),
        },
      );
    } finally {
      for (final file in injected.values) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  List<Map<String, Object>> _sanitizedFailures(int count) {
    return List<Map<String, Object>>.generate(
      count,
      (i) => {'index': i + 1, 'message': 'hidden verifier failure'},
    );
  }
}
