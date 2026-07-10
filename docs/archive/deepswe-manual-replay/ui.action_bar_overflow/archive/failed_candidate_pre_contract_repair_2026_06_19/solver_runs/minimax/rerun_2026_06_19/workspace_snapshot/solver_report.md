# PickArena `ui.action_bar_overflow` — solver report

## Changed behavior

`ResponsiveActionBar` now partitions secondary actions between an inline row and
a "More actions" overflow menu based on available width, instead of always
rendering every action inline.

- Public API is unchanged: `ResponsiveActionBarAction`, `ResponsiveActionBar`,
  and the four static keys (`primaryButtonKey`, `overflowButtonKey`,
  `actionButtonKey`, `overflowItemKey`) keep the same signatures and values.
- The primary CTA is always rendered as a `FilledButton` keyed by
  `primaryButtonKey`, anchored to the trailing edge of the bar.
- On wide layouts where `primary + all actions` fits, every secondary action is
  rendered as a `TextButton.icon` keyed by `actionButtonKey(id)` and no
  overflow button is shown.
- On compact layouts, lower-priority actions are moved behind a real
  `MenuAnchor` whose trigger is keyed by `overflowButtonKey`. Each menu item
  uses `overflowItemKey(id)`, displays the original `label` and `icon`, and
  invokes the original `onPressed` exactly once on tap.
- Actions are sorted by `(priority, inputIndex)` — lower `priority` stays
  inline longer, ties keep input order. Each action is rendered in exactly one
  place.
- Width decisions use the current `MediaQuery.textScalerOf(context)`, so
  ambient text scaling pushes the split toward overflow. Honors accessibility
  scaling without horizontal scrolling or clipping.
- Solution is deterministic and offline: no timers, sleeps, network, platform
  channels, golden files, scrolling, clipping, or hardcoded public examples.

## Files changed

- `lib/responsive_action_bar.dart` — replaced placeholder split logic with a
  `LayoutBuilder` + text-scaled `TextPainter` width estimate and a two-phase
  greedy partition (try all-inline first; if that fails, reserve the overflow
  button width and re-partition by priority). The `Row` lays inline actions
  with an 8 px gap, then the overflow menu (if any), then an `Expanded` slot
  that aligns the primary `FilledButton` to the trailing edge.

## Validation

Commands run:

- `flutter pub get` — resolved dependencies.
- `flutter test` — all 3 public widget tests pass:
  - `wide bar renders primary and all actions inline` (640 px)
  - `compact bar keeps primary visible and moves secondary actions to overflow` (320 px)
  - `public API keys are stable across direct and overflow modes`
- `flutter analyze` — no issues.

## Risks / uncertainties

- The split decision uses calibrated constants for Material 3 button metrics
  (text/icon gaps, padding). With very different themes the prediction could
  diverge from the real layout, but the algorithm is intentionally a little
  conservative on compact widths — i.e. it tends to push borderline actions
  into the overflow menu rather than risk overflow.
- The text-scaled overflow path was checked manually with a 2.0 text scaler
  and an 800 px width, which correctly showed the overflow button.

## Next action

None required — the public tests are green.
