# Solver Report: `ui.action_bar_overflow`

## Problem
`ResponsiveActionBar` placed every secondary action inline in a single `Row`,
which overflows on narrow widths / large text scaling. `_splitActions` was a
stub that always returned all actions inline and nothing in overflow, so the
overflow control never appeared on compact layouts. Two of three public tests
failed (compact + key-stability cases).

## Change (lib/responsive_action_bar.dart)
Implemented a deterministic, width-aware split in `_splitActions`:

- **Ordering** (`_orderedByPriority`): stable sort by ascending `priority`
  (lower stays inline longer); ties fall back to original input index, so equal
  priorities preserve input order.
- **Measurement**: uses a `TextPainter` with the ambient `Directionality`,
  `MediaQuery.textScalerOf` (honors text scaling), and `labelLarge` style to
  estimate each label width, plus calibrated chrome constants for the icon +
  padding of `TextButton.icon` (`+54`), the primary `FilledButton` (`+48`), and
  the overflow `IconButton` (`48`), with an `8px` inter-item gap. Constants were
  calibrated against real rendered widths captured from the widget tree.
- **Split logic**:
  - If all actions fit left of the primary CTA, keep them all inline and render
    **no** overflow button (wide case).
  - Otherwise reserve room for the overflow control and greedily keep the
    longest *prefix* of the priority order that fits; the rest go to overflow.
  - The inline set is always a prefix of the priority order, guaranteeing
    lower-priority actions stay inline first, ties keep input order, and every
    remaining action is reachable from overflow with no duplication.
- Non-finite `maxWidth` / empty actions fall back to all-inline.

The primary `FilledButton` (keyed `primaryButtonKey`), inline action keys,
overflow button key, and overflow item keys are all preserved unchanged. No
timers, network, platform channels, scrolling, or clipping were introduced.

## Verification
- `flutter pub get` — ok.
- `flutter analyze lib/responsive_action_bar.dart` — No issues found.
- `flutter test` — all 3 public tests pass.
- Throwaway probe tests (removed) confirmed across widths 640→320:
  monotone prefix split (`save` inline longest, then `share`, then `compare`),
  overflow button appears only on compact layouts, no action rendered both
  inline and in overflow, all actions reachable, large text scaling (2.5x at
  640px) forces overflow, and equal-priority ties preserve input order.

## Commands run
```
flutter pub get
flutter analyze lib/responsive_action_bar.dart
flutter test
```
