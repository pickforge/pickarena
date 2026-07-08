# Solver report

Changed behavior:
- `PriceLabelFormatter` now handles `Free`, whole-dollar labels, cents, comma-grouped dollars, and sale compare-at labels.
- Product, cart, and checkout widgets now use their injected formatter for all displayed prices.
- Cart line totals are still computed as `quantity * unitPriceCents` before formatting.

Commands run:
- `flutter pub get`
- `flutter test test/price_labels_test.dart` (passed; run twice)
