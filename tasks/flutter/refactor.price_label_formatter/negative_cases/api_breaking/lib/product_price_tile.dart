import 'package:flutter/material.dart';

import 'price_label_formatter.dart';

/// API-breaking variant: renames the public `priceTextKey` static key and the
/// `priceCents` constructor parameter, so the public tests no longer compile.
class ProductPriceTile extends StatelessWidget {
  const ProductPriceTile({
    super.key,
    required this.title,
    required this.cents,
    this.compareAtCents,
    this.formatter = const PriceLabelFormatter(),
  });

  static const Key titleTextKey = Key('product_price_tile_title');
  static const Key priceLabelKey = Key('product_price_tile_price');

  final String title;
  final int cents;
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
            priceCents: cents,
            compareAtCents: compareAtCents,
          ),
          key: priceLabelKey,
        ),
      ],
    );
  }
}
