import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('runs.name is writable and readable', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(
            id: 'r1',
            startedAt: DateTime(2026, 5, 2),
            name: const Value('my-run'),
          ),
        );

    final all = await db.select(db.runs).get();
    expect(all, hasLength(1));
    expect(all.first.id, 'r1');
    expect(all.first.name, 'my-run');

    await db.close();
  });

  test('runs.name is nullable (existing rows have no name)', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(id: 'r2', startedAt: DateTime(2026, 5, 2)),
        );

    final row = await (db.select(
      db.runs,
    )..where((r) => r.id.equals('r2'))).getSingle();
    expect(row.name, isNull);

    await db.close();
  });

  test('schemaVersion is 6', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 6);
    await db.close();
  });

  test('task run result primitive columns use safe defaults', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(id: 'r3', startedAt: DateTime(2026, 5, 2)),
        );
    await db
        .into(db.taskRuns)
        .insert(
          TaskRunsCompanion.insert(
            id: 'tr1',
            runId: 'r3',
            providerId: 'p',
            modelId: 'm',
            taskId: 't',
            responseText: '',
            latencyMs: 1,
            aggregateScore: 0.5,
            completedAt: DateTime(2026, 5, 2),
          ),
        );

    final row = await db.select(db.taskRuns).getSingle();
    expect(row.trialIndex, 0);
    expect(row.taskVersion, 1);
    expect(row.benchmarkTrack, 'codegen');
    expect(row.harnessId, isNull);
    expect(row.primaryPass, isNull);
    expect(row.failureTag, isNull);
    expect(row.patchText, isNull);
    expect(row.trajectoryLogPath, isNull);

    await db.close();
  });

  test('review battles table is additive and writable', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(id: 'r4', startedAt: DateTime(2026, 5, 2)),
        );
    Future<void> insertTaskRun(String id) {
      return db
          .into(db.taskRuns)
          .insert(
            TaskRunsCompanion.insert(
              id: id,
              runId: 'r4',
              providerId: 'p-$id',
              modelId: 'm-$id',
              taskId: 't',
              responseText: '',
              latencyMs: 1,
              aggregateScore: 1,
              completedAt: DateTime(2026, 5, 2),
            ),
          );
    }

    await insertTaskRun('tr1');
    await insertTaskRun('tr2');
    await db
        .into(db.reviewBattles)
        .insert(
          ReviewBattlesCompanion.insert(
            id: 'b1',
            taskId: 't',
            taskVersion: 1,
            benchmarkTrack: 'codegen',
            leftTaskRunId: 'tr1',
            rightTaskRunId: 'tr2',
            canonicalPairKey: 'tr1|tr2',
            leftLabel: 'A',
            rightLabel: 'B',
            reviewerId: 'reviewer-1',
            vote: 'left',
            createdAt: DateTime(2026, 5, 3),
          ),
        );

    final rows = await db.select(db.reviewBattles).get();
    expect(rows, hasLength(1));
    expect(rows.single.vote, 'left');

    await db.close();
  });

  test('version 5 databases migrate by creating review_battles', () async {
    final raw = sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE runs (
        id TEXT NOT NULL PRIMARY KEY,
        started_at INTEGER NOT NULL,
        completed_at INTEGER NULL,
        judge_model TEXT NULL,
        name TEXT NULL
      );
      CREATE TABLE plans (
        id TEXT NOT NULL PRIMARY KEY,
        task_id TEXT NOT NULL,
        planner_model_id TEXT NULL,
        reference_version INTEGER NULL,
        artifact TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE task_runs (
        id TEXT NOT NULL PRIMARY KEY,
        run_id TEXT NOT NULL REFERENCES runs (id),
        provider_id TEXT NOT NULL,
        model_id TEXT NOT NULL,
        task_id TEXT NOT NULL,
        response_text TEXT NOT NULL,
        prompt_tokens INTEGER NULL,
        completion_tokens INTEGER NULL,
        latency_ms INTEGER NOT NULL,
        aggregate_score REAL NOT NULL,
        completed_at INTEGER NOT NULL,
        plan_id TEXT NULL REFERENCES plans (id),
        trial_index INTEGER NOT NULL DEFAULT 0,
        task_version INTEGER NOT NULL DEFAULT 1,
        benchmark_track TEXT NOT NULL DEFAULT 'codegen',
        harness_id TEXT NULL,
        primary_pass INTEGER NULL CHECK ("primary_pass" IN (0, 1)),
        failure_tag TEXT NULL,
        patch_text TEXT NULL,
        trajectory_log_path TEXT NULL
      );
      CREATE TABLE evaluations (
        id TEXT NOT NULL PRIMARY KEY,
        task_run_id TEXT NOT NULL REFERENCES task_runs (id),
        evaluator_id TEXT NOT NULL,
        passed INTEGER NOT NULL CHECK ("passed" IN (0, 1)),
        score REAL NOT NULL,
        rationale TEXT NULL,
        details_json TEXT NOT NULL
      );
      PRAGMA user_version = 5;
    ''');
    final db = AppDatabase(NativeDatabase.opened(raw));

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'review_battles'",
        )
        .get();

    expect(tables, hasLength(1));
    await db.close();
  });
}
