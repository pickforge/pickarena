# V1 Flutter task backlog

Status: active note
Created: 2026-06-18

## Goal

First V1 Flutter expansion backlog, picked from the agent-assisted task-card triage. The aim is to broaden the official corpus beyond forms, list search, auth-redirect navigation, platform channels, and selection state, while keeping tasks deterministic and offline.

## First wave

Build these first. They add new capability slices with low flake risk.

| Task id | Why it is in the first wave | Verifier focus |
| --- | --- | --- |
| `async.refresh_deduplicator` | Best deterministic async-race/state task; high benchmark value, no emulator or goldens. | Completer-controlled futures: collapse concurrent refreshes, ignore stale out-of-order results, reach success on retry. Ban sleeps/timers. |
| `accessibility.quantity_stepper_semantics` | Fills the missing accessibility category. | Semantics labels/actions and disabled-at-limit state via state, not hidden text; real callback still fires. |
| `refactor.price_label_formatter` | Strongest behavior-preserving refactor candidate. | p2p: every current public price label preserved; single rounding/free-price rule across all consumers. |
| `persistence.offline_feed_preferences` | Offline persistence plus corrupt-value resilience. | Save/reload across simulated restart with a fake store; unknown/corrupt values fall back to default instead of throwing. |
| `ui.action_bar_overflow` | Responsive UI skill without golden-test brittleness. | Actions stay hittable at narrow/wide widths with no overflow; assert reachability via key + tap, not pixel positions. |

## Current status

As of 2026-06-19, the first-wave bundles are admitted and have V1+ evidence. Cross-slice DeepSWE readiness is tracked in `docs/plans/2026-06-19-first-wave-deepswe-readiness.md`; this backlog does not claim a DeepSWE finish, and every slice keeps `deepSWEComplete: false`.

## Second wave

Promote after the first wave QA loop is proven. Strong tasks, but each overlaps an existing official category.

- `state.undoable_cart_quantity` — undo/redo + total invariants (overlaps selection state).
- `navigation.checkout_result_pop` — typed result passing and stack identity (overlaps auth-redirect navigation).
- `theming.localized_empty_state` — theme-token + localization; assert theme-token source, not pixel contrast.

## Hold / rework

- `ui.snackbar_undo_lifecycle` — only promote with mandatory `fakeAsync`; otherwise highest flake risk.
- `localization.plural_badge_labels` — keep as a backfill "easy" localization task.

## Next action

Avoid another duplicate first-wave status pass. For DeepSWE readiness work, pick one shared blocker from `docs/plans/2026-06-19-first-wave-deepswe-readiness.md` and close it next. For V1-only work, explicitly choose one second-wave task instead of re-summarizing the first wave.
