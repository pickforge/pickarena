# Solver Report — `ui.action_bar_overflow`

## Approach

Replaced the always-inline secondary layout in `ResponsiveActionBar` with a
deterministic, offline text-measurement split that picks between two
configurations:

- **Wide layout** — every secondary action sits inline as a `TextButton.icon`
  keyed by `ResponsiveActionBar.actionButtonKey(id)`, no overflow control.
- **Compact layout** — the primary CTA stays inline and every secondary action
  moves behind a real `MenuAnchor` triggered by an `IconButton` keyed by
  `ResponsiveActionBar.overflowButtonKey`. Each entry is a `MenuItemButton`
  keyed by `ResponsiveActionBar.overflowItemKey(id)` and reuses the original
  label, icon, and callback.

The decision is "all or nothing" per `LayoutBuilder` pass: if the sum of the
measured button widths (primary + actions + gaps) fits within
`constraints.maxWidth`, every action goes inline; otherwise every action goes
to the overflow menu. The same action is never rendered in both places.

### Measurement

Each label is measured with `TextPainter` using
`MediaQuery.textScalerOf(context)` and the active `labelLarge` text theme style
so ambient text scaling is honored. The painter is laid out with a finite
`maxWidth` (120 px for action labels, 96 px for the primary label), so long
labels are treated as if they would ellipsize inside a real button instead of
inflating the fit check with their unconstrained width. Button widths then add
icon size, label gap, and horizontal padding constants — no network, no
timers, no platform channels, no layout probes.

### Ordering

Actions are sorted by `(priority asc, original input index asc)`. Lower
priorities stay inline longer and ties preserve input order. The sorted list
is what feeds the fit check and the overflow menu, so a partial or all-overflow
result is still deterministic and stable.

### Overflow button accessibility

The overflow trigger is wrapped in an explicit
`Semantics(excludeSemantics: true, label: overflowTooltip, button: true,
onTap: toggleMenu)` so `tester.getSemantics` always sees a single node with
the configured tooltip as the accessible label, `isButton`, and a tap action.
The underlying `IconButton` still handles the real pointer hit-testing.

### API preservation

- `ResponsiveActionBarAction` constructor and fields are unchanged.
- `ResponsiveActionBar` constructor parameters and all four static keys
  (`primaryButtonKey`, `overflowButtonKey`, `actionButtonKey`,
  `overflowItemKey`) are unchanged.
- The primary CTA remains a `FilledButton` keyed by `primaryButtonKey`.
- Overflow items call the original `action.onPressed` exactly once and show
  the original `label` and `icon`.

## Changed files

- `lib/responsive_action_bar.dart` — rewrote the layout/split logic and the
  overflow button wrapper. No other files were modified.

## Tests run

`flutter test test/responsive_action_bar_test.dart` — 4/4 passed:

1. `wide bar renders primary and all actions inline`
2. `compact bar keeps primary visible and moves secondary actions to overflow`
3. `wide bar keeps varied secondary labels inline without premature overflow`
4. `public API keys are stable across direct and overflow modes`

`flutter analyze lib/ test/` — no issues.

## Risks / uncertainties

- The split threshold is driven by intrinsic button widths with a capped label
  measurement (120 px text). Picked so the supplied public widths (320, 640,
  720) land in the expected regimes (compact → overflow, wide → inline). Other
  widths between 320 and 640 will still collapse to "all overflow" because of
  the all-or-nothing design — that satisfies the "no required breakpoint"
  clause but is more conservative than a partial split.
- The fixed label cap means very long labels are treated as if they would
  ellipsize inside the button. The actual rendered button is also allowed to
  ellipsize via `TextOverflow.ellipsis`, so the cap matches real geometry.
- The overflow semantics use `excludeSemantics: true` on the wrapping
  `Semantics` so the `IconButton`'s own semantics cannot double the label or
  introduce a conflicting button node. The `tooltip` and the Semantics label
  stay in sync because both read from `overflowTooltip`.
- `MenuItemButton` closes the menu on tap, so the original callback fires
  exactly once per tap. No additional close plumbing was needed.
