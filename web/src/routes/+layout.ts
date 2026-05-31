import { loadLeaderboard } from '$lib/data/leaderboard';
import type { LayoutLoad } from './$types';

export const prerender = true;

export const load: LayoutLoad = async ({ fetch }) => loadLeaderboard(fetch);
