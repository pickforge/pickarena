/// Formats integer-cent prices into customer-facing labels.
class PriceLabelFormatter {
  const PriceLabelFormatter();

  String formatCents(int cents) {
    if (cents == 0) {
      return 'Free';
    }
    final dollars = cents ~/ 100;
    final remainder = cents % 100;
    final dollarString = _formatDollars(dollars);
    if (remainder == 0) {
      return '\$$dollarString';
    }
    return '\$$dollarString.${remainder.toString().padLeft(2, '0')}';
  }

  String formatSaleLabel({required int priceCents, int? compareAtCents}) {
    final current = formatCents(priceCents);
    final compareAt = compareAtCents;
    if (compareAt != null && compareAt > priceCents) {
      return '$current (was ${formatCents(compareAt)})';
    }
    return current;
  }

  String _formatDollars(int dollars) {
    if (dollars == 0) {
      return '0';
    }
    final negative = dollars < 0;
    var value = negative ? -dollars : dollars;
    final groups = <String>[];
    while (value > 0) {
      final group = value % 1000;
      value ~/= 1000;
      if (groups.isEmpty) {
        groups.add(group.toString());
      } else {
        groups.add(group.toString().padLeft(3, '0'));
      }
    }
    final result = groups.reversed.join(',');
    return negative ? '-$result' : result;
  }
}
