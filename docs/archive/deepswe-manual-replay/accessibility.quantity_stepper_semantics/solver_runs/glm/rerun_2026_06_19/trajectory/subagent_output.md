Summary of the solution:

I modified `lib/quantity_stepper.dart` to make the cart quantity stepper accessible:

1. **Decrease button** — wrapped in `Semantics(label: 'Decrease quantity', button: true, enabled: value > min, onTap: ...)` with `excludeSemantics: true` so the announced label is exactly `Decrease quantity`, and it is disabled (no `onTap`, `enabled: false`) at `min`.

2. **Increase button** — same pattern with `label: 'Increase quantity'`, disabled at `max`.

3. **Value display** — wrapped the `Text` in `Semantics(label: 'Quantity', value: '$value', excludeSemantics: true)` so the screen reader announces `Quantity, <n>`.

4. **Bug fix** — the original `onPressed` closures were always non-null (the ternary was *inside* the closure), so the buttons were never truly disabled. I moved the boundary check to the `onPressed`/`onTap` level, making the boundary buttons inert to both pointer and accessibility input, so `onChanged` is never called at the boundaries.

Public API, static keys, compact row, and existing icons are all preserved. No visible label text, timers, network, or platform channels added.

Commands run: `flutter pub get`, `flutter test test/quantity_stepper_test.dart` → 6/6 passed. Report written to `solver_report.md`.