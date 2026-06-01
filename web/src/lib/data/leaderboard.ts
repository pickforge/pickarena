export type LeaderboardBenchmark = {
  title: string;
  track: string;
  dataPolicy: string;
};

export type LeaderboardSource = {
  anchorRunId: string | null;
  runIds: string[];
  taskCount: number;
  taskRunCount: number;
  modelCount: number;
  warnings: string[];
};

export type LeaderboardModel = {
  providerId: string;
  modelId: string;
  rank: number | null;
  score: number | null;
  passRate: number | null;
  passCount: number;
  sampleCount: number;
  confidenceInterval: {
    lower: number | null;
    upper: number | null;
  };
  lowSample: boolean;
  medianLatencyMs: number | null;
  medianPromptTokens: number | null;
  medianCompletionTokens: number | null;
  medianEstimatedCostMicros: number | null;
  costPerSolvedTaskMicros: number | null;
  failureBreakdown: Record<string, number>;
};

export type LeaderboardTask = {
  taskId: string;
  taskVersion: number | string | null;
  benchmarkTrack: string | null;
  sampleCount: number;
  modelCount: number;
  passRate: number | null;
};

export type LeaderboardData = {
  schemaVersion: 1;
  generatedAt: string | null;
  benchmark: LeaderboardBenchmark;
  source: LeaderboardSource;
  models: LeaderboardModel[];
  tasks: LeaderboardTask[];
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
  generatedAt: null,
  benchmark: {
    title: 'Dart Arena by Pickforge',
    track: 'agentic',
    dataPolicy: 'aggregate-compatible'
  },
  source: {
    anchorRunId: null,
    runIds: [],
    taskCount: 0,
    taskRunCount: 0,
    modelCount: 0,
    warnings: []
  },
  models: [],
  tasks: []
};

export async function loadLeaderboard(
  fetcher: LeaderboardFetch = fetch
): Promise<LeaderboardLoadResult> {
  try {
    const response = await fetcher('/data/leaderboard.v1.json');
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

  return {
    schemaVersion: 1,
    generatedAt: typeof value.generatedAt === 'string' ? value.generatedAt : null,
    benchmark: {
      title,
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
      warnings: parseWarnings(value.source.warnings)
    },
    models,
    tasks
  };
}

function parseModelRow(value: Record<string, unknown>): LeaderboardModel {
  const confidenceInterval = isRecord(value.confidenceInterval)
    ? value.confidenceInterval
    : {};

  return {
    providerId: parseString(value.providerId, 'unknown-provider'),
    modelId: parseString(value.modelId, 'unknown-model'),
    rank: parseNumber(value.rank),
    score: parseNumber(value.score),
    passRate: parseNumber(value.passRate),
    passCount: parseNumber(value.passCount) ?? 0,
    sampleCount: parseNumber(value.sampleCount) ?? 0,
    confidenceInterval: {
      lower: parseNumber(confidenceInterval.lower),
      upper: parseNumber(confidenceInterval.upper)
    },
    lowSample: typeof value.lowSample === 'boolean' ? value.lowSample : false,
    medianLatencyMs: parseNumber(value.medianLatencyMs),
    medianPromptTokens: parseNumber(value.medianPromptTokens),
    medianCompletionTokens: parseNumber(value.medianCompletionTokens),
    medianEstimatedCostMicros: parseNumber(value.medianEstimatedCostMicros),
    costPerSolvedTaskMicros: parseNumber(value.costPerSolvedTaskMicros),
    failureBreakdown: parseNumberRecord(value.failureBreakdown)
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
    sampleCount: parseNumber(value.sampleCount) ?? 0,
    modelCount: parseNumber(value.modelCount) ?? 0,
    passRate: parseNumber(value.passRate)
  };
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
