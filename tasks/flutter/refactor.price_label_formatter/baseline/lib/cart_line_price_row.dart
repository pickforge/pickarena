import 'package:flutter/material.dart';

import 'price_label_formatter.dart';

/// Shows one cart line: the item name, the quantity, the unit price, and the
/// computed line total.
///
/// Prices are currently produced by a private helper duplicated across the
/// product, cart, and checkout widgets. The injected [formatter] is ignored.
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(name, key: nameTextKey),
        Text('Qty: $quantity', key: quantityTextKey),
        Text(_formatCents(unitPriceCents), key: unitPriceTextKey),
        Text(_formatCents(quantity * unitPriceCents), key: lineTotalTextKey),
      ],
    );
  }
}
