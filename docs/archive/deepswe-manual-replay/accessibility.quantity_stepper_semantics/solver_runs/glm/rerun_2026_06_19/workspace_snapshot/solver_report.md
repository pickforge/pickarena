# Solver Report

## Task
`accessibility.quantity_stepper_semantics` — make `QuantityStepper` pass an accessibility audit while preserving the public API and visible layout.

## Changed behavior (production file `lib/quantity_stepper.dart`)

1. **Decrease control semantics**: wrapped the minus `IconButton` in a `Semantics` with
   `label: 'Decrease quantity'`, `button: true`, `enabled: value > min`, and an `onTap`
   that calls `onChanged(value - 1)` only when enabled. The `IconButton`'s own semantics are
   excluded (`excludeSemantics: true`) so the announced label is exactly `Decrease quantity`.

2. **Increase control semantics**: same treatment for the plus `IconButton`, with
   `label: 'Increase quantity'`, `enabled: value < max`, and `onTap` calling
   `onChanged(value + 1)` only when enabled.

3. **Value semantics**: wrapped the value `Text` in a `Semantics` with
   `label: 'Quantity'` and `value: '$value'` (the number as the semantic text value),
   excluding the text's own semantics so the screen reader announces `Quantity, <n>`.

4. **Boundary disabling (bug fix)**: the original `onPressed` callbacks were always
   non-null (they returned `null` from a ternary inside the closure), so the buttons were
   never actually disabled. Now `onPressed` is `null` at the boundary (`value > min` /
   `value < max` ternary at the `onPressed` level), so:
   - the decrease control is disabled to both pointer input and accessibility at `min`,
   - the increase control is disabled to both pointer input and accessibility at `max`,
   - `onChanged` is never called at the boundaries.

5. **Single invocation**: visual taps go through `IconButton.onPressed`; screen-reader
   activations go through the `Semantics.onTap`. The two paths are independent, and each
   calls `onChanged(value ± 1)` exactly once when enabled.

6. **Preserved**: public constructor (`value`, `min`, `max`, `onChanged`), the three
   static keys, the compact minus/value/plus `Row`, and the existing `Icons.remove` /
   `Icons.add` icons. No visible label text was added; no timers, delays, network, platform
   channels, or golden images introduced.

## Commands run
- `flutter pub get`
- `flutter test test/quantity_stepper_test.dart` → 6/6 passed.