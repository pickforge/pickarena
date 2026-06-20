import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantity_stepper_semantics/quantity_stepper.dart';

void main() {
  testWidgets('stepper can be constructed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuantityStepper(value: 3, min: 1, max: 5, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.byType(QuantityStepper), findsOneWidget);
  });
}
