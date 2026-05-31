import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:god_widget_fixture/god_widget.dart';

Widget _wrap() => const MaterialApp(home: Scaffold(body: GodWidget()));

void main() {
  testWidgets('initial status is 0 of 0 done', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byKey(const Key('status')), findsOneWidget);
    expect(find.text('0 of 0 done'), findsOneWidget);
  });

  testWidgets('Add button appends a todo', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('0 of 1 done'), findsOneWidget);
  });

  testWidgets('checking a todo updates status text', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text('1 of 1 done'), findsOneWidget);
  });

  testWidgets('filter Open hides done todos', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'B');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').last);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('sort by Title reorders alphabetically', (tester) async {
    await tester.pumpWidget(_wrap());
    for (final t in const ['banana', 'apple', 'cherry']) {
      await tester.enterText(find.byType(TextField), t);
      await tester.tap(find.text('Add'));
      await tester.pump();
    }
    await tester.tap(find.text('Created'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title').last);
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(CheckboxListTile),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    final order = [
      'apple',
      'banana',
      'cherry',
    ].map((s) => titles.indexOf(s)).toList();
    expect(order, [0, 1, 2]);
  });

  testWidgets('delete button removes a todo', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('0 of 0 done'), findsOneWidget);
  });

  testWidgets('Add ignores empty/whitespace input', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('0 of 0 done'), findsOneWidget);
  });
}
