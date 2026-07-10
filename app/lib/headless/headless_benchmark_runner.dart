import 'dart:async';
import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/export/artifact_bundle.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/agentic_run_orchestrator.dart';
import 'package:dart_arena/runner/codegen_task_executor.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/run_provenance.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:path/path.dart' as p;

const _timeoutCleanupGrace = Duration(milliseconds: 2500);

class HeadlessBenchmarkConfig {
  HeadlessBenchmarkConfig({
    required this.runId,
    required this.tasks,
    required this.providers,
    required this.modelsByProvider,
    this.agentHarnesses = const [],
    required this.evaluatorConfig,
    required this.evaluatorWeights,
    required this.workdirManager,
    required this.runDao,
    required this.bundleOutputParent,
    required this.now,
    required this.idGenerator,
    required this.provenanceEnvironmentProvider,
    required this.exportEnvironmentProvider,
    required this.exportAppVersionProvider,
    required List<Directory> allowedTrajectoryRoots,
    this.name,
    this.planDao,
    this.maxConcurrency = 4,
    this.trialsPerTask = 1,
    this.useReferencePlan = false,
    this.generatedCodeSandboxRequired = false,
    this.generatedCodeSandboxEnforced = false,
    this.generatedCodeSandboxBackend,
    this.generatedCodeSandbox,
    this.timeout = const Duration(minutes: 10),
  }) : allowedTrajectoryRoots = List.unmodifiable(allowedTrajectoryRoots);

  final String runId;
  final String? name;
  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, List<String>> modelsByProvider;
  final List<AgentHarness> agentHarnesses;
  final EvaluatorConfig evaluatorConfig;
  final Map<String, double> evaluatorWeights;
  final WorkdirManager workdirManager;
  final RunDao runDao;
  final PlanDao? planDao;
  final Directory bundleOutputParent;
  final DateTime Function() now;
  final String Function() idGenerator;
  final RunProvenanceEnvironmentProvider provenanceEnvironmentProvider;
  final Future<Map<String, Object?>> Function() exportEnvironmentProvider;
  final Future<String> Function() exportAppVersionProvider;
  final List<Directory> allowedTrajectoryRoots;
  final int maxConcurrency;
  final int trialsPerTask;
  final bool useReferencePlan;
  final bool generatedCodeSandboxRequired;
  final bool generatedCodeSandboxEnforced;
  final String? generatedCodeSandboxBackend;
  final GeneratedCodeSandbox? generatedCodeSandbox;
  final Duration timeout;
}

class HeadlessBenchmarkResult {
  const HeadlessBenchmarkResult({
    required this.runId,
    required this.finalSummary,
    required this.exportedBundleDirectory,
    required this.bundleWarningCount,
    required this.taskRunCount,
    required this.evaluationCount,
  });

  final String runId;
  final RunSummary finalSummary;
  final Directory exportedBundleDirectory;
  final int bundleWarningCount;
  final int taskRunCount;
  final int evaluationCount;
}

class HeadlessBenchmarkRunner {
  const HeadlessBenchmarkRunner();

  Future<HeadlessBenchmarkResult> run(HeadlessBenchmarkConfig config) async {
    final cancellation = _HeadlessRunCancellation(config.timeout);
    var providersDisposed = false;

    void disposeProviders() {
      if (providersDisposed) return;
      providersDisposed = true;
      for (final provider in config.providers) {
        provider.dispose();
      }
    }

    try {
      final runFuture = _run(config, cancellation);
      final signal = await Future.any<_HeadlessRunSignal>([
        runFuture.then<_HeadlessRunSignal>(
          _HeadlessRunCompleted.new,
          onError: (Object error, StackTrace stackTrace) =>
              _HeadlessRunFailed(error, stackTrace),
        ),
        Future<void>.delayed(
          config.timeout,
        ).then<_HeadlessRunSignal>((_) => const _HeadlessRunTimedOut()),
      ]);

      switch (signal) {
        case _HeadlessRunCompleted(:final result):
          return result;
        case _HeadlessRunFailed(:final error, :final stackTrace):
          Error.throwWithStackTrace(error, stackTrace);
        case _HeadlessRunTimedOut():
          cancellation.cancel();
          disposeProviders();
          try {
            return await runFuture.timeout(
              _timeoutCleanupGrace,
              onTimeout: () => throw cancellation.timeoutException,
            );
          } on Object {
            if (cancellation.isCancelled) {
              throw cancellation.timeoutException;
            }
            rethrow;
          }
      }
    } finally {
      disposeProviders();
    }
  }

  Future<HeadlessBenchmarkResult> _run(
    HeadlessBenchmarkConfig config,
    _HeadlessRunCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    if (config.generatedCodeSandboxRequired &&
        config.generatedCodeSandbox == null) {
      throw StateError(
        'Generated-code sandbox is required, but no sandbox backend was '
        'configured.',
      );
    }
    final normalizedModels = _normalizeModels(config);

    final combos = _buildCombos(config, normalizedModels);
    if (combos.isEmpty) {
      throw StateError('No benchmark combos selected');
    }

    cancellation.throwIfCancelled();
    await config.runDao.startRun(
      runId: config.runId,
      startedAt: config.now(),
      name: config.name,
    );
    cancellation.throwIfCancelled();

    for (final task in config.tasks) {
      await task.ensureLoaded();
      cancellation.throwIfCancelled();
    }

    final planIdsByTask = <String, String?>{};
    final planMarkdownsByTask = <String, String?>{};
    if (config.useReferencePlan) {
      for (final task in config.tasks) {
        if (task.referencePlan != null) {
          planMarkdownsByTask[task.id] = task.referencePlan!.markdown;
          if (config.planDao != null) {
            planIdsByTask[task.id] = await config.planDao!.upsertReferencePlan(
              taskId: task.id,
              version: task.referencePlan!.version,
              artifact: task.referencePlan!.markdown,
            );
            cancellation.throwIfCancelled();
          }
        }
      }
    }

    final plannedCombos = [
      for (final combo in combos)
        combo.copyWith(
          planId: planIdsByTask[combo.task.id],
          planMarkdown: planMarkdownsByTask[combo.task.id],
        ),
    ];

    final provenanceConfig = RunProvenanceConfig(
      tasks: config.tasks,
      providers: config.providers,
      evaluatorConfig: config.evaluatorConfig,
      useReferencePlan: config.useReferencePlan,
      name: config.name,
      maxConcurrency: config.maxConcurrency,
      trialsPerTask: config.trialsPerTask,
      generatedCodeSandboxRequired: config.generatedCodeSandboxRequired,
      generatedCodeSandboxEnforced: config.generatedCodeSandboxEnforced,
      generatedCodeSandboxBackend: config.generatedCodeSandboxBackend,
    );
    final provenanceJson = await buildRunProvenanceJson(
      runId: config.runId,
      config: provenanceConfig,
      normalizedModelsByProvider: normalizedModels,
      combos: [
        for (final combo in plannedCombos)
          RunProvenanceCombo(
            index: combo.index,
            task: combo.task,
            providerId: combo.provider.id,
            modelId: combo.modelId,
            trialIndex: combo.trialIndex,
            planId: combo.planId,
          ),
      ],
      evaluatorWeights: config.evaluatorWeights,
      capturedAt: config.now(),
      environmentProvider: config.provenanceEnvironmentProvider,
    );
    cancellation.throwIfCancelled();
    await config.runDao.updateRunProvenance(config.runId, provenanceJson);
    cancellation.throwIfCancelled();

    await _runCombos(config, plannedCombos, cancellation);
    cancellation.throwIfCancelled();
    await config.runDao.finishRun(config.runId, config.now());
    cancellation.throwIfCancelled();

    final summary = await config.runDao.loadSummary(config.runId);
    cancellation.throwIfCancelled();
    if (summary == null) {
      throw StateError(
        'Headless run completed but no summary was found for ${config.runId}',
      );
    }

    final bundleDirectory = Directory(
      p.join(
        config.bundleOutputParent.path,
        runBundleDirectoryName(config.runId),
      ),
    );
    cancellation.throwIfCancelled();
    final export = await exportRunBundle(
      summary: summary,
      targetDirectory: bundleDirectory,
      now: config.now,
      allowedTrajectoryRoots: config.allowedTrajectoryRoots,
      environmentProvider: config.exportEnvironmentProvider,
      appVersionProvider: config.exportAppVersionProvider,
    );
    cancellation.throwIfCancelled();

    return HeadlessBenchmarkResult(
      runId: config.runId,
      finalSummary: summary,
      exportedBundleDirectory: export.directory,
      bundleWarningCount: export.warnings.length,
      taskRunCount: summary.taskRuns.length,
      evaluationCount: summary.evaluationsByTaskRunId.values.fold<int>(
        0,
        (sum, evaluations) => sum + evaluations.length,
      ),
    );
  }

  Map<String, List<String>> _normalizeModels(HeadlessBenchmarkConfig config) {
    final normalizedModels = <String, List<String>>{};
    for (final provider in config.providers) {
      final models = config.modelsByProvider[provider.id];
      if (models == null) continue;
      final seen = <String>{};
      final deduped = <String>[];
      for (final model in models) {
        final trimmed = model.trim();
        if (trimmed.isEmpty) continue;
        if (seen.add(trimmed)) deduped.add(trimmed);
      }
      if (deduped.isEmpty) {
        throw StateError('No models selected for ${provider.id}');
      }
      normalizedModels[provider.id] = deduped;
    }
    return normalizedModels;
  }

  List<_HeadlessCombo> _buildCombos(
    HeadlessBenchmarkConfig config,
    Map<String, List<String>> normalizedModels,
  ) {
    final trialsPerTask = config.trialsPerTask < 1 ? 1 : config.trialsPerTask;
    final combos = <_HeadlessCombo>[];
    var index = 0;
    for (final task in config.tasks) {
      for (final provider in config.providers) {
        final models = normalizedModels[provider.id];
        if (models == null) continue;
        for (final modelId in models) {
          for (var trialIndex = 0; trialIndex < trialsPerTask; trialIndex++) {
            final baseLabel =
                '${provider.displayName} / $modelId on ${task.id}';
            final label = trialsPerTask == 1
                ? baseLabel
                : '$baseLabel (trial ${trialIndex + 1}/$trialsPerTask)';
            combos.add(
              _HeadlessCombo(
                index: index,
                task: task,
                provider: provider,
                modelId: modelId,
                trialIndex: trialIndex,
                label: label,
              ),
            );
            index++;
          }
        }
      }
    }
    return combos;
  }

  Future<void> _runCombos(
    HeadlessBenchmarkConfig config,
    List<_HeadlessCombo> combos,
    _HeadlessRunCancellation cancellation,
  ) async {
    final codegenExecutor = CodegenTaskExecutor(
      workdirManager: config.workdirManager,
      weights: config.evaluatorWeights,
      now: config.now,
      generatedCodeSandbox: config.generatedCodeSandbox,
    );
    final agenticOrchestrator = AgenticRunOrchestrator(
      workdirManager: config.workdirManager,
      weights: config.evaluatorWeights,
      now: config.now,
      generatedCodeSandbox: config.generatedCodeSandbox,
    );
    final harnessesByProviderId = {
      for (final harness in config.agentHarnesses) harness.id: harness,
    };
    final failures = <_HeadlessComboFailure>[];
    var nextIndex = 0;
    final workerCount = config.maxConcurrency.clamp(1, 8);

    Future<void> worker() async {
      while (true) {
        cancellation.throwIfCancelled();
        final index = nextIndex;
        nextIndex++;
        if (index >= combos.length) return;
        final combo = combos[index];
        try {
          final result = await _runCombo(
            config: config,
            combo: combo,
            codegenExecutor: codegenExecutor,
            agenticOrchestrator: agenticOrchestrator,
            harnessesByProviderId: harnessesByProviderId,
            cancellation: cancellation,
          );
          cancellation.throwIfCancelled();
          await config.runDao.persistTaskRun(result);
          cancellation.throwIfCancelled();
        } catch (error, stackTrace) {
          cancellation.throwIfCancelled();
          failures.add(
            await _persistComboFailure(
              config,
              combo,
              error,
              stackTrace,
              cancellation,
            ),
          );
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < workerCount && i < combos.length; i++) worker(),
    ], eagerError: true);

    if (failures.isNotEmpty) {
      failures.sort((a, b) => a.index.compareTo(b.index));
      throw StateError(_failedComboMessage(failures));
    }
  }

  Future<TaskRunResult> _runCombo({
    required HeadlessBenchmarkConfig config,
    required _HeadlessCombo combo,
    required CodegenTaskExecutor codegenExecutor,
    required AgenticRunOrchestrator agenticOrchestrator,
    required Map<String, AgentHarness> harnessesByProviderId,
    required _HeadlessRunCancellation cancellation,
  }) {
    return switch (combo.task.track) {
      BenchmarkTrack.codegen => codegenExecutor.run(
        runId: config.runId,
        task: combo.task,
        provider: combo.provider,
        modelId: combo.modelId,
        trialIndex: combo.trialIndex,
        evaluatorConfig: config.evaluatorConfig,
        planId: combo.planId,
        planMarkdown: combo.planMarkdown,
        cancellationCheck: cancellation.throwIfCancelled,
        remainingTimeout: cancellation.remainingTimeout,
        cancellationSignal: cancellation.signal,
      ),
      BenchmarkTrack.agentic => _runAgenticCombo(
        config: config,
        combo: combo,
        orchestrator: agenticOrchestrator,
        harnessesByProviderId: harnessesByProviderId,
        cancellation: cancellation,
      ),
    };
  }

  Future<TaskRunResult> _runAgenticCombo({
    required HeadlessBenchmarkConfig config,
    required _HeadlessCombo combo,
    required AgenticRunOrchestrator orchestrator,
    required Map<String, AgentHarness> harnessesByProviderId,
    required _HeadlessRunCancellation cancellation,
  }) {
    final harness = harnessesByProviderId[combo.provider.id];
    if (harness == null) {
      return Future.value(
        orchestrator.missingHarnessResult(
          runId: config.runId,
          task: combo.task,
          providerId: combo.provider.id,
          modelId: combo.modelId,
          trialIndex: combo.trialIndex,
          planId: combo.planId,
        ),
      );
    }

    return orchestrator.run(
      runId: config.runId,
      task: combo.task,
      harness: harness,
      providerId: combo.provider.id,
      modelId: combo.modelId,
      trialIndex: combo.trialIndex,
      evaluatorConfig: config.evaluatorConfig,
      planId: combo.planId,
      cancellationCheck: cancellation.throwIfCancelled,
      remainingTimeout: cancellation.remainingTimeout,
      cancellationSignal: cancellation.signal,
    );
  }

  Future<_HeadlessComboFailure> _persistComboFailure(
    HeadlessBenchmarkConfig config,
    _HeadlessCombo combo,
    Object error,
    StackTrace stackTrace,
    _HeadlessRunCancellation cancellation,
  ) async {
    final failureEvaluation = EvaluationResult(
      evaluatorId: 'combo_failure',
      passed: false,
      score: 0.0,
      rationale: 'combo failed during run: $error',
      details: {'phase': 'run', 'error': '$error'},
    );
    final synthetic = TaskRunResult(
      runId: config.runId,
      providerId: combo.provider.id,
      modelId: combo.modelId,
      taskId: combo.task.id,
      response: const ModelResponse(
        rawText: '<error>',
        extractedCode: null,
        promptTokens: null,
        completionTokens: null,
        latency: Duration.zero,
      ),
      evaluations: [failureEvaluation],
      aggregateScore: 0.0,
      completedAt: config.now(),
      trialIndex: combo.trialIndex,
      taskVersion: combo.task.version,
      benchmarkTrack: combo.task.track.name,
      primaryPass: false,
      failureTag: determineFailureTag(
        primaryPass: false,
        evaluations: [failureEvaluation],
      ),
      planId: combo.planId,
    );

    cancellation.throwIfCancelled();
    try {
      await config.runDao.persistTaskRun(synthetic);
    } on Object catch (persistError) {
      return _HeadlessComboFailure(
        index: combo.index,
        label: combo.label,
        errorMessage: 'persist failed: $persistError',
      );
    }
    cancellation.throwIfCancelled();
    return _HeadlessComboFailure(
      index: combo.index,
      label: combo.label,
      errorMessage: '$error',
    );
  }
}

class _HeadlessRunCancellation {
  _HeadlessRunCancellation(this.timeout) : _stopwatch = Stopwatch()..start();

  final Duration timeout;
  final Stopwatch _stopwatch;
  final _cancelled = Completer<void>();

  TimeoutException get timeoutException => TimeoutException(
    'Headless benchmark run timed out after $timeout',
    timeout,
  );

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }

  Future<void> get signal => _cancelled.future;

  bool get isCancelled =>
      _cancelled.isCompleted || _stopwatch.elapsed.compareTo(timeout) >= 0;

  Duration remainingTimeout() {
    final remaining = timeout - _stopwatch.elapsed;
    return remaining.compareTo(Duration.zero) <= 0 ? Duration.zero : remaining;
  }

  void throwIfCancelled() {
    if (!isCancelled) return;
    cancel();
    throw timeoutException;
  }
}

sealed class _HeadlessRunSignal {
  const _HeadlessRunSignal();
}

class _HeadlessRunCompleted extends _HeadlessRunSignal {
  const _HeadlessRunCompleted(this.result);

  final HeadlessBenchmarkResult result;
}

class _HeadlessRunFailed extends _HeadlessRunSignal {
  const _HeadlessRunFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

class _HeadlessRunTimedOut extends _HeadlessRunSignal {
  const _HeadlessRunTimedOut();
}

class _HeadlessCombo {
  const _HeadlessCombo({
    required this.index,
    required this.task,
    required this.provider,
    required this.modelId,
    required this.trialIndex,
    required this.label,
    this.planId,
    this.planMarkdown,
  });

  final int index;
  final BenchmarkTask task;
  final ModelProvider provider;
  final String modelId;
  final int trialIndex;
  final String label;
  final String? planId;
  final String? planMarkdown;

  _HeadlessCombo copyWith({String? planId, String? planMarkdown}) {
    return _HeadlessCombo(
      index: index,
      task: task,
      provider: provider,
      modelId: modelId,
      trialIndex: trialIndex,
      label: label,
      planId: planId,
      planMarkdown: planMarkdown,
    );
  }
}

class _HeadlessComboFailure {
  const _HeadlessComboFailure({
    required this.index,
    required this.label,
    required this.errorMessage,
  });

  final int index;
  final String label;
  final String errorMessage;
}

String _failedComboMessage(List<_HeadlessComboFailure> failures) {
  final first = failures.first;
  final countSuffix = failures.length == 1
      ? ''
      : ' (${failures.length} failed combos)';
  return 'Headless run failed$countSuffix: '
      '${first.label}: ${first.errorMessage}';
}
