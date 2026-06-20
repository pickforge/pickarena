# Runtime isolation instrumentation implementation report

Status: first-wave required-sandbox QA evidence captured; proof still pending
Created: 2026-06-20
Goal: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is not a completion claim. Every first-wave slice remains `deepSWEComplete: false`.

## Scope

This records the first approved-by-continuation implementation slice for Task QA runtime-isolation evidence and links the redacted first-wave required-sandbox QA evidence in [`docs/plans/2026-06-20-first-wave-required-sandbox-qa-evidence.md`](./2026-06-20-first-wave-required-sandbox-qa-evidence.md). It does not close the full runtime workspace isolation blocker because clean committed replay and solver/agent harness boundary proof are still pending.

## Implemented

- `app/lib/runner/generated_code_sandbox.dart`
  - Normalized sandbox temp environment variables to `/tmp`, matching the sandbox tmpfs so Flutter can run inside Bubblewrap.
- `app/lib/runner/workdir_manager.dart`
  - Added redacted workspace isolation evidence collection.
  - Exports counts, booleans, and SHA-256 digests only.
- `app/lib/runner/task_qa_runner.dart`
  - Added optional `generatedCodeSandboxRequired` / `generatedCodeSandbox` wiring.
  - Fails early when sandbox is required but unavailable.
  - Threads the sandbox into Task QA prepare and evaluator contexts.
  - Adds additive `runtimeIsolation` report data and non-gating checks.
- `app/lib/runner/task_qa_cli_runner.dart`
  - Added `--require-generated-code-sandbox`.
  - Adds redacted runtime-isolation summary fields.
- `app/test/runner/generated_code_sandbox_test.dart`
- `app/test/runner/workdir_manager_test.dart`
- `app/test/runner/task_qa_runner_test.dart`
- `app/test/runner/task_qa_cli_runner_test.dart`
  - Added coverage for sandbox temp normalization, evidence redaction, required sandbox failure, fake sandbox enforcement, and CLI summary output.

## Validation

Passed:

```sh
cd app && dart format --output=none --set-exit-if-changed lib/runner/generated_code_sandbox.dart test/runner/generated_code_sandbox_test.dart lib/runner/task_qa_cli_runner.dart lib/runner/task_qa_runner.dart lib/runner/workdir_manager.dart test/runner/task_qa_cli_runner_test.dart test/runner/task_qa_runner_test.dart test/runner/workdir_manager_test.dart
cd app && flutter test test/runner/generated_code_sandbox_test.dart test/runner/workdir_manager_test.dart test/runner/task_qa_runner_test.dart test/runner/task_qa_cli_runner_test.dart
cd app && dart run --verbosity=error dart_arena:dart_arena_task_qa --out build/task_qa_runtime_isolation_smoke --task-bundle-root ../tasks/flutter --task async.refresh_deduplicator --hidden-flake-runs 1 --evaluator-timeout-seconds 60 --require-generated-code-sandbox
cd app && flutter analyze
cd app && flutter test test/tasks/official_file_backed_task_test.dart
```

Required-sandbox smoke history: `async.refresh_deduplicator` completed, `taskCount: 1`, `admittedTaskCount: 1`, sandbox required/enforced with `bubblewrap`, workspace evidence collected for 6 workdirs, `restrictedPathCount: 0`, manifest digest length 64.

Full first-wave required-sandbox QA evidence: [`docs/plans/2026-06-20-first-wave-required-sandbox-qa-evidence.md`](./2026-06-20-first-wave-required-sandbox-qa-evidence.md). The run completed/admitted all five first-wave tasks: `taskCount 5`, `admitted 5`, `rejected 0`; sandbox required/enforced with `bubblewrap` for all five; aggregate `workspaceCount 40`, `visibleFileCount 144`, `visibleBytes 270573`, `restrictedPathCount 0`, `symlinkCount 0`, `unreadableFileCount 0`, and digest lengths `[64,64,64,64,64]`. This is not from a clean committed state.

Official regression result: `cd app && flutter test test/tasks/official_file_backed_task_test.dart` passed in `29:51`.

Read-only Opus review before the temp-env smoke fix: ACCEPT. A follow-up review is required for the temp-env fix and smoke evidence.

## Remaining proof gaps

- Clean committed provenance is still blocked on user approval to stage/commit and rerun.
- Required-sandbox Task QA evidence exists for all five first-wave tasks, but not from a clean committed state; clean committed replay and solver/agent harness boundary proof remain open.
- Provider-internal stream/session export remains blocked.
- Authored-by provenance remains unknown until a durable provenance source is provided.
- Droid/agent solver harness runtime boundary proof was not attempted in this slice.

## Redaction

The implementation and tests are intended to export only booleans, counts, static role labels, backend status, and SHA-256 digests. It must not export hidden verifier contents, solver diffs/source snippets, absolute temp/workdir paths, restricted paths, fixture filenames, or file contents.
