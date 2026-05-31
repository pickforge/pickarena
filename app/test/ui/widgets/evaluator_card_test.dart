import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/evaluator_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Evaluation _eval({
  required String id,
  required bool passed,
  required double score,
  String? rationale,
  String detailsJson = '{}',
}) => Evaluation(
  id: 'e1',
  taskRunId: 'tr1',
  evaluatorId: id,
  passed: passed,
  score: score,
  rationale: rationale,
  detailsJson: detailsJson,
);

void main() {
  testWidgets('renders evaluator id, score, pass badge, rationale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        EvaluatorCard(
          evaluation: _eval(
            id: 'compile',
            passed: true,
            score: 1.0,
            rationale: 'compiles cleanly',
          ),
        ),
      ),
    );
    expect(find.text('compile'), findsOneWidget);
    expect(find.text('1.00'), findsOneWidget);
    expect(find.text('PASS'), findsOneWidget);
    expect(find.text('compiles cleanly'), findsOneWidget);
  });

  testWidgets('renders FAIL badge when passed is false', (tester) async {
    await tester.pumpWidget(
      _wrap(
        EvaluatorCard(evaluation: _eval(id: 'test', passed: false, score: 0.0)),
      ),
    );
    expect(find.text('FAIL'), findsOneWidget);
  });

  testWidgets('details JSON appears when expansion tile is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        EvaluatorCard(
          evaluation: _eval(
            id: 'analyze',
            passed: true,
            score: 0.9,
            detailsJson: '{"warnings": 1}',
          ),
        ),
      ),
    );
    expect(find.textContaining('warnings'), findsNothing);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('warnings'), findsOneWidget);
  });

  testWidgets('renders ignored evaluator status before details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        EvaluatorCard(
          evaluation: _eval(
            id: 'llm_judge',
            passed: false,
            score: 0,
            detailsJson: '{"ignored": true, "reason": "objective_failure"}',
          ),
        ),
      ),
    );

    expect(find.text('Ignored: objective_failure'), findsOneWidget);
  });
}
