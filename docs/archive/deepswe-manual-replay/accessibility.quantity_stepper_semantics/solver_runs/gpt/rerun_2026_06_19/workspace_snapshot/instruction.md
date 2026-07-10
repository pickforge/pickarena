Fix `QuantityStepper` so the cart quantity stepper passes an accessibility audit.

Context: `QuantityStepper` is a compact control with a minus button, the current quantity,
and a plus button in a single row. It works visually, but screen-reader users cannot tell
what the controls do or what the current quantity is, and the boundary buttons are still
reachable when they should be inert.

Requirements:
- Preserve the public API: the `QuantityStepper` widget, its constructor parameters
  `value`, `min`, `max`, and `onChanged`, and the static keys
  `QuantityStepper.decrementButtonKey`, `QuantityStepper.valueTextKey`, and
  `QuantityStepper.incrementButtonKey`.
- Keep the compact visible minus / value / plus row and the existing icons.
- Do not add visible label text for accessibility.
- The decrease control must announce `Decrease quantity`.
- The increase control must announce `Increase quantity`.
- The current value must announce the label `Quantity` with the current number as its
  semantic value.
- At `min`, the decrease control must be disabled to accessibility and must not call
  `onChanged`.
- At `max`, the increase control must be disabled to accessibility and must not call
  `onChanged`.
- When enabled, both visual taps and screen-reader taps must call `onChanged(value ± 1)`
  exactly once.

Keep the widget deterministic and offline: no timers, delays, network, platform channels,
or golden images.
