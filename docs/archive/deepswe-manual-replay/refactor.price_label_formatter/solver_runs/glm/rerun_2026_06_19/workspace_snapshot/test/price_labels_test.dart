import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:price_label_formatter/cart_line_price_row.dart';
import 'package:price_label_formatter/checkout_price_summary.dart';
import 'package:price_label_formatter/price_label_formatter.dart';
import 'package:price_label_formatter/product_price_tile.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  test('formatter renders a plain two-decimal amount', () {
    expect(const PriceLabelFormatter().formatCents(1250), r'$12.50');
  });

  testWidgets('product tile shows a regular price', (tester) async {
    await tester.pumpWidget(
      _host(const ProductPriceTile(title: 'Trail Mix', priceCents: 1250)),
    );

    expect(find.byKey(ProductPriceTile.titleTextKey), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(ProductPriceTile.priceTextKey)).data,
      r'$12.50',
    );
  });

  testWidgets('product tile shows a sale price with compare-at', (tester) async {
    await tester.pumpWidget(
      _host(
        const ProductPriceTile(
          title: 'Trail Mix',
          priceCents: 800,
          compareAtCents: 1000,
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(ProductPriceTile.priceTextKey)).data,
      r'$8 (was $10)',
    );
  });

  testWidgets('product tile shows Free for a zero price', (tester) async {
    await tester.pumpWidget(
      _host(const ProductPriceTile(title: 'Sample', priceCents: 0)),
    );

    expect(
      tester.widget<Text>(find.byKey(ProductPriceTile.priceTextKey)).data,
      'Free',
    );
  });

  testWidgets('cart line row shows quantity, unit price, and line total', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CartLinePriceRow(
          name: 'Coffee',
          quantity: 2,
          unitPriceCents: 350,
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(CartLinePriceRow.quantityTextKey)).data,
      'Qty: 2',
    );
    expect(
      tester.widget<Text>(find.byKey(CartLinePriceRow.unitPriceTextKey)).data,
      r'$3.50',
    );
    expect(
      tester.widget<Text>(find.byKey(CartLinePriceRow.lineTotalTextKey)).data,
      r'$7',
    );
  });

  testWidgets('checkout summary shows subtotal, shipping, and total', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CheckoutPriceSummary(
          subtotalCents: 2100,
          shippingCents: 0,
          totalCents: 2100,
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(CheckoutPriceSummary.subtotalTextKey)).data,
      r'$21',
    );
    expect(
      tester.widget<Text>(find.byKey(CheckoutPriceSummary.shippingTextKey)).data,
      'Free',
    );
    expect(
      tester.widget<Text>(find.byKey(CheckoutPriceSummary.totalTextKey)).data,
      r'$21',
    );
  });
}
