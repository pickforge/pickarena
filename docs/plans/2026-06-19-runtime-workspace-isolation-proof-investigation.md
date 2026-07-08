# Runtime workspace isolation proof investigation

Status: active proof-gap note
Created: 2026-06-19
Goal: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is not a completion claim. Every first-wave slice remains `deepSWEComplete: false`.

## Scope

This note checks current Task QA and harness runtime behavior only far enough to separate artifact cleanliness from runtime workspace isolation proof. It does not reclassify first-wave DeepSWE status.

## Current runtime isolation behavior

- Task QA creates clean per-task workdirs under `workdirRoot/runs/...` and rewrites only task fixtures through `WorkdirManager.createTaskWorkdir` in `app/lib/runner/workdir_manager.dart`; the CLI deletes and recreates the workdir root before each run in `app/lib/runner/task_qa_cli_runner.dart`.
- Fixture paths reject absolute or escaping paths through `resolveWorkspaceFile` in `app/lib/core/workspace_path.dart`.
- File-backed bundles reject `..`, absolute paths, and symlinks before reading bundle files in `app/lib/tasks/file_backed/file_backed_task.dart`.
- Hidden verifiers are staged outside solver-facing workspaces, run separately, and deleted by the hidden test evaluator under `app/lib/evaluators/`; hidden verifier contents and locations are not repeated here.
- Public evaluators exclude hidden evaluators in `app/lib/runner/task_qa_runner.dart`.
- Baseline, reference, and negative-case QA paths use separate workdirs in `app/lib/runner/task_qa_runner.dart`.
- Task QA does not execute solver/provider agents; it runs baseline/reference/negative-case validation in `app/lib/runner/task_qa_runner.dart`.
- No sandbox is wired into Task QA: `EvaluationContext` is built without `generatedCodeSandbox` in `app/lib/runner/task_qa_runner.dart`.
- The agentic harness sets cwd and environment for agent runs in `app/lib/agent/droid_agent_harness.dart`, but that is not OS sandbox proof.
- Generated-code sandbox support exists in `app/lib/runner/generated_code_sandbox.dart`, but Task QA does not expose or use it.

## Current artifact-scope evidence

Existing workspace audit evidence is artifact-scope only: `workspaceIsolationVerified: false`, `artifactScopeOnly: true`, 20 snapshots audited, and zero restricted path, restricted content, or solver-facing overlap findings in `docs/plans/2026-06-19-first-wave-workspace-isolation-audit.md` and `docs/plans/2026-06-19-first-wave-workspace-isolation-audit.json`.

## Why this is insufficient

The current evidence supports artifact cleanliness, clean fixture path handling, bundle path guards, and evaluator separation. It does not prove a runtime/tool-level access boundary for solver or provider execution. Therefore, runtime workspace isolation proof remains blocked.

## Required evidence to close the blocker

- Add a Task QA sandbox/provenance option and emit evidence into admission/replay artifacts.
- Emit per-run workspace manifests, hashes, and path-guard evidence without contents.
- Prove solver/agent harness runtime boundaries, not only evaluator sandboxing.
- Perform a clean-provenance rerun after instrumentation.
- Keep `deepSWEComplete: false` until evidence exists and is reviewed.

## Redaction

No hidden verifier contents, no solver diffs or source snippets, no private paths beyond repo source pointers, and no temp paths.
