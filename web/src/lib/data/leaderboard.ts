import { base } from '$app/paths';

import {
  emptyLeaderboard,
  parseLeaderboardArtifactResult,
  type LeaderboardData
} from './leaderboard-contract';

export type * from './leaderboard-contract';

export type LeaderboardLoadResult = {
  leaderboard: LeaderboardData;
  warning: string | null;
};

type LeaderboardFetch = (
  input: RequestInfo | URL,
  init?: RequestInit
) => Promise<Response>;

export async function loadLeaderboard(
  fetcher: LeaderboardFetch = fetch
): Promise<LeaderboardLoadResult> {
  try {
    const response = await fetcher(`${base}/data/leaderboard.v1.json`);
    if (!response.ok) {
      return withWarning(`Leaderboard data is unavailable (${response.status}).`);
    }

    const parsed = parseLeaderboardArtifactResult(await response.text());
    if (!parsed.ok) {
      return withWarning(
        parsed.error === 'syntax'
          ? 'Leaderboard data could not be loaded.'
          : 'Leaderboard data is malformed.'
      );
    }

    return { leaderboard: parsed.value, warning: null };
  } catch {
    return withWarning('Leaderboard data could not be loaded.');
  }
}

function withWarning(warning: string): LeaderboardLoadResult {
  return { leaderboard: emptyLeaderboard, warning };
}
