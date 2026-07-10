import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantity_stepper_semantics/quantity_stepper.dart';

Widget _host({
  required int value,
  required int min,
  required int max,
  required ValueChanged<int> onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: QuantityStepper(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    ),
  );
}

void main() {
  testWidgets('renders the current visible quantity', (tester) async {
    await tester.pumpWidget(_host(value: 3, min: 1, max: 5, onChanged: (_) {}));

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('exposes the three static keys', (tester) async {
    await tester.pumpWidget(_host(value: 3, min: 1, max: 5, onChanged: (_) {}));

    expect(find.byKey(QuantityStepper.decrementButtonKey), findsOneWidget);
    expect(find.byKey(QuantityStepper.valueTextKey), findsOneWidget);
    expect(find.byKey(QuantityStepper.incrementButtonKey), findsOneWidget);
  });

  testWidgets('tapping increment calls onChanged(value + 1) once and updates', (
    tester,
  ) async {
    final calls = <int>[];
    var value = 3;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _host(
            value: value,
            min: 1,
            max: 5,
            onChanged: (next) {
              calls.add(next);
              setState(() => value = next);
            },
          );
        },
      ),
    );

    await tester.tap(find.byKey(QuantityStepper.incrementButtonKey));
    await tester.pump();

    expect(calls, <int>[4]);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('tapping decrement calls onChanged(value - 1) once and updates', (
    tester,
  ) async {
    final calls = <int>[];
    var value = 3;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _host(
            value: value,
            min: 1,
            max: 5,
            onChanged: (next) {
              calls.add(next);
              setState(() => value = next);
            },
          );
        },
      ),
    );

    await tester.tap(find.byKey(QuantityStepper.decrementButtonKey));
    await tester.pump();

    expect(calls, <int>[2]);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tapping decrement at min calls nothing', (tester) async {
    final calls = <int>[];

    await tester.pumpWidget(
      _host(value: 1, min: 1, max: 5, onChanged: calls.add),
    );

    await tester.tap(
      find.byKey(QuantityStepper.decrementButtonKey),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(calls, isEmpty);
  });

  testWidgets('tapping increment at max calls nothing', (tester) async {
    final calls = <int>[];

    await tester.pumpWidget(
      _host(value: 5, min: 1, max: 5, onChanged: calls.add),
    );

    await tester.tap(
      find.byKey(QuantityStepper.incrementButtonKey),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(calls, isEmpty);
  });
}
