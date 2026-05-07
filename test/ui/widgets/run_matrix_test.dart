import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/run_matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TaskRun _tr(String taskId, String providerId, String modelId, double score) =>
    TaskRun(
      id: '$taskId-$providerId-$modelId',
      runId: 'r1',
      providerId: providerId,
      modelId: modelId,
      taskId: taskId,
      responseText: '',
      promptTokens: null,
      completionTokens: null,
      latencyMs: 1,
      aggregateScore: score,
      completedAt: DateTime(2026, 5, 2),
    );

void main() {
  testWidgets('renders one row per task and one column per provider/model', (
    tester,
  ) async {
    final taskRuns = [
      _tr('bug.a', 'openai', 'gpt-5', 0.9),
      _tr('bug.a', 'anthropic', 'sonnet', 0.7),
      _tr('state.b', 'openai', 'gpt-5', 1.0),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunMatrix(taskRuns: taskRuns, onCellTap: (_) {}),
        ),
      ),
    );

    expect(find.text('bug.a'), findsOneWidget);
    expect(find.text('state.b'), findsOneWidget);
    expect(find.text('openai/gpt-5'), findsOneWidget);
    expect(find.text('anthropic/sonnet'), findsOneWidget);
    expect(find.text('0.90'), findsOneWidget);
    expect(find.text('1.00'), findsOneWidget);
  });

  testWidgets('cell tap invokes callback with the right task run', (
    tester,
  ) async {
    final taskRuns = [_tr('bug.a', 'openai', 'gpt-5', 0.9)];
    TaskRun? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunMatrix(taskRuns: taskRuns, onCellTap: (tr) => tapped = tr),
        ),
      ),
    );
    await tester.tap(find.text('0.90'));
    expect(tapped, isNotNull);
    expect(tapped!.taskId, 'bug.a');
  });

  testWidgets('renders em-dash for missing cells', (tester) async {
    final taskRuns = [
      _tr('bug.a', 'openai', 'gpt-5', 0.9),
      _tr('state.b', 'anthropic', 'sonnet', 1.0),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunMatrix(taskRuns: taskRuns, onCellTap: (_) {}),
        ),
      ),
    );
    // bug.a x anthropic/sonnet and state.b x openai/gpt-5 are missing.
    expect(find.text('\u2014'), findsNWidgets(2));
  });
}
