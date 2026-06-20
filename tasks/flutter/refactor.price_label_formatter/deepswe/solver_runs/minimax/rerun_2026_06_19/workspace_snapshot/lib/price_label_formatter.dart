/// Formats integer-cent prices into customer-facing labels.
class PriceLabelFormatter {
  const PriceLabelFormatter();

  String formatCents(int cents) {
    if (cents == 0) {
      return 'Free';
    }
    final negative = cents < 0;
    final abs = cents.abs();
    final dollars = abs ~/ 100;
    final remainder = abs % 100;
    final sign = negative ? '-' : '';
    if (remainder == 0) {
      return '$sign\$${_groupThousands(dollars)}';
    }
    final centsPart = remainder.toString().padLeft(2, '0');
    return '$sign\$${_groupThousands(dollars)}.$centsPart';
  }

  String formatSaleLabel({required int priceCents, int? compareAtCents}) {
    final current = formatCents(priceCents);
    final compareAt = compareAtCents;
    if (compareAt != null && compareAt > priceCents) {
      return '$current (was ${formatCents(compareAt)})';
    }
    return current;
  }

  static String _groupThousands(int value) {
    if (value < 1000) return value.toString();
    var digits = value.toString();
    final parts = <String>[];
    while (digits.length > 3) {
      parts.insert(0, digits.substring(digits.length - 3));
      digits = digits.substring(0, digits.length - 3);
    }
    parts.insert(0, digits);
    return parts.join(',');
  }
}
