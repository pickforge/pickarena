import 'dart:async';

import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/code_extractor.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dart_arena/runner/evaluator_resource_limits.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
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
      evaluations.add(
        environmentFailureEvaluation(
          rationale: 'prepare failed',
          stderr: prepResult.stderr,
        ),
      );
      for (final evaluator in evaluators) {
        evaluations.add(
          blockedEvaluationFor(
            evaluatorId: evaluator.id,
            previousResults: evaluations,
            blockAllDownstream: true,
          )!,
        );
      }
    } else {
      for (final evaluator in evaluators) {
        cancellationCheck?.call();
        final blocked = blockedEvaluationFor(
          evaluatorId: evaluator.id,
          previousResults: evaluations,
        );
        if (blocked != null) {
          evaluations.add(blocked);
          continue;
        }
        final result = await evaluator.evaluate(
          EvaluationContext(
            workDir: dir,
            response: responseWithCode,
            task: task,
            previousResults: evaluations,
            deniedEnvironmentKeys: workdirManager.deniedEnvironmentKeys,
            generatedCodeSandbox: generatedCodeSandbox,
          ),
        );
        cancellationCheck?.call();
        evaluations.add(result);
      }
    }

    cancellationCheck?.call();
    final aggregateScore = aggregate(evaluations, weights);
    final primitives = determineResultPrimitives(
      evaluations: evaluations,
      aggregateScore: aggregateScore,
      response: responseWithCode,
    );

    return TaskRunResult(
      runId: runId,
      providerId: provider.id,
      modelId: modelId,
      taskId: task.id,
      response: responseWithCode,
      evaluations: evaluations,
      aggregateScore: aggregateScore,
      completedAt: now(),
      trialIndex: trialIndex,
      taskVersion: task.version,
      benchmarkTrack: task.track.name,
      primaryPass: primitives.primaryPass,
      failureTag: primitives.failureTag,
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
