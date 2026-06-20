# MINIMAX fresh rerun summary

## Status

PUBLIC-ONLY PASS, HIDDEN FAIL

## Model

`ollama/minimax-m3:cloud:xhigh`

## Evidence

- Patch: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `78bfdf5b8f719c0a457e1674b89d69f1df67c164c7a717681661e5e2d87eed6c`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `1`
- Pre-hidden workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory artifacts: `rerun_2026_06_19/trajectory/`

## Notes

Not promoted; retained as evidence that public tests alone are insufficient for accessibility semantics.
Provider-internal stream chunks/session JSONL were not exposed for this run.
