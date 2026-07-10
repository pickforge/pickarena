# Kimi fresh repair rerun summary

## Status

PROMOTED: PUBLIC+HIDDEN PASS

## Model

`ollama/kimi-k2.7-code:cloud:xhigh`

## Evidence

- Patch diff: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `465d100194fd24d51c1b3fe36134156b73e939c04243d9566ed726fdc685e3d9`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `0`
- Workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory: `rerun_2026_06_19/trajectory/`
- Subagent run: `cf75c215/coder_4`; duration `83339ms`

## Notes

Promoted as clean replay evidence for this repaired public contract. Hidden replay logs are restricted evaluator-only. Provider-internal stream chunks/session JSONL remain unavailable.
