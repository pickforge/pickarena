import { base } from '$app/paths';

export type LeaderboardBenchmark = {
  title: string;
  version: string | null;
  taskSetId: string | null;
  evaluatorSchemaVersion: number;
  track: string;
  dataPolicy: string;
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
  schemaVersion: 1;
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

export type LeaderboardLoadResult = {
  leaderboard: LeaderboardData;
  warning: string | null;
};

type LeaderboardFetch = (
  input: RequestInfo | URL,
  init?: RequestInit
) => Promise<Response>;

const emptyLeaderboard: LeaderboardData = {
  schemaVersion: 1,
  provisional: false,
  generatedAt: null,
  benchmark: {
    title: 'PickArena by Pickforge Studio',
    version: null,
    taskSetId: null,
    evaluatorSchemaVersion: 0,
    track: 'agentic',
    dataPolicy: 'aggregate-compatible'
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
  pricingRegistry: {
    version: null,
    currency: null,
    modelCount: 0
  },
  models: [],
  tasks: [],
  taskModelCells: [],
  trialSummaries: []
};

export async function loadLeaderboard(
  fetcher: LeaderboardFetch = fetch
): Promise<LeaderboardLoadResult> {
  try {
    const response = await fetcher(`${base}/data/leaderboard.v1.json`);
    if (!response.ok) {
      return withWarning(`Leaderboard data is unavailable (${response.status}).`);
    }

    const decoded: unknown = await response.json();
    const leaderboard = parseLeaderboard(decoded);
    if (!leaderboard) {
      return withWarning('Leaderboard data is malformed.');
    }

    return {
      leaderboard,
      warning: null
    };
  } catch {
    return withWarning('Leaderboard data could not be loaded.');
  }
}

function withWarning(warning: string): LeaderboardLoadResult {
  return {
    leaderboard: emptyLeaderboard,
    warning
  };
}

function parseLeaderboard(value: unknown): LeaderboardData | null {
  if (!isRecord(value)) return null;
  if (value.schemaVersion !== 1) return null;
  if (!isRecord(value.benchmark)) return null;
  if (!isRecord(value.source)) return null;
  if (!Array.isArray(value.models)) return null;
  if (!Array.isArray(value.tasks)) return null;

  const title = value.benchmark.title;
  const track = value.benchmark.track;
  const dataPolicy = value.benchmark.dataPolicy;
  const taskCount = value.source.taskCount;
  const taskRunCount = value.source.taskRunCount;
  const pricingRegistry = isRecord(value.pricingRegistry)
    ? value.pricingRegistry
    : {};
  const scoring = isRecord(value.scoring) ? value.scoring : {};
  const judgeOverhead = isRecord(value.source.judgeOverhead)
    ? value.source.judgeOverhead
    : {};
  const runProvenance = isRecord(value.source.runProvenance)
    ? value.source.runProvenance
    : {};

  if (
    typeof title !== 'string' ||
    typeof track !== 'string' ||
    typeof dataPolicy !== 'string' ||
    typeof taskCount !== 'number' ||
    typeof taskRunCount !== 'number'
  ) {
    return null;
  }

  const models = value.models.filter(isRecord).map(parseModelRow);
  const tasks = value.tasks.filter(isRecord).map(parseTaskRow);
  const taskModelCells = Array.isArray(value.taskModelCells)
    ? value.taskModelCells.filter(isRecord).map(parseTaskModelCell)
    : [];
  const trialSummaries = Array.isArray(value.trialSummaries)
    ? value.trialSummaries.filter(isRecord).map(parseTrialSummary)
    : [];

  return {
    schemaVersion: 1,
    provisional: value.provisional === true,
    generatedAt: typeof value.generatedAt === 'string' ? value.generatedAt : null,
    benchmark: {
      title,
      version:
        typeof value.benchmark.version === 'string'
          ? value.benchmark.version
          : null,
      taskSetId:
        typeof value.benchmark.taskSetId === 'string'
          ? value.benchmark.taskSetId
          : null,
      evaluatorSchemaVersion:
        parseNumber(value.benchmark.evaluatorSchemaVersion) ?? 0,
      track,
      dataPolicy
    },
    source: {
      anchorRunId:
        typeof value.source.anchorRunId === 'string' ? value.source.anchorRunId : null,
      runIds: parseStringArray(value.source.runIds),
      taskCount,
      taskRunCount,
      modelCount: parseNumber(value.source.modelCount) ?? models.length,
      trialSummaryCount:
        parseNumber(value.source.trialSummaryCount) ?? trialSummaries.length,
      trialSummaryTotalCount:
        parseNumber(value.source.trialSummaryTotalCount) ?? taskRunCount,
      trialSummaryTruncated:
        typeof value.source.trialSummaryTruncated === 'boolean'
          ? value.source.trialSummaryTruncated
          : false,
      trialSummaryLimit: parseNumber(value.source.trialSummaryLimit) ?? 0,
      warnings: parseWarnings(value.source.warnings),
      judgeOverhead: parseJudgeOverhead(judgeOverhead),
      runProvenance: parseRunProvenance(runProvenance)
    },
    scoring: parseScoring(scoring),
    pricingRegistry: {
      version:
        typeof pricingRegistry.version === 'string' ? pricingRegistry.version : null,
      currency:
        typeof pricingRegistry.currency === 'string' ? pricingRegistry.currency : null,
      modelCount: parseNumber(pricingRegistry.modelCount) ?? 0
    },
    models,
    tasks,
    taskModelCells,
    trialSummaries
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

function parseScoring(value: Record<string, unknown>): LeaderboardScoring {
  return {
    schemaVersion: parseNumber(value.schemaVersion) ?? 0,
    primaryMetric:
      typeof value.primaryMetric === 'string' ? value.primaryMetric : null,
    rankingMetric:
      typeof value.rankingMetric === 'string' ? value.rankingMetric : null,
    confidenceInterval:
      typeof value.confidenceInterval === 'string'
        ? value.confidenceInterval
        : null,
    llmJudgePolicy:
      typeof value.llmJudgePolicy === 'string' ? value.llmJudgePolicy : null,
    objectiveEvaluatorIds: parseStringArray(value.objectiveEvaluatorIds),
    secondaryEvaluatorIds: parseStringArray(value.secondaryEvaluatorIds),
    hiddenVerifierPattern:
      typeof value.hiddenVerifierPattern === 'string'
        ? value.hiddenVerifierPattern
        : null,
    failureTags: parseStringArray(value.failureTags),
    objectiveFailureCaps: parseNumberRecord(value.objectiveFailureCaps),
    defaultEvaluatorWeights: parseNumberRecord(value.defaultEvaluatorWeights)
  };
}

function parseJudgeOverhead(
  value: Record<string, unknown>
): LeaderboardJudgeOverhead {
  return {
    evaluationCount: parseNumber(value.evaluationCount) ?? 0,
    promptTokens: parseNumber(value.promptTokens) ?? 0,
    completionTokens: parseNumber(value.completionTokens) ?? 0,
    knownEstimatedCostCount: parseNumber(value.knownEstimatedCostCount) ?? 0,
    unknownEstimatedCostCount: parseNumber(value.unknownEstimatedCostCount) ?? 0,
    totalEstimatedCostMicros: parseNumber(value.totalEstimatedCostMicros) ?? 0,
    pricingStatusCounts: parseNumberRecord(value.pricingStatusCounts)
  };
}

function parseRunProvenance(
  value: Record<string, unknown>
): LeaderboardRunProvenance {
  return {
    runCount: parseNumber(value.runCount) ?? 0,
    embeddedRunCount: parseNumber(value.embeddedRunCount) ?? 0,
    sandboxEnforcedRunCount: parseNumber(value.sandboxEnforcedRunCount) ?? 0,
    taskExecutionPolicyRunCount:
      parseNumber(value.taskExecutionPolicyRunCount) ?? 0,
    networkDisabledTaskPolicyRunCount:
      parseNumber(value.networkDisabledTaskPolicyRunCount) ?? 0,
    taskResourceLimitRunCount:
      parseNumber(value.taskResourceLimitRunCount) ?? 0,
    sdkVersionRunCount: parseNumber(value.sdkVersionRunCount) ?? 0,
    dependencySnapshotRunCount:
      parseNumber(value.dependencySnapshotRunCount) ?? 0,
    pricingRegistryRunCount: parseNumber(value.pricingRegistryRunCount) ?? 0,
    generatedCodeSandboxBackends: parseStringArray(
      value.generatedCodeSandboxBackends
    ),
    dartVersions: parseStringArray(value.dartVersions),
    flutterVersions: parseStringArray(value.flutterVersions),
    environmentIds: parseStringArray(value.environmentIds),
    warnings: parseWarnings(value.warnings)
  };
}

function parseModelIdentity(value: Record<string, unknown>): {
  displayName: string | null;
  providerLabel: string | null;
} {
  const config = isRecord(value.modelConfig) ? value.modelConfig : {};
  const displayName =
    typeof config.customModelDisplayName === 'string' &&
    config.customModelDisplayName.length > 0
      ? config.customModelDisplayName
      : null;
  const providerLabel =
    typeof config.customModelProvider === 'string' &&
    config.customModelProvider.length > 0
      ? config.customModelProvider
      : null;
  return { displayName, providerLabel };
}

function parseModelRow(value: Record<string, unknown>): LeaderboardModel {
  return {
    providerId: parseString(value.providerId, 'unknown-provider'),
    modelId: parseString(value.modelId, 'unknown-model'),
    ...parseModelIdentity(value),
    rank: parseNumber(value.rank),
    score: parseNumber(value.score),
    passRate: parseNumber(value.passRate),
    trialCount: parseNumber(value.trialCount) ?? parseNumber(value.sampleCount) ?? 0,
    passCount: parseNumber(value.passCount) ?? 0,
    sampleCount: parseNumber(value.sampleCount) ?? 0,
    passAtK: parsePassAtK(value.passAtK),
    medianStepCount: parseNumber(value.medianStepCount),
    medianPeakContextTokens: parseNumber(value.medianPeakContextTokens),
    publicPassCount: parseNumber(value.publicPassCount) ?? 0,
    publicSampleCount: parseNumber(value.publicSampleCount) ?? 0,
    publicPassRate: parseNumber(value.publicPassRate),
    hiddenPassCount: parseNumber(value.hiddenPassCount) ?? 0,
    hiddenSampleCount: parseNumber(value.hiddenSampleCount) ?? 0,
    hiddenPassRate: parseNumber(value.hiddenPassRate),
    confidenceInterval: parseConfidenceInterval(value.confidenceInterval),
    lowSample: typeof value.lowSample === 'boolean' ? value.lowSample : false,
    medianLatencyMs: parseNumber(value.medianLatencyMs),
    medianPromptTokens: parseNumber(value.medianPromptTokens),
    medianCompletionTokens: parseNumber(value.medianCompletionTokens),
    medianEstimatedCostMicros: parseNumber(value.medianEstimatedCostMicros),
    knownEstimatedCostCount: parseNumber(value.knownEstimatedCostCount) ?? 0,
    unknownEstimatedCostCount: parseNumber(value.unknownEstimatedCostCount) ?? 0,
    totalEstimatedCostMicros: parseNumber(value.totalEstimatedCostMicros),
    costPerSolvedTaskMicros: parseNumber(value.costPerSolvedTaskMicros),
    cheapestPassingEstimatedCostMicros: parseNumber(
      value.cheapestPassingEstimatedCostMicros
    ),
    failureBreakdown: parseNumberRecord(value.failureBreakdown),
    blockedEvaluationCount: parseNumber(value.blockedEvaluationCount) ?? 0,
    blockedTaskRunCount: parseNumber(value.blockedTaskRunCount) ?? 0
  };
}

function parseTaskRow(value: Record<string, unknown>): LeaderboardTask {
  return {
    taskId: parseString(value.taskId, 'unknown-task'),
    taskVersion:
      typeof value.taskVersion === 'string' || typeof value.taskVersion === 'number'
        ? value.taskVersion
        : null,
    benchmarkTrack:
      typeof value.benchmarkTrack === 'string' ? value.benchmarkTrack : null,
    trialCount: parseNumber(value.trialCount) ?? parseNumber(value.sampleCount) ?? 0,
    sampleCount: parseNumber(value.sampleCount) ?? 0,
    modelCount: parseNumber(value.modelCount) ?? 0,
    passRate: parseNumber(value.passRate),
    confidenceInterval: parseConfidenceInterval(value.confidenceInterval),
    passAtK: parsePassAtK(value.passAtK),
    medianStepCount: parseNumber(value.medianStepCount),
    medianPeakContextTokens: parseNumber(value.medianPeakContextTokens),
    publicPassCount: parseNumber(value.publicPassCount) ?? 0,
    publicSampleCount: parseNumber(value.publicSampleCount) ?? 0,
    publicPassRate: parseNumber(value.publicPassRate),
    hiddenPassCount: parseNumber(value.hiddenPassCount) ?? 0,
    hiddenSampleCount: parseNumber(value.hiddenSampleCount) ?? 0,
    hiddenPassRate: parseNumber(value.hiddenPassRate),
    blockedEvaluationCount: parseNumber(value.blockedEvaluationCount) ?? 0,
    blockedTaskRunCount: parseNumber(value.blockedTaskRunCount) ?? 0
  };
}

function parseTaskModelCell(
  value: Record<string, unknown>
): LeaderboardTaskModelCell {
  return {
    providerId: parseString(value.providerId, 'unknown-provider'),
    modelId: parseString(value.modelId, 'unknown-model'),
    ...parseModelIdentity(value),
    taskId: parseString(value.taskId, 'unknown-task'),
    taskVersion:
      typeof value.taskVersion === 'string' || typeof value.taskVersion === 'number'
        ? value.taskVersion
        : null,
    benchmarkTrack:
      typeof value.benchmarkTrack === 'string' ? value.benchmarkTrack : null,
    trialCount: parseNumber(value.trialCount) ?? parseNumber(value.sampleCount) ?? 0,
    passCount: parseNumber(value.passCount) ?? 0,
    sampleCount: parseNumber(value.sampleCount) ?? 0,
    passRate: parseNumber(value.passRate),
    confidenceInterval: parseConfidenceInterval(value.confidenceInterval),
    errorCount: parseNumber(value.errorCount) ?? 0,
    passAtK: parsePassAtK(value.passAtK),
    medianStepCount: parseNumber(value.medianStepCount),
    medianPeakContextTokens: parseNumber(value.medianPeakContextTokens),
    publicPassCount: parseNumber(value.publicPassCount) ?? 0,
    publicSampleCount: parseNumber(value.publicSampleCount) ?? 0,
    publicPassRate: parseNumber(value.publicPassRate),
    hiddenPassCount: parseNumber(value.hiddenPassCount) ?? 0,
    hiddenSampleCount: parseNumber(value.hiddenSampleCount) ?? 0,
    hiddenPassRate: parseNumber(value.hiddenPassRate),
    blockedEvaluationCount: parseNumber(value.blockedEvaluationCount) ?? 0,
    blockedTaskRunCount: parseNumber(value.blockedTaskRunCount) ?? 0,
    medianLatencyMs: parseNumber(value.medianLatencyMs),
    medianPromptTokens: parseNumber(value.medianPromptTokens),
    medianCompletionTokens: parseNumber(value.medianCompletionTokens),
    medianEstimatedCostMicros: parseNumber(value.medianEstimatedCostMicros),
    knownEstimatedCostCount: parseNumber(value.knownEstimatedCostCount) ?? 0,
    unknownEstimatedCostCount: parseNumber(value.unknownEstimatedCostCount) ?? 0,
    failureBreakdown: parseNumberRecord(value.failureBreakdown)
  };
}

function parseConfidenceInterval(value: unknown): LeaderboardConfidenceInterval {
  const confidenceInterval = isRecord(value) ? value : {};
  return {
    lower: parseNumber(confidenceInterval.lower),
    upper: parseNumber(confidenceInterval.upper)
  };
}

function parseTrialSummary(
  value: Record<string, unknown>
): LeaderboardTrialSummary {
  return {
    trialId: parseString(value.trialId, 'unknown-trial'),
    runId: parseString(value.runId, 'unknown-run'),
    providerId: parseString(value.providerId, 'unknown-provider'),
    modelId: parseString(value.modelId, 'unknown-model'),
    ...parseModelIdentity(value),
    taskId: parseString(value.taskId, 'unknown-task'),
    taskVersion:
      typeof value.taskVersion === 'string' || typeof value.taskVersion === 'number'
        ? value.taskVersion
        : null,
    benchmarkTrack:
      typeof value.benchmarkTrack === 'string' ? value.benchmarkTrack : null,
    trialIndex: parseNumber(value.trialIndex) ?? 0,
    completedAt: typeof value.completedAt === 'string' ? value.completedAt : null,
    primaryPass:
      typeof value.primaryPass === 'boolean' ? value.primaryPass : null,
    failureTag: parseString(value.failureTag, 'unknown'),
    aggregateScore: parseNumber(value.aggregateScore),
    publicPassed:
      typeof value.publicPassed === 'boolean' ? value.publicPassed : null,
    hiddenPassed:
      typeof value.hiddenPassed === 'boolean' ? value.hiddenPassed : null,
    blockedEvaluationCount: parseNumber(value.blockedEvaluationCount) ?? 0,
    stepCount: parseNumber(value.stepCount),
    peakContextTokens: parseNumber(value.peakContextTokens),
    latencyMs: parseNumber(value.latencyMs),
    promptTokens: parseNumber(value.promptTokens),
    completionTokens: parseNumber(value.completionTokens),
    estimatedCostMicros: parseNumber(value.estimatedCostMicros)
  };
}

function parsePassAtK(value: unknown): LeaderboardPassAtK {
  if (!isRecord(value)) return {};

  const parsed: [string, LeaderboardPassAtKEntry][] = [];
  for (const [key, rawEntry] of Object.entries(value)) {
    if (!isRecord(rawEntry)) continue;

    const k = parseNumber(rawEntry.k) ?? Number.parseInt(key, 10);
    if (!Number.isFinite(k)) continue;

    parsed.push([
      key,
      {
        k,
        passCount: parseNumber(rawEntry.passCount) ?? 0,
        sampleCount: parseNumber(rawEntry.sampleCount) ?? 0,
        passRate: parseNumber(rawEntry.passRate)
      }
    ]);
  }

  return Object.fromEntries(parsed);
}

function parseString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.length > 0 ? value : fallback;
}

function parseNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function parseWarnings(value: unknown): string[] {
  return parseStringArray(value);
}

function parseStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === 'string');
}

function parseNumberRecord(value: unknown): Record<string, number> {
  if (!isRecord(value)) return {};

  return Object.fromEntries(
    Object.entries(value).filter(
      (entry): entry is [string, number] =>
        typeof entry[1] === 'number' && Number.isFinite(entry[1])
    )
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
