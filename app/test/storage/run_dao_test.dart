import 'dart:convert';

import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

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
          EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
        ],
        aggregateScore: 1.0,
        completedAt: DateTime(2026, 5, 2),
      ),
    );

    final loaded = await dao.taskRunsForRun('r1');
    expect(loaded, hasLength(1));
    expect(loaded.first.aggregateScore, 1.0);
    expect(loaded.first.trialIndex, 0);
    expect(loaded.first.taskVersion, 1);
    expect(loaded.first.benchmarkTrack, 'codegen');
    expect(loaded.first.harnessId, isNull);
    expect(loaded.first.primaryPass, isNull);
    expect(loaded.first.failureTag, isNull);
    expect(loaded.first.patchText, isNull);
    expect(loaded.first.trajectoryLogPath, isNull);
    expect(
      jsonDecode(
        (await dao.evaluationsForTaskRun(loaded.first.id)).first.detailsJson,
      ),
      isMap,
    );

    await db.close();
  });

  test('persistTaskRun stores result primitive metadata', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);

    await dao.startRun(runId: 'r-meta', startedAt: DateTime(2026, 5, 2));
    await dao.persistTaskRun(
      TaskRunResult(
        runId: 'r-meta',
        providerId: 'p',
        modelId: 'm',
        taskId: 't',
        response: const ModelResponse(
          rawText: 'ok',
          extractedCode: 'ok',
          promptTokens: null,
          completionTokens: null,
          latency: Duration(milliseconds: 10),
        ),
        evaluations: const [],
        aggregateScore: 1.0,
        completedAt: DateTime(2026, 5, 2, 12),
        trialIndex: 2,
        taskVersion: 3,
        benchmarkTrack: 'planning',
        harnessId: 'h1',
        primaryPass: true,
        failureTag: 'pass',
        patchText: 'diff --git a/lib/a.dart b/lib/a.dart\n',
        trajectoryLogPath: '/tmp/trajectory.log',
      ),
    );

    final row = (await dao.taskRunsForRun('r-meta')).single;
    expect(row.trialIndex, 2);
    expect(row.taskVersion, 3);
    expect(row.benchmarkTrack, 'planning');
    expect(row.harnessId, 'h1');
    expect(row.primaryPass, isTrue);
    expect(row.failureTag, 'pass');
    expect(row.patchText, contains('diff --git'));
    expect(row.trajectoryLogPath, '/tmp/trajectory.log');

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

  test('startRun persists optional provenance', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(
      runId: 'r-prov',
      startedAt: DateTime(2026, 5, 2),
      provenanceJson: '{"schemaVersion":1}',
    );
    final row = await dao.runById('r-prov');
    expect(row, isNotNull);
    expect(row!.provenanceJson, '{"schemaVersion":1}');
    await db.close();
  });

  test('updateRunProvenance overwrites provenance explicitly', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(
      runId: 'r-prov-update',
      startedAt: DateTime(2026, 5, 2),
      provenanceJson: '{"schemaVersion":1,"old":true}',
    );

    await dao.updateRunProvenance(
      'r-prov-update',
      '{"schemaVersion":1,"new":true}',
    );

    final row = await dao.runById('r-prov-update');
    expect(row!.provenanceJson, '{"schemaVersion":1,"new":true}');
    await db.close();
  });

  test(
    'backfillRunProvenanceIfNull preserves existing non-null value',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = RunDao(db);
      await dao.startRun(
        runId: 'r-prov-keep',
        startedAt: DateTime(2026, 5, 2),
        provenanceJson: '{"schemaVersion":1,"keep":true}',
      );

      await dao.backfillRunProvenanceIfNull(
        'r-prov-keep',
        '{"schemaVersion":1,"replace":true}',
      );

      var row = await dao.runById('r-prov-keep');
      expect(row!.provenanceJson, '{"schemaVersion":1,"keep":true}');

      await dao.startRun(runId: 'r-prov-fill', startedAt: DateTime(2026, 5, 2));
      await dao.backfillRunProvenanceIfNull(
        'r-prov-fill',
        '{"schemaVersion":1,"filled":true}',
      );

      row = await dao.runById('r-prov-fill');
      expect(row!.provenanceJson, '{"schemaVersion":1,"filled":true}');
      await db.close();
    },
  );

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
    await dao.persistTaskRun(
      TaskRunResult(
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
      ),
    );

    final rows = await dao.taskRunsForRun('r-pid');
    expect(rows.single.planId, planId);

    await db.close();
  });

  test('deleteRun removes run, task runs, and evaluations', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r-del', startedAt: DateTime(2026, 5, 2));
    await dao.persistTaskRun(
      TaskRunResult(
        runId: 'r-del',
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
        evaluations: const [
          EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
        ],
        aggregateScore: 1.0,
        completedAt: DateTime(2026, 5, 2, 12),
      ),
    );

    final taskRunId = (await dao.taskRunsForRun('r-del')).single.id;
    expect(await dao.evaluationsForTaskRun(taskRunId), hasLength(1));

    await dao.deleteRun('r-del');

    expect(await dao.runById('r-del'), isNull);
    expect(await dao.taskRunsForRun('r-del'), isEmpty);
    expect(await dao.evaluationsForTaskRun(taskRunId), isEmpty);
    await db.close();
  });

  test(
    'deleteTaskRunByKey removes matching task run and evaluations only',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dao = RunDao(db);
      await dao.startRun(runId: 'r-dk', startedAt: DateTime(2026, 5, 2));

      await dao.persistTaskRun(
        TaskRunResult(
          runId: 'r-dk',
          providerId: 'p1',
          modelId: 'm1',
          taskId: 't1',
          response: const ModelResponse(
            rawText: 'a',
            extractedCode: null,
            promptTokens: null,
            completionTokens: null,
            latency: Duration.zero,
          ),
          evaluations: const [
            EvaluationResult(evaluatorId: 'eval1', passed: true, score: 1.0),
            EvaluationResult(evaluatorId: 'eval2', passed: false, score: 0.5),
          ],
          aggregateScore: 0.75,
          completedAt: DateTime(2026, 5, 2, 12),
        ),
      );

      await dao.persistTaskRun(
        TaskRunResult(
          runId: 'r-dk',
          providerId: 'p2',
          modelId: 'm2',
          taskId: 't2',
          response: const ModelResponse(
            rawText: 'b',
            extractedCode: null,
            promptTokens: null,
            completionTokens: null,
            latency: Duration.zero,
          ),
          evaluations: const [
            EvaluationResult(evaluatorId: 'eval3', passed: true, score: 0.8),
          ],
          aggregateScore: 0.8,
          completedAt: DateTime(2026, 5, 2, 13),
        ),
      );

      var allTaskRuns = await dao.taskRunsForRun('r-dk');
      expect(allTaskRuns, hasLength(2));

      await dao.deleteTaskRunByKey(
        runId: 'r-dk',
        providerId: 'p1',
        modelId: 'm1',
        taskId: 't1',
      );

      allTaskRuns = await dao.taskRunsForRun('r-dk');
      expect(allTaskRuns, hasLength(1));
      expect(allTaskRuns.single.providerId, 'p2');
      expect(allTaskRuns.single.taskId, 't2');

      final remainingEvals = await dao.evaluationsForTaskRun(
        allTaskRuns.single.id,
      );
      expect(remainingEvals, hasLength(1));
      expect(remainingEvals.single.evaluatorId, 'eval3');

      await db.close();
    },
  );

  test('deleteTaskRunByKey does nothing for non-matching key', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r-nk', startedAt: DateTime(2026, 5, 2));

    await dao.persistTaskRun(
      TaskRunResult(
        runId: 'r-nk',
        providerId: 'p1',
        modelId: 'm1',
        taskId: 't1',
        response: const ModelResponse(
          rawText: 'a',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        evaluations: const [],
        aggregateScore: 1.0,
        completedAt: DateTime(2026, 5, 2, 12),
      ),
    );

    await dao.deleteTaskRunByKey(
      runId: 'r-nk',
      providerId: 'p-nomatch',
      modelId: 'm1',
      taskId: 't1',
    );

    final rows = await dao.taskRunsForRun('r-nk');
    expect(rows, hasLength(1));

    await db.close();
  });

  test('deleteTaskRunByKey targets a single trial index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(runId: 'r-trial', startedAt: DateTime(2026, 5, 2));

    Future<void> persistTrial(int trialIndex) => dao.persistTaskRun(
      TaskRunResult(
        runId: 'r-trial',
        providerId: 'p',
        modelId: 'm',
        taskId: 't',
        response: const ModelResponse(
          rawText: 'x',
          extractedCode: null,
          promptTokens: null,
          completionTokens: null,
          latency: Duration.zero,
        ),
        evaluations: [
          EvaluationResult(
            evaluatorId: 'compile',
            passed: trialIndex == 0,
            score: trialIndex == 0 ? 1.0 : 0.0,
          ),
        ],
        aggregateScore: trialIndex == 0 ? 1.0 : 0.0,
        completedAt: DateTime(2026, 5, 2, 12, trialIndex),
        trialIndex: trialIndex,
      ),
    );

    await persistTrial(0);
    await persistTrial(1);

    await dao.deleteTaskRunByKey(
      runId: 'r-trial',
      providerId: 'p',
      modelId: 'm',
      taskId: 't',
      trialIndex: 1,
    );

    final rows = await dao.taskRunsForRun('r-trial');
    expect(rows, hasLength(1));
    expect(rows.single.trialIndex, 0);
    expect(await dao.evaluationsForTaskRun(rows.single.id), hasLength(1));

    await db.close();
  });
}
