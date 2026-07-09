import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/cost_estimator.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

Future<({AppDatabase db, RunDao dao})> _seed() async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
  await dao.persistTaskRun(
    TaskRunResult(
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
        EvaluationResult(evaluatorId: 'test', passed: true, score: 1.0),
      ],
      aggregateScore: 1.0,
      completedAt: DateTime(2026, 5, 1, 0, 5),
    ),
  );
  await dao.persistTaskRun(
    TaskRunResult(
      runId: 'r1',
      providerId: 'anthropic',
      modelId: 'claude-opus-4.7',
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
        EvaluationResult(evaluatorId: 'test', passed: false, score: 0.0),
      ],
      aggregateScore: 0.5,
      completedAt: DateTime(2026, 5, 1, 0, 6),
    ),
  );
  await dao.finishRun('r1', DateTime(2026, 5, 1, 0, 10));
  return (db: db, dao: dao);
}

void main() {
  test('rank returns one ModelRanking per (provider, model) pair', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);

    final rows = await repo.rank(filter: const LeaderboardFilter());

    expect(rows.length, 2);
    final providers = rows.map((r) => r.providerId).toSet();
    expect(providers, {'openai', 'anthropic'});
  });

  test('rank sorts descending by current dimension', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);

    final overall = await repo.rank(filter: const LeaderboardFilter());
    expect(overall.first.modelId, 'gpt-5');
    expect(overall.last.modelId, 'claude-opus-4.7');
  });

  test('provider filter narrows the list', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);
    final rows = await repo.rank(
      filter: const LeaderboardFilter(providerId: 'openai'),
    );
    expect(rows.length, 1);
    expect(rows.single.providerId, 'openai');
  });

  test('track filter separates codegen and agentic runs', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
    Future<void> seed(String provider, BenchmarkTrack track) {
      return dao.persistTaskRun(
        TaskRunResult(
          runId: 'r1',
          providerId: provider,
          modelId: 'm',
          taskId: 'bug.x',
          response: const ModelResponse(
            rawText: '',
            extractedCode: null,
            promptTokens: null,
            completionTokens: null,
            latency: Duration(milliseconds: 1),
          ),
          evaluations: const [],
          aggregateScore: 1.0,
          completedAt: DateTime(2026, 5, 1, 0, 5),
          benchmarkTrack: track.name,
        ),
      );
    }

    await seed('codegen-provider', BenchmarkTrack.codegen);
    await seed('agent-provider', BenchmarkTrack.agentic);

    final repo = LeaderboardRepository(db);
    final rows = await repo.rank(
      filter: const LeaderboardFilter(track: BenchmarkTrack.agentic),
    );
    expect(rows, hasLength(1));
    expect(rows.single.providerId, 'agent-provider');

    await db.close();
  });

  test('date range filter excludes runs outside the window', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db, now: () => DateTime(2026, 4, 1));
    final rows = await repo.rank(
      filter: const LeaderboardFilter(dateRange: DateRange.last7d),
    );
    expect(rows, isEmpty);
  });

  test('category filter intersects with provided taskIdsForCategory', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);
    final rows = await repo.rank(
      filter: const LeaderboardFilter(category: Category.bugFix),
      taskIdsForCategory: {'bug.off_by_one_pagination'},
    );
    expect(rows.length, 2);

    final rows2 = await repo.rank(
      filter: const LeaderboardFilter(category: Category.uiFromSpec),
      taskIdsForCategory: {'ui.profile_card'},
    );
    expect(rows2, isEmpty);
  });

  test('metadata filters intersect with provided taskIdsForFilter', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);

    final rows = await repo.rank(
      filter: const LeaderboardFilter(
        difficulty: TaskDifficulty.hard,
        tags: {TaskTag.bugfix},
      ),
      taskIdsForFilter: {'bug.off_by_one_pagination'},
    );
    expect(rows.length, 2);

    final empty = await repo.rank(
      filter: const LeaderboardFilter(difficulty: TaskDifficulty.hard),
      taskIdsForFilter: const {},
    );
    expect(empty, isEmpty);
  });

  test('rank by speed sorts by latency, not aggregateScore', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
    Future<void> seedTr(String provider, int latencyMs) => dao.persistTaskRun(
      TaskRunResult(
        runId: 'r1',
        providerId: provider,
        modelId: 'm',
        taskId: 'bug.x',
        response: ModelResponse(
          rawText: '',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration(milliseconds: latencyMs),
        ),
        evaluations: const [
          EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
        ],
        aggregateScore: 1.0,
        completedAt: DateTime(2026, 5, 1, 0, 5),
      ),
    );
    await seedTr('fast', 2000);
    await seedTr('slow', 50000);

    final repo = LeaderboardRepository(db);
    final rows = await repo.rank(
      filter: const LeaderboardFilter(dimension: ScoreDimension.speed),
    );
    expect(rows.first.providerId, 'fast');
  });

  test('rank exposes primary pass summary and reliability uses it', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
    Future<void> seed({
      required String provider,
      required double aggregate,
      required bool primaryPass,
    }) {
      return dao.persistTaskRun(
        TaskRunResult(
          runId: 'r1',
          providerId: provider,
          modelId: 'm',
          taskId: 'bug.x',
          response: const ModelResponse(
            rawText: '',
            extractedCode: null,
            promptTokens: null,
            completionTokens: null,
            latency: Duration(milliseconds: 5000),
          ),
          evaluations: const [],
          aggregateScore: aggregate,
          completedAt: DateTime(2026, 5, 1, 0, 5),
          primaryPass: primaryPass,
          failureTag: primaryPass ? 'pass' : 'public_tests_failed',
        ),
      );
    }

    await seed(provider: 'measured-pass', aggregate: 0.1, primaryPass: true);
    await seed(provider: 'measured-fail', aggregate: 1.0, primaryPass: false);

    final repo = LeaderboardRepository(db);
    final rows = await repo.rank(
      filter: const LeaderboardFilter(dimension: ScoreDimension.reliability),
    );

    expect(rows.first.providerId, 'measured-pass');
    expect(rows.first.primaryPassCount, 1);
    expect(rows.first.primaryPassSampleCount, 1);
    expect(rows.first.primaryPassRate, 1.0);
    expect(rows.last.primaryPassRate, 0.0);

    await db.close();
  });

  test(
    'rank computes reliable statistics, cost summaries, and failures',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = RunDao(db);
      await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
      for (var i = 0; i < 3; i++) {
        final pass = i != 1;
        await dao.persistTaskRun(
          TaskRunResult(
            runId: 'r1',
            providerId: 'p',
            modelId: 'm',
            taskId: 'task-$i',
            response: ModelResponse(
              rawText: '',
              extractedCode: null,
              promptTokens: 10 + i * 10,
              completionTokens: 20 + i * 10,
              latency: Duration(milliseconds: 1000 + i * 1000),
            ),
            evaluations: const [],
            aggregateScore: pass ? 1 : 0,
            completedAt: DateTime(2026, 5, 1, 0, i),
            primaryPass: pass,
            failureTag: pass ? 'pass' : 'compile_failed',
          ),
        );
      }

      final repo = LeaderboardRepository(
        db,
        costEstimator: const CostEstimator(
          pricingRegistry: {
            'p:m': ModelPricing(inputCostPerMToken: 1, outputCostPerMToken: 3),
          },
        ),
      );
      final row = (await repo.rank(filter: const LeaderboardFilter())).single;

      expect(row.primaryPassCount, 2);
      expect(row.primaryPassSampleCount, 3);
      expect(row.primaryPassInterval, isNotNull);
      expect(row.lowSample, isTrue);
      expect(row.medianLatencyMs, 2000);
      expect(row.medianPromptTokens, 20);
      expect(row.medianCompletionTokens, 30);
      expect(row.medianEstimatedCostMicros, 110);
      expect(row.knownEstimatedCostCount, 3);
      expect(row.unknownEstimatedCostCount, 0);
      expect(row.totalEstimatedCostMicros, 330);
      expect(row.costPerSolvedTaskMicros, 165);
      expect(row.cheapestPassingEstimatedCostMicros, 70);
      expect(row.failureBreakdown['pass'], 2);
      expect(row.failureBreakdown['compile_failed'], 1);

      await db.close();
    },
  );

  test(
    'default rank uses reliable comparator before legacy aggregate',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = RunDao(db);
      await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
      Future<void> seed({
        required String provider,
        required int index,
        bool? primaryPass,
        double aggregate = 1,
      }) {
        return dao.persistTaskRun(
          TaskRunResult(
            runId: 'r1',
            providerId: provider,
            modelId: 'm',
            taskId: 'task-$index',
            response: const ModelResponse(
              rawText: '',
              extractedCode: null,
              promptTokens: null,
              completionTokens: null,
              latency: Duration(milliseconds: 1000),
            ),
            evaluations: const [],
            aggregateScore: aggregate,
            completedAt: DateTime(2026, 5, 1, 0, index),
            primaryPass: primaryPass,
            failureTag: primaryPass == true
                ? 'pass'
                : primaryPass == false
                ? 'public_tests_failed'
                : null,
          ),
        );
      }

      for (var i = 0; i < 5; i++) {
        await seed(provider: 'four-of-five', index: i, primaryPass: i != 0);
      }
      await seed(provider: 'one-shot', index: 10, primaryPass: true);
      await seed(provider: 'legacy-high', index: 11, primaryPass: null);

      final repo = LeaderboardRepository(db);
      final rows = await repo.rank(filter: const LeaderboardFilter());

      expect(rows.map((row) => row.providerId), [
        'four-of-five',
        'one-shot',
        'legacy-high',
      ]);

      await db.close();
    },
  );

  test('detail returns one PerTaskScore per task within filter', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db);
    final detail = await repo.detail(
      providerId: 'openai',
      modelId: 'gpt-5',
      filter: const LeaderboardFilter(),
    );
    expect(detail.ranking.providerId, 'openai');
    expect(detail.perTask.length, 1);
    expect(detail.perTask.single.taskId, 'bug.off_by_one_pagination');
    expect(detail.perTask.single.aggregateScore, 1.0);
    expect(detail.perTask.single.lastRunId, 'r1');
    expect(detail.perTask.single.lastTaskRunId, isNotNull);
  });

  test('detail picks the most recent task-run per (model, task)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 1));
    Future<void> seed(DateTime when, double agg) => dao.persistTaskRun(
      TaskRunResult(
        runId: 'r1',
        providerId: 'p',
        modelId: 'm',
        taskId: 'bug.x',
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
        aggregateScore: agg,
        completedAt: when,
      ),
    );
    await seed(DateTime(2026, 5, 1, 0, 5), 0.4);
    await seed(DateTime(2026, 5, 1, 0, 10), 0.9);
    final repo = LeaderboardRepository(db);
    final detail = await repo.detail(
      providerId: 'p',
      modelId: 'm',
      filter: const LeaderboardFilter(),
    );
    expect(detail.perTask.single.aggregateScore, 0.9);
  });

  test('detail returns empty perTask when filter excludes all', () async {
    final s = await _seed();
    final repo = LeaderboardRepository(s.db, now: () => DateTime(2026, 4, 1));
    final detail = await repo.detail(
      providerId: 'openai',
      modelId: 'gpt-5',
      filter: const LeaderboardFilter(dateRange: DateRange.last7d),
    );
    expect(detail.perTask, isEmpty);
    expect(detail.ranking.dimensions, Dimensions.zero);
  });
}
