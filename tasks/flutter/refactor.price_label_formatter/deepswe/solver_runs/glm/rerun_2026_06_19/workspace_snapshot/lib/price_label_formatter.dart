/// Formats integer-cent prices into customer-facing labels.
class PriceLabelFormatter {
  const PriceLabelFormatter();

  /// Formats [cents] into a customer-facing price label.
  ///
  /// Rules:
  /// - `0` renders as `Free`.
  /// - Whole-dollar amounts omit the `.00` (e.g. `2100` -> `$21`).
  /// - Non-whole amounts always show exactly two cent digits.
  /// - Thousands are grouped with commas.
  String formatCents(int cents) {
    if (cents == 0) {
      return 'Free';
    }
    final dollars = cents ~/ 100;
    final remainder = cents % 100;
    if (remainder == 0) {
      return '\$${_groupWithCommas(dollars)}';
    }
    return '\$${_groupWithCommas(dollars)}.${remainder.toString().padLeft(2, '0')}';
  }

  /// Formats a sale label. Returns `<current> (was <compare-at>)` only when
  /// [compareAtCents] is strictly greater than [priceCents]; otherwise it
  /// returns the current price only.
  String formatSaleLabel({required int priceCents, int? compareAtCents}) {
    final current = formatCents(priceCents);
    if (compareAtCents != null && compareAtCents > priceCents) {
      return '$current (was ${formatCents(compareAtCents)})';
    }
    return current;
  }

  /// Groups an integer with commas every three digits from the right.
  String _groupWithCommas(int value) {
    if (value < 1000) {
      return value.toString();
    }
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}