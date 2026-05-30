import 'dart:async';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/export/artifact_bundle.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_provenance.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:path/path.dart' as p;

class HeadlessBenchmarkConfig {
  HeadlessBenchmarkConfig({
    required this.runId,
    required this.tasks,
    required this.providers,
    required this.modelsByProvider,
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
    this.timeout = const Duration(minutes: 10),
  }) : allowedTrajectoryRoots = List.unmodifiable(allowedTrajectoryRoots);

  final String runId;
  final String? name;
  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, List<String>> modelsByProvider;
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
    final bloc = RunBloc(
      workdirManager: config.workdirManager,
      runDao: config.runDao,
      planDao: config.planDao,
      weights: config.evaluatorWeights,
      now: config.now,
      idGenerator: config.idGenerator,
      provenanceEnvironmentProvider: config.provenanceEnvironmentProvider,
    );

    final terminal = Completer<RunCompleted>();
    late final StreamSubscription<RunState> subscription;
    subscription = bloc.stream.listen(
      (state) {
        if (terminal.isCompleted) return;
        switch (state) {
          case RunCompleted():
            terminal.complete(state);
          case RunFailed(:final error):
            terminal.completeError(StateError('Headless run failed: $error'));
          case RunInProgress(:final failed, :final pending, :final active)
              when failed.isNotEmpty && pending == 0 && active.isEmpty:
            terminal.completeError(StateError(_failedComboMessage(state)));
          case _:
            break;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!terminal.isCompleted) {
          terminal.completeError(error, stackTrace);
        }
      },
    );

    try {
      bloc.add(
        StartRun(
          tasks: config.tasks,
          providers: config.providers,
          modelsByProvider: config.modelsByProvider,
          evaluatorConfig: config.evaluatorConfig,
          useReferencePlan: config.useReferencePlan,
          name: config.name,
          maxConcurrency: config.maxConcurrency,
          trialsPerTask: config.trialsPerTask,
        ),
      );

      final completed = await terminal.future.timeout(
        config.timeout,
        onTimeout: () => throw TimeoutException(
          'Headless benchmark run timed out after ${config.timeout}',
          config.timeout,
        ),
      );
      if (completed.runId != config.runId) {
        throw StateError(
          'Headless run completed with unexpected run id '
          '${completed.runId}; expected ${config.runId}',
        );
      }

      final summary = await config.runDao.loadSummary(completed.runId);
      if (summary == null) {
        throw StateError(
          'Headless run completed but no summary was found for '
          '${completed.runId}',
        );
      }

      final bundleDirectory = Directory(
        p.join(
          config.bundleOutputParent.path,
          runBundleDirectoryName(completed.runId),
        ),
      );
      final export = await exportRunBundle(
        summary: summary,
        targetDirectory: bundleDirectory,
        now: config.now,
        allowedTrajectoryRoots: config.allowedTrajectoryRoots,
        environmentProvider: config.exportEnvironmentProvider,
        appVersionProvider: config.exportAppVersionProvider,
      );

      return HeadlessBenchmarkResult(
        runId: completed.runId,
        finalSummary: summary,
        exportedBundleDirectory: export.directory,
        bundleWarningCount: export.warnings.length,
        taskRunCount: summary.taskRuns.length,
        evaluationCount: summary.evaluationsByTaskRunId.values.fold<int>(
          0,
          (sum, evaluations) => sum + evaluations.length,
        ),
      );
    } finally {
      await subscription.cancel();
      await bloc.close();
    }
  }
}

String _failedComboMessage(RunInProgress state) {
  final first = state.failed.first;
  final countSuffix = state.failed.length == 1
      ? ''
      : ' (${state.failed.length} failed combos)';
  return 'Headless run failed$countSuffix: '
      '${first.label}: ${first.errorMessage}';
}
