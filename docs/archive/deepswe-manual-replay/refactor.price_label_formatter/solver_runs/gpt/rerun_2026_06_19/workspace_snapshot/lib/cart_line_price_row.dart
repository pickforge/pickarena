import 'package:flutter/material.dart';

import 'price_label_formatter.dart';

/// Shows one cart line: the item name, the quantity, the unit price, and the
/// computed line total.
class CartLinePriceRow extends StatelessWidget {
  const CartLinePriceRow({
    super.key,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
    this.formatter = const PriceLabelFormatter(),
  });

  static const Key nameTextKey = Key('cart_line_price_row_name');
  static const Key quantityTextKey = Key('cart_line_price_row_quantity');
  static const Key unitPriceTextKey = Key('cart_line_price_row_unit_price');
  static const Key lineTotalTextKey = Key('cart_line_price_row_line_total');

  final String name;
  final int quantity;
  final int unitPriceCents;
  final PriceLabelFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(name, key: nameTextKey),
        Text('Qty: $quantity', key: quantityTextKey),
        Text(formatter.formatCents(unitPriceCents), key: unitPriceTextKey),
        Text(
          formatter.formatCents(quantity * unitPriceCents),
          key: lineTotalTextKey,
        ),
      ],
    );
  }
}
