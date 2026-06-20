import 'package:flutter/material.dart';

import 'price_label_formatter.dart';

/// Shows a checkout summary: subtotal, shipping, and total.
///
/// Prices are produced entirely by the injected [formatter].
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(formatter.formatCents(subtotalCents), key: subtotalTextKey),
        Text(formatter.formatCents(shippingCents), key: shippingTextKey),
        Text(formatter.formatCents(totalCents), key: totalTextKey),
      ],
    );
  }
}