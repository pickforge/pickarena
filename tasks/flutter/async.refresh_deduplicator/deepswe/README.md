# DeepSWE evidence slice: async.refresh_deduplicator

## Status

This directory is an additive DeepSWE artifact slice for `async.refresh_deduplicator`.

Current status: clean patch replay is verified for the recorded Kimi and MiniMax solver patches; full DeepSWE completion is **pending**.

- `deepSWEComplete: false`
- `replayVerified: true`
- `workspaceIsolationVerified: false`
- `durationCostTokenCaptured: false` for the full DeepSWE workflow
- solver subagent duration/usage metadata captured in `telemetry_report.json`

## Current evidence

Admission report evidence:

- admitted
- baseline hidden failed
- reference public passed
- reference hidden passed
- required negatives rejected
- hidden flake runs: `3`
- flake failures: `0`

V1+ evidence:

- GPT/Opus/GLM hidden literal audit reported no blockers.
- Kimi and MiniMax sanitized V1+ solver attempts passed public `2/2` and hidden `6/6`.
- Fresh Kimi, MiniMax, and GPT solver reruns passed public `2/2` and hidden `6/6`.

DeepSWE slice evidence now captured:

- Durable solver patches under `solver_runs/*/solver.patch`.
- Clean `git apply --check` replay for both patches.
- Separate fresh staging workspaces ran public tests.
- Separate fresh grading workspaces injected hidden tests and passed hidden tests.
- Solver-facing patch/public-log leakage scan passed: `leakage_scan_result.json`.
- Hidden replay flake loops passed: original 5-run loop and fresh-rerun 10-run loop. In the 10-run loop, baseline failed hidden `10/10` as expected; reference, Kimi fresh rerun, MiniMax fresh rerun, and GPT fresh rerun each passed hidden `10/10`.
- Full task QA repetition passed `5/5` runs with `--hidden-flake-runs 5`.
- Kimi and MiniMax solver subagent prompt/output/metadata copied into `solver_runs/*/trajectory/`, with duration/usage recorded in `telemetry_report.json`.
- Fresh Kimi, MiniMax, and GPT reruns captured public-only pre-hidden workspace snapshots in `solver_runs/*/rerun_2026_06_19/workspace_snapshot/`; all three rerun patches passed public and hidden replay.
- Fresh rerun subagent `session.jsonl` transcripts copied into `solver_runs/*/rerun_2026_06_19/trajectory/` and scanned leakage-clean for solver-facing scope.
- Command wall-clock telemetry captured one full task-QA run plus fresh rerun public/hidden replay commands across Kimi, MiniMax, and GPT with `0` errors.

## Files

- `README.md` records this slice status, evidence, blockers, and validation pointers.
- `prompt_verifier_bijection.md` maps prompt requirements to public/hidden verifier coverage; restricted evaluator-only.
- `f2p_checklist.md` records restricted evaluator-only failure-to-pass coverage.
- `p2p_checklist.md` records solver-facing public pass-to-pass coverage.
- `model_audit.yaml` records known audit/solver model evidence and pending provenance gaps.
- `telemetry_report.json` records copied solver subagent duration/usage metadata, command wall-clock telemetry, and their limits.
- `leakage_audit.md` records prompt and artifact leakage evidence.
- `leakage_scan_result.json` records the solver-facing patch/public-log leakage scan and restricted artifact classifications.
- `replay_manifest.json` records replay metadata and solver patch digests.
- `replay_log.md` records clean replay commands and outcomes.
- `flake_report.json` records current flake evidence and the 5-run hidden replay flake loop.
- `flake_runs/` and `flake_runs_10/` hold restricted evaluator-only hidden-verifier logs plus summaries; do not provide these transcripts to solvers.
- `qa_repetition/` holds five repeated full task-QA run summaries and logs.
- `solver_runs/kimi/`, `solver_runs/minimax/`, and `solver_runs/gpt/` hold patch, replay result, test logs, copied subagent trajectory artifacts, fresh rerun pre-hidden snapshots, and fresh rerun session JSONL transcripts.
- `command_telemetry/` holds measured command durations and logs; hidden replay logs are restricted evaluator-only.

## Blockers before DeepSWE claim

- Clean committed provenance run with `gitDirty=false`.
- Provider-internal stream chunks beyond captured subagent session JSONL.
- Broader performance sampling beyond the single measured command pass.
- Authored-by provenance is not durably known.

## Validation

Narrow artifact validation:

```sh
python3 -m json.tool replay_manifest.json >/dev/null
python3 -m json.tool flake_report.json >/dev/null
python3 -m json.tool leakage_scan_result.json >/dev/null
python3 -m json.tool telemetry_report.json >/dev/null
python3 - <<'PY'
import yaml
from pathlib import Path
yaml.safe_load(Path('model_audit.yaml').read_text())
PY
```

Replay validation artifacts:

- `solver_runs/kimi/replay_result.json`
- `solver_runs/minimax/replay_result.json`
- `solver_runs/kimi/public_results.log`
- `solver_runs/kimi/hidden_results.log`
- `solver_runs/minimax/public_results.log`
- `solver_runs/minimax/hidden_results.log`
- `solver_runs/gpt/rerun_2026_06_19/rerun_result.json`
- `solver_runs/gpt/rerun_2026_06_19/public_results.log`
- `solver_runs/gpt/rerun_2026_06_19/hidden_results.log`
