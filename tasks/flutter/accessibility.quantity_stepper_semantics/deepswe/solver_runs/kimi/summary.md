# KIMI fresh rerun summary

## Status

PUBLIC-ONLY PASS, HIDDEN FAIL

## Model

`ollama/kimi-k2.7-code:cloud:xhigh`

## Evidence

- Patch: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `5024d8219fc7a2cc8980db9832d9effb52e80fb00056778407a2984075c31244`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `1`
- Pre-hidden workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory artifacts: `rerun_2026_06_19/trajectory/`

## Notes

Not promoted; retained as evidence that public tests alone are insufficient for accessibility semantics.
Provider-internal stream chunks/session JSONL were not exposed for this run.
