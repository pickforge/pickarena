# Runtime isolation instrumentation implementation plan

Status: first Task QA slice implemented; remaining proof pending
Created: 2026-06-20
Goal: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is not a completion claim. Every first-wave slice remains `deepSWEComplete: false`.

This began as a docs-only implementation plan. The first Task QA instrumentation slice is now implemented and recorded in [`docs/plans/2026-06-20-runtime-isolation-instrumentation-implementation-report.md`](./2026-06-20-runtime-isolation-instrumentation-implementation-report.md); remaining proof work is still pending.

Source pointers:

- [`docs/plans/2026-06-19-runtime-workspace-isolation-proof-investigation.md`](./2026-06-19-runtime-workspace-isolation-proof-investigation.md)
- [`docs/plans/2026-06-19-final-deepswe-completion-blocker-audit.md`](./2026-06-19-final-deepswe-completion-blocker-audit.md)
- [`docs/plans/2026-06-19-first-wave-workspace-isolation-audit.md`](./2026-06-19-first-wave-workspace-isolation-audit.md)

## Scope

- Plan runtime isolation instrumentation for a later approved implementation.
- Keep current first-wave status blocked until runtime evidence exists and is reviewed.
- Treat existing workspace evidence as artifact-scope only.
- Future code targets only, no edits now:
  - `app/lib/runner/task_qa_cli_runner.dart`
  - `app/lib/runner/task_qa_runner.dart`
  - `app/lib/runner/workdir_manager.dart`
  - `app/lib/runner/generated_code_sandbox.dart`
  - `app/lib/runner/codegen_task_executor.dart`
  - `app/lib/runner/agentic_run_orchestrator.dart`
  - `app/lib/agent/droid_agent_harness.dart`
  - `app/lib/runner/run_provenance.dart`
  - `app/lib/export/artifact_bundle.dart`
  - `app/lib/export/json_exporter.dart`
  - `app/lib/export/release_report.dart`

## Current code entry points

- Task QA CLI orchestration starts in `app/lib/runner/task_qa_cli_runner.dart`.
- Task QA workdir preparation and evaluator contexts are built through `app/lib/runner/task_qa_runner.dart`.
- Workdir creation and path handling run through `app/lib/runner/workdir_manager.dart`.
- Generated-code sandbox support lives in `app/lib/runner/generated_code_sandbox.dart` and is not yet wired into Task QA evidence.
- Code execution flows through `app/lib/runner/codegen_task_executor.dart` and agentic orchestration through `app/lib/runner/agentic_run_orchestrator.dart`.
- The Droid agent harness configures cwd/env in `app/lib/agent/droid_agent_harness.dart`; current Droid harness cwd/env is not runtime sandbox proof.
- Provenance and export surfaces are `app/lib/runner/run_provenance.dart`, `app/lib/export/artifact_bundle.dart`, `app/lib/export/json_exporter.dart`, and `app/lib/export/release_report.dart`.

## Implementation sequence after approval

1. Task QA sandbox/provenance option: add CLI option equivalent to headless `requireGeneratedCodeSandbox`, default off, required mode fails if sandbox backend unavailable, pass sandbox into prepare/evaluator contexts.
2. Workspace evidence: per-workdir evidence collection; export only counts, digests, backend/status, path-guard booleans; no contents/absolute temp paths/restricted paths.
3. Admission/replay artifacts: include sandbox required/enforced/backend and workspace evidence digest/counts in admission report/summary and replay manifests/results.
4. Solver/agent harness gap: current Droid harness cwd/env is not runtime sandbox proof. Options: existing sandbox backend wrapper, containerized harness with explicit binds, or keep agentic runtime proof blocked if external harness cannot be sandboxed.
5. Validation and review: unit tests, export/release-report tests, official QA rerun with sandbox required, Opus review.

## Validation after implementation

- Add unit coverage for required sandbox mode, unavailable backend failure, and redacted evidence export.
- Add export and release-report coverage for sandbox enforcement fields and workspace evidence counts/digests.
- Run the official QA flow with sandbox required after approved code changes.
- Keep review evidence attached to the blocker audit before any status change is considered.

## Non-goals and redaction

- no hidden verifier contents
- no solver diffs/source snippets
- no temp/absolute paths
- no additional task/app code changes without a focused follow-up plan
- no blocker closure / no DeepSWE completion claim
