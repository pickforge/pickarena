Done. Summary:

**Changed**
- `lib/responsive_action_bar.dart` — implemented deterministic split between inline and overflow using a `LayoutBuilder` + `TextPainter` measurement that honors `MediaQuery.textScalerOf`. Primary button stays a `FilledButton` keyed by `primaryButtonKey`. Overflow trigger is an `IconButton` keyed by `overflowButtonKey` wrapped in `Semantics(excludeSemantics: true, label: overflowTooltip, button: true, onTap: …)`. Overflow items are `MenuItemButton`s keyed by `overflowItemKey(id)` with original icon, label, and callback. Public `ResponsiveActionBarAction`, `ResponsiveActionBar`, and all static keys are preserved.

**Validated**
- `flutter test test/responsive_action_bar_test.dart` — 4/4 passed.
- `flutter analyze lib/` — no issues.

**Approach**
- All-or-nothing split: if measured total width (primary + all actions + gaps, with action label widths capped at 120 px text) fits in `constraints.maxWidth`, all actions go inline; otherwise all go to overflow. Actions are sorted by `(priority asc, input index asc)`. Label cap prevents long labels from forcing overflow on wide bars (matches the "must not move actions into overflow solely because unconstrained label text is wide" requirement).

**Risks/uncertainties**
- The all-or-nothing design is more conservative than a partial split; any width where the measured total exceeds the constraint collapses every action into overflow. This satisfies the public test cases and the "no required inline count" clause, but unknown widths between 320 and 640 always go to overflow rather than partially splitting.
- Overflow semantics rely on `excludeSemantics: true` to prevent the `IconButton`'s own tooltip semantics from doubling the label or creating a conflicting button node.

**Next action**
- None required from the solver; the public test suite passes and the report is written.