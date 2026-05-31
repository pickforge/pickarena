import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/patch_capture.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/runner/run_progress_snapshot.dart';
import 'package:dart_arena/runner/workdir_manager.dart';

typedef AgenticProgressCallback =
    void Function(
      RunComboPhase phase, {
      String? answerPreview,
      int? promptTokens,
      int? completionTokens,
    });

class AgenticRunOrchestrator {
  AgenticRunOrchestrator({
    required this.workdirManager,
    this.patchCapture = const PatchCapture(),
    this.weights = defaultEvaluatorWeights,
    DateTime Function()? now,
    this.maxPatchChars = 256 * 1024,
  }) : now = now ?? DateTime.now;

  final WorkdirManager workdirManager;
  final PatchCapture patchCapture;
  final Map<String, double> weights;
  final DateTime Function() now;
  final int maxPatchChars;

  Future<TaskRunResult> run({
    required String runId,
    required BenchmarkTask task,
    required AgentHarness harness,
    required String providerId,
    required String modelId,
    required int trialIndex,
    required EvaluatorConfig evaluatorConfig,
    String? planId,
    AgenticProgressCallback? onProgress,
  }) async {
    Directory? workspace;
    try {
      onProgress?.call(RunComboPhase.creatingWorkdir);
      workspace = await workdirManager.createAgenticTaskWorkdir(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        taskId: task.id,
        workspace: task.workspace,
        trialIndex: trialIndex,
      );
    } on Object catch (e) {
      return _failureResult(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        task: task,
        trialIndex: trialIndex,
        planId: planId,
        harnessId: harness.id,
        rationale: 'workspace preparation failed',
        error: e,
      );
    }

    onProgress?.call(RunComboPhase.preparingWorkspace);
    final initialPrep = await workdirManager.prepare(
      workspace,
      isFlutter: task.isFlutter,
    );
    if (initialPrep is PrepareFailed) {
      return _failureResult(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        task: task,
        trialIndex: trialIndex,
        planId: planId,
        harnessId: harness.id,
        rationale: 'prepare failed',
        error: initialPrep.stderr,
      );
    }

    onProgress?.call(RunComboPhase.runningAgent);
    final harnessStopwatch = Stopwatch()..start();
    late final AgentRunResult agentResult;
    try {
      agentResult = await harness.run(
        workspace: workspace,
        instruction: task.workspace.instruction ?? task.prompt,
        modelId: modelId,
        timeout: task.timeout ?? const Duration(minutes: 30),
      );
    } on Object catch (e) {
      harnessStopwatch.stop();
      agentResult = AgentRunResult(
        status: AgentRunStatus.failure,
        stdoutPreview: '',
        stderrPreview: e.toString(),
        exitCode: null,
        latency: harnessStopwatch.elapsed,
        metadata: {'exception': e.runtimeType.toString()},
      );
    }
    onProgress?.call(
      RunComboPhase.runningAgent,
      answerPreview: _combinedPreview(agentResult),
      promptTokens: agentResult.promptTokens,
      completionTokens: agentResult.completionTokens,
    );

    onProgress?.call(RunComboPhase.capturingPatch);
    PatchCaptureResult? capturedPatch;
    EvaluationResult? patchFailure;
    try {
      capturedPatch = await patchCapture.capture(workspace);
    } on Object catch (e) {
      patchFailure = EvaluationResult(
        evaluatorId: 'agent_patch',
        passed: false,
        score: 0.0,
        rationale: 'patch capture failed',
        details: {'error': e.toString()},
      );
    }

    final patchText = capturedPatch == null
        ? null
        : _boundedPatch(capturedPatch.patch);
    final response = ModelResponse(
      rawText: _combinedPreview(agentResult),
      extractedCode: patchText,
      promptTokens: agentResult.promptTokens,
      completionTokens: agentResult.completionTokens,
      latency: agentResult.latency,
    );
    final evaluations = <EvaluationResult>[
      _harnessEvaluation(agentResult),
      if (patchFailure != null) patchFailure,
    ];

    onProgress?.call(RunComboPhase.grading);
    final gradingPrep = await workdirManager.prepare(
      workspace,
      isFlutter: task.isFlutter,
    );
    final evaluators = task.evaluatorsFor(evaluatorConfig);
    if (gradingPrep is PrepareFailed) {
      for (final evaluator in evaluators) {
        evaluations.add(
          EvaluationResult(
            evaluatorId: evaluator.id,
            passed: false,
            score: 0.0,
            rationale: 'prepare failed',
            details: {'stderr': gradingPrep.stderr},
          ),
        );
      }
    } else {
      for (final evaluator in evaluators) {
        evaluations.add(
          await evaluator.evaluate(
            EvaluationContext(
              workDir: workspace,
              response: response,
              task: task,
              previousResults: evaluations,
            ),
          ),
        );
      }
    }

    onProgress?.call(RunComboPhase.persisting);
    final aggregateScore = aggregate(evaluations, weights);
    final primitives = determineResultPrimitives(
      evaluations: evaluations,
      aggregateScore: aggregateScore,
      response: response,
    );

    return TaskRunResult(
      runId: runId,
      providerId: providerId,
      modelId: modelId,
      taskId: task.id,
      response: response,
      evaluations: evaluations,
      aggregateScore: aggregateScore,
      completedAt: now(),
      trialIndex: trialIndex,
      taskVersion: task.version,
      benchmarkTrack: task.track.name,
      harnessId: harness.id,
      primaryPass: primitives.primaryPass,
      failureTag: primitives.failureTag,
      patchText: patchText,
      trajectoryLogPath: agentResult.trajectoryLogPath,
      planId: planId,
    );
  }

  TaskRunResult missingHarnessResult({
    required String runId,
    required BenchmarkTask task,
    required String providerId,
    required String modelId,
    required int trialIndex,
    String? planId,
  }) {
    return _failureResult(
      runId: runId,
      providerId: providerId,
      modelId: modelId,
      task: task,
      trialIndex: trialIndex,
      planId: planId,
      harnessId: null,
      rationale: 'no agent harness configured',
      error: 'No agent harness configured for provider "$providerId".',
    );
  }

  TaskRunResult _failureResult({
    required String runId,
    required String providerId,
    required String modelId,
    required BenchmarkTask task,
    required int trialIndex,
    required String? planId,
    required String? harnessId,
    required String rationale,
    required Object error,
  }) {
    final response = ModelResponse(
      rawText: error.toString(),
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    );
    final evaluation = EvaluationResult(
      evaluatorId: 'agent_harness',
      passed: false,
      score: 0.0,
      rationale: rationale,
      details: {'error': error.toString()},
    );
    final aggregateScore = aggregate([evaluation], weights);
    final primitives = determineResultPrimitives(
      evaluations: [evaluation],
      aggregateScore: aggregateScore,
      response: response,
    );
    return TaskRunResult(
      runId: runId,
      providerId: providerId,
      modelId: modelId,
      taskId: task.id,
      response: response,
      evaluations: [evaluation],
      aggregateScore: aggregateScore,
      completedAt: now(),
      trialIndex: trialIndex,
      taskVersion: task.version,
      benchmarkTrack: task.track.name,
      harnessId: harnessId,
      primaryPass: primitives.primaryPass,
      failureTag: primitives.failureTag,
      planId: planId,
    );
  }

  EvaluationResult _harnessEvaluation(AgentRunResult result) {
    final passed = result.succeeded;
    return EvaluationResult(
      evaluatorId: 'agent_harness',
      passed: passed,
      score: passed ? 1.0 : 0.0,
      rationale: passed
          ? 'agent harness completed'
          : switch (result.status) {
              AgentRunStatus.timeout => 'agent harness timed out',
              AgentRunStatus.cancelled => 'agent harness cancelled',
              AgentRunStatus.failure => 'agent harness failed',
              AgentRunStatus.success => 'agent harness exited non-zero',
            },
      details: {
        'status': result.status.name,
        'exit_code': result.exitCode,
        'stdout_preview': result.stdoutPreview,
        'stderr_preview': result.stderrPreview,
        if (!passed)
          'error': result.status == AgentRunStatus.timeout
              ? 'timeout'
              : 'exit code ${result.exitCode}',
        if (result.trajectoryLogPath != null)
          'trajectory_log_path': result.trajectoryLogPath,
        ...result.metadata,
      },
    );
  }

  String _combinedPreview(AgentRunResult result) {
    final buffer = StringBuffer();
    if (result.stdoutPreview.isNotEmpty) {
      buffer.writeln(result.stdoutPreview);
    }
    if (result.stderrPreview.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('stderr:');
      buffer.writeln(result.stderrPreview);
    }
    return buffer.toString();
  }

  String _boundedPatch(String patch) {
    if (patch.length <= maxPatchChars) return patch;
    return '${patch.substring(0, maxPatchChars)}'
        '\n\n[patch truncated at $maxPatchChars characters]\n';
  }
}
