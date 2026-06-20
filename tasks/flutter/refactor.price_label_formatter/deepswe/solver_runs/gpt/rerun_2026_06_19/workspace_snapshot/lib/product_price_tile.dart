import 'package:flutter/material.dart';

import 'price_label_formatter.dart';

/// Shows a product title and its price, optionally with a strikethrough-style
/// "was" compare-at price for items on sale.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, key: titleTextKey),
        Text(
          formatter.formatSaleLabel(
            priceCents: priceCents,
            compareAtCents: compareAtCents,
          ),
          key: priceTextKey,
        ),
      ],
    );
  }
}
