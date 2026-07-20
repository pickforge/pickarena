import 'dart:async';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dart_arena/runner/evaluator_resource_limits.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/objective_evaluation.dart';
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:dart_arena/runner/workdir_manager.dart';

typedef CodegenCancellationCheck = void Function();
typedef CodegenRemainingTimeout = Duration? Function();

class CodegenTaskExecutor {
  CodegenTaskExecutor({
    required this.workdirManager,
    required this.weights,
    required this.now,
    this.generatedCodeSandbox,
  });

  final WorkdirManager workdirManager;
  final Map<String, double> weights;
  final DateTime Function() now;
  final GeneratedCodeSandbox? generatedCodeSandbox;

  Future<TaskRunResult> run({
    required String runId,
    required BenchmarkTask task,
    required ModelProvider provider,
    required String modelId,
    required int trialIndex,
    required EvaluatorConfig evaluatorConfig,
    String? planId,
    String? planMarkdown,
    CodegenCancellationCheck? cancellationCheck,
    CodegenRemainingTimeout? remainingTimeout,
    Future<void>? cancellationSignal,
  }) async {
    cancellationCheck?.call();
    final targetContext = buildPromptSafeTargetContext(
      targetPath: task.generatedCodePath,
      fixtures: task.fixtures,
    );
    final prompt = buildPromptWithPlan(
      taskPrompt: task.prompt,
      targetContext: targetContext,
      planMarkdown: planMarkdown,
    );
    final taskTimeout = task.timeout ?? const Duration(minutes: 10);

    ModelResponse response;

    if (provider is StreamingModelProvider) {
      final rawBuf = StringBuffer();
      final stopwatch = Stopwatch()..start();
      int? promptTokens;
      int? completionTokens;

      cancellationCheck?.call();
      final modelTimeout = _effectiveTimeout(
        taskTimeout,
        remainingTimeout,
        cancellationCheck,
      );
      await for (final event in provider.generateStream(
        prompt: prompt,
        model: modelId,
        timeout: modelTimeout,
      )) {
        cancellationCheck?.call();
        switch (event) {
          case ModelStreamReasoningDelta():
            break;
          case ModelStreamContentDelta(:final text):
            rawBuf.write(text);
          case ModelStreamUsage(
            promptTokens: final pt,
            completionTokens: final ct,
          ):
            promptTokens = pt;
            completionTokens = ct;
          case ModelStreamStarted():
          case ModelStreamCompleted():
            break;
        }
      }

      cancellationCheck?.call();
      stopwatch.stop();
      response = ModelResponse(
        rawText: rawBuf.toString(),
        extractedCode: null,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        latency: stopwatch.elapsed,
      );
    } else {
      cancellationCheck?.call();
      final modelTimeout = _effectiveTimeout(
        taskTimeout,
        remainingTimeout,
        cancellationCheck,
      );
      response = await provider.generate(
        prompt: prompt,
        model: modelId,
        timeout: modelTimeout,
      );
      cancellationCheck?.call();
    }

    cancellationCheck?.call();
    final extracted = extractDartCode(response.rawText) ?? response.rawText;
    final responseWithCode = _copyWithCode(response, extracted);

    cancellationCheck?.call();
    final dir = await workdirManager.createTaskWorkdir(
      runId: runId,
      providerId: provider.id,
      modelId: modelId,
      taskId: task.id,
      fixtures: task.fixtures,
      generatedCode: extracted,
      generatedCodePath: task.generatedCodePath,
      trialIndex: trialIndex,
    );
    cancellationCheck?.call();

    final evaluators = applyTaskResourceLimitsToEvaluators(
      task.evaluatorsFor(evaluatorConfig),
      task,
    );
    cancellationCheck?.call();
    final prepResult = await workdirManager.prepare(
      dir,
      isFlutter: task.isFlutter,
      allowInternet: task.allowInternet,
      remainingTimeout: remainingTimeout,
      cancellationCheck: cancellationCheck,
      cancellationSignal: cancellationSignal,
      generatedCodeSandbox: generatedCodeSandbox,
      maxCpuCores: task.effectiveResourceLimits.cpus,
    );
    cancellationCheck?.call();
    final evaluations = <EvaluationResult>[];

    if (prepResult is PrepareFailed) {
      blockEvaluatorsForHardFailure(
        evaluations: evaluations,
        evaluators: evaluators,
        failure: environmentFailureEvaluation(
          rationale: 'prepare failed',
          stderr: prepResult.stderr,
        ),
      );
    } else {
      await runObjectiveEvaluators(
        evaluators: evaluators,
        evaluations: evaluations,
        contextFor: (previousResults) => EvaluationContext(
          workDir: dir,
          response: responseWithCode,
          task: task,
          previousResults: previousResults,
          deniedEnvironmentKeys: workdirManager.deniedEnvironmentKeys,
          generatedCodeSandbox: generatedCodeSandbox,
        ),
        cancellationCheck: cancellationCheck,
      );
    }

    cancellationCheck?.call();
    final outcome = finalizeObjectiveEvaluation(
      evaluations: evaluations,
      weights: weights,
      response: responseWithCode,
    );

    return TaskRunResult(
      runId: runId,
      providerId: provider.id,
      modelId: modelId,
      taskId: task.id,
      response: responseWithCode,
      evaluations: outcome.evaluations,
      aggregateScore: outcome.aggregateScore,
      completedAt: now(),
      trialIndex: trialIndex,
      taskVersion: task.version,
      benchmarkTrack: task.track.name,
      primaryPass: outcome.primaryPass,
      failureTag: outcome.failureTag,
      planId: planId,
    );
  }

  Duration _effectiveTimeout(
    Duration taskTimeout,
    CodegenRemainingTimeout? remainingTimeout,
    CodegenCancellationCheck? cancellationCheck,
  ) {
    final remaining = remainingTimeout?.call();
    if (remaining == null) return taskTimeout;
    if (remaining.compareTo(Duration.zero) <= 0) {
      cancellationCheck?.call();
      throw TimeoutException('codegen task timed out', remaining);
    }
    return remaining.compareTo(taskTimeout) < 0 ? remaining : taskTimeout;
  }
}

ModelResponse _copyWithCode(ModelResponse r, String? code) => ModelResponse(
  rawText: r.rawText,
  extractedCode: code,
  promptTokens: r.promptTokens,
  completionTokens: r.completionTokens,
  latency: r.latency,
);
