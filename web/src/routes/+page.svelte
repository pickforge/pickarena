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
  import type {
    LeaderboardConfidenceInterval,
    LeaderboardModel,
    LeaderboardPassAtK,
    LeaderboardTask,
    LeaderboardTaskModelCell,
    LeaderboardTrialSummary
  } from '$lib/data/leaderboard';
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
  const pickArenaLogoSrc = `${base}/branding/pickarena-lockup-horizontal.png`;

  let leaderboard = $derived(data.leaderboard);
  let rankedModels = $derived(sortModels(leaderboard.models));
  let taskExamples = $derived(sortTasks(leaderboard.tasks).slice(0, 6));
  let heatmapModels = $derived(rankedModels.slice(0, 8));
  let heatmapTasks = $derived(sortTasks(leaderboard.tasks).slice(0, 8));
  let heatmapCells = $derived(buildHeatmapCellMap(leaderboard.taskModelCells));
  let trialSummaries = $derived(leaderboard.trialSummaries.slice(0, 16));
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
  let provenanceWarnings = $derived(
    uniqueWarnings([
      ...leaderboard.source.warnings,
      ...leaderboard.source.runProvenance.warnings
    ])
  );

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

  function buildHeatmapCellMap(
    cells: LeaderboardTaskModelCell[]
  ): Map<string, LeaderboardTaskModelCell> {
    return new Map(
      cells.map((cell) => [
        heatmapKey(
          cell.providerId,
          cell.modelId,
          cell.taskId,
          cell.taskVersion,
          cell.benchmarkTrack
        ),
        cell
      ])
    );
  }

  function heatmapKey(
    providerId: string,
    modelId: string,
    taskId: string,
    taskVersion: number | string | null,
    benchmarkTrack: string | null
  ): string {
    return [
      providerId,
      modelId,
      taskId,
      taskVersion ?? 'unknown-version',
      benchmarkTrack ?? 'unknown-track'
    ].join('\u001f');
  }

  function taskCell(
    model: LeaderboardModel,
    task: LeaderboardTask,
    cells: Map<string, LeaderboardTaskModelCell>
  ): LeaderboardTaskModelCell | null {
    return (
      cells.get(
        heatmapKey(
          model.providerId,
          model.modelId,
          task.taskId,
          task.taskVersion,
          task.benchmarkTrack
        )
      ) ?? null
    );
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

  function formatConfidence(interval: LeaderboardConfidenceInterval): string {
    const { lower, upper } = interval;
    if (lower === null || upper === null) return 'unknown';

    return `${formatPercent(lower)}–${formatPercent(upper)}`;
  }

  function metricLabel(mode: ChartMode): string {
    return mode === 'cost' ? 'cost per solved task' : 'median latency';
  }

  function formatChartMetric(value: number, mode: ChartMode): string {
    return mode === 'cost' ? formatCost(value) : formatDuration(value);
  }

  function heatmapTone(cell: LeaderboardTaskModelCell | null): string {
    if (!cell || cell.sampleCount === 0 || cell.passRate === null) return 'unknown';
    if (cell.blockedTaskRunCount > 0) return 'blocked';
    if (cell.passRate >= 0.85) return 'strong';
    if (cell.passRate >= 0.5) return 'mixed';
    return 'weak';
  }

  function taskShortLabel(taskId: string): string {
    const segments = taskId.split('.');
    return segments.length > 1 ? segments.slice(-2).join('.') : taskId;
  }

  function formatCoverage(count: number, total: number): string {
    return `${formatCount(count)}/${formatCount(total)}`;
  }

  function formatEnvironmentIds(ids: string[]): string {
    if (ids.length === 0) return 'unknown';
    if (ids.length === 1) return ids[0];
    return `${formatCount(ids.length)} ids`;
  }

  function formatIdCount(ids: string[]): string {
    if (ids.length === 0) return 'unknown';
    return `${formatCount(ids.length)} ids`;
  }

  function formatPassAtK(passAtK: LeaderboardPassAtK, preferredK = 2): string {
    const preferred = passAtK[String(preferredK)];
    const fallback = passAtK['1'] ?? Object.values(passAtK)[0] ?? null;
    const entry = preferred ?? fallback;
    if (!entry) return 'unknown';

    return `P@${entry.k} ${formatPercent(entry.passRate)}`;
  }

  function formatUnknownCost(count: number): string | null {
    if (count <= 0) return null;
    return `${formatCount(count)} unknown cost`;
  }

  function formatContext(value: number | null): string {
    return `${formatTokens(value)} ctx`;
  }

  function formatOutcome(value: boolean | null): string {
    if (value === true) return 'pass';
    if (value === false) return 'fail';
    return 'unknown';
  }

  function outcomeTone(trial: LeaderboardTrialSummary): string {
    if (trial.blockedEvaluationCount > 0) return 'blocked';
    if (trial.primaryPass === true) return 'pass';
    if (trial.primaryPass === false) return 'fail';
    return 'unknown';
  }

  function shortTrialId(id: string): string {
    return id.length > 12 ? id.slice(0, 12) : id;
  }

  function formatScore(value: number | null): string {
    return value === null ? 'unknown' : value.toFixed(2);
  }
</script>

<main class="shell">
  <header class="site-header">
    <a class="brand-lockup" href={homeHref} aria-label="PickArena by Pickforge Studio home">
      <img src={pickforgeMarkSrc} alt="" width="44" height="44" />
      <span>PickArena by Pickforge Studio</span>
    </a>
    <nav class="nav-links" aria-label="Page sections">
      <a href="#leaderboard">Leaderboard</a>
      <a href="#matrix">Matrix</a>
      <a href="#trials">Trials</a>
      <a href="#tasks">Tasks</a>
      <a href="#methodology">Methodology</a>
    </nav>
  </header>

  <section class="hero" aria-labelledby="hero-title">
    <div class="hero-content">
      <img
        class="hero-logo"
        src={pickArenaLogoSrc}
        alt="PickArena"
      />
      <p class="eyebrow">Static public benchmark</p>
      <h1 id="hero-title">Benchmark AI coding models on Dart and Flutter engineering tasks.</h1>
      <p class="lede">
        PickArena uses a Dart/Flutter runner to execute coding tasks, aggregate
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
        <span>Trials shown</span>
        <strong>{formatCount(leaderboard.source.trialSummaryCount)}</strong>
        <p>{leaderboard.source.trialSummaryTruncated ? 'Truncated public summary.' : 'Sanitized public attempts.'}</p>
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
          <line x1="72" y1="282" x2="588" y2="282" stroke="rgba(242,242,243,0.24)" />
          <line x1="72" y1="48" x2="72" y2="282" stroke="rgba(242,242,243,0.24)" />
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
              stroke="rgba(242,242,243,0.09)"
            />
          {/each}
          {#each chartRows as row}
            <g>
              <circle
                cx={row.x}
                cy={row.y}
                r={row.model.lowSample ? 8 : 10}
                fill="var(--accent)"
                stroke="#0a0a0b"
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
              <th scope="col">Pass@k</th>
              <th scope="col">Public / hidden</th>
              <th scope="col">Blocked</th>
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
                  {#if model.unknownEstimatedCostCount > 0}
                    <span class="flag">unknown cost</span>
                  {/if}
                </td>
                <td>
                  {formatPercent(model.passRate)}
                  <span class="sub-metric">{formatCount(model.passCount)} passed</span>
                </td>
                <td>
                  {formatPassAtK(model.passAtK)}
                  <span class="sub-metric">
                    {formatCount(model.medianStepCount)} steps · {formatContext(model.medianPeakContextTokens)}
                  </span>
                </td>
                <td>
                  {formatPercent(model.publicPassRate)} public
                  <span class="sub-metric">{formatPercent(model.hiddenPassRate)} hidden</span>
                </td>
                <td>
                  {formatCount(model.blockedTaskRunCount)} runs
                  <span class="sub-metric">{formatCount(model.blockedEvaluationCount)} checks</span>
                </td>
                <td>{formatConfidence(model.confidenceInterval)}</td>
                <td>
                  {formatCount(model.sampleCount)}
                  <span class="sub-metric">
                    {formatTokens(model.medianPromptTokens)} in · {formatTokens(model.medianCompletionTokens)} out
                  </span>
                </td>
                <td>{formatDuration(model.medianLatencyMs)}</td>
                <td>
                  {formatCost(model.medianEstimatedCostMicros)}
                  {#if formatUnknownCost(model.unknownEstimatedCostCount)}
                    <span class="sub-metric">{formatUnknownCost(model.unknownEstimatedCostCount)}</span>
                  {/if}
                </td>
                <td>
                  {formatCost(model.costPerSolvedTaskMicros)}
                  {#if model.unknownEstimatedCostCount > 0}
                    <span class="sub-metric">excluded from cost ranking</span>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {:else}
      <p class="empty">No model rows are available yet.</p>
    {/if}
  </section>

  <section class="section" id="matrix" aria-labelledby="heatmap-title">
    <div class="section-heading">
      <div>
        <p class="eyebrow">Task matrix</p>
        <h2 id="heatmap-title">Model performance by task</h2>
      </div>
      <p>
        Aggregate cells keep per-task outcomes visible without publishing prompts,
        raw responses, hidden verifier output, or machine-local paths.
      </p>
    </div>

    {#if heatmapModels.length > 0 && heatmapTasks.length > 0 && leaderboard.taskModelCells.length > 0}
      <div class="heatmap-wrap">
        <div
          class="heatmap-grid"
          style={`grid-template-columns: minmax(180px, 1.3fr) repeat(${heatmapTasks.length}, minmax(118px, 1fr));`}
        >
          <div class="heatmap-corner">Model</div>
          {#each heatmapTasks as task}
            <div class="heatmap-task">
              <strong>{taskShortLabel(task.taskId)}</strong>
              <span>v{task.taskVersion ?? 'unknown'}</span>
            </div>
          {/each}

          {#each heatmapModels as model}
            <div class="heatmap-model">
              <strong>{formatModelName(model.providerId, model.modelId)}</strong>
              <span>{formatCount(model.sampleCount)} samples</span>
            </div>
            {#each heatmapTasks as task}
              {@const cell = taskCell(model, task, heatmapCells)}
              <div class={`heatmap-cell ${heatmapTone(cell)}`}>
                {#if cell}
                  <strong>{formatPercent(cell.passRate)}</strong>
                  <span>{formatCount(cell.passCount)}/{formatCount(cell.sampleCount)}</span>
                  <small>
                    CI {formatConfidence(cell.confidenceInterval)} ·
                    {formatCount(cell.errorCount)} errors ·
                    {formatCount(cell.medianStepCount)} steps ·
                    {formatContext(cell.medianPeakContextTokens)}
                    {#if formatUnknownCost(cell.unknownEstimatedCostCount)}
                      · {formatUnknownCost(cell.unknownEstimatedCostCount)}
                    {:else}
                      · {formatCost(cell.medianEstimatedCostMicros)}
                    {/if}
                  </small>
                {:else}
                  <strong>—</strong>
                  <span>no sample</span>
                  <small>not exported</small>
                {/if}
              </div>
            {/each}
          {/each}
        </div>
      </div>
    {:else}
      <p class="empty">No task-model cells are available yet.</p>
    {/if}
  </section>

  <section class="section" id="trials" aria-labelledby="trials-title">
    <div class="section-heading">
      <div>
        <p class="eyebrow">Trial browser</p>
        <h2 id="trials-title">Public attempts</h2>
      </div>
      <p>
        Trial rows expose outcome, task, model, latency, tokens, and cost while
        omitting raw responses, patches, verifier logs, and local paths.
      </p>
    </div>

    {#if leaderboard.source.trialSummaryTruncated}
      <p class="warning" role="alert">
        Trial summaries are truncated at {formatCount(leaderboard.source.trialSummaryLimit)} rows.
      </p>
    {/if}

    {#if trialSummaries.length > 0}
      <div class="table-wrap">
        <table class="trial-table">
          <caption>
            Sanitized per-trial data from leaderboard.v{leaderboard.schemaVersion}.
          </caption>
          <thead>
            <tr>
              <th scope="col">Trial</th>
              <th scope="col">Model</th>
              <th scope="col">Task</th>
              <th scope="col">Outcome</th>
              <th scope="col">Public / hidden</th>
              <th scope="col">Steps / context</th>
              <th scope="col">Duration</th>
              <th scope="col">Tokens</th>
              <th scope="col">Cost</th>
            </tr>
          </thead>
          <tbody>
            {#each trialSummaries as trial}
              <tr>
                <td>
                  <span class="model-name">{shortTrialId(trial.trialId)}</span>
                  <span class="sub-metric">trial {formatCount(trial.trialIndex + 1)} · score {formatScore(trial.aggregateScore)}</span>
                </td>
                <td>{formatModelName(trial.providerId, trial.modelId)}</td>
                <td>
                  {trial.taskId}
                  <span class="sub-metric">v{trial.taskVersion ?? 'unknown'} · {trial.benchmarkTrack ?? leaderboard.benchmark.track}</span>
                </td>
                <td>
                  <span class={`result-pill ${outcomeTone(trial)}`}>{formatOutcome(trial.primaryPass)}</span>
                  <span class="sub-metric">{trial.failureTag}</span>
                </td>
                <td>
                  {formatOutcome(trial.publicPassed)} public
                  <span class="sub-metric">
                    {formatOutcome(trial.hiddenPassed)} hidden · {formatCount(trial.blockedEvaluationCount)} blocked
                  </span>
                </td>
                <td>
                  {formatCount(trial.stepCount)} steps
                  <span class="sub-metric">{formatContext(trial.peakContextTokens)}</span>
                </td>
                <td>{formatDuration(trial.latencyMs)}</td>
                <td>
                  {formatTokens(trial.promptTokens)} in
                  <span class="sub-metric">{formatTokens(trial.completionTokens)} out</span>
                </td>
                <td>
                  {formatCost(trial.estimatedCostMicros)}
                  {#if trial.estimatedCostMicros === null}
                    <span class="sub-metric">unknown cost</span>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {:else}
      <p class="empty">No trial summaries are available yet.</p>
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
              <li><span>Confidence</span><strong>{formatConfidence(task.confidenceInterval)}</strong></li>
              <li><span>Public</span><strong>{formatPercent(task.publicPassRate)}</strong></li>
              <li><span>Hidden</span><strong>{formatPercent(task.hiddenPassRate)}</strong></li>
              <li><span>Steps</span><strong>{formatCount(task.medianStepCount)}</strong></li>
              <li><span>Context</span><strong>{formatContext(task.medianPeakContextTokens)}</strong></li>
              <li><span>Blocked</span><strong>{formatCount(task.blockedTaskRunCount)}</strong></li>
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
          <li><span>Run provenance</span><strong>{formatCoverage(leaderboard.source.runProvenance.embeddedRunCount, leaderboard.source.runProvenance.runCount)}</strong></li>
          <li><span>Sandbox</span><strong>{formatCoverage(leaderboard.source.runProvenance.sandboxEnforcedRunCount, leaderboard.source.runProvenance.runCount)}</strong></li>
          <li><span>Network policy</span><strong>{formatCoverage(leaderboard.source.runProvenance.networkDisabledTaskPolicyRunCount, leaderboard.source.runProvenance.runCount)}</strong></li>
          <li><span>Task resources</span><strong>{formatCoverage(leaderboard.source.runProvenance.taskResourceLimitRunCount, leaderboard.source.runProvenance.runCount)}</strong></li>
          <li><span>SDK</span><strong>{formatCoverage(leaderboard.source.runProvenance.sdkVersionRunCount, leaderboard.source.runProvenance.runCount)}</strong></li>
          <li><span>Dependencies</span><strong>{formatCoverage(leaderboard.source.runProvenance.dependencySnapshotRunCount, leaderboard.source.runProvenance.runCount)}</strong></li>
          <li><span>Environment</span><strong>{formatEnvironmentIds(leaderboard.source.runProvenance.environmentIds)}</strong></li>
          <li><span>Judge cost</span><strong>{formatCost(leaderboard.source.judgeOverhead.totalEstimatedCostMicros)}</strong></li>
          <li><span>Primary metric</span><strong>{leaderboard.scoring.primaryMetric ?? 'unknown'}</strong></li>
          <li><span>Ranking</span><strong>{leaderboard.scoring.rankingMetric ?? 'unknown'}</strong></li>
          <li><span>CI method</span><strong>{leaderboard.scoring.confidenceInterval ?? 'unknown'}</strong></li>
          <li><span>Benchmark</span><strong>{leaderboard.benchmark.version ?? 'unknown'}</strong></li>
          <li><span>Task set</span><strong>{leaderboard.benchmark.taskSetId ?? 'unknown'}</strong></li>
          <li><span>Evaluators</span><strong>v{leaderboard.benchmark.evaluatorSchemaVersion || 'unknown'}</strong></li>
          <li><span>Objective gates</span><strong>{formatIdCount(leaderboard.scoring.objectiveEvaluatorIds)}</strong></li>
          <li><span>LLM judge</span><strong>{leaderboard.scoring.llmJudgePolicy ?? 'unknown'}</strong></li>
          <li><span>Pricing</span><strong>{leaderboard.pricingRegistry.version ?? 'unknown'}</strong></li>
          <li><span>Currency</span><strong>{leaderboard.pricingRegistry.currency ?? 'unknown'}</strong></li>
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
      <strong>Pickforge Studio</strong>
    </div>
    <span>PickArena static data · leaderboard.v{leaderboard.schemaVersion}</span>
  </footer>
</main>
