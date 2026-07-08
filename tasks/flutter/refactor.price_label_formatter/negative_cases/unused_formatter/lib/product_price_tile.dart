import 'package:flutter/material.dart';

import 'price_label_formatter.dart';

/// Shows a product title and its price, optionally with a strikethrough-style
/// "was" compare-at price for items on sale.
///
/// The price label is currently produced by a private helper duplicated across
/// the product, cart, and checkout widgets. The injected [formatter] is ignored.
class ProductPriceTile extends StatelessWidget {
  const ProductPriceTile({
    super.key,
    required this.title,
    required this.priceCents,
    this.compareAtCents,
    this.formatter = const PriceLabelFormatter(),
  });

  static const Key titleTextKey = Key('product_price_tile_title');
  static const Key priceTextKey = Key('product_price_tile_price');

  final String title;
  final int priceCents;
  final int? compareAtCents;
  final PriceLabelFormatter formatter;

  String _formatCents(int cents) {
    if (cents == 0) {
      return 'Free';
    }
    final dollars = cents ~/ 100;
    final remainder = cents % 100;
    if (remainder == 0) {
      return '\$$dollars';
    }
    return '\$$dollars.${remainder.toString().padLeft(2, '0')}';
  }

  String _formatSaleLabel() {
    final current = _formatCents(priceCents);
    final compareAt = compareAtCents;
    if (compareAt != null && compareAt > priceCents) {
      return '$current (was ${_formatCents(compareAt)})';
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, key: titleTextKey),
        Text(_formatSaleLabel(), key: priceTextKey),
      ],
    );
  }
}
