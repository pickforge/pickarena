import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/pages/leaderboard_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({AppDatabase db, LeaderboardRepository repo})> _seed() async {
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
  await dao.finishRun('r1', DateTime(2026, 5, 1, 0, 10));
  return (db: db, repo: LeaderboardRepository(db));
}

void main() {
  testWidgets('shows the seeded model in the ranked list', (tester) async {
    final s = await _seed();
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }
    await tester.pumpWidget(MaterialApp(
      home: LeaderboardPage(
        repository: s.repo,
        registry: registry,
        initialQuery: const {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('gpt-5'), findsOneWidget);
  });

  testWidgets('initialQuery applies dimension filter', (tester) async {
    final s = await _seed();
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }
    await tester.pumpWidget(MaterialApp(
      home: LeaderboardPage(
        repository: s.repo,
        registry: registry,
        initialQuery: const {'dim': 'speed'},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Speed'), findsWidgets);
  });

  testWidgets('shows empty-state on the right pane when nothing matches',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LeaderboardRepository(db);
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }
    await tester.pumpWidget(MaterialApp(
      home: LeaderboardPage(
        repository: repo,
        registry: registry,
        initialQuery: const {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('No models match'), findsWidgets);
  });
}
