# GLM fresh rerun summary

## Status

PUBLIC-ONLY PASS, HIDDEN FAIL

## Model

`ollama/glm-5.2:cloud:xhigh`

## Evidence

- Patch: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `e840d8a60daeb38debb2131289239048dc9c933fda468525cc28ae2c81d97d96`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `1`
- Pre-hidden workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory artifacts: `rerun_2026_06_19/trajectory/`

## Notes

Not promoted. This run is retained as evidence that the current public task and tests did not elicit hidden-passing responsive behavior from this model family. Provider-internal stream chunks/session JSONL were not exposed for this run.
