# Solver/agent harness boundary implementation report

Status: optional sandbox slice implemented; official proof pending
Created: 2026-06-20
Goal id: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is not a completion claim. `deepSWEComplete: false` remains.

## Scope

This records the smallest off-by-default Droid agent harness sandbox-aware slice. It proves the harness can be wrapped by the existing generated-code sandbox in tests, but it does not claim official solver/provider execution is fully OS-sandboxed.

## Implemented

- `app/lib/agent/droid_agent_harness.dart`
  - Added optional `GeneratedCodeSandbox?` dependency, defaulting to `null`.
  - Preserved default no-sandbox behavior and custom-runner behavior.
  - Wrapped the default process launch only when a sandbox is provided.
  - Emits only sanitized boundary metadata when wrapped: `runtimeBoundary.enforced` and `runtimeBoundary.backend`.
- `app/test/agent/agent_harness_test.dart`
  - Added a fake sandbox wrapper test.
  - Extended no-sandbox assertions to confirm `runtimeBoundary` is absent by default.
  - Added a real Bubblewrap probe that denies a host-file read and allows a workspace write.
- `app/test/runner/agentic_run_orchestrator_test.dart`
  - Confirmed sanitized `runtimeBoundary` metadata survives while unsafe harness metadata is redacted.
- `app/lib/headless/headless_cli_runner.dart`
  - `HeadlessCliAgentHarnessBuilder` now receives the already-created `GeneratedCodeSandbox?`.
  - The default Droid harness builder passes that sandbox into `DroidAgentHarness(generatedCodeSandbox: generatedCodeSandbox, deniedEnvironmentKeys: ...)` for Droid providers.
  - Non-Droid/custom provider behavior remains unchanged.
- `app/test/headless/headless_cli_runner_test.dart`
  - Added focused default Droid headless harness sandbox wiring coverage.
  - `default Droid headless harness receives generated sandbox` verifies a fake generated sandbox reaches the captured `DroidAgentHarness` and emits only sanitized `runtimeBoundary` metadata.

## Validation

Passed:

```sh
cd app && dart format --output=none --set-exit-if-changed lib/agent/droid_agent_harness.dart test/agent/agent_harness_test.dart test/runner/agentic_run_orchestrator_test.dart
cd app && dart format --output=none --set-exit-if-changed lib/headless/headless_cli_runner.dart test/headless/headless_cli_runner_test.dart
cd app && flutter test test/agent/agent_harness_test.dart test/runner/agentic_run_orchestrator_test.dart
cd app && flutter test test/headless/headless_cli_runner_test.dart test/agent/agent_harness_test.dart
cd app && flutter analyze
```

The Bubblewrap probe ran locally and was not skipped.

A safe real-Droid binary probe also ran through `BubblewrapGeneratedCodeSandbox` using `droid --version` only: backend `bubblewrap`, exit code `0`, version `0.152.0`, stderr byte count `0`. This proves the local Droid executable can start under the wrapper, but it does not execute a provider session.

A real headless CLI default Droid harness smoke was attempted as blocker evidence, not completion: final run `droid-bwrap-smoke-20260620c`. The smoke used a disposable public-only file-backed task under ignored `app/build`; no hidden/restricted task artifacts were used. Earlier setup retries corrected config/schema issues before Droid was reached, so they are not Droid blocker evidence. The final headless config used the Droid provider/model `gpt-5.5`, `requireGeneratedCodeSandbox: true`, no judge, one public-only agentic task, one trial, and a short timeout. PickArena completed with process exit code `0` and run status `completed` because the task run was persisted. The SQLite/artifact summary recorded 1 run, 1 task_run, and 5 evaluations.

The agent harness evaluation recorded sanitized boundary metadata: `runtimeBoundary.enforced: true`, `runtimeBoundary.backend: bubblewrap`, `status: failure`, `exit_code: 1`, `argc: 8`, `cwd_proxy_used: true`, and `metadata_redacted_count: 2`. The stdout preview was empty. The stderr preview was an auth-required diagnostic; it is intentionally not quoted, and no secrets were exposed. Follow-on evaluators were blocked, skipped, or failed because the harness failed; `diff_size` passed trivially. This proves the real headless CLI default Droid harness path can launch the real Droid command through Bubblewrap and persist sanitized boundary metadata. It does not prove successful provider/session execution under Bubblewrap because Droid authentication/config was unavailable inside the sandbox; provider/session smoke remains blocked/pending.

Read-only Opus review: ACCEPT.

## Remaining proof gaps

- Real Droid/provider session execution under Bubblewrap has not been proven.
- The `droid --version` Bubblewrap probe proves binary startup only, not auth/config/provider/session behavior.
- The headless smoke proves the default Droid harness path can launch Droid through Bubblewrap and persist sanitized `runtimeBoundary` metadata, but it failed at sandbox auth/config before a provider session succeeded.
- Follow-up investigation found the wrapped Droid process uses a scrubbed environment with parent inheritance disabled, built-in models add no custom credential allowlist, and current Bubblewrap binds do not expose Droid auth/session, Factory settings, host home/config/cache/runtime state, or Droid-specific writable state. Any auth exposure strategy changes security scope and needs user/maintainer approval before implementation.
- The headless CLI default Droid harness test uses a fake generated sandbox and sanitized metadata only; it is not real Droid/provider-in-Bubblewrap proof.
- Clean committed V2 local replay is complete, but it resolves only the V2 local replay blocker.
- Provider-internal stream/session export remains blocked.
- Authored-by provenance remains unknown until a durable provenance source is provided.
- Generated-code sandbox evidence and test-harness probe evidence must not be treated as official solver/provider OS-sandbox proof.

## Redaction

The implementation exports only boundary booleans and backend labels. It must not export commands, instruction text, model ids, environment variables, wrapped executables, Bubblewrap args, workspace paths, proxy paths, provider credentials/config paths, prompts, transcripts, solver diffs, or source snippets.
