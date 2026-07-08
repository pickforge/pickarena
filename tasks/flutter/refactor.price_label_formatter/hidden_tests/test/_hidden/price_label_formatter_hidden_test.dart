import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:price_label_formatter/cart_line_price_row.dart';
import 'package:price_label_formatter/checkout_price_summary.dart';
import 'package:price_label_formatter/price_label_formatter.dart';
import 'package:price_label_formatter/product_price_tile.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

String _text(WidgetTester tester, Key key) {
  return tester.widget<Text>(find.byKey(key)).data!;
}

/// Routes every label to a recognizable sentinel string so the tests can prove
/// the widgets call the injected formatter rather than any private helper.
class _SentinelFormatter extends PriceLabelFormatter {
  const _SentinelFormatter();

  @override
  String formatCents(int cents) => 'cents:$cents';

  @override
  String formatSaleLabel({required int priceCents, int? compareAtCents}) {
    return 'sale:$priceCents:$compareAtCents';
  }
}

void main() {
  group('formatCents matrix', () {
    const formatter = PriceLabelFormatter();

    test('single cent keeps two decimal digits', () {
      expect(formatter.formatCents(1), r'$0.01');
    });

    test('sub-dollar amount keeps two decimal digits', () {
      expect(formatter.formatCents(105), r'$1.05');
    });

    test('whole dollars omit the decimal part', () {
      expect(formatter.formatCents(500), r'$5');
    });

    test('non-whole amount above ten keeps two decimal digits', () {
      expect(formatter.formatCents(1005), r'$10.05');
    });

    test('large non-whole amount groups thousands with commas', () {
      expect(formatter.formatCents(123456), r'$1,234.56');
    });

    test('large whole amount groups thousands and omits decimals', () {
      expect(formatter.formatCents(1200000), r'$12,000');
    });

    test('zero renders as Free', () {
      expect(formatter.formatCents(0), 'Free');
    });
  });

  group('formatSaleLabel', () {
    const formatter = PriceLabelFormatter();

    test('higher compare-at adds a was suffix', () {
      expect(
        formatter.formatSaleLabel(priceCents: 650, compareAtCents: 900),
        r'$6.50 (was $9)',
      );
    });

    test('equal compare-at returns the current price only', () {
      expect(
        formatter.formatSaleLabel(priceCents: 650, compareAtCents: 650),
        r'$6.50',
      );
    });

    test('lower compare-at returns the current price only', () {
      expect(
        formatter.formatSaleLabel(priceCents: 650, compareAtCents: 400),
        r'$6.50',
      );
    });

    test('null compare-at returns the current price only', () {
      expect(formatter.formatSaleLabel(priceCents: 650), r'$6.50');
    });

    test('free price with higher compare-at adds a was suffix', () {
      expect(
        formatter.formatSaleLabel(priceCents: 0, compareAtCents: 225),
        'Free (was \$2.25)',
      );
    });
  });

  group('product price tile labels', () {
    testWidgets('regular price routes through the formatter', (tester) async {
      await tester.pumpWidget(
        _host(const ProductPriceTile(title: 'Widget', priceCents: 1005)),
      );

      expect(_text(tester, ProductPriceTile.priceTextKey), r'$10.05');
    });

    testWidgets('sale price routes through the formatter', (tester) async {
      await tester.pumpWidget(
        _host(
          const ProductPriceTile(
            title: 'Widget',
            priceCents: 650,
            compareAtCents: 900,
          ),
        ),
      );

      expect(
        _text(tester, ProductPriceTile.priceTextKey),
        r'$6.50 (was $9)',
      );
    });

    testWidgets('equal compare-at shows the current price only', (tester) async {
      await tester.pumpWidget(
        _host(
          const ProductPriceTile(
            title: 'Widget',
            priceCents: 650,
            compareAtCents: 650,
          ),
        ),
      );

      expect(_text(tester, ProductPriceTile.priceTextKey), r'$6.50');
    });
  });

  group('cart line price row labels', () {
    testWidgets('unit price and line total route through the formatter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CartLinePriceRow(
            name: 'Beans',
            quantity: 3,
            unitPriceCents: 199,
          ),
        ),
      );

      expect(_text(tester, CartLinePriceRow.unitPriceTextKey), r'$1.99');
      expect(_text(tester, CartLinePriceRow.lineTotalTextKey), r'$5.97');
    });
  });

  group('checkout price summary labels', () {
    testWidgets('summary lines route through the formatter', (tester) async {
      await tester.pumpWidget(
        _host(
          const CheckoutPriceSummary(
            subtotalCents: 123456,
            shippingCents: 0,
            totalCents: 123456,
          ),
        ),
      );

      expect(_text(tester, CheckoutPriceSummary.subtotalTextKey), r'$1,234.56');
      expect(_text(tester, CheckoutPriceSummary.shippingTextKey), 'Free');
      expect(_text(tester, CheckoutPriceSummary.totalTextKey), r'$1,234.56');
    });
  });

  group('formatter injection routing', () {
    testWidgets('product tile uses the injected formatter', (tester) async {
      await tester.pumpWidget(
        _host(
          const ProductPriceTile(
            title: 'Widget',
            priceCents: 650,
            compareAtCents: 900,
            formatter: _SentinelFormatter(),
          ),
        ),
      );

      expect(_text(tester, ProductPriceTile.priceTextKey), 'sale:650:900');
    });

    testWidgets('cart line row uses the injected formatter', (tester) async {
      await tester.pumpWidget(
        _host(
          const CartLinePriceRow(
            name: 'Beans',
            quantity: 3,
            unitPriceCents: 199,
            formatter: _SentinelFormatter(),
          ),
        ),
      );

      expect(_text(tester, CartLinePriceRow.unitPriceTextKey), 'cents:199');
      expect(_text(tester, CartLinePriceRow.lineTotalTextKey), 'cents:597');
    });

    testWidgets('checkout summary uses the injected formatter', (tester) async {
      await tester.pumpWidget(
        _host(
          const CheckoutPriceSummary(
            subtotalCents: 123456,
            shippingCents: 0,
            totalCents: 123456,
            formatter: _SentinelFormatter(),
          ),
        ),
      );

      expect(
        _text(tester, CheckoutPriceSummary.subtotalTextKey),
        'cents:123456',
      );
      expect(_text(tester, CheckoutPriceSummary.shippingTextKey), 'cents:0');
      expect(_text(tester, CheckoutPriceSummary.totalTextKey), 'cents:123456');
    });
  });
}
