## Summary

The fix is complete. Here's what I did:

**Root cause:** `_splitActions` ignored the available width and always returned all actions inline, so on narrow screens the `Row` overflowed and no overflow menu ever appeared.

**Solution** (modified only `lib/responsive_action_bar.dart`):
- Kept the entire public API and static keys intact.
- Made `_splitActions` width-aware inside `LayoutBuilder`:
  - Stable-sorts actions by `priority` (lower first, ties keep input order).
  - Measures real button widths with `TextPainter` using `labelLarge` + ambient `TextScaler`, plus Material button overhead and the 64 px minimum floor — so it adapts to text scaling and label widths without hardcoding examples.
  - If everything (all secondary actions + primary) fits within `maxWidth` → all inline, no overflow button.
  - Otherwise → primary stays visible, all secondary actions move behind the `MenuAnchor` overflow menu (keyed `overflowButtonKey`, items keyed `overflowItemKey(id)`), each showing the original label/icon and calling `onPressed` once.
- Kept the overflow control accessible via `Semantics(label: 'More actions', button, onTap)` + `IconButton` tooltip.

**Verification:**
- `flutter pub get` ✓
- `flutter test test/responsive_action_bar_test.dart` → 3/3 passed ✓
- `flutter analyze lib/responsive_action_bar.dart` → no issues ✓

A report was written to `solver_report.md`.