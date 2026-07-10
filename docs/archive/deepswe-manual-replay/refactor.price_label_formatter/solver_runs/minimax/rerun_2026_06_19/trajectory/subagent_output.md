## Summary

**Changed**
- `lib/price_label_formatter.dart` — completed `formatCents` (Free / whole-dollar / comma-grouped) and `formatSaleLabel` (compare-at only when strictly greater), integer arithmetic only.
- `lib/product_price_tile.dart` — dropped private helpers, routes price through `formatter.formatSaleLabel`.
- `lib/cart_line_price_row.dart` — dropped private helper, routes unit + `quantity * unitPriceCents` total through `formatter.formatCents`.
- `lib/checkout_price_summary.dart` — dropped private helper, routes subtotal/shipping/total through `formatter.formatCents`.

Public APIs preserved (constructor params, `Key` constants, `PriceLabelFormatter` shape).

**Validated**
- `flutter pub get` — ok.
- `flutter test` — **6/6 passed**.
- `flutter analyze` — no issues.

Report at `/tmp/pickarena_refactor_deepswe_rerun/minimax/solver_report.md`.