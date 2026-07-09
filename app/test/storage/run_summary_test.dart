import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  test('loadSummary returns null for unknown run', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    expect(await dao.loadSummary('nope'), isNull);
    await db.close();
  });

  test('loadSummary aggregates run, task runs, and evaluations', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dao = RunDao(db);
    await dao.startRun(
      runId: 'r1',
      startedAt: DateTime(2026, 5, 2),
      name: 'demo',
    );
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
        evaluations: const [
          EvaluationResult(evaluatorId: 'compile', passed: true, score: 1.0),
          EvaluationResult(evaluatorId: 'test', passed: true, score: 0.8),
        ],
        aggregateScore: 0.9,
        completedAt: DateTime(2026, 5, 2, 12),
      ),
    );

    final summary = await dao.loadSummary('r1');
    expect(summary, isNotNull);
    expect(summary!.run.id, 'r1');
    expect(summary.run.name, 'demo');
    expect(summary.taskRuns, hasLength(1));
    final taskRunId = summary.taskRuns.first.id;
    expect(summary.evaluationsByTaskRunId[taskRunId], hasLength(2));
    final evalIds = summary.evaluationsByTaskRunId[taskRunId]!
        .map((e) => e.evaluatorId)
        .toSet();
    expect(evalIds, equals({'compile', 'test'}));

    await db.close();
  });
}
