# First-wave workspace-isolation audit

Status: active evidence note
Created: 2026-06-19

This is artifact-scope evidence over existing DeepSWE rerun snapshots and leakage artifacts. It does not flip `workspaceIsolationVerified` and does not claim full DeepSWE completion.

JSON evidence: [`2026-06-19-first-wave-workspace-isolation-audit.json`](./2026-06-19-first-wave-workspace-isolation-audit.json)

| Task | Slice state | Snapshots audited | Leakage scan | Restricted path hits | High-signal content hits | Note |
| --- | --- | ---: | --- | ---: | ---: | --- |
| `async.refresh_deduplicator` | `clean_replay_verified_deepswe_pending` | 3 | pass / 0 findings | 0 | 0 | pending shared blockers |
| `accessibility.quantity_stepper_semantics` | `v2-deepswe-slice-in-progress` | 5 | pass / 0 findings | 0 | 0 | pending shared blockers |
| `refactor.price_label_formatter` | `v2-deepswe-slice-in-progress` | 4 | pass / 0 findings | 0 | 0 | pending shared blockers |
| `persistence.offline_feed_preferences` | `v2-deepswe-slice-in-progress` | 4 | pass / 0 findings | 0 | 0 | pending shared blockers |
| `ui.action_bar_overflow` | `contract-repaired-replay-verified-incomplete-provenance` | 4 | pass / 0 findings; 75 files checked | 0 | 0 | accepted repair evidence: gpt, minimax, and kimi promoted; GLM failed; opus unavailable |

Active snapshots audited: 20. Failed candidate slices: none. Generic bare-word `hidden` wording is counted separately in the JSON. No snippets or file contents are included.

Historical note: the pre-contract-repair `ui.action_bar_overflow` failed candidate is archived and excluded from active counts.

## Next action

Use this as artifact-scope workspace evidence. Remaining blockers still require provider/session export, clean provenance, authored-by provenance, stronger runtime workspace-isolation proof, and non-benchmark performance-sampling caveats.
