# Solver Report: accessibility.quantity_stepper_semantics

## Changed behavior

Added accessibility semantics to `QuantityStepper` in `lib/quantity_stepper.dart` while
preserving the public API (widget, constructor params `value`/`min`/`max`/`onChanged`, and
the static keys) and the compact minus / value / plus row with existing icons.

- Each control is wrapped in a `Semantics` node with `excludeSemantics: true` so the inner
  `IconButton`/`Text` semantics don't duplicate or leak; the parent node defines the
  accessible behavior.
- Decrease control: `label: 'Decrease quantity'`, `button: true`, `enabled: canDecrement`,
  `onTap` calling `onChanged(value - 1)` only when `value > min`.
- Increase control: `label: 'Increase quantity'`, `button: true`, `enabled: canIncrement`,
  `onTap` calling `onChanged(value + 1)` only when `value < max`.
- Value display: `label: 'Quantity'`, `value: '$value'` (no button), so the current
  quantity is announced as a semantic value.
- At `min`/`max` the corresponding control is disabled both visually
  (`IconButton.onPressed: null`) and to accessibility (`enabled: false`, `onTap: null`),
  so neither a visual tap nor a screen-reader tap calls `onChanged`.
- When enabled, a visual tap hits the `IconButton.onPressed` and a screen-reader tap hits
  the `Semantics.onTap`; each path calls `onChanged(value ± 1)` exactly once.

No visible label text was added, and the widget stays deterministic and offline
(no timers, network, platform channels, or goldens).

## Commands run

- `flutter pub get`
- `flutter test` (all 6 public tests pass before and after the change)
