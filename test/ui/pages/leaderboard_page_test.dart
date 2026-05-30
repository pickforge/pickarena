import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/review/review_battle.dart';
import 'package:dart_arena/review/review_repository.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/pages/leaderboard_page.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({AppDatabase db, LeaderboardRepository repo})> _seed({
  String providerId = 'openai',
  String modelId = 'gpt-5',
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
  await dao.persistTaskRun(
    TaskRunResult(
      runId: 'r1',
      providerId: providerId,
      modelId: modelId,
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
    ),
  );
  await dao.finishRun('r1', DateTime(2026, 5, 1, 0, 10));
  return (db: db, repo: LeaderboardRepository(db));
}

void main() {
  testWidgets('leaderboard page states', (tester) async {
    final registry = buildDefaultTaskRegistry();
    for (final t in registry.all()) {
      await t.ensureLoaded();
    }

    // 1. Shows the seeded model in the ranked list
    final s1 = await _seed();
    addTearDown(() async => s1.db.close());
    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardPage(
          repository: s1.repo,
          registry: registry,
          initialQuery: const {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Correctness'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('gpt-5'), findsOneWidget);
    expect(find.textContaining('Reliable pass rate'), findsOneWidget);

    // 2. initialQuery applies dimension filter
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final s2 = await _seed();
    addTearDown(() async => s2.db.close());
    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardPage(
          repository: s2.repo,
          registry: registry,
          initialQuery: const {'dim': 'speed'},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Speed'), findsWidgets);

    // 3. Shows empty-state on the right pane when nothing matches
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = LeaderboardRepository(db);
    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardPage(
          repository: repo,
          registry: registry,
          initialQuery: const {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('No models match'), findsWidgets);
  });

  test('selection key parsing preserves model IDs containing ":"', () {
    final parsed = splitLeaderboardSelectionKey(
      'ollama_local:qwen2.5-coder:32b',
    );

    expect(parsed.providerId, 'ollama_local');
    expect(parsed.modelId, 'qwen2.5-coder:32b');
  });

  test('quality votes stay separate from correctness ranking data', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => db.close());
    await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(
            id: 'r-quality',
            startedAt: DateTime(2026, 5, 1),
          ),
        );
    Future<TaskRun> insertTaskRun({
      required String id,
      required String providerId,
      required String modelId,
      required bool primaryPass,
    }) async {
      await db
          .into(db.taskRuns)
          .insert(
            TaskRunsCompanion.insert(
              id: id,
              runId: 'r-quality',
              providerId: providerId,
              modelId: modelId,
              taskId: 'bug.off_by_one_pagination',
              responseText: '',
              latencyMs: 1,
              aggregateScore: primaryPass ? 1 : 0,
              completedAt: DateTime(2026, 5, 1),
              primaryPass: Value(primaryPass),
            ),
          );
      return (db.select(
        db.taskRuns,
      )..where((row) => row.id.equals(id))).getSingle();
    }

    final left = await insertTaskRun(
      id: 'tr-left',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: true,
    );
    final right = await insertTaskRun(
      id: 'tr-right',
      providerId: 'anthropic',
      modelId: 'claude-opus',
      primaryPass: false,
    );
    final reviewRepo = ReviewRepository(
      db,
      idGenerator: () => 'quality-battle-1',
    );
    await reviewRepo.insertBattleForTaskRuns(
      left: left,
      right: right,
      reviewerId: 'reviewer-1',
      vote: ReviewVote.left,
    );
    final qualityRows = await reviewRepo.qualityRankings();
    expect(qualityRows, isNotEmpty);
    expect(qualityRows.first.displayScore, isNull);
    expect(qualityRows.first.lowVoteCount, isTrue);

    final correctnessRows = await LeaderboardRepository(
      db,
    ).rank(filter: const LeaderboardFilter());
    expect(correctnessRows.first.modelId, 'gpt-5');
    expect(correctnessRows.first.primaryPassRate, 1);
  });
}
