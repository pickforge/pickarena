import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
  testWidgets('mid-range decrement control announces Decrease quantity', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(_host(value: 4, min: 0, max: 8, onChanged: (_) {}));

    expect(
      tester.getSemantics(find.byKey(QuantityStepper.decrementButtonKey)),
      containsSemantics(
        label: 'Decrease quantity',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    semanticsHandle.dispose();
  });

  testWidgets('mid-range increment control announces Increase quantity', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(_host(value: 4, min: 0, max: 8, onChanged: (_) {}));

    expect(
      tester.getSemantics(find.byKey(QuantityStepper.incrementButtonKey)),
      containsSemantics(
        label: 'Increase quantity',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    semanticsHandle.dispose();
  });

  testWidgets('current value node exposes Quantity label and numeric value', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(_host(value: 4, min: 0, max: 8, onChanged: (_) {}));

    expect(
      tester.getSemantics(find.byKey(QuantityStepper.valueTextKey)),
      containsSemantics(label: 'Quantity', value: '4'),
    );
    expect(find.text('4'), findsOneWidget);
    semanticsHandle.dispose();
  });

  testWidgets('at min the decrement control is disabled to accessibility', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final calls = <int>[];
    await tester.pumpWidget(
      _host(value: 0, min: 0, max: 8, onChanged: calls.add),
    );

    expect(
      tester.getSemantics(find.byKey(QuantityStepper.decrementButtonKey)),
      containsSemantics(
        label: 'Decrease quantity',
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(QuantityStepper.incrementButtonKey)),
      containsSemantics(isEnabled: true, hasTapAction: true),
    );

    await tester.tap(
      find.byKey(QuantityStepper.decrementButtonKey),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(calls, isEmpty);
    semanticsHandle.dispose();
  });

  testWidgets('at max the increment control is disabled to accessibility', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final calls = <int>[];
    await tester.pumpWidget(
      _host(value: 8, min: 0, max: 8, onChanged: calls.add),
    );

    expect(
      tester.getSemantics(find.byKey(QuantityStepper.incrementButtonKey)),
      containsSemantics(
        label: 'Increase quantity',
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(QuantityStepper.decrementButtonKey)),
      containsSemantics(isEnabled: true, hasTapAction: true),
    );

    await tester.tap(
      find.byKey(QuantityStepper.incrementButtonKey),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(calls, isEmpty);
    semanticsHandle.dispose();
  });

  testWidgets('screen-reader tap invokes the real onChanged exactly once', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final increments = <int>[];
    await tester.pumpWidget(
      _host(value: 4, min: 0, max: 8, onChanged: increments.add),
    );

    final owner = tester.binding.pipelineOwner.semanticsOwner!;
    final incrementNode = tester.getSemantics(
      find.byKey(QuantityStepper.incrementButtonKey),
    );
    owner.performAction(incrementNode.id, SemanticsAction.tap);
    await tester.pump();
    expect(increments, <int>[5]);

    final decrements = <int>[];
    await tester.pumpWidget(
      _host(value: 4, min: 0, max: 8, onChanged: decrements.add),
    );
    final decrementNode = tester.getSemantics(
      find.byKey(QuantityStepper.decrementButtonKey),
    );
    owner.performAction(decrementNode.id, SemanticsAction.tap);
    await tester.pump();
    expect(decrements, <int>[3]);
    semanticsHandle.dispose();
  });

  testWidgets('value semantics stay consistent with visible text on rebuild', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    var value = 4;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _host(
            value: value,
            min: 0,
            max: 8,
            onChanged: (next) => setState(() => value = next),
          );
        },
      ),
    );

    expect(
      tester.getSemantics(find.byKey(QuantityStepper.valueTextKey)),
      containsSemantics(label: 'Quantity', value: '4'),
    );

    await tester.tap(find.byKey(QuantityStepper.incrementButtonKey));
    await tester.pump();

    expect(find.text('5'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(QuantityStepper.valueTextKey)),
      containsSemantics(label: 'Quantity', value: '5'),
    );
    semanticsHandle.dispose();
  });

  testWidgets('special-case ranges still expose accessible controls', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(_host(value: 6, min: 2, max: 6, onChanged: (_) {}));

    expect(
      tester.getSemantics(find.byKey(QuantityStepper.decrementButtonKey)),
      containsSemantics(
        label: 'Decrease quantity',
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(QuantityStepper.incrementButtonKey)),
      containsSemantics(
        label: 'Increase quantity',
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    semanticsHandle.dispose();
  });

  testWidgets('accessibility strings are not added as visible label text', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(_host(value: 4, min: 0, max: 8, onChanged: (_) {}));

    final texts = tester.widgetList<Text>(
      find.byType(Text, skipOffstage: false),
    );
    for (final text in texts) {
      final data = text.data ?? '';
      expect(data.contains('Decrease quantity'), isFalse);
      expect(data.contains('Increase quantity'), isFalse);
      expect(data.contains('Quantity'), isFalse);
    }
    semanticsHandle.dispose();
  });
}
