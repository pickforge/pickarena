Done. All 3 public tests pass and the analyzer is clean.

## Summary

The bug was in `_splitActions`, a stub that always returned every action inline and nothing in overflow—so the overflow control never appeared on compact layouts.

I implemented a deterministic width-aware split in `lib/responsive_action_bar.dart:67`:

- **Ordering**: stable sort by ascending `priority` (lower stays inline longer), ties preserve input order via original index.
- **Measurement**: `TextPainter` using ambient `Directionality` + `MediaQuery.textScalerOf` (honors text scaling) and `labelLarge` style, plus calibrated chrome constants (verified against real rendered widget widths).
- **Split**: if everything fits left of the primary CTA, keep all inline with no overflow button (wide case); otherwise reserve space for the overflow control and keep the longest fitting *prefix* of the priority order, sending the rest to overflow.

This guarantees the inline set is always a prefix of the priority order — lower-priority actions stay inline first, ties keep input order, every remaining action is reachable from overflow, and nothing is duplicated. All public keys and APIs are preserved.

Verified: `flutter test` (3/3 pass), `flutter analyze` (clean), and probe tests across widths 640→320 plus 2.5x text scaling. Report written to `solver_report.md`.