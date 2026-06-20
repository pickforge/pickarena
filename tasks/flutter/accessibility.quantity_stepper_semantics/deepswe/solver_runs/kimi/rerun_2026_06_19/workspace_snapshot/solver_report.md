# QuantityStepper Accessibility Fix

## Changed
Wrapped each child in `lib/quantity_stepper.dart` with a `Semantics` widget:

- Decrement `IconButton`: `button: true`, `enabled: value > min`, label `Decrease quantity`.
- Value `Text`: label `Quantity`, semantic value `$value`.
- Increment `IconButton`: `button: true`, `enabled: value < max`, label `Increase quantity`.

The existing keys, public API, visible layout, and icons were preserved.

## Validated
- `flutter pub get` completed successfully.
- `flutter test` passed all 6 public tests.

## Risks/uncertainties
None. No architecture, persistence, auth, security, data model, or migration changes were made.
