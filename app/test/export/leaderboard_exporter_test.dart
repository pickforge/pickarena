import 'dart:convert';

import 'package:dart_arena/export/leaderboard_exporter.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('aggregate-compatible aggregates compatible completed runs', () async {
    await _seedRun(
      db,
      id: 'compatible-old',
      completedAt: DateTime.utc(2026, 5, 1),
    );
    await _seedTaskRun(
      db,
      id: 'old-a',
      runId: 'compatible-old',
      taskId: 'task.a',
      primaryPass: true,
    );
    await _seedTaskRun(
      db,
      id: 'old-b',
      runId: 'compatible-old',
      taskId: 'task.b',
      primaryPass: false,
      failureTag: 'test_failed',
    );
    await _seedRun(
      db,
      id: 'compatible-latest',
      completedAt: DateTime.utc(2026, 5, 2),
    );
    await _seedTaskRun(
      db,
      id: 'latest-a',
      runId: 'compatible-latest',
      taskId: 'task.a',
      primaryPass: true,
    );
    await _seedTaskRun(
      db,
      id: 'latest-b',
      runId: 'compatible-latest',
      taskId: 'task.b',
      primaryPass: null,
      failureTag: 'unknown',
    );
    await _seedRun(
      db,
      id: 'incompatible-version',
      completedAt: DateTime.utc(2026, 4, 30),
    );
    await _seedTaskRun(
      db,
      id: 'incompatible-a',
      runId: 'incompatible-version',
      taskId: 'task.a',
      taskVersion: 2,
      primaryPass: true,
    );
    await _seedTaskRun(
      db,
      id: 'incompatible-b',
      runId: 'incompatible-version',
      taskId: 'task.b',
      primaryPass: true,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
      now: () => DateTime.utc(2026, 5, 31),
    );

    expect(export['generatedAt'], '2026-05-31T00:00:00.000Z');
    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'compatible-latest');
    expect(source['runIds'], ['compatible-latest', 'compatible-old']);
    expect(source['taskCount'], 2);
    expect(source['taskRunCount'], 4);
    expect(source['modelCount'], 1);
    expect(source['warnings'], isEmpty);

    final benchmark = export['benchmark']! as Map<String, Object?>;
    expect(benchmark['dataPolicy'], 'aggregate-compatible');
    expect(benchmark['track'], 'agentic');
  });

  test('latest-run exports only the latest completed run for track', () async {
    await _seedRun(db, id: 'old', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(db, id: 'old-a', runId: 'old', taskId: 'task.a');
    await _seedRun(db, id: 'latest', completedAt: DateTime.utc(2026, 5, 2));
    await _seedTaskRun(db, id: 'latest-a', runId: 'latest', taskId: 'task.a');
    await _seedRun(
      db,
      id: 'new-codegen',
      completedAt: DateTime.utc(2026, 5, 3),
    );
    await _seedTaskRun(
      db,
      id: 'codegen-a',
      runId: 'new-codegen',
      taskId: 'task.a',
      benchmarkTrack: 'codegen',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'latest');
    expect(source['runIds'], ['latest']);
    expect(source['taskRunCount'], 1);
  });

  test('best-observed selects best task runs and respects run-id', () async {
    await _seedRun(db, id: 'r1', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'r1-fail',
      runId: 'r1',
      taskId: 'task.a',
      primaryPass: false,
      aggregateScore: 0.9,
    );
    await _seedRun(db, id: 'r2', completedAt: DateTime.utc(2026, 5, 2));
    await _seedTaskRun(
      db,
      id: 'r2-pass',
      runId: 'r2',
      taskId: 'task.a',
      primaryPass: true,
      aggregateScore: 0.7,
    );

    final best = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.bestObserved,
      ),
    );

    expect(
      (best['benchmark']! as Map<String, Object?>)['dataPolicy'],
      'best-observed',
    );
    final bestModel =
        ((best['models']! as List<Object?>).single! as Map<String, Object?>);
    expect(bestModel['passCount'], 1);
    expect((best['source']! as Map<String, Object?>)['runIds'], ['r1', 'r2']);

    final scoped = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.bestObserved,
        runId: 'r1',
      ),
    );

    final scopedModel =
        ((scoped['models']! as List<Object?>).single! as Map<String, Object?>);
    expect(scopedModel['passCount'], 0);
    expect((scoped['source']! as Map<String, Object?>)['runIds'], ['r1']);
  });

  test('model rows include metrics and rank by contract comparator', () async {
    await _seedRun(db, id: 'metrics', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'openai-pass',
      runId: 'metrics',
      taskId: 'task.a',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: true,
      latencyMs: 1000,
      promptTokens: 10,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-pass',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-pass',
      evaluatorId: 'hidden_test',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'openai-fail',
      runId: 'metrics',
      taskId: 'task.b',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: false,
      failureTag: 'public_tests_failed',
      latencyMs: 3000,
      promptTokens: 30,
      completionTokens: 40,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-fail',
      evaluatorId: 'test',
      passed: false,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-fail',
      evaluatorId: 'hidden_test',
      passed: false,
      details: const {'blocked': true, 'blocked_by': 'test'},
    );
    await _seedTaskRun(
      db,
      id: 'deepseek-pass-a',
      runId: 'metrics',
      taskId: 'task.a',
      providerId: 'deepseek',
      modelId: 'deepseek-v4-pro',
      primaryPass: true,
      latencyMs: 2000,
      promptTokens: 20,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-a',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-a',
      evaluatorId: 'hidden_test',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'deepseek-pass-b',
      runId: 'metrics',
      taskId: 'task.b',
      providerId: 'deepseek',
      modelId: 'deepseek-v4-pro',
      primaryPass: true,
      latencyMs: 2500,
      promptTokens: 20,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-b',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-b',
      evaluatorId: 'hidden_test',
      passed: true,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final models = (export['models']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(models.first['providerId'], 'deepseek');
    expect(models.first['rank'], 1);
    expect(models.first['score'], models.first['passRate']);
    expect(models.first['score'], 1.0);

    final openai = models.singleWhere((row) => row['providerId'] == 'openai');
    expect(openai['passCount'], 1);
    expect(openai['sampleCount'], 2);
    expect(openai['passRate'], 0.5);
    expect(openai['confidenceInterval'], isA<Map<String, Object?>>());
    expect(openai['lowSample'], isTrue);
    expect(openai['medianLatencyMs'], 2000);
    expect(openai['medianPromptTokens'], 20);
    expect(openai['medianCompletionTokens'], 30);
    expect(openai['medianEstimatedCostMicros'], 326);
    expect(openai['knownEstimatedCostCount'], 2);
    expect(openai['unknownEstimatedCostCount'], 0);
    expect(openai['totalEstimatedCostMicros'], 651);
    expect(openai['costPerSolvedTaskMicros'], 651);
    expect(openai['cheapestPassingEstimatedCostMicros'], 213);
    expect(openai['publicPassCount'], 1);
    expect(openai['publicSampleCount'], 2);
    expect(openai['publicPassRate'], 0.5);
    expect(openai['hiddenPassCount'], 1);
    expect(openai['hiddenSampleCount'], 1);
    expect(openai['hiddenPassRate'], 1.0);
    expect(openai['failureBreakdown'], {'pass': 1, 'public_tests_failed': 1});
  });

  test(
    'task rows aggregate by task/version/track using measured samples',
    () async {
      await _seedRun(db, id: 'tasks', completedAt: DateTime.utc(2026, 5, 1));
      await _seedTaskRun(
        db,
        id: 'task-pass',
        runId: 'tasks',
        taskId: 'task.a',
        primaryPass: true,
      );
      await _seedEvaluation(
        db,
        taskRunId: 'task-pass',
        evaluatorId: 'test',
        passed: true,
      );
      await _seedEvaluation(
        db,
        taskRunId: 'task-pass',
        evaluatorId: 'task_hidden',
        passed: true,
      );
      await _seedTaskRun(
        db,
        id: 'task-null',
        runId: 'tasks',
        taskId: 'task.a',
        providerId: 'deepseek',
        modelId: 'deepseek-v4-pro',
        primaryPass: null,
      );
      await _seedTaskRun(
        db,
        id: 'task-fail-v2',
        runId: 'tasks',
        taskId: 'task.a',
        taskVersion: 2,
        primaryPass: false,
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(
          track: 'agentic',
          strategy: LeaderboardExportStrategy.latestRun,
        ),
      );

      final tasks = (export['tasks']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(tasks, hasLength(2));
      expect(tasks.first['taskId'], 'task.a');
      expect(tasks.first['taskVersion'], 1);
      expect(tasks.first['sampleCount'], 1);
      expect(tasks.first['modelCount'], 2);
      expect(tasks.first['passRate'], 1.0);
      expect(tasks.first['publicPassCount'], 1);
      expect(tasks.first['publicSampleCount'], 1);
      expect(tasks.first['hiddenPassCount'], 1);
      expect(tasks.first['hiddenSampleCount'], 1);
      expect(tasks.last['taskVersion'], 2);
      expect(tasks.last['passRate'], 0.0);
    },
  );

  test('public export excludes raw and private task-run fields', () async {
    await _seedRun(db, id: 'safe', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'safe-a',
      runId: 'safe',
      taskId: 'task.a',
      responseText: 'raw prompt secret response',
      patchText: 'diff --git secret patch',
      trajectoryLogPath: '/home/dev/private/trajectory.log',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('raw prompt secret response')));
    expect(encoded, isNot(contains('diff --git secret patch')));
    expect(encoded, isNot(contains('/home/dev/private/trajectory.log')));
  });

  test('malformed or missing provenance warns without excluding', () async {
    await _seedRun(db, id: 'anchor', completedAt: DateTime.utc(2026, 5, 2));
    await _seedTaskRun(db, id: 'anchor-a', runId: 'anchor', taskId: 'task.a');
    await _seedRun(
      db,
      id: 'malformed',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: '{bad',
    );
    await _seedTaskRun(
      db,
      id: 'malformed-a',
      runId: 'malformed',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['runIds'], ['anchor', 'malformed']);
    expect(source['warnings'].toString(), contains('malformed provenance'));
  });

  test('empty matching result set emits empty JSON with warning', () async {
    await _seedRun(db, id: 'codegen', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'codegen-a',
      runId: 'codegen',
      taskId: 'task.a',
      benchmarkTrack: 'codegen',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['taskRunCount'], 0);
    expect(export['models'], isEmpty);
    expect(export['tasks'], isEmpty);
    expect(source['warnings'].toString(), contains('No completed task runs'));
  });
}

Future<void> _seedRun(
  AppDatabase db, {
  required String id,
  required DateTime completedAt,
  String provenanceJson =
      '{"schemaVersion":1,"config":{"evaluatorWeights":{"compile":1.0}}}',
}) async {
  await db
      .into(db.runs)
      .insert(
        RunsCompanion.insert(
          id: id,
          startedAt: completedAt.subtract(const Duration(minutes: 5)),
          completedAt: Value(completedAt),
          provenanceJson: Value(provenanceJson),
        ),
      );
}

Future<void> _seedTaskRun(
  AppDatabase db, {
  required String id,
  required String runId,
  required String taskId,
  String providerId = 'openai',
  String modelId = 'gpt-5',
  int taskVersion = 1,
  String benchmarkTrack = 'agentic',
  String? harnessId = 'harness-v1',
  bool? primaryPass = true,
  String? failureTag,
  int latencyMs = 1000,
  int? promptTokens = 10,
  int? completionTokens = 20,
  double aggregateScore = 1.0,
  String responseText = '',
  String? patchText,
  String? trajectoryLogPath,
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
          latencyMs: latencyMs,
          aggregateScore: aggregateScore,
          completedAt: DateTime.utc(2026, 5, 1, 12),
          promptTokens: Value(promptTokens),
          completionTokens: Value(completionTokens),
          taskVersion: Value(taskVersion),
          benchmarkTrack: Value(benchmarkTrack),
          harnessId: Value(harnessId),
          primaryPass: Value(primaryPass),
          failureTag: Value(failureTag),
          patchText: Value(patchText),
          trajectoryLogPath: Value(trajectoryLogPath),
        ),
      );
}

Future<void> _seedEvaluation(
  AppDatabase db, {
  required String taskRunId,
  required String evaluatorId,
  required bool passed,
  Map<String, Object?> details = const {},
}) async {
  await db
      .into(db.evaluations)
      .insert(
        EvaluationsCompanion.insert(
          id: '$taskRunId-$evaluatorId',
          taskRunId: taskRunId,
          evaluatorId: evaluatorId,
          passed: passed,
          score: passed ? 1.0 : 0.0,
          detailsJson: jsonEncode(details),
        ),
      );
}
