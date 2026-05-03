import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/pages/run_history_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RunDao> _seed({String? labelA, String? labelB}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(
    runId: 'a',
    startedAt: DateTime(2026, 5, 2, 10),
    name: labelA,
  );
  await dao.persistTaskRun(TaskRunResult(
    runId: 'a',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'bug.a',
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration.zero,
    ),
    evaluations: const [
      EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
    ],
    aggregateScore: 1.0,
    completedAt: DateTime(2026, 5, 2, 10, 5),
  ));
  await dao.startRun(
    runId: 'b',
    startedAt: DateTime(2026, 5, 1),
    name: labelB,
  );
  return dao;
}

void main() {
  testWidgets('shows empty state when no runs', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(MaterialApp(
      home: RunHistoryPage(dao: RunDao(db)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No runs yet'), findsOneWidget);
  });

  testWidgets('lists runs with labels and timestamp fallback',
      (tester) async {
    final dao = await _seed(labelA: 'experiment-1');
    await tester.pumpWidget(MaterialApp(
      home: RunHistoryPage(dao: dao),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('experiment-1'), findsOneWidget);
    expect(find.text('Run b'), findsOneWidget);
  });

  testWidgets('label search filters the list', (tester) async {
    final dao = await _seed(labelA: 'deepseek vs claude', labelB: 'gpt sweep');
    await tester.pumpWidget(MaterialApp(
      home: RunHistoryPage(dao: dao),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('deepseek vs claude'), findsOneWidget);
    expect(find.text('gpt sweep'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'deepseek');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('deepseek vs claude'), findsOneWidget);
    expect(find.text('gpt sweep'), findsNothing);
  });
}
