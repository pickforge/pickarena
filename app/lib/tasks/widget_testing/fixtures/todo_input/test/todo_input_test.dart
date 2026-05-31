import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_input_fixture/todo_input.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

ElevatedButton _submitButton(WidgetTester tester) {
  return tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Submit'),
  );
}

String _fieldText(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText)).controller.text;
}

void main() {
  testWidgets('Submit button is disabled when input is empty or whitespace', (
    tester,
  ) async {
    await tester.pumpWidget(_host(TodoInput(onSubmit: (_) {})));

    expect(_submitButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    expect(_submitButton(tester).onPressed, isNull);
  });

  testWidgets('Typing non-empty text enables the Submit button', (
    tester,
  ) async {
    await tester.pumpWidget(_host(TodoInput(onSubmit: (_) {})));

    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.pump();

    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets(
    'Tapping Submit calls onSubmit with trimmed text and clears input',
    (tester) async {
      final submissions = <String>[];
      await tester.pumpWidget(_host(TodoInput(onSubmit: submissions.add)));

      await tester.enterText(find.byType(TextField), '  Buy milk  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pump();

      expect(submissions, ['Buy milk']);
      expect(_fieldText(tester), isEmpty);
      expect(_submitButton(tester).onPressed, isNull);
    },
  );

  testWidgets('maxLength is passed to the underlying TextField', (
    tester,
  ) async {
    await tester.pumpWidget(_host(TodoInput(onSubmit: (_) {}, maxLength: 5)));

    expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 5);
  });

  testWidgets('Pressing Enter submits with trimmed text and clears input', (
    tester,
  ) async {
    final submissions = <String>[];
    await tester.pumpWidget(_host(TodoInput(onSubmit: submissions.add)));

    await tester.enterText(find.byType(TextField), '  Walk dog  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submissions, ['Walk dog']);
    expect(_fieldText(tester), isEmpty);
    expect(_submitButton(tester).onPressed, isNull);
  });
}
