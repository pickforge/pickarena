# GLM fresh repair rerun summary

## Status

PUBLIC PASS, HIDDEN FAIL

## Model

`ollama/glm-5.2:cloud:xhigh`

## Evidence

- Patch diff: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `fa8ecb4c137c234d636a82013a07805c6a7d554c02b7ae636182cff464edb67a`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `1`
- Workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory: `rerun_2026_06_19/trajectory/`
- Subagent run: `cf75c215/coder_1`; duration `277498ms`

## Notes

Not promoted; retained as the fresh failed-solver family for this repaired public contract. Hidden replay logs are restricted evaluator-only. Provider-internal stream chunks/session JSONL remain unavailable.
