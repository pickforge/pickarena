/// Behavior-changing variant: centralizes formatting through the formatter but
/// changes the customer-facing labels. It always prints two decimals, never
/// emits `Free`, and never groups thousands with commas.
class PriceLabelFormatter {
  const PriceLabelFormatter();

  String formatCents(int cents) {
    final dollars = cents ~/ 100;
    final remainder = cents % 100;
    return '\$$dollars.${remainder.toString().padLeft(2, '0')}';
  }

  String formatSaleLabel({required int priceCents, int? compareAtCents}) {
    final current = formatCents(priceCents);
    final compareAt = compareAtCents;
    if (compareAt != null && compareAt > priceCents) {
      return '$current (was ${formatCents(compareAt)})';
    }
    return current;
  }
}
