# GPT fresh rerun summary

## Status

PUBLIC-ONLY PASS, HIDDEN FAIL

## Model

`openai-codex/gpt-5.5:xhigh`

## Evidence

- Patch: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `d76c185ed99b457eef01be06d8fef2e567eef0c86a92c80fd8337d1477699a9a`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `1`
- Pre-hidden workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory artifacts: `rerun_2026_06_19/trajectory/`

## Notes

Not promoted. This run is retained as evidence that the current public task and tests did not elicit hidden-passing responsive behavior from this model family. Provider-internal stream chunks/session JSONL were not exposed for this run.
