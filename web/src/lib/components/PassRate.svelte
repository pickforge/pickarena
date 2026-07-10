<script lang="ts">
  import type { LeaderboardConfidenceInterval } from '$lib/data/leaderboard';
  import { formatPercent } from '$lib/data/format';

  let {
    rate,
    ci = null,
    sample = null
  }: {
    rate: number | null;
    ci?: LeaderboardConfidenceInterval | null;
    sample?: number | null;
  } = $props();

  const clamp = (value: number) => Math.max(0, Math.min(1, value));

  let known = $derived(rate !== null && Number.isFinite(rate));
  let fill = $derived(known ? clamp(rate as number) * 100 : 0);
  let ciLower = $derived(
    ci && ci.lower !== null && Number.isFinite(ci.lower) ? clamp(ci.lower) : null
  );
  let ciUpper = $derived(
    ci && ci.upper !== null && Number.isFinite(ci.upper) ? clamp(ci.upper) : null
  );
  let hasCi = $derived(ciLower !== null && ciUpper !== null);
  let ciLeft = $derived(hasCi ? (ciLower as number) * 100 : 0);
  let ciWidth = $derived(
    hasCi ? Math.max(0, ((ciUpper as number) - (ciLower as number)) * 100) : 0
  );

  let ariaLabel = $derived(
    known
      ? `Pass rate ${formatPercent(rate)}${
          hasCi
            ? `, 95% confidence interval ${formatPercent(ciLower)} to ${formatPercent(
                ciUpper
              )}`
            : ''
        }`
      : 'Pass rate unknown'
  );
</script>

<div class="passrate" class:empty={!known}>
  <div class="passrate-head">
    <span class="passrate-value">{known ? formatPercent(rate) : '—'}</span>
    {#if hasCi}
      <span class="passrate-ci">{formatPercent(ciLower)}–{formatPercent(ciUpper)}</span>
    {/if}
  </div>
  <div class="passbar" role="img" aria-label={ariaLabel}>
    {#if hasCi}
      <span class="passbar-ci" style={`left:${ciLeft}%;width:${ciWidth}%;`}></span>
    {/if}
    {#if known}
      <span class="passbar-fill" style={`width:${fill}%;`}></span>
    {/if}
  </div>
  {#if sample !== null}
    <span class="passrate-ci" style="margin-top:0.3rem;display:block;">n = {sample}</span>
  {/if}
</div>
