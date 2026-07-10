# Solver report

Changed behavior:
- Added explicit accessibility semantics for the quantity stepper controls: `Decrease quantity`, `Increase quantity`, and current value as label `Quantity` with semantic value set to the number.
- Disabled decrement at `min` and increment at `max` for both visual taps and accessibility tap actions.
- Kept the compact minus / value / plus row and existing icons.

Commands run:
- `flutter pub get`
- `flutter test`
