Done. All 6 public tests pass.

**Changes to `lib/quantity_stepper.dart`:** wrapped each of the three controls in a `Semantics` node (with `excludeSemantics: true` to avoid duplicate/leaked semantics):

- Decrease: label `Decrease quantity`, `button: true`, `enabled` only when `value > min`, with `onTap` for screen-reader taps.
- Value: label `Quantity` with `value: '$value'` so the current number announces as the semantic value (no button).
- Increase: label `Increase quantity`, `button: true`, `enabled` only when `value < max`, with `onTap`.

At `min`/`max` the boundary control is disabled both visually (`IconButton.onPressed: null`) and to accessibility (`enabled: false`, `onTap: null`), so neither path fires `onChanged`. When enabled, visual and screen-reader taps each call `onChanged(value ± 1)` exactly once. Public API, icons, and the compact row are preserved; no visible label text added. Report written to `solver_report.md`.