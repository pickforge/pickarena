import 'dart:convert';

import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists a TaskRunResult and its evaluations', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);

    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 2));
    await dao.persistTaskRun(
      TaskRunResult(
        runId: 'r1',
        providerId: 'ollama_local',
        modelId: 'llama3',
        taskId: 'bug.off_by_one_pagination',
        response: const ModelResponse(
          rawText: 'hi',
          extractedCode: 'code',
          promptTokens: 1,
          completionTokens: 2,
          latency: Duration(milliseconds: 50),
        ),
        evaluations: const [
          EvaluationResult(
            evaluatorId: 'compile',
            passed: true,
            score: 1.0,
          ),
        ],
        aggregateScore: 1.0,
        completedAt: DateTime(2026, 5, 2),
      ),
    );

    final loaded = await dao.taskRunsForRun('r1');
    expect(loaded, hasLength(1));
    expect(loaded.first.aggregateScore, 1.0);
    expect(
      jsonDecode(
        (await dao.evaluationsForTaskRun(loaded.first.id)).first.detailsJson,
      ),
      isMap,
    );

    await db.close();
  });

  test('startRun persists optional name', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(
      runId: 'r1',
      startedAt: DateTime(2026, 5, 2),
      name: 'experiment-1',
    );
    final row = await dao.runById('r1');
    expect(row, isNotNull);
    expect(row!.name, 'experiment-1');
    await db.close();
  });

  test('runById returns null for unknown id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    expect(await dao.runById('nope'), isNull);
    await db.close();
  });

  test('taskRunById returns the matching task run', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 2));
    await dao.persistTaskRun(
      TaskRunResult(
        runId: 'r1',
        providerId: 'fake',
        modelId: 'm',
        taskId: 't',
        response: const ModelResponse(
          rawText: 'x',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        evaluations: const [],
        aggregateScore: 0.5,
        completedAt: DateTime(2026, 5, 2, 12),
      ),
    );
    final all = await dao.taskRunsForRun('r1');
    expect(all, hasLength(1));
    final fetched = await dao.taskRunById(all.first.id);
    expect(fetched, isNotNull);
    expect(fetched!.taskId, 't');
    await db.close();
  });

  test('recentRuns(labelQuery) filters by LIKE on name', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(
      runId: 'a',
      startedAt: DateTime(2026, 5, 1),
      name: 'deepseek vs claude',
    );
    await dao.startRun(
      runId: 'b',
      startedAt: DateTime(2026, 5, 2),
      name: 'gpt sweep',
    );
    await dao.startRun(runId: 'c', startedAt: DateTime(2026, 5, 3));

    final all = await dao.recentRuns();
    expect(all, hasLength(3));

    final filtered = await dao.recentRuns(labelQuery: 'deepseek');
    expect(filtered, hasLength(1));
    expect(filtered.first.id, 'a');

    final empty = await dao.recentRuns(labelQuery: 'nomatch');
    expect(empty, isEmpty);

    await db.close();
  });

  test('recentRuns ignores empty labelQuery', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'a', startedAt: DateTime(2026, 5, 1));
    final all = await dao.recentRuns(labelQuery: '');
    expect(all, hasLength(1));
    await db.close();
  });

  test('persistTaskRun stores planId when set on TaskRunResult', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    final planDao = PlanDao(db);
    await dao.startRun(runId: 'r-pid', startedAt: DateTime(2026, 1, 1));
    final planId = await planDao.upsertReferencePlan(
      taskId: 'task-x',
      version: 1,
      artifact: 'plan',
    );
    await dao.persistTaskRun(TaskRunResult(
      runId: 'r-pid',
      providerId: 'p',
      modelId: 'm',
      taskId: 'task-x',
      response: const ModelResponse(
        rawText: '',
        extractedCode: null,
        promptTokens: 0,
        completionTokens: 0,
        latency: Duration.zero,
      ),
      evaluations: const [],
      aggregateScore: 1.0,
      completedAt: DateTime(2026, 1, 1, 0, 1),
      planId: planId,
    ));

    final rows = await dao.taskRunsForRun('r-pid');
    expect(rows.single.planId, planId);

    await db.close();
  });
}
