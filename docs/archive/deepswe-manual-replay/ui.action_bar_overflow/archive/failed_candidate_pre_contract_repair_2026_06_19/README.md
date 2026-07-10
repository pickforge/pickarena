# Action bar overflow DeepSWE candidate

This directory contains V2/DeepSWE hardening evidence for `ui.action_bar_overflow`.

## Current status

- `deepSWEComplete: false`.
- `replayVerified: false`.
- This is a failed candidate slice: GPT, GLM, Opus, MiniMax, and Kimi all passed public replay but failed hidden replay.
- 10-run hidden replay loop passed expectations for the failed candidate: baseline and all five solver reruns failed hidden `10/10`; reference passed hidden `10/10`.
- Full task QA repetition passed `5/5` with `--hidden-flake-runs 5`, so the canonical task remains admitted.
- Duration/cost/token telemetry is captured from Pi subagent metadata and measured local replay commands, but provider-internal stream chunks/session JSONL were not exposed.

## Artifact map

- `replay_manifest.json` is the main evidence index.
- `replay_log.md` summarizes patch replay outcomes.
- `model_audit.yaml` records model evidence and remaining blockers.
- `flake_report.json` summarizes failed-candidate 10-run hidden replay and full QA repetition.
- `telemetry_report.json` summarizes subagent usage and command telemetry.
- `prompt_verifier_bijection.md` and `f2p_checklist.md` are restricted evaluator-only.
- `p2p_checklist.md` is solver-facing and included in leakage scan scope.
- Hidden replay logs, hidden-side pub-get logs, and raw flake-loop logs are restricted evaluator-only.

## Remaining blockers

- At least three fresh solver families must produce clean public+hidden replay before this slice can be promoted.
- Clean committed provenance / `gitDirty=false` run is not available.
- Authored-by provenance is not durably recorded.
- Provider-internal stream chunks/session JSONL are not exposed.
- Workspace isolation is supported by sanitized snapshots with zero restricted path hits, but not fully proven.
