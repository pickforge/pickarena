/// Formats integer-cent prices into customer-facing labels.
class PriceLabelFormatter {
  const PriceLabelFormatter();

  String formatCents(int cents) {
    if (cents == 0) {
      return 'Free';
    }

    final dollars = cents ~/ 100;
    final remainder = cents % 100;
    final dollarLabel = _formatDollars(dollars);

    if (remainder == 0) {
      return '\$$dollarLabel';
    }

    return '\$$dollarLabel.${remainder.toString().padLeft(2, '0')}';
  }

  String formatSaleLabel({required int priceCents, int? compareAtCents}) {
    final current = formatCents(priceCents);
    if (compareAtCents != null && compareAtCents > priceCents) {
      return '$current (was ${formatCents(compareAtCents)})';
    }
    return current;
  }
}

String _formatDollars(int dollars) {
  final digits = dollars.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }

  return buffer.toString();
}
