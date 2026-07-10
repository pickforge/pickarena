import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_integrity.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/patch_capture.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/core/workspace_path.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/evaluator_resource_limits.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/workdir_manager.dart';

class AgenticRunOrchestrator {
  AgenticRunOrchestrator({
    required this.workdirManager,
    this.patchCapture = const PatchCapture(),
    this.weights = defaultEvaluatorWeights,
    DateTime Function()? now,
    this.maxPatchChars = 256 * 1024,
    this.generatedCodeSandbox,
  }) : now = now ?? DateTime.now;

  final WorkdirManager workdirManager;
  final PatchCapture patchCapture;
  final Map<String, double> weights;
  final DateTime Function() now;
  final int maxPatchChars;
  final GeneratedCodeSandbox? generatedCodeSandbox;

  Future<TaskRunResult> run({
    required String runId,
    required BenchmarkTask task,
    required AgentHarness harness,
    required String providerId,
    required String modelId,
    required int trialIndex,
    required EvaluatorConfig evaluatorConfig,
    String? planId,
    void Function()? cancellationCheck,
    Duration Function()? remainingTimeout,
    Future<void>? cancellationSignal,
  }) async {
    Directory? workspace;
    cancellationCheck?.call();
    try {
      workspace = await workdirManager.createAgenticTaskWorkdir(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        taskId: task.id,
        workspace: task.workspace,
        trialIndex: trialIndex,
      );
    } on Object catch (e) {
      return _environmentFailureResult(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        task: task,
        trialIndex: trialIndex,
        planId: planId,
        harnessId: harness.id,
        evaluatorConfig: evaluatorConfig,
        phase: 'workspace',
        rationale: 'workspace preparation failed',
        error: e,
      );
    }
    cancellationCheck?.call();

    final initialPrep = await workdirManager.prepare(
      workspace,
      isFlutter: task.isFlutter,
      allowInternet: task.allowInternet,
      remainingTimeout: remainingTimeout,
      cancellationCheck: cancellationCheck,
      cancellationSignal: cancellationSignal,
      generatedCodeSandbox: generatedCodeSandbox,
      maxCpuCores: task.effectiveResourceLimits.cpus,
    );
    cancellationCheck?.call();
    if (initialPrep is PrepareFailed) {
      return _environmentFailureResult(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        task: task,
        trialIndex: trialIndex,
        planId: planId,
        harnessId: harness.id,
        evaluatorConfig: evaluatorConfig,
        phase: 'initial_prepare',
        rationale: 'prepare failed',
        error: initialPrep.stderr,
      );
    }
    try {
      await workdirManager.resetPatchBaseline(workspace);
    } on Object catch (e) {
      return _environmentFailureResult(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        task: task,
        trialIndex: trialIndex,
        planId: planId,
        harnessId: harness.id,
        evaluatorConfig: evaluatorConfig,
        phase: 'patch_baseline',
        rationale: 'patch baseline failed',
        error: e,
      );
    }

    cancellationCheck?.call();
    final harnessStopwatch = Stopwatch()..start();
    late final AgentRunResult agentResult;
    try {
      agentResult = await harness.run(
        workspace: workspace,
        instruction: task.workspace.instruction ?? task.prompt,
        modelId: modelId,
        timeout: _effectiveTimeout(
          task.timeout ?? const Duration(minutes: 30),
          remainingTimeout,
        ),
        deniedEnvironmentKeys: workdirManager.deniedEnvironmentKeys,
        allowInternet: task.allowInternet,
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
    cancellationCheck?.call();
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

    late final Map<String, Object?> hiddenFixtureIsolation;
    try {
      hiddenFixtureIsolation = await _hiddenFixtureIsolation(task, workspace);
    } on Object catch (e) {
      return _environmentFailureResult(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        task: task,
        trialIndex: trialIndex,
        planId: planId,
        harnessId: harness.id,
        evaluatorConfig: evaluatorConfig,
        phase: 'workspace_isolation',
        rationale: 'workspace isolation evidence failed',
        error: e,
      );
    }
    final resultProvenance = <String, Object?>{
      'gradingMode': 'clean_replay',
      'patchApplied': false,
      'patchSha256': capturedPatch?.patchSha256,
      'hiddenFixtureIsolation': hiddenFixtureIsolation,
      'hiddenVerifierDigests': hiddenVerifierDigests(task),
    };

    late final Directory gradingWorkspace;
    try {
      gradingWorkspace = await workdirManager.createAgenticGradingWorkdir(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        taskId: task.id,
        workspace: task.workspace,
        trialIndex: trialIndex,
      );
    } on Object catch (e) {
      return _environmentFailureResult(
        runId: runId,
        providerId: providerId,
        modelId: modelId,
        task: task,
        trialIndex: trialIndex,
        planId: planId,
        harnessId: harness.id,
        evaluatorConfig: evaluatorConfig,
        phase: 'grading_workspace',
        rationale: 'grading workspace preparation failed',
        error: e,
        provenance: resultProvenance,
      );
    }

    final patchText = capturedPatch == null
        ? null
        : _boundedPatch(capturedPatch.patch);
    final response = ModelResponse(
      rawText: _agentResponseText(agentResult),
      extractedCode: patchText,
      promptTokens: agentResult.promptTokens,
      completionTokens: agentResult.completionTokens,
      latency: agentResult.latency,
    );
    final evaluations = <EvaluationResult>[
      _harnessEvaluation(agentResult),
      if (patchFailure != null) patchFailure,
    ];

    cancellationCheck?.call();
    final gradingPrep = await workdirManager.prepare(
      gradingWorkspace,
      isFlutter: task.isFlutter,
      allowInternet: task.allowInternet,
      remainingTimeout: remainingTimeout,
      cancellationCheck: cancellationCheck,
      cancellationSignal: cancellationSignal,
      generatedCodeSandbox: generatedCodeSandbox,
      maxCpuCores: task.effectiveResourceLimits.cpus,
    );
    cancellationCheck?.call();
    final evaluators = applyTaskResourceLimitsToEvaluators(
      task.evaluatorsFor(evaluatorConfig),
      task,
    );
    PrepareFailed? patchApplyFailure;
    if (gradingPrep is PrepareOk) {
      try {
        await workdirManager.applyCapturedPatch(
          gradingWorkspace,
          capturedPatch?.patch ?? '',
        );
        resultProvenance['patchApplied'] =
            capturedPatch?.hasMeaningfulDiff ?? false;
      } on Object catch (e) {
        patchApplyFailure = PrepareFailed(e.toString());
      }
    }
    if (gradingPrep is PrepareFailed) {
      _addPrepareFailureEvaluations(
        evaluations: evaluations,
        evaluators: evaluators,
        failure: gradingPrep,
        phase: 'grading_prepare',
      );
    } else if (patchApplyFailure != null) {
      _addPrepareFailureEvaluations(
        evaluations: evaluations,
        evaluators: evaluators,
        failure: patchApplyFailure,
        phase: 'grading_patch_apply',
      );
    } else {
      for (final evaluator in evaluators) {
        final blocked = blockedEvaluationFor(
          evaluatorId: evaluator.id,
          previousResults: evaluations,
        );
        if (blocked != null) {
          evaluations.add(blocked);
          continue;
        }
        evaluations.add(
          await evaluator.evaluate(
            EvaluationContext(
              workDir: gradingWorkspace,
              response: response,
              task: task,
              previousResults: evaluations,
              deniedEnvironmentKeys: workdirManager.deniedEnvironmentKeys,
              generatedCodeSandbox: generatedCodeSandbox,
            ),
          ),
        );
      }
    }

    cancellationCheck?.call();
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
      provenance: resultProvenance,
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
    Map<String, Object?> provenance = const {},
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
      provenance: provenance,
    );
  }

  TaskRunResult _environmentFailureResult({
    required String runId,
    required String providerId,
    required String modelId,
    required BenchmarkTask task,
    required int trialIndex,
    required String? planId,
    required String? harnessId,
    required EvaluatorConfig evaluatorConfig,
    required String phase,
    required String rationale,
    required Object error,
    Map<String, Object?> provenance = const {},
  }) {
    final response = ModelResponse(
      rawText: error.toString(),
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    );
    final evaluations = <EvaluationResult>[
      environmentFailureEvaluation(
        rationale: rationale,
        stderr: error.toString(),
        phase: phase,
      ),
    ];
    for (final evaluator in applyTaskResourceLimitsToEvaluators(
      task.evaluatorsFor(evaluatorConfig),
      task,
    )) {
      evaluations.add(
        blockedEvaluationFor(
          evaluatorId: evaluator.id,
          previousResults: evaluations,
          blockAllDownstream: true,
        )!,
      );
    }
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
      harnessId: harnessId,
      primaryPass: primitives.primaryPass,
      failureTag: primitives.failureTag,
      planId: planId,
      provenance: provenance,
    );
  }

  Future<Map<String, Object?>> _hiddenFixtureIsolation(
    BenchmarkTask task,
    Directory workspace,
  ) async {
    final leakedPaths = <String>{};
    for (final verifier in task.hiddenVerifiers) {
      final paths = {verifier.testPath, ...verifier.files.keys};
      for (final path in paths) {
        try {
          final file = resolveWorkspaceFile(workspace, path);
          final handle = await file.open(mode: FileMode.read);
          await handle.close();
          leakedPaths.add(path);
        } on FileSystemException {
          continue;
        } on ArgumentError {
          continue;
        }
      }
    }
    return {'asserted': true, 'leakedPaths': leakedPaths.toList()..sort()};
  }

  void _addPrepareFailureEvaluations({
    required List<EvaluationResult> evaluations,
    required List<Evaluator> evaluators,
    required PrepareFailed failure,
    required String phase,
  }) {
    if (!hasHardDownstreamBlocker(evaluations)) {
      evaluations.add(
        environmentFailureEvaluation(
          rationale: 'prepare failed',
          stderr: failure.stderr,
          phase: phase,
        ),
      );
    }
    for (final evaluator in evaluators) {
      evaluations.add(
        blockedEvaluationFor(
          evaluatorId: evaluator.id,
          previousResults: evaluations,
          blockAllDownstream: true,
        )!,
      );
    }
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
        ..._sanitizedHarnessMetadata(result.metadata),
      },
    );
  }

  Map<String, Object?> _sanitizedHarnessMetadata(
    Map<String, Object?> metadata,
  ) {
    final sanitized = <String, Object?>{};
    var redactedCount = 0;
    for (final entry in metadata.entries) {
      if (_unsafeHarnessMetadataKey(entry.key)) {
        redactedCount++;
        continue;
      }
      final value = _sanitizedHarnessMetadataValue(entry.value);
      if (value == null && entry.value != null) {
        redactedCount++;
        continue;
      }
      sanitized[entry.key] = value;
    }
    if (redactedCount > 0) {
      sanitized['metadata_redacted_count'] = redactedCount;
    }
    return sanitized;
  }

  Object? _sanitizedHarnessMetadataValue(Object? value) {
    if (value == null || value is bool || value is num) return value;
    if (value is String) {
      return _unsafeHarnessMetadataString(value) ? null : value;
    }
    if (value is Map) {
      final sanitized = <String, Object?>{};
      var redactedCount = 0;
      for (final entry in value.entries) {
        final key = entry.key?.toString();
        if (key == null || _unsafeHarnessMetadataKey(key)) {
          redactedCount++;
          continue;
        }
        final childValue = _sanitizedHarnessMetadataValue(entry.value);
        if (childValue == null && entry.value != null) {
          redactedCount++;
          continue;
        }
        sanitized[key] = childValue;
      }
      if (redactedCount > 0) {
        sanitized['metadata_redacted_count'] = redactedCount;
      }
      return sanitized.isEmpty ? null : sanitized;
    }
    return null;
  }

  bool _unsafeHarnessMetadataKey(String key) {
    final normalized = key.toLowerCase();
    const allowed = {
      'argc',
      'exception',
      'metadata',
      'metadata_redacted_count',
      'output_limit_exceeded',
      'max_output_chars',
      'stepcount',
      'peakcontext',
      'peakcontexttokens',
    };
    if (allowed.contains(normalized)) return false;
    const reserved = {
      'status',
      'exit_code',
      'stdout_preview',
      'stderr_preview',
      'error',
      'trajectory_log_path',
    };
    if (reserved.contains(normalized)) return true;
    return normalized.contains('path') ||
        normalized.contains('workspace') ||
        normalized.contains('executable') ||
        normalized.contains('command') ||
        normalized.contains('prompt') ||
        normalized.contains('secret') ||
        normalized.contains('token') ||
        normalized.contains('password') ||
        normalized.contains('cookie') ||
        normalized.contains('authorization') ||
        normalized.contains('api_key');
  }

  bool _unsafeHarnessMetadataString(String value) {
    if (value.length > 128 || value.contains('\n') || value.contains('\r')) {
      return true;
    }
    final normalized = value.toLowerCase();
    if (value.startsWith('/') ||
        value.startsWith('~') ||
        value.contains(r'\') ||
        value.contains('/')) {
      return true;
    }
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) return true;
    return normalized.contains('secret') ||
        normalized.contains('token') ||
        normalized.contains('password') ||
        normalized.contains('api_key');
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

  String _agentResponseText(AgentRunResult result) {
    final preview = _combinedPreview(result);
    if (preview.trim().isNotEmpty) return preview;
    final exitCode = result.exitCode ?? 'null';
    return 'Agent harness produced no stdout/stderr preview.\n'
        'status: ${result.status.name}\n'
        'exitCode: $exitCode\n'
        'latencyMs: ${result.latency.inMilliseconds}\n';
  }

  String _boundedPatch(String patch) {
    if (patch.length <= maxPatchChars) return patch;
    return '${patch.substring(0, maxPatchChars)}'
        '\n\n[patch truncated at $maxPatchChars characters]\n';
  }

  Duration _effectiveTimeout(
    Duration taskTimeout,
    Duration Function()? remainingTimeout,
  ) {
    if (remainingTimeout == null) return taskTimeout;
    final remaining = remainingTimeout();
    if (remaining.compareTo(Duration.zero) <= 0) return Duration.zero;
    return remaining.compareTo(taskTimeout) < 0 ? remaining : taskTimeout;
  }
}
