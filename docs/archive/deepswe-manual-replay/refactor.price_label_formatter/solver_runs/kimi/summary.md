# KIMI fresh rerun summary

## Status

PUBLIC-ONLY PASS, HIDDEN FAIL

## Model

`ollama/kimi-k2.7-code:cloud:xhigh`

## Evidence

- Patch: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `fe1269859a6e1a6b76cb25444fdec3fb51da4062690e266159719ded4a77d9ad`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `1`
- Pre-hidden workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory artifacts: `rerun_2026_06_19/trajectory/`

## Notes

Not promoted; retained as evidence that public tests alone are insufficient.
Provider-internal stream chunks/session JSONL were not exposed for this run.
