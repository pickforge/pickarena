# Solver Report: ui.action_bar_overflow

## Changed
- Implemented real width-based split in `ResponsiveActionBar._splitActions`.
- Secondary actions now render inline when there is room; lower-priority actions stay inline longest, with ties preserving input order. Remaining actions move to the overflow menu.
- The primary CTA stays a direct `FilledButton` keyed by `ResponsiveActionBar.primaryButtonKey`.
- The overflow control is a real `MenuAnchor` with `IconButton` keyed by `ResponsiveActionBar.overflowButtonKey`; menu items use `overflowItemKey(id)`, keep the original icon/label, and invoke the original callback.
- Added `Row.spacing` and removed the old `Flexible` wrappers so inline actions size naturally and the layout no longer relies on shrinking to avoid overflow.
- Width estimation uses `TextPainter` with the ambient `TextScaler` and `Directionality`, plus fixed overheads matching Material button/icon padding.

## Validated
- `flutter pub get`
- `flutter test test/responsive_action_bar_test.dart` — all 3 public tests pass.
- `flutter analyze lib/responsive_action_bar.dart` — no issues.

## Risks/uncertainties
- Width estimation assumes default Material button/icon geometry. Unusually large custom button themes could make the real layout slightly wider than estimated and potentially cause a rare Row overflow in edge cases.
- Long primary labels are not flexibly constrained; a very long primary label could exceed the available width when secondary actions are hidden.

## Next action
- Run hidden tests if available; no further changes planned unless a failure is reported.
