<script lang="ts">
  import type { PageData } from './$types';

  let { data }: { data: PageData } = $props();

  let leaderboard = $derived(data.leaderboard);
  let topModels = $derived(leaderboard.models.slice(0, 3));
</script>

<main class="shell">
  <header class="brand">
    <img src="/branding/pickforge_mark.png" alt="" width="44" height="44" />
    <span>Dart Arena by Pickforge</span>
  </header>

  <section class="panel">
    <img
      class="logo"
      src="/branding/dart_arena_logo_horizontal_dark.png"
      alt="Dart Arena"
    />
    <p class="eyebrow">SvelteKit static scaffold</p>
    <h1>{leaderboard.benchmark.title}</h1>
    <p class="intro">
      Static leaderboard data is loaded from
      <code>/data/leaderboard.v1.json</code>.
    </p>

    {#if data.warning}
      <p class="warning" role="alert">{data.warning}</p>
    {/if}
  </section>

  <section class="cards" aria-label="Leaderboard summary">
    <article>
      <span>Track</span>
      <strong>{leaderboard.benchmark.track}</strong>
    </article>
    <article>
      <span>Data policy</span>
      <strong>{leaderboard.benchmark.dataPolicy}</strong>
    </article>
    <article>
      <span>Tasks</span>
      <strong>{leaderboard.source.taskCount}</strong>
    </article>
    <article>
      <span>Task runs</span>
      <strong>{leaderboard.source.taskRunCount}</strong>
    </article>
  </section>

  <section class="panel">
    <h2>Sample model rows</h2>
    {#if topModels.length > 0}
      <ul class="models">
        {#each topModels as model}
          <li>
            <span>{model.providerId ?? 'provider'} / {model.modelId ?? 'model'}</span>
            <strong>{model.sampleCount ?? 0} samples</strong>
          </li>
        {/each}
      </ul>
    {:else}
      <p>No model rows are available yet.</p>
    {/if}
  </section>
</main>

<style>
  .shell {
    box-sizing: border-box;
    display: grid;
    gap: 1.5rem;
    margin: 0 auto;
    max-width: 960px;
    min-height: 100vh;
    padding: 2rem;
  }

  .brand {
    align-items: center;
    display: flex;
    font-weight: 800;
    gap: 0.75rem;
    letter-spacing: -0.02em;
  }

  .panel,
  .cards article {
    background: #ffffff;
    border: 1px solid rgba(24, 21, 17, 0.12);
    border-radius: 24px;
    box-shadow: 0 20px 60px rgba(24, 21, 17, 0.08);
    padding: 1.5rem;
  }

  .logo {
    display: block;
    height: auto;
    max-width: min(420px, 100%);
  }

  .eyebrow {
    color: #f36b21;
    font-size: 0.8rem;
    font-weight: 800;
    letter-spacing: 0.12em;
    margin: 1.5rem 0 0.5rem;
    text-transform: uppercase;
  }

  h1,
  h2,
  p {
    margin-top: 0;
  }

  h1 {
    font-size: clamp(2.25rem, 7vw, 4.75rem);
    letter-spacing: -0.06em;
    line-height: 0.95;
    margin-bottom: 1rem;
  }

  .intro {
    color: rgba(24, 21, 17, 0.72);
    font-size: 1.1rem;
    line-height: 1.6;
    margin-bottom: 0;
  }

  code {
    background: #fff1df;
    border-radius: 0.4rem;
    padding: 0.1rem 0.3rem;
  }

  .warning {
    background: #fff4d6;
    border: 1px solid #f6c453;
    border-radius: 0.75rem;
    margin: 1rem 0 0;
    padding: 0.75rem 1rem;
  }

  .cards {
    display: grid;
    gap: 1rem;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  }

  .cards span {
    color: rgba(24, 21, 17, 0.62);
    display: block;
    font-size: 0.85rem;
    font-weight: 700;
    margin-bottom: 0.5rem;
    text-transform: uppercase;
  }

  .cards strong {
    display: block;
    font-size: 1.6rem;
    letter-spacing: -0.04em;
  }

  .models {
    display: grid;
    gap: 0.75rem;
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .models li {
    align-items: center;
    border-top: 1px solid rgba(24, 21, 17, 0.12);
    display: flex;
    gap: 1rem;
    justify-content: space-between;
    padding-top: 0.75rem;
  }
</style>
