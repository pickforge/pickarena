import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/pages/dashboard_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({RunDao dao, LeaderboardRepository repo, AppDatabase db})> _seed({
  bool inProgress = false,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
  await dao.persistTaskRun(TaskRunResult(
    runId: 'r1',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'bug.off_by_one_pagination',
    response: const ModelResponse(
      rawText: '',
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: Duration(milliseconds: 5000),
    ),
    evaluations: const [
      EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
    ],
    aggregateScore: 1.0,
    completedAt: DateTime(2026, 5, 1, 0, 5),
  ));
  if (!inProgress) {
    await dao.finishRun('r1', DateTime(2026, 5, 1, 0, 10));
  }
  return (dao: dao, repo: LeaderboardRepository(db), db: db);
}

void main() {
  testWidgets('dashboard page states', (tester) async {
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }

    // 1. Shows showcase strip + recent run when data exists
    final s1 = await _seed();
    addTearDown(() async => s1.db.close());
    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(
        dao: s1.dao,
        repository: s1.repo,
        registry: registry,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Bug fix'), findsOneWidget);
    expect(find.text('gpt-5'), findsWidgets);
    expect(find.text('Recent runs'), findsOneWidget);

    // 2. Shows in-progress banner when applicable
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final s2 = await _seed(inProgress: true);
    addTearDown(() async => s2.db.close());
    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(
        dao: s2.dao,
        repository: s2.repo,
        registry: registry,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('In progress'), findsOneWidget);

    // 3. Shows fresh-install empty state when no runs
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => db.close());
    await tester.pumpWidget(MaterialApp(
      home: DashboardPage(
        dao: RunDao(db),
        repository: LeaderboardRepository(db),
        registry: registry,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Run your first benchmark'), findsOneWidget);
  });
}
