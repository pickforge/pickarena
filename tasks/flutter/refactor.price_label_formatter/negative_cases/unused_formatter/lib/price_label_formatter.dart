/// Formats integer-cent prices into customer-facing labels.
class PriceLabelFormatter {
  const PriceLabelFormatter();

  String formatCents(int cents) {
    if (cents == 0) {
      return 'Free';
    }
    final remainder = cents % 100;
    final dollars = (cents ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    if (remainder == 0) {
      return '\$$dollars';
    }
    return '\$$dollars.${remainder.toString().padLeft(2, '0')}';
  }

  String formatSaleLabel({required int priceCents, int? compareAtCents}) {
    final current = formatCents(priceCents);
    if (compareAtCents != null && compareAtCents > priceCents) {
      return '$current (was ${formatCents(compareAtCents)})';
    }
    return current;
  }
}
