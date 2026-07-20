import { base } from '$app/paths';

import {
  emptyLeaderboard,
  parseLeaderboardArtifact,
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

    const leaderboard = parseLeaderboardArtifact(await response.text());
    if (!leaderboard) {
      return withWarning('Leaderboard data is malformed.');
    }

    return { leaderboard, warning: null };
  } catch {
    return withWarning('Leaderboard data could not be loaded.');
  }
}

function withWarning(warning: string): LeaderboardLoadResult {
  return { leaderboard: emptyLeaderboard, warning };
}
