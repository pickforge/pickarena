import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({AppDatabase db, RunDao dao})> _seed() async {
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
      EvaluationResult(evaluatorId: 'test', passed: true, score: 1.0),
    ],
    aggregateScore: 1.0,
    completedAt: DateTime(2026, 5, 1, 0, 5),
  ));
  await dao.persistTaskRun(TaskRunResult(
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
  ));
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

    final overall = await repo.rank(
      filter: const LeaderboardFilter(),
    );
    expect(overall.first.modelId, 'gpt-5');
    expect(overall.last.modelId, 'claude-opus-4.7');
  });
}
