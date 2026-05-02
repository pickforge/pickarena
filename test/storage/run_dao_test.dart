import 'dart:convert';

import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
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
}
