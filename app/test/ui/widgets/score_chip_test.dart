import 'package:dart_arena/ui/widgets/score_chip.dart';
import 'package:dart_arena/core/evaluation_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('renders evaluator id and 2-decimal score', (tester) async {
    await tester.pumpWidget(
      _wrap(const ScoreChip(evaluatorId: 'compile', score: 0.875)),
    );
    expect(find.text('compile'), findsOneWidget);
    expect(find.text('0.88'), findsOneWidget);
  });

  testWidgets('null score renders as em-dash', (tester) async {
    await tester.pumpWidget(
      _wrap(const ScoreChip(evaluatorId: 'widget_tree', score: null)),
    );
    expect(find.text('\u2014'), findsOneWidget);
  });

  testWidgets('blocked status renders explicit blocked label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ScoreChip(
          evaluatorId: 'test',
          score: 0,
          status: EvaluationStatus.blocked,
        ),
      ),
    );
    expect(find.text('test'), findsOneWidget);
    expect(find.text('blocked'), findsOneWidget);
    expect(find.text('0.00'), findsNothing);
  });
}
