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
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:dart_arena/runner/run_progress_snapshot.dart';
import 'package:dart_arena/runner/workdir_manager.dart';

typedef CodegenTaskProgressCallback =
    void Function(
      RunComboPhase phase, {
      String? reasoningPreview,
      String? answerPreview,
      int? promptTokens,
      int? completionTokens,
    });
typedef CodegenCancellationCheck = void Function();
typedef CodegenRemainingTimeout = Duration? Function();

class CodegenTaskExecutor {
  CodegenTaskExecutor({
    required this.workdirManager,
    required this.weights,
    required this.now,
  });

  final WorkdirManager workdirManager;
  final Map<String, double> weights;
  final DateTime Function() now;

  static const _maxPreviewChars = 16 * 1024;

  Future<TaskRunResult> run({
    required String runId,
    required BenchmarkTask task,
    required ModelProvider provider,
    required String modelId,
    required int trialIndex,
    required EvaluatorConfig evaluatorConfig,
    String? planId,
    String? planMarkdown,
    CodegenTaskProgressCallback? onProgress,
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
      var reasoningPreview = '';
      var answerPreview = '';
      final rawBuf = StringBuffer();
      final stopwatch = Stopwatch()..start();
      int? promptTokens;
      int? completionTokens;

      onProgress?.call(RunComboPhase.streamingResponse);
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
          case ModelStreamReasoningDelta(:final text):
            reasoningPreview = _trimPreview(reasoningPreview + text);
            onProgress?.call(
              RunComboPhase.streamingResponse,
              reasoningPreview: reasoningPreview,
            );
          case ModelStreamContentDelta(:final text):
            answerPreview = _trimPreview(answerPreview + text);
            rawBuf.write(text);
            onProgress?.call(
              RunComboPhase.streamingResponse,
              answerPreview: answerPreview,
            );
          case ModelStreamUsage(
            promptTokens: final pt,
            completionTokens: final ct,
          ):
            promptTokens = pt;
            completionTokens = ct;
            onProgress?.call(
              RunComboPhase.streamingResponse,
              promptTokens: promptTokens,
              completionTokens: completionTokens,
            );
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
      onProgress?.call(RunComboPhase.requestingModel);
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
      onProgress?.call(
        RunComboPhase.extractingCode,
        answerPreview: _trimPreview(response.rawText),
        promptTokens: response.promptTokens,
        completionTokens: response.completionTokens,
      );
    }

    onProgress?.call(RunComboPhase.extractingCode);
    cancellationCheck?.call();
    final extracted = extractDartCode(response.rawText) ?? response.rawText;
    final responseWithCode = _copyWithCode(response, extracted);

    onProgress?.call(RunComboPhase.creatingWorkdir);
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

    onProgress?.call(RunComboPhase.preparing);
    final evaluators = task.evaluatorsFor(evaluatorConfig);
    cancellationCheck?.call();
    final prepResult = await workdirManager.prepare(
      dir,
      isFlutter: task.isFlutter,
      remainingTimeout: remainingTimeout,
      cancellationCheck: cancellationCheck,
      cancellationSignal: cancellationSignal,
    );
    cancellationCheck?.call();
    final evaluations = <EvaluationResult>[];

    if (prepResult is PrepareFailed) {
      for (final evaluator in evaluators) {
        evaluations.add(
          EvaluationResult(
            evaluatorId: evaluator.id,
            passed: false,
            score: 0.0,
            rationale: 'prepare failed',
            details: {'stderr': prepResult.stderr},
          ),
        );
      }
    } else {
      onProgress?.call(RunComboPhase.evaluating);
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
          ),
        );
        cancellationCheck?.call();
        evaluations.add(result);
      }
    }

    onProgress?.call(RunComboPhase.persisting);
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

  String _trimPreview(String value) {
    if (value.length <= _maxPreviewChars) return value;
    return value.substring(value.length - _maxPreviewChars);
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
