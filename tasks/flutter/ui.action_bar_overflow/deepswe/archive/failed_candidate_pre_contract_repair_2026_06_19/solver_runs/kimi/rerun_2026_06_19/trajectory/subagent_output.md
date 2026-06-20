Done.

**Changed** `lib/responsive_action_bar.dart`:
- `ResponsiveActionBar` now measures text/button widths inside `LayoutBuilder` and splits secondary actions into inline vs. overflow based on available width.
- Lower-priority actions stay inline longer; ties preserve input order. Overflow menu uses the original label, icon, and callback.
- Primary CTA remains a direct `FilledButton` with the static key; overflow button keeps its key and tooltip.
- Removed the old `Flexible` shrink-to-fit wrappers and added `Row.spacing` so the bar no longer masks overflow by squeezing buttons.

**Validated**
- `flutter pub get`
- `flutter test test/responsive_action_bar_test.dart` — all 3 public tests pass.
- `flutter analyze lib/responsive_action_bar.dart` — no issues.

Report written to `solver_report.md`.