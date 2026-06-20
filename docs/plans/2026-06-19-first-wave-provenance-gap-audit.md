# First-wave provenance gap audit

Status: active gap inventory
Created: 2026-06-19

JSON: [2026-06-19-first-wave-provenance-gap-audit.json](./2026-06-19-first-wave-provenance-gap-audit.json)

Existing first-wave artifacts provide durable run IDs/model-family telemetry for all five slices, including active repaired `ui.action_bar_overflow` subagent metadata from run `cf75c215`. Provenance is still not complete: provider-internal stream exports are unavailable, clean committed `gitDirty=false` provenance is unavailable, authored-by provenance is unknown, and runtime workspace isolation remains artifact-scope only. `ui.action_bar_overflow` meets the promoted solver threshold with 3 fresh public+hidden successes out of 3 required. Every slice remains `deepSWEComplete: false`; this audit is a gap inventory, not a completion claim.

## Summary

| Task | Run IDs/families | Clean provenance | Authored-by provenance | Provider streams | State/note |
| --- | --- | --- | --- | --- | --- |
| `async.refresh_deduplicator` | legacy `54e66617`: kimi/minimax; fresh `2c8d8e17`: kimi/minimax; fresh `9e72b221`: gpt | unavailable; admission `gitDirty=true` | unknown | 0 provider-internal chunks captured | accepted artifact-scope slice; `deepSWEComplete: false`; 3 session JSONL digest records counted only |
| `accessibility.quantity_stepper_semantics` | `418a9192`: gpt/glm/minimax/kimi; `90f0896e`: opus | unavailable; admission `gitDirty=true` | unknown | 0 provider-internal chunks captured | accepted artifact-scope slice; `deepSWEComplete: false` |
| `refactor.price_label_formatter` | `f2ed0622`: gpt/minimax/kimi; `9e788d86`: glm | unavailable; admission `gitDirty=true` | unknown | 0 provider-internal chunks captured | accepted artifact-scope slice; `deepSWEComplete: false` |
| `persistence.offline_feed_preferences` | `13254af7`: gpt/minimax/glm/kimi | unavailable; admission `gitDirty=true` | unknown | 0 provider-internal chunks captured | accepted artifact-scope slice; `deepSWEComplete: false` |
| `ui.action_bar_overflow` | `cf75c215`: gpt/glm/minimax/kimi; aborted `cf75c215`: opus | unavailable; admission `gitDirty=true` | unknown | 0 provider-internal chunks captured | accepted artifact-scope slice; promoted threshold met 3/3; `deepSWEComplete: false`; no active Opus solver run |

Historical note: the pre-contract-repair `ui.action_bar_overflow` failed candidate is archived and excluded from active run IDs, counts, and telemetry.

## Blockers

- Provider stream/session gap requires provider/tool export support.
- Clean `gitDirty=false` requires user approval to stage/commit and rerun from clean committed state.
- Authored-by provenance requires durable source/user-provided provenance; do not infer.
- Runtime workspace isolation is artifact-scope only; needs runtime/tool-level proof.
