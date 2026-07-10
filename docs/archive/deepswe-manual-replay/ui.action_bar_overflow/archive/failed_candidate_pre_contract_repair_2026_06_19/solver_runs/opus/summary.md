# OPUS fresh rerun summary

## Status

PUBLIC-ONLY PASS, HIDDEN FAIL

## Model

`anthropic/claude-opus-4-8:xhigh`

## Evidence

- Patch: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `8a10bb0463741a2a7912194e7ab9636feae8e3d5f5f4528e94585f0aef287cfa`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `1`
- Pre-hidden workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory artifacts: `rerun_2026_06_19/trajectory/`

## Notes

Not promoted. This run is retained as evidence that the current public task and tests did not elicit hidden-passing responsive behavior from this model family. Provider-internal stream chunks/session JSONL were not exposed for this run.
