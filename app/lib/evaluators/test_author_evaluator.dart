import 'dart:io';

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/_test_reporter_parser.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
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
  TestAuthorEvaluator({required this.testPath, required this.mutants});

  final String testPath;
  final List<TestMutant> mutants;

  @override
  String get id => 'test_author';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final exe = ctx.task.isFlutter ? 'flutter' : 'dart';
    final originalRun = await _runTests(
      exe,
      ctx.workDir.path,
      deniedEnvironmentKeys: ctx.deniedEnvironmentKeys,
    );
    final originalSummary = parseTestReporterJson(
      originalRun.stdout.toString(),
    );
    if (originalRun.exitCode != 0 || !originalSummary.allPassed) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: originalSummary.total == 0
            ? 'generated tests did not run'
            : 'generated tests fail on the correct implementation',
        details: {
          'tool': exe,
          'test_path': testPath,
          'original_exit_code': originalRun.exitCode,
          'original_total': originalSummary.total,
          'original_passed': originalSummary.passed,
          'original_failures': originalSummary.failures,
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
        );
        if (mutantRun.exitCode != 0) {
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

  Future<ProcessResult> _runTests(
    String exe,
    String workDir, {
    required Iterable<String> deniedEnvironmentKeys,
  }) {
    return Process.run(
      exe,
      ['test', testPath, '--reporter=json'],
      workingDirectory: workDir,
      environment: benchmarkSubprocessEnvironment(
        additionalDeniedKeys: deniedEnvironmentKeys,
      ),
      includeParentEnvironment: false,
    );
  }
}
