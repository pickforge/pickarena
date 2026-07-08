# GPT fresh rerun summary

## Status

PASSING CLEAN REPLAY

## Model

`openai-codex/gpt-5.5:xhigh`

## Evidence

- Patch: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `884b00a17ad0d65bf2c209ed633828fbaded1af8c8d9ab59ac3bad1bf50b52a9`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `0`
- Pre-hidden workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory artifacts: `rerun_2026_06_19/trajectory/`

## Notes

Promoted as a passing fresh solver. Provider-internal stream chunks/session JSONL were not exposed for this run.
