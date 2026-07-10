# Action bar overflow DeepSWE repair evidence

This directory contains repaired-contract DeepSWE evidence for `ui.action_bar_overflow`.

## Current status

- `deepSWEComplete: false`.
- `replayVerified: true`.
- `failedCandidate: false`.
- Promoted fresh solver families: `gpt`, `minimax`, `kimi`.
- Failed fresh solver family: `glm`.
- Aborted/unavailable family: `opus` (no active Opus solver run).
- The pre-contract-repair failed candidate is preserved under `archive/failed_candidate_pre_contract_repair_2026_06_19/`.
- Fresh repair subagent input/output/meta and duration/token/cost metadata are captured for `gpt`, `glm`, `minimax`, and `kimi`; aborted Opus metadata is top-level only.

## Artifact map

- `replay_manifest.json` is the main evidence index.
- `solver_runs/{gpt,glm,minimax,kimi}/rerun_2026_06_19/` contains patches, snapshots, trajectory metadata, and replay results.
- `command_telemetry/` contains public replay logs plus restricted hidden replay logs.
- `flake_runs_10/` contains 10-run replay-loop summaries and restricted raw run logs.
- `qa_repetition/` contains 5x QA repetition results, summaries, and restricted raw run logs.
- `replay_log.md`, `model_audit.yaml`, `flake_report.json`, `telemetry_report.json`, and `leakage_audit.md` summarize the evidence.
- `p2p_checklist.md` is solver-facing.
- `f2p_checklist.md` and `prompt_verifier_bijection.md` are restricted evaluator-only.

## Remaining blockers

- Workspace isolation is not fully proven.
- Clean committed provenance is not available.
- Authored-by provenance is unknown.
- Provider-internal stream chunks/session JSONL are not exposed.
