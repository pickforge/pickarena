<script lang="ts">
  import { base } from '$app/paths';
  import { countText } from '$lib/data/format';
  import type { PageData } from './$types';

  let { data }: { data: PageData } = $props();
  let board = $derived(data.leaderboard);
  let prov = $derived(board.source.runProvenance);

  let objectiveIds = $derived(board.scoring.objectiveEvaluatorIds);
  let sandbox = $derived(prov.generatedCodeSandboxBackends[0] ?? 'a sandboxed backend');
  let dart = $derived(prov.dartVersions[0] ?? null);
  let flutter = $derived(prov.flutterVersions[0] ?? null);

  const sections = [
    { id: 'overview', label: 'Overview' },
    { id: 'verifiers', label: 'Hidden verifiers' },
    { id: 'replay', label: 'Clean-baseline replay' },
    { id: 'negative', label: 'Negative cases' },
    { id: 'admission', label: 'Admission gates' },
    { id: 'f2p', label: 'f2p / p2p evidence' },
    { id: 'flake', label: 'Flake resistance' },
    { id: 'sandbox', label: 'Sandboxed runs' },
    { id: 'scoring', label: 'Scoring' },
    { id: 'telemetry', label: 'Honest telemetry' }
  ];

  const invariants: [string, string][] = [
    ['Human prompt', 'The instruction reads like a real mobile developer request, not a test-spec dump.'],
    ['Prompt–verifier bijection', 'Every hidden assertion maps to a behavior the prompt requests or implies; every critical requirement has verifier coverage.'],
    ['Hidden separation', 'Hidden tests, verifier names, reference solutions, and author rationale are never copied into agent workspaces or prompts.'],
    ['Separate verifier env', 'Grading runs in a clean verifier context, not the mutable context the agent used to reason.'],
    ['Behavior over snapshots', 'Hidden checks assert user-observable behavior and API contracts, not brittle implementation details.'],
    ['Bounded execution', 'Tasks are deterministic, offline by default, and sized to finish inside the declared timeout and resource limits.']
  ];
</script>

<svelte:head>
  <title>Methodology · PickArena by Pickforge Studio</title>
  <meta
    name="description"
    content="How PickArena grades coding agents: hidden behavioral verifiers, clean-baseline patch replay, negative cases, admission gates, f2p/p2p evidence, and honest telemetry."
  />
</svelte:head>

<section class="hero" aria-labelledby="method-title" style="padding-bottom:1rem;">
  <p class="eyebrow">Methodology</p>
  <h1 id="method-title">How we grade an agent.</h1>
  <p class="lede">
    PickArena answers one question: which coding agents can take a realistic mobile
    developer prompt, edit an app workspace, and produce behavior that passes clean
    hidden verification — without fake fixes, overfitting, or verifier leakage.
  </p>
</section>

<div class="doc-layout with-toc section" style="padding-top:1rem;">
  <nav class="doc-toc" aria-label="On this page">
    <span class="data-label">On this page</span>
    <ul>
      {#each sections as section}
        <li><a href={`#${section.id}`}>{section.label}</a></li>
      {/each}
    </ul>
  </nav>

  <div class="prose">
    <h2 id="overview">Overview</h2>
    <p>
      The benchmark starts with Flutter because the runner, task corpus, and Pickforge
      product surface are Flutter-first. An agent receives a workspace and a prompt,
      inspects and edits files, runs tools, and submits a patch. That patch is graded
      against hidden behavioral verifiers on a clean baseline, and the result is exported
      to the static leaderboard you are reading.
    </p>
    <p>
      The current public export covers <strong>{countText(board.source.taskCount)} tasks</strong>
      across <strong>{countText(board.source.modelCount)}
        {board.source.modelCount === 1 ? 'model' : 'models'}</strong>
      and <strong>{countText(board.source.taskRunCount)} scored trials</strong>{#if board.provisional},
      and is still marked provisional{/if}. The methodology below is the standard every
      admitted task and release run must meet, independent of how much data is published yet.
    </p>

    <h2 id="verifiers">Hidden behavioral verifiers</h2>
    <p>
      Each task ships two layers of checks. <strong>Public</strong> checks — visible tests
      and analyzer/compile passes — are available in the workspace. <strong>Hidden</strong>
      checks assert user-observable behavior and API contracts, and they are never copied
      into the agent's workspace or prompt. Verifier names match the pattern
      <code>{board.scoring.hiddenVerifierPattern ?? '*_hidden'}</code>, and grading runs in
      a separate context from the one the agent mutated.
    </p>
    <p>
      Hidden checks assert behavior, not snapshots. Golden and screenshot comparisons are
      used only where rendering is deterministic and tolerances are documented, so a
      passing agent is one whose app actually behaves correctly — not one that matched a
      brittle string.
    </p>

    <h2 id="replay">Clean-baseline patch replay grading</h2>
    <p>
      Agent changes are captured as a patch or equivalent file diff. Before final grading,
      that patch is <strong>replayed into a clean baseline</strong> — a fresh checkout with
      no residue from the agent's exploration. This makes scoring auditable and
      reproducible: the same patch, replayed the same way, yields the same grade.
    </p>

    <h2 id="negative">Negative cases</h2>
    <p>
      Rigor comes from what a task <em>rejects</em>. Every admitted task must carry negative
      cases that the hidden and admission gates fail:
    </p>
    <ul>
      <li><strong>Noop</strong> — an empty or cosmetic change must not pass.</li>
      <li><strong>API-breaking</strong> — a change that breaks the public contract must fail pass-to-pass checks.</li>
      <li><strong>Overfit</strong> — a solution hardcoded to the public examples must fail hidden breadth.</li>
    </ul>
    <p>
      Combined with enough hidden breadth, this rejects hardcoded values, removed tests,
      broken APIs, invented dependencies, and prompt-only compliance.
    </p>

    <h2 id="admission">Admission gates and task-bundle digests</h2>
    <p>
      A task is not part of an official preset until every applicable gate passes and the
      result is stored in <code>qa/admission_report.json</code>. Gates cover structure,
      stable metadata (id, version, category, difficulty, timeout, resource and network
      policy), the human-style prompt, baseline fail-to-pass, existing-behavior
      pass-to-pass, a reference solution that passes all verifiers, the required negative
      cases, hidden breadth, flake, and a recorded environment. The admission report and
      exported artifact bundle preserve the exact task ids and versions used, so a
      published claim is tied to a specific, digest-identified task set.
    </p>

    <div class="table-wrap" style="margin:1.5rem 0;">
      <table class="def-table">
        <caption class="sr-only">Selected benchmark invariants</caption>
        <tbody>
          {#each invariants as [name, detail]}
            <tr>
              <td>{name}</td>
              <td>{detail}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <h2 id="f2p">Fail-to-pass and pass-to-pass evidence</h2>
    <p>
      Two directional checks anchor every task. <strong>Fail-to-pass (f2p)</strong> proves
      the baseline genuinely fails the target behavior for the intended reason — so the
      task is real work, not already solved. <strong>Pass-to-pass (p2p)</strong> proves the
      existing expected behavior still passes after the reference solution — so a valid fix
      does not regress the rest of the app. An agent has to move f2p checks to passing
      while keeping p2p checks green.
    </p>

    <h2 id="flake">Flake resistance</h2>
    <p>
      Non-determinism is the enemy of a trustworthy benchmark. Tasks must survive repeated
      QA runs, or document why a non-repeated gate is acceptable, before admission.
      Reliability signals — trial variance, retries, tool failures, timeouts, and invalid
      patches — are preserved in reporting rather than averaged away.
    </p>

    <h2 id="sandbox">Sandboxed, offline runs</h2>
    <p>
      Generated code executes inside an isolated sandbox
      {#if sandbox}(<code>{sandbox}</code>){/if} with a network-disabled task policy and
      enforced resource limits. Runs are deterministic and offline by default. Every run
      records SDK and tool versions{#if dart || flutter}
        — this export ran on {#if dart}Dart <code>{dart}</code>{/if}{#if dart && flutter} and {/if}{#if flutter}Flutter <code>{flutter}</code>{/if}{/if} —
      along with host platform, dependency snapshot, resource policy, network policy, and
      git state.
    </p>

    <h2 id="scoring">Scoring</h2>
    <p>
      The primary metric is <code>{board.scoring.primaryMetric ?? 'primary_pass'}</code>,
      ranked by <code>{board.scoring.rankingMetric ?? 'primary_pass_rate'}</code> with a
      {board.scoring.confidenceInterval === 'wilson_95'
        ? 'Wilson 95% confidence interval'
        : (board.scoring.confidenceInterval ?? 'Wilson 95%') + ' confidence interval'}.
      Objective gates run deterministically
      {#if objectiveIds.length > 0}—
        {#each objectiveIds as id, i}<code>{id}</code>{#if i < objectiveIds.length - 1}, {/if}{/each}
      {/if}. Any LLM judge is
      <code>{board.scoring.llmJudgePolicy ?? 'diagnostic_only'}</code>: it informs
      diagnostics but does not decide pass/fail, which stays with the objective verifiers.
    </p>

    <h2 id="telemetry">Honest unknown telemetry</h2>
    <p>
      When a provider or harness does not report token counts, cost, step counts, or
      context usage, PickArena labels those fields <strong>unknown</strong> and excludes
      them from cost rankings — it never treats missing telemetry as zero. On the
      leaderboard a dash means "not reported", and cost-based comparisons quietly drop rows
      that lack the underlying data rather than inventing it.
    </p>

    <p style="margin-top:2rem;">
      <a href={`${base}/tasks/`}>Browse the task corpus</a> or
      <a href={`${base}/run/`}>reproduce a run</a>.
    </p>
  </div>
</div>
