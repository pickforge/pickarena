import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:price_label_formatter/product_price_tile.dart';

void main() {
  testWidgets('product price tile can be constructed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductPriceTile(title: 'Sample', priceCents: 100),
        ),
      ),
    );

    expect(find.byType(ProductPriceTile), findsOneWidget);
  });
}
