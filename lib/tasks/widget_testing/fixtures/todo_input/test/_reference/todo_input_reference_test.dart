import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_input_fixture/todo_input.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('Submit is disabled with empty input', (tester) async {
    await tester.pumpWidget(_wrap(TodoInput(onSubmit: (_) {})));
    final button = tester.widget<ElevatedButton>(
      find.byWidgetPredicate((w) => w is ElevatedButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Submit enables once text is entered', (tester) async {
    await tester.pumpWidget(_wrap(TodoInput(onSubmit: (_) {})));
    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();
    final button = tester.widget<ElevatedButton>(
      find.byWidgetPredicate((w) => w is ElevatedButton),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Tapping Submit fires onSubmit and clears the field',
      (tester) async {
    final received = <String>[];
    await tester.pumpWidget(_wrap(TodoInput(onSubmit: received.add)));
    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(received, ['Buy milk']);
    expect(find.text('Buy milk'), findsNothing);
  });

  testWidgets('respects maxLength', (tester) async {
    await tester.pumpWidget(_wrap(TodoInput(onSubmit: (_) {}, maxLength: 5)));
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.maxLength, 5);
  });
}
