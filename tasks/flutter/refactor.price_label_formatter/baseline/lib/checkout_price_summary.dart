import 'package:flutter/material.dart';

import 'price_label_formatter.dart';

/// Shows a checkout summary: subtotal, shipping, and total.
///
/// Prices are currently produced by a private helper duplicated across the
/// product, cart, and checkout widgets. The injected [formatter] is ignored.
class CheckoutPriceSummary extends StatelessWidget {
  const CheckoutPriceSummary({
    super.key,
    required this.subtotalCents,
    required this.shippingCents,
    required this.totalCents,
    this.formatter = const PriceLabelFormatter(),
  });

  static const Key subtotalTextKey = Key('checkout_price_summary_subtotal');
  static const Key shippingTextKey = Key('checkout_price_summary_shipping');
  static const Key totalTextKey = Key('checkout_price_summary_total');

  final int subtotalCents;
  final int shippingCents;
  final int totalCents;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(_formatCents(subtotalCents), key: subtotalTextKey),
        Text(_formatCents(shippingCents), key: shippingTextKey),
        Text(_formatCents(totalCents), key: totalTextKey),
      ],
    );
  }
}
