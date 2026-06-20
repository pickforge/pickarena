All 3 public tests pass, analyze is clean, and `solver_report.md` is written.

## Summary

**Changed**
- `lib/responsive_action_bar.dart` — Replaced the placeholder `_splitActions` (which always returned every action in `inline`) with a real `LayoutBuilder`-driven partition. Widths are measured via `TextPainter` with the current `MediaQuery.textScalerOf(context)`, then a two-phase greedy fit decides which actions go inline vs. into a `MenuAnchor` overflow menu. The `Row` keeps inline actions, the overflow trigger (if needed), and an `Expanded` slot that right-aligns the primary `FilledButton` keyed by `primaryButtonKey`.

**Validated**
- `flutter test` — all 3 public tests pass (wide 640 px keeps all inline / no overflow; compact 320 px moves all to overflow; API keys remain stable across re-layouts).
- `flutter analyze` — no issues.

**Risks/uncertainties**
- Width estimates use calibrated Material 3 padding constants; a heavily customized theme could diverge slightly. Algorithm is intentionally a little conservative on compact widths.

**Next action**
None — public tests are green.