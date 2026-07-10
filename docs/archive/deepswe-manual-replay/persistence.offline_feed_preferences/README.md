# Offline feed preferences DeepSWE slice

This directory contains V2/DeepSWE hardening evidence for `persistence.offline_feed_preferences`.

## Current status

- `deepSWEComplete: false`.
- Four fresh solver families have clean public+hidden replay: GPT, MiniMax, GLM, and Kimi.
- 10-run hidden replay loop passed expectations: baseline failed `10/10`; reference and all four fresh solvers passed `10/10`.
- Full task QA repetition passed `5/5` with `--hidden-flake-runs 5`.
- Duration/cost/token telemetry is captured from Pi subagent metadata and measured local replay commands, but provider-internal stream chunks/session JSONL were not exposed.

## Artifact map

- `replay_manifest.json` is the main evidence index.
- `replay_log.md` summarizes patch replay outcomes.
- `model_audit.yaml` records model evidence and remaining blockers.
- `flake_report.json` summarizes 10-run hidden replay and full QA repetition.
- `telemetry_report.json` summarizes subagent usage and command telemetry.
- `prompt_verifier_bijection.md` and `f2p_checklist.md` are restricted evaluator-only.
- `p2p_checklist.md` is solver-facing and included in leakage scan scope.
- Hidden replay logs, hidden-side pub-get logs, and raw flake-loop logs are restricted evaluator-only.

## Remaining blockers

- Clean committed provenance / `gitDirty=false` run is not available.
- Authored-by provenance is not durably recorded.
- Provider-internal stream chunks/session JSONL are not exposed.
- Workspace isolation is supported by sanitized snapshots with zero restricted path hits, but not fully proven.
