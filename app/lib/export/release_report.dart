import 'dart:collection';

import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/core/task_bundle_digest.dart';
import 'package:dart_arena/core/model_identity.dart';
import 'package:dart_arena/export/environment_compatibility.dart';

const _standardBundleFilePaths = [
  'report.md',
  'results.csv',
  'run_results.v1.json',
];

const _requiredArtifactBundleChecksumPaths = [
  'manifest.json',
  ..._standardBundleFilePaths,
];

const _artifactBundleManifestSchemaVersions = {1, 2};
const _artifactBundleChecksumsSchemaVersion = 1;
const _artifactRunResultsSchemaVersion = 1;
const _taskQaSummarySchemaVersion = 1;
const _taskQaReportSchemaVersion = 1;
const _requiredScoringSchemaVersion = 2;
const _requiredBenchmarkEvaluatorSchemaVersion = 2;
const _requiredDiffSizePolicy = 'diagnostic_only_full_patch';
const _diffSizeEvaluatorId = 'diff_size';
const _requiredTaskQaAdmissionEvaluatorSchemaVersion = 2;
final _artifactBundleWarningCodePattern = RegExp(
  r'^[a-z0-9][a-z0-9_.-]{0,95}$',
);
const _taskQaAdmissionToolName = 'dart_arena_task_qa';
const _allowedArtifactBundleKinds = {'patch', 'response', 'trajectory'};
const _requiredTaskQaAdmissionChecks = [
  'baselineHiddenFailed',
  'referencePublicPassed',
  'referenceHiddenPassed',
  'negativeCasesRejected',
  'requiredNegativeCaseKindsCovered',
  'promptSafeContextLeakFree',
];
const _optionalTaskQaAdmissionChecks = [
  'noopRejected',
  'apiBreakingRejected',
  'overfitRejected',
];
const _allowedTaskQaNegativeCaseKinds = {
  'noop',
  'api_breaking',
  'overfit',
  'minimal_bad',
  'custom',
};
const _requiredTaskQaPromptSafetyBooleanFields = [
  'target_context_present',
  'public_test_context_present',
  'public_test_context_required',
  'implementation_bodies_omitted',
  'hidden_verifier_leak_free',
  'reference_leak_free',
];
const _requiredTaskQaVerifierQualityFields = [
  'falsePositiveCount',
  'falseNegativeCount',
  'disagreementCount',
  'infrastructureErrorCount',
  'flakeRunCount',
  'flakeFailureCount',
  'negativeCaseCount',
  'acceptedNegativeCaseCount',
  'referencePublicFailureCount',
  'referenceHiddenFailureCount',
];
final _appVersionPattern = RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$');
final _gitCommitPattern = RegExp(r'^[0-9a-f]{40}$');
final _sha256DigestPattern = RegExp(r'^[0-9a-f]{64}$');
final _artifactIdPattern = RegExp(r'^artifact_[0-9a-f]{16}$');
final _windowsAbsolutePathPattern = RegExp(r'^[A-Za-z]:/');
const _allowedRunResultsEvaluationStatuses = {
  'passed',
  'failed',
  'blocked',
  'ignored',
  'skipped',
};
const _requiredResultsCsvColumns = {
  'run_id',
  'task_id',
  'provider_id',
  'model_id',
  'trial_index',
  'task_version',
  'benchmark_track',
  'primary_pass',
  'failure_tag',
  'aggregate_score',
};
const _requiredReportMarkdownTaskColumns = {
  'Task',
  'Provider',
  'Model',
  'Trial',
  'Task Version',
  'Track',
  'Primary Pass',
  'Failure',
  'Aggregate',
};

class ReleaseReportOptions {
  const ReleaseReportOptions({
    required this.releaseId,
    this.minSamplesPerModel = 2,
    this.minHiddenFlakeRunsPerTask = 3,
    this.allowMixedEnvironmentAggregates = false,
  });

  final String releaseId;
  final int minSamplesPerModel;
  final int minHiddenFlakeRunsPerTask;

  /// Explicit policy escape hatch: permits aggregates spanning multiple
  /// execution environments (environment IDs, Dart/Flutter versions).
  final bool allowMixedEnvironmentAggregates;
}

class ReleaseArtifactBundleInput {
  const ReleaseArtifactBundleInput({
    required this.manifest,
    required this.checksums,
    required this.runResults,
    required this.resultsCsv,
    required this.reportMarkdown,
    required this.manifestInput,
    required this.checksumsInput,
    required this.runResultsInput,
    required this.resultsCsvInput,
    required this.reportInput,
    required this.artifactFileInputs,
    this.rootInput,
  });

  final Map<String, Object?> manifest;
  final Map<String, Object?> checksums;
  final Map<String, Object?> runResults;
  final String resultsCsv;
  final String reportMarkdown;
  final Map<String, Object?> manifestInput;
  final Map<String, Object?> checksumsInput;
  final Map<String, Object?> runResultsInput;
  final Map<String, Object?> resultsCsvInput;
  final Map<String, Object?> reportInput;
  final Map<String, Map<String, Object?>> artifactFileInputs;
  final Map<String, Object?>? rootInput;

  Map<String, Object?> toInputJson() => {
    if (rootInput != null) 'root': rootInput,
    'artifactManifest': manifestInput,
    'artifactChecksums': checksumsInput,
    'artifactRunResults': runResultsInput,
    'artifactResultsCsv': resultsCsvInput,
    'artifactReport': reportInput,
    'artifactFiles': artifactFileInputs.values.toList(),
  };
}

Map<String, Object?> buildReleaseReport({
  required Map<String, Object?> leaderboard,
  required Map<String, Object?> taskQaSummary,
  required List<Map<String, Object?>> taskQaReports,
  List<Map<String, Object?>> taskBundleDigestEvidence = const [],
  required ReleaseReportOptions options,
  Map<String, Map<String, Object?>>? runProvenanceById,
  List<String> taskQaReportReadErrors = const [],
  Map<String, Object?>? artifactManifest,
  Map<String, Object?>? artifactChecksums,
  Map<String, Object?>? artifactRunResults,
  String? artifactResultsCsv,
  String? artifactReport,
  List<ReleaseArtifactBundleInput> artifactBundles = const [],
  Map<String, Object?>? inputs,
  DateTime Function()? now,
}) {
  final generatedAt = (now ?? DateTime.now)().toUtc();
  final blockers = <String>{};
  final warnings = <String>{};

  final benchmark = _objectMap(leaderboard['benchmark']);
  final source = _objectMap(leaderboard['source']);
  final modelRows = _objectMaps(leaderboard['models']);
  final taskRows = _objectMaps(leaderboard['tasks']);
  final taskModelCells = _objectMaps(leaderboard['taskModelCells']);
  final trialSummaries = _objectMaps(leaderboard['trialSummaries']);
  final sourceWarnings = _stringList(source['warnings']);
  final runIds = _stringList(source['runIds']);
  warnings.addAll(sourceWarnings);

  if (benchmark['dataPolicy'] != 'aggregate-compatible') {
    blockers.add(
      'Leaderboard dataPolicy must be aggregate-compatible for an official release.',
    );
  }
  final benchmarkVersion = _nonEmptyString(benchmark['version']);
  final taskSetId = _nonEmptyString(benchmark['taskSetId']);
  final evaluatorSchemaVersion = _intValue(benchmark['evaluatorSchemaVersion']);
  if (benchmarkVersion == null) {
    blockers.add('Leaderboard benchmark version metadata is missing.');
  }
  if (taskSetId == null) {
    blockers.add('Leaderboard benchmark task set id metadata is missing.');
  }
  final preset = _nonEmptyString(benchmark['preset']);
  final corpusManifestDigest = _nonEmptyString(
    benchmark['corpusManifestDigestSha256'],
  );
  final selectedTasks = benchmark['selectedTasks'];
  final digestIsSha256 =
      corpusManifestDigest != null &&
      RegExp(r'^[0-9a-f]{64}$').hasMatch(corpusManifestDigest);
  if (preset == null ||
      !digestIsSha256 ||
      selectedTasks is! List ||
      selectedTasks.isEmpty) {
    blockers.add(
      'Leaderboard is missing the frozen corpus manifest; run with --preset to '
      'snapshot the corpus before an official release.',
    );
  }
  _validateFrozenCorpusManifest(
    selectedTasks: selectedTasks,
    corpusManifestDigest: corpusManifestDigest,
    taskRows: taskRows,
    blockers: blockers,
  );
  if (evaluatorSchemaVersion <= 0) {
    blockers.add(
      'Leaderboard benchmark evaluator schema version metadata is missing.',
    );
  } else if (evaluatorSchemaVersion <
      _requiredBenchmarkEvaluatorSchemaVersion) {
    blockers.add('Leaderboard benchmark evaluator schema version is stale.');
  }

  final taskRunCount = _intValue(source['taskRunCount']);
  if (taskRunCount == 0) {
    blockers.add('No completed leaderboard task runs are available.');
  }
  final judgeOverhead = _judgeOverheadSummary(source, blockers);
  final scoring = _scoringSummary(leaderboard, blockers);
  final sourceRunProvenance = _sourceRunProvenanceSummary(
    source: source,
    runIds: runIds,
    blockers: blockers,
    reportWarnings: warnings,
    allowMixedEnvironmentAggregates: options.allowMixedEnvironmentAggregates,
  );
  final taskModelCellSummary = _taskModelCellSummary(
    rawCells: leaderboard['taskModelCells'],
    cells: taskModelCells,
    modelRows: modelRows,
    taskRows: taskRows,
    blockers: blockers,
    warnings: warnings,
  );
  final modelIdentity = _modelIdentitySummary(
    modelRows: modelRows,
    taskModelCells: taskModelCells,
    trialSummaries: trialSummaries,
    blockers: blockers,
  );
  final trialTransparency = _trialTransparencySummary(
    source: source,
    rawTrialSummaries: leaderboard['trialSummaries'],
    trialSummaries: trialSummaries,
    taskRunCount: taskRunCount,
    modelRows: modelRows,
    taskRows: taskRows,
    taskModelCells: taskModelCells,
    blockers: blockers,
    warnings: warnings,
  );
  final privacy = _publicLeaderboardPrivacyAudit(
    leaderboard: leaderboard,
    blockers: blockers,
  );
  final releaseInputs = inputs ?? const <String, Object?>{};
  final artifactBundleInputs = artifactBundles.isNotEmpty
      ? artifactBundles
      : _singleArtifactBundleInput(
          manifest: artifactManifest,
          checksums: artifactChecksums,
          runResults: artifactRunResults,
          resultsCsv: artifactResultsCsv,
          reportMarkdown: artifactReport,
          releaseInputs: releaseInputs,
        );
  final artifactBundle = _artifactBundleReadinessSummary(
    artifactBundles: artifactBundleInputs,
    reportGeneratedAt: generatedAt,
    sourceRunIds: runIds,
    leaderboardTrialSummaries: trialSummaries,
    blockers: blockers,
  );

  final lowSampleModels = <Map<String, Object?>>[];
  final unknownCostModels = <Map<String, Object?>>[];
  for (final model in modelRows) {
    final modelKey = _modelKey(model);
    final sampleCount = _intValue(model['sampleCount']);
    if (sampleCount < options.minSamplesPerModel) {
      lowSampleModels.add({
        'providerId': model['providerId'],
        'modelId': model['modelId'],
        'sampleCount': sampleCount,
      });
      blockers.add(
        'Model $modelKey has $sampleCount sample(s), below the required '
        '${options.minSamplesPerModel}.',
      );
    }
    final unknownCostCount = _intValue(model['unknownEstimatedCostCount']);
    if (unknownCostCount > 0) {
      unknownCostModels.add({
        'providerId': model['providerId'],
        'modelId': model['modelId'],
        'unknownEstimatedCostCount': unknownCostCount,
      });
      warnings.add(
        'Model $modelKey has $unknownCostCount sample(s) without known cost.',
      );
    }
  }

  final taskQa = _taskQaSummary(
    taskQaSummary,
    taskQaReports,
    taskRows,
    taskQaReportReadErrors,
    blockers,
    reportGeneratedAt: generatedAt,
  );
  final verifierAudit = _verifierAudit(
    taskQaReports,
    blockers,
    taskBundleDigestEvidence: taskBundleDigestEvidence,
    minHiddenFlakeRunsPerTask: options.minHiddenFlakeRunsPerTask,
    reportGeneratedAt: generatedAt,
  );

  final provenance = _provenanceSummary(
    runIds: runIds,
    runProvenanceById: runProvenanceById,
    taskBundleDigestEvidence: taskBundleDigestEvidence,
    blockers: blockers,
  );
  if (runProvenanceById != null) {
    _crossCheckSourceRunProvenance(
      sourceRunProvenance: sourceRunProvenance,
      storedRunProvenance: provenance,
      blockers: blockers,
    );
  }
  final readinessGates = _readinessGates(
    taskQa: taskQa,
    verifierAudit: verifierAudit,
    sourceRunProvenance: sourceRunProvenance,
    storedRunProvenance: provenance,
    scoring: scoring,
    lowSampleModels: lowSampleModels,
    judgeOverhead: judgeOverhead,
    taskModelCells: taskModelCellSummary,
    modelIdentity: modelIdentity,
    trialTransparency: trialTransparency,
    privacy: privacy,
    artifactBundle: artifactBundle,
    inputs: inputs,
  );

  return {
    'schemaVersion': 2,
    'releaseId': options.releaseId,
    'generatedAt': generatedAt.toIso8601String(),
    'status': blockers.isEmpty ? 'ready' : 'blocked',
    'blockers': blockers.toList()..sort(),
    'warnings': warnings.toList()..sort(),
    'readinessGates': readinessGates,
    if (inputs != null) 'inputs': inputs,
    'leaderboard': {
      'benchmark': {
        'name': benchmark['name'],
        'brand': benchmark['brand'],
        'title': benchmark['title'],
        'version': benchmarkVersion,
        'taskSetId': taskSetId,
        'evaluatorSchemaVersion': evaluatorSchemaVersion,
        'track': benchmark['track'],
        'dataPolicy': benchmark['dataPolicy'],
        'preset': benchmark['preset'],
        'selectedTasks': benchmark['selectedTasks'],
        'corpusManifestDigestSha256': benchmark['corpusManifestDigestSha256'],
      },
      'source': {
        'anchorRunId': source['anchorRunId'],
        'runIds': runIds,
        'taskCount': _intValue(source['taskCount']),
        'taskRunCount': taskRunCount,
        'modelCount': _intValue(source['modelCount']),
        'warningCount': sourceWarnings.length,
        'judgeOverhead': judgeOverhead,
        'runProvenance': sourceRunProvenance,
      },
      'scoring': scoring,
      'modelCount': modelRows.length,
      'taskCount': taskRows.length,
      'taskModelCells': taskModelCellSummary,
      'modelIdentity': modelIdentity,
      'trialTransparency': trialTransparency,
      'privacy': privacy,
      'lowSampleModels': lowSampleModels,
      'unknownCostModels': unknownCostModels,
    },
    'taskQa': taskQa,
    'verifierAudit': verifierAudit,
    'provenance': provenance,
    'artifactBundle': artifactBundle,
  };
}

Map<String, Object?> _readinessGates({
  required Map<String, Object?> taskQa,
  required Map<String, Object?> verifierAudit,
  required Map<String, Object?> sourceRunProvenance,
  required Map<String, Object?> storedRunProvenance,
  required Map<String, Object?> scoring,
  required List<Map<String, Object?>> lowSampleModels,
  required Map<String, Object?> judgeOverhead,
  required Map<String, Object?> taskModelCells,
  required Map<String, Object?> modelIdentity,
  required Map<String, Object?> trialTransparency,
  required Map<String, Object?> privacy,
  required Map<String, Object?> artifactBundle,
  required Map<String, Object?>? inputs,
}) {
  return {
    'corpus': _corpusReadinessGate(
      taskQa: taskQa,
      verifierAudit: verifierAudit,
    ),
    'execution': _executionReadinessGate(
      sourceRunProvenance: sourceRunProvenance,
      storedRunProvenance: storedRunProvenance,
    ),
    'scoring': _scoringReadinessGate(
      scoring: scoring,
      lowSampleModels: lowSampleModels,
    ),
    'reporting': _reportingReadinessGate(
      judgeOverhead: judgeOverhead,
      taskModelCells: taskModelCells,
      modelIdentity: modelIdentity,
      trialTransparency: trialTransparency,
      privacy: privacy,
      artifactBundle: artifactBundle,
      inputs: inputs,
    ),
  };
}

Map<String, Object?> _corpusReadinessGate({
  required Map<String, Object?> taskQa,
  required Map<String, Object?> verifierAudit,
}) {
  final taskCount = _intValue(taskQa['taskCount']);
  final leaderboardTaskCount = _intValue(taskQa['leaderboardTaskCount']);
  final coveredLeaderboardTaskCount = _intValue(
    taskQa['coveredLeaderboardTaskCount'],
  );
  final missingLeaderboardTaskQaCount = _intValue(
    taskQa['missingLeaderboardTaskQaCount'],
  );
  final extraTaskQaReportCount = _intValue(taskQa['extraTaskQaReportCount']);
  final invalidLeaderboardTaskRowCount = _intValue(
    taskQa['invalidLeaderboardTaskRowCount'],
  );
  final invalidTaskQaReportRowCount = _intValue(
    taskQa['invalidTaskQaReportRowCount'],
  );
  final summaryIntegrity = _objectMap(taskQa['summaryIntegrity']);
  final summaryIntegrityStatus = summaryIntegrity['status'];
  final invalidSummaryReportEntryCount = _intValue(
    summaryIntegrity['invalidReportEntryCount'],
  );
  final reportPathAudit = _objectMap(taskQa['reportPathAudit']);
  final summaryReportConsistency = _objectMap(
    taskQa['summaryReportConsistency'],
  );
  final matchedSummaryReportCount = _intValue(
    summaryReportConsistency['matchedReportCount'],
  );
  final missingLoadedReportForSummaryCount = _intValue(
    summaryReportConsistency['missingLoadedReportCount'],
  );
  final unreferencedLoadedReportCount = _intValue(
    summaryReportConsistency['unreferencedLoadedReportCount'],
  );
  final duplicateSummaryReportKeyCount = _intValue(
    summaryReportConsistency['duplicateSummaryReportKeyCount'],
  );
  final duplicateLoadedReportKeyCount = _intValue(
    summaryReportConsistency['duplicateLoadedReportKeyCount'],
  );
  final invalidSummaryFailureCountCount = _intValue(
    summaryReportConsistency['invalidFailureCountCount'],
  );
  final summaryReportStatusMismatchCount = _intValue(
    summaryReportConsistency['statusMismatchCount'],
  );
  final summaryReportFailureCountMismatchCount = _intValue(
    summaryReportConsistency['failureCountMismatchCount'],
  );
  final summaryReportGeneratedAfterSummaryCount = _intValue(
    summaryReportConsistency['reportGeneratedAfterSummaryCount'],
  );
  final missingReportPathCount = _intValue(
    reportPathAudit['missingReportPathCount'],
  );
  final absoluteReportPathCount = _intValue(
    reportPathAudit['absoluteReportPathCount'],
  );
  final parentReportPathCount = _intValue(
    reportPathAudit['parentReportPathCount'],
  );
  final malformedReportPathCount = _intValue(
    reportPathAudit['malformedReportPathCount'],
  );
  final outsideTaskQaRootReportPathCount = _intValue(
    reportPathAudit['outsideTaskQaRootReportPathCount'],
  );
  final unsafeReportPathCount = _intValue(
    reportPathAudit['unsafeReportPathCount'],
  );
  final loadedReportCount = _intValue(taskQa['loadedReportCount']);
  final rejectedTaskCount = _intValue(taskQa['rejectedTaskCount']);
  final reportReadErrorCount = _stringList(taskQa['reportReadErrors']).length;
  final hiddenVerifierDigestCount = _intValue(
    verifierAudit['hiddenVerifierDigestCount'],
  );
  final missingHiddenVerifierDigestCount = _objectMaps(
    verifierAudit['tasksMissingHiddenVerifierDigests'],
  ).length;
  final invalidHiddenVerifierDigestCount = _intValue(
    verifierAudit['invalidHiddenVerifierDigestCount'],
  );
  final negativeCases = _objectMap(verifierAudit['negativeCases']);
  final negativeCaseCount = _intValue(negativeCases['total']);
  final acceptedNegativeCaseCount = _intValue(negativeCases['accepted']);
  final invalidNegativeCaseCount = _intValue(negativeCases['invalid']);
  final malformedNegativeCaseEvidenceCount = _intValue(
    negativeCases['malformedEvidenceCount'],
  );
  final unsupportedNegativeCaseKindCount = _intValue(
    negativeCases['unsupportedKindCount'],
  );
  final negativeCaseOutcomeMismatchCount = _intValue(
    negativeCases['outcomeMismatchCount'],
  );
  final tasksMissingNegativeCaseCount = _objectMaps(
    negativeCases['tasksMissingNegativeCases'],
  ).length;
  final releaseMetadata = _objectMap(verifierAudit['releaseMetadata']);
  final privateOfficialTaskCount = _intValue(
    releaseMetadata['privateOfficialTaskCount'],
  );
  final activeTaskCount = _intValue(releaseMetadata['activeTaskCount']);
  final tasksMissingReleaseMetadataCount = _objectMaps(
    releaseMetadata['tasksMissingReleaseMetadata'],
  ).length;
  final tasksOutsidePrivateOfficialCorpusCount = _objectMaps(
    releaseMetadata['tasksOutsidePrivateOfficialCorpus'],
  ).length;
  final retiredTaskCount = _objectMaps(releaseMetadata['retiredTasks']).length;
  final quality = _objectMap(verifierAudit['quality']);
  final falsePositiveCount = _intValue(quality['falsePositiveCount']);
  final falseNegativeCount = _intValue(quality['falseNegativeCount']);
  final disagreementCount = _intValue(quality['disagreementCount']);
  final infrastructureErrorCount = _intValue(
    quality['infrastructureErrorCount'],
  );
  final flakeRunCount = _intValue(quality['flakeRunCount']);
  final flakeFailureCount = _intValue(quality['flakeFailureCount']);
  final hiddenFlakeRuns = _objectMap(verifierAudit['hiddenFlakeRuns']);
  final minHiddenFlakeRunsPerTask = _intValue(
    hiddenFlakeRuns['minimumPerTask'],
  );
  final tasksBelowHiddenFlakeRunMinimumCount = _objectMaps(
    hiddenFlakeRuns['tasksBelowMinimum'],
  ).length;
  final qualityAcceptedNegativeCaseCount = _intValue(
    quality['acceptedNegativeCaseCount'],
  );
  final missingVerifierQualityAuditCount = _intValue(
    quality['tasksMissingVerifierQualityAuditCount'],
  );
  final qualityConsistency = _objectMap(verifierAudit['qualityConsistency']);
  final invalidVerifierQualityFieldCount = _intValue(
    qualityConsistency['invalidFieldCount'],
  );
  final verifierQualityMismatchCount = _intValue(
    qualityConsistency['mismatchCount'],
  );
  final admissionChecks = _objectMap(verifierAudit['admissionChecks']);
  final requiredAdmissionCheckCount = _intValue(
    admissionChecks['requiredCheckCount'],
  );
  final passedRequiredAdmissionCheckCount = _intValue(
    admissionChecks['passedRequiredCheckCount'],
  );
  final missingRequiredAdmissionCheckCount = _intValue(
    admissionChecks['missingRequiredCheckCount'],
  );
  final failedRequiredAdmissionCheckCount = _intValue(
    admissionChecks['failedRequiredCheckCount'],
  );
  final invalidRequiredAdmissionCheckCount = _intValue(
    admissionChecks['invalidRequiredCheckCount'],
  );
  final failedOptionalAdmissionCheckCount = _intValue(
    admissionChecks['failedOptionalCheckCount'],
  );
  final invalidOptionalAdmissionCheckCount = _intValue(
    admissionChecks['invalidOptionalCheckCount'],
  );
  final admittedReportWithFailureMessagesCount = _intValue(
    admissionChecks['admittedReportWithFailureMessagesCount'],
  );
  final promptSafety = _objectMap(verifierAudit['promptSafety']);
  final promptSafetyPresentCount = _intValue(promptSafety['presentCount']);
  final missingPromptSafetyCount = _intValue(promptSafety['missingCount']);
  final failedPromptSafetyCount = _intValue(promptSafety['failedCount']);
  final invalidPromptSafetyPassedFlagCount = _intValue(
    promptSafety['invalidPassedFlagCount'],
  );
  final missingPromptSafetyRequiredNegativeKindCount = _intValue(
    promptSafety['missingRequiredNegativeKindCount'],
  );
  final promptSafeCheckMismatchCount = _intValue(
    promptSafety['promptSafeCheckMismatchCount'],
  );
  final requiredKindCoverageMismatchCount = _intValue(
    promptSafety['requiredKindCoverageMismatchCount'],
  );
  final promptSafetyInvalidKindCount = _intValue(
    promptSafety['invalidKindCount'],
  );
  final promptSafetyPresentKindMismatchCount = _intValue(
    promptSafety['presentKindMismatchCount'],
  );
  final promptSafetyMissingKindMismatchCount = _intValue(
    promptSafety['missingKindMismatchCount'],
  );
  final promptSafetyInvalidComponentFieldCount = _intValue(
    promptSafety['invalidComponentFieldCount'],
  );
  final promptSafetyPassedComputationMismatchCount = _intValue(
    promptSafety['passedComputationMismatchCount'],
  );
  final admissionProvenance = _objectMap(verifierAudit['admissionProvenance']);
  final admissionProvenancePresentCount = _intValue(
    admissionProvenance['presentCount'],
  );
  final missingAdmissionProvenanceCount = _intValue(
    admissionProvenance['missingCount'],
  );
  final invalidAdmissionEvaluatorCount = _intValue(
    admissionProvenance['invalidEvaluatorCount'],
  );
  final invalidAdmissionToolCount = _intValue(
    admissionProvenance['invalidToolCount'],
  );
  final admissionEnvironmentPresentCount = _intValue(
    admissionProvenance['environmentPresentCount'],
  );
  final admissionEnvironmentMissingCount = _intValue(
    admissionProvenance['environmentMissingCount'],
  );
  final admissionEnvironmentSdkVersionPresentCount = _intValue(
    admissionProvenance['sdkVersionPresentCount'],
  );
  final admissionEnvironmentSdkVersionIncompleteCount = _intValue(
    admissionProvenance['sdkVersionIncompleteCount'],
  );
  final admissionEnvironmentDependencySnapshotPresentCount = _intValue(
    admissionProvenance['dependencySnapshotPresentCount'],
  );
  final admissionEnvironmentDependencySnapshotIncompleteCount = _intValue(
    admissionProvenance['dependencySnapshotIncompleteCount'],
  );
  final taskBundleIntegrity = _objectMap(verifierAudit['taskBundleIntegrity']);
  final taskBundleDigestPresentCount = _intValue(
    taskBundleIntegrity['digestPresentCount'],
  );
  final taskBundleDigestMissingCount = _intValue(
    taskBundleIntegrity['digestMissingCount'],
  );
  final taskBundleDigestInvalidCount = _intValue(
    taskBundleIntegrity['digestInvalidCount'],
  );
  final taskBundleDigestMatchedCount = _intValue(
    taskBundleIntegrity['digestMatchedCount'],
  );
  final taskBundleDigestMismatchedCount = _intValue(
    taskBundleIntegrity['digestMismatchedCount'],
  );
  final taskBundleDigestRecomputeMissingCount = _intValue(
    taskBundleIntegrity['digestRecomputeMissingCount'],
  );
  final admissionEnvironmentGitDirtyCount = _intValue(
    taskBundleIntegrity['admissionEnvironmentGitDirtyCount'],
  );
  final taskExecutionPolicy = _objectMap(verifierAudit['taskExecutionPolicy']);
  final taskExecutionPolicyPresentCount = _intValue(
    taskExecutionPolicy['presentCount'],
  );
  final taskExecutionPolicyMissingCount = _intValue(
    taskExecutionPolicy['missingCount'],
  );
  final taskExecutionPolicyIncompleteCount = _intValue(
    taskExecutionPolicy['incompleteCount'],
  );
  final taskExecutionPolicyNetworkDisabledCount = _intValue(
    taskExecutionPolicy['networkDisabledCount'],
  );
  final taskExecutionPolicyNetworkEnabledCount = _intValue(
    taskExecutionPolicy['networkEnabledCount'],
  );
  final taskResourceLimitPresentCount = _intValue(
    taskExecutionPolicy['resourceLimitPresentCount'],
  );
  final taskResourceLimitIncompleteCount = _intValue(
    taskExecutionPolicy['resourceLimitIncompleteCount'],
  );
  final taskReportTimestamps = _objectMap(
    verifierAudit['taskReportTimestamps'],
  );
  final taskReportIntegrity = _objectMap(verifierAudit['taskReportIntegrity']);
  final taskReportSupportedSchemaVersionCount = _intValue(
    taskReportIntegrity['supportedSchemaVersionCount'],
  );
  final taskReportMissingSchemaVersionCount = _intValue(
    taskReportIntegrity['missingSchemaVersionCount'],
  );
  final taskReportUnsupportedSchemaVersionCount = _intValue(
    taskReportIntegrity['unsupportedSchemaVersionCount'],
  );
  final taskReportAdmittedStatusCount = _intValue(
    taskReportIntegrity['admittedStatusCount'],
  );
  final taskReportRejectedStatusCount = _intValue(
    taskReportIntegrity['rejectedStatusCount'],
  );
  final taskReportUnknownStatusCount = _intValue(
    taskReportIntegrity['unknownStatusCount'],
  );
  final taskReportGeneratedAtPresentCount = _intValue(
    taskReportTimestamps['presentCount'],
  );
  final taskReportGeneratedAtMissingCount = _intValue(
    taskReportTimestamps['missingCount'],
  );
  final taskReportGeneratedAtInvalidCount = _intValue(
    taskReportTimestamps['invalidCount'],
  );
  final taskReportGeneratedAtFutureCount = _intValue(
    taskReportTimestamps['futureCount'],
  );
  final passed =
      taskQa['status'] == 'completed' &&
      taskCount > 0 &&
      leaderboardTaskCount > 0 &&
      coveredLeaderboardTaskCount >= leaderboardTaskCount &&
      missingLeaderboardTaskQaCount == 0 &&
      extraTaskQaReportCount == 0 &&
      invalidLeaderboardTaskRowCount == 0 &&
      invalidTaskQaReportRowCount == 0 &&
      summaryIntegrityStatus == 'valid' &&
      invalidSummaryReportEntryCount == 0 &&
      matchedSummaryReportCount >= taskCount &&
      missingLoadedReportForSummaryCount == 0 &&
      unreferencedLoadedReportCount == 0 &&
      duplicateSummaryReportKeyCount == 0 &&
      duplicateLoadedReportKeyCount == 0 &&
      invalidSummaryFailureCountCount == 0 &&
      summaryReportStatusMismatchCount == 0 &&
      summaryReportFailureCountMismatchCount == 0 &&
      summaryReportGeneratedAfterSummaryCount == 0 &&
      missingReportPathCount == 0 &&
      absoluteReportPathCount == 0 &&
      parentReportPathCount == 0 &&
      malformedReportPathCount == 0 &&
      outsideTaskQaRootReportPathCount == 0 &&
      unsafeReportPathCount == 0 &&
      loadedReportCount >= taskCount &&
      rejectedTaskCount == 0 &&
      reportReadErrorCount == 0 &&
      hiddenVerifierDigestCount >= taskCount &&
      missingHiddenVerifierDigestCount == 0 &&
      invalidHiddenVerifierDigestCount == 0 &&
      negativeCaseCount > 0 &&
      acceptedNegativeCaseCount == 0 &&
      invalidNegativeCaseCount == 0 &&
      malformedNegativeCaseEvidenceCount == 0 &&
      unsupportedNegativeCaseKindCount == 0 &&
      negativeCaseOutcomeMismatchCount == 0 &&
      tasksMissingNegativeCaseCount == 0 &&
      privateOfficialTaskCount >= taskCount &&
      activeTaskCount >= taskCount &&
      tasksMissingReleaseMetadataCount == 0 &&
      tasksOutsidePrivateOfficialCorpusCount == 0 &&
      retiredTaskCount == 0 &&
      falsePositiveCount == 0 &&
      falseNegativeCount == 0 &&
      infrastructureErrorCount == 0 &&
      flakeRunCount >= taskCount * minHiddenFlakeRunsPerTask &&
      flakeFailureCount == 0 &&
      tasksBelowHiddenFlakeRunMinimumCount == 0 &&
      qualityAcceptedNegativeCaseCount == 0 &&
      missingVerifierQualityAuditCount == 0 &&
      invalidVerifierQualityFieldCount == 0 &&
      verifierQualityMismatchCount == 0 &&
      requiredAdmissionCheckCount >=
          taskCount * _requiredTaskQaAdmissionChecks.length &&
      passedRequiredAdmissionCheckCount >= requiredAdmissionCheckCount &&
      missingRequiredAdmissionCheckCount == 0 &&
      failedRequiredAdmissionCheckCount == 0 &&
      invalidRequiredAdmissionCheckCount == 0 &&
      failedOptionalAdmissionCheckCount == 0 &&
      invalidOptionalAdmissionCheckCount == 0 &&
      admittedReportWithFailureMessagesCount == 0 &&
      promptSafetyPresentCount >= taskCount &&
      missingPromptSafetyCount == 0 &&
      failedPromptSafetyCount == 0 &&
      invalidPromptSafetyPassedFlagCount == 0 &&
      missingPromptSafetyRequiredNegativeKindCount == 0 &&
      promptSafeCheckMismatchCount == 0 &&
      requiredKindCoverageMismatchCount == 0 &&
      promptSafetyInvalidKindCount == 0 &&
      promptSafetyPresentKindMismatchCount == 0 &&
      promptSafetyMissingKindMismatchCount == 0 &&
      promptSafetyInvalidComponentFieldCount == 0 &&
      promptSafetyPassedComputationMismatchCount == 0 &&
      admissionProvenancePresentCount >= taskCount &&
      missingAdmissionProvenanceCount == 0 &&
      invalidAdmissionToolCount == 0 &&
      invalidAdmissionEvaluatorCount == 0 &&
      admissionEnvironmentPresentCount >= taskCount &&
      admissionEnvironmentMissingCount == 0 &&
      admissionEnvironmentSdkVersionPresentCount >= taskCount &&
      admissionEnvironmentSdkVersionIncompleteCount == 0 &&
      admissionEnvironmentDependencySnapshotPresentCount >= taskCount &&
      admissionEnvironmentDependencySnapshotIncompleteCount == 0 &&
      taskBundleDigestPresentCount >= taskCount &&
      taskBundleDigestMissingCount == 0 &&
      taskBundleDigestInvalidCount == 0 &&
      taskBundleDigestMatchedCount >= taskCount &&
      taskBundleDigestMismatchedCount == 0 &&
      taskBundleDigestRecomputeMissingCount == 0 &&
      admissionEnvironmentGitDirtyCount == 0 &&
      taskExecutionPolicyPresentCount >= taskCount &&
      taskExecutionPolicyMissingCount == 0 &&
      taskExecutionPolicyIncompleteCount == 0 &&
      taskExecutionPolicyNetworkDisabledCount >= taskCount &&
      taskExecutionPolicyNetworkEnabledCount == 0 &&
      taskResourceLimitPresentCount >= taskCount &&
      taskResourceLimitIncompleteCount == 0 &&
      taskReportSupportedSchemaVersionCount >= taskCount &&
      taskReportMissingSchemaVersionCount == 0 &&
      taskReportUnsupportedSchemaVersionCount == 0 &&
      taskReportAdmittedStatusCount >= taskCount &&
      taskReportRejectedStatusCount == 0 &&
      taskReportUnknownStatusCount == 0 &&
      taskReportGeneratedAtPresentCount >= taskCount &&
      taskReportGeneratedAtMissingCount == 0 &&
      taskReportGeneratedAtInvalidCount == 0 &&
      taskReportGeneratedAtFutureCount == 0;

  return {
    'status': _readinessStatus(passed),
    'taskQaStatus': taskQa['status'],
    'taskCount': taskCount,
    'leaderboardTaskCount': leaderboardTaskCount,
    'coveredLeaderboardTaskCount': coveredLeaderboardTaskCount,
    'missingLeaderboardTaskQaCount': missingLeaderboardTaskQaCount,
    'extraTaskQaReportCount': extraTaskQaReportCount,
    'invalidLeaderboardTaskRowCount': invalidLeaderboardTaskRowCount,
    'invalidTaskQaReportRowCount': invalidTaskQaReportRowCount,
    'summaryIntegrityStatus': summaryIntegrityStatus,
    'summarySchemaVersion': summaryIntegrity['schemaVersion'],
    'summaryGeneratedAtStatus': summaryIntegrity['generatedAtStatus'],
    'summaryReportListStatus': summaryIntegrity['reportListStatus'],
    'summaryReportEntryCount': summaryIntegrity['reportEntryCount'],
    'invalidSummaryReportEntryCount': invalidSummaryReportEntryCount,
    'summaryReportCountMatchesTaskCount':
        summaryIntegrity['reportCountMatchesTaskCount'],
    'summaryAdmissionCountsMatchTaskCount':
        summaryIntegrity['admissionCountsMatchTaskCount'],
    'summaryAdmissionCountsMatchReportStatuses':
        summaryIntegrity['admissionCountsMatchReportStatuses'],
    'matchedSummaryReportCount': matchedSummaryReportCount,
    'missingLoadedReportForSummaryCount': missingLoadedReportForSummaryCount,
    'unreferencedLoadedReportCount': unreferencedLoadedReportCount,
    'duplicateSummaryReportKeyCount': duplicateSummaryReportKeyCount,
    'duplicateLoadedReportKeyCount': duplicateLoadedReportKeyCount,
    'invalidSummaryFailureCountCount': invalidSummaryFailureCountCount,
    'summaryReportStatusMismatchCount': summaryReportStatusMismatchCount,
    'summaryReportFailureCountMismatchCount':
        summaryReportFailureCountMismatchCount,
    'summaryReportGeneratedAfterSummaryCount':
        summaryReportGeneratedAfterSummaryCount,
    'missingReportPathCount': missingReportPathCount,
    'absoluteReportPathCount': absoluteReportPathCount,
    'parentReportPathCount': parentReportPathCount,
    'malformedReportPathCount': malformedReportPathCount,
    'outsideTaskQaRootReportPathCount': outsideTaskQaRootReportPathCount,
    'unsafeReportPathCount': unsafeReportPathCount,
    'loadedReportCount': loadedReportCount,
    'rejectedTaskCount': rejectedTaskCount,
    'reportReadErrorCount': reportReadErrorCount,
    'hiddenVerifierDigestCount': hiddenVerifierDigestCount,
    'missingHiddenVerifierDigestCount': missingHiddenVerifierDigestCount,
    'invalidHiddenVerifierDigestCount': invalidHiddenVerifierDigestCount,
    'negativeCaseCount': negativeCaseCount,
    'acceptedNegativeCaseCount': acceptedNegativeCaseCount,
    'invalidNegativeCaseCount': invalidNegativeCaseCount,
    'malformedNegativeCaseEvidenceCount': malformedNegativeCaseEvidenceCount,
    'unsupportedNegativeCaseKindCount': unsupportedNegativeCaseKindCount,
    'negativeCaseOutcomeMismatchCount': negativeCaseOutcomeMismatchCount,
    'tasksMissingNegativeCaseCount': tasksMissingNegativeCaseCount,
    'privateOfficialTaskCount': privateOfficialTaskCount,
    'activeTaskCount': activeTaskCount,
    'tasksMissingReleaseMetadataCount': tasksMissingReleaseMetadataCount,
    'tasksOutsidePrivateOfficialCorpusCount':
        tasksOutsidePrivateOfficialCorpusCount,
    'retiredTaskCount': retiredTaskCount,
    'falsePositiveCount': falsePositiveCount,
    'falseNegativeCount': falseNegativeCount,
    'disagreementCount': disagreementCount,
    'infrastructureErrorCount': infrastructureErrorCount,
    'flakeRunCount': flakeRunCount,
    'minHiddenFlakeRunsPerTask': minHiddenFlakeRunsPerTask,
    'tasksBelowHiddenFlakeRunMinimumCount':
        tasksBelowHiddenFlakeRunMinimumCount,
    'flakeFailureCount': flakeFailureCount,
    'qualityAcceptedNegativeCaseCount': qualityAcceptedNegativeCaseCount,
    'missingVerifierQualityAuditCount': missingVerifierQualityAuditCount,
    'invalidVerifierQualityFieldCount': invalidVerifierQualityFieldCount,
    'verifierQualityMismatchCount': verifierQualityMismatchCount,
    'requiredAdmissionCheckCount': requiredAdmissionCheckCount,
    'passedRequiredAdmissionCheckCount': passedRequiredAdmissionCheckCount,
    'missingRequiredAdmissionCheckCount': missingRequiredAdmissionCheckCount,
    'failedRequiredAdmissionCheckCount': failedRequiredAdmissionCheckCount,
    'invalidRequiredAdmissionCheckCount': invalidRequiredAdmissionCheckCount,
    'failedOptionalAdmissionCheckCount': failedOptionalAdmissionCheckCount,
    'invalidOptionalAdmissionCheckCount': invalidOptionalAdmissionCheckCount,
    'admittedReportWithFailureMessagesCount':
        admittedReportWithFailureMessagesCount,
    'promptSafetyPresentCount': promptSafetyPresentCount,
    'missingPromptSafetyCount': missingPromptSafetyCount,
    'failedPromptSafetyCount': failedPromptSafetyCount,
    'invalidPromptSafetyPassedFlagCount': invalidPromptSafetyPassedFlagCount,
    'missingPromptSafetyRequiredNegativeKindCount':
        missingPromptSafetyRequiredNegativeKindCount,
    'promptSafeCheckMismatchCount': promptSafeCheckMismatchCount,
    'requiredKindCoverageMismatchCount': requiredKindCoverageMismatchCount,
    'promptSafetyInvalidKindCount': promptSafetyInvalidKindCount,
    'promptSafetyPresentKindMismatchCount':
        promptSafetyPresentKindMismatchCount,
    'promptSafetyMissingKindMismatchCount':
        promptSafetyMissingKindMismatchCount,
    'promptSafetyInvalidComponentFieldCount':
        promptSafetyInvalidComponentFieldCount,
    'promptSafetyPassedComputationMismatchCount':
        promptSafetyPassedComputationMismatchCount,
    'admissionProvenancePresentCount': admissionProvenancePresentCount,
    'missingAdmissionProvenanceCount': missingAdmissionProvenanceCount,
    'invalidAdmissionToolCount': invalidAdmissionToolCount,
    'invalidAdmissionEvaluatorCount': invalidAdmissionEvaluatorCount,
    'admissionEnvironmentPresentCount': admissionEnvironmentPresentCount,
    'admissionEnvironmentMissingCount': admissionEnvironmentMissingCount,
    'admissionEnvironmentSdkVersionPresentCount':
        admissionEnvironmentSdkVersionPresentCount,
    'admissionEnvironmentSdkVersionIncompleteCount':
        admissionEnvironmentSdkVersionIncompleteCount,
    'admissionEnvironmentDependencySnapshotPresentCount':
        admissionEnvironmentDependencySnapshotPresentCount,
    'admissionEnvironmentDependencySnapshotIncompleteCount':
        admissionEnvironmentDependencySnapshotIncompleteCount,
    'taskBundleDigestPresentCount': taskBundleDigestPresentCount,
    'taskBundleDigestMissingCount': taskBundleDigestMissingCount,
    'taskBundleDigestInvalidCount': taskBundleDigestInvalidCount,
    'taskBundleDigestMatchedCount': taskBundleDigestMatchedCount,
    'taskBundleDigestMismatchedCount': taskBundleDigestMismatchedCount,
    'taskBundleDigestRecomputeMissingCount':
        taskBundleDigestRecomputeMissingCount,
    'admissionEnvironmentGitDirtyCount': admissionEnvironmentGitDirtyCount,
    'taskExecutionPolicyPresentCount': taskExecutionPolicyPresentCount,
    'taskExecutionPolicyMissingCount': taskExecutionPolicyMissingCount,
    'taskExecutionPolicyIncompleteCount': taskExecutionPolicyIncompleteCount,
    'taskExecutionPolicyNetworkDisabledCount':
        taskExecutionPolicyNetworkDisabledCount,
    'taskExecutionPolicyNetworkEnabledCount':
        taskExecutionPolicyNetworkEnabledCount,
    'taskResourceLimitPresentCount': taskResourceLimitPresentCount,
    'taskResourceLimitIncompleteCount': taskResourceLimitIncompleteCount,
    'taskReportSupportedSchemaVersionCount':
        taskReportSupportedSchemaVersionCount,
    'taskReportMissingSchemaVersionCount': taskReportMissingSchemaVersionCount,
    'taskReportUnsupportedSchemaVersionCount':
        taskReportUnsupportedSchemaVersionCount,
    'taskReportAdmittedStatusCount': taskReportAdmittedStatusCount,
    'taskReportRejectedStatusCount': taskReportRejectedStatusCount,
    'taskReportUnknownStatusCount': taskReportUnknownStatusCount,
    'taskReportGeneratedAtPresentCount': taskReportGeneratedAtPresentCount,
    'taskReportGeneratedAtMissingCount': taskReportGeneratedAtMissingCount,
    'taskReportGeneratedAtInvalidCount': taskReportGeneratedAtInvalidCount,
    'taskReportGeneratedAtFutureCount': taskReportGeneratedAtFutureCount,
  };
}

Map<String, Object?> _executionReadinessGate({
  required Map<String, Object?> sourceRunProvenance,
  required Map<String, Object?> storedRunProvenance,
}) {
  final runCount = _intValue(sourceRunProvenance['runCount']);
  final requiredRunCount = _stringList(
    storedRunProvenance['requiredRunIds'],
  ).length;
  final sourceWarnings = _stringList(sourceRunProvenance['warnings']);
  final sourceEmbeddedRunCount = _intValue(
    sourceRunProvenance['embeddedRunCount'],
  );
  final sourceSandboxEnforcedRunCount = _intValue(
    sourceRunProvenance['sandboxEnforcedRunCount'],
  );
  final sourceTaskExecutionPolicyRunCount = _intValue(
    sourceRunProvenance['taskExecutionPolicyRunCount'],
  );
  final sourceNetworkDisabledTaskPolicyRunCount = _intValue(
    sourceRunProvenance['networkDisabledTaskPolicyRunCount'],
  );
  final sourceTaskResourceLimitRunCount = _intValue(
    sourceRunProvenance['taskResourceLimitRunCount'],
  );
  final sourceSdkVersionRunCount = _intValue(
    sourceRunProvenance['sdkVersionRunCount'],
  );
  final sourceDependencySnapshotRunCount = _intValue(
    sourceRunProvenance['dependencySnapshotRunCount'],
  );
  final sourcePricingRegistryRunCount = _intValue(
    sourceRunProvenance['pricingRegistryRunCount'],
  );
  final storedEmbeddedRunCount = _intValue(
    storedRunProvenance['embeddedRunCount'],
  );
  final storedSandboxEnforcedRunCount = _intValue(
    storedRunProvenance['sandboxEnforcedRunCount'],
  );
  final storedTaskExecutionPolicyRunCount = _intValue(
    storedRunProvenance['taskExecutionPolicyRunCount'],
  );
  final storedNetworkDisabledTaskPolicyRunCount = _intValue(
    storedRunProvenance['networkDisabledTaskPolicyRunCount'],
  );
  final storedTaskResourceLimitRunCount = _intValue(
    storedRunProvenance['taskResourceLimitRunCount'],
  );
  final storedSdkVersionRunCount = _intValue(
    storedRunProvenance['sdkVersionRunCount'],
  );
  final storedDependencySnapshotRunCount = _intValue(
    storedRunProvenance['dependencySnapshotRunCount'],
  );
  final storedPricingRegistryRunCount = _intValue(
    storedRunProvenance['pricingRegistryRunCount'],
  );
  final sandboxBackendCount = _stringList(
    sourceRunProvenance['generatedCodeSandboxBackends'],
  ).length;
  final sourcePassed =
      runCount > 0 &&
      sourceWarnings.isEmpty &&
      sandboxBackendCount > 0 &&
      _coversRuns(sourceEmbeddedRunCount, runCount) &&
      _coversRuns(sourceSandboxEnforcedRunCount, runCount) &&
      _coversRuns(sourceTaskExecutionPolicyRunCount, runCount) &&
      _coversRuns(sourceNetworkDisabledTaskPolicyRunCount, runCount) &&
      _coversRuns(sourceTaskResourceLimitRunCount, runCount) &&
      _coversRuns(sourceSdkVersionRunCount, runCount) &&
      _coversRuns(sourceDependencySnapshotRunCount, runCount) &&
      _coversRuns(sourcePricingRegistryRunCount, runCount);
  final storedPassed =
      requiredRunCount > 0 &&
      requiredRunCount == runCount &&
      _coversRuns(storedEmbeddedRunCount, requiredRunCount) &&
      _coversRuns(storedSandboxEnforcedRunCount, requiredRunCount) &&
      _coversRuns(storedTaskExecutionPolicyRunCount, requiredRunCount) &&
      _coversRuns(storedNetworkDisabledTaskPolicyRunCount, requiredRunCount) &&
      _coversRuns(storedTaskResourceLimitRunCount, requiredRunCount) &&
      _coversRuns(storedSdkVersionRunCount, requiredRunCount) &&
      _coversRuns(storedDependencySnapshotRunCount, requiredRunCount) &&
      _coversRuns(storedPricingRegistryRunCount, requiredRunCount);

  return {
    'status': _readinessStatus(sourcePassed && storedPassed),
    'runCount': runCount,
    'requiredRunCount': requiredRunCount,
    'sourceEmbeddedRunCount': sourceEmbeddedRunCount,
    'storedEmbeddedRunCount': storedEmbeddedRunCount,
    'sourceSandboxEnforcedRunCount': sourceSandboxEnforcedRunCount,
    'storedSandboxEnforcedRunCount': storedSandboxEnforcedRunCount,
    'sourceTaskExecutionPolicyRunCount': sourceTaskExecutionPolicyRunCount,
    'storedTaskExecutionPolicyRunCount': storedTaskExecutionPolicyRunCount,
    'sourceNetworkDisabledTaskPolicyRunCount':
        sourceNetworkDisabledTaskPolicyRunCount,
    'storedNetworkDisabledTaskPolicyRunCount':
        storedNetworkDisabledTaskPolicyRunCount,
    'sourceTaskResourceLimitRunCount': sourceTaskResourceLimitRunCount,
    'storedTaskResourceLimitRunCount': storedTaskResourceLimitRunCount,
    'sourceSdkVersionRunCount': sourceSdkVersionRunCount,
    'storedSdkVersionRunCount': storedSdkVersionRunCount,
    'sourceDependencySnapshotRunCount': sourceDependencySnapshotRunCount,
    'storedDependencySnapshotRunCount': storedDependencySnapshotRunCount,
    'sourcePricingRegistryRunCount': sourcePricingRegistryRunCount,
    'storedPricingRegistryRunCount': storedPricingRegistryRunCount,
    'sandboxBackendCount': sandboxBackendCount,
    'sourceWarningCount': sourceWarnings.length,
  };
}

Map<String, Object?> _scoringReadinessGate({
  required Map<String, Object?> scoring,
  required List<Map<String, Object?>> lowSampleModels,
}) {
  final objectiveEvaluatorIds = _stringList(scoring['objectiveEvaluatorIds']);
  final secondaryEvaluatorIds = _stringList(scoring['secondaryEvaluatorIds']);
  final diagnosticOnlyEvaluatorIds = _stringList(
    scoring['diagnosticOnlyEvaluatorIds'],
  );
  final failureTags = _stringList(scoring['failureTags']);
  final objectiveFailureCaps = _objectMap(scoring['objectiveFailureCaps']);
  final defaultEvaluatorWeights = _objectMap(
    scoring['defaultEvaluatorWeights'],
  );
  final requiredFailureTagsPresent = _requiredFailureTagsPresent(failureTags);
  final hiddenVerifierPattern = scoring['hiddenVerifierPattern'];
  final passed =
      _intValue(scoring['schemaVersion']) >= _requiredScoringSchemaVersion &&
      scoring['primaryMetric'] == 'primary_pass' &&
      scoring['rankingMetric'] == 'primary_pass_rate' &&
      scoring['confidenceInterval'] == 'wilson_95' &&
      scoring['llmJudgePolicy'] is String &&
      scoring['diffSizePolicy'] == _requiredDiffSizePolicy &&
      objectiveEvaluatorIds.isNotEmpty &&
      secondaryEvaluatorIds.isNotEmpty &&
      diagnosticOnlyEvaluatorIds.contains(_diffSizeEvaluatorId) &&
      hiddenVerifierPattern is String &&
      hiddenVerifierPattern.trim().isNotEmpty &&
      failureTags.isNotEmpty &&
      requiredFailureTagsPresent &&
      objectiveFailureCaps.isNotEmpty &&
      defaultEvaluatorWeights.isNotEmpty &&
      lowSampleModels.isEmpty;

  return {
    'status': _readinessStatus(passed),
    'primaryMetric': scoring['primaryMetric'],
    'rankingMetric': scoring['rankingMetric'],
    'confidenceInterval': scoring['confidenceInterval'],
    'llmJudgePolicy': scoring['llmJudgePolicy'],
    'diffSizePolicy': scoring['diffSizePolicy'],
    'objectiveEvaluatorCount': objectiveEvaluatorIds.length,
    'secondaryEvaluatorCount': secondaryEvaluatorIds.length,
    'diagnosticOnlyEvaluatorCount': diagnosticOnlyEvaluatorIds.length,
    'diffSizeDiagnosticOnly': diagnosticOnlyEvaluatorIds.contains(
      _diffSizeEvaluatorId,
    ),
    'failureTagCount': failureTags.length,
    'requiredFailureTagsPresent': requiredFailureTagsPresent,
    'objectiveFailureCapCount': objectiveFailureCaps.length,
    'defaultEvaluatorWeightCount': defaultEvaluatorWeights.length,
    'lowSampleModelCount': lowSampleModels.length,
  };
}

List<ReleaseArtifactBundleInput> _singleArtifactBundleInput({
  required Map<String, Object?>? manifest,
  required Map<String, Object?>? checksums,
  required Map<String, Object?>? runResults,
  required String? resultsCsv,
  required String? reportMarkdown,
  required Map<String, Object?> releaseInputs,
}) {
  if (manifest == null &&
      checksums == null &&
      runResults == null &&
      resultsCsv == null &&
      reportMarkdown == null) {
    return const [];
  }
  return [
    ReleaseArtifactBundleInput(
      manifest: manifest ?? const {},
      checksums: checksums ?? const {},
      runResults: runResults ?? const {},
      resultsCsv: resultsCsv ?? '',
      reportMarkdown: reportMarkdown ?? '',
      manifestInput: _objectMap(releaseInputs['artifactManifest']),
      checksumsInput: _objectMap(releaseInputs['artifactChecksums']),
      runResultsInput: _objectMap(releaseInputs['artifactRunResults']),
      resultsCsvInput: _objectMap(releaseInputs['artifactResultsCsv']),
      reportInput: _objectMap(releaseInputs['artifactReport']),
      artifactFileInputs: {
        for (final input in _objectMaps(releaseInputs['artifactFiles']))
          if (_nonEmptyString(input['path']) case final path?) path: input,
      },
    ),
  ];
}

Map<String, Object?> _artifactBundleReadinessSummary({
  required List<ReleaseArtifactBundleInput> artifactBundles,
  required DateTime reportGeneratedAt,
  required List<String> sourceRunIds,
  required List<Map<String, Object?>> leaderboardTrialSummaries,
  required Set<String> blockers,
}) {
  if (artifactBundles.isEmpty) {
    return _artifactBundleSummary(
      manifest: null,
      checksums: null,
      runResults: null,
      resultsCsv: null,
      reportMarkdown: null,
      reportGeneratedAt: reportGeneratedAt,
      sourceRunIds: sourceRunIds,
      leaderboardTrialSummaries: leaderboardTrialSummaries,
      manifestInput: const {},
      checksumsInput: const {},
      standardFileInputs: const {},
      artifactFileInputs: const {},
      blockers: blockers,
    );
  }

  if (artifactBundles.length == 1) {
    final bundle = artifactBundles.single;
    return _artifactBundleSummary(
      manifest: bundle.manifest,
      checksums: bundle.checksums,
      runResults: bundle.runResults,
      resultsCsv: bundle.resultsCsv,
      reportMarkdown: bundle.reportMarkdown,
      reportGeneratedAt: reportGeneratedAt,
      sourceRunIds: sourceRunIds,
      leaderboardTrialSummaries: leaderboardTrialSummaries,
      manifestInput: bundle.manifestInput,
      checksumsInput: bundle.checksumsInput,
      standardFileInputs: {
        'report.md': bundle.reportInput,
        'results.csv': bundle.resultsCsvInput,
        'run_results.v1.json': bundle.runResultsInput,
      },
      artifactFileInputs: bundle.artifactFileInputs,
      blockers: blockers,
    );
  }

  final summaries = <Map<String, Object?>>[];
  for (final bundle in artifactBundles) {
    final runId = _manifestRunId(bundle.manifest);
    summaries.add(
      _artifactBundleSummary(
        manifest: bundle.manifest,
        checksums: bundle.checksums,
        runResults: bundle.runResults,
        resultsCsv: bundle.resultsCsv,
        reportMarkdown: bundle.reportMarkdown,
        reportGeneratedAt: reportGeneratedAt,
        sourceRunIds: sourceRunIds,
        leaderboardTrialSummaries: runId == null
            ? const []
            : _trialSummariesForRun(leaderboardTrialSummaries, runId),
        manifestInput: bundle.manifestInput,
        checksumsInput: bundle.checksumsInput,
        standardFileInputs: {
          'report.md': bundle.reportInput,
          'results.csv': bundle.resultsCsvInput,
          'run_results.v1.json': bundle.runResultsInput,
        },
        artifactFileInputs: bundle.artifactFileInputs,
        blockers: blockers,
      ),
    );
  }

  return _combinedArtifactBundleSummary(
    summaries: summaries,
    sourceRunIds: sourceRunIds,
    blockers: blockers,
  );
}

String? _manifestRunId(Map<String, Object?> manifest) =>
    _nonEmptyString(_objectMap(manifest['run'])['id']);

List<Map<String, Object?>> _trialSummariesForRun(
  List<Map<String, Object?>> trialSummaries,
  String runId,
) => [
  for (final trial in trialSummaries)
    if (trial['runId'] == runId) trial,
];

Map<String, Object?> _combinedArtifactBundleSummary({
  required List<Map<String, Object?>> summaries,
  required List<String> sourceRunIds,
  required Set<String> blockers,
}) {
  final observedRunIds = [
    for (final summary in summaries)
      if (_nonEmptyString(summary['runId']) case final runId?) runId,
  ];
  final sourceRunIdSet = sourceRunIds.toSet();
  final observedRunIdSet = observedRunIds.toSet();
  final missingRunIds = sourceRunIdSet.difference(observedRunIdSet);
  final extraRunIds = observedRunIdSet.difference(sourceRunIdSet);
  final duplicateRunIdCount = observedRunIds.length - observedRunIdSet.length;

  if (missingRunIds.isNotEmpty) {
    blockers.add(
      'Release artifact bundle inputs are missing ${missingRunIds.length} '
      'leaderboard source run(s).',
    );
  }
  if (extraRunIds.isNotEmpty) {
    blockers.add(
      'Release artifact bundle inputs include ${extraRunIds.length} '
      'run(s) outside leaderboard source run ids.',
    );
  }
  if (duplicateRunIdCount > 0) {
    blockers.add(
      'Release artifact bundle inputs include $duplicateRunIdCount duplicate '
      'run id(s).',
    );
  }

  final combined = <String, Object?>{};
  final keys = summaries.expand((summary) => summary.keys).toSet()
    ..removeAll({
      'status',
      'runId',
      'runIdStatus',
      'runIdInLeaderboardSource',
      'schemaVersion',
      'checksumSchemaVersion',
      'runResultsSchemaVersion',
      'artifactKindCounts',
      'warningCodeCounts',
    });

  for (final key in keys) {
    final values = [
      for (final summary in summaries)
        if (summary.containsKey(key)) summary[key],
    ];
    if (values.isEmpty) continue;
    if (values.every((value) => value is num)) {
      combined[key] = values.cast<num>().fold<num>(
        0,
        (sum, value) => sum + value,
      );
    } else if (values.every((value) => value is bool)) {
      combined[key] = values.cast<bool>().every((value) => value);
    } else if (key.endsWith('Status')) {
      combined[key] = values.every((value) => value == values.first)
          ? values.first
          : 'mixed';
    } else if (values.every((value) => value == values.first)) {
      combined[key] = values.first;
    }
  }

  final allBundlesPresent = summaries.every(
    (summary) => summary['status'] == 'present',
  );
  final exactRunCoverage =
      missingRunIds.isEmpty && extraRunIds.isEmpty && duplicateRunIdCount == 0;
  combined.addAll({
    'status': allBundlesPresent && exactRunCoverage ? 'present' : 'incomplete',
    'bundleCount': summaries.length,
    'runId': observedRunIds.length == 1 ? observedRunIds.single : null,
    'runIds': observedRunIds,
    'runIdStatus': observedRunIds.length == summaries.length
        ? 'present'
        : 'missing',
    'runIdInLeaderboardSource': exactRunCoverage,
    'missingSourceRunBundleCount': missingRunIds.length,
    'extraSourceRunBundleCount': extraRunIds.length,
    'duplicateBundleRunIdCount': duplicateRunIdCount,
    'missingSourceRunArtifactBundleCount': missingRunIds.length,
    'extraSourceRunArtifactBundleCount': extraRunIds.length,
    'duplicateSourceRunArtifactBundleCount': duplicateRunIdCount,
    'schemaVersion': _commonIntValue(summaries, 'schemaVersion'),
    'checksumSchemaVersion': _commonIntValue(
      summaries,
      'checksumSchemaVersion',
    ),
    'runResultsSchemaVersion': _commonIntValue(
      summaries,
      'runResultsSchemaVersion',
    ),
    'artifactKindCounts': _combinedCountMap(summaries, 'artifactKindCounts'),
    'warningCodeCounts': _combinedCountMap(summaries, 'warningCodeCounts'),
    'bundles': [
      for (final summary in summaries)
        {
          'runId': summary['runId'],
          'status': summary['status'],
          'taskRunCount': _intValue(summary['taskRunCount']),
          'artifactCount': _intValue(summary['artifactCount']),
          'warningCount': _intValue(summary['warningCount']),
          'warningCodeCounts': _countMap(summary['warningCodeCounts']),
          'missingResponseArtifactCount': _intValue(
            summary['missingResponseArtifactCount'],
          ),
          'missingAgenticPatchArtifactCount': _intValue(
            summary['missingAgenticPatchArtifactCount'],
          ),
        },
    ],
  });
  return combined;
}

int _commonIntValue(List<Map<String, Object?>> summaries, String key) {
  final values = {
    for (final summary in summaries)
      if (summary[key] is num) (summary[key] as num).toInt(),
  };
  return values.length == 1 ? values.single : 0;
}

Map<String, int> _combinedCountMap(
  List<Map<String, Object?>> summaries,
  String key,
) {
  final out = SplayTreeMap<String, int>();
  for (final summary in summaries) {
    final map = _countMap(summary[key]);
    for (final entry in map.entries) {
      out[entry.key] = (out[entry.key] ?? 0) + entry.value;
    }
  }
  return out;
}

Map<String, int> _countMap(Object? value) {
  final out = SplayTreeMap<String, int>();
  final map = _objectMap(value);
  for (final entry in map.entries) {
    final count = _intValue(entry.value);
    if (count > 0) {
      out[entry.key] = count;
    }
  }
  return out;
}

Map<String, int> _artifactBundleWarningCodeCounts(Object? warnings) {
  final out = SplayTreeMap<String, int>();
  if (warnings is! List) return out;
  for (final warning in warnings) {
    final code = _artifactBundleWarningCode(_objectMap(warning)['code']);
    out[code] = (out[code] ?? 0) + 1;
  }
  return out;
}

String _artifactBundleWarningCode(Object? value) {
  final code = _nonEmptyString(value);
  if (code == null || !_artifactBundleWarningCodePattern.hasMatch(code)) {
    return 'unknown';
  }
  return code;
}

Map<String, Object?> _artifactBundleSummary({
  required Map<String, Object?>? manifest,
  required Map<String, Object?>? checksums,
  required Map<String, Object?>? runResults,
  required String? resultsCsv,
  required String? reportMarkdown,
  required DateTime reportGeneratedAt,
  required List<String> sourceRunIds,
  required List<Map<String, Object?>> leaderboardTrialSummaries,
  required Map<String, Object?> manifestInput,
  required Map<String, Object?> checksumsInput,
  required Map<String, Map<String, Object?>> standardFileInputs,
  required Map<String, Map<String, Object?>> artifactFileInputs,
  required Set<String> blockers,
}) {
  if (manifest == null) {
    blockers.add('Run artifact bundle manifest was not provided.');
    return const {
      'status': 'missing',
      'schemaVersion': 0,
      'runId': null,
      'runIdStatus': 'missing',
      'runIdInLeaderboardSource': false,
      'manifestPopulationSummaryStatus': 'missing',
      'manifestTaskCountStatus': 'missing',
      'manifestProviderCountStatus': 'missing',
      'manifestModelCountStatus': 'missing',
      'manifestTaskCount': 0,
      'manifestProviderCount': 0,
      'manifestModelCount': 0,
      'manifestDistinctTaskCount': 0,
      'manifestDistinctProviderCount': 0,
      'manifestDistinctModelCount': 0,
      'manifestPopulationCountMismatchCount': 0,
      'manifestRunMetadataStatus': 'missing',
      'manifestRunNameStatus': 'missing',
      'manifestRunStartedAtStatus': 'missing',
      'manifestRunCompletedAtStatus': 'missing',
      'manifestRunDurationStatus': 'unverified',
      'manifestRunCompletedBeforeGeneratedAtStatus': 'unverified',
      'manifestOutcomeSummaryStatus': 'missing',
      'manifestPassSummaryStatus': 'missing',
      'manifestFailureSummaryStatus': 'missing',
      'manifestPassSummaryMismatchCount': 0,
      'manifestFailureSummaryMismatchCount': 0,
      'taskRunCount': 0,
      'agenticTaskRunCount': 0,
      'evaluationCount': 0,
      'manifestEvaluatorIdCount': 0,
      'invalidManifestEvaluatorIdCount': 0,
      'duplicateManifestEvaluatorIdCount': 0,
      'artifactCount': 0,
      'artifactKindCounts': <String, int>{},
      'responseArtifactCount': 0,
      'patchArtifactCount': 0,
      'trajectoryArtifactCount': 0,
      'warningCount': 0,
      'warningCodeCounts': <String, int>{},
      'missingResponseArtifactCount': 0,
      'missingAgenticPatchArtifactCount': 0,
      'missingAgenticHarnessMetadataCount': 0,
      'missingLeaderboardTrialSummaryTaskRunCount': 0,
      'extraLeaderboardTrialSummaryTaskRunCount': 0,
      'invalidTaskRunModelIdentityCount': 0,
      'invalidTaskRunCount': 0,
      'duplicateTaskRunCount': 0,
      'invalidArtifactCount': 0,
      'invalidArtifactIdCount': 0,
      'duplicateArtifactIdCount': 0,
      'unknownArtifactKindCount': 0,
      'duplicateArtifactReferenceCount': 0,
      'unsafeArtifactPathCount': 0,
      'absoluteArtifactPathCount': 0,
      'parentArtifactPathCount': 0,
      'privateArtifactPathCount': 0,
      'outsideArtifactRootPathCount': 0,
      'manifestMetadataStatus': 'missing',
      'manifestGeneratedAtStatus': 'missing',
      'manifestAppVersionStatus': 'missing',
      'manifestDriftSchemaVersionStatus': 'missing',
      'manifestExportToolStatus': 'missing',
      'manifestExportEnvironmentStatus': 'missing',
      'manifestExportEnvironmentGitStatus': 'missing',
      'manifestProvenanceStatus': 'missing',
      'manifestProvenanceRunId': null,
      'manifestProvenanceRunIdMatchesManifest': false,
      'manifestProvenanceSandboxStatus': 'missing',
      'manifestProvenanceSandboxBackend': null,
      'manifestProvenanceTaskExecutionPolicyStatus': 'missing',
      'manifestProvenanceNetworkDisabledTaskPolicyStatus': 'missing',
      'manifestProvenanceTaskResourceLimitStatus': 'missing',
      'manifestProvenanceSdkVersionStatus': 'missing',
      'manifestProvenanceDependencySnapshotStatus': 'missing',
      'manifestProvenancePricingRegistryStatus': 'missing',
      'checksumsPath': null,
      'checksumsPathStatus': 'missing',
      'checksumSchemaVersion': 0,
      'checksumsStatus': 'missing',
      'checksumAlgorithm': null,
      'checksumFileCount': 0,
      'manifestChecksumStatus': 'missing',
      'manifestChecksumDigestStatus': 'missing',
      'checksumsPathMatchesInput': false,
      'coveredArtifactChecksumCount': 0,
      'missingArtifactChecksumCount': 0,
      'coveredStandardChecksumCount': 0,
      'missingStandardChecksumCount': 0,
      'verifiedStandardChecksumCount': 0,
      'missingStandardInputCount': 0,
      'mismatchedStandardChecksumCount': 0,
      'standardInputPathMismatchCount': 0,
      'verifiedArtifactFileCount': 0,
      'missingArtifactFileCount': 0,
      'mismatchedArtifactFileByteCount': 0,
      'mismatchedArtifactFileDigestCount': 0,
      'mismatchedManifestArtifactDigestCount': 0,
      'unexpectedChecksumPathCount': 0,
      'unsafeChecksumPathCount': 0,
      'absoluteChecksumPathCount': 0,
      'parentChecksumPathCount': 0,
      'privateChecksumPathCount': 0,
      'outsideArtifactRootChecksumPathCount': 0,
      'invalidChecksumEntryCount': 0,
      'duplicateChecksumPathCount': 0,
      'resultsCsvStatus': 'missing',
      'resultsCsvTaskRunCount': 0,
      'missingResultsCsvHeaderCount': 0,
      'invalidResultsCsvTaskRunCount': 0,
      'duplicateResultsCsvTaskRunCount': 0,
      'missingResultsCsvTaskRunCount': 0,
      'extraResultsCsvTaskRunCount': 0,
      'mismatchedResultsCsvRunResultsCount': 0,
      'invalidResultsCsvOutcomeCount': 0,
      'reportMarkdownStatus': 'missing',
      'reportMarkdownDeclaredTaskRunCount': 0,
      'reportMarkdownTaskRunCount': 0,
      'missingReportMarkdownSectionCount': 0,
      'missingReportMarkdownColumnCount': 0,
      'invalidReportMarkdownTaskRunCount': 0,
      'duplicateReportMarkdownTaskRunCount': 0,
      'missingReportMarkdownTaskRunCount': 0,
      'extraReportMarkdownTaskRunCount': 0,
      'mismatchedReportMarkdownRunResultsCount': 0,
      'invalidReportMarkdownOutcomeCount': 0,
      'runResultsStatus': 'missing',
      'runResultsSchemaVersion': 0,
      'runResultsRunId': null,
      'runResultsRunIdMatchesManifest': false,
      'runResultsRunMetadataStatus': 'missing',
      'runResultsRunNameMatchesManifest': false,
      'runResultsRunStartedAtMatchesManifest': false,
      'runResultsRunCompletedAtMatchesManifest': false,
      'mismatchedRunResultsRunMetadataFieldCount': 0,
      'runResultsTaskRunCount': 0,
      'runResultsEvaluationCount': 0,
      'runResultsEvaluationCountMatchesManifest': false,
      'runResultsEvaluatorIdCount': 0,
      'runResultsEvaluatorIdsMatchManifest': false,
      'missingRunResultsEvaluatorIdCount': 0,
      'extraRunResultsEvaluatorIdCount': 0,
      'missingRunResultsTaskRunCount': 0,
      'extraRunResultsTaskRunCount': 0,
      'mismatchedRunResultsTaskRunCount': 0,
      'missingRunResultsAgenticHarnessMetadataCount': 0,
      'mismatchedRunResultsAgenticHarnessMetadataCount': 0,
      'mismatchedRunResultsTaskRunRunIdCount': 0,
      'mismatchedRunResultsTrialOutcomeCount': 0,
      'invalidRunResultsTrialOutcomeCount': 0,
      'invalidRunResultsTimingTaskRunCount': 0,
      'invalidRunResultsTokenUsageTaskRunCount': 0,
      'missingRunResultsEvaluationTaskRunCount': 0,
      'invalidRunResultsEvaluationCount': 0,
      'invalidRunResultsEvaluationRationaleCount': 0,
      'invalidRunResultsEvaluationDetailsMetadataCount': 0,
      'invalidRunResultsBlockedEvaluationMetadataCount': 0,
      'invalidRunResultsJudgeOverheadMetadataCount': 0,
      'missingRunResultsAgentHarnessStatusMetadataCount': 0,
      'invalidRunResultsAgentHarnessStatusMetadataCount': 0,
      'duplicateRunResultsEvaluationIdCount': 0,
      'duplicateRunResultsTaskEvaluatorCount': 0,
      'missingRunResultsArtifactCount': 0,
      'extraRunResultsArtifactCount': 0,
      'mismatchedRunResultsArtifactCount': 0,
      'missingRunResultsArtifactMetadataCount': 0,
      'invalidRunResultsArtifactMetadataEntryCount': 0,
      'mismatchedRunResultsArtifactMetadataCount': 0,
      'invalidRunResultsArtifactIdCount': 0,
      'mismatchedRunResultsArtifactIdCount': 0,
      'invalidRunResultsArtifactMetadataCount': 0,
      'mismatchedRunResultsArtifactByteCount': 0,
      'mismatchedRunResultsArtifactDigestCount': 0,
      'invalidRunResultsTaskRunCount': 0,
      'invalidRunResultsTaskRunModelIdentityCount': 0,
      'duplicateRunResultsTaskRunCount': 0,
    };
  }

  final schemaVersion = _intValue(manifest['schemaVersion']);
  final manifestRun = _objectMap(manifest['run']);
  final manifestRunId = _nonEmptyString(manifestRun['id']);
  final runIdInLeaderboardSource =
      manifestRunId != null && sourceRunIds.contains(manifestRunId);
  final counts = _objectMap(manifest['counts']);
  final manifestTaskRunCount = _intValue(counts['taskRunCount']);
  final manifestEvaluationCount = _intValue(counts['evaluationCount']);
  final manifestArtifactCount = _intValue(counts['artifactCount']);
  final manifestWarningCount = _intValue(counts['warningCount']);
  final manifestEvaluatorIdsValue = manifest['evaluatorIds'];
  final manifestEvaluatorIdList = _nonEmptyStringList(
    manifestEvaluatorIdsValue,
  );
  final manifestEvaluatorIds = SplayTreeSet<String>.of(manifestEvaluatorIdList);
  final invalidManifestEvaluatorIdCount = manifestEvaluatorIdsValue is List
      ? manifestEvaluatorIdsValue.length - manifestEvaluatorIdList.length
      : 0;
  final duplicateManifestEvaluatorIdCount =
      manifestEvaluatorIdList.length - manifestEvaluatorIds.length;
  final taskRuns = _objectMaps(manifest['taskRuns']);
  final artifacts = _objectMaps(manifest['artifacts']);
  final warnings = manifest['warnings'];
  final warningCount = warnings is List ? warnings.length : 0;
  final warningCodeCounts = _artifactBundleWarningCodeCounts(warnings);
  final checksumsPath = _nonEmptyString(manifest['checksumsPath']);
  final checksumsInputPath = _nonEmptyString(checksumsInput['path']);
  final checksumsPathMatchesInput =
      checksumsPath != null &&
      checksumsInputPath != null &&
      checksumsPath == checksumsInputPath;
  final checksumAudit = _artifactChecksumAudit(
    checksums: checksums,
    manifestArtifacts: artifacts,
    manifestInputSha256: _nonEmptyString(manifestInput['sha256']),
    standardFileInputs: standardFileInputs,
    artifactFileInputs: artifactFileInputs,
    blockers: blockers,
  );
  final runResultsAudit = _artifactRunResultsAudit(
    runResults: runResults,
    checksums: checksums,
    manifestRunId: manifestRunId,
    manifestRun: manifestRun,
    manifestTaskRuns: taskRuns,
    manifestArtifacts: artifacts,
    manifestEvaluatorIds: manifestEvaluatorIds,
    leaderboardTrialSummaries: leaderboardTrialSummaries,
    blockers: blockers,
  );
  final resultsCsvAudit = _artifactResultsCsvAudit(
    resultsCsv: resultsCsv,
    manifestRunId: manifestRunId,
    manifestTaskRuns: taskRuns,
    runResults: runResults,
    blockers: blockers,
  );
  final reportMarkdownAudit = _artifactReportMarkdownAudit(
    reportMarkdown: reportMarkdown,
    manifestRunId: manifestRunId,
    manifestTaskRuns: taskRuns,
    runResults: runResults,
    blockers: blockers,
  );
  final manifestPopulationSummaryAudit =
      _artifactManifestPopulationSummaryAudit(
        counts: counts,
        taskRuns: taskRuns,
        blockers: blockers,
      );
  final manifestMetadataAudit = _artifactManifestMetadataAudit(
    manifest: manifest,
    reportGeneratedAt: reportGeneratedAt,
    blockers: blockers,
  );
  final manifestRunMetadataAudit = _artifactManifestRunMetadataAudit(
    manifestRun: manifestRun,
    manifestGeneratedAt: _nonEmptyString(manifest['generatedAt']),
    blockers: blockers,
  );
  final manifestOutcomeSummaryAudit = _artifactManifestOutcomeSummaryAudit(
    manifest: manifest,
    runResults: runResults,
    blockers: blockers,
  );
  final manifestProvenanceAudit = _artifactManifestProvenanceAudit(
    provenanceValue: manifest['provenance'],
    manifestRunId: manifestRunId,
    blockers: blockers,
  );

  if (schemaVersion <= 0) {
    blockers.add('Run artifact bundle manifest schema version is missing.');
  } else if (!_artifactBundleManifestSchemaVersions.contains(schemaVersion)) {
    blockers.add(
      'Run artifact bundle manifest schema version $schemaVersion is unsupported.',
    );
  }
  if (manifestRunId == null) {
    blockers.add('Run artifact bundle manifest run id is missing.');
  } else if (!runIdInLeaderboardSource) {
    blockers.add(
      'Run artifact bundle manifest run id is not listed in leaderboard source run ids.',
    );
  }
  if (manifestTaskRunCount <= 0) {
    blockers.add('Run artifact bundle manifest has no task runs.');
  }
  if (manifestEvaluationCount <= 0) {
    blockers.add('Run artifact bundle manifest has no evaluations.');
  }
  if (manifestEvaluatorIdsValue is! List || manifestEvaluatorIds.isEmpty) {
    blockers.add('Run artifact bundle manifest evaluator id list is missing.');
  }
  if (invalidManifestEvaluatorIdCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $invalidManifestEvaluatorIdCount invalid evaluator id(s).',
    );
  }
  if (duplicateManifestEvaluatorIdCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $duplicateManifestEvaluatorIdCount duplicate evaluator id(s).',
    );
  }
  if (manifestTaskRunCount != taskRuns.length) {
    blockers.add(
      'Run artifact bundle manifest task run count does not match taskRuns.',
    );
  }
  if (manifestEvaluationCount != runResultsAudit['evaluationCount']) {
    blockers.add(
      'Run artifact bundle manifest evaluation count does not match run results.',
    );
  }
  if (manifestArtifactCount != artifacts.length) {
    blockers.add(
      'Run artifact bundle manifest artifact count does not match artifacts.',
    );
  }
  if (warnings is! List) {
    blockers.add('Run artifact bundle manifest warning list is missing.');
  } else if (manifestWarningCount != warningCount) {
    blockers.add(
      'Run artifact bundle manifest warning count does not match warnings.',
    );
  }
  if (checksumsPath == null) {
    blockers.add('Run artifact bundle manifest checksum path is missing.');
  } else if (!checksumsPathMatchesInput) {
    blockers.add(
      'Run artifact bundle manifest checksum path does not match the provided checksums input.',
    );
  }
  if (artifacts.isEmpty) {
    blockers.add('Run artifact bundle manifest has no exported artifacts.');
  }
  if (warningCount > 0) {
    blockers.add(
      'Run artifact bundle manifest contains $warningCount warning(s).',
    );
  }

  final artifactKindCounts = SplayTreeMap<String, int>();
  final responseTaskRunIds = <String>{};
  final patchTaskRunIds = <String>{};
  final seenArtifactReferences = <(String, String)>{};
  final seenArtifactIds = <String>{};
  var invalidArtifactCount = 0;
  var invalidArtifactIdCount = 0;
  var duplicateArtifactIdCount = 0;
  var unknownArtifactKindCount = 0;
  var duplicateArtifactReferenceCount = 0;
  var invalidArtifactDigestCount = 0;
  var unsafeArtifactPathCount = 0;
  var absoluteArtifactPathCount = 0;
  var parentArtifactPathCount = 0;
  var privateArtifactPathCount = 0;
  var outsideArtifactRootPathCount = 0;
  for (final artifact in artifacts) {
    final kind = _nonEmptyString(artifact['kind']);
    final taskRunId = _nonEmptyString(artifact['taskRunId']);
    final artifactId = _nonEmptyString(artifact['artifactId']);
    final path = _nonEmptyString(artifact['path']);
    final bytes = _intValue(artifact['bytes']);
    final artifactSha256 = _nonEmptyString(artifact['sha256']);
    if (kind == null || taskRunId == null || path == null || bytes <= 0) {
      invalidArtifactCount++;
      continue;
    }
    if (!_isSha256Digest(artifactSha256)) {
      invalidArtifactDigestCount++;
    }
    if (!_isArtifactId(artifactId)) {
      invalidArtifactIdCount++;
    } else if (!seenArtifactIds.add(artifactId!)) {
      duplicateArtifactIdCount++;
    }
    if (!_allowedArtifactBundleKinds.contains(kind)) {
      unknownArtifactKindCount++;
    }
    if (!seenArtifactReferences.add((taskRunId, kind))) {
      duplicateArtifactReferenceCount++;
    }
    final pathIssues = _artifactPathIssues(path);
    if (pathIssues.isNotEmpty) {
      unsafeArtifactPathCount++;
      if (pathIssues.contains('absolute')) absoluteArtifactPathCount++;
      if (pathIssues.contains('parent')) parentArtifactPathCount++;
      if (pathIssues.contains('private')) privateArtifactPathCount++;
      if (pathIssues.contains('outsideRoot')) outsideArtifactRootPathCount++;
      continue;
    }

    artifactKindCounts[kind] = (artifactKindCounts[kind] ?? 0) + 1;
    if (kind == 'response') responseTaskRunIds.add(taskRunId);
    if (kind == 'patch') patchTaskRunIds.add(taskRunId);
  }

  var agenticTaskRunCount = 0;
  var missingResponseArtifactCount = 0;
  var missingAgenticPatchArtifactCount = 0;
  var missingAgenticHarnessMetadataCount = 0;
  var missingLeaderboardTrialSummaryTaskRunCount = 0;
  var extraLeaderboardTrialSummaryTaskRunCount = 0;
  var invalidTaskRunModelIdentityCount = 0;
  var invalidTaskRunCount = 0;
  var duplicateTaskRunCount = 0;
  final seenTaskRunIds = <String>{};
  final artifactTaskRunKeys = <String>{};
  final leaderboardTrialSummaryKeys = {
    for (final trial in leaderboardTrialSummaries)
      if (_releaseTaskRunKey(trial) case final key?) key,
  };
  for (final taskRun in taskRuns) {
    final taskRunId = _nonEmptyString(taskRun['taskRunId']);
    final track = _taskRunTrack(taskRun);
    if (!_validTaskRunMetadata(taskRun, idKey: 'taskRunId')) {
      invalidTaskRunCount++;
    }
    if (!_validModelIdentityMetadata(taskRun)) {
      invalidTaskRunModelIdentityCount++;
    }
    if (taskRunId == null) {
      continue;
    }
    if (!seenTaskRunIds.add(taskRunId)) {
      duplicateTaskRunCount++;
      continue;
    }
    if (!responseTaskRunIds.contains(taskRunId)) {
      missingResponseArtifactCount++;
    }
    final artifactTaskRunKey = _releaseTaskRunKey(
      taskRun,
      fallbackRunId: manifestRunId,
    );
    if (artifactTaskRunKey != null) {
      artifactTaskRunKeys.add(artifactTaskRunKey);
    }
    if (track == 'agentic') {
      agenticTaskRunCount++;
      if (_nonEmptyString(taskRun['harnessId']) == null) {
        missingAgenticHarnessMetadataCount++;
      }
      if (!patchTaskRunIds.contains(taskRunId)) {
        missingAgenticPatchArtifactCount++;
      }
    }
  }
  missingLeaderboardTrialSummaryTaskRunCount = artifactTaskRunKeys
      .where((key) => !leaderboardTrialSummaryKeys.contains(key))
      .length;
  extraLeaderboardTrialSummaryTaskRunCount = leaderboardTrialSummaryKeys
      .where((key) => !artifactTaskRunKeys.contains(key))
      .length;

  if (invalidTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $invalidTaskRunCount invalid task run(s).',
    );
  }
  if (invalidTaskRunModelIdentityCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $invalidTaskRunModelIdentityCount task run(s) with invalid model identity metadata.',
    );
  }
  if (duplicateTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $duplicateTaskRunCount duplicate task run id(s).',
    );
  }
  if (invalidArtifactCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $invalidArtifactCount invalid artifact(s).',
    );
  }
  if (invalidArtifactDigestCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $invalidArtifactDigestCount invalid artifact digest(s).',
    );
  }
  if (invalidArtifactIdCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $invalidArtifactIdCount invalid artifact id(s).',
    );
  }
  if (duplicateArtifactIdCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $duplicateArtifactIdCount duplicate artifact id(s).',
    );
  }
  if (unknownArtifactKindCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $unknownArtifactKindCount unknown artifact kind(s).',
    );
  }
  if (duplicateArtifactReferenceCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $duplicateArtifactReferenceCount duplicate artifact reference(s).',
    );
  }
  if (unsafeArtifactPathCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has $unsafeArtifactPathCount unsafe artifact path(s).',
    );
  }
  if (missingResponseArtifactCount > 0) {
    blockers.add(
      'Run artifact bundle manifest is missing response artifacts for '
      '$missingResponseArtifactCount task run(s).',
    );
  }
  if (missingAgenticPatchArtifactCount > 0) {
    blockers.add(
      'Run artifact bundle manifest is missing patch artifacts for '
      '$missingAgenticPatchArtifactCount agentic task run(s).',
    );
  }
  if (missingAgenticHarnessMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle manifest is missing harness metadata for '
      '$missingAgenticHarnessMetadataCount agentic task run(s).',
    );
  }
  if (missingLeaderboardTrialSummaryTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle manifest has '
      '$missingLeaderboardTrialSummaryTaskRunCount task run(s) not represented '
      'in leaderboard trial summaries.',
    );
  }
  if (extraLeaderboardTrialSummaryTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle manifest is missing '
      '$extraLeaderboardTrialSummaryTaskRunCount leaderboard trial summary task run(s).',
    );
  }

  final complete =
      schemaVersion > 0 &&
      _artifactBundleManifestSchemaVersions.contains(schemaVersion) &&
      manifestRunId != null &&
      runIdInLeaderboardSource &&
      manifestTaskRunCount > 0 &&
      manifestEvaluationCount > 0 &&
      manifestEvaluatorIds.isNotEmpty &&
      invalidManifestEvaluatorIdCount == 0 &&
      duplicateManifestEvaluatorIdCount == 0 &&
      manifestTaskRunCount == taskRuns.length &&
      manifestEvaluationCount == runResultsAudit['evaluationCount'] &&
      manifestArtifactCount == artifacts.length &&
      warnings is List &&
      manifestWarningCount == warningCount &&
      warningCount == 0 &&
      checksumsPath != null &&
      artifacts.isNotEmpty &&
      invalidTaskRunCount == 0 &&
      duplicateTaskRunCount == 0 &&
      invalidArtifactCount == 0 &&
      invalidArtifactDigestCount == 0 &&
      invalidArtifactIdCount == 0 &&
      duplicateArtifactIdCount == 0 &&
      unknownArtifactKindCount == 0 &&
      duplicateArtifactReferenceCount == 0 &&
      unsafeArtifactPathCount == 0 &&
      missingResponseArtifactCount == 0 &&
      missingAgenticPatchArtifactCount == 0 &&
      missingAgenticHarnessMetadataCount == 0 &&
      missingLeaderboardTrialSummaryTaskRunCount == 0 &&
      extraLeaderboardTrialSummaryTaskRunCount == 0 &&
      invalidTaskRunModelIdentityCount == 0 &&
      manifestPopulationSummaryAudit['status'] == 'present' &&
      manifestMetadataAudit['status'] == 'present' &&
      manifestRunMetadataAudit['status'] == 'present' &&
      manifestOutcomeSummaryAudit['status'] == 'present' &&
      manifestProvenanceAudit['status'] == 'present' &&
      checksumAudit['status'] == 'present' &&
      runResultsAudit['status'] == 'present' &&
      resultsCsvAudit['status'] == 'present' &&
      reportMarkdownAudit['status'] == 'present' &&
      runResultsAudit['runIdMatchesManifest'] == true &&
      checksumsPathMatchesInput;

  return {
    'status': complete ? 'present' : 'incomplete',
    'schemaVersion': schemaVersion,
    'runId': manifestRunId,
    'runIdStatus': manifestRunId == null ? 'missing' : 'present',
    'runIdInLeaderboardSource': runIdInLeaderboardSource,
    'manifestPopulationSummaryStatus': manifestPopulationSummaryAudit['status'],
    'manifestTaskCountStatus': manifestPopulationSummaryAudit['taskStatus'],
    'manifestProviderCountStatus':
        manifestPopulationSummaryAudit['providerStatus'],
    'manifestModelCountStatus': manifestPopulationSummaryAudit['modelStatus'],
    'manifestTaskCount': manifestPopulationSummaryAudit['taskCount'],
    'manifestProviderCount': manifestPopulationSummaryAudit['providerCount'],
    'manifestModelCount': manifestPopulationSummaryAudit['modelCount'],
    'manifestDistinctTaskCount':
        manifestPopulationSummaryAudit['distinctTaskCount'],
    'manifestDistinctProviderCount':
        manifestPopulationSummaryAudit['distinctProviderCount'],
    'manifestDistinctModelCount':
        manifestPopulationSummaryAudit['distinctModelCount'],
    'manifestPopulationCountMismatchCount':
        manifestPopulationSummaryAudit['mismatchCount'],
    'manifestRunMetadataStatus': manifestRunMetadataAudit['status'],
    'manifestRunNameStatus': manifestRunMetadataAudit['nameStatus'],
    'manifestRunStartedAtStatus': manifestRunMetadataAudit['startedAtStatus'],
    'manifestRunCompletedAtStatus':
        manifestRunMetadataAudit['completedAtStatus'],
    'manifestRunDurationStatus': manifestRunMetadataAudit['durationStatus'],
    'manifestRunCompletedBeforeGeneratedAtStatus':
        manifestRunMetadataAudit['completedBeforeGeneratedAtStatus'],
    'manifestOutcomeSummaryStatus': manifestOutcomeSummaryAudit['status'],
    'manifestPassSummaryStatus':
        manifestOutcomeSummaryAudit['passSummaryStatus'],
    'manifestFailureSummaryStatus':
        manifestOutcomeSummaryAudit['failureSummaryStatus'],
    'manifestPassSummaryMismatchCount':
        manifestOutcomeSummaryAudit['passSummaryMismatchCount'],
    'manifestFailureSummaryMismatchCount':
        manifestOutcomeSummaryAudit['failureSummaryMismatchCount'],
    'taskRunCount': manifestTaskRunCount,
    'agenticTaskRunCount': agenticTaskRunCount,
    'evaluationCount': manifestEvaluationCount,
    'manifestEvaluatorIdCount': manifestEvaluatorIds.length,
    'invalidManifestEvaluatorIdCount': invalidManifestEvaluatorIdCount,
    'duplicateManifestEvaluatorIdCount': duplicateManifestEvaluatorIdCount,
    'artifactCount': manifestArtifactCount,
    'artifactKindCounts': artifactKindCounts,
    'responseArtifactCount': artifactKindCounts['response'] ?? 0,
    'patchArtifactCount': artifactKindCounts['patch'] ?? 0,
    'trajectoryArtifactCount': artifactKindCounts['trajectory'] ?? 0,
    'warningCount': warningCount,
    'warningCodeCounts': warningCodeCounts,
    'missingResponseArtifactCount': missingResponseArtifactCount,
    'missingAgenticPatchArtifactCount': missingAgenticPatchArtifactCount,
    'missingAgenticHarnessMetadataCount': missingAgenticHarnessMetadataCount,
    'missingLeaderboardTrialSummaryTaskRunCount':
        missingLeaderboardTrialSummaryTaskRunCount,
    'extraLeaderboardTrialSummaryTaskRunCount':
        extraLeaderboardTrialSummaryTaskRunCount,
    'invalidTaskRunModelIdentityCount': invalidTaskRunModelIdentityCount,
    'invalidTaskRunCount': invalidTaskRunCount,
    'duplicateTaskRunCount': duplicateTaskRunCount,
    'invalidArtifactCount': invalidArtifactCount,
    'invalidArtifactDigestCount': invalidArtifactDigestCount,
    'invalidArtifactIdCount': invalidArtifactIdCount,
    'duplicateArtifactIdCount': duplicateArtifactIdCount,
    'unknownArtifactKindCount': unknownArtifactKindCount,
    'duplicateArtifactReferenceCount': duplicateArtifactReferenceCount,
    'unsafeArtifactPathCount': unsafeArtifactPathCount,
    'absoluteArtifactPathCount': absoluteArtifactPathCount,
    'parentArtifactPathCount': parentArtifactPathCount,
    'privateArtifactPathCount': privateArtifactPathCount,
    'outsideArtifactRootPathCount': outsideArtifactRootPathCount,
    'manifestMetadataStatus': manifestMetadataAudit['status'],
    'manifestGeneratedAtStatus': manifestMetadataAudit['generatedAtStatus'],
    'manifestAppVersionStatus': manifestMetadataAudit['appVersionStatus'],
    'manifestDriftSchemaVersionStatus':
        manifestMetadataAudit['driftSchemaVersionStatus'],
    'manifestExportToolStatus': manifestMetadataAudit['exportToolStatus'],
    'manifestExportEnvironmentStatus':
        manifestMetadataAudit['environmentStatus'],
    'manifestExportEnvironmentGitStatus':
        manifestMetadataAudit['environmentGitStatus'],
    'manifestProvenanceStatus': manifestProvenanceAudit['status'],
    'manifestProvenanceRunId': manifestProvenanceAudit['runId'],
    'manifestProvenanceRunIdMatchesManifest':
        manifestProvenanceAudit['runIdMatchesManifest'],
    'manifestProvenanceSandboxStatus': manifestProvenanceAudit['sandboxStatus'],
    'manifestProvenanceSandboxBackend':
        manifestProvenanceAudit['sandboxBackend'],
    'manifestProvenanceTaskExecutionPolicyStatus':
        manifestProvenanceAudit['taskExecutionPolicyStatus'],
    'manifestProvenanceNetworkDisabledTaskPolicyStatus':
        manifestProvenanceAudit['networkDisabledTaskPolicyStatus'],
    'manifestProvenanceTaskResourceLimitStatus':
        manifestProvenanceAudit['taskResourceLimitStatus'],
    'manifestProvenanceSdkVersionStatus':
        manifestProvenanceAudit['sdkVersionStatus'],
    'manifestProvenanceDependencySnapshotStatus':
        manifestProvenanceAudit['dependencySnapshotStatus'],
    'manifestProvenancePricingRegistryStatus':
        manifestProvenanceAudit['pricingRegistryStatus'],
    'checksumsPath': checksumsPath,
    'checksumsPathStatus': checksumsPath == null ? 'missing' : 'present',
    'checksumSchemaVersion': checksumAudit['schemaVersion'],
    'checksumsStatus': checksumAudit['status'],
    'checksumAlgorithm': checksumAudit['algorithm'],
    'checksumFileCount': checksumAudit['fileCount'],
    'manifestChecksumStatus': checksumAudit['manifestChecksumStatus'],
    'manifestChecksumDigestStatus':
        checksumAudit['manifestChecksumDigestStatus'],
    'checksumsPathMatchesInput': checksumsPathMatchesInput,
    'coveredArtifactChecksumCount':
        checksumAudit['coveredArtifactChecksumCount'],
    'missingArtifactChecksumCount':
        checksumAudit['missingArtifactChecksumCount'],
    'coveredStandardChecksumCount':
        checksumAudit['coveredStandardChecksumCount'],
    'missingStandardChecksumCount':
        checksumAudit['missingStandardChecksumCount'],
    'verifiedStandardChecksumCount':
        checksumAudit['verifiedStandardChecksumCount'],
    'missingStandardInputCount': checksumAudit['missingStandardInputCount'],
    'mismatchedStandardChecksumCount':
        checksumAudit['mismatchedStandardChecksumCount'],
    'standardInputPathMismatchCount':
        checksumAudit['standardInputPathMismatchCount'],
    'verifiedArtifactFileCount': checksumAudit['verifiedArtifactFileCount'],
    'missingArtifactFileCount': checksumAudit['missingArtifactFileCount'],
    'mismatchedArtifactFileByteCount':
        checksumAudit['mismatchedArtifactFileByteCount'],
    'mismatchedArtifactFileDigestCount':
        checksumAudit['mismatchedArtifactFileDigestCount'],
    'mismatchedManifestArtifactDigestCount':
        checksumAudit['mismatchedManifestArtifactDigestCount'],
    'unexpectedChecksumPathCount': checksumAudit['unexpectedChecksumPathCount'],
    'unsafeChecksumPathCount': checksumAudit['unsafeChecksumPathCount'],
    'absoluteChecksumPathCount': checksumAudit['absoluteChecksumPathCount'],
    'parentChecksumPathCount': checksumAudit['parentChecksumPathCount'],
    'privateChecksumPathCount': checksumAudit['privateChecksumPathCount'],
    'outsideArtifactRootChecksumPathCount':
        checksumAudit['outsideArtifactRootChecksumPathCount'],
    'invalidChecksumEntryCount': checksumAudit['invalidChecksumEntryCount'],
    'duplicateChecksumPathCount': checksumAudit['duplicateChecksumPathCount'],
    'resultsCsvStatus': resultsCsvAudit['status'],
    'resultsCsvTaskRunCount': resultsCsvAudit['taskRunCount'],
    'missingResultsCsvHeaderCount': resultsCsvAudit['missingHeaderCount'],
    'invalidResultsCsvTaskRunCount': resultsCsvAudit['invalidTaskRunCount'],
    'duplicateResultsCsvTaskRunCount': resultsCsvAudit['duplicateTaskRunCount'],
    'missingResultsCsvTaskRunCount': resultsCsvAudit['missingTaskRunCount'],
    'extraResultsCsvTaskRunCount': resultsCsvAudit['extraTaskRunCount'],
    'mismatchedResultsCsvRunResultsCount':
        resultsCsvAudit['mismatchedRunResultsCount'],
    'invalidResultsCsvOutcomeCount': resultsCsvAudit['invalidOutcomeCount'],
    'reportMarkdownStatus': reportMarkdownAudit['status'],
    'reportMarkdownDeclaredTaskRunCount':
        reportMarkdownAudit['declaredTaskRunCount'],
    'reportMarkdownTaskRunCount': reportMarkdownAudit['taskRunCount'],
    'missingReportMarkdownSectionCount':
        reportMarkdownAudit['missingSectionCount'],
    'missingReportMarkdownColumnCount':
        reportMarkdownAudit['missingColumnCount'],
    'invalidReportMarkdownTaskRunCount':
        reportMarkdownAudit['invalidTaskRunCount'],
    'duplicateReportMarkdownTaskRunCount':
        reportMarkdownAudit['duplicateTaskRunCount'],
    'missingReportMarkdownTaskRunCount':
        reportMarkdownAudit['missingTaskRunCount'],
    'extraReportMarkdownTaskRunCount': reportMarkdownAudit['extraTaskRunCount'],
    'mismatchedReportMarkdownRunResultsCount':
        reportMarkdownAudit['mismatchedRunResultsCount'],
    'invalidReportMarkdownOutcomeCount':
        reportMarkdownAudit['invalidOutcomeCount'],
    'runResultsStatus': runResultsAudit['status'],
    'runResultsSchemaVersion': runResultsAudit['schemaVersion'],
    'runResultsRunId': runResultsAudit['runId'],
    'runResultsRunIdMatchesManifest': runResultsAudit['runIdMatchesManifest'],
    'runResultsRunMetadataStatus': runResultsAudit['runMetadataStatus'],
    'runResultsRunNameMatchesManifest':
        runResultsAudit['runNameMatchesManifest'],
    'runResultsRunStartedAtMatchesManifest':
        runResultsAudit['runStartedAtMatchesManifest'],
    'runResultsRunCompletedAtMatchesManifest':
        runResultsAudit['runCompletedAtMatchesManifest'],
    'mismatchedRunResultsRunMetadataFieldCount':
        runResultsAudit['mismatchedRunMetadataFieldCount'],
    'runResultsTaskRunCount': runResultsAudit['taskRunCount'],
    'runResultsEvaluationCount': runResultsAudit['evaluationCount'],
    'runResultsEvaluationCountMatchesManifest':
        manifestEvaluationCount == runResultsAudit['evaluationCount'],
    'runResultsEvaluatorIdCount': runResultsAudit['evaluatorIdCount'],
    'runResultsEvaluatorIdsMatchManifest':
        runResultsAudit['evaluatorIdsMatchManifest'],
    'missingRunResultsEvaluatorIdCount':
        runResultsAudit['missingEvaluatorIdCount'],
    'extraRunResultsEvaluatorIdCount': runResultsAudit['extraEvaluatorIdCount'],
    'missingRunResultsTaskRunCount': runResultsAudit['missingTaskRunCount'],
    'extraRunResultsTaskRunCount': runResultsAudit['extraTaskRunCount'],
    'mismatchedRunResultsTaskRunCount':
        runResultsAudit['mismatchedTaskRunCount'],
    'missingRunResultsAgenticHarnessMetadataCount':
        runResultsAudit['missingAgenticHarnessMetadataCount'],
    'mismatchedRunResultsAgenticHarnessMetadataCount':
        runResultsAudit['mismatchedAgenticHarnessMetadataCount'],
    'mismatchedRunResultsTaskRunRunIdCount':
        runResultsAudit['mismatchedTaskRunRunIdCount'],
    'mismatchedRunResultsTrialOutcomeCount':
        runResultsAudit['mismatchedTrialOutcomeCount'],
    'invalidRunResultsTrialOutcomeCount':
        runResultsAudit['invalidTrialOutcomeCount'],
    'invalidRunResultsTimingTaskRunCount':
        runResultsAudit['invalidTimingTaskRunCount'],
    'invalidRunResultsTokenUsageTaskRunCount':
        runResultsAudit['invalidTokenUsageTaskRunCount'],
    'missingRunResultsEvaluationTaskRunCount':
        runResultsAudit['missingEvaluationTaskRunCount'],
    'invalidRunResultsEvaluationCount':
        runResultsAudit['invalidEvaluationCount'],
    'invalidRunResultsEvaluationRationaleCount':
        runResultsAudit['invalidEvaluationRationaleCount'],
    'invalidRunResultsEvaluationDetailsMetadataCount':
        runResultsAudit['invalidEvaluationDetailsMetadataCount'],
    'invalidRunResultsBlockedEvaluationMetadataCount':
        runResultsAudit['invalidBlockedEvaluationMetadataCount'],
    'invalidRunResultsJudgeOverheadMetadataCount':
        runResultsAudit['invalidJudgeOverheadMetadataCount'],
    'missingRunResultsAgentHarnessStatusMetadataCount':
        runResultsAudit['missingAgentHarnessStatusMetadataCount'],
    'invalidRunResultsAgentHarnessStatusMetadataCount':
        runResultsAudit['invalidAgentHarnessStatusMetadataCount'],
    'duplicateRunResultsEvaluationIdCount':
        runResultsAudit['duplicateEvaluationIdCount'],
    'duplicateRunResultsTaskEvaluatorCount':
        runResultsAudit['duplicateTaskEvaluatorCount'],
    'missingRunResultsArtifactCount': runResultsAudit['missingArtifactCount'],
    'extraRunResultsArtifactCount': runResultsAudit['extraArtifactCount'],
    'mismatchedRunResultsArtifactCount':
        runResultsAudit['mismatchedArtifactCount'],
    'missingRunResultsArtifactMetadataCount':
        runResultsAudit['missingArtifactMetadataCount'],
    'invalidRunResultsArtifactMetadataEntryCount':
        runResultsAudit['invalidArtifactMetadataEntryCount'],
    'mismatchedRunResultsArtifactMetadataCount':
        runResultsAudit['mismatchedArtifactMetadataCount'],
    'invalidRunResultsArtifactIdCount':
        runResultsAudit['invalidArtifactIdCount'],
    'mismatchedRunResultsArtifactIdCount':
        runResultsAudit['mismatchedArtifactIdCount'],
    'invalidRunResultsArtifactMetadataCount':
        runResultsAudit['invalidArtifactMetadataCount'],
    'mismatchedRunResultsArtifactByteCount':
        runResultsAudit['mismatchedArtifactByteCount'],
    'mismatchedRunResultsArtifactDigestCount':
        runResultsAudit['mismatchedArtifactDigestCount'],
    'invalidRunResultsTaskRunCount': runResultsAudit['invalidTaskRunCount'],
    'invalidRunResultsTaskRunModelIdentityCount':
        runResultsAudit['invalidTaskRunModelIdentityCount'],
    'duplicateRunResultsTaskRunCount': runResultsAudit['duplicateTaskRunCount'],
  };
}

Map<String, Object?> _artifactChecksumAudit({
  required Map<String, Object?>? checksums,
  required List<Map<String, Object?>> manifestArtifacts,
  required String? manifestInputSha256,
  required Map<String, Map<String, Object?>> standardFileInputs,
  required Map<String, Map<String, Object?>> artifactFileInputs,
  required Set<String> blockers,
}) {
  if (checksums == null) {
    blockers.add('Run artifact bundle checksums were not provided.');
    return const {
      'status': 'missing',
      'schemaVersion': 0,
      'algorithm': null,
      'fileCount': 0,
      'manifestChecksumStatus': 'missing',
      'manifestChecksumDigestStatus': 'missing',
      'coveredArtifactChecksumCount': 0,
      'missingArtifactChecksumCount': 0,
      'coveredStandardChecksumCount': 0,
      'missingStandardChecksumCount': 0,
      'verifiedStandardChecksumCount': 0,
      'missingStandardInputCount': 0,
      'mismatchedStandardChecksumCount': 0,
      'standardInputPathMismatchCount': 0,
      'verifiedArtifactFileCount': 0,
      'missingArtifactFileCount': 0,
      'mismatchedArtifactFileByteCount': 0,
      'mismatchedArtifactFileDigestCount': 0,
      'mismatchedManifestArtifactDigestCount': 0,
      'unexpectedChecksumPathCount': 0,
      'unsafeChecksumPathCount': 0,
      'absoluteChecksumPathCount': 0,
      'parentChecksumPathCount': 0,
      'privateChecksumPathCount': 0,
      'outsideArtifactRootChecksumPathCount': 0,
      'invalidChecksumEntryCount': 0,
      'duplicateChecksumPathCount': 0,
    };
  }

  final schemaVersion = _intValue(checksums['schemaVersion']);
  final algorithm = _nonEmptyString(checksums['algorithm']);
  final filesValue = checksums['files'];
  final files = _objectMaps(filesValue);
  if (schemaVersion <= 0) {
    blockers.add('Run artifact bundle checksums schema version is missing.');
  } else if (schemaVersion != _artifactBundleChecksumsSchemaVersion) {
    blockers.add(
      'Run artifact bundle checksums schema version $schemaVersion is unsupported.',
    );
  }
  if (algorithm != 'sha256') {
    blockers.add('Run artifact bundle checksums must use sha256.');
  }
  if (filesValue is! List || files.isEmpty) {
    blockers.add('Run artifact bundle checksums file list is missing.');
  }

  final checksumsByPath = <String, String>{};
  final expectedPaths = {
    ..._requiredArtifactBundleChecksumPaths,
    for (final artifact in manifestArtifacts)
      if (_nonEmptyString(artifact['path']) case final path?) path,
  };
  var invalidChecksumEntryCount = 0;
  var duplicateChecksumPathCount = 0;
  var unexpectedChecksumPathCount = 0;
  var unsafeChecksumPathCount = 0;
  var absoluteChecksumPathCount = 0;
  var parentChecksumPathCount = 0;
  var privateChecksumPathCount = 0;
  var outsideArtifactRootChecksumPathCount = 0;
  for (final file in files) {
    final path = _nonEmptyString(file['path']);
    final sha256 = _nonEmptyString(file['sha256']);
    if (path == null ||
        sha256 == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      invalidChecksumEntryCount++;
      continue;
    }
    if (checksumsByPath.containsKey(path)) {
      duplicateChecksumPathCount++;
    } else {
      checksumsByPath[path] = sha256;
    }
    if (!expectedPaths.contains(path)) {
      unexpectedChecksumPathCount++;
    }
    final pathIssues = _checksumPathIssues(path);
    if (pathIssues.isNotEmpty) {
      unsafeChecksumPathCount++;
      if (pathIssues.contains('absolute')) absoluteChecksumPathCount++;
      if (pathIssues.contains('parent')) parentChecksumPathCount++;
      if (pathIssues.contains('private')) privateChecksumPathCount++;
      if (pathIssues.contains('outsideRoot')) {
        outsideArtifactRootChecksumPathCount++;
      }
    }
  }

  final manifestChecksum = checksumsByPath['manifest.json'];
  final manifestChecksumStatus = manifestChecksum != null
      ? 'present'
      : 'missing';
  if (manifestChecksumStatus == 'missing') {
    blockers.add('Run artifact bundle checksums are missing manifest.json.');
  }
  final manifestChecksumDigestStatus = switch ((
    manifestChecksum,
    manifestInputSha256,
  )) {
    (null, _) => 'missing',
    (_, null) => 'unverified',
    (final checksum?, final inputSha256?) =>
      checksum == inputSha256 ? 'matched' : 'mismatched',
  };
  if (manifestChecksumDigestStatus == 'unverified') {
    blockers.add(
      'Run artifact bundle manifest checksum cannot be verified without a manifest input fingerprint.',
    );
  } else if (manifestChecksumDigestStatus == 'mismatched') {
    blockers.add(
      'Run artifact bundle manifest checksum does not match the provided manifest input.',
    );
  }

  var coveredArtifactChecksumCount = 0;
  var missingArtifactChecksumCount = 0;
  var coveredStandardChecksumCount = 0;
  var missingStandardChecksumCount = 0;
  var verifiedStandardChecksumCount = 0;
  var missingStandardInputCount = 0;
  var mismatchedStandardChecksumCount = 0;
  var standardInputPathMismatchCount = 0;
  var verifiedArtifactFileCount = 0;
  var missingArtifactFileCount = 0;
  var mismatchedArtifactFileByteCount = 0;
  var mismatchedArtifactFileDigestCount = 0;
  var mismatchedManifestArtifactDigestCount = 0;
  for (final artifact in manifestArtifacts) {
    final path = _nonEmptyString(artifact['path']);
    if (path == null) continue;
    if (checksumsByPath.containsKey(path)) {
      coveredArtifactChecksumCount++;
    } else {
      missingArtifactChecksumCount++;
    }
    if (_artifactPathIssues(path).isNotEmpty) continue;
    final input = artifactFileInputs[path] ?? const <String, Object?>{};
    final inputSha256 = _nonEmptyString(input['sha256']);
    if (inputSha256 == null || input['bytes'] is! num) {
      missingArtifactFileCount++;
      continue;
    }
    if (_intValue(input['bytes']) != _intValue(artifact['bytes'])) {
      mismatchedArtifactFileByteCount++;
    }
    final checksumSha256 = checksumsByPath[path];
    final manifestSha256 = _nonEmptyString(artifact['sha256']);
    if (_isSha256Digest(manifestSha256) &&
        checksumSha256 != null &&
        manifestSha256 != checksumSha256) {
      mismatchedManifestArtifactDigestCount++;
    }
    if (checksumSha256 == null) continue;
    if (checksumSha256 == inputSha256) {
      verifiedArtifactFileCount++;
    } else {
      mismatchedArtifactFileDigestCount++;
    }
  }
  for (final path in _requiredArtifactBundleChecksumPaths) {
    if (checksumsByPath.containsKey(path)) {
      coveredStandardChecksumCount++;
    } else {
      missingStandardChecksumCount++;
    }
  }
  for (final path in _standardBundleFilePaths) {
    final input = standardFileInputs[path] ?? const <String, Object?>{};
    final inputPath = _nonEmptyString(input['path']);
    final inputSha256 = _nonEmptyString(input['sha256']);
    final checksumSha256 = checksumsByPath[path];
    if (inputPath == null || inputSha256 == null) {
      missingStandardInputCount++;
      continue;
    }
    if (inputPath != path) {
      standardInputPathMismatchCount++;
      continue;
    }
    if (checksumSha256 == null) {
      continue;
    }
    if (checksumSha256 == inputSha256) {
      verifiedStandardChecksumCount++;
    } else {
      mismatchedStandardChecksumCount++;
    }
  }

  if (invalidChecksumEntryCount > 0) {
    blockers.add(
      'Run artifact bundle checksums have $invalidChecksumEntryCount invalid file entry(s).',
    );
  }
  if (duplicateChecksumPathCount > 0) {
    blockers.add(
      'Run artifact bundle checksums have $duplicateChecksumPathCount duplicate file path(s).',
    );
  }
  if (unexpectedChecksumPathCount > 0) {
    blockers.add(
      'Run artifact bundle checksums have $unexpectedChecksumPathCount unexpected file path(s).',
    );
  }
  if (unsafeChecksumPathCount > 0) {
    blockers.add(
      'Run artifact bundle checksums have $unsafeChecksumPathCount unsafe file path(s).',
    );
  }
  if (missingArtifactChecksumCount > 0) {
    blockers.add(
      'Run artifact bundle checksums are missing $missingArtifactChecksumCount artifact file(s).',
    );
  }
  if (missingStandardChecksumCount > 0) {
    blockers.add(
      'Run artifact bundle checksums are missing $missingStandardChecksumCount standard bundle file(s).',
    );
  }
  if (missingStandardInputCount > 0) {
    blockers.add(
      'Run artifact bundle standard file inputs are missing $missingStandardInputCount file(s).',
    );
  }
  if (standardInputPathMismatchCount > 0) {
    blockers.add(
      'Run artifact bundle standard file inputs have $standardInputPathMismatchCount path mismatch(es).',
    );
  }
  if (mismatchedStandardChecksumCount > 0) {
    blockers.add(
      'Run artifact bundle standard file checksums mismatch $mismatchedStandardChecksumCount input file(s).',
    );
  }
  if (missingArtifactFileCount > 0) {
    blockers.add(
      'Run artifact bundle artifact file inputs are missing $missingArtifactFileCount file(s).',
    );
  }
  if (mismatchedArtifactFileByteCount > 0) {
    blockers.add(
      'Run artifact bundle artifact file byte counts mismatch $mismatchedArtifactFileByteCount file(s).',
    );
  }
  if (mismatchedArtifactFileDigestCount > 0) {
    blockers.add(
      'Run artifact bundle artifact file checksums mismatch $mismatchedArtifactFileDigestCount file(s).',
    );
  }
  if (mismatchedManifestArtifactDigestCount > 0) {
    blockers.add(
      'Run artifact bundle manifest artifact digests mismatch $mismatchedManifestArtifactDigestCount checksum entry(s).',
    );
  }

  final complete =
      schemaVersion > 0 &&
      schemaVersion == _artifactBundleChecksumsSchemaVersion &&
      algorithm == 'sha256' &&
      filesValue is List &&
      files.isNotEmpty &&
      manifestChecksumStatus == 'present' &&
      manifestChecksumDigestStatus == 'matched' &&
      invalidChecksumEntryCount == 0 &&
      duplicateChecksumPathCount == 0 &&
      unexpectedChecksumPathCount == 0 &&
      unsafeChecksumPathCount == 0 &&
      missingArtifactChecksumCount == 0 &&
      missingStandardChecksumCount == 0 &&
      missingStandardInputCount == 0 &&
      standardInputPathMismatchCount == 0 &&
      mismatchedStandardChecksumCount == 0 &&
      missingArtifactFileCount == 0 &&
      mismatchedArtifactFileByteCount == 0 &&
      mismatchedArtifactFileDigestCount == 0 &&
      mismatchedManifestArtifactDigestCount == 0;

  return {
    'status': complete ? 'present' : 'incomplete',
    'schemaVersion': schemaVersion,
    'algorithm': algorithm,
    'fileCount': files.length,
    'manifestChecksumStatus': manifestChecksumStatus,
    'manifestChecksumDigestStatus': manifestChecksumDigestStatus,
    'coveredArtifactChecksumCount': coveredArtifactChecksumCount,
    'missingArtifactChecksumCount': missingArtifactChecksumCount,
    'coveredStandardChecksumCount': coveredStandardChecksumCount,
    'missingStandardChecksumCount': missingStandardChecksumCount,
    'verifiedStandardChecksumCount': verifiedStandardChecksumCount,
    'missingStandardInputCount': missingStandardInputCount,
    'mismatchedStandardChecksumCount': mismatchedStandardChecksumCount,
    'standardInputPathMismatchCount': standardInputPathMismatchCount,
    'verifiedArtifactFileCount': verifiedArtifactFileCount,
    'missingArtifactFileCount': missingArtifactFileCount,
    'mismatchedArtifactFileByteCount': mismatchedArtifactFileByteCount,
    'mismatchedArtifactFileDigestCount': mismatchedArtifactFileDigestCount,
    'mismatchedManifestArtifactDigestCount':
        mismatchedManifestArtifactDigestCount,
    'unexpectedChecksumPathCount': unexpectedChecksumPathCount,
    'unsafeChecksumPathCount': unsafeChecksumPathCount,
    'absoluteChecksumPathCount': absoluteChecksumPathCount,
    'parentChecksumPathCount': parentChecksumPathCount,
    'privateChecksumPathCount': privateChecksumPathCount,
    'outsideArtifactRootChecksumPathCount':
        outsideArtifactRootChecksumPathCount,
    'invalidChecksumEntryCount': invalidChecksumEntryCount,
    'duplicateChecksumPathCount': duplicateChecksumPathCount,
  };
}

Map<String, Object?> _artifactManifestMetadataAudit({
  required Map<String, Object?> manifest,
  required DateTime reportGeneratedAt,
  required Set<String> blockers,
}) {
  final generatedAt = _nonEmptyString(manifest['generatedAt']);
  final parsedGeneratedAt = generatedAt == null
      ? null
      : DateTime.tryParse(generatedAt);
  final generatedAtStatus = generatedAt == null
      ? 'missing'
      : parsedGeneratedAt == null
      ? 'invalid'
      : parsedGeneratedAt.toUtc().isAfter(reportGeneratedAt.toUtc())
      ? 'future'
      : 'present';
  final appVersion = _nonEmptyString(manifest['appVersion']);
  final appVersionStatus = appVersion == null
      ? 'missing'
      : appVersion == 'unknown'
      ? 'unknown'
      : !_appVersionPattern.hasMatch(appVersion)
      ? 'invalid'
      : 'present';
  final driftSchemaVersionStatus = _intValue(manifest['driftSchemaVersion']) > 0
      ? 'present'
      : 'missing';
  final exportTool = _objectMap(manifest['exportTool']);
  final exportToolName = _nonEmptyString(exportTool['name']);
  final exportToolVersion = _nonEmptyString(exportTool['version']);
  final exportToolStatus = exportToolName == null || exportToolVersion == null
      ? 'missing'
      : exportToolName != 'dart_arena_export_bundle'
      ? 'unsupported'
      : int.tryParse(exportToolVersion) == null ||
            int.parse(exportToolVersion) <= 0
      ? 'invalid'
      : 'present';
  final environment = _objectMap(manifest['environment']);
  final dartVersion = _nonEmptyString(environment['dartVersion']);
  final flutterVersion = _nonEmptyString(environment['flutterVersion']);
  final gitCommit = _nonEmptyString(environment['gitCommit']);
  final hostPlatform = _nonEmptyString(environment['hostPlatform']);
  final locale = _nonEmptyString(environment['locale']);
  final operatingSystemVersion = _nonEmptyString(
    environment['operatingSystemVersion'],
  );
  final environmentStatus =
      dartVersion == null ||
          dartVersion == 'unknown' ||
          flutterVersion == null ||
          flutterVersion == 'unknown' ||
          hostPlatform == null ||
          locale == null ||
          operatingSystemVersion == null
      ? 'incomplete'
      : 'present';
  final gitDirty = environment['gitDirty'];
  final environmentGitStatus =
      gitCommit == null || gitCommit == 'unknown' || gitDirty is! bool
      ? 'missing'
      : !_gitCommitPattern.hasMatch(gitCommit)
      ? 'invalid'
      : gitDirty
      ? 'dirty'
      : 'clean';

  if (generatedAtStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest generatedAt timestamp is $generatedAtStatus.',
    );
  }
  if (appVersionStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest app version is $appVersionStatus.',
    );
  }
  if (driftSchemaVersionStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest drift schema version is missing.',
    );
  }
  if (exportToolStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest export tool metadata is $exportToolStatus.',
    );
  }
  if (environmentStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest export environment metadata is incomplete.',
    );
  }
  if (environmentGitStatus == 'missing') {
    blockers.add(
      'Run artifact bundle manifest export environment git metadata is missing.',
    );
  } else if (environmentGitStatus == 'invalid') {
    blockers.add(
      'Run artifact bundle manifest export environment git metadata is invalid.',
    );
  } else if (environmentGitStatus == 'dirty') {
    blockers.add(
      'Run artifact bundle manifest export environment records a dirty git worktree.',
    );
  }

  final complete =
      generatedAtStatus == 'present' &&
      appVersionStatus == 'present' &&
      driftSchemaVersionStatus == 'present' &&
      exportToolStatus == 'present' &&
      environmentStatus == 'present' &&
      environmentGitStatus == 'clean';
  return {
    'status': complete ? 'present' : 'incomplete',
    'generatedAtStatus': generatedAtStatus,
    'appVersionStatus': appVersionStatus,
    'driftSchemaVersionStatus': driftSchemaVersionStatus,
    'exportToolStatus': exportToolStatus,
    'environmentStatus': environmentStatus,
    'environmentGitStatus': environmentGitStatus,
  };
}

Map<String, Object?> _artifactManifestRunMetadataAudit({
  required Map<String, Object?> manifestRun,
  required String? manifestGeneratedAt,
  required Set<String> blockers,
}) {
  final name = _nonEmptyString(manifestRun['name']);
  final startedAt = _nonEmptyString(manifestRun['startedAt']);
  final completedAt = _nonEmptyString(manifestRun['completedAt']);
  final parsedStartedAt = startedAt == null
      ? null
      : DateTime.tryParse(startedAt);
  final parsedCompletedAt = completedAt == null
      ? null
      : DateTime.tryParse(completedAt);
  final parsedGeneratedAt = manifestGeneratedAt == null
      ? null
      : DateTime.tryParse(manifestGeneratedAt);
  final nameStatus = name == null ? 'missing' : 'present';
  final startedAtStatus = startedAt == null
      ? 'missing'
      : parsedStartedAt == null
      ? 'invalid'
      : 'present';
  final completedAtStatus = completedAt == null
      ? 'missing'
      : parsedCompletedAt == null
      ? 'invalid'
      : 'present';
  final durationStatus = parsedStartedAt == null || parsedCompletedAt == null
      ? 'unverified'
      : parsedCompletedAt.toUtc().isBefore(parsedStartedAt.toUtc())
      ? 'invalid'
      : 'valid';
  final completedBeforeGeneratedAtStatus =
      parsedCompletedAt == null || parsedGeneratedAt == null
      ? 'unverified'
      : parsedCompletedAt.toUtc().isAfter(parsedGeneratedAt.toUtc())
      ? 'invalid'
      : 'valid';

  if (nameStatus != 'present') {
    blockers.add('Run artifact bundle manifest run name is missing.');
  }
  if (startedAtStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest run startedAt timestamp is $startedAtStatus.',
    );
  }
  if (completedAtStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest run completedAt timestamp is $completedAtStatus.',
    );
  }
  if (durationStatus == 'invalid') {
    blockers.add(
      'Run artifact bundle manifest run completedAt timestamp is before startedAt.',
    );
  }
  if (completedBeforeGeneratedAtStatus == 'invalid') {
    blockers.add(
      'Run artifact bundle manifest run completedAt timestamp is after generatedAt.',
    );
  }

  final complete =
      nameStatus == 'present' &&
      startedAtStatus == 'present' &&
      completedAtStatus == 'present' &&
      durationStatus == 'valid' &&
      completedBeforeGeneratedAtStatus == 'valid';
  return {
    'status': complete ? 'present' : 'incomplete',
    'nameStatus': nameStatus,
    'startedAtStatus': startedAtStatus,
    'completedAtStatus': completedAtStatus,
    'durationStatus': durationStatus,
    'completedBeforeGeneratedAtStatus': completedBeforeGeneratedAtStatus,
  };
}

Map<String, Object?> _artifactManifestOutcomeSummaryAudit({
  required Map<String, Object?> manifest,
  required Map<String, Object?>? runResults,
  required Set<String> blockers,
}) {
  final passSummaryValue = manifest['passSummary'];
  final failureSummaryValue = manifest['failureSummary'];
  final passSummary = _objectMap(passSummaryValue);
  final failureSummary = _objectMap(failureSummaryValue);
  final runResultRows = _objectMaps(runResults?['taskRuns']);
  final expectedPassSummary = <String, int>{
    'primaryPassTrue': 0,
    'primaryPassFalse': 0,
    'primaryPassUnknown': 0,
    'evaluationPassCount': 0,
    'evaluationFailCount': 0,
  };
  final expectedFailureSummary = SplayTreeMap<String, int>();

  for (final row in runResultRows) {
    switch (row['primaryPass']) {
      case true:
        expectedPassSummary['primaryPassTrue'] =
            expectedPassSummary['primaryPassTrue']! + 1;
      case false:
        expectedPassSummary['primaryPassFalse'] =
            expectedPassSummary['primaryPassFalse']! + 1;
      default:
        expectedPassSummary['primaryPassUnknown'] =
            expectedPassSummary['primaryPassUnknown']! + 1;
    }
    final failureTag = _nonEmptyString(row['failureTag']) ?? 'unknown';
    expectedFailureSummary[failureTag] =
        (expectedFailureSummary[failureTag] ?? 0) + 1;
    for (final evaluation in _objectMaps(row['evaluations'])) {
      switch (evaluation['passed']) {
        case true:
          expectedPassSummary['evaluationPassCount'] =
              expectedPassSummary['evaluationPassCount']! + 1;
        case false:
          expectedPassSummary['evaluationFailCount'] =
              expectedPassSummary['evaluationFailCount']! + 1;
      }
    }
  }

  final passSummaryStatus = passSummaryValue is! Map
      ? 'missing'
      : expectedPassSummary.keys.every(
          (key) => passSummary[key] is num && _intValue(passSummary[key]) >= 0,
        )
      ? 'present'
      : 'incomplete';
  final failureSummaryStatus = failureSummaryValue is! Map
      ? 'missing'
      : failureSummary.entries.every(
          (entry) =>
              entry.key.trim().isNotEmpty &&
              entry.value is num &&
              _intValue(entry.value) >= 0,
        )
      ? 'present'
      : 'incomplete';

  var passSummaryMismatchCount = 0;
  if (passSummaryStatus == 'present') {
    for (final entry in expectedPassSummary.entries) {
      if (_intValue(passSummary[entry.key]) != entry.value) {
        passSummaryMismatchCount++;
      }
    }
  }

  var failureSummaryMismatchCount = 0;
  if (failureSummaryStatus == 'present') {
    for (final entry in expectedFailureSummary.entries) {
      if (_intValue(failureSummary[entry.key]) != entry.value) {
        failureSummaryMismatchCount++;
      }
    }
    for (final key in failureSummary.keys) {
      if (!expectedFailureSummary.containsKey(key)) {
        failureSummaryMismatchCount++;
      }
    }
  }

  if (runResultRows.isEmpty) {
    blockers.add(
      'Run artifact bundle manifest outcome summaries cannot be verified without run results task rows.',
    );
  }
  if (passSummaryStatus == 'missing') {
    blockers.add('Run artifact bundle manifest pass summary is missing.');
  } else if (passSummaryStatus == 'incomplete') {
    blockers.add('Run artifact bundle manifest pass summary is incomplete.');
  }
  if (failureSummaryStatus == 'missing') {
    blockers.add('Run artifact bundle manifest failure summary is missing.');
  } else if (failureSummaryStatus == 'incomplete') {
    blockers.add('Run artifact bundle manifest failure summary is incomplete.');
  }
  if (passSummaryMismatchCount > 0) {
    blockers.add(
      'Run artifact bundle manifest pass summary mismatches run results in '
      '$passSummaryMismatchCount field(s).',
    );
  }
  if (failureSummaryMismatchCount > 0) {
    blockers.add(
      'Run artifact bundle manifest failure summary mismatches run results in '
      '$failureSummaryMismatchCount tag(s).',
    );
  }

  final complete =
      runResultRows.isNotEmpty &&
      passSummaryStatus == 'present' &&
      failureSummaryStatus == 'present' &&
      passSummaryMismatchCount == 0 &&
      failureSummaryMismatchCount == 0;
  return {
    'status': complete ? 'present' : 'incomplete',
    'passSummaryStatus': passSummaryStatus,
    'failureSummaryStatus': failureSummaryStatus,
    'passSummaryMismatchCount': passSummaryMismatchCount,
    'failureSummaryMismatchCount': failureSummaryMismatchCount,
  };
}

Map<String, Object?> _artifactManifestPopulationSummaryAudit({
  required Map<String, Object?> counts,
  required List<Map<String, Object?>> taskRuns,
  required Set<String> blockers,
}) {
  final taskCount = _intValue(counts['taskCount']);
  final providerCount = _intValue(counts['providerCount']);
  final modelCount = _intValue(counts['modelCount']);
  final distinctTaskCount = {
    for (final taskRun in taskRuns)
      if (_nonEmptyString(taskRun['taskId']) case final taskId?) taskId,
  }.length;
  final distinctProviderCount = {
    for (final taskRun in taskRuns)
      if (_nonEmptyString(taskRun['providerId']) case final providerId?)
        providerId,
  }.length;
  final distinctModelCount = {
    for (final taskRun in taskRuns)
      if (_nonEmptyString(taskRun['modelId']) case final modelId?) modelId,
  }.length;

  final taskStatus = _manifestPopulationCountStatus(
    declaredCount: taskCount,
    expectedCount: distinctTaskCount,
  );
  final providerStatus = _manifestPopulationCountStatus(
    declaredCount: providerCount,
    expectedCount: distinctProviderCount,
  );
  final modelStatus = _manifestPopulationCountStatus(
    declaredCount: modelCount,
    expectedCount: distinctModelCount,
  );

  if (taskStatus == 'missing') {
    blockers.add('Run artifact bundle manifest task count is missing.');
  } else if (taskStatus == 'mismatched') {
    blockers.add(
      'Run artifact bundle manifest task count does not match taskRuns.',
    );
  }
  if (providerStatus == 'missing') {
    blockers.add('Run artifact bundle manifest provider count is missing.');
  } else if (providerStatus == 'mismatched') {
    blockers.add(
      'Run artifact bundle manifest provider count does not match taskRuns.',
    );
  }
  if (modelStatus == 'missing') {
    blockers.add('Run artifact bundle manifest model count is missing.');
  } else if (modelStatus == 'mismatched') {
    blockers.add(
      'Run artifact bundle manifest model count does not match taskRuns.',
    );
  }

  final mismatchCount = [
    taskStatus,
    providerStatus,
    modelStatus,
  ].where((status) => status == 'mismatched').length;
  final complete =
      taskStatus == 'present' &&
      providerStatus == 'present' &&
      modelStatus == 'present';

  return {
    'status': complete ? 'present' : 'incomplete',
    'taskStatus': taskStatus,
    'providerStatus': providerStatus,
    'modelStatus': modelStatus,
    'taskCount': taskCount,
    'providerCount': providerCount,
    'modelCount': modelCount,
    'distinctTaskCount': distinctTaskCount,
    'distinctProviderCount': distinctProviderCount,
    'distinctModelCount': distinctModelCount,
    'mismatchCount': mismatchCount,
  };
}

String _manifestPopulationCountStatus({
  required int declaredCount,
  required int expectedCount,
}) {
  if (declaredCount <= 0) return 'missing';
  if (declaredCount != expectedCount) return 'mismatched';
  return 'present';
}

Map<String, Object?> _artifactManifestProvenanceAudit({
  required Object? provenanceValue,
  required String? manifestRunId,
  required Set<String> blockers,
}) {
  if (provenanceValue is! Map) {
    blockers.add('Run artifact bundle manifest provenance is missing.');
    return const {
      'status': 'missing',
      'runId': null,
      'runIdMatchesManifest': false,
      'sandboxStatus': 'missing',
      'sandboxBackend': null,
      'taskExecutionPolicyStatus': 'missing',
      'networkDisabledTaskPolicyStatus': 'missing',
      'taskResourceLimitStatus': 'missing',
      'sdkVersionStatus': 'missing',
      'dependencySnapshotStatus': 'missing',
      'pricingRegistryStatus': 'missing',
    };
  }

  final provenance = _objectMap(provenanceValue);
  final runId = _nonEmptyString(provenance['runId']);
  final runIdMatchesManifest =
      runId != null && manifestRunId != null && runId == manifestRunId;
  final sandboxStatus = _generatedCodeSandboxStatus(provenance);
  final taskExecutionPolicyStatus = _taskExecutionPolicyStatus(provenance);
  final networkDisabledTaskPolicyStatus = _networkDisabledTaskPolicyStatus(
    provenance,
  );
  final taskResourceLimitStatus = _taskResourceLimitStatus(provenance);
  final sdkVersionStatus = _sdkVersionStatus(provenance);
  final dependencySnapshotStatus = _dependencySnapshotStatus(provenance);
  final pricingRegistryStatus = _pricingRegistryStatus(provenance);

  if (runId == null) {
    blockers.add('Run artifact bundle manifest provenance run id is missing.');
  } else if (!runIdMatchesManifest) {
    blockers.add(
      'Run artifact bundle manifest provenance run id does not match the manifest.',
    );
  }
  if (sandboxStatus['status'] != 'enforced') {
    blockers.add(
      'Run artifact bundle manifest provenance does not record generated-code sandbox enforcement.',
    );
  }
  if (taskExecutionPolicyStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest provenance has incomplete task execution policy.',
    );
  }
  if (networkDisabledTaskPolicyStatus == 'enabled') {
    blockers.add(
      'Run artifact bundle manifest provenance records network-enabled generated-code task policy.',
    );
  } else if (networkDisabledTaskPolicyStatus != 'disabled') {
    blockers.add(
      'Run artifact bundle manifest provenance has incomplete network-disabled task policy.',
    );
  }
  if (taskResourceLimitStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest provenance has incomplete or unenforced task resource limits.',
    );
  }
  if (sdkVersionStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest provenance has incomplete SDK versions.',
    );
  }
  if (dependencySnapshotStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest provenance has incomplete dependency lockfile snapshot.',
    );
  }
  if (pricingRegistryStatus != 'present') {
    blockers.add(
      'Run artifact bundle manifest provenance has incomplete pricing registry.',
    );
  }

  final complete =
      runIdMatchesManifest &&
      sandboxStatus['status'] == 'enforced' &&
      taskExecutionPolicyStatus == 'present' &&
      networkDisabledTaskPolicyStatus == 'disabled' &&
      taskResourceLimitStatus == 'present' &&
      sdkVersionStatus == 'present' &&
      dependencySnapshotStatus == 'present' &&
      pricingRegistryStatus == 'present';
  return {
    'status': complete ? 'present' : 'incomplete',
    'runId': runId,
    'runIdMatchesManifest': runIdMatchesManifest,
    'sandboxStatus': sandboxStatus['status'],
    'sandboxBackend': _nonEmptyString(sandboxStatus['backend']),
    'taskExecutionPolicyStatus': taskExecutionPolicyStatus,
    'networkDisabledTaskPolicyStatus': networkDisabledTaskPolicyStatus,
    'taskResourceLimitStatus': taskResourceLimitStatus,
    'sdkVersionStatus': sdkVersionStatus,
    'dependencySnapshotStatus': dependencySnapshotStatus,
    'pricingRegistryStatus': pricingRegistryStatus,
  };
}

Map<String, Object?> _artifactReportMarkdownAudit({
  required String? reportMarkdown,
  required String? manifestRunId,
  required List<Map<String, Object?>> manifestTaskRuns,
  required Map<String, Object?>? runResults,
  required Set<String> blockers,
}) {
  if (reportMarkdown == null) {
    blockers.add('Run artifact bundle report markdown was not provided.');
    return const {
      'status': 'missing',
      'declaredTaskRunCount': 0,
      'taskRunCount': 0,
      'missingSectionCount': 0,
      'missingColumnCount': 0,
      'invalidTaskRunCount': 0,
      'duplicateTaskRunCount': 0,
      'missingTaskRunCount': 0,
      'extraTaskRunCount': 0,
      'mismatchedRunResultsCount': 0,
      'invalidOutcomeCount': 0,
    };
  }

  final lines = reportMarkdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final hasTitle = lines.any((line) => line.trim() == '# Benchmark run');
  final hasLeaderboardSummary = lines.any(
    (line) => line.trim() == '## Leaderboard summary',
  );
  final taskRunsSectionIndex = lines.indexWhere(
    (line) => line.trim() == '## Task runs',
  );
  final declaredTaskRunCount = _reportMarkdownDeclaredTaskRunCount(lines);
  final taskHeaderIndex = taskRunsSectionIndex < 0
      ? -1
      : lines.indexWhere((line) {
          final cells = _markdownTableCells(line);
          return cells.contains('Task') &&
              cells.contains('Provider') &&
              cells.contains('Model') &&
              cells.contains('Trial');
        }, taskRunsSectionIndex + 1);
  final missingSectionCount =
      (hasTitle ? 0 : 1) +
      (declaredTaskRunCount == null ? 1 : 0) +
      (hasLeaderboardSummary ? 0 : 1) +
      (taskRunsSectionIndex < 0 ? 1 : 0) +
      (taskHeaderIndex < 0 ? 1 : 0);

  final header = taskHeaderIndex < 0
      ? const <String>[]
      : _markdownTableCells(lines[taskHeaderIndex]);
  final headerIndexes = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    headerIndexes.putIfAbsent(header[i], () => i);
  }
  final missingColumnCount = _requiredReportMarkdownTaskColumns
      .where((column) => !headerIndexes.containsKey(column))
      .length;

  final markdownTaskRunsByKey = <String, Map<String, Object?>>{};
  var taskRunCount = 0;
  var invalidTaskRunCount = 0;
  var duplicateTaskRunCount = 0;
  var invalidOutcomeCount = 0;
  if (taskHeaderIndex >= 0 && missingColumnCount == 0) {
    for (var i = taskHeaderIndex + 1; i < lines.length; i++) {
      final cells = _markdownTableCells(lines[i]);
      if (cells.isEmpty) break;
      if (cells.every((cell) => RegExp(r'^-+$').hasMatch(cell))) continue;
      taskRunCount++;
      final taskRun = _reportMarkdownTaskRun(cells, headerIndexes);
      if (_releaseTaskRunKey(taskRun, fallbackRunId: manifestRunId)
          case final key?) {
        if (!markdownTaskRunsByKey.containsKey(key)) {
          markdownTaskRunsByKey[key] = taskRun;
        } else {
          duplicateTaskRunCount++;
        }
      } else {
        invalidTaskRunCount++;
      }
      if (!_validRunResultsTrialOutcome(taskRun)) {
        invalidOutcomeCount++;
      }
    }
  }

  final manifestTaskRunKeys = {
    for (final taskRun in manifestTaskRuns)
      if (_releaseTaskRunKey(taskRun, fallbackRunId: manifestRunId)
          case final key?)
        key,
  };
  final missingTaskRunCount = manifestTaskRunKeys
      .where((key) => !markdownTaskRunsByKey.containsKey(key))
      .length;
  final extraTaskRunCount = markdownTaskRunsByKey.keys
      .where((key) => !manifestTaskRunKeys.contains(key))
      .length;

  final runResultsByKey = {
    for (final taskRun in _objectMaps(runResults?['taskRuns']))
      if (_releaseTaskRunKey(taskRun) case final key?) key: taskRun,
  };
  var mismatchedRunResultsCount = 0;
  for (final entry in markdownTaskRunsByKey.entries) {
    final runResult = runResultsByKey[entry.key];
    if (runResult != null &&
        !_reportMarkdownOutcomeMatchesRunResult(entry.value, runResult)) {
      mismatchedRunResultsCount++;
    }
  }

  if (missingSectionCount > 0) {
    blockers.add(
      'Run artifact bundle report markdown is missing $missingSectionCount required section(s).',
    );
  }
  if (missingColumnCount > 0) {
    blockers.add(
      'Run artifact bundle report markdown task table is missing $missingColumnCount required column(s).',
    );
  }
  if (declaredTaskRunCount != null &&
      declaredTaskRunCount != taskRunCount &&
      missingColumnCount == 0) {
    blockers.add(
      'Run artifact bundle report markdown task-run count does not match task rows.',
    );
  }
  if (invalidTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle report markdown has $invalidTaskRunCount invalid task run row(s).',
    );
  }
  if (duplicateTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle report markdown has $duplicateTaskRunCount duplicate task run row(s).',
    );
  }
  if (missingTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle report markdown is missing $missingTaskRunCount manifest task run(s).',
    );
  }
  if (extraTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle report markdown contains $extraTaskRunCount extra task run(s).',
    );
  }
  if (mismatchedRunResultsCount > 0) {
    blockers.add(
      'Run artifact bundle report markdown mismatches $mismatchedRunResultsCount run results task outcome(s).',
    );
  }
  if (invalidOutcomeCount > 0) {
    blockers.add(
      'Run artifact bundle report markdown has $invalidOutcomeCount invalid task-run outcome(s).',
    );
  }

  final countMatches =
      declaredTaskRunCount != null && declaredTaskRunCount == taskRunCount;
  final complete =
      taskRunCount > 0 &&
      countMatches &&
      missingSectionCount == 0 &&
      missingColumnCount == 0 &&
      invalidTaskRunCount == 0 &&
      duplicateTaskRunCount == 0 &&
      missingTaskRunCount == 0 &&
      extraTaskRunCount == 0 &&
      mismatchedRunResultsCount == 0 &&
      invalidOutcomeCount == 0;

  return {
    'status': complete ? 'present' : 'incomplete',
    'declaredTaskRunCount': declaredTaskRunCount ?? 0,
    'taskRunCount': taskRunCount,
    'missingSectionCount': missingSectionCount,
    'missingColumnCount': missingColumnCount,
    'invalidTaskRunCount': invalidTaskRunCount,
    'duplicateTaskRunCount': duplicateTaskRunCount,
    'missingTaskRunCount': missingTaskRunCount,
    'extraTaskRunCount': extraTaskRunCount,
    'mismatchedRunResultsCount': mismatchedRunResultsCount,
    'invalidOutcomeCount': invalidOutcomeCount,
  };
}

int? _reportMarkdownDeclaredTaskRunCount(List<String> lines) {
  final pattern = RegExp(r'\bTask-runs:\s*(\d+)\b');
  for (final line in lines) {
    final match = pattern.firstMatch(line);
    if (match != null) return int.tryParse(match.group(1)!);
  }
  return null;
}

List<String> _markdownTableCells(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) {
    return const [];
  }
  final cells = trimmed.split('|').map((cell) => cell.trim()).toList();
  if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
  if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
  return cells;
}

Map<String, Object?> _reportMarkdownTaskRun(
  List<String> row,
  Map<String, int> headerIndexes,
) {
  String? value(String header) {
    final index = headerIndexes[header];
    if (index == null || index >= row.length) return null;
    final cell = row[index].trim();
    return cell.isEmpty ? null : cell;
  }

  return {
    'taskId': value('Task'),
    'providerId': value('Provider'),
    'modelId': value('Model'),
    'trialIndex': int.tryParse(value('Trial') ?? ''),
    'taskVersion': int.tryParse(value('Task Version') ?? ''),
    'benchmarkTrack': value('Track'),
    'primaryPass': _parseBool(value('Primary Pass')),
    'failureTag': value('Failure'),
    'aggregateScore': _parseMarkdownNumber(value('Aggregate')),
  };
}

double? _parseMarkdownNumber(String? value) {
  if (value == null) return null;
  final cleaned = value.replaceAll('*', '').trim();
  return double.tryParse(cleaned);
}

bool _reportMarkdownOutcomeMatchesRunResult(
  Map<String, Object?> markdownRow,
  Map<String, Object?> runResult,
) {
  return markdownRow['primaryPass'] == runResult['primaryPass'] &&
      _nonEmptyString(markdownRow['failureTag']) ==
          _nonEmptyString(runResult['failureTag']) &&
      _numMatchesWithTolerance(
        markdownRow['aggregateScore'],
        runResult['aggregateScore'],
        0.005,
      );
}

Map<String, Object?> _artifactResultsCsvAudit({
  required String? resultsCsv,
  required String? manifestRunId,
  required List<Map<String, Object?>> manifestTaskRuns,
  required Map<String, Object?>? runResults,
  required Set<String> blockers,
}) {
  if (resultsCsv == null) {
    blockers.add('Run artifact bundle results CSV was not provided.');
    return const {
      'status': 'missing',
      'taskRunCount': 0,
      'missingHeaderCount': 0,
      'invalidTaskRunCount': 0,
      'duplicateTaskRunCount': 0,
      'missingTaskRunCount': 0,
      'extraTaskRunCount': 0,
      'mismatchedRunResultsCount': 0,
      'invalidOutcomeCount': 0,
    };
  }

  final parsed = _parseCsvRows(resultsCsv);
  final rows = parsed.rows;
  final headerIndex = rows.indexWhere((row) => !_blankCsvRow(row));
  if (!parsed.valid || headerIndex < 0) {
    blockers.add('Run artifact bundle results CSV is malformed.');
    return {
      'status': 'incomplete',
      'taskRunCount': 0,
      'missingHeaderCount': _requiredResultsCsvColumns.length,
      'invalidTaskRunCount': 0,
      'duplicateTaskRunCount': 0,
      'missingTaskRunCount': 0,
      'extraTaskRunCount': 0,
      'mismatchedRunResultsCount': 0,
      'invalidOutcomeCount': 0,
    };
  }

  final header = rows[headerIndex].map((cell) => cell.trim()).toList();
  final headerIndexes = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    headerIndexes.putIfAbsent(header[i], () => i);
  }
  final missingHeaderCount = _requiredResultsCsvColumns
      .where((column) => !headerIndexes.containsKey(column))
      .length;

  final csvTaskRunsByKey = <String, Map<String, Object?>>{};
  var taskRunCount = 0;
  var invalidTaskRunCount = 0;
  var duplicateTaskRunCount = 0;
  var invalidOutcomeCount = 0;
  if (missingHeaderCount == 0) {
    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (_blankCsvRow(row)) break;
      if (row.isNotEmpty && row.first.trim() == 'leaderboard_summary') break;
      taskRunCount++;
      final taskRun = _resultsCsvTaskRun(row, headerIndexes);
      if (_releaseTaskRunKey(taskRun) case final key?) {
        if (!csvTaskRunsByKey.containsKey(key)) {
          csvTaskRunsByKey[key] = taskRun;
        } else {
          duplicateTaskRunCount++;
        }
      } else {
        invalidTaskRunCount++;
      }
      if (!_validRunResultsTrialOutcome(taskRun)) {
        invalidOutcomeCount++;
      }
    }
  }

  final manifestTaskRunKeys = {
    for (final taskRun in manifestTaskRuns)
      if (_releaseTaskRunKey(taskRun, fallbackRunId: manifestRunId)
          case final key?)
        key,
  };
  final missingTaskRunCount = manifestTaskRunKeys
      .where((key) => !csvTaskRunsByKey.containsKey(key))
      .length;
  final extraTaskRunCount = csvTaskRunsByKey.keys
      .where((key) => !manifestTaskRunKeys.contains(key))
      .length;

  final runResultsByKey = {
    for (final taskRun in _objectMaps(runResults?['taskRuns']))
      if (_releaseTaskRunKey(taskRun) case final key?) key: taskRun,
  };
  var mismatchedRunResultsCount = 0;
  for (final entry in csvTaskRunsByKey.entries) {
    final runResult = runResultsByKey[entry.key];
    if (runResult != null &&
        !_resultsCsvOutcomeMatchesRunResult(entry.value, runResult)) {
      mismatchedRunResultsCount++;
    }
  }

  if (missingHeaderCount > 0) {
    blockers.add(
      'Run artifact bundle results CSV is missing $missingHeaderCount required column(s).',
    );
  }
  if (invalidTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle results CSV has $invalidTaskRunCount invalid task run row(s).',
    );
  }
  if (duplicateTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle results CSV has $duplicateTaskRunCount duplicate task run row(s).',
    );
  }
  if (missingTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle results CSV is missing $missingTaskRunCount manifest task run(s).',
    );
  }
  if (extraTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle results CSV contains $extraTaskRunCount extra task run(s).',
    );
  }
  if (mismatchedRunResultsCount > 0) {
    blockers.add(
      'Run artifact bundle results CSV mismatches $mismatchedRunResultsCount run results task outcome(s).',
    );
  }
  if (invalidOutcomeCount > 0) {
    blockers.add(
      'Run artifact bundle results CSV has $invalidOutcomeCount invalid task-run outcome(s).',
    );
  }

  final complete =
      parsed.valid &&
      taskRunCount > 0 &&
      missingHeaderCount == 0 &&
      invalidTaskRunCount == 0 &&
      duplicateTaskRunCount == 0 &&
      missingTaskRunCount == 0 &&
      extraTaskRunCount == 0 &&
      mismatchedRunResultsCount == 0 &&
      invalidOutcomeCount == 0;

  return {
    'status': complete ? 'present' : 'incomplete',
    'taskRunCount': taskRunCount,
    'missingHeaderCount': missingHeaderCount,
    'invalidTaskRunCount': invalidTaskRunCount,
    'duplicateTaskRunCount': duplicateTaskRunCount,
    'missingTaskRunCount': missingTaskRunCount,
    'extraTaskRunCount': extraTaskRunCount,
    'mismatchedRunResultsCount': mismatchedRunResultsCount,
    'invalidOutcomeCount': invalidOutcomeCount,
  };
}

Map<String, Object?> _resultsCsvTaskRun(
  List<String> row,
  Map<String, int> headerIndexes,
) {
  String? value(String header) {
    final index = headerIndexes[header];
    if (index == null || index >= row.length) return null;
    final cell = row[index].trim();
    return cell.isEmpty ? null : cell;
  }

  return {
    'runId': value('run_id'),
    'taskId': value('task_id'),
    'providerId': value('provider_id'),
    'modelId': value('model_id'),
    'trialIndex': int.tryParse(value('trial_index') ?? ''),
    'taskVersion': int.tryParse(value('task_version') ?? ''),
    'benchmarkTrack': value('benchmark_track'),
    'primaryPass': _parseBool(value('primary_pass')),
    'failureTag': value('failure_tag'),
    'aggregateScore': double.tryParse(value('aggregate_score') ?? ''),
  };
}

bool _resultsCsvOutcomeMatchesRunResult(
  Map<String, Object?> csvRow,
  Map<String, Object?> runResult,
) {
  return csvRow['primaryPass'] == runResult['primaryPass'] &&
      _nonEmptyString(csvRow['failureTag']) ==
          _nonEmptyString(runResult['failureTag']) &&
      _numMatchesWithTolerance(
        csvRow['aggregateScore'],
        runResult['aggregateScore'],
        0.0001,
      );
}

bool? _parseBool(String? value) {
  return switch (value?.toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}

({List<List<String>> rows, bool valid}) _parseCsvRows(String source) {
  final rows = <List<String>>[];
  final row = <String>[];
  final cell = StringBuffer();
  var valid = true;
  var inQuotes = false;

  void finishCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void finishRow() {
    finishCell();
    rows.add(List.unmodifiable(row));
    row.clear();
  }

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(char);
      }
      continue;
    }

    if (char == '"') {
      if (cell.isEmpty) {
        inQuotes = true;
      } else {
        valid = false;
        cell.write(char);
      }
    } else if (char == ',') {
      finishCell();
    } else if (char == '\n') {
      finishRow();
    } else if (char == '\r') {
      if (i + 1 < source.length && source[i + 1] == '\n') i++;
      finishRow();
    } else {
      cell.write(char);
    }
  }

  if (inQuotes) valid = false;
  if (cell.isNotEmpty || row.isNotEmpty || source.endsWith(',')) {
    finishRow();
  }

  return (rows: rows, valid: valid);
}

bool _blankCsvRow(List<String> row) => row.every((cell) => cell.trim().isEmpty);

Map<String, Object?> _artifactRunResultsAudit({
  required Map<String, Object?>? runResults,
  required Map<String, Object?>? checksums,
  required String? manifestRunId,
  required Map<String, Object?> manifestRun,
  required List<Map<String, Object?>> manifestTaskRuns,
  required List<Map<String, Object?>> manifestArtifacts,
  required Set<String> manifestEvaluatorIds,
  required List<Map<String, Object?>> leaderboardTrialSummaries,
  required Set<String> blockers,
}) {
  if (runResults == null) {
    blockers.add('Run artifact bundle run results were not provided.');
    return const {
      'status': 'missing',
      'schemaVersion': 0,
      'runId': null,
      'runIdMatchesManifest': false,
      'runMetadataStatus': 'missing',
      'runNameMatchesManifest': false,
      'runStartedAtMatchesManifest': false,
      'runCompletedAtMatchesManifest': false,
      'mismatchedRunMetadataFieldCount': 0,
      'taskRunCount': 0,
      'evaluationCount': 0,
      'evaluatorIdCount': 0,
      'evaluatorIdsMatchManifest': false,
      'missingEvaluatorIdCount': 0,
      'extraEvaluatorIdCount': 0,
      'missingTaskRunCount': 0,
      'extraTaskRunCount': 0,
      'mismatchedTaskRunCount': 0,
      'missingAgenticHarnessMetadataCount': 0,
      'mismatchedAgenticHarnessMetadataCount': 0,
      'mismatchedTaskRunRunIdCount': 0,
      'invalidTaskRunModelIdentityCount': 0,
      'mismatchedTrialOutcomeCount': 0,
      'invalidTrialOutcomeCount': 0,
      'invalidTimingTaskRunCount': 0,
      'invalidTokenUsageTaskRunCount': 0,
      'missingEvaluationTaskRunCount': 0,
      'invalidEvaluationCount': 0,
      'invalidEvaluationRationaleCount': 0,
      'invalidEvaluationDetailsMetadataCount': 0,
      'invalidBlockedEvaluationMetadataCount': 0,
      'invalidJudgeOverheadMetadataCount': 0,
      'duplicateEvaluationIdCount': 0,
      'duplicateTaskEvaluatorCount': 0,
      'missingArtifactCount': 0,
      'extraArtifactCount': 0,
      'mismatchedArtifactCount': 0,
      'missingArtifactMetadataCount': 0,
      'invalidArtifactMetadataEntryCount': 0,
      'mismatchedArtifactMetadataCount': 0,
      'invalidArtifactIdCount': 0,
      'mismatchedArtifactIdCount': 0,
      'invalidArtifactMetadataCount': 0,
      'mismatchedArtifactByteCount': 0,
      'mismatchedArtifactDigestCount': 0,
      'invalidTaskRunCount': 0,
      'duplicateTaskRunCount': 0,
    };
  }

  final checksumDigestByPath = _artifactChecksumDigestByPath(checksums);
  final schemaVersion = _intValue(runResults['schemaVersion']);
  final run = _objectMap(runResults['run']);
  final runId = _nonEmptyString(run['id']);
  final manifestRunName = _nonEmptyString(manifestRun['name']);
  final manifestRunStartedAt = _nonEmptyString(manifestRun['startedAt']);
  final manifestRunCompletedAt = _nonEmptyString(manifestRun['completedAt']);
  final manifestRunStartedAtParsed = manifestRunStartedAt == null
      ? null
      : DateTime.tryParse(manifestRunStartedAt);
  final manifestRunCompletedAtParsed = manifestRunCompletedAt == null
      ? null
      : DateTime.tryParse(manifestRunCompletedAt);
  final manifestRunMetadataVerifiable =
      manifestRunName != null &&
      manifestRunStartedAt != null &&
      manifestRunCompletedAt != null &&
      manifestRunStartedAtParsed != null &&
      manifestRunCompletedAtParsed != null &&
      !manifestRunCompletedAtParsed.toUtc().isBefore(
        manifestRunStartedAtParsed.toUtc(),
      );
  final runResultsRunName = _nonEmptyString(run['name']);
  final runResultsRunStartedAt = _nonEmptyString(run['startedAt']);
  final runResultsRunCompletedAt = _nonEmptyString(run['completedAt']);
  final runNameMatchesManifest =
      manifestRunMetadataVerifiable && runResultsRunName == manifestRunName;
  final runStartedAtMatchesManifest =
      manifestRunMetadataVerifiable &&
      runResultsRunStartedAt == manifestRunStartedAt;
  final runCompletedAtMatchesManifest =
      manifestRunMetadataVerifiable &&
      runResultsRunCompletedAt == manifestRunCompletedAt;
  final mismatchedRunMetadataFieldCount = !manifestRunMetadataVerifiable
      ? 0
      : [
          runNameMatchesManifest,
          runStartedAtMatchesManifest,
          runCompletedAtMatchesManifest,
        ].where((matches) => !matches).length;
  final runMetadataStatus = !manifestRunMetadataVerifiable
      ? 'unverified'
      : mismatchedRunMetadataFieldCount == 0
      ? 'present'
      : 'mismatched';
  if (schemaVersion <= 0) {
    blockers.add('Run artifact bundle run results schema version is missing.');
  } else if (schemaVersion != _artifactRunResultsSchemaVersion) {
    blockers.add(
      'Run artifact bundle run results schema version $schemaVersion is unsupported.',
    );
  }
  if (runId == null) {
    blockers.add('Run artifact bundle run results run id is missing.');
  } else if (manifestRunId != null && runId != manifestRunId) {
    blockers.add(
      'Run artifact bundle run results run id does not match the manifest.',
    );
  }
  if (mismatchedRunMetadataFieldCount > 0) {
    blockers.add(
      'Run artifact bundle run results run metadata mismatches manifest in '
      '$mismatchedRunMetadataFieldCount field(s).',
    );
  }
  final runResultRows = _objectMaps(runResults['taskRuns']);
  if (runResults['taskRuns'] is! List || runResultRows.isEmpty) {
    blockers.add('Run artifact bundle run results task run list is missing.');
  }

  final runResultsById = <String, Map<String, Object?>>{};
  final leaderboardTrialsByKey = {
    for (final trial in leaderboardTrialSummaries)
      if (_releaseTaskRunKey(trial) case final key?) key: trial,
  };
  var invalidTaskRunCount = 0;
  var invalidTaskRunModelIdentityCount = 0;
  var duplicateTaskRunCount = 0;
  var mismatchedTaskRunRunIdCount = 0;
  var mismatchedTrialOutcomeCount = 0;
  var invalidTrialOutcomeCount = 0;
  var missingAgenticHarnessMetadataCount = 0;
  var invalidTimingTaskRunCount = 0;
  var invalidTokenUsageTaskRunCount = 0;
  var evaluationCount = 0;
  var missingEvaluationTaskRunCount = 0;
  var invalidEvaluationCount = 0;
  var invalidEvaluationRationaleCount = 0;
  var invalidEvaluationDetailsMetadataCount = 0;
  var invalidBlockedEvaluationMetadataCount = 0;
  var invalidJudgeOverheadMetadataCount = 0;
  var missingAgentHarnessStatusMetadataCount = 0;
  var invalidAgentHarnessStatusMetadataCount = 0;
  var duplicateEvaluationIdCount = 0;
  var duplicateTaskEvaluatorCount = 0;
  final seenEvaluationIds = <String>{};
  final runResultsEvaluatorIds = SplayTreeSet<String>();
  for (final row in runResultRows) {
    final id = _nonEmptyString(row['id']);
    if (!_validTaskRunMetadata(row, idKey: 'id')) {
      invalidTaskRunCount++;
    }
    if (!_validModelIdentityMetadata(row)) {
      invalidTaskRunModelIdentityCount++;
    }
    if (!_validRunResultsTrialOutcome(row)) {
      invalidTrialOutcomeCount++;
    }
    if (_taskRunTrack(row) == 'agentic' &&
        _nonEmptyString(row['harnessId']) == null) {
      missingAgenticHarnessMetadataCount++;
    }
    if (!_validRunResultsTaskRunTimingMetadata(
      row,
      manifestRunMetadataVerifiable: manifestRunMetadataVerifiable,
      manifestRunStartedAt: manifestRunStartedAtParsed,
      manifestRunCompletedAt: manifestRunCompletedAtParsed,
    )) {
      invalidTimingTaskRunCount++;
    }
    if (!_validRunResultsTaskRunTokenUsageMetadata(row)) {
      invalidTokenUsageTaskRunCount++;
    }
    final evaluationsValue = row['evaluations'];
    final evaluations = _objectMaps(evaluationsValue);
    if (evaluationsValue is! List || evaluations.isEmpty) {
      missingEvaluationTaskRunCount++;
    } else {
      evaluationCount += evaluations.length;
      invalidEvaluationCount += evaluationsValue.length - evaluations.length;
      invalidEvaluationCount += evaluations
          .where((evaluation) => !_validRunResultsEvaluation(evaluation))
          .length;
      invalidEvaluationRationaleCount += evaluations
          .where(
            (evaluation) => !_validRunResultsEvaluationRationale(evaluation),
          )
          .length;
      invalidEvaluationDetailsMetadataCount += evaluations
          .where(
            (evaluation) =>
                !_validRunResultsEvaluationDetailsMetadata(evaluation),
          )
          .length;
      invalidBlockedEvaluationMetadataCount += evaluations
          .where(
            (evaluation) =>
                !_validRunResultsBlockedEvaluationMetadata(evaluation),
          )
          .length;
      invalidJudgeOverheadMetadataCount += evaluations
          .where(
            (evaluation) => !_validRunResultsJudgeOverheadMetadata(evaluation),
          )
          .length;
      for (final evaluation in evaluations) {
        if (_nonEmptyString(evaluation['evaluatorId']) != 'agent_harness') {
          continue;
        }
        final agentHarness = evaluation['agentHarness'];
        if (agentHarness == null) {
          missingAgentHarnessStatusMetadataCount++;
        } else if (!_validRunResultsAgentHarnessStatusMetadata(evaluation)) {
          invalidAgentHarnessStatusMetadataCount++;
        }
      }
      final rowEvaluatorIds = <String>{};
      for (final evaluation in evaluations) {
        final evaluationId = _nonEmptyString(evaluation['id']);
        if (evaluationId != null && !seenEvaluationIds.add(evaluationId)) {
          duplicateEvaluationIdCount++;
        }
        final evaluatorId = _nonEmptyString(evaluation['evaluatorId']);
        if (evaluatorId != null) {
          if (!rowEvaluatorIds.add(evaluatorId)) {
            duplicateTaskEvaluatorCount++;
          }
          runResultsEvaluatorIds.add(evaluatorId);
        }
      }
    }
    final rowRunId = _nonEmptyString(row['runId']);
    if (runId != null && rowRunId != runId) {
      mismatchedTaskRunRunIdCount++;
    }
    final rowKey = _releaseTaskRunKey(row);
    final leaderboardTrial = rowKey == null
        ? null
        : leaderboardTrialsByKey[rowKey];
    if (leaderboardTrial != null &&
        !_runResultsOutcomeMatchesTrial(row, leaderboardTrial)) {
      mismatchedTrialOutcomeCount++;
    }
    if (id == null) {
      continue;
    }
    if (runResultsById.containsKey(id)) {
      duplicateTaskRunCount++;
      continue;
    }
    runResultsById[id] = row;
  }

  final manifestTaskRunIds = <String>{};
  var missingTaskRunCount = 0;
  var mismatchedTaskRunCount = 0;
  var mismatchedAgenticHarnessMetadataCount = 0;
  for (final manifestTaskRun in manifestTaskRuns) {
    final taskRunId = _nonEmptyString(manifestTaskRun['taskRunId']);
    if (taskRunId == null) continue;
    manifestTaskRunIds.add(taskRunId);
    final runResult = runResultsById[taskRunId];
    if (runResult == null) {
      missingTaskRunCount++;
      continue;
    }
    final runResultTaskVersion = _intValue(runResult['taskVersion']);
    final manifestTaskVersion = _intValue(manifestTaskRun['taskVersion']);
    final runResultTrack = _taskRunTrack(runResult);
    final manifestTrack = _taskRunTrack(manifestTaskRun);
    final runResultHarnessId = _nonEmptyString(runResult['harnessId']);
    final manifestHarnessId = _nonEmptyString(manifestTaskRun['harnessId']);
    if (runResult['taskId'] != manifestTaskRun['taskId'] ||
        runResult['providerId'] != manifestTaskRun['providerId'] ||
        runResult['modelId'] != manifestTaskRun['modelId'] ||
        runResult['baseModelId'] != manifestTaskRun['baseModelId'] ||
        !_jsonValueEquals(
          runResult['modelConfig'],
          manifestTaskRun['modelConfig'],
        ) ||
        _intValue(runResult['trialIndex']) !=
            _intValue(manifestTaskRun['trialIndex']) ||
        runResultTaskVersion != manifestTaskVersion ||
        runResultTrack != manifestTrack) {
      mismatchedTaskRunCount++;
    }
    if (manifestTrack == 'agentic' &&
        manifestHarnessId != null &&
        runResultHarnessId != null &&
        runResultHarnessId != manifestHarnessId) {
      mismatchedAgenticHarnessMetadataCount++;
    }
  }
  final extraTaskRunCount = runResultsById.keys
      .where((taskRunId) => !manifestTaskRunIds.contains(taskRunId))
      .length;

  var missingArtifactCount = 0;
  var extraArtifactCount = 0;
  var mismatchedArtifactCount = 0;
  var missingArtifactMetadataCount = 0;
  var invalidArtifactMetadataEntryCount = 0;
  var mismatchedArtifactMetadataCount = 0;
  var invalidArtifactIdCount = 0;
  var mismatchedArtifactIdCount = 0;
  var invalidArtifactMetadataCount = 0;
  var mismatchedArtifactByteCount = 0;
  var mismatchedArtifactDigestCount = 0;
  final manifestArtifactKeys = <String>{};
  for (final artifact in manifestArtifacts) {
    final kind = _nonEmptyString(artifact['kind']);
    final taskRunId = _nonEmptyString(artifact['taskRunId']);
    final path = _nonEmptyString(artifact['path']);
    final manifestBytes = _intValue(artifact['bytes']);
    if (kind == null || taskRunId == null || path == null) continue;
    final manifestArtifactId = _nonEmptyString(artifact['artifactId']);
    final manifestSha256 = _nonEmptyString(artifact['sha256']);
    final checksumDigest = checksumDigestByPath[path];
    manifestArtifactKeys.add('$taskRunId/$kind');
    final runResult = runResultsById[taskRunId];
    final artifacts = _objectMap(runResult?['artifacts']);
    if (!artifacts.containsKey(kind)) {
      missingArtifactCount++;
    } else if (artifacts[kind] != path) {
      mismatchedArtifactCount++;
    } else {
      final artifactMetadata = _objectMap(runResult?['artifactMetadata']);
      final metadata = _objectMap(artifactMetadata[kind]);
      if (metadata.isEmpty) {
        missingArtifactMetadataCount++;
      } else {
        final metadataPath = _nonEmptyString(metadata['path']);
        final metadataArtifactId = _nonEmptyString(metadata['artifactId']);
        final metadataBytes = _intValue(metadata['bytes']);
        final metadataSha256 = _nonEmptyString(metadata['sha256']);
        if (!_isArtifactId(metadataArtifactId)) {
          invalidArtifactIdCount++;
        } else if (_isArtifactId(manifestArtifactId) &&
            metadataArtifactId != manifestArtifactId) {
          mismatchedArtifactIdCount++;
        }
        if (metadataPath == null ||
            metadataBytes <= 0 ||
            !_isSha256Digest(metadataSha256)) {
          invalidArtifactMetadataEntryCount++;
        } else if (metadataPath != path ||
            (manifestBytes > 0 && metadataBytes != manifestBytes) ||
            (_isSha256Digest(manifestSha256) &&
                metadataSha256 != manifestSha256) ||
            (checksumDigest != null && metadataSha256 != checksumDigest)) {
          mismatchedArtifactMetadataCount++;
        }
      }
    }
    if (artifacts[kind] == path && (kind == 'response' || kind == 'patch')) {
      final byteField = kind == 'response'
          ? 'responseTextBytes'
          : 'patchTextBytes';
      final digestField = kind == 'response'
          ? 'responseTextSha256'
          : 'patchTextSha256';
      final bytes = _intValue(runResult?[byteField]);
      final digest = _nonEmptyString(runResult?[digestField]);
      if (bytes <= 0 ||
          digest == null ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
        invalidArtifactMetadataCount++;
      } else {
        if (manifestBytes > 0 && bytes != manifestBytes) {
          mismatchedArtifactByteCount++;
        }
        if (checksumDigest != null && digest != checksumDigest) {
          mismatchedArtifactDigestCount++;
        }
      }
    }
  }
  for (final entry in runResultsById.entries) {
    final artifacts = _objectMap(entry.value['artifacts']);
    for (final kind in artifacts.keys) {
      if (!manifestArtifactKeys.contains('${entry.key}/$kind')) {
        extraArtifactCount++;
      }
    }
  }
  final missingEvaluatorIdCount = manifestEvaluatorIds
      .where((evaluatorId) => !runResultsEvaluatorIds.contains(evaluatorId))
      .length;
  final extraEvaluatorIdCount = runResultsEvaluatorIds
      .where((evaluatorId) => !manifestEvaluatorIds.contains(evaluatorId))
      .length;
  final evaluatorIdsMatchManifest =
      manifestEvaluatorIds.isNotEmpty &&
      missingEvaluatorIdCount == 0 &&
      extraEvaluatorIdCount == 0;

  if (invalidTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidTaskRunCount invalid task run(s).',
    );
  }
  if (invalidTaskRunModelIdentityCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidTaskRunModelIdentityCount task run(s) with invalid model identity metadata.',
    );
  }
  if (duplicateTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $duplicateTaskRunCount duplicate task run id(s).',
    );
  }
  if (mismatchedTaskRunRunIdCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $mismatchedTaskRunRunIdCount task run(s) with missing or mismatched run id.',
    );
  }
  if (mismatchedTrialOutcomeCount > 0) {
    blockers.add(
      'Run artifact bundle run results mismatch $mismatchedTrialOutcomeCount leaderboard trial outcome(s).',
    );
  }
  if (missingAgenticHarnessMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $missingAgenticHarnessMetadataCount agentic task run(s) with missing harness metadata.',
    );
  }
  if (mismatchedAgenticHarnessMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results mismatch $mismatchedAgenticHarnessMetadataCount manifest agentic harness metadata record(s).',
    );
  }
  if (invalidTrialOutcomeCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidTrialOutcomeCount invalid task-run outcome(s).',
    );
  }
  if (invalidTimingTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidTimingTaskRunCount task run(s) with invalid timing metadata.',
    );
  }
  if (invalidTokenUsageTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidTokenUsageTaskRunCount task run(s) with invalid token usage metadata.',
    );
  }
  if (missingEvaluationTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $missingEvaluationTaskRunCount task run(s) without evaluation evidence.',
    );
  }
  if (invalidEvaluationCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidEvaluationCount invalid evaluation record(s).',
    );
  }
  if (invalidEvaluationRationaleCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidEvaluationRationaleCount evaluation record(s) with missing rationale.',
    );
  }
  if (invalidEvaluationDetailsMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidEvaluationDetailsMetadataCount evaluation record(s) with invalid details metadata.',
    );
  }
  if (invalidBlockedEvaluationMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidBlockedEvaluationMetadataCount evaluation record(s) with invalid blocked metadata.',
    );
  }
  if (invalidJudgeOverheadMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidJudgeOverheadMetadataCount evaluation record(s) with invalid judge overhead metadata.',
    );
  }
  if (missingAgentHarnessStatusMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $missingAgentHarnessStatusMetadataCount agent harness evaluation record(s) with missing status metadata.',
    );
  }
  if (invalidAgentHarnessStatusMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidAgentHarnessStatusMetadataCount agent harness evaluation record(s) with invalid status metadata.',
    );
  }
  if (duplicateEvaluationIdCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $duplicateEvaluationIdCount duplicate evaluation id(s).',
    );
  }
  if (duplicateTaskEvaluatorCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $duplicateTaskEvaluatorCount duplicate task-run evaluator id(s).',
    );
  }
  if (missingEvaluatorIdCount > 0) {
    blockers.add(
      'Run artifact bundle run results are missing $missingEvaluatorIdCount manifest evaluator id(s).',
    );
  }
  if (extraEvaluatorIdCount > 0) {
    blockers.add(
      'Run artifact bundle run results contain $extraEvaluatorIdCount evaluator id(s) not listed in the manifest.',
    );
  }
  if (missingTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle run results are missing $missingTaskRunCount manifest task run(s).',
    );
  }
  if (extraTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle run results contain $extraTaskRunCount extra task run(s).',
    );
  }
  if (mismatchedTaskRunCount > 0) {
    blockers.add(
      'Run artifact bundle run results mismatch $mismatchedTaskRunCount manifest task run(s).',
    );
  }
  if (missingArtifactCount > 0) {
    blockers.add(
      'Run artifact bundle run results are missing $missingArtifactCount manifest artifact reference(s).',
    );
  }
  if (extraArtifactCount > 0) {
    blockers.add(
      'Run artifact bundle run results contain $extraArtifactCount extra artifact reference(s).',
    );
  }
  if (mismatchedArtifactCount > 0) {
    blockers.add(
      'Run artifact bundle run results mismatch $mismatchedArtifactCount manifest artifact reference(s).',
    );
  }
  if (missingArtifactMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results are missing $missingArtifactMetadataCount artifact metadata record(s).',
    );
  }
  if (invalidArtifactMetadataEntryCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidArtifactMetadataEntryCount invalid artifact metadata record(s).',
    );
  }
  if (mismatchedArtifactMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results mismatch $mismatchedArtifactMetadataCount artifact metadata record(s).',
    );
  }
  if (invalidArtifactIdCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidArtifactIdCount invalid artifact id metadata record(s).',
    );
  }
  if (mismatchedArtifactIdCount > 0) {
    blockers.add(
      'Run artifact bundle run results mismatch $mismatchedArtifactIdCount artifact id metadata record(s).',
    );
  }
  if (invalidArtifactMetadataCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $invalidArtifactMetadataCount invalid response/patch artifact metadata record(s).',
    );
  }
  if (mismatchedArtifactByteCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $mismatchedArtifactByteCount response/patch artifact byte count mismatch(es).',
    );
  }
  if (mismatchedArtifactDigestCount > 0) {
    blockers.add(
      'Run artifact bundle run results have $mismatchedArtifactDigestCount response/patch artifact checksum mismatch(es).',
    );
  }

  final complete =
      schemaVersion > 0 &&
      schemaVersion == _artifactRunResultsSchemaVersion &&
      runId != null &&
      manifestRunId != null &&
      runId == manifestRunId &&
      runMetadataStatus != 'mismatched' &&
      runResults['taskRuns'] is List &&
      runResultRows.isNotEmpty &&
      evaluationCount > 0 &&
      evaluatorIdsMatchManifest &&
      invalidTaskRunCount == 0 &&
      invalidTaskRunModelIdentityCount == 0 &&
      duplicateTaskRunCount == 0 &&
      mismatchedTaskRunRunIdCount == 0 &&
      mismatchedTrialOutcomeCount == 0 &&
      missingAgenticHarnessMetadataCount == 0 &&
      mismatchedAgenticHarnessMetadataCount == 0 &&
      invalidTrialOutcomeCount == 0 &&
      invalidTimingTaskRunCount == 0 &&
      invalidTokenUsageTaskRunCount == 0 &&
      missingEvaluationTaskRunCount == 0 &&
      invalidEvaluationCount == 0 &&
      invalidEvaluationRationaleCount == 0 &&
      invalidEvaluationDetailsMetadataCount == 0 &&
      invalidBlockedEvaluationMetadataCount == 0 &&
      invalidJudgeOverheadMetadataCount == 0 &&
      missingAgentHarnessStatusMetadataCount == 0 &&
      invalidAgentHarnessStatusMetadataCount == 0 &&
      duplicateEvaluationIdCount == 0 &&
      duplicateTaskEvaluatorCount == 0 &&
      missingTaskRunCount == 0 &&
      extraTaskRunCount == 0 &&
      mismatchedTaskRunCount == 0 &&
      missingArtifactCount == 0 &&
      extraArtifactCount == 0 &&
      mismatchedArtifactCount == 0 &&
      missingArtifactMetadataCount == 0 &&
      invalidArtifactMetadataEntryCount == 0 &&
      mismatchedArtifactMetadataCount == 0 &&
      invalidArtifactIdCount == 0 &&
      mismatchedArtifactIdCount == 0 &&
      invalidArtifactMetadataCount == 0 &&
      mismatchedArtifactByteCount == 0 &&
      mismatchedArtifactDigestCount == 0;

  return {
    'status': complete ? 'present' : 'incomplete',
    'schemaVersion': schemaVersion,
    'runId': runId,
    'runIdMatchesManifest':
        runId != null && manifestRunId != null && runId == manifestRunId,
    'runMetadataStatus': runMetadataStatus,
    'runNameMatchesManifest': runNameMatchesManifest,
    'runStartedAtMatchesManifest': runStartedAtMatchesManifest,
    'runCompletedAtMatchesManifest': runCompletedAtMatchesManifest,
    'mismatchedRunMetadataFieldCount': mismatchedRunMetadataFieldCount,
    'taskRunCount': runResultRows.length,
    'evaluationCount': evaluationCount,
    'evaluatorIdCount': runResultsEvaluatorIds.length,
    'evaluatorIdsMatchManifest': evaluatorIdsMatchManifest,
    'missingEvaluatorIdCount': missingEvaluatorIdCount,
    'extraEvaluatorIdCount': extraEvaluatorIdCount,
    'missingTaskRunCount': missingTaskRunCount,
    'extraTaskRunCount': extraTaskRunCount,
    'mismatchedTaskRunCount': mismatchedTaskRunCount,
    'missingAgenticHarnessMetadataCount': missingAgenticHarnessMetadataCount,
    'mismatchedAgenticHarnessMetadataCount':
        mismatchedAgenticHarnessMetadataCount,
    'mismatchedTaskRunRunIdCount': mismatchedTaskRunRunIdCount,
    'mismatchedTrialOutcomeCount': mismatchedTrialOutcomeCount,
    'invalidTrialOutcomeCount': invalidTrialOutcomeCount,
    'invalidTimingTaskRunCount': invalidTimingTaskRunCount,
    'invalidTokenUsageTaskRunCount': invalidTokenUsageTaskRunCount,
    'missingEvaluationTaskRunCount': missingEvaluationTaskRunCount,
    'invalidEvaluationCount': invalidEvaluationCount,
    'invalidEvaluationRationaleCount': invalidEvaluationRationaleCount,
    'invalidEvaluationDetailsMetadataCount':
        invalidEvaluationDetailsMetadataCount,
    'invalidBlockedEvaluationMetadataCount':
        invalidBlockedEvaluationMetadataCount,
    'invalidJudgeOverheadMetadataCount': invalidJudgeOverheadMetadataCount,
    'missingAgentHarnessStatusMetadataCount':
        missingAgentHarnessStatusMetadataCount,
    'invalidAgentHarnessStatusMetadataCount':
        invalidAgentHarnessStatusMetadataCount,
    'duplicateEvaluationIdCount': duplicateEvaluationIdCount,
    'duplicateTaskEvaluatorCount': duplicateTaskEvaluatorCount,
    'missingArtifactCount': missingArtifactCount,
    'extraArtifactCount': extraArtifactCount,
    'mismatchedArtifactCount': mismatchedArtifactCount,
    'missingArtifactMetadataCount': missingArtifactMetadataCount,
    'invalidArtifactMetadataEntryCount': invalidArtifactMetadataEntryCount,
    'mismatchedArtifactMetadataCount': mismatchedArtifactMetadataCount,
    'invalidArtifactIdCount': invalidArtifactIdCount,
    'mismatchedArtifactIdCount': mismatchedArtifactIdCount,
    'invalidArtifactMetadataCount': invalidArtifactMetadataCount,
    'mismatchedArtifactByteCount': mismatchedArtifactByteCount,
    'mismatchedArtifactDigestCount': mismatchedArtifactDigestCount,
    'invalidTaskRunCount': invalidTaskRunCount,
    'invalidTaskRunModelIdentityCount': invalidTaskRunModelIdentityCount,
    'duplicateTaskRunCount': duplicateTaskRunCount,
  };
}

Map<String, String> _artifactChecksumDigestByPath(
  Map<String, Object?>? checksums,
) {
  final digests = <String, String>{};
  for (final file in _objectMaps(checksums?['files'])) {
    final path = _nonEmptyString(file['path']);
    final sha256 = _nonEmptyString(file['sha256']);
    if (path == null ||
        sha256 == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
        digests.containsKey(path)) {
      continue;
    }
    digests[path] = sha256;
  }
  return digests;
}

Set<String> _artifactPathIssues(String path) {
  final issues = <String>{};
  if (path.startsWith('/') ||
      path.startsWith(r'\') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) {
    issues.add('absolute');
  }

  final parts = path
      .split(RegExp(r'[\\/]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty || parts.first != 'artifacts') {
    issues.add('outsideRoot');
  }
  if (parts.any((part) => part == '..')) {
    issues.add('parent');
  }
  final privatePathParts = {
    '_hidden',
    'hidden',
    '_reference',
    'reference',
    'fixtures',
  };
  if (parts.map((part) => part.toLowerCase()).any(privatePathParts.contains)) {
    issues.add('private');
  }
  return issues;
}

Set<String> _checksumPathIssues(String path) {
  if (_requiredArtifactBundleChecksumPaths.contains(path)) {
    return const {};
  }
  return _artifactPathIssues(path);
}

String? _taskRunTrack(Map<String, Object?> taskRun) =>
    _nonEmptyString(taskRun['benchmarkTrack']) ??
    _nonEmptyString(taskRun['track']);

bool _validTaskRunMetadata(
  Map<String, Object?> taskRun, {
  required String idKey,
}) {
  return _nonEmptyString(taskRun[idKey]) != null &&
      _nonEmptyString(taskRun['taskId']) != null &&
      _nonEmptyString(taskRun['providerId']) != null &&
      _nonEmptyString(taskRun['modelId']) != null &&
      _intValue(taskRun['taskVersion']) > 0 &&
      taskRun['trialIndex'] is num &&
      (taskRun['trialIndex'] as num) >= 0 &&
      _taskRunTrack(taskRun) != null;
}

bool _validModelIdentityMetadata(Map<String, Object?> row) {
  final providerId = _nonEmptyString(row['providerId']);
  final modelId = _nonEmptyString(row['modelId']);
  final baseModelId = _nonEmptyString(row['baseModelId']);
  final modelConfig = row['modelConfig'];
  if (providerId == null ||
      modelId == null ||
      baseModelId == null ||
      modelConfig is! Map) {
    return false;
  }

  final expected = ModelIdentity.from(providerId: providerId, modelId: modelId);
  if (baseModelId != expected.baseModelId) return false;
  if (!_validPublicModelConfig(modelConfig)) return false;

  final expectedEffort = expected.effort;
  if (expectedEffort == null) {
    return !modelConfig.containsKey('effort');
  }
  return modelConfig['effort'] == expectedEffort;
}

bool _validPublicModelConfig(Map<dynamic, dynamic> modelConfig) {
  for (final entry in modelConfig.entries) {
    final key = entry.key;
    if (key is! String || key.trim().isEmpty) {
      return false;
    }
    if (!_validPublicModelConfigValue(entry.value)) return false;
  }
  return true;
}

bool _validPublicModelConfigValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is bool) return true;
  if (value is num) return value.isFinite;
  if (value is List) {
    return value.every(_validPublicModelConfigValue);
  }
  if (value is Map) {
    return _validPublicModelConfig(value);
  }
  return false;
}

bool _validRunResultsTaskRunTimingMetadata(
  Map<String, Object?> row, {
  required bool manifestRunMetadataVerifiable,
  required DateTime? manifestRunStartedAt,
  required DateTime? manifestRunCompletedAt,
}) {
  final completedAt = _nonEmptyString(row['completedAt']);
  final parsedCompletedAt = completedAt == null
      ? null
      : DateTime.tryParse(completedAt);
  final latencyMs = row['latencyMs'];
  if (parsedCompletedAt == null || latencyMs is! int || latencyMs <= 0) {
    return false;
  }
  if (!manifestRunMetadataVerifiable) return true;

  final completedAtUtc = parsedCompletedAt.toUtc();
  final startedAtUtc = manifestRunStartedAt!.toUtc();
  final runCompletedAtUtc = manifestRunCompletedAt!.toUtc();
  return !completedAtUtc.isBefore(startedAtUtc) &&
      !completedAtUtc.isAfter(runCompletedAtUtc);
}

bool _validRunResultsTaskRunTokenUsageMetadata(Map<String, Object?> row) {
  return row.containsKey('promptTokens') &&
      row.containsKey('completionTokens') &&
      _validNullableNonNegativeInt(row['promptTokens']) &&
      _validNullableNonNegativeInt(row['completionTokens']);
}

bool _validNullableNonNegativeInt(Object? value) =>
    value == null || value is int && value >= 0;

bool _validRunResultsEvaluation(Map<String, Object?> evaluation) {
  final score = evaluation['score'];
  final passed = evaluation['passed'];
  final status = _nonEmptyString(evaluation['status']);
  return _nonEmptyString(evaluation['id']) != null &&
      _nonEmptyString(evaluation['evaluatorId']) != null &&
      passed is bool &&
      score is num &&
      score >= 0 &&
      score <= 1 &&
      status != null &&
      _validRunResultsEvaluationStatus(passed: passed, status: status);
}

bool _validRunResultsEvaluationRationale(Map<String, Object?> evaluation) {
  return _nonEmptyString(evaluation['rationale']) != null;
}

bool _validRunResultsEvaluationDetailsMetadata(
  Map<String, Object?> evaluation,
) {
  final sha256 = _nonEmptyString(evaluation['detailsJsonSha256']);
  final bytes = _intValue(evaluation['detailsJsonBytes']);
  return sha256 != null &&
      RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) &&
      bytes > 0;
}

bool _validRunResultsBlockedEvaluationMetadata(
  Map<String, Object?> evaluation,
) {
  final status = _nonEmptyString(evaluation['status']);
  final blockedBy = _nonEmptyString(evaluation['blockedBy']);
  final blockedReason = _nonEmptyString(evaluation['blockedReason']);
  if (status == 'blocked') {
    return blockedBy != null && blockedReason == 'blocked by $blockedBy';
  }
  return blockedBy == null && blockedReason == null;
}

bool _validRunResultsJudgeOverheadMetadata(Map<String, Object?> evaluation) {
  if (!evaluation.containsKey('judgeOverhead')) return true;
  final value = evaluation['judgeOverhead'];
  if (value is! Map) return false;
  final overhead = _objectMap(value);
  final providerId = _nonEmptyString(overhead['providerId']);
  final modelId = _nonEmptyString(overhead['modelId']);
  final pricingStatus = _nonEmptyString(overhead['pricingStatus']);
  final pricingRegistryVersion = overhead.containsKey('pricingRegistryVersion')
      ? _nonEmptyString(overhead['pricingRegistryVersion'])
      : null;
  final pricingCurrency = overhead.containsKey('pricingCurrency')
      ? _nonEmptyString(overhead['pricingCurrency'])
      : null;
  return providerId != null &&
      modelId != null &&
      pricingStatus != null &&
      overhead.containsKey('promptTokens') &&
      _validNullableNonNegativeInt(overhead['promptTokens']) &&
      overhead.containsKey('completionTokens') &&
      _validNullableNonNegativeInt(overhead['completionTokens']) &&
      overhead.containsKey('estimatedCostMicros') &&
      _validNullableNonNegativeInt(overhead['estimatedCostMicros']) &&
      (!overhead.containsKey('pricingRegistryVersion') ||
          pricingRegistryVersion != null) &&
      (!overhead.containsKey('pricingCurrency') || pricingCurrency != null);
}

bool _validRunResultsAgentHarnessStatusMetadata(
  Map<String, Object?> evaluation,
) {
  final value = evaluation['agentHarness'];
  if (value is! Map) return false;
  final agentHarness = _objectMap(value);
  final status = _nonEmptyString(agentHarness['status']);
  return status != null &&
      const {'success', 'failure', 'timeout', 'cancelled'}.contains(status) &&
      agentHarness.containsKey('exitCode') &&
      _validNullableNonNegativeInt(agentHarness['exitCode']) &&
      agentHarness['stdoutPreviewPresent'] is bool &&
      agentHarness['stderrPreviewPresent'] is bool &&
      agentHarness['trajectoryLogPresent'] is bool;
}

bool _validRunResultsEvaluationStatus({
  required bool passed,
  required String status,
}) {
  if (!_allowedRunResultsEvaluationStatuses.contains(status)) return false;
  return passed ? status == 'passed' : status != 'passed';
}

bool _validRunResultsTrialOutcome(Map<String, Object?> row) {
  final primaryPass = row['primaryPass'];
  final failureTag = _nonEmptyString(row['failureTag']);
  final aggregateScore = row['aggregateScore'];
  if (primaryPass is! bool ||
      failureTag == null ||
      aggregateScore is! num ||
      aggregateScore < 0 ||
      aggregateScore > 1 ||
      !supportedFailureTags.contains(failureTag)) {
    return false;
  }
  return primaryPass ? failureTag == 'pass' : failureTag != 'pass';
}

String? _releaseTaskRunKey(
  Map<String, Object?> taskRun, {
  String? fallbackRunId,
}) {
  final runId = _nonEmptyString(taskRun['runId']) ?? fallbackRunId;
  final providerId = _nonEmptyString(taskRun['providerId']);
  final modelId = _nonEmptyString(taskRun['modelId']);
  final taskId = _nonEmptyString(taskRun['taskId']);
  final taskVersion = taskRun['taskVersion'];
  final track = _taskRunTrack(taskRun);
  final trialIndex = taskRun['trialIndex'];
  if (runId == null ||
      providerId == null ||
      modelId == null ||
      taskId == null ||
      taskVersion == null ||
      track == null ||
      trialIndex is! num ||
      trialIndex < 0) {
    return null;
  }
  return [
    runId,
    providerId,
    modelId,
    taskId,
    taskVersion.toString(),
    track,
    trialIndex.toInt().toString(),
  ].join('\u0000');
}

bool _runResultsOutcomeMatchesTrial(
  Map<String, Object?> row,
  Map<String, Object?> trial,
) {
  return row['primaryPass'] == trial['primaryPass'] &&
      _nonEmptyString(row['failureTag']) ==
          _nonEmptyString(trial['failureTag']) &&
      _numMatches(row['aggregateScore'], trial['aggregateScore']);
}

bool _numMatches(Object? left, Object? right) {
  return _numMatchesWithTolerance(left, right, 1e-9);
}

bool _numMatchesWithTolerance(Object? left, Object? right, double tolerance) {
  if (left is! num || right is! num) return false;
  return (left.toDouble() - right.toDouble()).abs() <= tolerance;
}

Map<String, Object?> _reportingReadinessGate({
  required Map<String, Object?> judgeOverhead,
  required Map<String, Object?> taskModelCells,
  required Map<String, Object?> modelIdentity,
  required Map<String, Object?> trialTransparency,
  required Map<String, Object?> privacy,
  required Map<String, Object?> artifactBundle,
  required Map<String, Object?>? inputs,
}) {
  final judgeOverheadStatus = judgeOverhead['status'];
  final artifactBundleStatus = artifactBundle['status'];
  final missingCellCount = _intValue(taskModelCells['missingCellCount']);
  final missingMetricCellCount = _intValue(
    taskModelCells['missingMetricCellCount'],
  );
  final invalidModelIdentityCount = _intValue(
    modelIdentity['invalidModelIdentityCount'],
  );
  final invalidArtifactBundleTaskRunModelIdentityCount = _intValue(
    artifactBundle['invalidTaskRunModelIdentityCount'],
  );
  final invalidRunResultsTaskRunModelIdentityCount = _intValue(
    artifactBundle['invalidRunResultsTaskRunModelIdentityCount'],
  );
  final unknownTraceMetricCellCount = _intValue(
    taskModelCells['unknownTraceMetricCellCount'],
  );
  final unknownTokenUsageCellCount = _intValue(
    taskModelCells['unknownTokenUsageCellCount'],
  );
  final trialSummaryCount = _intValue(trialTransparency['trialSummaryCount']);
  final trialSummaryTotalCount = _intValue(
    trialTransparency['trialSummaryTotalCount'],
  );
  final trialSummaryTruncated =
      trialTransparency['trialSummaryTruncated'] == true;
  final missingMetricTrialCount = _intValue(
    trialTransparency['missingMetricTrialCount'],
  );
  final unknownTraceMetricTrialCount = _intValue(
    trialTransparency['unknownTraceMetricTrialCount'],
  );
  final unknownTokenUsageTrialCount = _intValue(
    trialTransparency['unknownTokenUsageTrialCount'],
  );
  final missingPassAtKCount =
      _intValue(trialTransparency['missingModelPassAtKCount']) +
      _intValue(trialTransparency['missingTaskPassAtKCount']) +
      _intValue(trialTransparency['missingCellPassAtKCount']);
  final missingConfidenceIntervalCount =
      _intValue(trialTransparency['missingModelConfidenceIntervalCount']) +
      _intValue(trialTransparency['missingTaskConfidenceIntervalCount']) +
      _intValue(trialTransparency['missingCellConfidenceIntervalCount']);
  final inputFingerprintCount = _inputFingerprintCount(inputs);
  final privacyStatus = privacy['status'];
  final passed =
      judgeOverheadStatus == 'present' &&
      artifactBundleStatus == 'present' &&
      privacyStatus == 'passed' &&
      missingCellCount == 0 &&
      missingMetricCellCount == 0 &&
      invalidModelIdentityCount == 0 &&
      invalidArtifactBundleTaskRunModelIdentityCount == 0 &&
      invalidRunResultsTaskRunModelIdentityCount == 0 &&
      trialSummaryCount > 0 &&
      trialSummaryCount == trialSummaryTotalCount &&
      !trialSummaryTruncated &&
      missingMetricTrialCount == 0 &&
      missingPassAtKCount == 0 &&
      missingConfidenceIntervalCount == 0 &&
      inputFingerprintCount > 0;

  return {
    'status': _readinessStatus(passed),
    'judgeOverheadStatus': judgeOverheadStatus,
    'judgeOverheadEvaluationCount': _intValue(judgeOverhead['evaluationCount']),
    'judgeOverheadUnknownCostCount': _intValue(
      judgeOverhead['unknownEstimatedCostCount'],
    ),
    'artifactBundleStatus': artifactBundleStatus,
    'artifactBundleRunIdStatus': artifactBundle['runIdStatus'],
    'artifactBundleRunIdInLeaderboardSource':
        artifactBundle['runIdInLeaderboardSource'],
    'artifactCount': _intValue(artifactBundle['artifactCount']),
    'artifactBundleEvaluationCount': _intValue(
      artifactBundle['evaluationCount'],
    ),
    'manifestPopulationSummaryStatus':
        artifactBundle['manifestPopulationSummaryStatus'],
    'manifestTaskCountStatus': artifactBundle['manifestTaskCountStatus'],
    'manifestProviderCountStatus':
        artifactBundle['manifestProviderCountStatus'],
    'manifestModelCountStatus': artifactBundle['manifestModelCountStatus'],
    'manifestTaskCount': _intValue(artifactBundle['manifestTaskCount']),
    'manifestProviderCount': _intValue(artifactBundle['manifestProviderCount']),
    'manifestModelCount': _intValue(artifactBundle['manifestModelCount']),
    'manifestDistinctTaskCount': _intValue(
      artifactBundle['manifestDistinctTaskCount'],
    ),
    'manifestDistinctProviderCount': _intValue(
      artifactBundle['manifestDistinctProviderCount'],
    ),
    'manifestDistinctModelCount': _intValue(
      artifactBundle['manifestDistinctModelCount'],
    ),
    'manifestPopulationCountMismatchCount': _intValue(
      artifactBundle['manifestPopulationCountMismatchCount'],
    ),
    'manifestEvaluatorIdCount': _intValue(
      artifactBundle['manifestEvaluatorIdCount'],
    ),
    'invalidManifestEvaluatorIdCount': _intValue(
      artifactBundle['invalidManifestEvaluatorIdCount'],
    ),
    'duplicateManifestEvaluatorIdCount': _intValue(
      artifactBundle['duplicateManifestEvaluatorIdCount'],
    ),
    'artifactBundleWarningCount': _intValue(artifactBundle['warningCount']),
    'artifactBundleWarningCodeCounts': _countMap(
      artifactBundle['warningCodeCounts'],
    ),
    'unsafeArtifactPathCount': _intValue(
      artifactBundle['unsafeArtifactPathCount'],
    ),
    'absoluteArtifactPathCount': _intValue(
      artifactBundle['absoluteArtifactPathCount'],
    ),
    'parentArtifactPathCount': _intValue(
      artifactBundle['parentArtifactPathCount'],
    ),
    'privateArtifactPathCount': _intValue(
      artifactBundle['privateArtifactPathCount'],
    ),
    'outsideArtifactRootPathCount': _intValue(
      artifactBundle['outsideArtifactRootPathCount'],
    ),
    'artifactChecksumsStatus': artifactBundle['checksumsStatus'],
    'artifactChecksumSchemaVersion': _intValue(
      artifactBundle['checksumSchemaVersion'],
    ),
    'artifactChecksumFileCount': _intValue(artifactBundle['checksumFileCount']),
    'manifestChecksumStatus': artifactBundle['manifestChecksumStatus'],
    'manifestChecksumDigestStatus':
        artifactBundle['manifestChecksumDigestStatus'],
    'checksumsPathMatchesInput': artifactBundle['checksumsPathMatchesInput'],
    'coveredArtifactChecksumCount': _intValue(
      artifactBundle['coveredArtifactChecksumCount'],
    ),
    'missingArtifactChecksumCount': _intValue(
      artifactBundle['missingArtifactChecksumCount'],
    ),
    'coveredStandardChecksumCount': _intValue(
      artifactBundle['coveredStandardChecksumCount'],
    ),
    'missingStandardChecksumCount': _intValue(
      artifactBundle['missingStandardChecksumCount'],
    ),
    'verifiedStandardChecksumCount': _intValue(
      artifactBundle['verifiedStandardChecksumCount'],
    ),
    'missingStandardInputCount': _intValue(
      artifactBundle['missingStandardInputCount'],
    ),
    'mismatchedStandardChecksumCount': _intValue(
      artifactBundle['mismatchedStandardChecksumCount'],
    ),
    'standardInputPathMismatchCount': _intValue(
      artifactBundle['standardInputPathMismatchCount'],
    ),
    'verifiedArtifactFileCount': _intValue(
      artifactBundle['verifiedArtifactFileCount'],
    ),
    'missingArtifactFileCount': _intValue(
      artifactBundle['missingArtifactFileCount'],
    ),
    'mismatchedArtifactFileByteCount': _intValue(
      artifactBundle['mismatchedArtifactFileByteCount'],
    ),
    'mismatchedArtifactFileDigestCount': _intValue(
      artifactBundle['mismatchedArtifactFileDigestCount'],
    ),
    'invalidManifestArtifactDigestCount': _intValue(
      artifactBundle['invalidArtifactDigestCount'],
    ),
    'invalidManifestArtifactIdCount': _intValue(
      artifactBundle['invalidArtifactIdCount'],
    ),
    'duplicateManifestArtifactIdCount': _intValue(
      artifactBundle['duplicateArtifactIdCount'],
    ),
    'mismatchedManifestArtifactDigestCount': _intValue(
      artifactBundle['mismatchedManifestArtifactDigestCount'],
    ),
    'unexpectedChecksumPathCount': _intValue(
      artifactBundle['unexpectedChecksumPathCount'],
    ),
    'unsafeChecksumPathCount': _intValue(
      artifactBundle['unsafeChecksumPathCount'],
    ),
    'absoluteChecksumPathCount': _intValue(
      artifactBundle['absoluteChecksumPathCount'],
    ),
    'parentChecksumPathCount': _intValue(
      artifactBundle['parentChecksumPathCount'],
    ),
    'privateChecksumPathCount': _intValue(
      artifactBundle['privateChecksumPathCount'],
    ),
    'outsideArtifactRootChecksumPathCount': _intValue(
      artifactBundle['outsideArtifactRootChecksumPathCount'],
    ),
    'artifactManifestMetadataStatus': artifactBundle['manifestMetadataStatus'],
    'manifestRunMetadataStatus': artifactBundle['manifestRunMetadataStatus'],
    'manifestRunNameStatus': artifactBundle['manifestRunNameStatus'],
    'manifestRunStartedAtStatus': artifactBundle['manifestRunStartedAtStatus'],
    'manifestRunCompletedAtStatus':
        artifactBundle['manifestRunCompletedAtStatus'],
    'manifestRunDurationStatus': artifactBundle['manifestRunDurationStatus'],
    'manifestRunCompletedBeforeGeneratedAtStatus':
        artifactBundle['manifestRunCompletedBeforeGeneratedAtStatus'],
    'manifestOutcomeSummaryStatus':
        artifactBundle['manifestOutcomeSummaryStatus'],
    'manifestPassSummaryStatus': artifactBundle['manifestPassSummaryStatus'],
    'manifestFailureSummaryStatus':
        artifactBundle['manifestFailureSummaryStatus'],
    'manifestPassSummaryMismatchCount': _intValue(
      artifactBundle['manifestPassSummaryMismatchCount'],
    ),
    'manifestFailureSummaryMismatchCount': _intValue(
      artifactBundle['manifestFailureSummaryMismatchCount'],
    ),
    'manifestGeneratedAtStatus': artifactBundle['manifestGeneratedAtStatus'],
    'manifestAppVersionStatus': artifactBundle['manifestAppVersionStatus'],
    'manifestDriftSchemaVersionStatus':
        artifactBundle['manifestDriftSchemaVersionStatus'],
    'manifestExportToolStatus': artifactBundle['manifestExportToolStatus'],
    'manifestExportEnvironmentStatus':
        artifactBundle['manifestExportEnvironmentStatus'],
    'manifestExportEnvironmentGitStatus':
        artifactBundle['manifestExportEnvironmentGitStatus'],
    'artifactManifestProvenanceStatus':
        artifactBundle['manifestProvenanceStatus'],
    'manifestProvenanceRunIdMatchesManifest':
        artifactBundle['manifestProvenanceRunIdMatchesManifest'],
    'manifestProvenanceSandboxStatus':
        artifactBundle['manifestProvenanceSandboxStatus'],
    'manifestProvenanceSandboxBackend':
        artifactBundle['manifestProvenanceSandboxBackend'],
    'manifestProvenanceTaskExecutionPolicyStatus':
        artifactBundle['manifestProvenanceTaskExecutionPolicyStatus'],
    'manifestProvenanceNetworkDisabledTaskPolicyStatus':
        artifactBundle['manifestProvenanceNetworkDisabledTaskPolicyStatus'],
    'manifestProvenanceTaskResourceLimitStatus':
        artifactBundle['manifestProvenanceTaskResourceLimitStatus'],
    'manifestProvenanceSdkVersionStatus':
        artifactBundle['manifestProvenanceSdkVersionStatus'],
    'manifestProvenanceDependencySnapshotStatus':
        artifactBundle['manifestProvenanceDependencySnapshotStatus'],
    'manifestProvenancePricingRegistryStatus':
        artifactBundle['manifestProvenancePricingRegistryStatus'],
    'artifactResultsCsvStatus': artifactBundle['resultsCsvStatus'],
    'resultsCsvTaskRunCount': _intValue(
      artifactBundle['resultsCsvTaskRunCount'],
    ),
    'missingResultsCsvHeaderCount': _intValue(
      artifactBundle['missingResultsCsvHeaderCount'],
    ),
    'invalidResultsCsvTaskRunCount': _intValue(
      artifactBundle['invalidResultsCsvTaskRunCount'],
    ),
    'duplicateResultsCsvTaskRunCount': _intValue(
      artifactBundle['duplicateResultsCsvTaskRunCount'],
    ),
    'missingResultsCsvTaskRunCount': _intValue(
      artifactBundle['missingResultsCsvTaskRunCount'],
    ),
    'extraResultsCsvTaskRunCount': _intValue(
      artifactBundle['extraResultsCsvTaskRunCount'],
    ),
    'mismatchedResultsCsvRunResultsCount': _intValue(
      artifactBundle['mismatchedResultsCsvRunResultsCount'],
    ),
    'invalidResultsCsvOutcomeCount': _intValue(
      artifactBundle['invalidResultsCsvOutcomeCount'],
    ),
    'artifactReportMarkdownStatus': artifactBundle['reportMarkdownStatus'],
    'reportMarkdownDeclaredTaskRunCount': _intValue(
      artifactBundle['reportMarkdownDeclaredTaskRunCount'],
    ),
    'reportMarkdownTaskRunCount': _intValue(
      artifactBundle['reportMarkdownTaskRunCount'],
    ),
    'missingReportMarkdownSectionCount': _intValue(
      artifactBundle['missingReportMarkdownSectionCount'],
    ),
    'missingReportMarkdownColumnCount': _intValue(
      artifactBundle['missingReportMarkdownColumnCount'],
    ),
    'invalidReportMarkdownTaskRunCount': _intValue(
      artifactBundle['invalidReportMarkdownTaskRunCount'],
    ),
    'duplicateReportMarkdownTaskRunCount': _intValue(
      artifactBundle['duplicateReportMarkdownTaskRunCount'],
    ),
    'missingReportMarkdownTaskRunCount': _intValue(
      artifactBundle['missingReportMarkdownTaskRunCount'],
    ),
    'extraReportMarkdownTaskRunCount': _intValue(
      artifactBundle['extraReportMarkdownTaskRunCount'],
    ),
    'mismatchedReportMarkdownRunResultsCount': _intValue(
      artifactBundle['mismatchedReportMarkdownRunResultsCount'],
    ),
    'invalidReportMarkdownOutcomeCount': _intValue(
      artifactBundle['invalidReportMarkdownOutcomeCount'],
    ),
    'runResultsStatus': artifactBundle['runResultsStatus'],
    'runResultsSchemaVersion': _intValue(
      artifactBundle['runResultsSchemaVersion'],
    ),
    'runResultsRunIdMatchesManifest':
        artifactBundle['runResultsRunIdMatchesManifest'],
    'runResultsRunMetadataStatus':
        artifactBundle['runResultsRunMetadataStatus'],
    'runResultsRunNameMatchesManifest':
        artifactBundle['runResultsRunNameMatchesManifest'],
    'runResultsRunStartedAtMatchesManifest':
        artifactBundle['runResultsRunStartedAtMatchesManifest'],
    'runResultsRunCompletedAtMatchesManifest':
        artifactBundle['runResultsRunCompletedAtMatchesManifest'],
    'mismatchedRunResultsRunMetadataFieldCount': _intValue(
      artifactBundle['mismatchedRunResultsRunMetadataFieldCount'],
    ),
    'runResultsTaskRunCount': _intValue(
      artifactBundle['runResultsTaskRunCount'],
    ),
    'runResultsEvaluationCount': _intValue(
      artifactBundle['runResultsEvaluationCount'],
    ),
    'runResultsEvaluationCountMatchesManifest':
        artifactBundle['runResultsEvaluationCountMatchesManifest'],
    'runResultsEvaluatorIdCount': _intValue(
      artifactBundle['runResultsEvaluatorIdCount'],
    ),
    'runResultsEvaluatorIdsMatchManifest':
        artifactBundle['runResultsEvaluatorIdsMatchManifest'],
    'missingRunResultsEvaluatorIdCount': _intValue(
      artifactBundle['missingRunResultsEvaluatorIdCount'],
    ),
    'extraRunResultsEvaluatorIdCount': _intValue(
      artifactBundle['extraRunResultsEvaluatorIdCount'],
    ),
    'missingRunResultsTaskRunCount': _intValue(
      artifactBundle['missingRunResultsTaskRunCount'],
    ),
    'extraRunResultsTaskRunCount': _intValue(
      artifactBundle['extraRunResultsTaskRunCount'],
    ),
    'mismatchedRunResultsTaskRunCount': _intValue(
      artifactBundle['mismatchedRunResultsTaskRunCount'],
    ),
    'mismatchedRunResultsTaskRunRunIdCount': _intValue(
      artifactBundle['mismatchedRunResultsTaskRunRunIdCount'],
    ),
    'mismatchedRunResultsTrialOutcomeCount': _intValue(
      artifactBundle['mismatchedRunResultsTrialOutcomeCount'],
    ),
    'invalidRunResultsTrialOutcomeCount': _intValue(
      artifactBundle['invalidRunResultsTrialOutcomeCount'],
    ),
    'invalidRunResultsTimingTaskRunCount': _intValue(
      artifactBundle['invalidRunResultsTimingTaskRunCount'],
    ),
    'invalidRunResultsTokenUsageTaskRunCount': _intValue(
      artifactBundle['invalidRunResultsTokenUsageTaskRunCount'],
    ),
    'missingRunResultsEvaluationTaskRunCount': _intValue(
      artifactBundle['missingRunResultsEvaluationTaskRunCount'],
    ),
    'invalidRunResultsEvaluationCount': _intValue(
      artifactBundle['invalidRunResultsEvaluationCount'],
    ),
    'invalidRunResultsEvaluationRationaleCount': _intValue(
      artifactBundle['invalidRunResultsEvaluationRationaleCount'],
    ),
    'invalidRunResultsEvaluationDetailsMetadataCount': _intValue(
      artifactBundle['invalidRunResultsEvaluationDetailsMetadataCount'],
    ),
    'invalidRunResultsBlockedEvaluationMetadataCount': _intValue(
      artifactBundle['invalidRunResultsBlockedEvaluationMetadataCount'],
    ),
    'invalidRunResultsJudgeOverheadMetadataCount': _intValue(
      artifactBundle['invalidRunResultsJudgeOverheadMetadataCount'],
    ),
    'missingRunResultsAgentHarnessStatusMetadataCount': _intValue(
      artifactBundle['missingRunResultsAgentHarnessStatusMetadataCount'],
    ),
    'invalidRunResultsAgentHarnessStatusMetadataCount': _intValue(
      artifactBundle['invalidRunResultsAgentHarnessStatusMetadataCount'],
    ),
    'duplicateRunResultsEvaluationIdCount': _intValue(
      artifactBundle['duplicateRunResultsEvaluationIdCount'],
    ),
    'duplicateRunResultsTaskEvaluatorCount': _intValue(
      artifactBundle['duplicateRunResultsTaskEvaluatorCount'],
    ),
    'invalidRunResultsTaskRunCount': _intValue(
      artifactBundle['invalidRunResultsTaskRunCount'],
    ),
    'invalidRunResultsTaskRunModelIdentityCount':
        invalidRunResultsTaskRunModelIdentityCount,
    'duplicateRunResultsTaskRunCount': _intValue(
      artifactBundle['duplicateRunResultsTaskRunCount'],
    ),
    'missingRunResultsArtifactCount': _intValue(
      artifactBundle['missingRunResultsArtifactCount'],
    ),
    'extraRunResultsArtifactCount': _intValue(
      artifactBundle['extraRunResultsArtifactCount'],
    ),
    'mismatchedRunResultsArtifactCount': _intValue(
      artifactBundle['mismatchedRunResultsArtifactCount'],
    ),
    'missingRunResultsArtifactMetadataCount': _intValue(
      artifactBundle['missingRunResultsArtifactMetadataCount'],
    ),
    'invalidRunResultsArtifactMetadataEntryCount': _intValue(
      artifactBundle['invalidRunResultsArtifactMetadataEntryCount'],
    ),
    'mismatchedRunResultsArtifactMetadataCount': _intValue(
      artifactBundle['mismatchedRunResultsArtifactMetadataCount'],
    ),
    'invalidRunResultsArtifactIdCount': _intValue(
      artifactBundle['invalidRunResultsArtifactIdCount'],
    ),
    'mismatchedRunResultsArtifactIdCount': _intValue(
      artifactBundle['mismatchedRunResultsArtifactIdCount'],
    ),
    'invalidRunResultsArtifactMetadataCount': _intValue(
      artifactBundle['invalidRunResultsArtifactMetadataCount'],
    ),
    'mismatchedRunResultsArtifactByteCount': _intValue(
      artifactBundle['mismatchedRunResultsArtifactByteCount'],
    ),
    'mismatchedRunResultsArtifactDigestCount': _intValue(
      artifactBundle['mismatchedRunResultsArtifactDigestCount'],
    ),
    'missingResponseArtifactCount': _intValue(
      artifactBundle['missingResponseArtifactCount'],
    ),
    'missingAgenticPatchArtifactCount': _intValue(
      artifactBundle['missingAgenticPatchArtifactCount'],
    ),
    'missingAgenticHarnessMetadataCount': _intValue(
      artifactBundle['missingAgenticHarnessMetadataCount'],
    ),
    'missingRunResultsAgenticHarnessMetadataCount': _intValue(
      artifactBundle['missingRunResultsAgenticHarnessMetadataCount'],
    ),
    'mismatchedRunResultsAgenticHarnessMetadataCount': _intValue(
      artifactBundle['mismatchedRunResultsAgenticHarnessMetadataCount'],
    ),
    'missingLeaderboardTrialSummaryTaskRunCount': _intValue(
      artifactBundle['missingLeaderboardTrialSummaryTaskRunCount'],
    ),
    'extraLeaderboardTrialSummaryTaskRunCount': _intValue(
      artifactBundle['extraLeaderboardTrialSummaryTaskRunCount'],
    ),
    'invalidArtifactBundleTaskRunCount': _intValue(
      artifactBundle['invalidTaskRunCount'],
    ),
    'invalidArtifactBundleTaskRunModelIdentityCount':
        invalidArtifactBundleTaskRunModelIdentityCount,
    'duplicateArtifactBundleTaskRunCount': _intValue(
      artifactBundle['duplicateTaskRunCount'],
    ),
    'unknownArtifactKindCount': _intValue(
      artifactBundle['unknownArtifactKindCount'],
    ),
    'duplicateArtifactReferenceCount': _intValue(
      artifactBundle['duplicateArtifactReferenceCount'],
    ),
    'privacyStatus': privacyStatus,
    'privacyIssueCount': _intValue(privacy['issueCount']),
    'modelIdentityStatus': modelIdentity['status'],
    'invalidModelIdentityCount': invalidModelIdentityCount,
    'invalidModelIdentityModelRowCount': _intValue(
      modelIdentity['invalidModelRowCount'],
    ),
    'invalidModelIdentityTaskModelCellCount': _intValue(
      modelIdentity['invalidTaskModelCellCount'],
    ),
    'invalidModelIdentityTrialSummaryCount': _intValue(
      modelIdentity['invalidTrialSummaryCount'],
    ),
    'taskModelCellCount': _intValue(taskModelCells['cellCount']),
    'expectedTaskModelCellCount': _intValue(
      taskModelCells['expectedCellCount'],
    ),
    'missingTaskModelCellCount': missingCellCount,
    'missingTaskModelCellMetricCount': missingMetricCellCount,
    'unknownTaskModelCellTraceMetricCount': unknownTraceMetricCellCount,
    'unknownTaskModelCellTokenUsageCount': unknownTokenUsageCellCount,
    'trialSummaryCount': trialSummaryCount,
    'trialSummaryTotalCount': trialSummaryTotalCount,
    'trialSummaryTruncated': trialSummaryTruncated,
    'missingTrialMetricCount': missingMetricTrialCount,
    'unknownTrialTraceMetricCount': unknownTraceMetricTrialCount,
    'unknownTrialTokenUsageCount': unknownTokenUsageTrialCount,
    'missingPassAtKCount': missingPassAtKCount,
    'missingConfidenceIntervalCount': missingConfidenceIntervalCount,
    'inputFingerprintCount': inputFingerprintCount,
  };
}

String _readinessStatus(bool passed) => passed ? 'passed' : 'blocked';

bool _coversRuns(int coveredRunCount, int runCount) {
  return runCount > 0 && coveredRunCount >= runCount;
}

bool _requiredFailureTagsPresent(List<String> failureTags) {
  return failureTags.contains('pass') &&
      failureTags.contains('public_tests_failed') &&
      failureTags.contains('hidden_verifier_failed');
}

int _inputFingerprintCount(Map<String, Object?>? inputs) {
  if (inputs == null) return 0;
  var count = 0;

  void scan(Object? value) {
    if (value is Map) {
      final map = <String, Object?>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
      if (_isInputFingerprint(map)) count++;
      for (final child in value.values) {
        scan(child);
      }
      return;
    }
    if (value is List) {
      for (final child in value) {
        scan(child);
      }
    }
  }

  scan(inputs);
  return count;
}

bool _isInputFingerprint(Map<String, Object?> value) {
  final path = value['path'];
  final bytes = value['bytes'];
  final sha256 = value['sha256'];
  return path is String &&
      path.trim().isNotEmpty &&
      bytes is num &&
      bytes > 0 &&
      sha256 is String &&
      RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256);
}

Map<String, Object?> _publicLeaderboardPrivacyAudit({
  required Map<String, Object?> leaderboard,
  required Set<String> blockers,
}) {
  var secretKeyCount = 0;
  var secretValueCount = 0;
  var absolutePathCount = 0;
  var hiddenVerifierMarkerCount = 0;
  var privatePromptFieldCount = 0;
  var sensitiveModelOutputFieldCount = 0;

  void scan(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_isPublicSecretKey(key)) secretKeyCount++;
        if (_isPrivatePromptFieldKey(key)) privatePromptFieldCount++;
        if (_isSensitiveModelOutputFieldKey(key)) {
          sensitiveModelOutputFieldCount++;
        }
        if (_isHiddenVerifierContentKey(key)) hiddenVerifierMarkerCount++;
        scan(entry.value);
      }
      return;
    }
    if (value is List) {
      for (final item in value) {
        scan(item);
      }
      return;
    }
    if (value is String) {
      if (_containsPrivatePath(value)) absolutePathCount++;
      if (_looksLikeSecretValue(value)) secretValueCount++;
      if (_containsHiddenVerifierContentMarker(value)) {
        hiddenVerifierMarkerCount++;
      }
    }
  }

  scan(leaderboard);

  if (secretKeyCount > 0 || secretValueCount > 0) {
    blockers.add(
      'Leaderboard public export privacy audit found secret-looking content.',
    );
  }
  if (absolutePathCount > 0) {
    blockers.add(
      'Leaderboard public export privacy audit found private local path content.',
    );
  }
  if (hiddenVerifierMarkerCount > 0) {
    blockers.add(
      'Leaderboard public export privacy audit found hidden verifier content markers.',
    );
  }
  if (privatePromptFieldCount > 0 || sensitiveModelOutputFieldCount > 0) {
    blockers.add(
      'Leaderboard public export privacy audit found private prompt or model output fields.',
    );
  }

  final issueCount =
      secretKeyCount +
      secretValueCount +
      absolutePathCount +
      hiddenVerifierMarkerCount +
      privatePromptFieldCount +
      sensitiveModelOutputFieldCount;
  return {
    'status': issueCount == 0 ? 'passed' : 'blocked',
    'issueCount': issueCount,
    'secretKeyCount': secretKeyCount,
    'secretValueCount': secretValueCount,
    'absolutePathCount': absolutePathCount,
    'hiddenVerifierMarkerCount': hiddenVerifierMarkerCount,
    'privatePromptFieldCount': privatePromptFieldCount,
    'sensitiveModelOutputFieldCount': sensitiveModelOutputFieldCount,
  };
}

Map<String, Object?> _scoringSummary(
  Map<String, Object?> leaderboard,
  Set<String> blockers,
) {
  final rawScoring = leaderboard['scoring'];
  final scoring = _objectMap(rawScoring);
  final objectiveEvaluatorIds = _stringList(scoring['objectiveEvaluatorIds']);
  final secondaryEvaluatorIds = _stringList(scoring['secondaryEvaluatorIds']);
  final diagnosticOnlyEvaluatorIds = _stringList(
    scoring['diagnosticOnlyEvaluatorIds'],
  );
  final failureTags = _stringList(scoring['failureTags']);
  final objectiveFailureCaps = _objectMap(scoring['objectiveFailureCaps']);
  final defaultEvaluatorWeights = _objectMap(
    scoring['defaultEvaluatorWeights'],
  );

  if (rawScoring is! Map ||
      scoring['schemaVersion'] is! num ||
      scoring['primaryMetric'] is! String ||
      scoring['rankingMetric'] is! String ||
      scoring['confidenceInterval'] is! String ||
      scoring['llmJudgePolicy'] is! String ||
      scoring['diffSizePolicy'] is! String ||
      scoring['objectiveEvaluatorIds'] is! List ||
      scoring['secondaryEvaluatorIds'] is! List ||
      scoring['diagnosticOnlyEvaluatorIds'] is! List ||
      scoring['hiddenVerifierPattern'] is! String ||
      scoring['failureTags'] is! List ||
      scoring['objectiveFailureCaps'] is! Map ||
      scoring['defaultEvaluatorWeights'] is! Map) {
    blockers.add('Leaderboard export has incomplete scoring metadata.');
  }
  if (_intValue(scoring['schemaVersion']) < _requiredScoringSchemaVersion) {
    blockers.add('Leaderboard scoring schema version is stale.');
  }
  if (scoring['primaryMetric'] != 'primary_pass') {
    blockers.add('Leaderboard scoring primary metric is not primary_pass.');
  }
  if (scoring['rankingMetric'] != 'primary_pass_rate') {
    blockers.add(
      'Leaderboard scoring ranking metric is not primary_pass_rate.',
    );
  }
  if (scoring['confidenceInterval'] != 'wilson_95') {
    blockers.add('Leaderboard scoring confidence interval is not wilson_95.');
  }
  if (scoring['diffSizePolicy'] != _requiredDiffSizePolicy) {
    blockers.add(
      'Leaderboard scoring diff_size policy is not diagnostic_only_full_patch.',
    );
  }
  if (!diagnosticOnlyEvaluatorIds.contains(_diffSizeEvaluatorId)) {
    blockers.add(
      'Leaderboard scoring diagnostic-only evaluator ids are incomplete.',
    );
  }
  if (!failureTags.contains('pass') ||
      !failureTags.contains('public_tests_failed') ||
      !failureTags.contains('hidden_verifier_failed')) {
    blockers.add('Leaderboard scoring failure tags are incomplete.');
  }

  return {
    'schemaVersion': _intValue(scoring['schemaVersion']),
    'primaryMetric': scoring['primaryMetric'],
    'rankingMetric': scoring['rankingMetric'],
    'confidenceInterval': scoring['confidenceInterval'],
    'llmJudgePolicy': scoring['llmJudgePolicy'],
    'diffSizePolicy': scoring['diffSizePolicy'],
    'objectiveEvaluatorIds': objectiveEvaluatorIds,
    'secondaryEvaluatorIds': secondaryEvaluatorIds,
    'diagnosticOnlyEvaluatorIds': diagnosticOnlyEvaluatorIds,
    'hiddenVerifierPattern': scoring['hiddenVerifierPattern'],
    'failureTags': failureTags,
    'objectiveFailureCaps': {
      for (final entry in objectiveFailureCaps.entries)
        entry.key: _numValue(entry.value),
    },
    'defaultEvaluatorWeights': {
      for (final entry in defaultEvaluatorWeights.entries)
        entry.key: _numValue(entry.value),
    },
  };
}

Map<String, Object?> _judgeOverheadSummary(
  Map<String, Object?> source,
  Set<String> blockers,
) {
  final overhead = _objectMap(source['judgeOverhead']);
  final evaluationCount = _intValue(overhead['evaluationCount']);
  final knownEstimatedCostCount = _intValue(
    overhead['knownEstimatedCostCount'],
  );
  final unknownEstimatedCostCount = _intValue(
    overhead['unknownEstimatedCostCount'],
  );
  final totalEstimatedCostMicros = _intValue(
    overhead['totalEstimatedCostMicros'],
  );
  final pricingStatusCounts = _objectMap(overhead['pricingStatusCounts']);

  final metadataComplete =
      source['judgeOverhead'] is Map &&
      overhead['evaluationCount'] is num &&
      overhead['knownEstimatedCostCount'] is num &&
      overhead['unknownEstimatedCostCount'] is num &&
      overhead['totalEstimatedCostMicros'] is num &&
      overhead['pricingStatusCounts'] is Map;
  if (!metadataComplete) {
    blockers.add('Leaderboard source has incomplete judge overhead summary.');
  }

  return {
    'status': metadataComplete ? 'present' : 'incomplete',
    'evaluationCount': evaluationCount,
    'promptTokens': _intValue(overhead['promptTokens']),
    'completionTokens': _intValue(overhead['completionTokens']),
    'knownEstimatedCostCount': knownEstimatedCostCount,
    'unknownEstimatedCostCount': unknownEstimatedCostCount,
    'totalEstimatedCostMicros': totalEstimatedCostMicros,
    'pricingStatusCounts': {
      for (final entry in pricingStatusCounts.entries)
        entry.key: _intValue(entry.value),
    },
  };
}

Map<String, Object?> _sourceRunProvenanceSummary({
  required Map<String, Object?> source,
  required List<String> runIds,
  required Set<String> blockers,
  required Set<String> reportWarnings,
  required bool allowMixedEnvironmentAggregates,
}) {
  final sourceRunProvenance = _objectMap(source['runProvenance']);
  final rawSourceRunProvenance = source['runProvenance'];
  final runCount = _intValue(sourceRunProvenance['runCount']);
  final embeddedRunCount = _intValue(sourceRunProvenance['embeddedRunCount']);
  final sandboxEnforcedRunCount = _intValue(
    sourceRunProvenance['sandboxEnforcedRunCount'],
  );
  final taskExecutionPolicyRunCount = _intValue(
    sourceRunProvenance['taskExecutionPolicyRunCount'],
  );
  final networkDisabledTaskPolicyRunCount = _intValue(
    sourceRunProvenance['networkDisabledTaskPolicyRunCount'],
  );
  final taskResourceLimitRunCount = _intValue(
    sourceRunProvenance['taskResourceLimitRunCount'],
  );
  final sdkVersionRunCount = _intValue(
    sourceRunProvenance['sdkVersionRunCount'],
  );
  final dependencySnapshotRunCount = _intValue(
    sourceRunProvenance['dependencySnapshotRunCount'],
  );
  final pricingRegistryRunCount = _intValue(
    sourceRunProvenance['pricingRegistryRunCount'],
  );
  final warnings = _stringList(sourceRunProvenance['warnings']);

  if (rawSourceRunProvenance is! Map ||
      sourceRunProvenance['runCount'] is! num ||
      sourceRunProvenance['embeddedRunCount'] is! num ||
      sourceRunProvenance['sandboxEnforcedRunCount'] is! num ||
      sourceRunProvenance['taskExecutionPolicyRunCount'] is! num ||
      sourceRunProvenance['networkDisabledTaskPolicyRunCount'] is! num ||
      sourceRunProvenance['taskResourceLimitRunCount'] is! num ||
      sourceRunProvenance['sdkVersionRunCount'] is! num ||
      sourceRunProvenance['dependencySnapshotRunCount'] is! num ||
      sourceRunProvenance['pricingRegistryRunCount'] is! num ||
      sourceRunProvenance['generatedCodeSandboxBackends'] is! List ||
      sourceRunProvenance['dartVersions'] is! List ||
      sourceRunProvenance['flutterVersions'] is! List ||
      sourceRunProvenance['environmentIds'] is! List ||
      sourceRunProvenance['warnings'] is! List) {
    blockers.add('Leaderboard source has incomplete run provenance summary.');
  }
  if (runCount != runIds.length) {
    blockers.add(
      'Leaderboard source run provenance count does not match runIds.',
    );
  }
  for (final warning in warnings) {
    blockers.add('Leaderboard source run provenance warning: $warning');
  }
  _blockMixedEnvironmentAggregates(
    sourceRunProvenance: sourceRunProvenance,
    blockers: blockers,
    reportWarnings: reportWarnings,
    allowMixedEnvironmentAggregates: allowMixedEnvironmentAggregates,
  );
  _blockIfIncompleteRunCoverage(
    blockers: blockers,
    fieldLabel: 'stored provenance',
    runCount: runCount,
    coveredRunCount: embeddedRunCount,
  );
  _blockIfIncompleteRunCoverage(
    blockers: blockers,
    fieldLabel: 'generated-code sandbox enforcement',
    runCount: runCount,
    coveredRunCount: sandboxEnforcedRunCount,
  );
  _blockIfIncompleteRunCoverage(
    blockers: blockers,
    fieldLabel: 'task execution policy provenance',
    runCount: runCount,
    coveredRunCount: taskExecutionPolicyRunCount,
  );
  _blockIfIncompleteRunCoverage(
    blockers: blockers,
    fieldLabel: 'network-disabled task policy provenance',
    runCount: runCount,
    coveredRunCount: networkDisabledTaskPolicyRunCount,
  );
  _blockIfIncompleteRunCoverage(
    blockers: blockers,
    fieldLabel: 'enforced task resource limit provenance',
    runCount: runCount,
    coveredRunCount: taskResourceLimitRunCount,
  );
  _blockIfIncompleteRunCoverage(
    blockers: blockers,
    fieldLabel: 'SDK version provenance',
    runCount: runCount,
    coveredRunCount: sdkVersionRunCount,
  );
  _blockIfIncompleteRunCoverage(
    blockers: blockers,
    fieldLabel: 'dependency lockfile provenance',
    runCount: runCount,
    coveredRunCount: dependencySnapshotRunCount,
  );
  _blockIfIncompleteRunCoverage(
    blockers: blockers,
    fieldLabel: 'pricing registry provenance',
    runCount: runCount,
    coveredRunCount: pricingRegistryRunCount,
  );

  return {
    'runCount': runCount,
    'embeddedRunCount': embeddedRunCount,
    'sandboxEnforcedRunCount': sandboxEnforcedRunCount,
    'taskExecutionPolicyRunCount': taskExecutionPolicyRunCount,
    'networkDisabledTaskPolicyRunCount': networkDisabledTaskPolicyRunCount,
    'taskResourceLimitRunCount': taskResourceLimitRunCount,
    'sdkVersionRunCount': sdkVersionRunCount,
    'dependencySnapshotRunCount': dependencySnapshotRunCount,
    'pricingRegistryRunCount': pricingRegistryRunCount,
    'generatedCodeSandboxBackends': _stringList(
      sourceRunProvenance['generatedCodeSandboxBackends'],
    ),
    'dartVersions': _stringList(sourceRunProvenance['dartVersions']),
    'flutterVersions': _stringList(sourceRunProvenance['flutterVersions']),
    'environmentIds': _stringList(sourceRunProvenance['environmentIds']),
    'warnings': warnings,
  };
}

void _blockMixedEnvironmentAggregates({
  required Map<String, Object?> sourceRunProvenance,
  required Set<String> blockers,
  required Set<String> reportWarnings,
  required bool allowMixedEnvironmentAggregates,
}) {
  const fields = {
    'environmentIds': 'environment ID',
    'dartVersions': 'Dart version',
    'flutterVersions': 'Flutter version',
  };
  for (final entry in fields.entries) {
    final values = _stringList(sourceRunProvenance[entry.key]);
    if (values.length <= 1) continue;
    final message =
        'Leaderboard aggregate spans ${values.length} ${entry.value}s: '
        '${values.join(', ')}.';
    if (allowMixedEnvironmentAggregates) {
      reportWarnings.add(
        '$message Permitted by allowMixedEnvironmentAggregates policy.',
      );
    } else {
      blockers.add(
        '$message Aggregates must not span multiple execution environments '
        'unless the mixed-environment aggregation policy is explicitly '
        'enabled.',
      );
    }
  }
}

void _blockIfIncompleteRunCoverage({
  required Set<String> blockers,
  required String fieldLabel,
  required int runCount,
  required int coveredRunCount,
}) {
  if (coveredRunCount >= runCount) return;
  blockers.add(
    'Leaderboard source run provenance has ${runCount - coveredRunCount} '
    'run(s) without $fieldLabel.',
  );
}

void _crossCheckSourceRunProvenance({
  required Map<String, Object?> sourceRunProvenance,
  required Map<String, Object?> storedRunProvenance,
  required Set<String> blockers,
}) {
  const fields = {
    'embeddedRunCount': 'embedded run',
    'sandboxEnforcedRunCount': 'sandbox enforcement',
    'taskExecutionPolicyRunCount': 'task execution policy',
    'networkDisabledTaskPolicyRunCount': 'network-disabled task policy',
    'taskResourceLimitRunCount': 'enforced task resource limits',
    'sdkVersionRunCount': 'SDK version',
    'dependencySnapshotRunCount': 'dependency snapshot',
    'pricingRegistryRunCount': 'pricing registry',
  };
  for (final entry in fields.entries) {
    if (_intValue(sourceRunProvenance[entry.key]) ==
        _intValue(storedRunProvenance[entry.key])) {
      continue;
    }
    blockers.add(
      'Leaderboard source run provenance ${entry.value} count does not match '
      'stored run provenance.',
    );
  }

  const environmentFields = {
    'environmentIds': 'environment IDs',
    'dartVersions': 'Dart versions',
    'flutterVersions': 'Flutter versions',
  };
  for (final entry in environmentFields.entries) {
    final sourceValues = _stringList(sourceRunProvenance[entry.key])..sort();
    final storedValues = _stringList(storedRunProvenance[entry.key])..sort();
    if (_stringListsEqual(sourceValues, storedValues)) continue;
    blockers.add(
      'Leaderboard source run provenance ${entry.value} do not match stored '
      'run provenance.',
    );
  }
}

Map<String, Object?> _taskModelCellSummary({
  required Object? rawCells,
  required List<Map<String, Object?>> cells,
  required List<Map<String, Object?>> modelRows,
  required List<Map<String, Object?>> taskRows,
  required Set<String> blockers,
  required Set<String> warnings,
}) {
  if (rawCells is! List) {
    blockers.add('Leaderboard export has no task-model cell summary.');
  }

  final expectedKeys = <String>{};
  for (final model in modelRows) {
    final providerId = model['providerId'];
    final modelId = model['modelId'];
    if (providerId is! String || providerId.trim().isEmpty) continue;
    if (modelId is! String || modelId.trim().isEmpty) continue;
    for (final task in taskRows) {
      final taskId = task['taskId'];
      if (taskId is! String || taskId.trim().isEmpty) continue;
      expectedKeys.add(
        _taskModelCellKey(
          providerId: providerId,
          modelId: modelId,
          taskId: taskId,
          taskVersion: task['taskVersion'],
          benchmarkTrack: task['benchmarkTrack'],
        ),
      );
    }
  }

  final observedKeys = <String>{};
  var sampleCount = 0;
  var errorCount = 0;
  var missingMetricCellCount = 0;
  var unknownCostCellCount = 0;
  var unknownTraceMetricCellCount = 0;
  var unknownTokenUsageCellCount = 0;
  for (final cell in cells) {
    final providerId = cell['providerId'];
    final modelId = cell['modelId'];
    final taskId = cell['taskId'];
    if (providerId is String && modelId is String && taskId is String) {
      observedKeys.add(
        _taskModelCellKey(
          providerId: providerId,
          modelId: modelId,
          taskId: taskId,
          taskVersion: cell['taskVersion'],
          benchmarkTrack: cell['benchmarkTrack'],
        ),
      );
    }

    sampleCount += _intValue(cell['sampleCount']);
    errorCount += _intValue(cell['errorCount']);
    if (_intValue(cell['unknownEstimatedCostCount']) > 0) {
      unknownCostCellCount++;
    }
    if (_taskModelCellHasUnknownTraceMetrics(cell)) {
      unknownTraceMetricCellCount++;
    }
    if (_taskModelCellHasUnknownTokenUsage(cell)) {
      unknownTokenUsageCellCount++;
    }
    if (!_taskModelCellHasRequiredMetrics(cell)) {
      missingMetricCellCount++;
    }
  }

  final missingKeys = expectedKeys.difference(observedKeys);
  if (missingKeys.isNotEmpty) {
    blockers.add(
      'Leaderboard task-model cells are missing ${missingKeys.length} '
      'expected model/task combination(s).',
    );
  }
  if (missingMetricCellCount > 0) {
    blockers.add(
      'Leaderboard task-model cells have $missingMetricCellCount cell(s) '
      'with incomplete public metrics.',
    );
  }
  if (unknownCostCellCount > 0) {
    warnings.add(
      'Leaderboard task-model cells include $unknownCostCellCount cell(s) '
      'with unknown candidate cost.',
    );
  }
  if (unknownTraceMetricCellCount > 0) {
    warnings.add(
      'Leaderboard task-model cells include $unknownTraceMetricCellCount '
      'cell(s) with unknown agent trace metrics.',
    );
  }
  if (unknownTokenUsageCellCount > 0) {
    warnings.add(
      'Leaderboard task-model cells include $unknownTokenUsageCellCount '
      'cell(s) with unknown token usage.',
    );
  }

  return {
    'cellCount': cells.length,
    'expectedCellCount': expectedKeys.length,
    'missingCellCount': missingKeys.length,
    'sampleCount': sampleCount,
    'errorCount': errorCount,
    'unknownCostCellCount': unknownCostCellCount,
    'unknownTraceMetricCellCount': unknownTraceMetricCellCount,
    'unknownTokenUsageCellCount': unknownTokenUsageCellCount,
    'missingMetricCellCount': missingMetricCellCount,
  };
}

Map<String, Object?> _modelIdentitySummary({
  required List<Map<String, Object?>> modelRows,
  required List<Map<String, Object?>> taskModelCells,
  required List<Map<String, Object?>> trialSummaries,
  required Set<String> blockers,
}) {
  final invalidModelRowCount = modelRows
      .where((row) => !_validModelIdentityMetadata(row))
      .length;
  final invalidTaskModelCellCount = taskModelCells
      .where((row) => !_validModelIdentityMetadata(row))
      .length;
  final invalidTrialSummaryCount = trialSummaries
      .where((row) => !_validModelIdentityMetadata(row))
      .length;
  final invalidModelIdentityCount =
      invalidModelRowCount +
      invalidTaskModelCellCount +
      invalidTrialSummaryCount;

  if (invalidModelIdentityCount > 0) {
    blockers.add(
      'Leaderboard model identity metadata is invalid for $invalidModelIdentityCount public row(s).',
    );
  }

  return {
    'status': invalidModelIdentityCount == 0 ? 'present' : 'invalid',
    'invalidModelRowCount': invalidModelRowCount,
    'invalidTaskModelCellCount': invalidTaskModelCellCount,
    'invalidTrialSummaryCount': invalidTrialSummaryCount,
    'invalidModelIdentityCount': invalidModelIdentityCount,
  };
}

bool _taskModelCellHasRequiredMetrics(Map<String, Object?> cell) {
  final sampleCount = _intValue(cell['sampleCount']);
  final traceCoverage = _objectMap(cell['traceMetricCoverage']);
  final tokenCoverage = _objectMap(cell['tokenUsageCoverage']);
  return cell['providerId'] is String &&
      (cell['providerId']! as String).trim().isNotEmpty &&
      cell['modelId'] is String &&
      (cell['modelId']! as String).trim().isNotEmpty &&
      cell['taskId'] is String &&
      (cell['taskId']! as String).trim().isNotEmpty &&
      cell['sampleCount'] is num &&
      cell['trialCount'] is num &&
      cell['passCount'] is num &&
      cell['errorCount'] is num &&
      cell['passRate'] is num &&
      _hasConfidenceIntervalSummary(cell) &&
      _hasTraceMetricCoverage(traceCoverage, sampleCount) &&
      _aggregateMetricReportedOrExplicitlyUnknown(
        cell['medianStepCount'],
        traceCoverage,
        knownKey: 'stepCountKnownCount',
        unknownKey: 'stepCountUnknownCount',
        sampleCount: sampleCount,
      ) &&
      _aggregateMetricReportedOrExplicitlyUnknown(
        cell['medianPeakContextTokens'],
        traceCoverage,
        knownKey: 'peakContextTokensKnownCount',
        unknownKey: 'peakContextTokensUnknownCount',
        sampleCount: sampleCount,
      ) &&
      cell['medianLatencyMs'] is num &&
      _hasTokenUsageCoverage(tokenCoverage, sampleCount) &&
      _aggregateMetricReportedOrExplicitlyUnknown(
        cell['medianPromptTokens'],
        tokenCoverage,
        knownKey: 'promptTokensKnownCount',
        unknownKey: 'promptTokensUnknownCount',
        sampleCount: sampleCount,
      ) &&
      _aggregateMetricReportedOrExplicitlyUnknown(
        cell['medianCompletionTokens'],
        tokenCoverage,
        knownKey: 'completionTokensKnownCount',
        unknownKey: 'completionTokensUnknownCount',
        sampleCount: sampleCount,
      ) &&
      cell['failureBreakdown'] is Map &&
      cell['blockedTaskRunCount'] is num &&
      cell['knownEstimatedCostCount'] is num &&
      cell['unknownEstimatedCostCount'] is num;
}

bool _taskModelCellHasUnknownTraceMetrics(Map<String, Object?> cell) {
  final coverage = _objectMap(cell['traceMetricCoverage']);
  return _intValue(coverage['stepCountUnknownCount']) > 0 ||
      _intValue(coverage['peakContextTokensUnknownCount']) > 0;
}

bool _taskModelCellHasUnknownTokenUsage(Map<String, Object?> cell) {
  final coverage = _objectMap(cell['tokenUsageCoverage']);
  return _intValue(coverage['promptTokensUnknownCount']) > 0 ||
      _intValue(coverage['completionTokensUnknownCount']) > 0;
}

bool _hasTraceMetricCoverage(Map<String, Object?> coverage, int sampleCount) {
  final complete = coverage['completeTraceMetricCount'];
  return _hasMetricCoverage(
        coverage,
        sampleCount,
        knownKey: 'stepCountKnownCount',
        unknownKey: 'stepCountUnknownCount',
      ) &&
      _hasMetricCoverage(
        coverage,
        sampleCount,
        knownKey: 'peakContextTokensKnownCount',
        unknownKey: 'peakContextTokensUnknownCount',
      ) &&
      complete is num &&
      complete >= 0 &&
      complete <= sampleCount;
}

bool _hasTokenUsageCoverage(Map<String, Object?> coverage, int sampleCount) {
  final complete = coverage['completeTokenUsageCount'];
  return _hasMetricCoverage(
        coverage,
        sampleCount,
        knownKey: 'promptTokensKnownCount',
        unknownKey: 'promptTokensUnknownCount',
      ) &&
      _hasMetricCoverage(
        coverage,
        sampleCount,
        knownKey: 'completionTokensKnownCount',
        unknownKey: 'completionTokensUnknownCount',
      ) &&
      complete is num &&
      complete >= 0 &&
      complete <= sampleCount;
}

bool _hasMetricCoverage(
  Map<String, Object?> coverage,
  int sampleCount, {
  required String knownKey,
  required String unknownKey,
}) {
  final coverageSampleCount = coverage['sampleCount'];
  final known = coverage[knownKey];
  final unknown = coverage[unknownKey];
  if (coverageSampleCount is! num ||
      known is! num ||
      unknown is! num ||
      coverageSampleCount < 0 ||
      known < 0 ||
      unknown < 0) {
    return false;
  }
  return coverageSampleCount.toInt() == sampleCount &&
      known.toInt() + unknown.toInt() == sampleCount;
}

bool _aggregateMetricReportedOrExplicitlyUnknown(
  Object? value,
  Map<String, Object?> coverage, {
  required String knownKey,
  required String unknownKey,
  required int sampleCount,
}) {
  if (value is num) return true;
  if (value != null) return false;
  return _intValue(coverage[knownKey]) == 0 &&
      _intValue(coverage[unknownKey]) == sampleCount;
}

Map<String, Object?> _trialTransparencySummary({
  required Map<String, Object?> source,
  required Object? rawTrialSummaries,
  required List<Map<String, Object?>> trialSummaries,
  required int taskRunCount,
  required List<Map<String, Object?>> modelRows,
  required List<Map<String, Object?>> taskRows,
  required List<Map<String, Object?>> taskModelCells,
  required Set<String> blockers,
  required Set<String> warnings,
}) {
  final trialSummaryCount = _intValue(source['trialSummaryCount']);
  final trialSummaryTotalCount = _intValue(source['trialSummaryTotalCount']);
  final trialSummaryLimit = _intValue(source['trialSummaryLimit']);
  final trialSummaryTruncated = source['trialSummaryTruncated'] == true;

  if (rawTrialSummaries is! List ||
      source['trialSummaryCount'] is! num ||
      source['trialSummaryTotalCount'] is! num ||
      source['trialSummaryLimit'] is! num ||
      source['trialSummaryTruncated'] is! bool) {
    blockers.add('Leaderboard export has incomplete trial summary metadata.');
  }
  if (trialSummaryTotalCount != taskRunCount) {
    blockers.add(
      'Leaderboard trial summary total does not match taskRunCount.',
    );
  }
  if (trialSummaryCount != trialSummaries.length) {
    blockers.add(
      'Leaderboard trial summary count does not match exported trial summaries.',
    );
  }
  if (trialSummaryTruncated || trialSummaryCount < taskRunCount) {
    blockers.add(
      'Leaderboard trial summaries are truncated before covering all task runs.',
    );
  }

  var missingMetricTrialCount = 0;
  var unknownCostTrialCount = 0;
  var unknownTraceMetricTrialCount = 0;
  var unknownTokenUsageTrialCount = 0;
  for (final trial in trialSummaries) {
    if (!_trialSummaryHasRequiredMetrics(trial)) {
      missingMetricTrialCount++;
    }
    if (trial['estimatedCostMicros'] is! num) {
      unknownCostTrialCount++;
    }
    if (_trialHasUnknownTraceMetrics(trial)) {
      unknownTraceMetricTrialCount++;
    }
    if (_trialHasUnknownTokenUsage(trial)) {
      unknownTokenUsageTrialCount++;
    }
  }
  if (missingMetricTrialCount > 0) {
    blockers.add(
      'Leaderboard trial summaries have $missingMetricTrialCount trial(s) '
      'with incomplete public metrics.',
    );
  }
  if (unknownCostTrialCount > 0) {
    warnings.add(
      'Leaderboard trial summaries include $unknownCostTrialCount trial(s) '
      'with unknown candidate cost.',
    );
  }
  if (unknownTraceMetricTrialCount > 0) {
    warnings.add(
      'Leaderboard trial summaries include $unknownTraceMetricTrialCount '
      'trial(s) with unknown agent trace metrics.',
    );
  }
  if (unknownTokenUsageTrialCount > 0) {
    warnings.add(
      'Leaderboard trial summaries include $unknownTokenUsageTrialCount '
      'trial(s) with unknown token usage.',
    );
  }

  final missingModelPassAtKCount = modelRows
      .where((row) => !_hasPassAtKSummary(row))
      .length;
  final missingTaskPassAtKCount = taskRows
      .where((row) => !_hasPassAtKSummary(row))
      .length;
  final missingCellPassAtKCount = taskModelCells
      .where((row) => !_hasPassAtKSummary(row))
      .length;
  final missingPassAtKCount =
      missingModelPassAtKCount +
      missingTaskPassAtKCount +
      missingCellPassAtKCount;
  if (missingPassAtKCount > 0) {
    blockers.add(
      'Leaderboard pass@k summaries are missing or incomplete for '
      '$missingPassAtKCount public row(s).',
    );
  }

  final missingModelConfidenceIntervalCount = modelRows
      .where((row) => !_hasConfidenceIntervalSummary(row))
      .length;
  final missingTaskConfidenceIntervalCount = taskRows
      .where((row) => !_hasConfidenceIntervalSummary(row))
      .length;
  final missingCellConfidenceIntervalCount = taskModelCells
      .where((row) => !_hasConfidenceIntervalSummary(row))
      .length;
  final missingConfidenceIntervalCount =
      missingModelConfidenceIntervalCount +
      missingTaskConfidenceIntervalCount +
      missingCellConfidenceIntervalCount;
  if (missingConfidenceIntervalCount > 0) {
    blockers.add(
      'Leaderboard confidence intervals are missing or incomplete for '
      '$missingConfidenceIntervalCount public row(s).',
    );
  }

  return {
    'trialSummaryCount': trialSummaryCount,
    'trialSummaryTotalCount': trialSummaryTotalCount,
    'trialSummaryLimit': trialSummaryLimit,
    'trialSummaryTruncated': trialSummaryTruncated,
    'missingMetricTrialCount': missingMetricTrialCount,
    'unknownCostTrialCount': unknownCostTrialCount,
    'unknownTraceMetricTrialCount': unknownTraceMetricTrialCount,
    'unknownTokenUsageTrialCount': unknownTokenUsageTrialCount,
    'missingModelPassAtKCount': missingModelPassAtKCount,
    'missingTaskPassAtKCount': missingTaskPassAtKCount,
    'missingCellPassAtKCount': missingCellPassAtKCount,
    'missingModelConfidenceIntervalCount': missingModelConfidenceIntervalCount,
    'missingTaskConfidenceIntervalCount': missingTaskConfidenceIntervalCount,
    'missingCellConfidenceIntervalCount': missingCellConfidenceIntervalCount,
  };
}

bool _trialSummaryHasRequiredMetrics(Map<String, Object?> trial) {
  final taskVersion = trial['taskVersion'];
  final publicPassed = trial['publicPassed'];
  final hiddenPassed = trial['hiddenPassed'];
  final traceMetricStatus = _objectMap(trial['traceMetricStatus']);
  final tokenUsageStatus = _objectMap(trial['tokenUsageStatus']);
  return trial['trialId'] is String &&
      (trial['trialId']! as String).trim().isNotEmpty &&
      trial['runId'] is String &&
      (trial['runId']! as String).trim().isNotEmpty &&
      trial['providerId'] is String &&
      (trial['providerId']! as String).trim().isNotEmpty &&
      trial['modelId'] is String &&
      (trial['modelId']! as String).trim().isNotEmpty &&
      trial['taskId'] is String &&
      (trial['taskId']! as String).trim().isNotEmpty &&
      (taskVersion is String || taskVersion is num) &&
      trial['benchmarkTrack'] is String &&
      (trial['benchmarkTrack']! as String).trim().isNotEmpty &&
      trial['trialIndex'] is num &&
      trial['completedAt'] is String &&
      (trial['completedAt']! as String).trim().isNotEmpty &&
      trial['primaryPass'] is bool &&
      trial['failureTag'] is String &&
      (trial['failureTag']! as String).trim().isNotEmpty &&
      trial['aggregateScore'] is num &&
      (publicPassed == null || publicPassed is bool) &&
      (hiddenPassed == null || hiddenPassed is bool) &&
      trial['blockedEvaluationCount'] is num &&
      _trialMetricReportedOrExplicitlyUnknown(
        trial['stepCount'],
        traceMetricStatus['stepCount'],
      ) &&
      _trialMetricReportedOrExplicitlyUnknown(
        trial['peakContextTokens'],
        traceMetricStatus['peakContextTokens'],
      ) &&
      trial['latencyMs'] is num &&
      _trialMetricReportedOrExplicitlyUnknown(
        trial['promptTokens'],
        tokenUsageStatus['promptTokens'],
      ) &&
      _trialMetricReportedOrExplicitlyUnknown(
        trial['completionTokens'],
        tokenUsageStatus['completionTokens'],
      );
}

bool _trialMetricReportedOrExplicitlyUnknown(Object? value, Object? status) {
  if (value is num) return status == 'reported';
  if (value == null) return status == 'unknown';
  return false;
}

bool _trialHasUnknownTraceMetrics(Map<String, Object?> trial) {
  final status = _objectMap(trial['traceMetricStatus']);
  return status['stepCount'] == 'unknown' ||
      status['peakContextTokens'] == 'unknown';
}

bool _trialHasUnknownTokenUsage(Map<String, Object?> trial) {
  final status = _objectMap(trial['tokenUsageStatus']);
  return status['promptTokens'] == 'unknown' ||
      status['completionTokens'] == 'unknown';
}

bool _hasPassAtKSummary(Map<String, Object?> row) {
  final passAtK = _objectMap(row['passAtK']);
  final passAt1 = _objectMap(passAtK['1']);
  return passAt1['k'] is num &&
      passAt1['passCount'] is num &&
      passAt1['sampleCount'] is num &&
      passAt1['passRate'] is num;
}

bool _hasConfidenceIntervalSummary(Map<String, Object?> row) {
  final interval = _objectMap(row['confidenceInterval']);
  return interval['lower'] is num && interval['upper'] is num;
}

String _taskModelCellKey({
  required String providerId,
  required String modelId,
  required String taskId,
  required Object? taskVersion,
  required Object? benchmarkTrack,
}) {
  return [
    providerId,
    modelId,
    taskId,
    taskVersion?.toString() ?? 'unknown-version',
    benchmarkTrack?.toString() ?? 'unknown-track',
  ].join('\u001f');
}

String? _leaderboardTaskQaKey(Map<String, Object?> task) {
  final taskId = task['taskId'];
  final taskVersion = task['taskVersion'];
  final track = task['benchmarkTrack'] ?? task['track'];
  if (taskId is! String ||
      taskId.trim().isEmpty ||
      taskVersion == null ||
      track is! String ||
      track.trim().isEmpty) {
    return null;
  }
  return _taskQaKey(taskId: taskId, taskVersion: taskVersion, track: track);
}

String? _taskQaReportKey(Map<String, Object?> report) {
  final taskId = report['taskId'];
  final taskVersion = report['taskVersion'];
  final track = report['track'];
  if (taskId is! String ||
      taskId.trim().isEmpty ||
      taskVersion == null ||
      track is! String ||
      track.trim().isEmpty) {
    return null;
  }
  return _taskQaKey(taskId: taskId, taskVersion: taskVersion, track: track);
}

String _taskQaKey({
  required String taskId,
  required Object taskVersion,
  required String track,
}) {
  return '$taskId@v$taskVersion/$track';
}

Map<String, Object?> _taskQaSummary(
  Map<String, Object?> summary,
  List<Map<String, Object?>> reports,
  List<Map<String, Object?>> leaderboardTasks,
  List<String> readErrors,
  Set<String> blockers, {
  required DateTime reportGeneratedAt,
}) {
  final rawReports = summary['reports'];
  final reportEntries = _objectMaps(rawReports);
  final taskCount = _intValue(summary['taskCount']);
  final admittedCount = _intValue(summary['admittedTaskCount']);
  final rejectedCount = _intValue(summary['rejectedTaskCount']);
  final leaderboardTaskKeys = <String>{};
  final invalidLeaderboardTaskRows = <Map<String, Object?>>[];
  final reportKeys = <String>{};
  final invalidReportRows = <Map<String, Object?>>[];
  final missingLeaderboardTaskQa = <Map<String, Object?>>[];
  final extraTaskQaReports = <Map<String, Object?>>[];
  final summaryIntegrity = _taskQaSummaryIntegrityAudit(
    summary: summary,
    rawReports: rawReports,
    reportEntries: reportEntries,
    taskCount: taskCount,
    admittedCount: admittedCount,
    rejectedCount: rejectedCount,
    reportGeneratedAt: reportGeneratedAt,
    blockers: blockers,
  );
  final reportPathAudit = _taskQaReportPathAudit(reportEntries, blockers);
  final summaryReportConsistency = _taskQaSummaryReportConsistencyAudit(
    summary['generatedAt'],
    reportEntries,
    reports,
    blockers,
  );

  for (final task in leaderboardTasks) {
    final key = _leaderboardTaskQaKey(task);
    if (key == null) {
      invalidLeaderboardTaskRows.add(_publicTaskRef(task));
    } else {
      leaderboardTaskKeys.add(key);
    }
  }
  for (final report in reports) {
    final key = _taskQaReportKey(report);
    if (key == null) {
      invalidReportRows.add(_taskRef(report));
    } else {
      reportKeys.add(key);
    }
  }
  for (final task in leaderboardTasks) {
    final key = _leaderboardTaskQaKey(task);
    if (key == null || reportKeys.contains(key)) continue;
    final ref = _publicTaskRef(task);
    missingLeaderboardTaskQa.add(ref);
    blockers.add(
      'Leaderboard task ${_publicTaskKey(task)} has no loaded task QA admission report.',
    );
  }
  for (final report in reports) {
    final key = _taskQaReportKey(report);
    if (key == null || leaderboardTaskKeys.contains(key)) continue;
    final ref = _taskRef(report);
    extraTaskQaReports.add(ref);
    blockers.add(
      'Task QA report ${_taskKey(report)} is not present in the leaderboard task set.',
    );
  }
  if (invalidLeaderboardTaskRows.isNotEmpty) {
    blockers.add(
      'Leaderboard task rows have incomplete task QA identity metadata.',
    );
  }
  if (invalidReportRows.isNotEmpty) {
    blockers.add('Task QA reports have incomplete task identity metadata.');
  }
  if (summary['status'] != 'completed') {
    blockers.add('Task QA summary status is not completed.');
  }
  if (rejectedCount > 0) {
    blockers.add('Task QA rejected $rejectedCount task(s).');
  }
  if (readErrors.isNotEmpty) {
    blockers.add('One or more task QA reports could not be loaded.');
  }
  if (reports.length < reportEntries.length) {
    blockers.add(
      'Only ${reports.length} of ${reportEntries.length} task QA report(s) were loaded.',
    );
  }

  return {
    'schemaVersion': summary['schemaVersion'],
    'status': summary['status'],
    'generatedAt': summary['generatedAt'],
    'taskCount': taskCount,
    'admittedTaskCount': admittedCount,
    'rejectedTaskCount': rejectedCount,
    'leaderboardTaskCount': leaderboardTasks.length,
    'loadedReportCount': reports.length,
    'coveredLeaderboardTaskCount': leaderboardTaskKeys
        .intersection(reportKeys)
        .length,
    'missingLeaderboardTaskQaCount': missingLeaderboardTaskQa.length,
    'extraTaskQaReportCount': extraTaskQaReports.length,
    'invalidLeaderboardTaskRowCount': invalidLeaderboardTaskRows.length,
    'invalidTaskQaReportRowCount': invalidReportRows.length,
    'leaderboardTasksMissingTaskQa': missingLeaderboardTaskQa,
    'taskQaReportsOutsideLeaderboard': extraTaskQaReports,
    'invalidLeaderboardTaskRows': invalidLeaderboardTaskRows,
    'invalidTaskQaReportRows': invalidReportRows,
    'reportReadErrors': readErrors,
    'summaryIntegrity': summaryIntegrity,
    'reportPathAudit': reportPathAudit,
    'summaryReportConsistency': summaryReportConsistency,
    'tasks': [
      for (final entry in reportEntries)
        {
          'taskId': entry['taskId'],
          'taskVersion': entry['taskVersion'],
          'track': entry['track'],
          'status': entry['status'],
          'failureCount': _intValue(entry['failureCount']),
          ..._f2pP2pForTaskQaReport(_taskQaReportForEntry(reports, entry)),
        },
    ],
  };
}

Map<String, Object?>? _taskQaReportForEntry(
  List<Map<String, Object?>> reports,
  Map<String, Object?> entry,
) {
  final key = _taskQaReportKey(entry);
  if (key == null) return null;
  for (final report in reports) {
    if (_taskQaReportKey(report) == key) return report;
  }
  return null;
}

Map<String, Object?> _f2pP2pForTaskQaReport(Map<String, Object?>? report) {
  final checks = _objectMap(report?['checks']);
  final f2p = checks['baselineHiddenFailed'];
  final publicPassed = checks['referencePublicPassed'];
  final hiddenPassed = checks['referenceHiddenPassed'];
  return {
    'f2p': f2p is bool ? f2p : null,
    'p2p': publicPassed is bool && hiddenPassed is bool
        ? publicPassed && hiddenPassed
        : null,
  };
}

Map<String, Object?> _taskQaSummaryIntegrityAudit({
  required Map<String, Object?> summary,
  required Object? rawReports,
  required List<Map<String, Object?>> reportEntries,
  required int taskCount,
  required int admittedCount,
  required int rejectedCount,
  required DateTime reportGeneratedAt,
  required Set<String> blockers,
}) {
  final schemaVersion = _intValue(summary['schemaVersion']);
  final schemaVersionStatus = schemaVersion <= 0
      ? 'missing'
      : schemaVersion == _taskQaSummarySchemaVersion
      ? 'supported'
      : 'unsupported';
  final generatedAt = _nonEmptyString(summary['generatedAt']);
  final parsedGeneratedAt = generatedAt == null
      ? null
      : DateTime.tryParse(generatedAt);
  final generatedAtStatus = generatedAt == null
      ? 'missing'
      : parsedGeneratedAt == null
      ? 'invalid'
      : parsedGeneratedAt.toUtc().isAfter(reportGeneratedAt.toUtc())
      ? 'future'
      : 'present';
  final reportListPresent = rawReports is List;
  final rawReportEntryCount = reportListPresent ? rawReports.length : 0;
  final invalidReportEntryCount = rawReportEntryCount - reportEntries.length;
  final taskCountPresent = summary['taskCount'] is num && taskCount > 0;
  final admittedCountPresent =
      summary['admittedTaskCount'] is num && admittedCount >= 0;
  final rejectedCountPresent =
      summary['rejectedTaskCount'] is num && rejectedCount >= 0;
  final reportCountMatchesTaskCount =
      reportListPresent && taskCount == reportEntries.length;
  final admissionCountsMatchTaskCount =
      taskCountPresent &&
      admittedCountPresent &&
      rejectedCountPresent &&
      admittedCount + rejectedCount == taskCount;
  final admittedReportCount = reportEntries
      .where((entry) => entry['status'] == 'admitted')
      .length;
  final rejectedReportCount = reportEntries
      .where((entry) => entry['status'] == 'rejected')
      .length;
  final unknownStatusReportCount =
      reportEntries.length - admittedReportCount - rejectedReportCount;
  final admissionCountsMatchReportStatuses =
      reportListPresent &&
      admittedCount == admittedReportCount &&
      rejectedCount == rejectedReportCount &&
      unknownStatusReportCount == 0;
  final valid =
      schemaVersionStatus == 'supported' &&
      generatedAtStatus == 'present' &&
      reportListPresent &&
      invalidReportEntryCount == 0 &&
      taskCountPresent &&
      admittedCountPresent &&
      rejectedCountPresent &&
      reportCountMatchesTaskCount &&
      admissionCountsMatchTaskCount &&
      admissionCountsMatchReportStatuses;

  if (schemaVersionStatus == 'missing') {
    blockers.add('Task QA summary schema version is missing.');
  } else if (schemaVersionStatus == 'unsupported') {
    blockers.add(
      'Task QA summary schema version $schemaVersion is unsupported.',
    );
  }
  if (generatedAtStatus != 'present') {
    blockers.add(
      'Task QA summary generatedAt timestamp is $generatedAtStatus.',
    );
  }
  if (!reportListPresent) {
    blockers.add('Task QA summary report list is missing.');
  }
  if (invalidReportEntryCount > 0) {
    blockers.add(
      'Task QA summary has $invalidReportEntryCount invalid report entr${invalidReportEntryCount == 1 ? 'y' : 'ies'}.',
    );
  }
  if (!taskCountPresent || !admittedCountPresent || !rejectedCountPresent) {
    blockers.add('Task QA summary count metadata is incomplete.');
  }
  if (!reportCountMatchesTaskCount) {
    blockers.add(
      'Task QA summary task count does not match its report entries.',
    );
  }
  if (!admissionCountsMatchTaskCount) {
    blockers.add(
      'Task QA summary admitted/rejected counts do not add up to task count.',
    );
  }
  if (!admissionCountsMatchReportStatuses) {
    blockers.add(
      'Task QA summary admitted/rejected counts do not match report statuses.',
    );
  }

  return {
    'status': valid ? 'valid' : 'invalid',
    'schemaVersion': schemaVersion,
    'schemaVersionStatus': schemaVersionStatus,
    'generatedAtStatus': generatedAtStatus,
    'reportListStatus': reportListPresent ? 'present' : 'missing',
    'rawReportEntryCount': rawReportEntryCount,
    'reportEntryCount': reportEntries.length,
    'invalidReportEntryCount': invalidReportEntryCount,
    'taskCount': taskCount,
    'admittedTaskCount': admittedCount,
    'rejectedTaskCount': rejectedCount,
    'taskCountPresent': taskCountPresent,
    'admittedCountPresent': admittedCountPresent,
    'rejectedCountPresent': rejectedCountPresent,
    'reportCountMatchesTaskCount': reportCountMatchesTaskCount,
    'admissionCountsMatchTaskCount': admissionCountsMatchTaskCount,
    'admittedReportStatusCount': admittedReportCount,
    'rejectedReportStatusCount': rejectedReportCount,
    'unknownReportStatusCount': unknownStatusReportCount,
    'admissionCountsMatchReportStatuses': admissionCountsMatchReportStatuses,
  };
}

Map<String, Object?> _taskQaSummaryReportConsistencyAudit(
  Object? summaryGeneratedAtValue,
  List<Map<String, Object?>> reportEntries,
  List<Map<String, Object?>> reports,
  Set<String> blockers,
) {
  final summaryGeneratedAt = _nonEmptyString(summaryGeneratedAtValue);
  final parsedSummaryGeneratedAt = summaryGeneratedAt == null
      ? null
      : DateTime.tryParse(summaryGeneratedAt);
  final summaryReportsByKey = <String, Map<String, Object?>>{};
  final loadedReportsByKey = <String, Map<String, Object?>>{};
  final duplicateSummaryReportKeys = <Map<String, Object?>>[];
  final duplicateLoadedReportKeys = <Map<String, Object?>>[];
  final tasksMissingLoadedReports = <Map<String, Object?>>[];
  final unreferencedLoadedReports = <Map<String, Object?>>[];
  final tasksWithInvalidFailureCounts = <Map<String, Object?>>[];
  final tasksWithStatusMismatches = <Map<String, Object?>>[];
  final tasksWithFailureCountMismatches = <Map<String, Object?>>[];
  final tasksWithReportGeneratedAfterSummary = <Map<String, Object?>>[];
  var matchedReportCount = 0;

  for (final entry in reportEntries) {
    final key = _taskQaReportKey(entry);
    if (key == null) continue;
    if (summaryReportsByKey.containsKey(key)) {
      duplicateSummaryReportKeys.add(_taskRef(entry));
    } else {
      summaryReportsByKey[key] = entry;
    }
  }
  for (final report in reports) {
    final key = _taskQaReportKey(report);
    if (key == null) continue;
    if (loadedReportsByKey.containsKey(key)) {
      duplicateLoadedReportKeys.add(_taskRef(report));
    } else {
      loadedReportsByKey[key] = report;
    }
  }

  for (final entry in reportEntries) {
    final key = _taskQaReportKey(entry);
    if (key == null) continue;
    final report = loadedReportsByKey[key];
    if (report == null) {
      tasksMissingLoadedReports.add(_taskRef(entry));
      blockers.add(
        'Task QA summary references ${_taskKey(entry)} without a matching loaded report.',
      );
      continue;
    }
    matchedReportCount++;

    final summaryStatus = entry['status'];
    final reportStatus = report['status'];
    if (summaryStatus != reportStatus) {
      tasksWithStatusMismatches.add({
        ..._taskRef(entry),
        'summaryStatus': summaryStatus?.toString(),
        'reportStatus': reportStatus?.toString(),
      });
      blockers.add(
        'Task QA summary status does not match loaded report for ${_taskKey(entry)}.',
      );
    }

    final reportGeneratedAt = _nonEmptyString(report['generatedAt']);
    final parsedReportGeneratedAt = reportGeneratedAt == null
        ? null
        : DateTime.tryParse(reportGeneratedAt);
    if (parsedSummaryGeneratedAt != null &&
        parsedReportGeneratedAt != null &&
        parsedReportGeneratedAt.toUtc().isAfter(
          parsedSummaryGeneratedAt.toUtc(),
        )) {
      tasksWithReportGeneratedAfterSummary.add({
        ..._taskRef(entry),
        'summaryGeneratedAt': summaryGeneratedAt,
        'reportGeneratedAt': reportGeneratedAt,
      });
      blockers.add(
        'Task QA report generatedAt is after summary generatedAt for ${_taskKey(entry)}.',
      );
    }

    final summaryFailureCount = entry['failureCount'];
    final loadedFailureCount = _stringList(report['failureMessages']).length;
    if (summaryFailureCount is! num ||
        summaryFailureCount < 0 ||
        summaryFailureCount.toInt() != summaryFailureCount) {
      tasksWithInvalidFailureCounts.add(_taskRef(entry));
      blockers.add(
        'Task QA summary failure count is invalid for ${_taskKey(entry)}.',
      );
    } else if (summaryFailureCount.toInt() != loadedFailureCount) {
      tasksWithFailureCountMismatches.add({
        ..._taskRef(entry),
        'summaryFailureCount': summaryFailureCount.toInt(),
        'reportFailureCount': loadedFailureCount,
      });
      blockers.add(
        'Task QA summary failure count does not match loaded report for ${_taskKey(entry)}.',
      );
    }
  }

  for (final report in reports) {
    final key = _taskQaReportKey(report);
    if (key == null || summaryReportsByKey.containsKey(key)) continue;
    unreferencedLoadedReports.add(_taskRef(report));
    blockers.add(
      'Loaded task QA report ${_taskKey(report)} is not referenced by the task QA summary.',
    );
  }

  if (duplicateSummaryReportKeys.isNotEmpty) {
    blockers.add('Task QA summary has duplicate task report entries.');
  }
  if (duplicateLoadedReportKeys.isNotEmpty) {
    blockers.add('Loaded task QA reports have duplicate task identities.');
  }

  return {
    'summaryReportCount': reportEntries.length,
    'loadedReportCount': reports.length,
    'matchedReportCount': matchedReportCount,
    'missingLoadedReportCount': tasksMissingLoadedReports.length,
    'unreferencedLoadedReportCount': unreferencedLoadedReports.length,
    'duplicateSummaryReportKeyCount': duplicateSummaryReportKeys.length,
    'duplicateLoadedReportKeyCount': duplicateLoadedReportKeys.length,
    'invalidFailureCountCount': tasksWithInvalidFailureCounts.length,
    'statusMismatchCount': tasksWithStatusMismatches.length,
    'failureCountMismatchCount': tasksWithFailureCountMismatches.length,
    'reportGeneratedAfterSummaryCount':
        tasksWithReportGeneratedAfterSummary.length,
    'tasksMissingLoadedReports': tasksMissingLoadedReports,
    'unreferencedLoadedReports': unreferencedLoadedReports,
    'duplicateSummaryReportKeys': duplicateSummaryReportKeys,
    'duplicateLoadedReportKeys': duplicateLoadedReportKeys,
    'tasksWithInvalidFailureCounts': tasksWithInvalidFailureCounts,
    'tasksWithStatusMismatches': tasksWithStatusMismatches,
    'tasksWithFailureCountMismatches': tasksWithFailureCountMismatches,
    'tasksWithReportGeneratedAfterSummary':
        tasksWithReportGeneratedAfterSummary,
  };
}

Map<String, Object?> _taskQaReportPathAudit(
  List<Map<String, Object?>> reportEntries,
  Set<String> blockers,
) {
  var missingReportPathCount = 0;
  var absoluteReportPathCount = 0;
  var parentReportPathCount = 0;
  var malformedReportPathCount = 0;
  var outsideTaskQaRootReportPathCount = 0;
  var unsafeReportPathCount = 0;
  final unsafeReportPaths = <Map<String, Object?>>[];

  for (final entry in reportEntries) {
    final rawPath = _nonEmptyString(entry['reportPath']);
    if (rawPath == null) {
      missingReportPathCount++;
      unsafeReportPathCount++;
      unsafeReportPaths.add({..._taskRef(entry), 'reason': 'missing'});
      continue;
    }

    final normalized = rawPath.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final isAbsolute =
        normalized.startsWith('/') ||
        _windowsAbsolutePathPattern.hasMatch(normalized);
    final hasParent = parts.any((part) => part == '..');
    final isMalformed =
        normalized.contains('\u0000') ||
        (!isAbsolute && parts.any((part) => part.isEmpty || part == '.'));
    final outsideTaskQaRoot = !isAbsolute && !normalized.startsWith('tasks/');
    final isUnsafe =
        isAbsolute || hasParent || isMalformed || outsideTaskQaRoot;

    if (isAbsolute) absoluteReportPathCount++;
    if (hasParent) parentReportPathCount++;
    if (isMalformed) malformedReportPathCount++;
    if (outsideTaskQaRoot) outsideTaskQaRootReportPathCount++;
    if (isUnsafe) {
      unsafeReportPathCount++;
      unsafeReportPaths.add({
        ..._taskRef(entry),
        'reason': _taskQaReportPathReason(
          isAbsolute: isAbsolute,
          hasParent: hasParent,
          isMalformed: isMalformed,
          outsideTaskQaRoot: outsideTaskQaRoot,
        ),
      });
    }
  }

  if (missingReportPathCount > 0) {
    blockers.add(
      'Task QA summary has $missingReportPathCount missing report path(s).',
    );
  }
  if (absoluteReportPathCount > 0) {
    blockers.add(
      'Task QA summary has $absoluteReportPathCount absolute report path(s).',
    );
  }
  if (parentReportPathCount > 0) {
    blockers.add(
      'Task QA summary has $parentReportPathCount parent-traversing report path(s).',
    );
  }
  if (malformedReportPathCount > 0) {
    blockers.add(
      'Task QA summary has $malformedReportPathCount malformed report path(s).',
    );
  }
  if (outsideTaskQaRootReportPathCount > 0) {
    blockers.add(
      'Task QA summary has $outsideTaskQaRootReportPathCount report path(s) outside tasks/.',
    );
  }

  return {
    'reportPathCount': reportEntries.length,
    'missingReportPathCount': missingReportPathCount,
    'absoluteReportPathCount': absoluteReportPathCount,
    'parentReportPathCount': parentReportPathCount,
    'malformedReportPathCount': malformedReportPathCount,
    'outsideTaskQaRootReportPathCount': outsideTaskQaRootReportPathCount,
    'unsafeReportPathCount': unsafeReportPathCount,
    'unsafeReportPaths': unsafeReportPaths,
  };
}

String _taskQaReportPathReason({
  required bool isAbsolute,
  required bool hasParent,
  required bool isMalformed,
  required bool outsideTaskQaRoot,
}) {
  if (isAbsolute) return 'absolute';
  if (hasParent) return 'parent_traversal';
  if (isMalformed) return 'malformed';
  if (outsideTaskQaRoot) return 'outside_tasks';
  return 'unsafe';
}

Map<String, Object?> _verifierAudit(
  List<Map<String, Object?>> reports,
  Set<String> blockers, {
  List<Map<String, Object?>> taskBundleDigestEvidence = const [],
  required int minHiddenFlakeRunsPerTask,
  required DateTime reportGeneratedAt,
}) {
  final taskBundleDigestEvidenceByKey = {
    for (final evidence in taskBundleDigestEvidence)
      if (_taskQaReportKey(evidence) case final key?)
        if (_nonEmptyString(evidence['taskBundleDigest']) case final digest?)
          key: digest,
  };
  final taskBundleDigestUnavailableReasonByKey = {
    for (final evidence in taskBundleDigestEvidence)
      if (_taskQaReportKey(evidence) case final key?)
        if (_nonEmptyString(evidence['taskBundleDigestUnavailableReason'])
            case final reason?)
          key: reason,
  };
  final checkCounts = SplayTreeMap<String, Map<String, int>>();
  final negativeCaseCounts = SplayTreeMap<String, Map<String, int>>();
  var hiddenVerifierDigestCount = 0;
  var hiddenFlakeRunTotal = 0;
  var totalNegativeCaseCount = 0;
  var rejectedNegativeCaseCount = 0;
  var acceptedNegativeCaseCount = 0;
  var invalidNegativeCaseCount = 0;
  var malformedNegativeCaseEvidenceCount = 0;
  var unsupportedNegativeCaseKindCount = 0;
  var negativeCaseOutcomeMismatchCount = 0;
  var falsePositiveCount = 0;
  var falseNegativeCount = 0;
  var disagreementCount = 0;
  var infrastructureErrorCount = 0;
  var qualityFlakeRunCount = 0;
  var qualityFlakeFailureCount = 0;
  var qualityAcceptedNegativeCaseCount = 0;
  var tasksMissingVerifierQualityAuditCount = 0;
  var invalidVerifierQualityFieldCount = 0;
  var verifierQualityMismatchCount = 0;
  var requiredAdmissionCheckCount = 0;
  var passedRequiredAdmissionCheckCount = 0;
  var missingRequiredAdmissionCheckCount = 0;
  var failedRequiredAdmissionCheckCount = 0;
  var invalidRequiredAdmissionCheckCount = 0;
  var failedOptionalAdmissionCheckCount = 0;
  var invalidOptionalAdmissionCheckCount = 0;
  var promptSafetyPresentCount = 0;
  var missingPromptSafetyCount = 0;
  var failedPromptSafetyCount = 0;
  var invalidPromptSafetyPassedFlagCount = 0;
  var missingPromptSafetyRequiredNegativeKindCount = 0;
  var promptSafeCheckMismatchCount = 0;
  var requiredKindCoverageMismatchCount = 0;
  var promptSafetyInvalidKindCount = 0;
  var promptSafetyPresentKindMismatchCount = 0;
  var promptSafetyMissingKindMismatchCount = 0;
  var promptSafetyInvalidComponentFieldCount = 0;
  var promptSafetyPassedComputationMismatchCount = 0;
  var privateOfficialTaskCount = 0;
  var activeTaskCount = 0;
  var supportedTaskReportSchemaVersionCount = 0;
  var missingTaskReportSchemaVersionCount = 0;
  var unsupportedTaskReportSchemaVersionCount = 0;
  var admittedTaskReportStatusCount = 0;
  var rejectedTaskReportStatusCount = 0;
  var unknownTaskReportStatusCount = 0;
  var taskReportGeneratedAtPresentCount = 0;
  var taskReportGeneratedAtMissingCount = 0;
  var taskReportGeneratedAtInvalidCount = 0;
  var taskReportGeneratedAtFutureCount = 0;
  var admissionProvenancePresentCount = 0;
  var missingAdmissionProvenanceCount = 0;
  var invalidAdmissionToolCount = 0;
  var invalidAdmissionEvaluatorCount = 0;
  var admissionEnvironmentPresentCount = 0;
  var admissionEnvironmentMissingCount = 0;
  var admissionEnvironmentSdkVersionPresentCount = 0;
  var admissionEnvironmentSdkVersionIncompleteCount = 0;
  var admissionEnvironmentDependencySnapshotPresentCount = 0;
  var admissionEnvironmentDependencySnapshotIncompleteCount = 0;
  var admissionEnvironmentGitDirtyCount = 0;
  var taskBundleDigestPresentCount = 0;
  var taskBundleDigestMissingCount = 0;
  var taskBundleDigestInvalidCount = 0;
  var taskBundleDigestMatchedCount = 0;
  var taskBundleDigestMismatchedCount = 0;
  var taskBundleDigestRecomputeMissingCount = 0;
  var taskExecutionPolicyPresentCount = 0;
  var taskExecutionPolicyMissingCount = 0;
  var taskExecutionPolicyIncompleteCount = 0;
  var taskExecutionPolicyNetworkDisabledCount = 0;
  var taskExecutionPolicyNetworkEnabledCount = 0;
  var taskResourceLimitPresentCount = 0;
  var taskResourceLimitIncompleteCount = 0;
  int? minHiddenFlakeRuns;
  int? maxHiddenFlakeRuns;
  final rejectedTasks = <Map<String, Object?>>[];
  final tasksMissingHiddenVerifierDigests = <Map<String, Object?>>[];
  final tasksWithInvalidHiddenVerifierDigests = <Map<String, Object?>>[];
  final tasksMissingNegativeCases = <Map<String, Object?>>[];
  final tasksWithNegativeCaseEvidenceIssues = <Map<String, Object?>>[];
  final tasksMissingVerifierQualityAudit = <Map<String, Object?>>[];
  final tasksWithVerifierQualityIssues = <Map<String, Object?>>[];
  final tasksWithAdmissionCheckIssues = <Map<String, Object?>>[];
  final tasksWithAdmissionFailureMessages = <Map<String, Object?>>[];
  final tasksWithTaskBundleDigestIssues = <Map<String, Object?>>[];
  final tasksWithDirtyAdmissionEnvironment = <Map<String, Object?>>[];
  final tasksMissingPromptSafety = <Map<String, Object?>>[];
  final tasksWithPromptSafetyIssues = <Map<String, Object?>>[];
  final tasksBelowHiddenFlakeRunMinimum = <Map<String, Object?>>[];
  final tasksMissingReleaseMetadata = <Map<String, Object?>>[];
  final tasksOutsidePrivateOfficialCorpus = <Map<String, Object?>>[];
  final retiredTasks = <Map<String, Object?>>[];
  final tasksWithSchemaVersionIssues = <Map<String, Object?>>[];
  final tasksWithStatusIssues = <Map<String, Object?>>[];
  final tasksWithInvalidGeneratedAt = <Map<String, Object?>>[];
  final tasksWithAdmissionProvenanceIssues = <Map<String, Object?>>[];
  final tasksWithExecutionPolicyIssues = <Map<String, Object?>>[];

  for (final report in reports) {
    final taskRef = _taskRef(report);
    final taskKey = _taskQaReportKey(report);
    final schemaVersion = _intValue(report['schemaVersion']);
    final schemaVersionStatus = schemaVersion <= 0
        ? 'missing'
        : schemaVersion == _taskQaReportSchemaVersion
        ? 'supported'
        : 'unsupported';
    if (schemaVersionStatus == 'supported') {
      supportedTaskReportSchemaVersionCount++;
    } else {
      if (schemaVersionStatus == 'missing') {
        missingTaskReportSchemaVersionCount++;
        blockers.add(
          'Task QA report ${_taskKey(report)} schema version is missing.',
        );
      } else {
        unsupportedTaskReportSchemaVersionCount++;
        blockers.add(
          'Task QA report ${_taskKey(report)} schema version $schemaVersion is unsupported.',
        );
      }
      tasksWithSchemaVersionIssues.add({
        ...taskRef,
        'status': schemaVersionStatus,
        if (schemaVersion > 0) 'schemaVersion': schemaVersion,
      });
    }
    final reportStatus = report['status'];
    final statusIssue = reportStatus == 'admitted'
        ? null
        : reportStatus == 'rejected'
        ? 'rejected'
        : 'unknown';
    if (statusIssue == null) {
      admittedTaskReportStatusCount++;
    } else {
      if (statusIssue == 'rejected') {
        rejectedTaskReportStatusCount++;
      } else {
        unknownTaskReportStatusCount++;
      }
      tasksWithStatusIssues.add({...taskRef, 'status': statusIssue});
      blockers.add(
        'Task QA report ${_taskKey(report)} status is not admitted.',
      );
    }
    final generatedAtStatus = _taskQaReportGeneratedAtStatus(
      report['generatedAt'],
      reportGeneratedAt,
    );
    if (generatedAtStatus == 'present') {
      taskReportGeneratedAtPresentCount++;
    } else {
      if (generatedAtStatus == 'missing') {
        taskReportGeneratedAtMissingCount++;
      } else if (generatedAtStatus == 'invalid') {
        taskReportGeneratedAtInvalidCount++;
      } else if (generatedAtStatus == 'future') {
        taskReportGeneratedAtFutureCount++;
      }
      tasksWithInvalidGeneratedAt.add({
        ...taskRef,
        'status': generatedAtStatus,
      });
      blockers.add(
        'Task QA report ${_taskKey(report)} generatedAt timestamp is $generatedAtStatus.',
      );
    }
    if (statusIssue != null) {
      rejectedTasks.add({...taskRef, 'status': report['status']});
    }
    final failureMessages = _stringList(report['failureMessages']);
    if (statusIssue == null && failureMessages.isNotEmpty) {
      tasksWithAdmissionFailureMessages.add({
        ...taskRef,
        'failureMessageCount': failureMessages.length,
      });
      blockers.add(
        'Task QA report ${_taskKey(report)} is admitted but has ${failureMessages.length} failure message(s).',
      );
    }
    final admission = _objectMap(report['admission']);
    if (admission.isEmpty) {
      missingAdmissionProvenanceCount++;
      tasksWithAdmissionProvenanceIssues.add({...taskRef, 'status': 'missing'});
      blockers.add(
        'Task QA report ${_taskKey(report)} has no admission provenance metadata.',
      );
    } else {
      admissionProvenancePresentCount++;
      final tool = _objectMap(admission['tool']);
      final toolName = _nonEmptyString(tool['name']);
      if (toolName != _taskQaAdmissionToolName) {
        invalidAdmissionToolCount++;
        tasksWithAdmissionProvenanceIssues.add({
          ...taskRef,
          'status': 'invalid_tool',
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} admission tool metadata is invalid.',
        );
      }
      final evaluator = _objectMap(admission['evaluator']);
      final evaluatorSchemaVersion = _intValue(evaluator['schemaVersion']);
      final evaluatorVersion = _nonEmptyString(evaluator['version']);
      if (evaluatorSchemaVersion !=
              _requiredTaskQaAdmissionEvaluatorSchemaVersion ||
          evaluatorVersion == null) {
        invalidAdmissionEvaluatorCount++;
        tasksWithAdmissionProvenanceIssues.add({
          ...taskRef,
          'status': 'invalid_evaluator',
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} admission evaluator metadata is invalid.',
        );
      }
      final environment = _objectMap(admission['environment']);
      if (environment.isEmpty) {
        admissionEnvironmentMissingCount++;
        tasksWithAdmissionProvenanceIssues.add({
          ...taskRef,
          'status': 'missing_environment',
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} admission environment metadata is missing.',
        );
      } else {
        admissionEnvironmentPresentCount++;
        if (environment['gitDirty'] != false) {
          admissionEnvironmentGitDirtyCount++;
          tasksWithDirtyAdmissionEnvironment.add(taskRef);
          blockers.add(
            'Task QA report ${_taskKey(report)} admission environment gitDirty must be false.',
          );
        }
        final sdkVersionStatus = _environmentSdkVersionStatus(environment);
        if (sdkVersionStatus == 'present') {
          admissionEnvironmentSdkVersionPresentCount++;
        } else {
          admissionEnvironmentSdkVersionIncompleteCount++;
          tasksWithAdmissionProvenanceIssues.add({
            ...taskRef,
            'status': 'incomplete_sdk_versions',
          });
          blockers.add(
            'Task QA report ${_taskKey(report)} admission environment SDK metadata is incomplete.',
          );
        }
        final dependencySnapshotStatus = _environmentDependencySnapshotStatus(
          environment,
        );
        if (dependencySnapshotStatus == 'present') {
          admissionEnvironmentDependencySnapshotPresentCount++;
        } else {
          admissionEnvironmentDependencySnapshotIncompleteCount++;
          tasksWithAdmissionProvenanceIssues.add({
            ...taskRef,
            'status': 'incomplete_dependency_snapshot',
          });
          blockers.add(
            'Task QA report ${_taskKey(report)} admission environment dependency snapshot metadata is incomplete.',
          );
        }
      }
      final taskBundleDigest = _nonEmptyString(admission['taskBundleDigest']);
      if (taskBundleDigest == null) {
        taskBundleDigestMissingCount++;
        tasksWithTaskBundleDigestIssues.add({...taskRef, 'status': 'missing'});
        blockers.add(
          'Task QA report ${_taskKey(report)} task bundle digest is missing.',
        );
      } else if (!_sha256DigestPattern.hasMatch(taskBundleDigest)) {
        taskBundleDigestInvalidCount++;
        tasksWithTaskBundleDigestIssues.add({...taskRef, 'status': 'invalid'});
        blockers.add(
          'Task QA report ${_taskKey(report)} task bundle digest is invalid.',
        );
      } else {
        taskBundleDigestPresentCount++;
        final recomputedDigest = taskKey == null
            ? null
            : taskBundleDigestEvidenceByKey[taskKey];
        if (recomputedDigest == null) {
          final unavailableReason = taskKey == null
              ? 'task report identity is invalid'
              : taskBundleDigestUnavailableReasonByKey[taskKey] ??
                    'no task bundle digest evidence was produced';
          taskBundleDigestRecomputeMissingCount++;
          tasksWithTaskBundleDigestIssues.add({
            ...taskRef,
            'status': 'unavailable',
            'reason': unavailableReason,
          });
          blockers.add(
            'Task QA report ${_taskKey(report)} digest evidence unavailable: $unavailableReason.',
          );
        } else if (recomputedDigest != taskBundleDigest) {
          taskBundleDigestMismatchedCount++;
          tasksWithTaskBundleDigestIssues.add({
            ...taskRef,
            'status': 'mismatched',
          });
          blockers.add(
            'Task QA report ${_taskKey(report)} task bundle digest does not match the disk bundle.',
          );
        } else {
          taskBundleDigestMatchedCount++;
        }
      }
    }
    final executionPolicy = _objectMap(report['executionPolicy']);
    if (executionPolicy.isEmpty) {
      taskExecutionPolicyMissingCount++;
      taskResourceLimitIncompleteCount++;
      tasksWithExecutionPolicyIssues.add({...taskRef, 'status': 'missing'});
      blockers.add(
        'Task QA report ${_taskKey(report)} has no task execution policy metadata.',
      );
    } else {
      final allowInternet = executionPolicy['allowInternet'];
      final resources = _objectMap(executionPolicy['resources']);
      if (allowInternet is bool && resources.isNotEmpty) {
        taskExecutionPolicyPresentCount++;
      } else {
        taskExecutionPolicyIncompleteCount++;
        tasksWithExecutionPolicyIssues.add({
          ...taskRef,
          'status': 'incomplete',
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} has incomplete task execution policy metadata.',
        );
      }

      if (allowInternet == false) {
        taskExecutionPolicyNetworkDisabledCount++;
      } else if (allowInternet == true) {
        taskExecutionPolicyNetworkEnabledCount++;
        tasksWithExecutionPolicyIssues.add({
          ...taskRef,
          'status': 'network_enabled',
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} allows generated-code networking.',
        );
      }

      if (_taskQaResourceLimitsComplete(resources)) {
        taskResourceLimitPresentCount++;
      } else {
        taskResourceLimitIncompleteCount++;
        tasksWithExecutionPolicyIssues.add({
          ...taskRef,
          'status': 'incomplete_resource_limits',
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} has incomplete task resource limit metadata.',
        );
      }

      final resourceEnforcementStatus = _taskResourceEnforcementStatus(
        executionPolicy,
      );
      if (resourceEnforcementStatus != 'present') {
        tasksWithExecutionPolicyIssues.add({
          ...taskRef,
          'status': resourceEnforcementStatus,
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} has incomplete or unenforced '
          'task resource limit provenance.',
        );
      }
    }
    final hiddenDigests = _objectMap(report['hiddenVerifierDigests']);
    if (hiddenDigests.isEmpty) {
      tasksMissingHiddenVerifierDigests.add(taskRef);
      blockers.add(
        'Task ${_taskKey(report)} has no hidden verifier digest metadata.',
      );
    }
    for (final digest in hiddenDigests.entries) {
      final verifierId = digest.key.trim();
      final value = _nonEmptyString(digest.value);
      if (verifierId.isEmpty ||
          value == null ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
        tasksWithInvalidHiddenVerifierDigests.add({
          ...taskRef,
          'verifierId': verifierId.isEmpty ? '[empty]' : verifierId,
          'status': value == null ? 'missing' : 'invalid',
        });
        blockers.add(
          'Task ${_taskKey(report)} has invalid hidden verifier digest metadata.',
        );
      } else {
        hiddenVerifierDigestCount++;
      }
    }
    final qualityAudit = _objectMap(report['verifierQualityAudit']);
    if (qualityAudit.isEmpty) {
      tasksMissingVerifierQualityAuditCount++;
      tasksMissingVerifierQualityAudit.add(taskRef);
      blockers.add(
        'Task ${_taskKey(report)} has no verifier-quality audit summary.',
      );
    } else {
      for (final field in _requiredTaskQaVerifierQualityFields) {
        final value = qualityAudit[field];
        if (value is! int || value < 0) {
          invalidVerifierQualityFieldCount++;
          tasksWithVerifierQualityIssues.add({
            ...taskRef,
            'field': field,
            'status': 'invalid',
          });
          blockers.add(
            'Task QA report ${_taskKey(report)} verifier-quality field $field is invalid.',
          );
        }
      }
      falsePositiveCount += _intValue(qualityAudit['falsePositiveCount']);
      falseNegativeCount += _intValue(qualityAudit['falseNegativeCount']);
      disagreementCount += _intValue(qualityAudit['disagreementCount']);
      infrastructureErrorCount += _intValue(
        qualityAudit['infrastructureErrorCount'],
      );
      qualityFlakeRunCount += _intValue(qualityAudit['flakeRunCount']);
      qualityFlakeFailureCount += _intValue(qualityAudit['flakeFailureCount']);
      qualityAcceptedNegativeCaseCount += _intValue(
        qualityAudit['acceptedNegativeCaseCount'],
      );
    }
    final checks = _objectMap(report['checks']);
    for (final checkId in _requiredTaskQaAdmissionChecks) {
      requiredAdmissionCheckCount++;
      final value = checks[checkId];
      if (value == true) {
        passedRequiredAdmissionCheckCount++;
      } else {
        final status = value == null
            ? 'missing'
            : value == false
            ? 'failed'
            : 'invalid';
        if (status == 'missing') {
          missingRequiredAdmissionCheckCount++;
        } else if (status == 'failed') {
          failedRequiredAdmissionCheckCount++;
        } else {
          invalidRequiredAdmissionCheckCount++;
        }
        tasksWithAdmissionCheckIssues.add({
          ...taskRef,
          'check': checkId,
          'status': status,
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} admission check $checkId is $status.',
        );
      }
    }
    for (final checkId in _optionalTaskQaAdmissionChecks) {
      if (!checks.containsKey(checkId)) continue;
      final value = checks[checkId];
      if (value == true) continue;
      final status = value == false ? 'failed' : 'invalid';
      if (status == 'failed') {
        failedOptionalAdmissionCheckCount++;
      } else {
        invalidOptionalAdmissionCheckCount++;
      }
      tasksWithAdmissionCheckIssues.add({
        ...taskRef,
        'check': checkId,
        'status': status,
      });
      blockers.add(
        'Task QA report ${_taskKey(report)} admission check $checkId is $status.',
      );
    }
    final negativeCases = [
      ..._objectMaps(report['negativeCases']),
      ..._objectMaps(report['negative_cases']),
    ];
    final loadedNegativeCaseKinds = {
      for (final negativeCase in negativeCases)
        if (_nonEmptyString(negativeCase['kind']) case final kind?) kind,
    };
    final promptSafety = _objectMap(report['promptSafety']);
    if (promptSafety.isEmpty) {
      missingPromptSafetyCount++;
      tasksMissingPromptSafety.add(taskRef);
      blockers.add(
        'Task QA report ${_taskKey(report)} has no prompt-safety evidence.',
      );
    } else {
      promptSafetyPresentCount++;
      final promptSafetyPassed = promptSafety['passed'];
      if (promptSafetyPassed is! bool) {
        invalidPromptSafetyPassedFlagCount++;
        tasksWithPromptSafetyIssues.add({
          ...taskRef,
          'status': 'invalid_passed_flag',
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} prompt-safety passed flag is invalid.',
        );
      } else {
        if (!promptSafetyPassed) {
          failedPromptSafetyCount++;
          tasksWithPromptSafetyIssues.add({...taskRef, 'status': 'failed'});
          blockers.add(
            'Task QA report ${_taskKey(report)} prompt-safety evidence did not pass.',
          );
        }
        if (checks['promptSafeContextLeakFree'] is bool &&
            checks['promptSafeContextLeakFree'] != promptSafetyPassed) {
          promptSafeCheckMismatchCount++;
          tasksWithPromptSafetyIssues.add({
            ...taskRef,
            'status': 'prompt_safe_check_mismatch',
            'check': 'promptSafeContextLeakFree',
          });
          blockers.add(
            'Task QA report ${_taskKey(report)} promptSafeContextLeakFree check does not match prompt-safety evidence.',
          );
        }
      }

      final missingKinds = _stringList(
        promptSafety['missing_negative_case_kinds'],
      ).where((kind) => kind.trim().isNotEmpty).toList()..sort();
      final requiredKindSet = _nonEmptyStringSet(
        promptSafety['required_negative_case_kinds'],
      );
      final presentKindSet = _nonEmptyStringSet(
        promptSafety['present_negative_case_kinds'],
      );
      final missingKindSet = _nonEmptyStringSet(
        promptSafety['missing_negative_case_kinds'],
      );
      final invalidKinds = {
        ..._unsupportedTaskQaNegativeCaseKinds(requiredKindSet),
        ..._unsupportedTaskQaNegativeCaseKinds(presentKindSet),
        ..._unsupportedTaskQaNegativeCaseKinds(missingKindSet),
      }.toList()..sort();
      if (invalidKinds.isNotEmpty) {
        promptSafetyInvalidKindCount += invalidKinds.length;
        tasksWithPromptSafetyIssues.add({
          ...taskRef,
          'status': 'invalid_negative_case_kinds',
          'kinds': invalidKinds,
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} prompt-safety negative-case kind metadata is invalid.',
        );
      }
      if (!_setEquals(presentKindSet, loadedNegativeCaseKinds)) {
        promptSafetyPresentKindMismatchCount++;
        tasksWithPromptSafetyIssues.add({
          ...taskRef,
          'status': 'present_negative_case_kind_mismatch',
          'expectedKinds': loadedNegativeCaseKinds.toList()..sort(),
          'actualKinds': presentKindSet.toList()..sort(),
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} prompt-safety present negative-case kinds do not match loaded evidence.',
        );
      }
      final expectedMissingKindSet = requiredKindSet.difference(presentKindSet);
      if (!_setEquals(missingKindSet, expectedMissingKindSet)) {
        promptSafetyMissingKindMismatchCount++;
        tasksWithPromptSafetyIssues.add({
          ...taskRef,
          'status': 'missing_negative_case_kind_mismatch',
          'expectedKinds': expectedMissingKindSet.toList()..sort(),
          'actualKinds': missingKindSet.toList()..sort(),
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} prompt-safety missing negative-case kinds do not match required/present evidence.',
        );
      }
      final invalidComponentFields = [
        for (final field in _requiredTaskQaPromptSafetyBooleanFields)
          if (promptSafety[field] is! bool) field,
      ];
      if (invalidComponentFields.isNotEmpty) {
        promptSafetyInvalidComponentFieldCount += invalidComponentFields.length;
        tasksWithPromptSafetyIssues.add({
          ...taskRef,
          'status': 'invalid_component_fields',
          'fields': invalidComponentFields,
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} prompt-safety component field metadata is invalid.',
        );
      } else if (promptSafetyPassed is bool) {
        final expectedPromptSafetyPassed =
            promptSafety['target_context_present'] == true &&
            (promptSafety['public_test_context_required'] != true ||
                promptSafety['public_test_context_present'] == true) &&
            promptSafety['implementation_bodies_omitted'] == true &&
            promptSafety['hidden_verifier_leak_free'] == true &&
            promptSafety['reference_leak_free'] == true &&
            missingKindSet.isEmpty;
        if (promptSafetyPassed != expectedPromptSafetyPassed) {
          promptSafetyPassedComputationMismatchCount++;
          tasksWithPromptSafetyIssues.add({
            ...taskRef,
            'status': 'passed_computation_mismatch',
            'expected': expectedPromptSafetyPassed,
            'actual': promptSafetyPassed,
          });
          blockers.add(
            'Task QA report ${_taskKey(report)} prompt-safety passed flag does not match component evidence.',
          );
        }
      }
      if (missingKinds.isNotEmpty) {
        missingPromptSafetyRequiredNegativeKindCount += missingKinds.length;
        tasksWithPromptSafetyIssues.add({
          ...taskRef,
          'status': 'missing_required_negative_case_kinds',
          'missingKinds': missingKinds,
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} prompt-safety evidence is missing required negative case kind(s): ${missingKinds.join(', ')}.',
        );
      }
      final requiredKindCoverageCheck =
          checks['requiredNegativeCaseKindsCovered'];
      final requiredKindsCovered = missingKinds.isEmpty;
      if (requiredKindCoverageCheck is bool &&
          requiredKindCoverageCheck != requiredKindsCovered) {
        requiredKindCoverageMismatchCount++;
        tasksWithPromptSafetyIssues.add({
          ...taskRef,
          'status': 'required_kind_coverage_mismatch',
          'check': 'requiredNegativeCaseKindsCovered',
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} requiredNegativeCaseKindsCovered check does not match prompt-safety evidence.',
        );
      }
    }
    final hiddenFlakeRuns = _intValue(checks['hiddenFlakeRuns']);
    if (hiddenFlakeRuns < minHiddenFlakeRunsPerTask) {
      tasksBelowHiddenFlakeRunMinimum.add({
        ...taskRef,
        'hiddenFlakeRuns': hiddenFlakeRuns,
        'minimum': minHiddenFlakeRunsPerTask,
      });
      blockers.add(
        'Task ${_taskKey(report)} has $hiddenFlakeRuns hidden verifier '
        'flake run(s), below the required $minHiddenFlakeRunsPerTask.',
      );
    }
    for (final entry in checks.entries) {
      final counts = checkCounts.putIfAbsent(entry.key, () {
        return {'passed': 0, 'failed': 0, 'other': 0};
      });
      if (entry.value == true) {
        counts['passed'] = counts['passed']! + 1;
      } else if (entry.value == false) {
        counts['failed'] = counts['failed']! + 1;
      } else if (entry.value is num && entry.key == 'hiddenFlakeRuns') {
        final runs = (entry.value! as num).toInt();
        hiddenFlakeRunTotal += runs;
        minHiddenFlakeRuns = minHiddenFlakeRuns == null
            ? runs
            : _min(minHiddenFlakeRuns, runs);
        maxHiddenFlakeRuns = maxHiddenFlakeRuns == null
            ? runs
            : _max(maxHiddenFlakeRuns, runs);
        counts['other'] = counts['other']! + 1;
      } else {
        counts['other'] = counts['other']! + 1;
      }
    }

    if (negativeCases.isEmpty) {
      tasksMissingNegativeCases.add(taskRef);
      blockers.add(
        'Task ${_taskKey(report)} has no loaded negative-case audit entries.',
      );
    }
    var expectedAcceptedNegativeCaseCount = 0;
    var expectedNegativeCaseDisagreementCount = 0;
    final releaseMetadata = _objectMap(report['release']);
    if (releaseMetadata.isEmpty) {
      tasksMissingReleaseMetadata.add(taskRef);
      blockers.add('Task ${_taskKey(report)} has no release corpus metadata.');
    } else {
      final corpus = releaseMetadata['corpus']?.toString();
      if (corpus == 'private_official') {
        privateOfficialTaskCount++;
      } else {
        tasksOutsidePrivateOfficialCorpus.add({
          ...taskRef,
          if (corpus != null) 'corpus': corpus,
        });
        blockers.add(
          'Task ${_taskKey(report)} is not in the private official corpus.',
        );
      }
      final status = releaseMetadata['status']?.toString();
      if (status == 'active') {
        activeTaskCount++;
      } else if (status == 'retired') {
        retiredTasks.add(taskRef);
        blockers.add(
          'Task ${_taskKey(report)} is retired and cannot be used for an official release.',
        );
      } else {
        blockers.add(
          'Task ${_taskKey(report)} has incomplete release status metadata.',
        );
      }
    }
    for (final negativeCase in negativeCases) {
      totalNegativeCaseCount++;
      final id = _nonEmptyString(negativeCase['id']);
      final kind = _nonEmptyString(negativeCase['kind']);
      if (id == null) {
        malformedNegativeCaseEvidenceCount++;
        tasksWithNegativeCaseEvidenceIssues.add({
          ...taskRef,
          'status': 'missing_id',
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} has malformed negative-case evidence.',
        );
      }
      if (kind == null || !_allowedTaskQaNegativeCaseKinds.contains(kind)) {
        unsupportedNegativeCaseKindCount++;
        tasksWithNegativeCaseEvidenceIssues.add({
          ...taskRef,
          'status': 'unsupported_kind',
          if (id != null) 'negativeCaseId': id,
          if (kind != null) 'kind': kind,
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} has unsupported negative-case kind metadata.',
        );
      }
      final counts = negativeCaseCounts.putIfAbsent(
        kind == null || kind.trim().isEmpty ? 'unknown' : kind,
        () => {
          'total': 0,
          'rejected': 0,
          'accepted': 0,
          'invalid': 0,
          'publicRejected': 0,
          'hiddenRejected': 0,
        },
      );
      counts['total'] = counts['total']! + 1;
      final rejectedValue = negativeCase['rejected'];
      final rejected = rejectedValue == true;
      final preparePassed = _boolField(
        negativeCase,
        camelKey: 'preparePassed',
        snakeKey: 'prepare_passed',
      );
      final publicPassed = _boolField(
        negativeCase,
        camelKey: 'publicPassed',
        snakeKey: 'public_passed',
      );
      final hiddenPassed = _boolField(
        negativeCase,
        camelKey: 'hiddenPassed',
        snakeKey: 'hidden_passed',
      );
      if (rejectedValue is! bool ||
          preparePassed == null ||
          publicPassed == null ||
          hiddenPassed == null) {
        malformedNegativeCaseEvidenceCount++;
        tasksWithNegativeCaseEvidenceIssues.add({
          ...taskRef,
          'status': 'missing_outcome_field',
          if (id != null) 'negativeCaseId': id,
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} has malformed negative-case evidence.',
        );
      } else {
        final expectedRejected =
            preparePassed && (!publicPassed || !hiddenPassed);
        if (rejected != expectedRejected) {
          negativeCaseOutcomeMismatchCount++;
          tasksWithNegativeCaseEvidenceIssues.add({
            ...taskRef,
            'status': 'outcome_mismatch',
            if (id != null) 'negativeCaseId': id,
            'expectedRejected': expectedRejected,
            'actualRejected': rejected,
          });
          blockers.add(
            'Task QA report ${_taskKey(report)} negative-case rejection does not match loaded outcomes.',
          );
        }
      }
      if (preparePassed == true) {
        if (!rejected) expectedAcceptedNegativeCaseCount++;
        if (publicPassed != null &&
            hiddenPassed != null &&
            publicPassed != hiddenPassed) {
          expectedNegativeCaseDisagreementCount++;
        }
      }

      if (preparePassed == false) {
        invalidNegativeCaseCount++;
        counts['invalid'] = counts['invalid']! + 1;
      } else if (rejected) {
        rejectedNegativeCaseCount++;
        counts['rejected'] = counts['rejected']! + 1;
        if (publicPassed == false) {
          counts['publicRejected'] = counts['publicRejected']! + 1;
        } else if (hiddenPassed == false) {
          counts['hiddenRejected'] = counts['hiddenRejected']! + 1;
        }
      } else {
        acceptedNegativeCaseCount++;
        counts['accepted'] = counts['accepted']! + 1;
      }
    }
    if (qualityAudit.isNotEmpty) {
      void addQualityMismatch(String field, int expected, int actual) {
        verifierQualityMismatchCount++;
        tasksWithVerifierQualityIssues.add({
          ...taskRef,
          'field': field,
          'status': 'mismatch',
          'expected': expected,
          'actual': actual,
        });
        blockers.add(
          'Task QA report ${_taskKey(report)} verifier-quality field $field does not match loaded evidence.',
        );
      }

      void checkQualityField(String field, int expected) {
        final actual = _nonNegativeIntValue(qualityAudit[field]);
        if (actual != null && actual != expected) {
          addQualityMismatch(field, expected, actual);
        }
      }

      final referencePublicPassed = checks['referencePublicPassed'];
      final referenceHiddenPassed = checks['referenceHiddenPassed'];
      final expectedReferencePublicFailureCount = referencePublicPassed is bool
          ? (referencePublicPassed ? 0 : 1)
          : null;
      final expectedReferenceHiddenFailureCount = referenceHiddenPassed is bool
          ? (referenceHiddenPassed ? 0 : 1)
          : null;
      final expectedReferenceDisagreementCount =
          referencePublicPassed is bool &&
              referenceHiddenPassed is bool &&
              referencePublicPassed != referenceHiddenPassed
          ? 1
          : 0;

      checkQualityField('negativeCaseCount', negativeCases.length);
      checkQualityField(
        'acceptedNegativeCaseCount',
        expectedAcceptedNegativeCaseCount,
      );
      checkQualityField(
        'falsePositiveCount',
        expectedAcceptedNegativeCaseCount,
      );
      checkQualityField('flakeRunCount', hiddenFlakeRuns);
      if (expectedReferencePublicFailureCount != null) {
        checkQualityField(
          'referencePublicFailureCount',
          expectedReferencePublicFailureCount,
        );
      }
      if (expectedReferenceHiddenFailureCount != null) {
        checkQualityField(
          'referenceHiddenFailureCount',
          expectedReferenceHiddenFailureCount,
        );
        checkQualityField(
          'flakeFailureCount',
          expectedReferenceHiddenFailureCount,
        );
      }
      if (expectedReferencePublicFailureCount != null &&
          expectedReferenceHiddenFailureCount != null) {
        checkQualityField(
          'falseNegativeCount',
          expectedReferencePublicFailureCount +
              expectedReferenceHiddenFailureCount,
        );
        checkQualityField(
          'disagreementCount',
          expectedReferenceDisagreementCount +
              expectedNegativeCaseDisagreementCount,
        );
      }
    }
  }
  if (falsePositiveCount > 0) {
    blockers.add(
      'Verifier audit found $falsePositiveCount false-positive acceptance(s).',
    );
  }
  if (falseNegativeCount > 0) {
    blockers.add(
      'Verifier audit found $falseNegativeCount false-negative rejection(s).',
    );
  }
  if (infrastructureErrorCount > 0) {
    blockers.add(
      'Verifier audit found $infrastructureErrorCount infrastructure error(s).',
    );
  }
  if (qualityFlakeFailureCount > 0) {
    blockers.add(
      'Verifier audit found $qualityFlakeFailureCount hidden verifier flake failure(s).',
    );
  }

  return {
    'taskCount': reports.length,
    'hiddenVerifierDigestCount': hiddenVerifierDigestCount,
    'hiddenFlakeRuns': {
      'minimumPerTask': minHiddenFlakeRunsPerTask,
      'min': minHiddenFlakeRuns,
      'max': maxHiddenFlakeRuns,
      'total': hiddenFlakeRunTotal,
      'tasksBelowMinimum': tasksBelowHiddenFlakeRunMinimum,
    },
    'checkCounts': checkCounts,
    'negativeCases': {
      'total': totalNegativeCaseCount,
      'rejected': rejectedNegativeCaseCount,
      'accepted': acceptedNegativeCaseCount,
      'invalid': invalidNegativeCaseCount,
      'malformedEvidenceCount': malformedNegativeCaseEvidenceCount,
      'unsupportedKindCount': unsupportedNegativeCaseKindCount,
      'outcomeMismatchCount': negativeCaseOutcomeMismatchCount,
      'byKind': negativeCaseCounts,
      'tasksMissingNegativeCases': tasksMissingNegativeCases,
      'tasksWithNegativeCaseEvidenceIssues':
          tasksWithNegativeCaseEvidenceIssues,
    },
    'releaseMetadata': {
      'privateOfficialTaskCount': privateOfficialTaskCount,
      'activeTaskCount': activeTaskCount,
      'tasksMissingReleaseMetadata': tasksMissingReleaseMetadata,
      'tasksOutsidePrivateOfficialCorpus': tasksOutsidePrivateOfficialCorpus,
      'retiredTasks': retiredTasks,
    },
    'quality': {
      'falsePositiveCount': falsePositiveCount,
      'falseNegativeCount': falseNegativeCount,
      'disagreementCount': disagreementCount,
      'infrastructureErrorCount': infrastructureErrorCount,
      'flakeRunCount': qualityFlakeRunCount,
      'flakeFailureCount': qualityFlakeFailureCount,
      'flakeRate': qualityFlakeRunCount == 0
          ? null
          : qualityFlakeFailureCount / qualityFlakeRunCount,
      'acceptedNegativeCaseCount': qualityAcceptedNegativeCaseCount,
      'tasksMissingVerifierQualityAuditCount':
          tasksMissingVerifierQualityAuditCount,
      'tasksMissingVerifierQualityAudit': tasksMissingVerifierQualityAudit,
    },
    'qualityConsistency': {
      'requiredFieldIds': _requiredTaskQaVerifierQualityFields,
      'invalidFieldCount': invalidVerifierQualityFieldCount,
      'mismatchCount': verifierQualityMismatchCount,
      'tasksWithVerifierQualityIssues': tasksWithVerifierQualityIssues,
    },
    'admissionChecks': {
      'requiredCheckIds': _requiredTaskQaAdmissionChecks,
      'optionalCheckIds': _optionalTaskQaAdmissionChecks,
      'requiredCheckCount': requiredAdmissionCheckCount,
      'passedRequiredCheckCount': passedRequiredAdmissionCheckCount,
      'missingRequiredCheckCount': missingRequiredAdmissionCheckCount,
      'failedRequiredCheckCount': failedRequiredAdmissionCheckCount,
      'invalidRequiredCheckCount': invalidRequiredAdmissionCheckCount,
      'failedOptionalCheckCount': failedOptionalAdmissionCheckCount,
      'invalidOptionalCheckCount': invalidOptionalAdmissionCheckCount,
      'admittedReportWithFailureMessagesCount':
          tasksWithAdmissionFailureMessages.length,
      'tasksWithAdmissionCheckIssues': tasksWithAdmissionCheckIssues,
      'tasksWithAdmissionFailureMessages': tasksWithAdmissionFailureMessages,
    },
    'promptSafety': {
      'presentCount': promptSafetyPresentCount,
      'missingCount': missingPromptSafetyCount,
      'failedCount': failedPromptSafetyCount,
      'invalidPassedFlagCount': invalidPromptSafetyPassedFlagCount,
      'missingRequiredNegativeKindCount':
          missingPromptSafetyRequiredNegativeKindCount,
      'promptSafeCheckMismatchCount': promptSafeCheckMismatchCount,
      'requiredKindCoverageMismatchCount': requiredKindCoverageMismatchCount,
      'invalidKindCount': promptSafetyInvalidKindCount,
      'presentKindMismatchCount': promptSafetyPresentKindMismatchCount,
      'missingKindMismatchCount': promptSafetyMissingKindMismatchCount,
      'invalidComponentFieldCount': promptSafetyInvalidComponentFieldCount,
      'passedComputationMismatchCount':
          promptSafetyPassedComputationMismatchCount,
      'tasksMissingPromptSafety': tasksMissingPromptSafety,
      'tasksWithPromptSafetyIssues': tasksWithPromptSafetyIssues,
    },
    'admissionProvenance': {
      'presentCount': admissionProvenancePresentCount,
      'missingCount': missingAdmissionProvenanceCount,
      'invalidToolCount': invalidAdmissionToolCount,
      'invalidEvaluatorCount': invalidAdmissionEvaluatorCount,
      'environmentPresentCount': admissionEnvironmentPresentCount,
      'environmentMissingCount': admissionEnvironmentMissingCount,
      'sdkVersionPresentCount': admissionEnvironmentSdkVersionPresentCount,
      'sdkVersionIncompleteCount':
          admissionEnvironmentSdkVersionIncompleteCount,
      'dependencySnapshotPresentCount':
          admissionEnvironmentDependencySnapshotPresentCount,
      'dependencySnapshotIncompleteCount':
          admissionEnvironmentDependencySnapshotIncompleteCount,
      'tasksWithAdmissionProvenanceIssues': tasksWithAdmissionProvenanceIssues,
    },
    'taskBundleIntegrity': {
      'digestPresentCount': taskBundleDigestPresentCount,
      'digestMissingCount': taskBundleDigestMissingCount,
      'digestInvalidCount': taskBundleDigestInvalidCount,
      'digestMatchedCount': taskBundleDigestMatchedCount,
      'digestMismatchedCount': taskBundleDigestMismatchedCount,
      'digestRecomputeMissingCount': taskBundleDigestRecomputeMissingCount,
      'admissionEnvironmentGitDirtyCount': admissionEnvironmentGitDirtyCount,
      'tasksWithTaskBundleDigestIssues': tasksWithTaskBundleDigestIssues,
      'tasksWithDirtyAdmissionEnvironment': tasksWithDirtyAdmissionEnvironment,
    },
    'taskExecutionPolicy': {
      'presentCount': taskExecutionPolicyPresentCount,
      'missingCount': taskExecutionPolicyMissingCount,
      'incompleteCount': taskExecutionPolicyIncompleteCount,
      'networkDisabledCount': taskExecutionPolicyNetworkDisabledCount,
      'networkEnabledCount': taskExecutionPolicyNetworkEnabledCount,
      'resourceLimitPresentCount': taskResourceLimitPresentCount,
      'resourceLimitIncompleteCount': taskResourceLimitIncompleteCount,
      'tasksWithExecutionPolicyIssues': tasksWithExecutionPolicyIssues,
    },
    'taskReportIntegrity': {
      'totalCount': reports.length,
      'supportedSchemaVersionCount': supportedTaskReportSchemaVersionCount,
      'missingSchemaVersionCount': missingTaskReportSchemaVersionCount,
      'unsupportedSchemaVersionCount': unsupportedTaskReportSchemaVersionCount,
      'admittedStatusCount': admittedTaskReportStatusCount,
      'rejectedStatusCount': rejectedTaskReportStatusCount,
      'unknownStatusCount': unknownTaskReportStatusCount,
      'tasksWithSchemaVersionIssues': tasksWithSchemaVersionIssues,
      'tasksWithStatusIssues': tasksWithStatusIssues,
    },
    'taskReportTimestamps': {
      'totalCount': reports.length,
      'presentCount': taskReportGeneratedAtPresentCount,
      'missingCount': taskReportGeneratedAtMissingCount,
      'invalidCount': taskReportGeneratedAtInvalidCount,
      'futureCount': taskReportGeneratedAtFutureCount,
      'tasksWithInvalidGeneratedAt': tasksWithInvalidGeneratedAt,
    },
    'tasksMissingHiddenVerifierDigests': tasksMissingHiddenVerifierDigests,
    'invalidHiddenVerifierDigestCount':
        tasksWithInvalidHiddenVerifierDigests.length,
    'tasksWithInvalidHiddenVerifierDigests':
        tasksWithInvalidHiddenVerifierDigests,
    'rejectedTasks': rejectedTasks,
  };
}

String _taskQaReportGeneratedAtStatus(
  Object? value,
  DateTime reportGeneratedAt,
) {
  final generatedAt = _nonEmptyString(value);
  final parsedGeneratedAt = generatedAt == null
      ? null
      : DateTime.tryParse(generatedAt);
  return generatedAt == null
      ? 'missing'
      : parsedGeneratedAt == null
      ? 'invalid'
      : parsedGeneratedAt.toUtc().isAfter(reportGeneratedAt.toUtc())
      ? 'future'
      : 'present';
}

Map<String, Object?> _taskRef(Map<String, Object?> report) => {
  'taskId': report['taskId'],
  'taskVersion': report['taskVersion'],
};

String _taskKey(Map<String, Object?> report) =>
    '${report['taskId']}@v${report['taskVersion']}';

void _validateFrozenCorpusManifest({
  required Object? selectedTasks,
  required String? corpusManifestDigest,
  required List<Map<String, Object?>> taskRows,
  required Set<String> blockers,
}) {
  if (selectedTasks is! List || corpusManifestDigest == null) return;
  final entries = <CorpusManifestEntry>[];
  final selectedTaskKeys = <String>{};
  var valid = true;
  for (final selectedTask in selectedTasks) {
    final entry = _objectMap(selectedTask);
    final taskId = _nonEmptyString(entry['taskId']);
    final taskVersion = entry['taskVersion'];
    final taskBundleDigest = _nonEmptyString(entry['taskBundleDigest']);
    if (taskId == null ||
        taskVersion is! int ||
        taskBundleDigest == null ||
        !_sha256DigestPattern.hasMatch(taskBundleDigest)) {
      valid = false;
      continue;
    }
    final key = '$taskId@v$taskVersion';
    if (!selectedTaskKeys.add(key)) valid = false;
    entries.add(
      CorpusManifestEntry(
        taskId: taskId,
        taskVersion: taskVersion,
        taskBundleDigest: taskBundleDigest,
      ),
    );
  }
  final taskRowsByKey = <String, Map<String, Object?>>{};
  for (final taskRow in taskRows) {
    final taskId = _nonEmptyString(taskRow['taskId']);
    final taskVersion = taskRow['taskVersion'];
    if (taskId == null || taskVersion is! int) {
      valid = false;
      continue;
    }
    final key = '$taskId@v$taskVersion';
    if (taskRowsByKey.containsKey(key)) {
      valid = false;
      continue;
    }
    taskRowsByKey[key] = taskRow;
  }
  if (selectedTaskKeys.length != taskRowsByKey.length) valid = false;
  for (final entry in entries) {
    final row = taskRowsByKey['${entry.taskId}@v${entry.taskVersion}'];
    if (row == null || row['taskBundleDigest'] != entry.taskBundleDigest) {
      valid = false;
    }
  }
  if (!valid) {
    blockers.add(
      'Leaderboard frozen corpus manifest entries do not match leaderboard tasks.',
    );
  }
  if (entries.length != selectedTasks.length ||
      corpusManifestDigestSha256(entries) != corpusManifestDigest) {
    blockers.add(
      'Leaderboard frozen corpus manifest digest does not match its entries.',
    );
  }
}

Map<String, Object?> _publicTaskRef(Map<String, Object?> task) => {
  'taskId': task['taskId'],
  'taskVersion': task['taskVersion'],
  'track': task['benchmarkTrack'] ?? task['track'],
};

String _publicTaskKey(Map<String, Object?> task) {
  final track = task['benchmarkTrack'] ?? task['track'];
  return '${task['taskId']}@v${task['taskVersion']}/$track';
}

bool? _boolField(
  Map<String, Object?> value, {
  required String camelKey,
  required String snakeKey,
}) {
  final camel = value[camelKey];
  if (camel is bool) return camel;
  final snake = value[snakeKey];
  if (snake is bool) return snake;
  return null;
}

Map<String, Object?> _provenanceSummary({
  required List<String> runIds,
  required Map<String, Map<String, Object?>>? runProvenanceById,
  required List<Map<String, Object?>> taskBundleDigestEvidence,
  required Set<String> blockers,
}) {
  if (runIds.isNotEmpty && runProvenanceById == null) {
    blockers.add('Run provenance database was not provided.');
  }

  final runs = <Map<String, Object?>>[];
  var sandboxEnforcedRunCount = 0;
  var taskExecutionPolicyRunCount = 0;
  var networkDisabledTaskPolicyRunCount = 0;
  var taskResourceLimitRunCount = 0;
  var sdkVersionRunCount = 0;
  var dependencySnapshotRunCount = 0;
  var pricingRegistryRunCount = 0;
  final dartVersions = <String>{};
  final flutterVersions = <String>{};
  final environmentIds = <String>{};
  var resultProvenanceCount = 0;
  var cleanReplayResultCount = 0;
  final gradingModeCounts = SplayTreeMap<String, int>();
  var hiddenFixtureIsolationAssertedResultCount = 0;
  var hiddenFixtureIsolationLeakResultCount = 0;
  var hiddenVerifierDigestMatchedResultCount = 0;
  final currentHiddenVerifierDigestsByTaskKey = {
    for (final evidence in taskBundleDigestEvidence)
      if (_taskQaReportKey(evidence) case final key?)
        if (evidence.containsKey('hiddenVerifierDigests'))
          key: _objectMap(evidence['hiddenVerifierDigests']),
  };
  for (final runId in runIds) {
    final provenance = runProvenanceById?[runId];
    if (runProvenanceById != null && provenance == null) {
      blockers.add('Run $runId has no stored provenance.');
    }
    final sandboxStatus = provenance == null
        ? const <String, Object?>{'status': 'missing'}
        : _generatedCodeSandboxStatus(provenance);
    final taskExecutionPolicyStatus = provenance == null
        ? 'missing'
        : _taskExecutionPolicyStatus(provenance);
    final networkDisabledTaskPolicyStatus = provenance == null
        ? 'missing'
        : _networkDisabledTaskPolicyStatus(provenance);
    final taskResourceLimitStatus = provenance == null
        ? 'missing'
        : _taskResourceLimitStatus(provenance);
    final sdkVersionStatus = provenance == null
        ? 'missing'
        : _sdkVersionStatus(provenance);
    final dependencySnapshotStatus = provenance == null
        ? 'missing'
        : _dependencySnapshotStatus(provenance);
    final pricingRegistryStatus = provenance == null
        ? 'missing'
        : _pricingRegistryStatus(provenance);
    final resultProvenance = provenance == null
        ? const <Map<String, Object?>>[]
        : _objectMaps(provenance['resultProvenance']);
    final expectedResultCount = provenance == null
        ? 0
        : _objectMaps(provenance['combos']).length;
    if (provenance != null &&
        (provenance['resultProvenance'] is! List ||
            resultProvenance.length != expectedResultCount)) {
      blockers.add(
        'Run $runId is missing clean-replay result provenance for some results.',
      );
    }
    var runCleanReplayResultCount = 0;
    var runHiddenFixtureIsolationAssertedResultCount = 0;
    var runHiddenFixtureIsolationLeakResultCount = 0;
    for (final result in resultProvenance) {
      resultProvenanceCount++;
      final gradingMode = result['gradingMode'];
      final gradingModeKey = gradingMode is String && gradingMode.isNotEmpty
          ? gradingMode
          : 'missing';
      gradingModeCounts[gradingModeKey] =
          (gradingModeCounts[gradingModeKey] ?? 0) + 1;

      final benchmarkTrack = result['benchmarkTrack'];
      if (benchmarkTrack == 'codegen') {
        continue;
      }
      if (benchmarkTrack != 'agentic') {
        blockers.add(
          'Result provenance has a missing or unrecognized benchmark track.',
        );
        continue;
      }

      if (result['gradingMode'] == 'clean_replay') {
        cleanReplayResultCount++;
        runCleanReplayResultCount++;
      } else {
        blockers.add(
          'Result was graded in the agent workspace, not a clean replay baseline.',
        );
      }

      final hiddenFixtureIsolation = _objectMap(
        result['hiddenFixtureIsolation'],
      );
      final leakedPaths = _stringList(hiddenFixtureIsolation['leakedPaths']);
      if (hiddenFixtureIsolation['asserted'] == true) {
        hiddenFixtureIsolationAssertedResultCount++;
        runHiddenFixtureIsolationAssertedResultCount++;
      } else {
        blockers.add(
          'Result is missing hidden verifier fixture isolation provenance.',
        );
      }
      if (leakedPaths.isNotEmpty) {
        hiddenFixtureIsolationLeakResultCount++;
        runHiddenFixtureIsolationLeakResultCount++;
        blockers.add(
          'Hidden verifier fixtures were readable from the agent workspace.',
        );
      }

      final taskKey = _resultProvenanceTaskKey(result);
      final storedHiddenVerifierDigests = _objectMap(
        result['hiddenVerifierDigests'],
      );
      if (taskKey == null) {
        blockers.add(
          'Result is missing task identity for hidden verifier digest verification.',
        );
      } else if (!currentHiddenVerifierDigestsByTaskKey.containsKey(taskKey)) {
        blockers.add(
          'Could not recompute hidden verifier digests from the live task '
          'bundle for a graded result.',
        );
      } else if (_stringMapEquals(
        storedHiddenVerifierDigests,
        currentHiddenVerifierDigestsByTaskKey[taskKey],
      )) {
        hiddenVerifierDigestMatchedResultCount++;
      } else {
        blockers.add(
          'Hidden verifier digests drifted from the corpus since the run.',
        );
      }
    }
    if (provenance != null) {
      final environment = _objectMap(provenance['environment']);
      final dartVersion = environmentSdkVersion(environment['dartVersion']);
      final flutterVersion = environmentSdkVersion(
        environment['flutterVersion'],
      );
      final environmentId = environmentCompatibilityId(environment);
      if (dartVersion != null) dartVersions.add(dartVersion);
      if (flutterVersion != null) flutterVersions.add(flutterVersion);
      if (environmentId != null) environmentIds.add(environmentId);

      if (sandboxStatus['status'] == 'enforced') {
        sandboxEnforcedRunCount++;
      } else {
        blockers.add(
          'Run $runId does not record generated-code sandbox enforcement.',
        );
      }
      if (taskExecutionPolicyStatus == 'present') {
        taskExecutionPolicyRunCount++;
      } else {
        blockers.add(
          'Run $runId has incomplete task execution policy provenance.',
        );
      }
      if (networkDisabledTaskPolicyStatus == 'disabled') {
        networkDisabledTaskPolicyRunCount++;
      } else if (networkDisabledTaskPolicyStatus == 'enabled') {
        blockers.add(
          'Run $runId records network-enabled generated-code task policy.',
        );
      } else {
        blockers.add(
          'Run $runId has incomplete network-disabled task policy provenance.',
        );
      }
      if (taskResourceLimitStatus == 'present') {
        taskResourceLimitRunCount++;
      } else {
        blockers.add(
          'Run $runId has incomplete or unenforced task resource limit provenance.',
        );
      }
      if (sdkVersionStatus == 'present') {
        sdkVersionRunCount++;
      } else {
        blockers.add('Run $runId has incomplete SDK version provenance.');
      }
      if (dependencySnapshotStatus == 'present') {
        dependencySnapshotRunCount++;
      } else {
        blockers.add(
          'Run $runId has incomplete dependency lockfile provenance.',
        );
      }
      if (pricingRegistryStatus == 'present') {
        pricingRegistryRunCount++;
      } else {
        blockers.add('Run $runId has incomplete pricing registry provenance.');
      }
    }
    runs.add({
      'runId': runId,
      'status': provenance == null ? 'missing' : 'present',
      'generatedCodeSandbox': sandboxStatus,
      'taskExecutionPolicyStatus': taskExecutionPolicyStatus,
      'networkDisabledTaskPolicyStatus': networkDisabledTaskPolicyStatus,
      'taskResourceLimitStatus': taskResourceLimitStatus,
      'sdkVersionStatus': sdkVersionStatus,
      'dependencySnapshotStatus': dependencySnapshotStatus,
      'pricingRegistryStatus': pricingRegistryStatus,
      'resultProvenanceCount': resultProvenance.length,
      'gradingModeCounts': _gradingModeCounts(resultProvenance),
      'cleanReplayResultCount': runCleanReplayResultCount,
      'hiddenFixtureIsolationAssertedResultCount':
          runHiddenFixtureIsolationAssertedResultCount,
      'hiddenFixtureIsolationLeakResultCount':
          runHiddenFixtureIsolationLeakResultCount,
      if (provenance != null) 'provenance': _sanitize(provenance),
    });
  }

  return {
    'schemaVersion': 2,
    'requiredRunIds': runIds,
    'embeddedRunCount': runs.where((run) => run['status'] == 'present').length,
    'sandboxEnforcedRunCount': sandboxEnforcedRunCount,
    'taskExecutionPolicyRunCount': taskExecutionPolicyRunCount,
    'networkDisabledTaskPolicyRunCount': networkDisabledTaskPolicyRunCount,
    'taskResourceLimitRunCount': taskResourceLimitRunCount,
    'sdkVersionRunCount': sdkVersionRunCount,
    'dependencySnapshotRunCount': dependencySnapshotRunCount,
    'pricingRegistryRunCount': pricingRegistryRunCount,
    'dartVersions': dartVersions.toList()..sort(),
    'flutterVersions': flutterVersions.toList()..sort(),
    'environmentIds': environmentIds.toList()..sort(),
    'resultProvenanceCount': resultProvenanceCount,
    'cleanReplayResultCount': cleanReplayResultCount,
    'gradingModeCounts': gradingModeCounts,
    'hiddenFixtureIsolationAssertedResultCount':
        hiddenFixtureIsolationAssertedResultCount,
    'hiddenFixtureIsolationLeakResultCount':
        hiddenFixtureIsolationLeakResultCount,
    'hiddenVerifierDigestMatchedResultCount':
        hiddenVerifierDigestMatchedResultCount,
    'runs': runs,
  };
}

bool _stringMapEquals(
  Map<String, Object?> actual,
  Map<String, Object?>? expected,
) {
  if (expected == null || actual.length != expected.length) return false;
  for (final entry in expected.entries) {
    if (actual[entry.key] != entry.value) return false;
  }
  return true;
}

Map<String, int> _gradingModeCounts(
  Iterable<Map<String, Object?>> resultProvenance,
) {
  final counts = SplayTreeMap<String, int>();
  for (final result in resultProvenance) {
    final gradingMode = result['gradingMode'];
    final key = gradingMode is String && gradingMode.isNotEmpty
        ? gradingMode
        : 'missing';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

String? _resultProvenanceTaskKey(Map<String, Object?> result) {
  final benchmarkTrack = result['benchmarkTrack'];
  return _taskQaReportKey({
    ...result,
    if (benchmarkTrack is String) 'track': benchmarkTrack,
  });
}

Map<String, Object?> _generatedCodeSandboxStatus(
  Map<String, Object?> provenance,
) {
  final config = _objectMap(provenance['config']);
  final sandbox = _objectMap(config['generatedCodeSandbox']);
  if (sandbox.isEmpty) return const {'status': 'missing'};
  final required = sandbox['required'];
  final enforced = sandbox['enforced'];
  final backend = sandbox['backend'];
  if (enforced == true) {
    if (backend is! String || backend.trim().isEmpty) {
      return {
        'status': 'missing_backend',
        if (required is bool) 'required': required,
        'enforced': true,
      };
    }
    return {
      'status': 'enforced',
      if (required is bool) 'required': required,
      'enforced': true,
      'backend': backend,
    };
  }
  if (enforced == false) {
    return {
      'status': 'not_enforced',
      if (required is bool) 'required': required,
      'enforced': false,
    };
  }
  return {'status': 'unknown', if (required is bool) 'required': required};
}

String _taskExecutionPolicyStatus(Map<String, Object?> provenance) {
  final tasks = _objectMaps(provenance['tasks']);
  if (tasks.isEmpty) return 'missing';
  for (final task in tasks) {
    final policy = _objectMap(task['executionPolicy']);
    if (policy['allowInternet'] is! bool) return 'incomplete';
    final resources = _objectMap(policy['resources']);
    if (resources.isEmpty) return 'incomplete';
  }
  return 'present';
}

String _networkDisabledTaskPolicyStatus(Map<String, Object?> provenance) {
  final tasks = _objectMaps(provenance['tasks']);
  if (tasks.isEmpty) return 'missing';
  var sawEnabled = false;
  for (final task in tasks) {
    final policy = _objectMap(task['executionPolicy']);
    final allowInternet = policy['allowInternet'];
    if (allowInternet is! bool) return 'incomplete';
    if (allowInternet) sawEnabled = true;
  }
  return sawEnabled ? 'enabled' : 'disabled';
}

String _taskResourceLimitStatus(Map<String, Object?> provenance) {
  final tasks = _objectMaps(provenance['tasks']);
  if (tasks.isEmpty) return 'missing';
  for (final task in tasks) {
    final policy = _objectMap(task['executionPolicy']);
    final resources = _objectMap(policy['resources']);
    if (!_positiveNumber(resources['cpus']) ||
        !_positiveNumber(resources['memoryMb']) ||
        !_positiveNumber(resources['maxProcesses']) ||
        !_positiveNumber(resources['maxOutputBytes'])) {
      return 'incomplete';
    }
    final enforcementStatus = _taskResourceEnforcementStatus(policy);
    if (enforcementStatus != 'present') return enforcementStatus;
  }
  return 'present';
}

bool _positiveNumber(Object? value) => value is num && value > 0;

String _taskResourceEnforcementStatus(Map<String, Object?> policy) {
  final enforcement = _objectMap(policy['resourceEnforcement']);
  if (enforcement.isEmpty) return 'missing_enforcement';
  var sawNotEnforced = false;
  for (final key in const [
    'cpus',
    'memoryMb',
    'maxProcesses',
    'maxOutputBytes',
  ]) {
    final field = _objectMap(enforcement[key]);
    if (field.isEmpty) return 'incomplete_enforcement';
    final enforced = field['enforced'];
    if (enforced is! bool) return 'incomplete_enforcement';
    final mechanism = _nonEmptyString(field['mechanism']);
    if (mechanism == null) return 'incomplete_enforcement';
    final kernelEnforced = field['kernelEnforced'];
    if (kernelEnforced is! bool) return 'incomplete_enforcement';
    if (!enforced || (key != 'maxOutputBytes' && !kernelEnforced)) {
      sawNotEnforced = true;
    }
  }
  return sawNotEnforced ? 'not_enforced' : 'present';
}

bool _taskQaResourceLimitsComplete(Map<String, Object?> resources) {
  return _positiveNumber(resources['cpus']) &&
      _positiveNumber(resources['memoryMb']) &&
      _positiveNumber(resources['maxProcesses']) &&
      _positiveNumber(resources['maxOutputBytes']);
}

String _sdkVersionStatus(Map<String, Object?> provenance) {
  final environment = _objectMap(provenance['environment']);
  return _environmentSdkVersionStatus(environment);
}

String _environmentSdkVersionStatus(Map<String, Object?> environment) {
  final dartVersion = environment['dartVersion'];
  final flutterVersion = environment['flutterVersion'];
  if (dartVersion is! String ||
      dartVersion.trim().isEmpty ||
      dartVersion == 'unknown') {
    return 'incomplete';
  }
  if (flutterVersion is! String ||
      flutterVersion.trim().isEmpty ||
      flutterVersion == 'unknown') {
    return 'incomplete';
  }
  return 'present';
}

String _dependencySnapshotStatus(Map<String, Object?> provenance) {
  final environment = _objectMap(provenance['environment']);
  return _environmentDependencySnapshotStatus(environment);
}

String _environmentDependencySnapshotStatus(Map<String, Object?> environment) {
  final snapshot = _objectMap(environment['dependencySnapshot']);
  if (snapshot['status'] != 'present') return 'incomplete';
  final files = _objectMap(snapshot['files']);
  final lockfile = _objectMap(files['pubspec.lock']);
  final digest = lockfile['sha256'];
  if (digest is! String || digest.trim().isEmpty) return 'incomplete';
  return 'present';
}

String _pricingRegistryStatus(Map<String, Object?> provenance) {
  final config = _objectMap(provenance['config']);
  final registry = _objectMap(config['pricingRegistry']);
  final version = registry['version'];
  final currency = registry['currency'];
  if (version is! String || version.trim().isEmpty) return 'incomplete';
  if (currency is! String || currency.trim().isEmpty) return 'incomplete';
  final models = _objectMap(registry['models']);
  if (models.isEmpty) return 'incomplete';
  for (final entry in models.values) {
    final pricing = _objectMap(entry);
    if (pricing['inputCostPerMToken'] is! num) return 'incomplete';
    if (pricing['outputCostPerMToken'] is! num) return 'incomplete';
    final source = pricing['source'];
    final effectiveFrom = pricing['effectiveFrom'];
    if (source is! String || source.trim().isEmpty) return 'incomplete';
    if (effectiveFrom is! String || effectiveFrom.trim().isEmpty) {
      return 'incomplete';
    }
  }
  return 'present';
}

Object? _sanitize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in keys)
        key: _isSensitiveKey(key) ? '[redacted]' : _sanitize(value[key]),
    };
  }
  if (value is List) return value.map(_sanitize).toList();
  if (value is String && _looksLikeAbsolutePath(value)) {
    return '[redacted_path]';
  }
  return value;
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase();
  return normalized.contains('secret') ||
      normalized.contains('token') ||
      normalized.contains('apikey') ||
      normalized.contains('api_key') ||
      normalized.contains('authorization') ||
      normalized.contains('password');
}

bool _looksLikeAbsolutePath(String value) {
  if (value.startsWith('/')) return true;
  if (value.length >= 3 &&
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value.substring(0, 3))) {
    return true;
  }
  return false;
}

bool _containsPrivatePath(String value) {
  final trimmed = value.trim();
  if (_looksLikeAbsolutePath(trimmed)) return true;
  if (RegExp(
    r'(^|[\s"=:])/(home|Users|Volumes|run|mnt|var|tmp)/[^\s"]+',
  ).hasMatch(value)) {
    return true;
  }
  if (RegExp(r'(^|[\s"=:])[A-Za-z]:[\\/][^\s"]+').hasMatch(value)) {
    return true;
  }
  return false;
}

bool _isPublicSecretKey(String key) {
  final compact = _compactKey(key);
  return compact.contains('apikey') ||
      compact.contains('secret') ||
      compact == 'authorization' ||
      compact.endsWith('authorization') ||
      compact == 'password' ||
      compact.endsWith('password') ||
      compact == 'token' ||
      compact.endsWith('accesstoken') ||
      compact.endsWith('refreshtoken') ||
      compact.endsWith('authtoken');
}

bool _isPrivatePromptFieldKey(String key) {
  final compact = _compactKey(key);
  return const {
    'prompt',
    'prompts',
    'rawprompt',
    'judgeprompt',
    'systemprompt',
    'privateprompt',
    'privatecorpusprompt',
  }.contains(compact);
}

bool _isSensitiveModelOutputFieldKey(String key) {
  final compact = _compactKey(key);
  return const {
    'rawtext',
    'rawresponse',
    'modelresponse',
    'fullresponse',
    'extractedcode',
    'generatedcode',
  }.contains(compact);
}

bool _isHiddenVerifierContentKey(String key) {
  final compact = _compactKey(key);
  return const {
    'hiddenverifiers',
    'hiddenverifierfiles',
    'hiddenverifiercontent',
    'hiddenverifiersource',
  }.contains(compact);
}

bool _looksLikeSecretValue(String value) {
  return RegExp(
    r'(sk-(live|test|proj)-[A-Za-z0-9_-]{8,}|ghp_[A-Za-z0-9_]{10,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{12,}|Bearer\s+[A-Za-z0-9._-]{8,})',
  ).hasMatch(value);
}

bool _containsHiddenVerifierContentMarker(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('test/_hidden/') ||
      normalized.contains('test/hidden/') ||
      normalized.contains('hidden_tests/') ||
      normalized.contains('hidden verifier source') ||
      normalized.contains('do_not_leak_hidden');
}

String _compactKey(String key) =>
    key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _modelKey(Map<String, Object?> model) =>
    '${model['providerId']}:${model['modelId']}';

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

bool _jsonValueEquals(Object? left, Object? right) {
  if (left is Map && right is Map) {
    final leftMap = _objectMap(left);
    final rightMap = _objectMap(right);
    if (leftMap.length != rightMap.length) return false;
    for (final key in leftMap.keys) {
      if (!rightMap.containsKey(key)) return false;
      if (!_jsonValueEquals(leftMap[key], rightMap[key])) return false;
    }
    return true;
  }

  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_jsonValueEquals(left[i], right[i])) return false;
    }
    return true;
  }

  return left == right;
}

List<Map<String, Object?>> _objectMaps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String) item,
  ];
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

List<String> _nonEmptyStringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (_nonEmptyString(item) case final text?) text,
  ];
}

Set<String> _nonEmptyStringSet(Object? value) =>
    _nonEmptyStringList(value).toSet();

Iterable<String> _unsupportedTaskQaNegativeCaseKinds(Set<String> kinds) =>
    kinds.where((kind) => !_allowedTaskQaNegativeCaseKinds.contains(kind));

bool _setEquals(Set<String> left, Set<String> right) {
  if (left.length != right.length) return false;
  return left.containsAll(right);
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

int? _nonNegativeIntValue(Object? value) =>
    value is int && value >= 0 ? value : null;

num _numValue(Object? value) => value is num ? value : 0;

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _isSha256Digest(String? value) =>
    value != null && _sha256DigestPattern.hasMatch(value);

bool _isArtifactId(String? value) =>
    value != null && _artifactIdPattern.hasMatch(value);

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
