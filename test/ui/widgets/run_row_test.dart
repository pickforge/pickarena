import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/run_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Run _r({String? name}) => Run(
      id: 'r1',
      startedAt: DateTime(2026, 5, 2, 10),
      completedAt: DateTime(2026, 5, 2, 10, 5),
      judgeModel: null,
      name: name,
    );

TaskRun _tr(double agg) => TaskRun(
      id: 'tr-${agg.toStringAsFixed(2)}',
      runId: 'r1',
      providerId: 'p',
      modelId: 'm',
      taskId: 't',
      responseText: '',
      promptTokens: null,
      completionTokens: null,
      latencyMs: 1000,
      aggregateScore: agg,
      completedAt: DateTime(2026, 5, 2, 10, 4),
    );

void main() {
  testWidgets('renders run name when present', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunRow(
          run: _r(name: 'experiment-1'),
          taskRuns: [_tr(0.8)],
          onTap: () {},
        ),
      ),
    ));
    expect(find.text('experiment-1'), findsOneWidget);
  });

  testWidgets('falls back to "Run <id>" when name is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunRow(
          run: _r(name: null),
          taskRuns: [_tr(0.8)],
          onTap: () {},
        ),
      ),
    ));
    expect(find.text('Run r1'), findsOneWidget);
  });

  testWidgets('shows progress indicator when run is in progress',
      (tester) async {
    final inProgress = Run(
      id: 'r1',
      startedAt: DateTime(2026, 5, 2),
      completedAt: null,
      judgeModel: null,
      name: null,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunRow(run: inProgress, taskRuns: const [], onTap: () {}),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('tapping invokes onTap callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RunRow(
          run: _r(name: 'x'),
          taskRuns: [_tr(0.5)],
          onTap: () => taps++,
        ),
      ),
    ));
    await tester.tap(find.byType(ListTile));
    expect(taps, 1);
  });
}
