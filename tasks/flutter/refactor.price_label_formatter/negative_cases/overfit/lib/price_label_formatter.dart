/// Overfit variant: routes widgets through the formatter, but the formatter
/// only knows the public example values. Hidden numeric fixtures fall through
/// to a broken default that ignores grouping and the two-decimal rule.
class PriceLabelFormatter {
  const PriceLabelFormatter();

  String formatCents(int cents) {
    switch (cents) {
      case 0:
        return 'Free';
      case 350:
        return '\$3.50';
      case 700:
        return '\$7';
      case 1250:
        return '\$12.50';
      case 2100:
        return '\$21';
    }
    // Fallback that does not group thousands or pad cents.
    final dollars = cents ~/ 100;
    final remainder = cents % 100;
    if (remainder == 0) {
      return '\$$dollars';
    }
    return '\$$dollars.$remainder';
  }

  String formatSaleLabel({required int priceCents, int? compareAtCents}) {
    if (priceCents == 800 && compareAtCents == 1000) {
      return '\$8 (was \$10)';
    }
    return formatCents(priceCents);
  }
}
