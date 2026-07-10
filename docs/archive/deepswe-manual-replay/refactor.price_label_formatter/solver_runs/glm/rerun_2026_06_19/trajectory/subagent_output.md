The task is complete. Summary of what was done:

1. **`lib/price_label_formatter.dart`** — Completed the formatter:
   - `formatCents`: `0`→`Free`, whole-dollar amounts omit `.00`, non-whole show two cent digits, thousands grouped with commas, integer arithmetic only (no `double`/`intl`/locale APIs).
   - `formatSaleLabel`: returns `<current> (was <compare-at>)` only when `compareAtCents > priceCents`, else current price only.

2. **`lib/product_price_tile.dart`** — Removed private `_formatCents`/`_formatSaleLabel`; now calls `formatter.formatSaleLabel(...)`.

3. **`lib/cart_line_price_row.dart`** — Removed private `_formatCents`; unit price and line total (`quantity * unitPriceCents`) now formatted via `formatter`.

4. **`lib/checkout_price_summary.dart`** — Removed private `_formatCents`; subtotal/shipping/total now formatted via `formatter`.

All public APIs (constructor params, static keys, `const PriceLabelFormatter()`) preserved. `flutter pub get` and `flutter test test/price_labels_test.dart` both ran successfully — all 6 public tests pass.