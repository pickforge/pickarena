import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PlanDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = PlanDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertReferencePlan is idempotent on (taskId, referenceVersion)',
      () async {
    final id1 = await dao.upsertReferencePlan(
      taskId: 't1',
      version: 1,
      artifact: 'first',
    );
    final id2 = await dao.upsertReferencePlan(
      taskId: 't1',
      version: 1,
      artifact: 'first',
    );
    expect(id1, id2);

    final all = await db.select(db.plans).get();
    expect(all, hasLength(1));
    expect(all.single.artifact, 'first');
  });

  test('upsertReferencePlan with a different version creates a second row',
      () async {
    await dao.upsertReferencePlan(
      taskId: 't1',
      version: 1,
      artifact: 'first',
    );
    await dao.upsertReferencePlan(
      taskId: 't1',
      version: 2,
      artifact: 'second',
    );
    final all = await db.select(db.plans).get();
    expect(all, hasLength(2));
  });

  test('insertModelPlan creates a fresh row each call', () async {
    final id1 = await dao.insertModelPlan(
      taskId: 't1',
      plannerModelId: 'm1',
      artifact: 'plan A',
    );
    final id2 = await dao.insertModelPlan(
      taskId: 't1',
      plannerModelId: 'm1',
      artifact: 'plan B',
    );
    expect(id1, isNot(id2));
    final all = await db.select(db.plans).get();
    expect(all, hasLength(2));
  });

  test('planById returns null for unknown id', () async {
    final p = await dao.planById('nope');
    expect(p, isNull);
  });

  test('TaskRuns.planId round-trips via FK', () async {
    final planId = await dao.upsertReferencePlan(
      taskId: 't1',
      version: 1,
      artifact: 'plan',
    );

    await db.into(db.runs).insert(
          RunsCompanion.insert(
            id: 'r1',
            startedAt: DateTime(2026, 1, 1),
          ),
        );
    await db.into(db.taskRuns).insert(
          TaskRunsCompanion.insert(
            id: 'tr1',
            runId: 'r1',
            providerId: 'p',
            modelId: 'm',
            taskId: 't1',
            responseText: '',
            latencyMs: 0,
            aggregateScore: 1.0,
            completedAt: DateTime(2026, 1, 1, 0, 1),
            planId: Value(planId),
          ),
        );
    final row = await (db.select(db.taskRuns)
          ..where((t) => t.id.equals('tr1')))
        .getSingle();
    expect(row.planId, planId);
  });
}
