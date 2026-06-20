Refactor the price label code so every customer-facing price is produced by a single,
injectable `PriceLabelFormatter`.

Context: this package renders prices in three places — a product tile, a cart line row, and a
checkout summary. Today each widget formats prices with its own duplicated private helper, and
`PriceLabelFormatter` is incomplete: it renders a plain two-decimal amount and ignores sale
compare-at prices. The widgets accept a `formatter` but never call it. Prices are always integer
cents.

Goal: complete `PriceLabelFormatter`, route every price label through each widget's injected
`formatter`, and remove the duplicated private helpers — all while keeping the visible labels
exactly the same.

Requirements:
- Preserve the public API:
  - `PriceLabelFormatter` with `const PriceLabelFormatter()`, `String formatCents(int cents)`, and
    `String formatSaleLabel({required int priceCents, int? compareAtCents})`.
  - `ProductPriceTile` with constructor parameters `title`, `priceCents`, `compareAtCents`, and
    `formatter`, plus the static keys `ProductPriceTile.titleTextKey` and
    `ProductPriceTile.priceTextKey`.
  - `CartLinePriceRow` with constructor parameters `name`, `quantity`, `unitPriceCents`, and
    `formatter`, plus the static keys `CartLinePriceRow.nameTextKey`,
    `CartLinePriceRow.quantityTextKey`, `CartLinePriceRow.unitPriceTextKey`, and
    `CartLinePriceRow.lineTotalTextKey`.
  - `CheckoutPriceSummary` with constructor parameters `subtotalCents`, `shippingCents`,
    `totalCents`, and `formatter`, plus the static keys `CheckoutPriceSummary.subtotalTextKey`,
    `CheckoutPriceSummary.shippingTextKey`, and `CheckoutPriceSummary.totalTextKey`.
- Each widget must format its prices by calling the injected `formatter`, not a private helper. A
  custom formatter passed into a widget must control that widget's price text.
- The cart line total must be `quantity * unitPriceCents`, formatted by the formatter.
- Formatting rules for `PriceLabelFormatter`:
  - `0` cents renders as `Free`.
  - Whole-dollar amounts omit the `.00` (for example, `1250` renders as `$12.50` but `2100`
    renders as `$21`).
  - Non-whole amounts always show exactly two cent digits.
  - Thousands are grouped with commas.
  - `formatSaleLabel` returns `<current> (was <compare-at>)` only when `compareAtCents` is strictly
    greater than `priceCents`; otherwise it returns the current price only.
- Use integer arithmetic only. Do not add `intl`, locale/currency APIs, or `double` math.

Keep the widgets deterministic and offline: no timers, delays, network, platform channels, or
golden images.
