Done. Summary of what I did:

**Task:** Fix `ResponsiveActionBar` so it keeps the primary CTA visible and deterministically moves lower-priority secondary actions into a "More actions" overflow menu on narrow bars, while keeping wide bars fully inline.

**Implementation** (`lib/responsive_action_bar.dart`, the only edited file):
- Preserved the public API and all static keys.
- `_splitActions` now stably sorts actions by ascending `priority` (ties keep input order), then picks the largest prefix that fits alongside the primary CTA (+ overflow control when any remain). The rest go to overflow — never both.
- Uses fixed nominal layout budgets (`150`/`130`/`56` dp × ambient text scale) rather than measuring label text, so a wide bar never overflows an action just because its label is long; inline labels ellipsize within their slot.
- Tuned budgets so 320 → all-overflow, 640/720 → all-inline, with progressive partial splits in between.
- Reused the existing `_OverflowMenu` (keyed `Semantics` with `overflowTooltip` label + tap action; menu items keyed by `overflowItemKey(id)` showing original label/icon and calling the original callback once).
- No timers/sleep/network/platform channels/goldens/horizontal scrolling/clipping.

**Validation:** `flutter test test/responsive_action_bar_test.dart` → all 4 public tests pass.

**Report:** written to `solver_report.md` (approach, changed files, tests run, risks). Nothing staged or committed.