Done.

**Changed `lib/quantity_stepper.dart`:**
- Wrapped decrement `IconButton` in `Semantics(button: true, enabled: value > min, label: 'Decrease quantity', ...)`.
- Wrapped value `Text` in `Semantics(label: 'Quantity', value: '$value', ...)`.
- Wrapped increment `IconButton` in `Semantics(button: true, enabled: value < max, label: 'Increase quantity', ...)`.
- Preserved the constructor, parameters, static keys, visible row layout, and icons.

**Validated:**
- `flutter pub get` ✅
- `flutter test` — all 6 public tests passed ✅

**Report written to `solver_report.md`.**

No architecture/persistence/auth/security/data model/migration decisions were required.