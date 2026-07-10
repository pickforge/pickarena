# Leakage audit

## Status

Current status: prompt-level and solver-facing patch/public-log leakage checks pass for this DeepSWE slice. Full agent-side sandbox proof remains pending.

Hidden-verifier transcripts are restricted evaluator-only evidence, not solver-facing artifacts.

## Current durable evidence

From `qa/admission_report.json`:

- `promptSafeContextLeakFree: true`
- `hidden_verifier_leak_free: true`
- `reference_leak_free: true`

From `qa/v1plus_report.md`:

- GPT/Opus/GLM read-only audit found no hidden-only literals or hidden paths in instruction/baseline/public tests.
- Deleted/weakened public test negative exists and is rejected by hidden tests.

From `leakage_scan_result.json`:

- checked solver-facing original and fresh-rerun patches, sanitized summaries, public replay logs, copied subagent prompt/output/metadata/session JSONL, pre-hidden workspace snapshots, redacted command telemetry summaries, flake-loop summaries, and `p2p_checklist.md`
- forbidden path tokens checked: `_hidden/`, `hidden_tests`, `solution/`, `negative_cases`
- hidden-only string literal sample count checked: 6
- Kimi findings: 0
- MiniMax findings: 0
- solver-facing scan passed: true

Grading hidden logs and hidden-case mapping docs are intentionally excluded from the solver-facing scan. `solver_runs/*/hidden_results.log`, `solver_runs/*/rerun_2026_06_19/hidden_results.log`, `flake_runs/*_run_*.log`, `flake_runs_10/*_run_*.log`, `command_telemetry/*_hidden_replay.log`, `prompt_verifier_bijection.md`, and `f2p_checklist.md` are restricted evaluator-only artifacts, not solver-facing evidence. The `qa_repetition/run_*.log` files, redacted `command_telemetry/command_telemetry_result.json`, flake-loop summary JSON files, and `p2p_checklist.md` were checked as solver-facing summary artifacts and do not contain hidden verifier details.

## Solver input isolation evidence

The V1+ report says solvers used sanitized `/tmp` workspaces containing only:

- `instruction.md`
- `pubspec.yaml`
- `lib/feed_refresh_controller.dart`
- `test/feed_refresh_controller_test.dart`

Hidden tests, solution files, negative cases, and author notes were reportedly absent during solving.

This is reported evidence, not a durable pre-solve workspace snapshot.

## Pending DeepSWE leakage checks

- durable raw solver workspace snapshots before hidden-test injection
- raw provider/harness trajectory scan for `_hidden/`, restricted asset paths, and hidden-only literals
- exported artifact scan from an official clean run
- clean solver/staging/grading isolation proof from a committed workflow

## Do not claim yet

Current audit does not prove full agent-side sandboxing or clean DeepSWE isolation.
