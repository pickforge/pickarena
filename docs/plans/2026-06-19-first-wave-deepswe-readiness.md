# First-wave DeepSWE readiness checkpoint

Status: active note
Created: 2026-06-19

## Scope

Tracks the five first-wave V1 Flutter bundles after V1+ and DeepSWE attempts. This is not a DeepSWE completion claim, and every slice keeps `deepSWEComplete: false`.

## Current state

- First-wave bundles admitted: `async.refresh_deduplicator`, `accessibility.quantity_stepper_semantics`, `refactor.price_label_formatter`, `persistence.offline_feed_preferences`, `ui.action_bar_overflow`.
- V1+ solver/audit done for all five.
- Official regression passed: `cd app && flutter test test/tasks/official_file_backed_task_test.dart` in `27:47` after the action-bar contract repair.
- Artifact-scope workspace-isolation evidence is captured in `docs/plans/2026-06-19-first-wave-workspace-isolation-audit.md`.
- Artifact-scope performance/duration sampling is captured in `docs/plans/2026-06-19-first-wave-performance-sampling-audit.md`; it is not a statistical benchmark or DeepSWE completion claim.
- First-wave provenance gap audit exists at `docs/plans/2026-06-19-first-wave-provenance-gap-audit.md` and `docs/plans/2026-06-19-first-wave-provenance-gap-audit.json`; it is a gap inventory and does not complete DeepSWE/provenance.
- Final completion blocker audit exists at `docs/plans/2026-06-19-final-deepswe-completion-blocker-audit.md`; it confirms task artifacts should stay unchanged until a blocker owner acts.
- Clean-provenance staging is prepared, dry-run verified, and backed by read-only git/link/content-hygiene review evidence in `docs/plans/2026-06-20-clean-provenance-approval-packet.md`, pending explicit user approval.
- Required-sandbox Task QA replay now admits all five first-wave bundles under Bubblewrap; this strengthens Task QA runtime evidence but does not close clean replay or solver/provider proof.
- The Droid harness can start under Bubblewrap and the headless path persists sanitized `runtimeBoundary` metadata, but provider/session success remains blocked until a maintainer approves a Droid/Bubblewrap auth strategy in `docs/plans/2026-06-20-droid-bubblewrap-auth-approval-packet.md`.
- `ui.action_bar_overflow` now has accepted contract-repaired hardening evidence: gpt, minimax, and kimi pass both public and hidden replay; GLM remains failed solver evidence; durable `cf75c215` subagent metadata is captured for active reruns, while Opus remains aborted with no active solver run.
- Full DeepSWE remains blocked.

## Slice summary

| Task | Corpus state | DeepSWE slice state | Current limitation |
| --- | --- | --- | --- |
| `async.refresh_deduplicator` | admitted + accepted hardening evidence | `deepSWEComplete: false` | shared blockers |
| `accessibility.quantity_stepper_semantics` | admitted + accepted hardening evidence | `deepSWEComplete: false` | shared blockers |
| `refactor.price_label_formatter` | admitted + accepted hardening evidence | `deepSWEComplete: false` | shared blockers |
| `persistence.offline_feed_preferences` | admitted + accepted hardening evidence | `deepSWEComplete: false` | shared blockers |
| `ui.action_bar_overflow` | admitted + accepted contract-repaired hardening evidence; 3 promoted solvers | `deepSWEComplete: false` | shared blockers |

## Shared blockers

- provider-internal stream/session export gaps
- clean committed provenance / `gitDirty=false`
- durable authored-by provenance
- stronger runtime workspace isolation proof beyond artifact-scope audit; Droid/Bubblewrap provider-session proof needs an approved auth strategy before implementation or rerun
- performance evidence is artifact-scope sampled, not a statistical benchmark or full DeepSWE completion claim

## History note

The pre-contract-repair `ui.action_bar_overflow` failed candidate is archived and excluded from active counts.

## Artifact pointers

- [`tasks/flutter/async.refresh_deduplicator/deepswe/README.md`](../../tasks/flutter/async.refresh_deduplicator/deepswe/README.md)
- [`tasks/flutter/accessibility.quantity_stepper_semantics/deepswe/README.md`](../../tasks/flutter/accessibility.quantity_stepper_semantics/deepswe/README.md)
- [`tasks/flutter/refactor.price_label_formatter/deepswe/README.md`](../../tasks/flutter/refactor.price_label_formatter/deepswe/README.md)
- [`tasks/flutter/persistence.offline_feed_preferences/deepswe/README.md`](../../tasks/flutter/persistence.offline_feed_preferences/deepswe/README.md)
- [`tasks/flutter/ui.action_bar_overflow/deepswe/README.md`](../../tasks/flutter/ui.action_bar_overflow/deepswe/README.md)
- [`docs/plans/2026-06-19-first-wave-workspace-isolation-audit.md`](./2026-06-19-first-wave-workspace-isolation-audit.md)
- [`docs/plans/2026-06-19-first-wave-performance-sampling-audit.md`](./2026-06-19-first-wave-performance-sampling-audit.md)
- [`docs/plans/2026-06-19-first-wave-performance-sampling-audit.json`](./2026-06-19-first-wave-performance-sampling-audit.json)
- [`docs/plans/2026-06-19-first-wave-provenance-gap-audit.md`](./2026-06-19-first-wave-provenance-gap-audit.md)
- [`docs/plans/2026-06-19-first-wave-provenance-gap-audit.json`](./2026-06-19-first-wave-provenance-gap-audit.json)
- [`docs/plans/2026-06-19-final-deepswe-completion-blocker-audit.md`](./2026-06-19-final-deepswe-completion-blocker-audit.md)
- [`docs/plans/2026-06-20-clean-provenance-approval-packet.md`](./2026-06-20-clean-provenance-approval-packet.md)
- [`docs/plans/2026-06-20-provider-session-export-decision-packet.md`](./2026-06-20-provider-session-export-decision-packet.md)
- [`docs/plans/2026-06-20-authored-by-provenance-request.md`](./2026-06-20-authored-by-provenance-request.md)
- [`docs/plans/2026-06-20-first-wave-required-sandbox-qa-evidence.md`](./2026-06-20-first-wave-required-sandbox-qa-evidence.md)
- [`docs/plans/2026-06-20-solver-agent-harness-boundary-proof-plan.md`](./2026-06-20-solver-agent-harness-boundary-proof-plan.md)
- [`docs/plans/2026-06-20-droid-bubblewrap-auth-approval-packet.md`](./2026-06-20-droid-bubblewrap-auth-approval-packet.md)

## Next action

Keep first-wave task artifacts unchanged. Work is blocked until a blocker owner acts. The next non-duplicate step needs explicit approval or owner input for clean-provenance staging/commit and clean replay, Droid/Bubblewrap auth strategy before any provider-session rerun, provider/session export decision, or authored-by provenance source.
