# Solver Report — `ui.action_bar_overflow`

## Problem
`ResponsiveActionBar` always laid every secondary action out in a single
horizontal `Row` (`_splitActions` ignored the available width and returned all
actions inline). On narrow screens this overflows and pushes lower-priority
actions out of reach; no overflow menu was ever shown.

## Changed behavior (production file `lib/responsive_action_bar.dart` only)
- Public API preserved: `ResponsiveActionBarAction`, `ResponsiveActionBar`,
  `primaryButtonKey`, `overflowButtonKey`, `actionButtonKey(id)`,
  `overflowItemKey(id)`, `primaryLabel`, `onPrimaryPressed`, `actions`,
  `overflowTooltip` are all unchanged.
- Primary CTA stays a direct `FilledButton` keyed by `primaryButtonKey`,
  rendered on the right via `Spacer()`.
- A width-aware split (`_splitActions`) now decides the layout inside
  `LayoutBuilder`:
  - Secondary actions are ordered by a **stable sort on `priority`** (lower
    values first, ties keep input order).
  - The preferred inline width is measured from the actual text (via
    `TextPainter`) using `Theme.textTheme.labelLarge` and the ambient
    `MediaQuery.textScalerOf`, plus Material button overhead (icon + spacing +
    padding) and the 64 px minimum button floor; the primary button width is
    measured the same way. This honors ambient text scaling and label widths
    without hardcoding any example.
  - If the preferred width (all secondary actions inline + primary) fits within
    `maxWidth`, **all secondary actions stay inline and no overflow control is
    shown**.
  - Otherwise, the primary CTA stays visible and **every secondary action moves
    behind the overflow menu**, so nothing overflows and no action is rendered
    both inline and in the menu.
- Overflow control is a `MenuAnchor` with an `IconButton` (keyed by
  `overflowButtonKey`) wrapped in a `Semantics(label: 'More actions', button,
  onTap)` for accessibility; tapping toggles the menu.
- Overflow entries are `MenuItemButton`s keyed by `overflowItemKey(id)`,
  showing the original `label` and `icon` and calling the original `onPressed`
  exactly once.
- Deterministic/offline: no timers, sleeps, network, platform channels, goldens,
  horizontal scrolling, or clipping.

## Commands run
- `flutter pub get`
- `flutter test test/responsive_action_bar_test.dart` → `All tests passed!` (3/3)
- `flutter analyze lib/responsive_action_bar.dart` → `No issues found!`