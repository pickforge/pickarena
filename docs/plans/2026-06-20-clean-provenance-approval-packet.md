# Clean provenance approval packet

Status: awaiting user approval
Created: 2026-06-20
Goal: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is a staging/commit approval packet only. It does not stage, commit, push, clean, or mark the DeepSWE goal finished.

## Current git state

- Branch: `main`
- Repo dirty: yes
- Status entries: 50
- Untracked files: 584
- Index: empty

## Validation/evidence notes

- This packet remains approval-only and preserves `deepSWEComplete: false`; runtime isolation/blocker status is still blocked.
- Dry-run staging check passed on 2026-06-20: the 50-entry allowlist produced 601 `git add --dry-run` actions, including one tracked spec removal and 600 additions, and left the index empty.
- Independent read-only review accepted the dry-run evidence as useful and accurate, with no clean-provenance or DeepSWE-completion overclaim.
- Read-only git hygiene check confirmed the allowlist covers all current 50 status entries with no extra paths, the suggested commit message is Conventional Commits-compliant, and no forbidden attribution/model terms are present.
- Read-only blocker-doc link/path audit checked 7 active blocker/readiness/approval docs and 109 repo references; no missing references were found and the index remained empty.
- Allowlist content hygiene scan now has no non-task whitespace issues after fixing `.gitignore` final newline and one docs-plan trailing space. Remaining whitespace/newline noise is limited to task DeepSWE evidence artifacts and is intentionally left unchanged to avoid altering generated evidence before approval.
- Independent read-only review accepted the content-hygiene fixes and the decision to leave generated task DeepSWE evidence artifacts untouched before approval.
- All four owner packets now carry independent read-only review notes; they remain approval/decision requests and close no blockers.
- The provider/session export decision packet is decision-only; it does not expose provider/session content and preserves `deepSWEComplete: false`.
- The Droid/Bubblewrap auth packet is approval-only; it does not implement or expose auth and preserves `deepSWEComplete: false`.
- Safe binary-only probe: `droid --version` under Bubblewrap exited `0` and reported version `0.152.0`; this proves binary startup only.
- Real headless CLI default Droid Bubblewrap smoke: `droid-bwrap-smoke-20260620c`. It used a disposable public-only file-backed task under ignored `app/build`; no hidden/restricted task artifacts were used.
- The final smoke used Droid provider/model `gpt-5.5`, `requireGeneratedCodeSandbox: true`, no judge, one public-only agentic task, one trial, and a short timeout. PickArena exited `0` with run status `completed` because it persisted the task run; artifacts recorded 1 run, 1 task_run, and 5 evaluations.
- The agent harness evaluation recorded sanitized `runtimeBoundary` metadata with backend `bubblewrap`, `status: failure`, `exit_code: 1`, `argc: 8`, `cwd_proxy_used: true`, and `metadata_redacted_count: 2`. Output preview metadata was sanitized and contains no provider payloads or secrets.
- Follow-on evaluators were blocked/skipped/failed because the agent harness failed; `diff_size` passed trivially. This is blocker evidence only: it proves the real headless CLI default Droid harness path can launch Droid through Bubblewrap and persist sanitized boundary metadata, but provider/session execution remains blocked at auth/config.

## Changed areas

- App runtime isolation instrumentation: `app/lib/runner/generated_code_sandbox.dart`, `app/lib/runner/task_qa_cli_runner.dart`, `app/lib/runner/task_qa_runner.dart`, `app/lib/runner/workdir_manager.dart`, `app/lib/agent/droid_agent_harness.dart`, `app/lib/headless/headless_cli_runner.dart`, and matching runner/agent/headless tests.
- App test harness: `app/test/tasks/official_file_backed_task_test.dart`, `app/test/headless/headless_cli_runner_test.dart`
- Task bundles/artifacts: `tasks/flutter/{async.refresh_deduplicator,accessibility.quantity_stepper_semantics,refactor.price_label_formatter,persistence.offline_feed_preferences,ui.action_bar_overflow}/`
- Task docs: `tasks/AUTHORING.md`, `tasks/README.md`
- Plans/audits: `docs/plans/2026-06-15-agent-assisted-task-authoring.md`, `docs/plans/2026-06-18-v1-flutter-task-backlog.md`, `docs/plans/2026-06-19-*`, `docs/plans/2026-06-20-provider-session-export-decision-packet.md`, `docs/plans/2026-06-20-droid-bubblewrap-auth-approval-packet.md`, and the 2026-06-20 blocker/approval/evidence notes
- Specs: new mobile benchmark spec, specs README, and archived old master spec
- Repo docs/config: `README.md`, `.gitignore`, `.vscode/settings.json`

## Risk notes

- Untracked files are user-owned until explicitly approved for staging.
- Before staging, explicitly confirm the old spec move: tracked deletion at `docs/specs/2026-05-31-pickarena-by-pickforge-studio-master.md` plus archived copy at `docs/specs/old/2026-05-31-pickarena-by-pickforge-studio-master.md`.
- DeepSWE task bundles include restricted evaluator-only files such as hidden tests and negative cases. Stage them only as intentional private benchmark corpus artifacts, never via `git add .` or broad parent-directory staging.
- Do not push without a separate explicit request.

## Suggested commit boundary

Preferred single provenance commit after approval:

```text
test: add first-wave PickArena DeepSWE benchmark tasks
```

Reason: the task bundles, QA artifacts, docs, audits, and official harness split are one provenance unit. Splitting them would make the first clean committed rerun harder to interpret.

If smaller commits are required, use:

1. `docs: add PickArena benchmark workflow and specs`
2. `test: add first-wave Flutter benchmark tasks`
3. `test: harden official file-backed task regression`

## Approval command shape

Only run after explicit approval:

```sh
git status --short
# Confirm the spec archive move before running the next command.
# This intentionally stages private benchmark task bundles, including restricted evaluator-only files.
git add -- \
  README.md \
  .gitignore \
  .vscode/settings.json \
  app/lib/agent/droid_agent_harness.dart \
  app/lib/headless/headless_cli_runner.dart \
  app/lib/runner/generated_code_sandbox.dart \
  app/lib/runner/task_qa_cli_runner.dart \
  app/lib/runner/task_qa_runner.dart \
  app/lib/runner/workdir_manager.dart \
  app/test/agent/agent_harness_test.dart \
  app/test/headless/headless_cli_runner_test.dart \
  app/test/runner/agentic_run_orchestrator_test.dart \
  app/test/runner/generated_code_sandbox_test.dart \
  app/test/runner/task_qa_cli_runner_test.dart \
  app/test/runner/task_qa_runner_test.dart \
  app/test/runner/workdir_manager_test.dart \
  app/test/tasks/official_file_backed_task_test.dart \
  docs/plans/2026-06-15-agent-assisted-task-authoring.md \
  docs/plans/2026-06-18-v1-flutter-task-backlog.md \
  docs/plans/2026-06-19-final-deepswe-completion-blocker-audit.md \
  docs/plans/2026-06-19-first-wave-deepswe-readiness.md \
  docs/plans/2026-06-19-provider-session-export-availability-investigation.md \
  docs/plans/2026-06-19-runtime-workspace-isolation-proof-investigation.md \
  docs/plans/2026-06-19-first-wave-performance-sampling-audit.json \
  docs/plans/2026-06-19-first-wave-performance-sampling-audit.md \
  docs/plans/2026-06-19-first-wave-provenance-gap-audit.json \
  docs/plans/2026-06-19-first-wave-provenance-gap-audit.md \
  docs/plans/2026-06-19-first-wave-workspace-isolation-audit.json \
  docs/plans/2026-06-19-first-wave-workspace-isolation-audit.md \
  docs/plans/2026-06-19-pickarena-task-multiplication-workflow.md \
  docs/plans/2026-06-20-authored-by-provenance-request.md \
  docs/plans/2026-06-20-clean-provenance-approval-packet.md \
  docs/plans/2026-06-20-provider-session-export-decision-packet.md \
  docs/plans/2026-06-20-droid-bubblewrap-auth-approval-packet.md \
  docs/plans/2026-06-20-solver-agent-harness-boundary-proof-plan.md \
  docs/plans/2026-06-20-solver-agent-harness-boundary-implementation-report.md \
  docs/plans/2026-06-20-first-wave-required-sandbox-qa-evidence.md \
  docs/plans/2026-06-20-runtime-isolation-instrumentation-plan.md \
  docs/plans/2026-06-20-runtime-isolation-instrumentation-implementation-report.md \
  docs/specs/2026-05-31-pickarena-by-pickforge-studio-master.md \
  docs/specs/2026-06-15-pickarena-mobile-agent-benchmark.md \
  docs/specs/README.md \
  docs/specs/old/2026-05-31-pickarena-by-pickforge-studio-master.md \
  tasks/AUTHORING.md \
  tasks/README.md \
  tasks/flutter/accessibility.quantity_stepper_semantics \
  tasks/flutter/async.refresh_deduplicator \
  tasks/flutter/persistence.offline_feed_preferences \
  tasks/flutter/refactor.price_label_formatter \
  tasks/flutter/ui.action_bar_overflow

git status --short
git commit -m "test: add first-wave PickArena DeepSWE benchmark tasks"
```

## Post-commit clean-provenance checks

Run only after the approved commit:

```sh
git status --short
cd app && dart format --output=none --set-exit-if-changed lib/agent/droid_agent_harness.dart test/agent/agent_harness_test.dart test/runner/agentic_run_orchestrator_test.dart lib/headless/headless_cli_runner.dart test/headless/headless_cli_runner_test.dart lib/runner/generated_code_sandbox.dart test/runner/generated_code_sandbox_test.dart lib/runner/task_qa_cli_runner.dart lib/runner/task_qa_runner.dart lib/runner/workdir_manager.dart test/runner/task_qa_cli_runner_test.dart test/runner/task_qa_runner_test.dart test/runner/workdir_manager_test.dart
cd app && flutter test test/runner/generated_code_sandbox_test.dart test/runner/workdir_manager_test.dart test/runner/task_qa_runner_test.dart test/runner/task_qa_cli_runner_test.dart
cd app && flutter test test/agent/agent_harness_test.dart test/runner/agentic_run_orchestrator_test.dart
cd app && flutter test test/headless/headless_cli_runner_test.dart test/agent/agent_harness_test.dart
cd app && dart run --verbosity=error dart_arena:dart_arena_task_qa --out build/task_qa_runtime_isolation_smoke --task-bundle-root ../tasks/flutter --task async.refresh_deduplicator --hidden-flake-runs 1 --evaluator-timeout-seconds 60 --require-generated-code-sandbox
cd app && for task_pair in \
  async.refresh_deduplicator:async_refresh_deduplicator \
  accessibility.quantity_stepper_semantics:accessibility_quantity_stepper_semantics \
  refactor.price_label_formatter:refactor_price_label_formatter \
  persistence.offline_feed_preferences:persistence_offline_feed_preferences \
  ui.action_bar_overflow:ui_action_bar_overflow
do
  task="${task_pair%%:*}"
  task_safe="${task_pair##*:}"
  dart run --verbosity=error dart_arena:dart_arena_task_qa --out "build/task_qa_runtime_isolation_first_wave_clean/${task_safe}" --task-bundle-root ../tasks/flutter --task "$task" --hidden-flake-runs 1 --evaluator-timeout-seconds 60 --require-generated-code-sandbox
done
cd app && flutter analyze
cd app && flutter test test/tasks/official_file_backed_task_test.dart
```

Expected clean-provenance target:

- `git status --short` is empty before the rerun.
- Runtime-isolation format/test/analyze checks pass.
- Full first-wave required-sandbox Task QA replay passes for all five tasks.
- Official regression passes.
- Any follow-up provenance artifact update must state the exact committed revision and still keep `deepSWEComplete: false` until provider/session, authored-by, and runtime isolation blockers are resolved.

## Still blocked after commit

A clean commit/rerun can address only the `gitDirty=false` blocker. These remain:

- authored-by provenance must come from a durable source; do not infer it.
- provider-internal stream/session export still needs provider/tooling owner approval, export, certification, or unavailable/deferred decision; do not infer from generic session files.
- runtime workspace isolation has first-wave required-sandbox Task QA evidence, but still needs clean required-sandbox replay and solver/agent harness boundary proof; Droid/Bubblewrap provider/session proof needs an approved auth strategy before implementation or rerun.
- performance evidence remains artifact-scope sampling, not a statistical benchmark.
