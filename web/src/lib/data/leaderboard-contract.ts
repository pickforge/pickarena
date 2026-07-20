export const supportedArtifactSchemaVersions = [1, 2] as const;
export const acceptedDataPolicies = [
  'aggregate-compatible',
  'latest-run',
  'best-observed'
] as const;

export type LeaderboardBenchmark = {
  title: string;
  version: string | null;
  taskSetId: string | null;
  evaluatorSchemaVersion: number;
  track: string;
  dataPolicy: LeaderboardDataPolicy;
  preset: string | null;
  selectedTasks: LeaderboardSelectedTask[];
  corpusManifestDigestSha256: string | null;
};

export type LeaderboardDataPolicy = (typeof acceptedDataPolicies)[number];

export type LeaderboardSelectedTask = {
  taskId: string;
  taskVersion: number | string | null;
  taskBundleDigest: string | null;
};

export type LeaderboardSource = {
  anchorRunId: string | null;
  runIds: string[];
  taskCount: number;
  taskRunCount: number;
  modelCount: number;
  trialSummaryCount: number;
  trialSummaryTotalCount: number;
  trialSummaryTruncated: boolean;
  trialSummaryLimit: number;
  warnings: string[];
  judgeOverhead: LeaderboardJudgeOverhead;
  runProvenance: LeaderboardRunProvenance;
};

export type LeaderboardJudgeOverhead = {
  evaluationCount: number;
  promptTokens: number;
  completionTokens: number;
  knownEstimatedCostCount: number;
  unknownEstimatedCostCount: number;
  totalEstimatedCostMicros: number;
  pricingStatusCounts: Record<string, number>;
};

export type LeaderboardRunProvenance = {
  runCount: number;
  embeddedRunCount: number;
  sandboxEnforcedRunCount: number;
  taskExecutionPolicyRunCount: number;
  networkDisabledTaskPolicyRunCount: number;
  taskResourceLimitRunCount: number;
  sdkVersionRunCount: number;
  dependencySnapshotRunCount: number;
  pricingRegistryRunCount: number;
  generatedCodeSandboxBackends: string[];
  dartVersions: string[];
  flutterVersions: string[];
  environmentIds: string[];
  warnings: string[];
};

export type LeaderboardPricingRegistry = {
  version: string | null;
  currency: string | null;
  modelCount: number;
};

export type LeaderboardScoring = {
  schemaVersion: number;
  primaryMetric: string | null;
  rankingMetric: string | null;
  confidenceInterval: string | null;
  llmJudgePolicy: string | null;
  objectiveEvaluatorIds: string[];
  secondaryEvaluatorIds: string[];
  hiddenVerifierPattern: string | null;
  failureTags: string[];
  objectiveFailureCaps: Record<string, number>;
  defaultEvaluatorWeights: Record<string, number>;
};

export type LeaderboardPassAtKEntry = {
  k: number;
  passCount: number;
  sampleCount: number;
  passRate: number | null;
};

export type LeaderboardPassAtK = Record<string, LeaderboardPassAtKEntry>;

export type LeaderboardConfidenceInterval = {
  lower: number | null;
  upper: number | null;
};

export type LeaderboardModel = {
  providerId: string;
  modelId: string;
  displayName: string | null;
  providerLabel: string | null;
  rank: number | null;
  score: number | null;
  passRate: number | null;
  trialCount: number;
  passCount: number;
  sampleCount: number;
  passAtK: LeaderboardPassAtK;
  medianStepCount: number | null;
  medianPeakContextTokens: number | null;
  publicPassCount: number;
  publicSampleCount: number;
  publicPassRate: number | null;
  hiddenPassCount: number;
  hiddenSampleCount: number;
  hiddenPassRate: number | null;
  confidenceInterval: LeaderboardConfidenceInterval;
  lowSample: boolean;
  medianLatencyMs: number | null;
  medianPromptTokens: number | null;
  medianCompletionTokens: number | null;
  medianEstimatedCostMicros: number | null;
  knownEstimatedCostCount: number;
  unknownEstimatedCostCount: number;
  totalEstimatedCostMicros: number | null;
  costPerSolvedTaskMicros: number | null;
  cheapestPassingEstimatedCostMicros: number | null;
  failureBreakdown: Record<string, number>;
  blockedEvaluationCount: number;
  blockedTaskRunCount: number;
};

export type LeaderboardTask = {
  taskId: string;
  taskVersion: number | string | null;
  taskBundleDigest: string | null;
  benchmarkTrack: string | null;
  trialCount: number;
  sampleCount: number;
  modelCount: number;
  passRate: number | null;
  confidenceInterval: LeaderboardConfidenceInterval;
  passAtK: LeaderboardPassAtK;
  medianStepCount: number | null;
  medianPeakContextTokens: number | null;
  publicPassCount: number;
  publicSampleCount: number;
  publicPassRate: number | null;
  hiddenPassCount: number;
  hiddenSampleCount: number;
  hiddenPassRate: number | null;
  blockedEvaluationCount: number;
  blockedTaskRunCount: number;
};

export type LeaderboardTaskModelCell = {
  providerId: string;
  modelId: string;
  displayName: string | null;
  providerLabel: string | null;
  taskId: string;
  taskVersion: number | string | null;
  benchmarkTrack: string | null;
  trialCount: number;
  passCount: number;
  sampleCount: number;
  passRate: number | null;
  confidenceInterval: LeaderboardConfidenceInterval;
  errorCount: number;
  passAtK: LeaderboardPassAtK;
  medianStepCount: number | null;
  medianPeakContextTokens: number | null;
  publicPassCount: number;
  publicSampleCount: number;
  publicPassRate: number | null;
  hiddenPassCount: number;
  hiddenSampleCount: number;
  hiddenPassRate: number | null;
  blockedEvaluationCount: number;
  blockedTaskRunCount: number;
  medianLatencyMs: number | null;
  medianPromptTokens: number | null;
  medianCompletionTokens: number | null;
  medianEstimatedCostMicros: number | null;
  knownEstimatedCostCount: number;
  unknownEstimatedCostCount: number;
  failureBreakdown: Record<string, number>;
};

export type LeaderboardTrialSummary = {
  trialId: string;
  runId: string;
  providerId: string;
  modelId: string;
  displayName: string | null;
  providerLabel: string | null;
  taskId: string;
  taskVersion: number | string | null;
  benchmarkTrack: string | null;
  trialIndex: number;
  completedAt: string | null;
  primaryPass: boolean | null;
  failureTag: string;
  aggregateScore: number | null;
  publicPassed: boolean | null;
  hiddenPassed: boolean | null;
  blockedEvaluationCount: number;
  stepCount: number | null;
  peakContextTokens: number | null;
  latencyMs: number | null;
  promptTokens: number | null;
  completionTokens: number | null;
  estimatedCostMicros: number | null;
};

export type LeaderboardData = {
  schemaVersion: number;
  provisional: boolean;
  generatedAt: string | null;
  benchmark: LeaderboardBenchmark;
  source: LeaderboardSource;
  scoring: LeaderboardScoring;
  pricingRegistry: LeaderboardPricingRegistry;
  models: LeaderboardModel[];
  tasks: LeaderboardTask[];
  taskModelCells: LeaderboardTaskModelCell[];
  trialSummaries: LeaderboardTrialSummary[];
};

export type LeaderboardArtifactParseResult =
  | { ok: true; value: LeaderboardData }
  | { ok: false; error: 'syntax' | 'shape' };

export const emptyLeaderboard: LeaderboardData = {
  schemaVersion: 1,
  provisional: false,
  generatedAt: null,
  benchmark: {
    title: 'PickArena by Pickforge Studio',
    version: null,
    taskSetId: null,
    evaluatorSchemaVersion: 0,
    track: 'agentic',
    dataPolicy: 'aggregate-compatible',
    preset: null,
    selectedTasks: [],
    corpusManifestDigestSha256: null
  },
  source: {
    anchorRunId: null,
    runIds: [],
    taskCount: 0,
    taskRunCount: 0,
    modelCount: 0,
    trialSummaryCount: 0,
    trialSummaryTotalCount: 0,
    trialSummaryTruncated: false,
    trialSummaryLimit: 0,
    warnings: [],
    judgeOverhead: emptyJudgeOverhead(),
    runProvenance: emptyRunProvenance()
  },
  scoring: emptyScoring(),
  pricingRegistry: { version: null, currency: null, modelCount: 0 },
  models: [],
  tasks: [],
  taskModelCells: [],
  trialSummaries: []
};

export function parseLeaderboardArtifactResult(
  text: string
): LeaderboardArtifactParseResult {
  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch {
    return { ok: false, error: 'syntax' };
  }
  const value = parseLeaderboardValue(decoded);
  return value === null
    ? { ok: false, error: 'shape' }
    : { ok: true, value };
}

export function parseLeaderboardArtifact(text: string): LeaderboardData | null {
  const result = parseLeaderboardArtifactResult(text);
  return result.ok ? result.value : null;
}

export function parseLeaderboardValue(value: unknown): LeaderboardData | null {
  try {
    return parseLeaderboardRecord(requiredRecord(value));
  } catch {
    return null;
  }
}

function parseLeaderboardRecord(value: Record<string, unknown>): LeaderboardData {
  const schemaVersion = requiredNonNegativeInteger(value, 'schemaVersion');
  if (!supportedArtifactSchemaVersions.includes(schemaVersion as 1 | 2)) {
    invalid();
  }
  const current = schemaVersion === 2;
  const benchmark = requiredRecord(value.benchmark);
  const source = requiredRecord(value.source);
  const modelValues = requiredArray(value, 'models');
  const taskValues = requiredArray(value, 'tasks');
  const modelRecords = records(modelValues);
  const taskRecords = records(taskValues);
  const cellRecords = records(arrayField(value, 'taskModelCells', current));
  const trialRecords = records(arrayField(value, 'trialSummaries', current));
  const scoring = recordField(value, 'scoring', current);
  const pricingRegistry = recordField(value, 'pricingRegistry', current);
  const judgeOverhead = recordField(source, 'judgeOverhead', current);
  const runProvenance = recordField(source, 'runProvenance', current);

  return {
    schemaVersion,
    provisional: booleanField(value, 'provisional', false),
    generatedAt: nullableStringField(value, 'generatedAt'),
    benchmark: {
      title: requiredString(benchmark, 'title'),
      version: nullableStringField(benchmark, 'version'),
      taskSetId: nullableStringField(benchmark, 'taskSetId'),
      evaluatorSchemaVersion: countField(
        benchmark,
        'evaluatorSchemaVersion',
        current,
        0
      ),
      track: requiredString(benchmark, 'track'),
      dataPolicy: dataPolicyField(benchmark, 'dataPolicy'),
      preset: nullableStringField(benchmark, 'preset'),
      selectedTasks: parseSelectedTasks(arrayField(benchmark, 'selectedTasks')),
      corpusManifestDigestSha256: nullableStringField(
        benchmark,
        'corpusManifestDigestSha256'
      )
    },
    source: {
      anchorRunId: nullableStringField(source, 'anchorRunId'),
      runIds: stringArrayField(source, 'runIds', current),
      taskCount: requiredNonNegativeInteger(source, 'taskCount'),
      taskRunCount: requiredNonNegativeInteger(source, 'taskRunCount'),
      modelCount: countField(source, 'modelCount', current, modelRecords.length),
      trialSummaryCount: countField(
        source,
        'trialSummaryCount',
        current,
        trialRecords.length
      ),
      trialSummaryTotalCount: countField(
        source,
        'trialSummaryTotalCount',
        current,
        requiredNonNegativeInteger(source, 'taskRunCount')
      ),
      trialSummaryTruncated: booleanField(
        source,
        'trialSummaryTruncated',
        false,
        current
      ),
      trialSummaryLimit: countField(source, 'trialSummaryLimit', current, 0),
      warnings: stringArrayField(source, 'warnings', current),
      judgeOverhead: parseJudgeOverhead(judgeOverhead, current),
      runProvenance: parseRunProvenance(runProvenance, current)
    },
    scoring: parseScoring(scoring, current),
    pricingRegistry: {
      version: nullableStringField(pricingRegistry, 'version'),
      currency: nullableStringField(pricingRegistry, 'currency'),
      modelCount: countField(pricingRegistry, 'modelCount', current, 0)
    },
    models: modelRecords.map((entry) => parseModelRow(entry, current)),
    tasks: taskRecords.map((entry) => parseTaskRow(entry, current)),
    taskModelCells: cellRecords.map((entry) =>
      parseTaskModelCell(entry, current)
    ),
    trialSummaries: trialRecords.map((entry) => parseTrialSummary(entry, current))
  };
}

function emptyScoring(): LeaderboardScoring {
  return {
    schemaVersion: 0,
    primaryMetric: null,
    rankingMetric: null,
    confidenceInterval: null,
    llmJudgePolicy: null,
    objectiveEvaluatorIds: [],
    secondaryEvaluatorIds: [],
    hiddenVerifierPattern: null,
    failureTags: [],
    objectiveFailureCaps: {},
    defaultEvaluatorWeights: {}
  };
}

function emptyJudgeOverhead(): LeaderboardJudgeOverhead {
  return {
    evaluationCount: 0,
    promptTokens: 0,
    completionTokens: 0,
    knownEstimatedCostCount: 0,
    unknownEstimatedCostCount: 0,
    totalEstimatedCostMicros: 0,
    pricingStatusCounts: {}
  };
}

function emptyRunProvenance(): LeaderboardRunProvenance {
  return {
    runCount: 0,
    embeddedRunCount: 0,
    sandboxEnforcedRunCount: 0,
    taskExecutionPolicyRunCount: 0,
    networkDisabledTaskPolicyRunCount: 0,
    taskResourceLimitRunCount: 0,
    sdkVersionRunCount: 0,
    dependencySnapshotRunCount: 0,
    pricingRegistryRunCount: 0,
    generatedCodeSandboxBackends: [],
    dartVersions: [],
    flutterVersions: [],
    environmentIds: [],
    warnings: []
  };
}

function parseScoring(
  value: Record<string, unknown>,
  current: boolean
): LeaderboardScoring {
  return {
    schemaVersion: countField(value, 'schemaVersion', current, 0),
    primaryMetric: nullableStringField(value, 'primaryMetric'),
    rankingMetric: nullableStringField(value, 'rankingMetric'),
    confidenceInterval: nullableStringField(value, 'confidenceInterval'),
    llmJudgePolicy: nullableStringField(value, 'llmJudgePolicy'),
    objectiveEvaluatorIds: stringArrayField(
      value,
      'objectiveEvaluatorIds',
      current
    ),
    secondaryEvaluatorIds: stringArrayField(
      value,
      'secondaryEvaluatorIds',
      current
    ),
    hiddenVerifierPattern: nullableStringField(value, 'hiddenVerifierPattern'),
    failureTags: stringArrayField(value, 'failureTags', current),
    objectiveFailureCaps: numberRecordField(
      value,
      'objectiveFailureCaps',
      current
    ),
    defaultEvaluatorWeights: numberRecordField(
      value,
      'defaultEvaluatorWeights',
      current
    )
  };
}

function parseJudgeOverhead(
  value: Record<string, unknown>,
  current: boolean
): LeaderboardJudgeOverhead {
  return {
    evaluationCount: countField(value, 'evaluationCount', current, 0),
    promptTokens: countField(value, 'promptTokens', current, 0),
    completionTokens: countField(value, 'completionTokens', current, 0),
    knownEstimatedCostCount: countField(
      value,
      'knownEstimatedCostCount',
      current,
      0
    ),
    unknownEstimatedCostCount: countField(
      value,
      'unknownEstimatedCostCount',
      current,
      0
    ),
    totalEstimatedCostMicros: countField(
      value,
      'totalEstimatedCostMicros',
      current,
      0
    ),
    pricingStatusCounts: countRecordField(
      value,
      'pricingStatusCounts',
      current
    )
  };
}

function parseRunProvenance(
  value: Record<string, unknown>,
  current: boolean
): LeaderboardRunProvenance {
  return {
    runCount: countField(value, 'runCount', current, 0),
    embeddedRunCount: countField(value, 'embeddedRunCount', current, 0),
    sandboxEnforcedRunCount: countField(
      value,
      'sandboxEnforcedRunCount',
      current,
      0
    ),
    taskExecutionPolicyRunCount: countField(
      value,
      'taskExecutionPolicyRunCount',
      current,
      0
    ),
    networkDisabledTaskPolicyRunCount: countField(
      value,
      'networkDisabledTaskPolicyRunCount',
      current,
      0
    ),
    taskResourceLimitRunCount: countField(
      value,
      'taskResourceLimitRunCount',
      current,
      0
    ),
    sdkVersionRunCount: countField(value, 'sdkVersionRunCount', current, 0),
    dependencySnapshotRunCount: countField(
      value,
      'dependencySnapshotRunCount',
      current,
      0
    ),
    pricingRegistryRunCount: countField(
      value,
      'pricingRegistryRunCount',
      current,
      0
    ),
    generatedCodeSandboxBackends: stringArrayField(
      value,
      'generatedCodeSandboxBackends',
      current
    ),
    dartVersions: stringArrayField(value, 'dartVersions', current),
    flutterVersions: stringArrayField(value, 'flutterVersions', current),
    environmentIds: stringArrayField(value, 'environmentIds', current),
    warnings: stringArrayField(value, 'warnings', current)
  };
}

function parseModelIdentity(
  value: Record<string, unknown>,
  current: boolean
): { displayName: string | null; providerLabel: string | null } {
  const config = recordField(value, 'modelConfig', current);
  return {
    displayName: nullableNonEmptyStringField(
      config,
      'customModelDisplayName'
    ),
    providerLabel: nullableNonEmptyStringField(config, 'customModelProvider')
  };
}

function parseModelRow(
  value: Record<string, unknown>,
  current: boolean
): LeaderboardModel {
  const sampleCount = countField(value, 'sampleCount', current, 0);
  return {
    providerId: requiredString(value, 'providerId'),
    modelId: requiredString(value, 'modelId'),
    ...parseModelIdentity(value, current),
    rank: nullableNonNegativeIntegerField(value, 'rank'),
    score: nullableFiniteNumberField(value, 'score'),
    passRate: nullableFiniteNumberField(value, 'passRate'),
    trialCount: countField(value, 'trialCount', current, sampleCount),
    passCount: countField(value, 'passCount', current, 0),
    sampleCount,
    passAtK: parsePassAtK(recordField(value, 'passAtK', current), current),
    medianStepCount: nullableNonNegativeIntegerField(value, 'medianStepCount'),
    medianPeakContextTokens: nullableNonNegativeIntegerField(
      value,
      'medianPeakContextTokens'
    ),
    publicPassCount: countField(value, 'publicPassCount', current, 0),
    publicSampleCount: countField(value, 'publicSampleCount', current, 0),
    publicPassRate: nullableFiniteNumberField(value, 'publicPassRate'),
    hiddenPassCount: countField(value, 'hiddenPassCount', current, 0),
    hiddenSampleCount: countField(value, 'hiddenSampleCount', current, 0),
    hiddenPassRate: nullableFiniteNumberField(value, 'hiddenPassRate'),
    confidenceInterval: parseConfidenceInterval(
      recordField(value, 'confidenceInterval', current)
    ),
    lowSample: booleanField(value, 'lowSample', false, current),
    medianLatencyMs: nullableNonNegativeIntegerField(value, 'medianLatencyMs'),
    medianPromptTokens: nullableNonNegativeIntegerField(
      value,
      'medianPromptTokens'
    ),
    medianCompletionTokens: nullableNonNegativeIntegerField(
      value,
      'medianCompletionTokens'
    ),
    medianEstimatedCostMicros: nullableNonNegativeIntegerField(
      value,
      'medianEstimatedCostMicros'
    ),
    knownEstimatedCostCount: countField(
      value,
      'knownEstimatedCostCount',
      current,
      0
    ),
    unknownEstimatedCostCount: countField(
      value,
      'unknownEstimatedCostCount',
      current,
      0
    ),
    totalEstimatedCostMicros: nullableNonNegativeIntegerField(
      value,
      'totalEstimatedCostMicros'
    ),
    costPerSolvedTaskMicros: nullableNonNegativeIntegerField(
      value,
      'costPerSolvedTaskMicros'
    ),
    cheapestPassingEstimatedCostMicros: nullableNonNegativeIntegerField(
      value,
      'cheapestPassingEstimatedCostMicros'
    ),
    failureBreakdown: countRecordField(value, 'failureBreakdown', current),
    blockedEvaluationCount: countField(
      value,
      'blockedEvaluationCount',
      current,
      0
    ),
    blockedTaskRunCount: countField(
      value,
      'blockedTaskRunCount',
      current,
      0
    )
  };
}

function parseTaskRow(
  value: Record<string, unknown>,
  current: boolean
): LeaderboardTask {
  const sampleCount = countField(value, 'sampleCount', current, 0);
  return {
    taskId: requiredString(value, 'taskId'),
    taskVersion: nullableVersionField(value, 'taskVersion'),
    taskBundleDigest: nullableStringField(value, 'taskBundleDigest'),
    benchmarkTrack: nullableStringField(value, 'benchmarkTrack'),
    trialCount: countField(value, 'trialCount', current, sampleCount),
    sampleCount,
    modelCount: countField(value, 'modelCount', current, 0),
    passRate: nullableFiniteNumberField(value, 'passRate'),
    confidenceInterval: parseConfidenceInterval(
      recordField(value, 'confidenceInterval', current)
    ),
    passAtK: parsePassAtK(recordField(value, 'passAtK', current), current),
    medianStepCount: nullableNonNegativeIntegerField(value, 'medianStepCount'),
    medianPeakContextTokens: nullableNonNegativeIntegerField(
      value,
      'medianPeakContextTokens'
    ),
    publicPassCount: countField(value, 'publicPassCount', current, 0),
    publicSampleCount: countField(value, 'publicSampleCount', current, 0),
    publicPassRate: nullableFiniteNumberField(value, 'publicPassRate'),
    hiddenPassCount: countField(value, 'hiddenPassCount', current, 0),
    hiddenSampleCount: countField(value, 'hiddenSampleCount', current, 0),
    hiddenPassRate: nullableFiniteNumberField(value, 'hiddenPassRate'),
    blockedEvaluationCount: countField(
      value,
      'blockedEvaluationCount',
      current,
      0
    ),
    blockedTaskRunCount: countField(
      value,
      'blockedTaskRunCount',
      current,
      0
    )
  };
}

function parseTaskModelCell(
  value: Record<string, unknown>,
  current: boolean
): LeaderboardTaskModelCell {
  const sampleCount = countField(value, 'sampleCount', current, 0);
  return {
    providerId: requiredString(value, 'providerId'),
    modelId: requiredString(value, 'modelId'),
    ...parseModelIdentity(value, current),
    taskId: requiredString(value, 'taskId'),
    taskVersion: nullableVersionField(value, 'taskVersion'),
    benchmarkTrack: nullableStringField(value, 'benchmarkTrack'),
    trialCount: countField(value, 'trialCount', current, sampleCount),
    passCount: countField(value, 'passCount', current, 0),
    sampleCount,
    passRate: nullableFiniteNumberField(value, 'passRate'),
    confidenceInterval: parseConfidenceInterval(
      recordField(value, 'confidenceInterval', current)
    ),
    errorCount: countField(value, 'errorCount', current, 0),
    passAtK: parsePassAtK(recordField(value, 'passAtK', current), current),
    medianStepCount: nullableNonNegativeIntegerField(value, 'medianStepCount'),
    medianPeakContextTokens: nullableNonNegativeIntegerField(
      value,
      'medianPeakContextTokens'
    ),
    publicPassCount: countField(value, 'publicPassCount', current, 0),
    publicSampleCount: countField(value, 'publicSampleCount', current, 0),
    publicPassRate: nullableFiniteNumberField(value, 'publicPassRate'),
    hiddenPassCount: countField(value, 'hiddenPassCount', current, 0),
    hiddenSampleCount: countField(value, 'hiddenSampleCount', current, 0),
    hiddenPassRate: nullableFiniteNumberField(value, 'hiddenPassRate'),
    blockedEvaluationCount: countField(
      value,
      'blockedEvaluationCount',
      current,
      0
    ),
    blockedTaskRunCount: countField(
      value,
      'blockedTaskRunCount',
      current,
      0
    ),
    medianLatencyMs: nullableNonNegativeIntegerField(value, 'medianLatencyMs'),
    medianPromptTokens: nullableNonNegativeIntegerField(
      value,
      'medianPromptTokens'
    ),
    medianCompletionTokens: nullableNonNegativeIntegerField(
      value,
      'medianCompletionTokens'
    ),
    medianEstimatedCostMicros: nullableNonNegativeIntegerField(
      value,
      'medianEstimatedCostMicros'
    ),
    knownEstimatedCostCount: countField(
      value,
      'knownEstimatedCostCount',
      current,
      0
    ),
    unknownEstimatedCostCount: countField(
      value,
      'unknownEstimatedCostCount',
      current,
      0
    ),
    failureBreakdown: countRecordField(value, 'failureBreakdown', current)
  };
}

function parseTrialSummary(
  value: Record<string, unknown>,
  current: boolean
): LeaderboardTrialSummary {
  return {
    trialId: requiredString(value, 'trialId'),
    runId: requiredString(value, 'runId'),
    providerId: requiredString(value, 'providerId'),
    modelId: requiredString(value, 'modelId'),
    ...parseModelIdentity(value, current),
    taskId: requiredString(value, 'taskId'),
    taskVersion: nullableVersionField(value, 'taskVersion'),
    benchmarkTrack: nullableStringField(value, 'benchmarkTrack'),
    trialIndex: requiredNonNegativeInteger(value, 'trialIndex'),
    completedAt: nullableStringField(value, 'completedAt'),
    primaryPass: nullableBooleanField(value, 'primaryPass'),
    failureTag: requiredString(value, 'failureTag'),
    aggregateScore: nullableFiniteNumberField(value, 'aggregateScore'),
    publicPassed: nullableBooleanField(value, 'publicPassed'),
    hiddenPassed: nullableBooleanField(value, 'hiddenPassed'),
    blockedEvaluationCount: countField(
      value,
      'blockedEvaluationCount',
      current,
      0
    ),
    stepCount: nullableNonNegativeIntegerField(value, 'stepCount'),
    peakContextTokens: nullableNonNegativeIntegerField(
      value,
      'peakContextTokens'
    ),
    latencyMs: nullableNonNegativeIntegerField(value, 'latencyMs'),
    promptTokens: nullableNonNegativeIntegerField(value, 'promptTokens'),
    completionTokens: nullableNonNegativeIntegerField(
      value,
      'completionTokens'
    ),
    estimatedCostMicros: nullableNonNegativeIntegerField(
      value,
      'estimatedCostMicros'
    )
  };
}

function parseConfidenceInterval(
  value: Record<string, unknown>
): LeaderboardConfidenceInterval {
  return {
    lower: nullableFiniteNumberField(value, 'lower'),
    upper: nullableFiniteNumberField(value, 'upper')
  };
}

function parsePassAtK(
  value: Record<string, unknown>,
  current: boolean
): LeaderboardPassAtK {
  const result: LeaderboardPassAtK = {};
  for (const [key, rawEntry] of Object.entries(value)) {
    const entry = requiredRecord(rawEntry);
    const parsedKey = Number.parseInt(key, 10);
    const fallback = Number.isInteger(parsedKey) && parsedKey >= 0 ? parsedKey : 0;
    result[key] = {
      k: countField(entry, 'k', current, fallback),
      passCount: countField(entry, 'passCount', current, 0),
      sampleCount: countField(entry, 'sampleCount', current, 0),
      passRate: nullableFiniteNumberField(entry, 'passRate')
    };
  }
  return result;
}

function parseSelectedTasks(value: unknown[]): LeaderboardSelectedTask[] {
  return records(value).map((entry) => ({
    taskId: requiredString(entry, 'taskId'),
    taskVersion: nullableVersionField(entry, 'taskVersion'),
    taskBundleDigest: nullableStringField(entry, 'taskBundleDigest')
  }));
}

function requiredRecord(value: unknown): Record<string, unknown> {
  if (!isRecord(value)) invalid();
  return value;
}

function recordField(
  value: Record<string, unknown>,
  key: string,
  required: boolean
): Record<string, unknown> {
  if (!has(value, key)) {
    if (required) invalid();
    return {};
  }
  return requiredRecord(value[key]);
}

function records(values: unknown[]): Record<string, unknown>[] {
  return values.map(requiredRecord);
}

function requiredArray(value: Record<string, unknown>, key: string): unknown[] {
  if (!Array.isArray(value[key])) invalid();
  return value[key];
}

function arrayField(
  value: Record<string, unknown>,
  key: string,
  required = false
): unknown[] {
  if (!has(value, key)) {
    if (required) invalid();
    return [];
  }
  return requiredArray(value, key);
}

function stringArrayField(
  value: Record<string, unknown>,
  key: string,
  required = false
): string[] {
  const entries = arrayField(value, key, required);
  if (!entries.every((entry) => typeof entry === 'string')) invalid();
  return entries as string[];
}

function requiredString(value: Record<string, unknown>, key: string): string {
  const entry = value[key];
  if (typeof entry !== 'string' || entry.trim().length === 0) invalid();
  return entry;
}

function nullableStringField(
  value: Record<string, unknown>,
  key: string
): string | null {
  if (!has(value, key) || value[key] === null) return null;
  if (typeof value[key] !== 'string') invalid();
  return value[key];
}

function nullableNonEmptyStringField(
  value: Record<string, unknown>,
  key: string
): string | null {
  const entry = nullableStringField(value, key);
  if (entry !== null && entry.trim().length === 0) invalid();
  return entry;
}

function nullableVersionField(
  value: Record<string, unknown>,
  key: string
): number | string | null {
  if (!has(value, key) || value[key] === null) return null;
  const entry = value[key];
  if (typeof entry === 'string') {
    if (entry.trim().length === 0) invalid();
    return entry;
  }
  if (typeof entry !== 'number' || !Number.isFinite(entry)) invalid();
  return entry;
}

function requiredNonNegativeInteger(
  value: Record<string, unknown>,
  key: string
): number {
  const entry = value[key];
  if (
    typeof entry !== 'number' ||
    !Number.isInteger(entry) ||
    entry < 0 ||
    !Number.isFinite(entry)
  ) {
    invalid();
  }
  return entry;
}

function countField(
  value: Record<string, unknown>,
  key: string,
  required: boolean,
  fallback: number
): number {
  if (!has(value, key)) {
    if (required) invalid();
    return fallback;
  }
  return requiredNonNegativeInteger(value, key);
}

function nullableNonNegativeIntegerField(
  value: Record<string, unknown>,
  key: string
): number | null {
  if (!has(value, key) || value[key] === null) return null;
  return requiredNonNegativeInteger(value, key);
}

function nullableFiniteNumberField(
  value: Record<string, unknown>,
  key: string
): number | null {
  if (!has(value, key) || value[key] === null) return null;
  const entry = value[key];
  if (typeof entry !== 'number' || !Number.isFinite(entry)) invalid();
  return entry;
}

function booleanField(
  value: Record<string, unknown>,
  key: string,
  fallback: boolean,
  required = false
): boolean {
  if (!has(value, key)) {
    if (required) invalid();
    return fallback;
  }
  if (typeof value[key] !== 'boolean') invalid();
  return value[key];
}

function nullableBooleanField(
  value: Record<string, unknown>,
  key: string
): boolean | null {
  if (!has(value, key) || value[key] === null) return null;
  if (typeof value[key] !== 'boolean') invalid();
  return value[key];
}

function numberRecordField(
  value: Record<string, unknown>,
  key: string,
  required: boolean
): Record<string, number> {
  const record = recordField(value, key, required);
  for (const entry of Object.values(record)) {
    if (typeof entry !== 'number' || !Number.isFinite(entry)) invalid();
  }
  return record as Record<string, number>;
}

function countRecordField(
  value: Record<string, unknown>,
  key: string,
  required: boolean
): Record<string, number> {
  const record = recordField(value, key, required);
  for (const entry of Object.values(record)) {
    if (!Number.isInteger(entry) || (entry as number) < 0) invalid();
  }
  return record as Record<string, number>;
}

function dataPolicyField(
  value: Record<string, unknown>,
  key: string
): LeaderboardDataPolicy {
  const entry = value[key];
  if (!acceptedDataPolicies.includes(entry as LeaderboardDataPolicy)) invalid();
  return entry as LeaderboardDataPolicy;
}

function has(value: Record<string, unknown>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(value, key);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function invalid(): never {
  throw new TypeError('Malformed leaderboard artifact');
}
