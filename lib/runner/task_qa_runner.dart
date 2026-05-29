import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';

class TaskQaReport {
  const TaskQaReport({
    required this.taskId,
    required this.taskVersion,
    required this.baselineHiddenFailed,
    required this.referencePublicPassed,
    required this.referenceHiddenPassed,
    required this.hiddenFlakeRuns,
    required this.failureMessages,
    required this.baselineHiddenResults,
    required this.referencePublicResults,
    required this.referenceHiddenResults,
  });

  final String taskId;
  final int taskVersion;
  final bool baselineHiddenFailed;
  final bool referencePublicPassed;
  final bool referenceHiddenPassed;
  final int hiddenFlakeRuns;
  final List<String> failureMessages;
  final List<EvaluationResult> baselineHiddenResults;
  final List<EvaluationResult> referencePublicResults;
  final List<EvaluationResult> referenceHiddenResults;

  bool get referencePassed => referencePublicPassed && referenceHiddenPassed;
}

class TaskQaRunner {
  TaskQaRunner({
    required this.workdirManager,
    this.evaluatorConfig = const EvaluatorConfig(),
    this.requiredHiddenFlakeRuns = 3,
  });

  final WorkdirManager workdirManager;
  final EvaluatorConfig evaluatorConfig;
  final int requiredHiddenFlakeRuns;

  Future<TaskQaReport> run(BenchmarkTask task) async {
    await task.ensureLoaded();

    final failureMessages = <String>[];
    if (task.hiddenVerifiers.isEmpty) {
      failureMessages.add('Task has no hidden verifiers.');
    }
    final referenceSolution = task.referenceSolution;
    if (referenceSolution == null) {
      failureMessages.add('Task has no executable reference solution.');
    }

    final baselineHiddenResults = <EvaluationResult>[];
    var baselineHiddenFailed = false;
    if (task.hiddenVerifiers.isNotEmpty) {
      final baselineDir = await workdirManager.createTaskWorkdir(
        runId: 'qa-baseline-${task.id}',
        providerId: 'task_qa',
        modelId: 'baseline',
        taskId: task.id,
        fixtures: task.fixtures,
        generatedCode: null,
        generatedCodePath: task.generatedCodePath,
      );
      final prep = await workdirManager.prepare(
        baselineDir,
        isFlutter: task.isFlutter,
      );
      if (prep is PrepareFailed) {
        failureMessages.add('Baseline prepare failed: ${prep.stderr}');
      } else {
        baselineHiddenResults.addAll(
          await _runHiddenVerifiers(task, baselineDir),
        );
        baselineHiddenFailed = baselineHiddenResults.any((r) => !r.passed);
        if (!baselineHiddenFailed) {
          failureMessages.add('Baseline did not fail hidden verification.');
        }
      }
    }

    final referencePublicResults = <EvaluationResult>[];
    final referenceHiddenResults = <EvaluationResult>[];
    var referencePublicPassed = false;
    var referenceHiddenPassed = false;
    var hiddenFlakeRuns = 0;

    if (referenceSolution != null) {
      final referenceDir = await workdirManager.createTaskWorkdir(
        runId: 'qa-reference-${task.id}',
        providerId: 'task_qa',
        modelId: 'reference',
        taskId: task.id,
        fixtures: task.fixtures,
        generatedCode: null,
        generatedCodePath: task.generatedCodePath,
      );
      try {
        await applyReferenceSolution(referenceDir, referenceSolution);
      } on Object catch (e) {
        failureMessages.add('Reference solution failed to apply: $e');
      }

      final prep = await workdirManager.prepare(
        referenceDir,
        isFlutter: task.isFlutter,
      );
      if (prep is PrepareFailed) {
        failureMessages.add('Reference prepare failed: ${prep.stderr}');
      } else {
        referencePublicResults.addAll(
          await _runPublicEvaluators(task, referenceDir),
        );
        referencePublicPassed = referencePublicResults.every((r) => r.passed);
        if (!referencePublicPassed) {
          failureMessages.addAll(
            referencePublicResults
                .where((r) => !r.passed)
                .map(
                  (r) =>
                      'Reference public evaluator failed: ${r.evaluatorId} '
                      '(${r.rationale ?? 'no rationale'})',
                ),
          );
        }

        for (var i = 0; i < requiredHiddenFlakeRuns; i++) {
          final results = await _runHiddenVerifiers(task, referenceDir);
          referenceHiddenResults.addAll(results);
          if (results.every((r) => r.passed)) {
            hiddenFlakeRuns++;
          } else {
            final failedIds = results
                .where((r) => !r.passed)
                .map((r) => '${r.evaluatorId}: ${r.rationale}')
                .join(', ');
            failureMessages.add(
              'Reference hidden verifier failed on run ${i + 1}: $failedIds.',
            );
            break;
          }
        }
        referenceHiddenPassed = hiddenFlakeRuns == requiredHiddenFlakeRuns;
      }
    }

    return TaskQaReport(
      taskId: task.id,
      taskVersion: task.version,
      baselineHiddenFailed: baselineHiddenFailed,
      referencePublicPassed: referencePublicPassed,
      referenceHiddenPassed: referenceHiddenPassed,
      hiddenFlakeRuns: hiddenFlakeRuns,
      failureMessages: List.unmodifiable(failureMessages),
      baselineHiddenResults: List.unmodifiable(baselineHiddenResults),
      referencePublicResults: List.unmodifiable(referencePublicResults),
      referenceHiddenResults: List.unmodifiable(referenceHiddenResults),
    );
  }

  Future<List<EvaluationResult>> _runPublicEvaluators(
    BenchmarkTask task,
    Directory workDir,
  ) async {
    final hiddenIds = task.hiddenVerifiers.map((v) => v.id).toSet();
    final evaluators = task
        .evaluatorsFor(evaluatorConfig)
        .where((e) => e is! HiddenTestEvaluator && !hiddenIds.contains(e.id));
    return _runEvaluators(task, workDir, evaluators);
  }

  Future<List<EvaluationResult>> _runHiddenVerifiers(
    BenchmarkTask task,
    Directory workDir,
  ) {
    final evaluators = task.hiddenVerifiers.map(HiddenTestEvaluator.new);
    return _runEvaluators(task, workDir, evaluators);
  }

  Future<List<EvaluationResult>> _runEvaluators(
    BenchmarkTask task,
    Directory workDir,
    Iterable<Evaluator> evaluators,
  ) async {
    final results = <EvaluationResult>[];
    for (final evaluator in evaluators) {
      results.add(
        await evaluator.evaluate(
          EvaluationContext(
            workDir: workDir,
            response: const ModelResponse(
              rawText: '',
              extractedCode: null,
              promptTokens: null,
              completionTokens: null,
              latency: Duration.zero,
            ),
            task: task,
          ),
        ),
      );
    }
    return results;
  }
}
