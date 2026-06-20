# GPT fresh repair rerun summary

## Status

PROMOTED: PUBLIC+HIDDEN PASS

## Model

`openai-codex/gpt-5.5:xhigh`

## Evidence

- Patch diff: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `c0c2136d7ab897542e5284540c9995f88926c2f07a7c931da5db1233b5326816`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `0`
- Workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory: `rerun_2026_06_19/trajectory/`
- Subagent run: `cf75c215/coder_0`; duration `234250ms`

## Notes

Promoted as clean replay evidence for this repaired public contract. Hidden replay logs are restricted evaluator-only. Provider-internal stream chunks/session JSONL remain unavailable.
