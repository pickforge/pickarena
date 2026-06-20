# Solver/agent harness boundary proof plan

Status: optional sandbox slice implemented; official proof pending
Created: 2026-06-20
Goal id: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is not a completion claim. `deepSWEComplete: false` remains.

## Scope

- Record the solver/agent harness runtime boundary gap separately from Task QA generated-code sandbox evidence.
- Record the smallest safe implementation slice needed before any solver/agent OS-sandbox proof can be claimed.
- The optional sandbox slice is implemented in [`docs/plans/2026-06-20-solver-agent-harness-boundary-implementation-report.md`](./2026-06-20-solver-agent-harness-boundary-implementation-report.md).
- Record the headless CLI default Droid harness wiring slice that passes the already-created generated sandbox into default Droid harness construction for Droid providers.
- Keep the final blocker status blocked until clean committed replay, provider/session provenance, authored-by provenance, and solver/agent harness boundary proof are resolved.
- Do not edit app code, tests, task bundles, or specs in this docs-only note.

## Current solver harness behavior

- Current agentic solver flow does workspace/env confinement only, not OS sandboxing.
- Agent workspaces are created under `root/runs/...`, cleaned and recreated, populated from the visible fixture root with restricted paths excluded, and initialized with a git baseline in `app/lib/runner/workdir_manager.dart`.
- The agent command is `droid exec --auto high --output-format text --model <model> <instruction>` in `app/lib/agent/droid_agent_harness.dart`.
- The default Droid harness spawn still uses `Process.start(... workingDirectory, environment, includeParentEnvironment:false)` unless its optional `GeneratedCodeSandbox?` is supplied; custom runners and no-sandbox defaults remain unchanged.
- Long path handling uses a temporary cwd proxy, syncs back to the requested workspace, then deletes the proxy. This note records no actual proxy paths.
- `GeneratedCodeSandbox` is wired for prepare/evaluator processes and agentic prep/grading in `app/lib/runner/agentic_run_orchestrator.dart`.
- The headless CLI default Droid harness builder now receives the already-created `GeneratedCodeSandbox?` and passes it into `DroidAgentHarness` for Droid providers; focused tests prove fake generated sandbox propagation and sanitized `runtimeBoundary` metadata only.
- A safe `droid --version` probe through `BubblewrapGeneratedCodeSandbox` started the real Droid binary with backend `bubblewrap`, exit code `0`, version `0.152.0`, and empty stderr.
- A real headless CLI default Droid harness smoke, `droid-bwrap-smoke-20260620c`, used a disposable public-only file-backed task under ignored `app/build`; no hidden/restricted task artifacts were used. Initial setup retries corrected config/schema issues before Droid was reached, so they are setup corrections rather than Droid blocker evidence.
- The final smoke used Droid provider/model `gpt-5.5`, `requireGeneratedCodeSandbox: true`, no judge, one public-only agentic task, one trial, and a short timeout. PickArena exited `0` with run status `completed` because the task run was persisted; artifacts recorded 1 run, 1 task_run, and 5 evaluations.
- The agent harness evaluation recorded sanitized metadata only: `runtimeBoundary.enforced: true`, `runtimeBoundary.backend: bubblewrap`, `status: failure`, `exit_code: 1`, `argc: 8`, `cwd_proxy_used: true`, `metadata_redacted_count: 2`, empty stdout preview, and an unquoted auth-required stderr diagnostic with no secrets exposed.
- The Bubblewrap wrapper is generic enough to wrap arbitrary executables, but current bind configuration may not support Droid auth/config/network/provider needs.
- Existing Droid harness tests cover cwd, environment, proxy behavior, timeout handling, and output limits, not OS sandboxing.

## Why current evidence is insufficient

- Workspace cleanup, fixture copying, path exclusion, and git baseline setup are useful confinement signals, but they do not prove an OS boundary around the solver process.
- Task QA generated-code sandbox evidence proves prepare/evaluator sandboxing only for that flow.
- Optional `DroidAgentHarness` wrapping and headless CLI default Droid wiring are exercised by focused fake-sandbox tests, but they do not prove real Droid/provider execution under Bubblewrap.
- The real `droid --version` Bubblewrap probe proves executable startup only; it does not prove auth/config/provider/session behavior or solver execution.
- The real headless smoke proves the default Droid harness path can launch the real Droid command through Bubblewrap and persist sanitized `runtimeBoundary` metadata, but it does not prove successful provider/session execution because Droid authentication/config was unavailable inside the sandbox.
- A sanitized metadata field such as `runtimeBoundary: {enforced: true, backend: 'bubblewrap'}` is valid only when the agent command is actually wrapped; fake sandbox metadata demonstrates propagation, not production/provider enforcement.

## Droid auth/config Bubblewrap blocker investigation

- The wrapped Droid harness starts with parent environment inheritance disabled and a benchmark-scrubbed environment.
- Built-in Droid models add no custom-model environment allowlist, so no provider credential variable is intentionally forwarded for the `gpt-5.5` smoke.
- The current Bubblewrap setup binds the workdir and tool/system roots needed for process startup, but does not expose host Droid auth/session state, Factory model/settings state, host home/config/cache/runtime state, or a Droid-specific writable state area.
- The smoke allowed network access, so the observed failure is currently classified as auth/config availability, not network isolation.
- A successful wrapped provider/session smoke likely needs one approved auth strategy: bind a narrow host auth/config subset, copy a benchmark-scoped auth bundle into the sandbox, allowlist explicit Droid credential environment variables, provide sandbox-private Droid state/cache locations, or use a supported Droid config override.
- Every auth strategy changes security scope and needs user/maintainer approval before implementation or another real provider/session smoke.

## Smallest safe implementation slice

1. Add optional sandbox wrapping to `DroidAgentHarness` default runner, disabled by default. Implemented.
2. Emit sanitized harness metadata like `runtimeBoundary: {enforced: true, backend: 'bubblewrap'}` only when actually wrapped. Implemented.
3. Add fake-executable sandbox/probe test proving host-file denial and workdir write. Implemented.
4. Wire the headless CLI default Droid harness builder to pass the already-created generated sandbox into `DroidAgentHarness` for Droid providers, with fake-sandbox propagation coverage. Implemented.
5. Run a real Droid-in-Bubblewrap smoke before any official proof claim. Binary startup probe complete; headless CLI wrapped-Droid smoke attempted and blocked at auth/config; successful provider/session smoke pending.

## Proof required before closure

- The optional wrapper must be exercised by an automated fake-executable test that shows host-file denial and allowed workdir write.
- The metadata must be absent or unenforced when the wrapper is disabled, and present only after a real wrapped launch.
- A real Droid-in-Bubblewrap smoke must pass with the required auth/config/network/provider behavior before any official solver/agent OS-sandbox proof claim.
- The `droid-bwrap-smoke-20260620c` run is blocker evidence only: follow-on evaluators were blocked/skipped/failed because the agent harness failed, while `diff_size` passed trivially.
- A real headless CLI Droid/provider run using the wrapped harness path must pass before the headless wiring is treated as runtime proof.
- If Droid cannot run inside Bubblewrap, solver/agent OS-sandbox proof remains blocked and generated-code sandbox evidence must not be treated as agent process proof.

## Redaction and non-goals

- No hidden or restricted content.
- No prompts, transcripts, or provider message payloads.
- No solver diffs or source snippets.
- No absolute temp paths or proxy paths.
- No architecture, auth, persistence, provider, or network policy decisions in this plan.
- No blocker closure and no status advancement from this docs-only note.
