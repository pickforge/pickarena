# KIMI fresh rerun summary

## Status

PUBLIC-ONLY PASS, HIDDEN FAIL

## Model

`ollama/kimi-k2.7-code:cloud:xhigh`

## Evidence

- Patch: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `f727b867e7b93e4dd72059e76c10ab707f54eab03dcb8cc99cbf112c4e76df92`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `1`
- Pre-hidden workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory artifacts: `rerun_2026_06_19/trajectory/`

## Notes

Not promoted. This run is retained as evidence that the current public task and tests did not elicit hidden-passing responsive behavior from this model family. Provider-internal stream chunks/session JSONL were not exposed for this run.
