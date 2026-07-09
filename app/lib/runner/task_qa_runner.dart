import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_integrity.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/runner/evaluator_resource_limits.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/prompt_safety.dart';
import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:dart_arena/runner/resource_enforcement_policy.dart';
import 'package:dart_arena/runner/workdir_manager.dart';

const taskQaAdmissionToolName = 'dart_arena_task_qa';
const taskQaAdmissionEvaluatorSchemaVersion = 1;
const taskQaAdmissionEvaluatorVersion = '2026-05-31-master-spec';

class TaskQaReport {
  const TaskQaReport({
    required this.taskId,
    required this.taskVersion,
    required this.baselineHiddenFailed,
    required this.referencePublicPassed,
    required this.referenceHiddenPassed,
    required this.hiddenFlakeRuns,
    required this.hiddenVerifierDigests,
    required this.negativeCaseReports,
    required this.promptSafety,
    required this.failureMessages,
    required this.baselineHiddenResults,
    required this.referencePublicResults,
    required this.referenceHiddenResults,
    this.runtimeIsolation = const TaskQaRuntimeIsolationReport(),
  });

  final String taskId;
  final int taskVersion;
  final bool baselineHiddenFailed;
  final bool referencePublicPassed;
  final bool referenceHiddenPassed;
  final int hiddenFlakeRuns;
  final Map<String, String> hiddenVerifierDigests;
  final List<TaskQaNegativeCaseReport> negativeCaseReports;
  final TaskQaPromptSafetyReport promptSafety;
  final List<String> failureMessages;
  final List<EvaluationResult> baselineHiddenResults;
  final List<EvaluationResult> referencePublicResults;
  final List<EvaluationResult> referenceHiddenResults;
  final TaskQaRuntimeIsolationReport runtimeIsolation;

  bool get referencePassed => referencePublicPassed && referenceHiddenPassed;

  bool get negativeCasesRejected =>
      negativeCaseReports.isNotEmpty &&
      negativeCaseReports.every((report) => report.rejected);

  bool get requiredNegativeCaseKindsCovered =>
      promptSafety.requiredNegativeCaseKinds.isEmpty ||
      promptSafety.missingNegativeCaseKinds.isEmpty;

  TaskQaVerifierQualityAudit get verifierQualityAudit =>
      TaskQaVerifierQualityAudit.fromReport(this);
}

class TaskQaVerifierQualityAudit {
  const TaskQaVerifierQualityAudit({
    required this.falsePositiveCount,
    required this.falseNegativeCount,
    required this.disagreementCount,
    required this.infrastructureErrorCount,
    required this.flakeRunCount,
    required this.flakeFailureCount,
    required this.negativeCaseCount,
    required this.acceptedNegativeCaseCount,
    required this.referencePublicFailureCount,
    required this.referenceHiddenFailureCount,
  });

  factory TaskQaVerifierQualityAudit.fromReport(TaskQaReport report) {
    var falsePositiveCount = 0;
    var falseNegativeCount = 0;
    var disagreementCount = 0;
    var infrastructureErrorCount = 0;
    var acceptedNegativeCaseCount = 0;

    if (!report.referencePublicPassed) {
      falseNegativeCount++;
    }
    if (!report.referenceHiddenPassed) {
      falseNegativeCount++;
    }
    if (report.referencePublicPassed != report.referenceHiddenPassed) {
      disagreementCount++;
    }

    infrastructureErrorCount += _infrastructureErrorCount(
      report.baselineHiddenResults,
    );
    infrastructureErrorCount += _infrastructureErrorCount(
      report.referencePublicResults,
    );
    infrastructureErrorCount += _infrastructureErrorCount(
      report.referenceHiddenResults,
    );

    for (final negativeCase in report.negativeCaseReports) {
      if (negativeCase.preparePassed && !negativeCase.rejected) {
        falsePositiveCount++;
        acceptedNegativeCaseCount++;
      }
      if (negativeCase.preparePassed &&
          negativeCase.publicPassed != negativeCase.hiddenPassed) {
        disagreementCount++;
      }
      infrastructureErrorCount += _infrastructureErrorCount(
        negativeCase.publicResults,
      );
      infrastructureErrorCount += _infrastructureErrorCount(
        negativeCase.hiddenResults,
      );
    }

    return TaskQaVerifierQualityAudit(
      falsePositiveCount: falsePositiveCount,
      falseNegativeCount: falseNegativeCount,
      disagreementCount: disagreementCount,
      infrastructureErrorCount: infrastructureErrorCount,
      flakeRunCount: report.hiddenFlakeRuns,
      flakeFailureCount: report.referenceHiddenPassed ? 0 : 1,
      negativeCaseCount: report.negativeCaseReports.length,
      acceptedNegativeCaseCount: acceptedNegativeCaseCount,
      referencePublicFailureCount: report.referencePublicPassed ? 0 : 1,
      referenceHiddenFailureCount: report.referenceHiddenPassed ? 0 : 1,
    );
  }

  final int falsePositiveCount;
  final int falseNegativeCount;
  final int disagreementCount;
  final int infrastructureErrorCount;
  final int flakeRunCount;
  final int flakeFailureCount;
  final int negativeCaseCount;
  final int acceptedNegativeCaseCount;
  final int referencePublicFailureCount;
  final int referenceHiddenFailureCount;

  Map<String, Object?> toJson() => {
    'falsePositiveCount': falsePositiveCount,
    'falseNegativeCount': falseNegativeCount,
    'disagreementCount': disagreementCount,
    'infrastructureErrorCount': infrastructureErrorCount,
    'flakeRunCount': flakeRunCount,
    'flakeFailureCount': flakeFailureCount,
    'flakeRate': flakeRunCount == 0 ? null : flakeFailureCount / flakeRunCount,
    'negativeCaseCount': negativeCaseCount,
    'acceptedNegativeCaseCount': acceptedNegativeCaseCount,
    'referencePublicFailureCount': referencePublicFailureCount,
    'referenceHiddenFailureCount': referenceHiddenFailureCount,
  };
}

class TaskQaRuntimeIsolationReport {
  const TaskQaRuntimeIsolationReport({
    this.generatedCodeSandboxRequired = false,
    this.generatedCodeSandboxEnforced = false,
    this.generatedCodeSandboxBackend = bubblewrapGeneratedCodeSandboxBackend,
    this.workspaces = const [],
  });

  final bool generatedCodeSandboxRequired;
  final bool generatedCodeSandboxEnforced;
  final String generatedCodeSandboxBackend;
  final List<TaskQaWorkspaceIsolationEvidence> workspaces;

  int get workspaceCount => workspaces.length;
  bool get workspaceEvidenceCollected => workspaces.isNotEmpty;
  int get visibleFileCount => workspaces.fold(
    0,
    (count, workspace) => count + workspace.visibleFileCount,
  );
  int get visibleBytes =>
      workspaces.fold(0, (count, workspace) => count + workspace.visibleBytes);
  int get restrictedPathCount => workspaces.fold(
    0,
    (count, workspace) => count + workspace.restrictedPathCount,
  );
  int get symlinkCount =>
      workspaces.fold(0, (count, workspace) => count + workspace.symlinkCount);
  int get unreadableFileCount => workspaces.fold(
    0,
    (count, workspace) => count + workspace.unreadableFileCount,
  );
  bool get workdirsUnderRunsRoot =>
      workspaces.every((workspace) => workspace.workdirUnderRunsRoot);
  bool get rootConfined =>
      workspaces.every((workspace) => workspace.rootConfined);
  bool get relativePathsOnly =>
      workspaces.every((workspace) => workspace.relativePathsOnly);
  bool get restrictedPathsAbsent =>
      workspaces.every((workspace) => workspace.restrictedPathsAbsent);
  bool get symlinksFollowed =>
      workspaces.any((workspace) => workspace.symlinksFollowed);

  String? get combinedVisibleManifestSha256 {
    if (workspaces.isEmpty) return null;
    final entries = [
      for (final workspace in workspaces)
        [
          workspace.role,
          workspace.index,
          workspace.visibleManifestSha256,
          workspace.visibleFileCount,
          workspace.visibleBytes,
          workspace.restrictedPathCount,
          workspace.symlinkCount,
          workspace.unreadableFileCount,
          workspace.workdirUnderRunsRoot,
          workspace.rootConfined,
          workspace.relativePathsOnly,
          workspace.restrictedPathsAbsent,
          workspace.symlinksFollowed,
        ].join('\u0000'),
    ];
    return sha256.convert(utf8.encode(entries.join('\n'))).toString();
  }

  Map<String, Object?> toJson() => {
    'generatedCodeSandbox': {
      'required': generatedCodeSandboxRequired,
      'enforced': generatedCodeSandboxEnforced,
      'backend': generatedCodeSandboxBackend,
    },
    'workspaceEvidence': {
      'snapshotStage': 'pre_tool_execution',
      'workspaceCount': workspaceCount,
      'visibleFileCount': visibleFileCount,
      'visibleBytes': visibleBytes,
      'combinedVisibleManifestSha256': combinedVisibleManifestSha256,
      'restrictedPathCount': restrictedPathCount,
      'symlinkCount': symlinkCount,
      'unreadableFileCount': unreadableFileCount,
      'pathGuards': {
        'workdirsUnderRunsRoot': workdirsUnderRunsRoot,
        'rootConfined': rootConfined,
        'relativePathsOnly': relativePathsOnly,
        'restrictedPathsAbsent': restrictedPathsAbsent,
        'symlinksFollowed': symlinksFollowed,
      },
      'workspaces': [for (final workspace in workspaces) workspace.toJson()],
    },
  };
}

class TaskQaWorkspaceIsolationEvidence {
  const TaskQaWorkspaceIsolationEvidence({
    required this.role,
    required this.index,
    required this.visibleFileCount,
    required this.visibleBytes,
    required this.visibleManifestSha256,
    required this.workdirUnderRunsRoot,
    required this.rootConfined,
    required this.relativePathsOnly,
    required this.restrictedPathsAbsent,
    required this.restrictedPathCount,
    required this.symlinkCount,
    required this.unreadableFileCount,
    required this.symlinksFollowed,
  });

  factory TaskQaWorkspaceIsolationEvidence.fromWorkdirEvidence({
    required String role,
    required int index,
    required WorkdirIsolationEvidence evidence,
  }) {
    return TaskQaWorkspaceIsolationEvidence(
      role: role,
      index: index,
      visibleFileCount: evidence.visibleFileCount,
      visibleBytes: evidence.visibleBytes,
      visibleManifestSha256: evidence.visibleManifestSha256,
      workdirUnderRunsRoot: evidence.workdirUnderRunsRoot,
      rootConfined: evidence.rootConfined,
      relativePathsOnly: evidence.relativePathsOnly,
      restrictedPathsAbsent: evidence.restrictedPathsAbsent,
      restrictedPathCount: evidence.restrictedPathCount,
      symlinkCount: evidence.symlinkCount,
      unreadableFileCount: evidence.unreadableFileCount,
      symlinksFollowed: evidence.symlinksFollowed,
    );
  }

  final String role;
  final int index;
  final int visibleFileCount;
  final int visibleBytes;
  final String visibleManifestSha256;
  final bool workdirUnderRunsRoot;
  final bool rootConfined;
  final bool relativePathsOnly;
  final bool restrictedPathsAbsent;
  final int restrictedPathCount;
  final int symlinkCount;
  final int unreadableFileCount;
  final bool symlinksFollowed;

  Map<String, Object?> toJson() => {
    'role': role,
    'index': index,
    'visibleFileCount': visibleFileCount,
    'visibleBytes': visibleBytes,
    'visibleManifestSha256': visibleManifestSha256,
    'workdirUnderRunsRoot': workdirUnderRunsRoot,
    'rootConfined': rootConfined,
    'relativePathsOnly': relativePathsOnly,
    'restrictedPathsAbsent': restrictedPathsAbsent,
    'restrictedPathCount': restrictedPathCount,
    'symlinkCount': symlinkCount,
    'unreadableFileCount': unreadableFileCount,
    'symlinksFollowed': symlinksFollowed,
  };
}

class TaskQaNegativeCaseReport {
  const TaskQaNegativeCaseReport({
    required this.id,
    required this.description,
    required this.kind,
    required this.preparePassed,
    required this.publicPassed,
    required this.hiddenPassed,
    required this.publicResults,
    required this.hiddenResults,
    this.error,
  });

  final String id;
  final String description;
  final TaskNegativeCaseKind kind;
  final bool preparePassed;
  final bool publicPassed;
  final bool hiddenPassed;
  final List<EvaluationResult> publicResults;
  final List<EvaluationResult> hiddenResults;
  final String? error;

  bool get rejected => preparePassed && (!publicPassed || !hiddenPassed);

  Map<String, Object?> toJson() => {
    'id': id,
    'description': description,
    'kind': kind.wireName,
    'prepare_passed': preparePassed,
    'public_passed': publicPassed,
    'hidden_passed': hiddenPassed,
    'rejected': rejected,
    if (error != null) 'error': error,
    'public_results': publicResults.map(_evaluationJson).toList(),
    'hidden_results': hiddenResults.map(_evaluationJson).toList(),
  };
}

class TaskQaPromptSafetyReport {
  const TaskQaPromptSafetyReport({
    required this.targetContextPresent,
    required this.publicTestContextPresent,
    required this.publicTestContextRequired,
    required this.implementationBodiesOmitted,
    required this.hiddenVerifierLeakFree,
    required this.referenceLeakFree,
    required this.requiredNegativeCaseKinds,
    required this.presentNegativeCaseKinds,
    required this.missingNegativeCaseKinds,
  });

  final bool targetContextPresent;
  final bool publicTestContextPresent;
  final bool publicTestContextRequired;
  final bool implementationBodiesOmitted;
  final bool hiddenVerifierLeakFree;
  final bool referenceLeakFree;
  final Set<TaskNegativeCaseKind> requiredNegativeCaseKinds;
  final Set<TaskNegativeCaseKind> presentNegativeCaseKinds;
  final Set<TaskNegativeCaseKind> missingNegativeCaseKinds;

  bool get passed =>
      targetContextPresent &&
      (!publicTestContextRequired || publicTestContextPresent) &&
      implementationBodiesOmitted &&
      hiddenVerifierLeakFree &&
      referenceLeakFree &&
      missingNegativeCaseKinds.isEmpty;

  Map<String, Object?> toJson() => {
    'target_context_present': targetContextPresent,
    'public_test_context_present': publicTestContextPresent,
    'public_test_context_required': publicTestContextRequired,
    'implementation_bodies_omitted': implementationBodiesOmitted,
    'hidden_verifier_leak_free': hiddenVerifierLeakFree,
    'reference_leak_free': referenceLeakFree,
    'required_negative_case_kinds':
        requiredNegativeCaseKinds.map((kind) => kind.wireName).toList()..sort(),
    'present_negative_case_kinds':
        presentNegativeCaseKinds.map((kind) => kind.wireName).toList()..sort(),
    'missing_negative_case_kinds':
        missingNegativeCaseKinds.map((kind) => kind.wireName).toList()..sort(),
    'passed': passed,
  };
}

class TaskQaRunner {
  TaskQaRunner({
    required this.workdirManager,
    this.evaluatorConfig = const EvaluatorConfig(),
    this.requiredHiddenFlakeRuns = 3,
    this.requireNegativeCases = false,
    this.evaluatorTimeout = const Duration(minutes: 2),
    this.allowReentrantFlutterTool = false,
    this.generatedCodeSandboxRequired = false,
    this.generatedCodeSandbox,
  });

  final WorkdirManager workdirManager;
  final EvaluatorConfig evaluatorConfig;
  final int requiredHiddenFlakeRuns;
  final bool requireNegativeCases;
  final Duration? evaluatorTimeout;
  final bool allowReentrantFlutterTool;
  final bool generatedCodeSandboxRequired;
  final GeneratedCodeSandbox? generatedCodeSandbox;

  Future<TaskQaReport> run(BenchmarkTask task) async {
    if (generatedCodeSandboxRequired && generatedCodeSandbox == null) {
      throw StateError(
        'Generated-code sandbox is required, but no sandbox backend was '
        'configured.',
      );
    }
    await task.ensureLoaded();

    final failureMessages = <String>[];
    if (task.hiddenVerifiers.isEmpty) {
      failureMessages.add('Task has no hidden verifiers.');
    }
    final referenceSolution = task.referenceSolution;
    if (referenceSolution == null) {
      failureMessages.add('Task has no executable reference solution.');
    }

    final promptSafety = _checkPromptSafety(task);
    if (!promptSafety.targetContextPresent) {
      failureMessages.add(
        'Prompt-safe target API/skeleton context is missing.',
      );
    }
    if (promptSafety.publicTestContextRequired &&
        !promptSafety.publicTestContextPresent) {
      failureMessages.add('Prompt-safe public test context is missing.');
    }
    if (!promptSafety.implementationBodiesOmitted) {
      failureMessages.add('Prompt-safe context leaks implementation bodies.');
    }
    if (!promptSafety.hiddenVerifierLeakFree) {
      failureMessages.add(
        'Task prompt or prompt-safe context leaks hidden verifier content.',
      );
    }
    if (!promptSafety.referenceLeakFree) {
      failureMessages.add(
        'Task prompt or prompt-safe context leaks reference solution content.',
      );
    }

    if (requireNegativeCases) {
      if (task.negativeCases.isEmpty) {
        failureMessages.add('Task has no verifier negative cases.');
      }
      for (final missingKind in promptSafety.missingNegativeCaseKinds) {
        failureMessages.add(
          'Task has no ${missingKind.wireName} verifier negative case.',
        );
      }
    }

    final workspaceEvidence = <TaskQaWorkspaceIsolationEvidence>[];

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
      workspaceEvidence.add(
        await _collectWorkspaceEvidence(
          role: 'baseline',
          index: 0,
          workDir: baselineDir,
        ),
      );
      final prep = await workdirManager.prepare(
        baselineDir,
        isFlutter: task.isFlutter,
        allowInternet: task.allowInternet,
        generatedCodeSandbox: generatedCodeSandbox,
        maxCpuCores: generatedCodeSandbox == null
            ? null
            : task.effectiveResourceLimits.cpus,
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
      workspaceEvidence.add(
        await _collectWorkspaceEvidence(
          role: 'reference',
          index: 0,
          workDir: referenceDir,
        ),
      );

      final prep = await workdirManager.prepare(
        referenceDir,
        isFlutter: task.isFlutter,
        allowInternet: task.allowInternet,
        generatedCodeSandbox: generatedCodeSandbox,
        maxCpuCores: generatedCodeSandbox == null
            ? null
            : task.effectiveResourceLimits.cpus,
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

    final negativeCaseReports = <TaskQaNegativeCaseReport>[];
    for (var i = 0; i < task.negativeCases.length; i++) {
      final negativeCase = task.negativeCases[i];
      final report = await _runNegativeCase(
        task,
        negativeCase,
        index: i,
        workspaceEvidence: workspaceEvidence,
      );
      negativeCaseReports.add(report);
      if (!report.preparePassed) {
        failureMessages.add(
          'Negative case ${negativeCase.id} was invalid: '
          '${report.error ?? 'prepare failed without details'}.',
        );
      } else if (!report.rejected) {
        failureMessages.add(
          'Negative case ${negativeCase.id} was accepted by verifiers.',
        );
      }
    }

    final runtimeIsolation = TaskQaRuntimeIsolationReport(
      generatedCodeSandboxRequired: generatedCodeSandboxRequired,
      generatedCodeSandboxEnforced: generatedCodeSandbox != null,
      generatedCodeSandboxBackend:
          generatedCodeSandbox?.backend ??
          bubblewrapGeneratedCodeSandboxBackend,
      workspaces: List.unmodifiable(workspaceEvidence),
    );
    if (!runtimeIsolation.restrictedPathsAbsent) {
      failureMessages.add(
        'Workspace isolation evidence found '
        '${runtimeIsolation.restrictedPathCount} restricted path(s) in '
        'solver workspaces.',
      );
    }

    return TaskQaReport(
      taskId: task.id,
      taskVersion: task.version,
      baselineHiddenFailed: baselineHiddenFailed,
      referencePublicPassed: referencePublicPassed,
      referenceHiddenPassed: referenceHiddenPassed,
      hiddenFlakeRuns: hiddenFlakeRuns,
      hiddenVerifierDigests: Map.unmodifiable(hiddenVerifierDigests(task)),
      negativeCaseReports: List.unmodifiable(negativeCaseReports),
      promptSafety: promptSafety,
      failureMessages: List.unmodifiable(failureMessages),
      baselineHiddenResults: List.unmodifiable(baselineHiddenResults),
      referencePublicResults: List.unmodifiable(referencePublicResults),
      referenceHiddenResults: List.unmodifiable(referenceHiddenResults),
      runtimeIsolation: runtimeIsolation,
    );
  }

  Future<TaskQaNegativeCaseReport> _runNegativeCase(
    BenchmarkTask task,
    TaskNegativeCase negativeCase, {
    required int index,
    required List<TaskQaWorkspaceIsolationEvidence> workspaceEvidence,
  }) async {
    final dir = await workdirManager.createTaskWorkdir(
      runId: 'qa-negative-${task.id}-${negativeCase.id}',
      providerId: 'task_qa',
      modelId: negativeCase.id,
      taskId: task.id,
      fixtures: task.fixtures,
      generatedCode: null,
      generatedCodePath: task.generatedCodePath,
    );
    var evidenceCollected = false;
    Future<void> collectEvidence() async {
      if (evidenceCollected) return;
      workspaceEvidence.add(
        await _collectWorkspaceEvidence(
          role: 'negative_case',
          index: index,
          workDir: dir,
        ),
      );
      evidenceCollected = true;
    }

    try {
      await applyReferenceSolution(dir, negativeCase.solution);
    } on Object catch (e) {
      await collectEvidence();
      return TaskQaNegativeCaseReport(
        id: negativeCase.id,
        description: negativeCase.description,
        kind: negativeCase.kind,
        preparePassed: false,
        publicPassed: false,
        hiddenPassed: false,
        publicResults: const [],
        hiddenResults: const [],
        error: 'Negative case solution failed to apply: $e',
      );
    }

    await collectEvidence();
    final prep = await workdirManager.prepare(
      dir,
      isFlutter: task.isFlutter,
      allowInternet: task.allowInternet,
      generatedCodeSandbox: generatedCodeSandbox,
      maxCpuCores: generatedCodeSandbox == null
          ? null
          : task.effectiveResourceLimits.cpus,
    );
    if (prep is PrepareFailed) {
      return TaskQaNegativeCaseReport(
        id: negativeCase.id,
        description: negativeCase.description,
        kind: negativeCase.kind,
        preparePassed: false,
        publicPassed: false,
        hiddenPassed: false,
        publicResults: const [],
        hiddenResults: const [],
        error: 'Negative case prepare failed: ${prep.stderr}',
      );
    }

    final publicResults = await _runPublicEvaluators(task, dir);
    if (publicResults.any((result) => !result.passed)) {
      return TaskQaNegativeCaseReport(
        id: negativeCase.id,
        description: negativeCase.description,
        kind: negativeCase.kind,
        preparePassed: true,
        publicPassed: false,
        hiddenPassed: false,
        publicResults: List.unmodifiable(publicResults),
        hiddenResults: const [],
      );
    }

    final hiddenResults = await _runHiddenVerifiers(task, dir);
    return TaskQaNegativeCaseReport(
      id: negativeCase.id,
      description: negativeCase.description,
      kind: negativeCase.kind,
      preparePassed: true,
      publicPassed: publicResults.every((r) => r.passed),
      hiddenPassed: hiddenResults.every((r) => r.passed),
      publicResults: List.unmodifiable(publicResults),
      hiddenResults: List.unmodifiable(hiddenResults),
    );
  }

  Future<TaskQaWorkspaceIsolationEvidence> _collectWorkspaceEvidence({
    required String role,
    required int index,
    required Directory workDir,
  }) async {
    final evidence = await workdirManager.collectWorkspaceIsolationEvidence(
      workDir,
    );
    return TaskQaWorkspaceIsolationEvidence.fromWorkdirEvidence(
      role: role,
      index: index,
      evidence: evidence,
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
    final evaluators = task.hiddenVerifiers.map(
      (verifier) => HiddenTestEvaluator(verifier, timeout: evaluatorTimeout),
    );
    return _runEvaluators(task, workDir, evaluators);
  }

  Future<List<EvaluationResult>> _runEvaluators(
    BenchmarkTask task,
    Directory workDir,
    Iterable<Evaluator> evaluators,
  ) async {
    final results = <EvaluationResult>[];
    for (final evaluator in evaluators.map((e) => _qaEvaluator(task, e))) {
      final blocked = blockedEvaluationFor(
        evaluatorId: evaluator.id,
        previousResults: results,
      );
      if (blocked != null) {
        results.add(blocked);
        continue;
      }
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
            previousResults: results,
            deniedEnvironmentKeys: workdirManager.deniedEnvironmentKeys,
            allowReentrantFlutterTool: allowReentrantFlutterTool,
            generatedCodeSandbox: generatedCodeSandbox,
          ),
        ),
      );
    }
    return results;
  }

  Evaluator _qaEvaluator(BenchmarkTask task, Evaluator evaluator) {
    final qaEvaluator = switch (evaluator) {
      TestEvaluator(
        :final testPath,
        :final maxOutputChars,
        :final maxProcesses,
        :final maxMemoryMb,
        :final dartExecutable,
        :final flutterExecutable,
      ) =>
        TestEvaluator(
          testPath: testPath,
          timeout: evaluatorTimeout,
          maxOutputChars: maxOutputChars,
          maxProcesses: maxProcesses,
          maxMemoryMb: maxMemoryMb,
          dartExecutable: dartExecutable,
          flutterExecutable: flutterExecutable,
        ),
      HiddenTestEvaluator(
        :final verifier,
        :final maxOutputChars,
        :final maxProcesses,
        :final maxMemoryMb,
      ) =>
        HiddenTestEvaluator(
          verifier,
          timeout: evaluatorTimeout,
          maxOutputChars: maxOutputChars,
          maxProcesses: maxProcesses,
          maxMemoryMb: maxMemoryMb,
        ),
      _ => evaluator,
    };
    return applyResourceLimitsToEvaluator(
      qaEvaluator,
      task.effectiveResourceLimits,
    );
  }

  TaskQaPromptSafetyReport _checkPromptSafety(BenchmarkTask task) {
    final targetContext = buildPromptSafeTargetContext(
      targetPath: task.generatedCodePath,
      fixtures: task.fixtures,
    );
    final publicTestContext = buildPublicTestFixtureContext(
      fixtures: task.fixtures,
    );
    final promptSafeContext = [
      targetContext,
      publicTestContext,
    ].whereType<String>().join('\n');
    final visiblePromptContext = buildPromptSafetyVisibleContext(
      task: task,
      promptSafeContext: promptSafeContext,
    );
    final targetSource = task.fixtures[task.generatedCodePath]?.trim();
    final publicTestContextRequired = _hasPublicTestFixtures(task.fixtures);
    final requiredKinds = task.requiredNegativeCaseKinds;
    final presentKinds = task.negativeCases
        .map((negative) => negative.kind)
        .toSet();
    final leakScan = scanPromptSafetyLeaks(
      visiblePromptContext: visiblePromptContext,
      task: task,
    );

    return TaskQaPromptSafetyReport(
      targetContextPresent: targetContext != null && targetContext.isNotEmpty,
      publicTestContextPresent:
          publicTestContext != null && publicTestContext.isNotEmpty,
      publicTestContextRequired: publicTestContextRequired,
      implementationBodiesOmitted:
          targetSource != null &&
          targetSource.isNotEmpty &&
          targetContext != null &&
          !targetContext.contains(targetSource),
      hiddenVerifierLeakFree: !leakScan.hiddenVerifierLeak,
      referenceLeakFree: !leakScan.referenceLeak,
      requiredNegativeCaseKinds: Set.unmodifiable(requiredKinds),
      presentNegativeCaseKinds: Set.unmodifiable(presentKinds),
      missingNegativeCaseKinds: Set.unmodifiable(
        requiredKinds.difference(presentKinds),
      ),
    );
  }
}

bool _hasPublicTestFixtures(Map<String, String> fixtures) {
  return fixtures.keys.any((path) {
    final normalized = path.replaceAll('\\', '/');
    if (!normalized.startsWith('test/') || !normalized.endsWith('.dart')) {
      return false;
    }
    final segments = normalized.split('/');
    return !segments.any(
      (segment) =>
          segment == '_hidden' ||
          segment == 'hidden' ||
          segment == '_reference' ||
          segment == 'reference',
    );
  });
}

int _infrastructureErrorCount(Iterable<EvaluationResult> results) {
  return results.where(_isInfrastructureError).length;
}

bool _isInfrastructureError(EvaluationResult result) {
  if (result.passed) return false;
  final evaluatorId = result.evaluatorId.toLowerCase();
  if (evaluatorId == 'environment' ||
      evaluatorId == 'environment_error' ||
      evaluatorId == 'infrastructure' ||
      evaluatorId == 'infrastructure_error') {
    return true;
  }
  final detailValues = result.details.entries
      .map((entry) => '${entry.key} ${entry.value}'.toLowerCase())
      .join(' ');
  final evidence = '${result.rationale ?? ''} $detailValues'.toLowerCase();
  return evidence.contains('environment_error') ||
      evidence.contains('infrastructure_error') ||
      evidence.contains('prepare failed') ||
      evidence.contains('tool unavailable') ||
      evidence.contains('process failed');
}

Map<String, Object?> _evaluationJson(EvaluationResult result) => {
  'evaluator_id': result.evaluatorId,
  'passed': result.passed,
  'score': result.score,
  if (result.rationale != null) 'rationale': result.rationale,
  if (result.details.isNotEmpty) 'details': result.details,
};

bool taskQaAdmissionPassed(TaskQaReport report) =>
    report.failureMessages.isEmpty;

Map<String, Object?> taskQaAdmissionReportJson({
  required BenchmarkTask task,
  required TaskQaReport report,
  DateTime? generatedAt,
  Map<String, Object?>? environment,
}) {
  final checks = <String, Object?>{
    'baselineHiddenFailed': report.baselineHiddenFailed,
    'referencePublicPassed': report.referencePublicPassed,
    'referenceHiddenPassed': report.referenceHiddenPassed,
    'negativeCasesRejected': report.negativeCasesRejected,
    'requiredNegativeCaseKindsCovered': report.requiredNegativeCaseKindsCovered,
    'hiddenFlakeRuns': report.hiddenFlakeRuns,
    'promptSafeContextLeakFree': report.promptSafety.passed,
    'generatedCodeSandboxRequired':
        report.runtimeIsolation.generatedCodeSandboxRequired,
    'generatedCodeSandboxEnforced':
        report.runtimeIsolation.generatedCodeSandboxEnforced,
    'workspaceEvidenceCollected':
        report.runtimeIsolation.workspaceEvidenceCollected,
    'workspaceRestrictedPathsAbsent':
        report.runtimeIsolation.restrictedPathsAbsent,
  };
  _addNegativeKindCheck(
    checks,
    label: 'noopRejected',
    kind: TaskNegativeCaseKind.noop,
    report: report,
  );
  _addNegativeKindCheck(
    checks,
    label: 'apiBreakingRejected',
    kind: TaskNegativeCaseKind.apiBreaking,
    report: report,
  );
  _addNegativeKindCheck(
    checks,
    label: 'overfitRejected',
    kind: TaskNegativeCaseKind.overfit,
    report: report,
  );

  return {
    'schemaVersion': 1,
    'taskId': report.taskId,
    'taskVersion': report.taskVersion,
    'category': task.category.name,
    'difficulty': task.difficulty.name,
    'track': task.track.name,
    'tags': task.tags.map((tag) => tag.slug).toList()..sort(),
    'release': task.releaseMetadata.toJson(),
    'admission': {
      'tool': {'name': taskQaAdmissionToolName},
      'evaluator': {
        'schemaVersion': taskQaAdmissionEvaluatorSchemaVersion,
        'version': taskQaAdmissionEvaluatorVersion,
      },
      if (environment != null) 'environment': _sortedObjectMap(environment),
    },
    'executionPolicy': {
      'allowInternet': task.allowInternet,
      'resources': task.effectiveResourceLimits.toJson(),
      'resourceEnforcement': taskResourceEnforcementJson(),
    },
    'runtimeIsolation': report.runtimeIsolation.toJson(),
    'status': taskQaAdmissionPassed(report) ? 'admitted' : 'rejected',
    if (generatedAt != null) 'generatedAt': generatedAt.toIso8601String(),
    'checks': checks,
    'hiddenVerifierDigests': report.hiddenVerifierDigests,
    'verifierQualityAudit': report.verifierQualityAudit.toJson(),
    'promptSafety': report.promptSafety.toJson(),
    'negativeCases': [
      for (final negativeCase in report.negativeCaseReports)
        negativeCase.toJson(),
    ],
    'failureMessages': report.failureMessages,
  };
}

Map<String, Object?> _sortedObjectMap(Map<String, Object?> value) {
  final keys = value.keys.toList()..sort();
  return {for (final key in keys) key: value[key]};
}

void _addNegativeKindCheck(
  Map<String, Object?> checks, {
  required String label,
  required TaskNegativeCaseKind kind,
  required TaskQaReport report,
}) {
  final required = report.promptSafety.requiredNegativeCaseKinds.contains(kind);
  final cases = report.negativeCaseReports
      .where((negativeCase) => negativeCase.kind == kind)
      .toList(growable: false);
  if (!required && cases.isEmpty) return;
  checks[label] =
      cases.isNotEmpty && cases.every((negative) => negative.rejected);
}
