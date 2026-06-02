<script lang="ts">
  import { base } from '$app/paths';
  import {
    formatCost,
    formatCount,
    formatDate,
    formatDuration,
    formatModelName,
    formatPercent,
    formatTokens
  } from '$lib/data/format';
  import type { LeaderboardModel, LeaderboardTask } from '$lib/data/leaderboard';
  import type { PageData } from './$types';

  type ChartMode = 'cost' | 'latency';

  type ChartRow = {
    model: LeaderboardModel;
    x: number;
    y: number;
    metric: number;
  };

  let { data }: { data: PageData } = $props();

  const homeHref = `${base}/`;
  const pickforgeMarkSrc = `${base}/branding/pickforge_mark.png`;
  const dartArenaLogoSrc = `${base}/branding/dart_arena_logo_horizontal_light.png`;

  let leaderboard = $derived(data.leaderboard);
  let rankedModels = $derived(sortModels(leaderboard.models));
  let taskExamples = $derived(sortTasks(leaderboard.tasks).slice(0, 6));
  let topModel = $derived(rankedModels[0] ?? null);
  let bestCost = $derived(lowestKnownCost(rankedModels));
  let chartMode = $derived(selectChartMode(rankedModels));
  let chartRows = $derived(buildChartRows(rankedModels, chartMode));
  let sourceWarnings = $derived(
    uniqueWarnings([
      ...(data.warning ? [data.warning] : []),
      ...leaderboard.source.warnings
    ])
  );
  let provenanceWarnings = $derived(uniqueWarnings(leaderboard.source.warnings));

  function sortModels(models: LeaderboardModel[]): LeaderboardModel[] {
    return [...models].sort((left, right) => {
      if (left.rank !== null && right.rank !== null) return left.rank - right.rank;
      if (left.rank !== null) return -1;
      if (right.rank !== null) return 1;
      return 0;
    });
  }

  function sortTasks(tasks: LeaderboardTask[]): LeaderboardTask[] {
    return [...tasks].sort((left, right) => {
      const sampleDelta = right.sampleCount - left.sampleCount;
      if (sampleDelta !== 0) return sampleDelta;

      return (right.passRate ?? -1) - (left.passRate ?? -1);
    });
  }

  function uniqueWarnings(warnings: string[]): string[] {
    return [...new Set(warnings.filter((warning) => warning.length > 0))];
  }

  function lowestKnownCost(models: LeaderboardModel[]): number | null {
    const costs = models
      .map((model) => model.costPerSolvedTaskMicros)
      .filter((cost): cost is number => cost !== null);

    return costs.length > 0 ? Math.min(...costs) : null;
  }

  function selectChartMode(models: LeaderboardModel[]): ChartMode {
    return models.some((model) => model.costPerSolvedTaskMicros !== null)
      ? 'cost'
      : 'latency';
  }

  function buildChartRows(
    models: LeaderboardModel[],
    mode: ChartMode
  ): ChartRow[] {
    const candidates = models
      .map((model) => ({
        model,
        metric:
          mode === 'cost'
            ? model.costPerSolvedTaskMicros
            : model.medianLatencyMs,
        passRate: model.passRate
      }))
      .filter(
        (
          row
        ): row is { model: LeaderboardModel; metric: number; passRate: number } =>
          row.metric !== null && row.passRate !== null
      );

    if (candidates.length === 0) return [];

    const metrics = candidates.map((row) => row.metric);
    const minMetric = Math.min(...metrics);
    const maxMetric = Math.max(...metrics);
    const metricSpan = maxMetric - minMetric;

    return candidates.map((row) => {
      const metricRatio =
        metricSpan === 0 ? 0.5 : (row.metric - minMetric) / metricSpan;
      const passRatio = Math.max(0, Math.min(1, row.passRate));

      return {
        model: row.model,
        metric: row.metric,
        x: 72 + metricRatio * 500,
        y: 282 - passRatio * 218
      };
    });
  }

  function formatConfidence(model: LeaderboardModel): string {
    const { lower, upper } = model.confidenceInterval;
    if (lower === null || upper === null) return 'unknown';

    return `${formatPercent(lower)}–${formatPercent(upper)}`;
  }

  function metricLabel(mode: ChartMode): string {
    return mode === 'cost' ? 'cost per solved task' : 'median latency';
  }

  function formatChartMetric(value: number, mode: ChartMode): string {
    return mode === 'cost' ? formatCost(value) : formatDuration(value);
  }
</script>

<main class="shell">
  <header class="site-header">
    <a class="brand-lockup" href={homeHref} aria-label="Dart Arena by Pickforge home">
      <img src={pickforgeMarkSrc} alt="" width="44" height="44" />
      <span>Dart Arena by Pickforge</span>
    </a>
    <nav class="nav-links" aria-label="Page sections">
      <a href="#leaderboard">Leaderboard</a>
      <a href="#tasks">Tasks</a>
      <a href="#methodology">Methodology</a>
    </nav>
  </header>

  <section class="hero" aria-labelledby="hero-title">
    <div class="hero-content">
      <img
        class="hero-logo"
        src={dartArenaLogoSrc}
        alt="Dart Arena"
      />
      <p class="eyebrow">Static public benchmark</p>
      <h1 id="hero-title">Benchmark AI coding models on Dart and Flutter engineering tasks.</h1>
      <p class="lede">
        Dart Arena uses a Dart/Flutter runner to execute coding tasks, aggregate
        compatible public results, and publish a static leaderboard export for
        comparing model quality, speed, and efficiency.
      </p>
      <div class="cta-row">
        <a class="button" href="#leaderboard">View leaderboard</a>
        <a class="button secondary" href="#methodology">Read methodology</a>
      </div>

      {#if sourceWarnings.length > 0}
        {#each sourceWarnings as warning}
          <p class="warning" role="alert">{warning}</p>
        {/each}
      {/if}
    </div>
  </section>

  <section class="section" aria-labelledby="metrics-title">
    <div class="section-heading">
      <div>
        <p class="eyebrow">Benchmark snapshot</p>
        <h2 id="metrics-title">Current public export</h2>
      </div>
      <p>
        Results are generated from <strong>{leaderboard.benchmark.dataPolicy}</strong>
        task runs and retain sample counts so early rows stay visibly provisional.
      </p>
    </div>

    <div class="metric-grid">
      <article class="metric-card">
        <span>Models</span>
        <strong>{formatCount(leaderboard.source.modelCount)}</strong>
        <p>Published model rows.</p>
      </article>
      <article class="metric-card">
        <span>Tasks</span>
        <strong>{formatCount(leaderboard.source.taskCount)}</strong>
        <p>Dart and Flutter task definitions.</p>
      </article>
      <article class="metric-card">
        <span>Task runs</span>
        <strong>{formatCount(leaderboard.source.taskRunCount)}</strong>
        <p>Compatible scored attempts.</p>
      </article>
      <article class="metric-card">
        <span>Generated</span>
        <strong>{formatDate(leaderboard.generatedAt)}</strong>
        <p>Timestamp shown in UTC.</p>
      </article>
      <article class="metric-card">
        <span>Data policy</span>
        <strong>{leaderboard.benchmark.dataPolicy}</strong>
        <p>Aggregate-compatible by default.</p>
      </article>
      <article class="metric-card">
        <span>Top pass rate</span>
        <strong>{topModel ? formatPercent(topModel.passRate) : 'unknown'}</strong>
        <p>{topModel ? formatModelName(topModel.providerId, topModel.modelId) : 'No model rows yet.'}</p>
      </article>
      <article class="metric-card">
        <span>Lowest solved cost</span>
        <strong>{formatCost(bestCost)}</strong>
        <p>Among rows with known solved-task cost.</p>
      </article>
      <article class="metric-card">
        <span>Top latency</span>
        <strong>{topModel ? formatDuration(topModel.medianLatencyMs) : 'unknown'}</strong>
        <p>Median latency for the top ranked row.</p>
      </article>
    </div>
  </section>

  <section class="section" aria-labelledby="chart-title">
    <div class="section-heading">
      <div>
        <p class="eyebrow">Pass rate vs efficiency</p>
        <h2 id="chart-title">Performance with context</h2>
      </div>
      <p>
        Dots compare pass rate against known {metricLabel(chartMode)}. Sample sizes
        are shown separately; this first-pass view does not imply precision beyond
        the exported rows.
      </p>
    </div>

    <div class="chart-card">
      <div class="chart-legend">
        <span class="dot-key">Model row</span>
        <span>Y-axis: pass rate · X-axis: {metricLabel(chartMode)}</span>
      </div>

      {#if chartRows.length > 0}
        <svg
          class="chart"
          viewBox="0 0 640 340"
          role="img"
          aria-labelledby="chart-svg-title chart-svg-desc"
        >
          <title id="chart-svg-title">Model pass rate compared with {metricLabel(chartMode)}</title>
          <desc id="chart-svg-desc">
            Each point represents a model row with a known pass rate and known
            {metricLabel(chartMode)}. Lower x values are more efficient.
          </desc>
          <line x1="72" y1="282" x2="588" y2="282" stroke="rgba(24,21,17,0.24)" />
          <line x1="72" y1="48" x2="72" y2="282" stroke="rgba(24,21,17,0.24)" />
          <text class="axis-label" x="72" y="314">lower {chartMode}</text>
          <text class="axis-label" x="500" y="314">higher {chartMode}</text>
          <text class="axis-label" x="18" y="58">100%</text>
          <text class="axis-label" x="24" y="286">0%</text>
          {#each [0.25, 0.5, 0.75] as guide}
            <line
              x1="72"
              y1={282 - guide * 218}
              x2="588"
              y2={282 - guide * 218}
              stroke="rgba(24,21,17,0.09)"
            />
          {/each}
          {#each chartRows as row}
            <g>
              <circle
                cx={row.x}
                cy={row.y}
                r={row.model.lowSample ? 8 : 10}
                fill="var(--accent)"
                stroke="#181511"
                stroke-width="2"
              />
              <text class="point-label" x={Math.min(row.x + 12, 486)} y={row.y - 10}>
                {row.model.providerId}
              </text>
            </g>
          {/each}
        </svg>

        <ul class="fallback-list" aria-label="Chart data summary">
          {#each chartRows as row}
            <li>
              <strong>{formatModelName(row.model.providerId, row.model.modelId)}</strong>:
              {formatPercent(row.model.passRate)} pass rate,
              {formatChartMetric(row.metric, chartMode)} {metricLabel(chartMode)},
              {formatCount(row.model.sampleCount)} samples.
            </li>
          {/each}
        </ul>
      {:else}
        <p class="empty">
          No model rows include both pass rate and {metricLabel(chartMode)} yet.
        </p>
      {/if}
    </div>
  </section>

  <section class="section" id="leaderboard" aria-labelledby="leaderboard-title">
    <div class="section-heading">
      <div>
        <p class="eyebrow">Ranked model table</p>
        <h2 id="leaderboard-title">Leaderboard</h2>
      </div>
      <p>
        Rows are ordered by exported rank when available. Low-sample rows are
        labeled so early previews are not mistaken for stable conclusions.
      </p>
    </div>

    {#if rankedModels.length > 0}
      <div class="table-wrap">
        <table>
          <caption>
            Model quality and efficiency metrics from the static leaderboard export.
          </caption>
          <thead>
            <tr>
              <th scope="col">Rank</th>
              <th scope="col">Model</th>
              <th scope="col">Pass rate</th>
              <th scope="col">Public / hidden</th>
              <th scope="col">Confidence</th>
              <th scope="col">Samples</th>
              <th scope="col">Latency</th>
              <th scope="col">Median cost</th>
              <th scope="col">Cost / solved</th>
            </tr>
          </thead>
          <tbody>
            {#each rankedModels as model, index}
              <tr>
                <td class="rank">{model.rank ?? index + 1}</td>
                <td>
                  <span class="model-name">{formatModelName(model.providerId, model.modelId)}</span>
                  {#if model.lowSample}
                    <span class="flag">low sample</span>
                  {/if}
                </td>
                <td>
                  {formatPercent(model.passRate)}
                  <span class="sub-metric">{formatCount(model.passCount)} passed</span>
                </td>
                <td>
                  {formatPercent(model.publicPassRate)} public
                  <span class="sub-metric">{formatPercent(model.hiddenPassRate)} hidden</span>
                </td>
                <td>{formatConfidence(model)}</td>
                <td>
                  {formatCount(model.sampleCount)}
                  <span class="sub-metric">
                    {formatTokens(model.medianPromptTokens)} in · {formatTokens(model.medianCompletionTokens)} out
                  </span>
                </td>
                <td>{formatDuration(model.medianLatencyMs)}</td>
                <td>{formatCost(model.medianEstimatedCostMicros)}</td>
                <td>{formatCost(model.costPerSolvedTaskMicros)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {:else}
      <p class="empty">No model rows are available yet.</p>
    {/if}
  </section>

  <section class="section" id="tasks" aria-labelledby="tasks-title">
    <div class="section-heading">
      <div>
        <p class="eyebrow">Task examples</p>
        <h2 id="tasks-title">What the benchmark runs</h2>
      </div>
      <p>
        Example task rows show the exported track, version, pass rate, model count,
        and sample count without exposing prompts, hidden verifiers, responses, or
        local paths.
      </p>
    </div>

    {#if taskExamples.length > 0}
      <div class="task-grid">
        {#each taskExamples as task}
          <article class="card">
            <span class="data-label">{task.benchmarkTrack ?? leaderboard.benchmark.track}</span>
            <h3>{task.taskId}</h3>
            <ul class="task-meta">
              <li><span>Version</span><strong>{task.taskVersion ?? 'unknown'}</strong></li>
              <li><span>Pass rate</span><strong>{formatPercent(task.passRate)}</strong></li>
              <li><span>Public</span><strong>{formatPercent(task.publicPassRate)}</strong></li>
              <li><span>Hidden</span><strong>{formatPercent(task.hiddenPassRate)}</strong></li>
              <li><span>Models</span><strong>{formatCount(task.modelCount)}</strong></li>
              <li><span>Samples</span><strong>{formatCount(task.sampleCount)}</strong></li>
            </ul>
          </article>
        {/each}
      </div>
    {:else}
      <p class="empty">No task rows are available yet.</p>
    {/if}
  </section>

  <section class="section" id="methodology" aria-labelledby="methodology-title">
    <div class="section-heading">
      <div>
        <p class="eyebrow">Methodology and provenance</p>
        <h2 id="methodology-title">How to read the export</h2>
      </div>
    </div>

    <div class="method-grid">
      <article class="card method-copy">
        <p>
          The public leaderboard uses <strong>aggregate-compatible</strong>
          data: compatible task runs for the selected benchmark track are aggregated
          into a versioned <strong>leaderboard.v1.json</strong> static export.
          The Svelte page reads that JSON directly, so the Dart/Flutter runner and
          exporter remain the source of truth.
        </p>
        <p>
          <strong>Best-observed</strong> is not the public default because selecting
          only each model's best attempt can look cherry-picked. Rows keep sample
          counts, confidence intervals, and low-sample labels to make preview data
          easier to interpret.
        </p>
      </article>

      <aside class="card" aria-label="Source provenance">
        <span class="data-label">Source</span>
        <ul class="provenance-list">
          <li><span>Run count</span><strong>{formatCount(leaderboard.source.runIds.length)}</strong></li>
          <li><span>Anchor run</span><strong>{leaderboard.source.anchorRunId ?? 'unknown'}</strong></li>
          <li><span>Task runs</span><strong>{formatCount(leaderboard.source.taskRunCount)}</strong></li>
          <li><span>Schema</span><strong>leaderboard.v{leaderboard.schemaVersion}</strong></li>
        </ul>

        {#if provenanceWarnings.length > 0}
          {#each provenanceWarnings as warning}
            <p class="source-warning">{warning}</p>
          {/each}
        {:else}
          <p class="muted">No source warnings in this export.</p>
        {/if}
      </aside>
    </div>
  </section>

  <footer class="site-footer">
    <div class="footer-brand">
      <img src={pickforgeMarkSrc} alt="" width="32" height="32" />
      <strong>Pickforge</strong>
    </div>
    <span>Dart Arena static data · leaderboard.v{leaderboard.schemaVersion}</span>
  </footer>
</main>
