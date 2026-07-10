<script lang="ts">
  import { base } from '$app/paths';
  import PassRate from '$lib/components/PassRate.svelte';
  import {
    costText,
    countText,
    durationText,
    formatCost,
    formatDuration,
    modelName,
    percentText,
    providerName,
    tokensText
  } from '$lib/data/format';
  import type {
    LeaderboardModel,
    LeaderboardPassAtKEntry
  } from '$lib/data/leaderboard';
  import type { PageData } from './$types';

  type ChartMode = 'cost' | 'latency';
  type ChartRow = { model: LeaderboardModel; x: number; y: number; metric: number };

  let { data }: { data: PageData } = $props();

  let leaderboard = $derived(data.leaderboard);
  let rankedModels = $derived(sortModels(leaderboard.models));
  let categoryCount = $derived(countCategories(leaderboard));
  let chartMode = $derived<ChartMode>(
    rankedModels.some((m) => m.costPerSolvedTaskMicros !== null) ? 'cost' : 'latency'
  );
  let chartRows = $derived(buildChartRows(rankedModels, chartMode));
  let sandbox = $derived(
    leaderboard.source.runProvenance.generatedCodeSandboxBackends[0] ?? null
  );

  const PLOT = { left: 66, right: 694, top: 28, bottom: 296 } as const;

  function sortModels(models: LeaderboardModel[]): LeaderboardModel[] {
    return [...models].sort((a, b) => {
      if (a.rank !== null && b.rank !== null) return a.rank - b.rank;
      if (a.rank !== null) return -1;
      if (b.rank !== null) return 1;
      return (b.passRate ?? -1) - (a.passRate ?? -1);
    });
  }

  function countCategories(board: PageData['leaderboard']): number {
    const categories = new Set(
      board.tasks.map((task) => task.taskId.split('.')[0]).filter(Boolean)
    );
    return categories.size;
  }

  function buildChartRows(models: LeaderboardModel[], mode: ChartMode): ChartRow[] {
    const candidates = models
      .map((model) => ({
        model,
        metric: mode === 'cost' ? model.costPerSolvedTaskMicros : model.medianLatencyMs,
        passRate: model.passRate
      }))
      .filter(
        (row): row is { model: LeaderboardModel; metric: number; passRate: number } =>
          row.metric !== null && row.passRate !== null
      );

    if (candidates.length === 0) return [];

    const metrics = candidates.map((row) => row.metric);
    const min = Math.min(...metrics);
    const max = Math.max(...metrics);
    const span = max - min;
    const width = PLOT.right - PLOT.left;
    const height = PLOT.bottom - PLOT.top;

    return candidates.map((row) => {
      const ratio = span === 0 ? 0.5 : (row.metric - min) / span;
      const pass = Math.max(0, Math.min(1, row.passRate));
      return {
        model: row.model,
        metric: row.metric,
        x: PLOT.left + ratio * width,
        y: PLOT.bottom - pass * height
      };
    });
  }

  function metricLabel(mode: ChartMode): string {
    return mode === 'cost' ? 'cost per solved task' : 'median latency';
  }

  function chartMetricText(value: number, mode: ChartMode): string {
    return mode === 'cost' ? formatCost(value) : formatDuration(value);
  }

  function gridY(fraction: number): number {
    return PLOT.bottom - fraction * (PLOT.bottom - PLOT.top);
  }

  function passAtOne(model: LeaderboardModel): LeaderboardPassAtKEntry | null {
    const entry = model.passAtK['1'];
    return entry && entry.passRate !== null ? entry : null;
  }
</script>

<svelte:head>
  <title>PickArena by Pickforge Studio</title>
  <meta
    name="description"
    content="PickArena measures AI coding agents on real Flutter engineering tasks with hidden behavioral verification, clean-baseline grading, and reproducible provenance."
  />
</svelte:head>

<section class="hero" aria-labelledby="hero-title">
  <p class="eyebrow">Pickforge Studio benchmark</p>
  <h1 id="hero-title">Measuring AI coding agents on real Flutter tasks.</h1>
  <p class="lede">
    PickArena runs coding agents inside sandboxed Flutter workspaces, grades their
    patches against hidden behavioral verifiers on a clean baseline, and publishes the
    results as a reproducible static leaderboard — quality, cost, and reliability side
    by side.
  </p>
  <div class="cta-row">
    <a class="button primary" href={`${base}/methodology/`}>Read the methodology</a>
    <a class="button secondary" href={`${base}/run/`}>Run it yourself</a>
    <a class="button ghost" href="#leaderboard">Jump to leaderboard →</a>
  </div>
</section>

<div class="stat-strip">
  <div class="stat">
    <span class="stat-label">Tasks</span>
    <span class="stat-value">{countText(leaderboard.source.taskCount)}</span>
    <span class="stat-note">Flutter engineering tasks</span>
  </div>
  <div class="stat">
    <span class="stat-label">Categories</span>
    <span class="stat-value">{categoryCount || '—'}</span>
    <span class="stat-note">forms, lists, state, nav…</span>
  </div>
  <div class="stat">
    <span class="stat-label">Models</span>
    <span class="stat-value">{countText(leaderboard.source.modelCount)}</span>
    <span class="stat-note">agents evaluated</span>
  </div>
  <div class="stat">
    <span class="stat-label">Trials</span>
    <span class="stat-value">{countText(leaderboard.source.taskRunCount)}</span>
    <span class="stat-note">scored attempts</span>
  </div>
  <div class="stat">
    <span class="stat-label">Sandbox</span>
    <span class="stat-value" style="font-size:1.15rem;">{sandbox ?? '—'}</span>
    <span class="stat-note">isolated execution</span>
  </div>
  <div class="stat">
    <span class="stat-label">Interval</span>
    <span class="stat-value" style="font-size:1.15rem;">
      {leaderboard.scoring.confidenceInterval === 'wilson_95' ? 'Wilson 95%' : (leaderboard.scoring.confidenceInterval ?? '—')}
    </span>
    <span class="stat-note">confidence method</span>
  </div>
</div>

<section class="section" aria-labelledby="chart-title">
  <div class="section-head">
    <p class="eyebrow">Efficiency frontier</p>
    <h2 id="chart-title">Pass rate vs {metricLabel(chartMode)}</h2>
    <p>
      Higher and to the left is better: more tasks solved for less
      {chartMode === 'cost' ? 'money' : 'wall-clock time'}. Points are model rows with
      both a known pass rate and known {metricLabel(chartMode)}.
    </p>
  </div>

  <div class="chart-card">
    <div class="chart-head">
      <span class="data-label" style="margin:0;">Pass rate (y) · {metricLabel(chartMode)} (x)</span>
      <span class="caption">
        {#if chartMode === 'latency'}
          Cost telemetry is unknown for this run, so latency is plotted instead.
        {:else}
          {chartRows.length} model{chartRows.length === 1 ? '' : 's'} plotted
        {/if}
      </span>
    </div>

    {#if chartRows.length > 0}
      <svg class="chart" viewBox="0 0 720 340" role="img" aria-labelledby="chart-svg-title chart-svg-desc">
        <title id="chart-svg-title">Model pass rate against {metricLabel(chartMode)}</title>
        <desc id="chart-svg-desc">
          Scatter plot. The vertical axis is pass rate from zero to one hundred percent.
          The horizontal axis is {metricLabel(chartMode)}; lower values are more efficient.
        </desc>

        {#each [0, 0.25, 0.5, 0.75, 1] as fraction}
          <line class="grid-line" x1={PLOT.left} y1={gridY(fraction)} x2={PLOT.right} y2={gridY(fraction)} />
          <text class="axis-label" x={PLOT.left - 10} y={gridY(fraction) + 3} text-anchor="end">
            {Math.round(fraction * 100)}%
          </text>
        {/each}

        <line class="axis-line" x1={PLOT.left} y1={PLOT.top} x2={PLOT.left} y2={PLOT.bottom} />
        <line class="axis-line" x1={PLOT.left} y1={PLOT.bottom} x2={PLOT.right} y2={PLOT.bottom} />

        <text class="axis-label" x={PLOT.left} y={PLOT.bottom + 24} text-anchor="start">
          lower {chartMode}
        </text>
        <text class="axis-label" x={PLOT.right} y={PLOT.bottom + 24} text-anchor="end">
          higher {chartMode}
        </text>

        {#each chartRows as row}
          <circle class="point" class:low={row.model.lowSample} cx={row.x} cy={row.y} r={row.model.lowSample ? 7 : 9} />
          <text class="point-label" x={Math.min(row.x + 14, PLOT.right - 4)} y={row.y - 12}>
            {modelName(row.model)}
          </text>
          <text class="axis-label" x={Math.min(row.x + 14, PLOT.right - 4)} y={row.y + 1}>
            {percentText(row.model.passRate)} · {chartMetricText(row.metric, chartMode)}
          </text>
        {/each}
      </svg>
    {:else}
      <p class="chart-empty">No model rows include both a pass rate and {metricLabel(chartMode)} yet.</p>
    {/if}
  </div>
</section>

<section class="section" id="leaderboard" aria-labelledby="leaderboard-title">
  <div class="section-head">
    <p class="eyebrow">Ranked results</p>
    <h2 id="leaderboard-title">Leaderboard</h2>
    <p>
      Ordered by primary pass rate. Each row keeps its sample size, Wilson 95%
      confidence interval, and public/hidden split visible so a small run is never
      mistaken for a settled ranking.
    </p>
  </div>

  {#if rankedModels.length > 0}
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th scope="col" class="num">#</th>
            <th scope="col">Model</th>
            <th scope="col">Pass rate</th>
            <th scope="col" class="num">Public / hidden</th>
            <th scope="col" class="num">Cost / solved task</th>
            <th scope="col" class="num">Output tokens</th>
            <th scope="col" class="num">Steps</th>
            <th scope="col" class="num">Latency</th>
          </tr>
        </thead>
        <tbody>
          {#each rankedModels as model, index}
            {@const passOne = passAtOne(model)}
            <tr>
              <td class="rank-cell" class:top={(model.rank ?? index + 1) === 1}>
                {model.rank ?? index + 1}
              </td>
              <td class="model-cell">
                <span class="model-name">{modelName(model)}</span>
                <span class="model-provider">{providerName(model)}</span>
                <div class="flag-row">
                  <span class="flag neutral">n = {model.sampleCount}</span>
                  {#if model.lowSample}
                    <span class="flag">low sample</span>
                  {/if}
                  {#if model.unknownEstimatedCostCount > 0}
                    <span class="flag">cost unknown</span>
                  {/if}
                  {#if model.blockedTaskRunCount > 0 || model.blockedEvaluationCount > 0}
                    <span class="flag" title="Some verifier runs were blocked; pass rate reflects only unblocked runs">
                      {model.blockedTaskRunCount || model.blockedEvaluationCount} blocked
                    </span>
                  {/if}
                </div>
              </td>
              <td>
                <PassRate rate={model.passRate} ci={model.confidenceInterval} />
                {#if passOne}
                  <span class="passrate-ci" style="display:block;margin-top:0.4rem;">
                    Pass@1 {percentText(passOne.passRate)} · n {passOne.sampleCount}
                  </span>
                {/if}
              </td>
              <td class="num">
                <span class="split">
                  <span>{percentText(model.publicPassRate)}</span>
                  <span class="divider">/</span>
                  <span class="hidden">{percentText(model.hiddenPassRate)}</span>
                </span>
              </td>
              <td class="num">{costText(model.costPerSolvedTaskMicros)}</td>
              <td class="num">{tokensText(model.medianCompletionTokens)}</td>
              <td class="num">{countText(model.medianStepCount)}</td>
              <td class="num">{durationText(model.medianLatencyMs)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
    <p class="muted" style="margin-top:0.9rem;font-size:0.88rem;">
      Pass rate is the aggregate primary-pass rate over all trials (the ranking metric,
      with its Wilson 95% interval); Pass@1 is the single-attempt rate over n first
      attempts. Public pass = visible tests and analyzer checks. Hidden pass =
      clean-baseline behavioral verifiers the agent never sees. A dash means the provider
      or harness did not report that telemetry — it is shown as unknown, never as zero.
    </p>
  {:else}
    <p class="empty">No model rows are available yet.</p>
  {/if}
</section>

<section class="section" aria-labelledby="how-title">
  <div class="section-head">
    <p class="eyebrow">How it works</p>
    <h2 id="how-title">Honest grading, not vibes</h2>
    <p>
      PickArena borrows its rigor from DeepSWE-style evaluation and applies it to mobile
      app work. The short version:
    </p>
  </div>

  <div class="feature-grid">
    <article class="card">
      <div class="kicker">01 · Hidden verifiers</div>
      <h3>Behavior, not snapshots</h3>
      <p>
        Every task carries hidden tests that assert user-observable behavior and API
        contracts. Agents never see them, so passing means the app actually works.
      </p>
    </article>
    <article class="card">
      <div class="kicker">02 · Clean replay</div>
      <h3>Graded on a fresh baseline</h3>
      <p>
        Each submitted patch is captured and replayed into a clean baseline before
        grading, in a separate verifier context from the one the agent mutated.
      </p>
    </article>
    <article class="card">
      <div class="kicker">03 · Negative cases</div>
      <h3>Fake fixes get rejected</h3>
      <p>
        Noop, API-breaking, and overfit solutions must fail admission. Hidden breadth
        rejects hardcoded values, deleted tests, and prompt-only edits.
      </p>
    </article>
    <article class="card">
      <div class="kicker">04 · Provenance</div>
      <h3>Reproducible runs</h3>
      <p>
        Runs record SDK versions, sandbox backend, network policy, resource limits, and
        git state. Unknown cost and token telemetry is labeled, never assumed zero.
      </p>
    </article>
  </div>

  <div class="cta-row" style="margin-top:1.5rem;">
    <a class="button secondary" href={`${base}/methodology/`}>Full methodology</a>
    <a class="button ghost" href={`${base}/tasks/`}>Browse the task corpus →</a>
  </div>
</section>
