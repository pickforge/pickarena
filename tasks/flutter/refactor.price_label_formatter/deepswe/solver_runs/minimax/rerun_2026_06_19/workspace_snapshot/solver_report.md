# Solver Report — `refactor.price_label_formatter`

## Changed behavior

- **`PriceLabelFormatter`** (`lib/price_label_formatter.dart`):
  - `formatCents` now follows the spec: `0` → `"Free"`, whole-dollar amounts drop `.00`
    (e.g. `2100` → `"$21"`), non-whole amounts always show exactly two cent digits
    (e.g. `1250` → `"$12.50"`), and thousands are grouped with commas.
  - `formatSaleLabel` now appends ` (was <compare-at>)` only when `compareAtCents > priceCents`,
    otherwise returns the current price only.
  - Implemented with integer arithmetic only. No `intl`, no locale/currency APIs, no `double`.

- **`ProductPriceTile`** (`lib/product_price_tile.dart`):
  - Removed private `_formatCents` and `_formatSaleLabel` helpers.
  - The price label is produced by the injected `formatter.formatSaleLabel(...)`.

- **`CartLinePriceRow`** (`lib/cart_line_price_row.dart`):
  - Removed private `_formatCents` helper.
  - Unit price and `quantity * unitPriceCents` line total both go through `formatter.formatCents`.

- **`CheckoutPriceSummary`** (`lib/checkout_price_summary.dart`):
  - Removed private `_formatCents` helper.
  - Subtotal, shipping, and total all rendered through `formatter.formatCents`.

Public APIs (constructors, parameter names, static `Key` constants) are unchanged.

## Commands run

- `flutter pub get` — resolved deps successfully.
- `flutter test` — **6/6 tests passed**.
- `flutter analyze` — **No issues found**.

## Risks / uncertainties

- Behavior around negative cents is not exercised by the public tests. The implementation
  uses `abs()` and prefixes a `-` for negative input; this should be benign but is
  untested.
- The codebase is not a git repo in this workspace, so no diff vs. origin is produced.
