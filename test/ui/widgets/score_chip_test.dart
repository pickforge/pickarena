import 'package:dart_arena/ui/widgets/score_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders evaluator id and 2-decimal score', (tester) async {
    await tester.pumpWidget(_wrap(const ScoreChip(
      evaluatorId: 'compile',
      score: 0.875,
    )));
    expect(find.text('compile'), findsOneWidget);
    expect(find.text('0.88'), findsOneWidget);
  });

  testWidgets('null score renders as em-dash', (tester) async {
    await tester.pumpWidget(_wrap(const ScoreChip(
      evaluatorId: 'widget_tree',
      score: null,
    )));
    expect(find.text('\u2014'), findsOneWidget);
  });
}
