/// Formats integer-cent prices into customer-facing labels.
class PriceLabelFormatter {
  const PriceLabelFormatter();

  String formatCents(int cents) {
    final dollars = cents ~/ 100;
    final remainder = cents % 100;
    return '\$$dollars.${remainder.toString().padLeft(2, '0')}';
  }

  String formatSaleLabel({required int priceCents, int? compareAtCents}) {
    return formatCents(priceCents);
  }
}
