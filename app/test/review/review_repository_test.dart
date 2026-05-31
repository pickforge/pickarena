import 'package:dart_arena/review/review_battle.dart';
import 'package:dart_arena/review/review_repository.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<TaskRun> seedTaskRun(
    AppDatabase db, {
    required String id,
    required String providerId,
    required String modelId,
    String runId = 'run-1',
    String taskId = 'task.a',
    int taskVersion = 1,
    String benchmarkTrack = 'codegen',
    bool? primaryPass = true,
    String responseText = '```dart\nvoid main() {}\n```',
    String? patchText,
  }) async {
    await db
        .into(db.taskRuns)
        .insert(
          TaskRunsCompanion.insert(
            id: id,
            runId: runId,
            providerId: providerId,
            modelId: modelId,
            taskId: taskId,
            responseText: responseText,
            latencyMs: 1,
            aggregateScore: primaryPass == false ? 0 : 1,
            completedAt: DateTime(
              2026,
              5,
              1,
              0,
              0,
              id.codeUnits.fold<int>(0, (sum, code) => sum + code) % 50,
            ),
            taskVersion: Value(taskVersion),
            benchmarkTrack: Value(benchmarkTrack),
            primaryPass: Value(primaryPass),
            patchText: Value(patchText),
          ),
        );
    return (db.select(
      db.taskRuns,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Future<void> seedRun(AppDatabase db, {String runId = 'run-1'}) {
    return db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(id: runId, startedAt: DateTime(2026, 5, 1)),
        );
  }

  test('canonical pair key is stable for swapped sides', () {
    expect(canonicalReviewPairKey('b', 'a'), 'a|b');
  });

  test(
    'inserts battles and rejects duplicate reviewer unordered pair',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedRun(db);
      final left = await seedTaskRun(
        db,
        id: 'tr-a',
        providerId: 'openai',
        modelId: 'gpt-5',
      );
      final right = await seedTaskRun(
        db,
        id: 'tr-b',
        providerId: 'anthropic',
        modelId: 'claude-opus',
      );
      final repo = ReviewRepository(
        db,
        idGenerator: () => 'battle-1',
        now: () => DateTime(2026, 5, 2),
      );

      final battle = await repo.insertBattleForTaskRuns(
        left: left,
        right: right,
        reviewerId: 'reviewer-1',
        vote: ReviewVote.left,
        rationale: 'A is cleaner',
      );

      expect(battle.canonicalPairKey, 'tr-a|tr-b');
      expect(await repo.battlesForReviewer('reviewer-1'), hasLength(1));
      await expectLater(
        () => repo.insertBattleForTaskRuns(
          left: right,
          right: left,
          reviewerId: 'reviewer-1',
          vote: ReviewVote.right,
        ),
        throwsA(isA<SqliteException>()),
      );
    },
  );

  test(
    'nextBattle selects same task version track and excludes reviewed pairs',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedRun(db);
      final a = await seedTaskRun(
        db,
        id: 'tr-a',
        providerId: 'openai',
        modelId: 'gpt-5',
      );
      final b = await seedTaskRun(
        db,
        id: 'tr-b',
        providerId: 'anthropic',
        modelId: 'claude-opus',
      );
      await seedTaskRun(db, id: 'tr-c', providerId: 'deepseek', modelId: 'v4');
      await seedTaskRun(
        db,
        id: 'other-track',
        providerId: 'other',
        modelId: 'model',
        benchmarkTrack: 'agentic',
        patchText: 'diff --git a/a.dart b/a.dart',
        responseText: '',
      );
      final repo = ReviewRepository(db, now: () => DateTime(2026, 5, 2));
      await repo.insertBattleForTaskRuns(
        left: a,
        right: b,
        reviewerId: 'reviewer-1',
        vote: ReviewVote.left,
      );

      final selection = await repo.nextBattle(reviewerId: 'reviewer-1');

      expect(selection, isNotNull);
      expect(selection!.taskId, 'task.a');
      expect(selection.taskVersion, 1);
      expect(selection.benchmarkTrack, 'codegen');
      expect(selection.canonicalPairKey, isNot('tr-a|tr-b'));
      expect({
        selection.left.providerId,
        selection.right.providerId,
      }, isNot(contains('other')));
    },
  );

  test(
    'nextBattle prefers same non-passing bucket before mixed buckets',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedRun(db);
      await seedTaskRun(
        db,
        id: 'pass',
        providerId: 'p1',
        modelId: 'm1',
        primaryPass: true,
      );
      await seedTaskRun(
        db,
        id: 'fail-a',
        providerId: 'p2',
        modelId: 'm2',
        primaryPass: false,
      );
      await seedTaskRun(
        db,
        id: 'fail-b',
        providerId: 'p3',
        modelId: 'm3',
        primaryPass: false,
      );
      final repo = ReviewRepository(db);

      final selection = await repo.nextBattle(reviewerId: 'reviewer-1');

      expect(selection, isNotNull);
      expect(selection!.left.primaryPass, isFalse);
      expect(selection.right.primaryPass, isFalse);
    },
  );

  test('nextBattle falls back to same-model pairs only when needed', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedRun(db);
    await seedTaskRun(db, id: 'same-a', providerId: 'openai', modelId: 'gpt-5');
    await seedTaskRun(db, id: 'same-b', providerId: 'openai', modelId: 'gpt-5');
    final repo = ReviewRepository(db);

    final selection = await repo.nextBattle(reviewerId: 'reviewer-1');

    expect(selection, isNotNull);
    expect(selection!.left.providerId, selection.right.providerId);
    expect(selection.left.modelId, selection.right.modelId);
  });

  test('nextBattle requires review artifacts', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedRun(db);
    await seedTaskRun(
      db,
      id: 'agent-a',
      providerId: 'p1',
      modelId: 'm1',
      benchmarkTrack: 'agentic',
      responseText: '',
    );
    await seedTaskRun(
      db,
      id: 'agent-b',
      providerId: 'p2',
      modelId: 'm2',
      benchmarkTrack: 'agentic',
      responseText: '',
    );
    final repo = ReviewRepository(db);

    expect(await repo.nextBattle(reviewerId: 'reviewer-1'), isNull);
  });

  test('quality rankings are computed from stored review battles', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedRun(db);
    final left = await seedTaskRun(
      db,
      id: 'tr-a',
      providerId: 'openai',
      modelId: 'gpt-5',
    );
    final right = await seedTaskRun(
      db,
      id: 'tr-b',
      providerId: 'anthropic',
      modelId: 'claude-opus',
    );
    final repo = ReviewRepository(db, idGenerator: () => 'battle-1');
    await repo.insertBattleForTaskRuns(
      left: left,
      right: right,
      reviewerId: 'reviewer-1',
      vote: ReviewVote.left,
      rationale: 'Better tests',
    );

    final rankings = await repo.qualityRankings(minimumVotes: 1);

    expect(rankings.first.providerId, 'openai');
    expect(rankings.first.displayScore, 1);
    expect(rankings.first.rationales, ['Better tests']);
  });
}
