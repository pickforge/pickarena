<script lang="ts">
  import PassRate from '$lib/components/PassRate.svelte';
  import {
    countText,
    durationText,
    modelName,
    percentText,
    providerName,
    tokensText
  } from '$lib/data/format';
  import type {
    LeaderboardModel,
    LeaderboardTask,
    LeaderboardTaskModelCell,
    LeaderboardTrialSummary
  } from '$lib/data/leaderboard';
  import type { PageData } from './$types';

  let { data }: { data: PageData } = $props();
  let board = $derived(data.leaderboard);

  let tasks = $derived(sortTasks(board.tasks));
  let models = $derived(sortModels(board.models));
  let cellMap = $derived(buildCellMap(board.taskModelCells));
  let trials = $derived([...board.trialSummaries].slice(0, 24));
  let hasMatrix = $derived(
    models.length > 0 && tasks.length > 0 && board.taskModelCells.length > 0
  );

  function sortTasks(input: LeaderboardTask[]): LeaderboardTask[] {
    return [...input].sort((a, b) => a.taskId.localeCompare(b.taskId));
  }

  function sortModels(input: LeaderboardModel[]): LeaderboardModel[] {
    return [...input].sort((a, b) => (a.rank ?? 99) - (b.rank ?? 99));
  }

  function category(taskId: string): string {
    return taskId.split('.')[0] || 'task';
  }

  function shortName(taskId: string): string {
    const parts = taskId.split('.');
    return parts.length > 1 ? parts.slice(1).join('.') : taskId;
  }

  const SEP = '';

  function cellKey(
    providerId: string,
    modelId: string,
    taskId: string,
    version: number | string | null
  ): string {
    return [providerId, modelId, taskId, version ?? 'v?'].join(SEP);
  }

  function buildCellMap(
    cells: LeaderboardTaskModelCell[]
  ): Map<string, LeaderboardTaskModelCell> {
    return new Map(
      cells.map((cell) => [
        cellKey(cell.providerId, cell.modelId, cell.taskId, cell.taskVersion),
        cell
      ])
    );
  }

  function lookup(
    model: LeaderboardModel,
    task: LeaderboardTask,
    map: Map<string, LeaderboardTaskModelCell>
  ): LeaderboardTaskModelCell | null {
    return map.get(cellKey(model.providerId, model.modelId, task.taskId, task.taskVersion)) ?? null;
  }

  function tone(cell: LeaderboardTaskModelCell | null): string {
    if (!cell || cell.sampleCount === 0 || cell.passRate === null) return 'unknown';
    if (cell.blockedTaskRunCount > 0) return 'blocked';
    if (cell.passRate >= 0.85) return 'strong';
    if (cell.passRate >= 0.5) return 'mixed';
    return 'weak';
  }

  function outcomeTone(trial: LeaderboardTrialSummary): string {
    if (trial.blockedEvaluationCount > 0) return 'blocked';
    if (trial.primaryPass === true) return 'pass';
    if (trial.primaryPass === false) return 'fail';
    return 'unknown';
  }

  function outcomeLabel(trial: LeaderboardTrialSummary): string {
    if (trial.blockedEvaluationCount > 0) return 'blocked';
    if (trial.primaryPass === true) return 'pass';
    if (trial.primaryPass === false) return 'fail';
    return 'unknown';
  }
</script>

<svelte:head>
  <title>Task corpus · PickArena by Pickforge Studio</title>
  <meta
    name="description"
    content="Browse the PickArena Flutter task corpus: categories, versions, pass rates, the per-task model matrix, and sanitized public attempts."
  />
</svelte:head>

<section class="hero" aria-labelledby="tasks-title" style="padding-bottom:1rem;">
  <p class="eyebrow">Task corpus</p>
  <h1 id="tasks-title">What the benchmark runs.</h1>
  <p class="lede">
    Each task is a real Flutter engineering problem with a human-style prompt, a failing
    baseline, and hidden behavioral verifiers. Prompts, hidden tests, reference solutions,
    and local paths are never published — only the aggregate outcomes below.
  </p>
</section>

<section class="section" id="tasks" aria-labelledby="catalog-title" style="padding-top:1rem;">
  <div class="section-head">
    <p class="eyebrow">{countText(board.source.taskCount)} tasks</p>
    <h2 id="catalog-title">Corpus</h2>
    <p>Sorted by id. Pass rates carry their Wilson 95% interval and sample size.</p>
  </div>

  {#if tasks.length > 0}
    <div class="task-grid">
      {#each tasks as task}
        <article class="card task-card">
          <div class="task-top">
            <span class="category">{category(task.taskId)}</span>
            <span class="flag neutral">v{task.taskVersion ?? '?'} · {task.benchmarkTrack ?? board.benchmark.track}</span>
          </div>
          <h3>{shortName(task.taskId)}</h3>
          <PassRate rate={task.passRate} ci={task.confidenceInterval} sample={task.sampleCount} />
          <ul class="task-meta">
            <li><span>Public</span><strong>{percentText(task.publicPassRate)}</strong></li>
            <li><span>Hidden</span><strong>{percentText(task.hiddenPassRate)}</strong></li>
            <li><span>Models</span><strong>{countText(task.modelCount)}</strong></li>
            <li><span>Blocked</span><strong>{countText(task.blockedTaskRunCount)}</strong></li>
          </ul>
        </article>
      {/each}
    </div>
  {:else}
    <p class="empty">No task rows are available yet.</p>
  {/if}
</section>

{#if hasMatrix}
  <section class="section" id="matrix" aria-labelledby="matrix-title">
    <div class="section-head">
      <p class="eyebrow">Task × model</p>
      <h2 id="matrix-title">Per-task outcomes</h2>
      <p>
        Each cell is an aggregate of a model on a task: pass rate and pass/sample count.
        Cells never expose prompts, responses, or hidden verifier output.
      </p>
    </div>

    <div class="matrix-wrap">
      <div
        class="matrix-grid"
        style={`grid-template-columns: minmax(150px, 1fr) repeat(${tasks.length}, minmax(120px, 1fr));`}
      >
        <div class="matrix-corner">Model \\ Task</div>
        {#each tasks as task}
          <div class="matrix-col">
            <strong>{category(task.taskId)}</strong>
            <span>{shortName(task.taskId)}</span>
          </div>
        {/each}

        {#each models as model}
          <div class="matrix-row">
            <strong>{modelName(model)}</strong>
            <span>{providerName(model)} · n {model.sampleCount}</span>
          </div>
          {#each tasks as task}
            {@const cell = lookup(model, task, cellMap)}
            <div class={`matrix-cell ${tone(cell)}`}>
              {#if cell && cell.passRate !== null}
                <strong>{percentText(cell.passRate)}</strong>
                <span>{cell.passCount}/{cell.sampleCount}</span>
              {:else}
                <strong>—</strong>
                <span>no sample</span>
              {/if}
            </div>
          {/each}
        {/each}
      </div>
    </div>

    <div class="legend">
      <span class="sr-only">Cell background encodes pass rate:</span>
      <span class="swatch strong">≥ 85%</span>
      <span class="swatch mixed">50–85%</span>
      <span class="swatch weak">&lt; 50%</span>
      <span class="swatch blocked">blocked</span>
    </div>
  </section>
{/if}

{#if trials.length > 0}
  <section class="section" id="attempts" aria-labelledby="attempts-title">
    <div class="section-head">
      <p class="eyebrow">Public attempts</p>
      <h2 id="attempts-title">Recent trials</h2>
      <p>
        Sanitized per-trial rows: outcome, task, latency, and tokens, with raw responses,
        patches, and verifier logs omitted.
      </p>
    </div>

    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th scope="col">Task</th>
            <th scope="col">Model</th>
            <th scope="col">Outcome</th>
            <th scope="col" class="num">Public / hidden</th>
            <th scope="col" class="num">Latency</th>
            <th scope="col" class="num">Output tokens</th>
          </tr>
        </thead>
        <tbody>
          {#each trials as trial}
            <tr>
              <td class="model-cell">
                <span class="model-name" style="font-family:var(--mono);font-size:0.9rem;">{trial.taskId}</span>
                <span class="model-provider">v{trial.taskVersion ?? '?'} · trial {trial.trialIndex + 1}</span>
              </td>
              <td>{modelName(trial)}</td>
              <td>
                <span class={`pill ${outcomeTone(trial)}`}>{outcomeLabel(trial)}</span>
                {#if trial.failureTag && trial.failureTag !== 'pass'}
                  <span class="model-provider">{trial.failureTag}</span>
                {/if}
              </td>
              <td class="num">
                <span class="split">
                  <span>{trial.publicPassed === null ? '—' : trial.publicPassed ? 'pass' : 'fail'}</span>
                  <span class="divider">/</span>
                  <span class="hidden">{trial.hiddenPassed === null ? '—' : trial.hiddenPassed ? 'pass' : 'fail'}</span>
                </span>
              </td>
              <td class="num">{durationText(trial.latencyMs)}</td>
              <td class="num">{tokensText(trial.completionTokens)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </section>
{/if}
