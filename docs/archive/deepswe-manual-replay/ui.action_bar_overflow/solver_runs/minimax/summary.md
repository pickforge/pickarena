# MiniMax fresh repair rerun summary

## Status

PROMOTED: PUBLIC+HIDDEN PASS

## Model

`ollama/minimax-m3:cloud:xhigh`

## Evidence

- Patch diff: `rerun_2026_06_19/solver.patch`
- Patch SHA-256: `de079f24ce175c8041b97c711baf6bdd6035098e267cf9d5fe50b07792ca75a7`
- Public replay: exit `0`
- Hidden replay after separate injection: exit `0`
- Workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`
- Subagent trajectory: `rerun_2026_06_19/trajectory/`
- Subagent run: `cf75c215/coder_3`; duration `518440ms`

## Notes

Promoted as clean replay evidence for this repaired public contract. Hidden replay logs are restricted evaluator-only. Provider-internal stream chunks/session JSONL remain unavailable.
