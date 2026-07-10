<script lang="ts">
  import { base } from '$app/paths';
  import CodeBlock from '$lib/components/CodeBlock.svelte';
  import type { PageData } from './$types';

  let { data }: { data: PageData } = $props();
  let board = $derived(data.leaderboard);
  let anchorRun = $derived(board.source.anchorRunId);

  const officialRun = `RUN_ID=spark-sandboxed-official-$(date -u +%Y%m%dT%H%M%SZ) \\
  bash scripts/run-official-bubblewrap-benchmark.sh`;

  const overrides = `TRIALS_PER_TASK=3 MAX_CONCURRENCY=1 TIMEOUT_SECONDS=7200 \\
  RUN_ID=spark-sandboxed-official-20260606T120000Z \\
  bash scripts/run-official-bubblewrap-benchmark.sh`;

  const publish = `bash scripts/publish-benchmark-to-web.sh .factory/<run-id>`;

  const publishPush = `COMMIT=1 PUSH=1 \\
  COMMIT_MESSAGE="data: publish spark benchmark results" \\
  bash scripts/publish-benchmark-to-web.sh .factory/<run-id>`;

  const appRun = `cd app
flutter pub get
flutter run -d linux   # or -d windows, -d macos`;

  const webPreview = `cd web
bun install --frozen-lockfile
bun run check
bun run smoke   # builds the static site + validates the export`;
</script>

<svelte:head>
  <title>Run it · PickArena by Pickforge Studio</title>
  <meta
    name="description"
    content="Reproduce a PickArena benchmark run: the official sandboxed Bubblewrap script, publishing to the static site, and the interactive Flutter app path."
  />
</svelte:head>

<section class="hero" aria-labelledby="run-title" style="padding-bottom:1rem;">
  <p class="eyebrow">Run &amp; reproduce</p>
  <h1 id="run-title">Reproduce the benchmark.</h1>
  <p class="lede">
    PickArena is a Dart CLI (<code>dart_arena</code>) with a headless runner, task QA, and
    static exports, plus a Flutter desktop app for interactive runs. The official corpus
    runs sandboxed under Bubblewrap and publishes a versioned static leaderboard.
  </p>
  <div class="cta-row">
    <a class="button secondary" href="https://github.com/pickforge/pickarena">View the repository</a>
    <a class="button ghost" href={`${base}/methodology`}>Read the methodology →</a>
  </div>
</section>

<section class="section" aria-labelledby="prereq-title" style="padding-top:1rem;">
  <div class="section-head">
    <p class="eyebrow">Before you start</p>
    <h2 id="prereq-title">Prerequisites</h2>
    <p>The official sandboxed run assumes a Linux host with the sandbox and toolchain in place.</p>
  </div>

  <div class="feature-grid">
    <article class="card">
      <div class="kicker">Sandbox</div>
      <h3>Bubblewrap</h3>
      <p><code>bwrap</code> is installed and available on <code>PATH</code>. Generated code runs isolated with network disabled.</p>
    </article>
    <article class="card">
      <div class="kicker">Toolchain</div>
      <h3>Flutter, Dart, Bun</h3>
      <p>Flutter and Dart drive the runner and verifiers; Bun builds and validates the static web export.</p>
    </article>
    <article class="card">
      <div class="kicker">Provider</div>
      <h3>Factory Droid</h3>
      <p>
        Droid can run the configured model from <code>~/.factory/settings.json</code>. The
        default id <code>custom:gpt-5.3-codex-spark---Codex</code> maps to
        <strong>GPT 5.3 Codex Spark - Codex</strong>.
      </p>
    </article>
    <article class="card">
      <div class="kicker">Clean state</div>
      <h3>Clean worktree</h3>
      <p>The git worktree must be clean before a run — release reports intentionally mark dirty-worktree runs as non-release evidence.</p>
    </article>
  </div>

  <div class="note">
    <strong>Note:</strong> the official agentic corpus (private official Flutter tasks) is
    required for a release-labeled run. Without it you can still exercise the runner and
    the web export, but the numbers will not match the published board.
  </div>
</section>

<section class="section" aria-labelledby="steps-title">
  <div class="section-head">
    <p class="eyebrow">The path</p>
    <h2 id="steps-title">One official run, start to finish</h2>
  </div>

  <ol class="step-list">
    <li>
      <h3>Run the official Bubblewrap benchmark</h3>
      <p>
        Writes <code>.factory/$RUN_ID/run.json</code>, runs <code>dart_arena_headless</code>
        with generated-code sandboxing enabled, executes the active official Flutter tasks,
        and stores the run database plus artifact bundle under <code>.factory/$RUN_ID/</code>.
      </p>
      <CodeBlock title="official sandboxed run" code={officialRun} />
      <p>Useful overrides for trial count, concurrency, and timeout:</p>
      <CodeBlock title="with overrides" code={overrides} />
    </li>
    <li>
      <h3>Publish the run to the static site</h3>
      <p>
        Exports <code>web/static/data/leaderboard.v1.json</code> with the
        <code>aggregate-compatible</code> strategy, writes the
        <code>release_report.v1.json</code> provenance sidecar, and validates the site with
        <code>bun run web:check</code> and <code>bun run web:smoke</code>. It stages only the
        generated data files — never databases, workdirs, screenshots, or credentials.
      </p>
      <CodeBlock title="publish to web data" code={publish} />
      <p>Publish and push in one step after reviewing the run id:</p>
      <CodeBlock title="publish and push" code={publishPush} />
    </li>
    <li>
      <h3>Preview the site locally</h3>
      <p>
        The static site reads the exported JSON directly. Build and validate it from the
        <code>web/</code> directory:
      </p>
      <CodeBlock title="web preview" code={webPreview} />
    </li>
  </ol>
</section>

<section class="section" aria-labelledby="app-title">
  <div class="section-head">
    <p class="eyebrow">Interactive</p>
    <h2 id="app-title">Or drive it from the app</h2>
    <p>
      For exploratory runs, the Flutter desktop app lets you configure providers, pick
      tasks and models, set evaluator settings, concurrency, and trial count, then watch
      progress and inspect task-run details.
    </p>
  </div>
  <CodeBlock title="run the desktop app" code={appRun} />
  <div class="note">
    Configure at least one provider in <strong>Settings</strong>, choose <strong>New Run</strong>,
    then review the leaderboard, inspect trials, or export a run bundle. API keys stay in
    platform secure storage — do not commit keys, databases, or work directories.
  </div>

  {#if anchorRun}
    <p class="muted" style="margin-top:1.5rem;font-size:0.9rem;">
      The current published export comes from run
      <code class="mono">{anchorRun}</code>.
    </p>
  {/if}
</section>
