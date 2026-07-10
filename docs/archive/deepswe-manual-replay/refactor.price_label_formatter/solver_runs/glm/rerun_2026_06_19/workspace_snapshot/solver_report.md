# Solver Report — refactor.price_label_formatter

## Changed behavior

Completed `PriceLabelFormatter` and routed every customer-facing price label through the injected
formatter in each widget, removing the duplicated private helpers.

### `lib/price_label_formatter.dart`
- `formatCents` now implements the full spec:
  - `0` cents renders as `Free`.
  - Whole-dollar amounts omit `.00` (e.g. `2100` -> `$21`).
  - Non-whole amounts show exactly two cent digits (e.g. `1250` -> `$12.50`).
  - Thousands grouped with commas via an integer-only `_groupWithCommas` helper.
  - No `double` math, no `intl`, no locale/currency APIs.
- `formatSaleLabel` returns `<current> (was <compare-at>)` only when `compareAtCents` is strictly
  greater than `priceCents`; otherwise returns the current price only.

### `lib/product_price_tile.dart`
- Removed the private `_formatCents` / `_formatSaleLabel` helpers.
- The price `Text` now calls `formatter.formatSaleLabel(priceCents:..., compareAtCents:...)`.

### `lib/cart_line_price_row.dart`
- Removed the private `_formatCents` helper.
- Unit price uses `formatter.formatCents(unitPriceCents)`.
- Line total is computed as `quantity * unitPriceCents` and formatted via `formatter.formatCents`.

### `lib/checkout_price_summary.dart`
- Removed the private `_formatCents` helper.
- Subtotal, shipping, and total each use `formatter.formatCents(...)`.

Public API (constructor parameters and static keys) for all three widgets is preserved, as is
`const PriceLabelFormatter()`. A custom formatter injected into any widget now controls that
widget's price text.

## Commands run
- `flutter pub get`
- `flutter test test/price_labels_test.dart` — all 6 tests passed.