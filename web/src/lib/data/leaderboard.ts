export type LeaderboardBenchmark = {
  title: string;
  track: string;
  dataPolicy: string;
};

export type LeaderboardSource = {
  taskCount: number;
  taskRunCount: number;
  warnings?: string[];
};

export type LeaderboardModel = Record<string, unknown>;

export type LeaderboardTask = Record<string, unknown>;

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
    taskCount: 0,
    taskRunCount: 0,
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

  return {
    schemaVersion: 1,
    generatedAt: typeof value.generatedAt === 'string' ? value.generatedAt : null,
    benchmark: {
      title,
      track,
      dataPolicy
    },
    source: {
      taskCount,
      taskRunCount,
      warnings: parseWarnings(value.source.warnings)
    },
    models: value.models.filter(isRecord),
    tasks: value.tasks.filter(isRecord)
  };
}

function parseWarnings(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === 'string');
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
