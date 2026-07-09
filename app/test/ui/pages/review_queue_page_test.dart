import 'dart:io';

import 'package:dart_arena/app.dart';
import 'package:dart_arena/review/review_repository.dart';
import 'package:dart_arena/runner/tmpdir_manager.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/flutter_secure_settings_store.dart';
import 'package:dart_arena/ui/pages/review_queue_page.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<TaskRun> seedTaskRun(
    AppDatabase db, {
    required String id,
    required String providerId,
    required String modelId,
  }) async {
    await db
        .into(db.taskRuns)
        .insert(
          TaskRunsCompanion.insert(
            id: id,
            runId: 'run-1',
            providerId: providerId,
            modelId: modelId,
            taskId: 'bug.off_by_one_pagination',
            responseText: '```dart\nint nextPage(int page) => page + 1;\n```',
            latencyMs: 1,
            aggregateScore: 1,
            completedAt: DateTime(2026, 5, 1),
            primaryPass: const Value(true),
          ),
        );
    return (db.select(
      db.taskRuns,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Future<void> seedRun(AppDatabase db) {
    return db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(id: 'run-1', startedAt: DateTime(2026, 5, 1)),
        );
  }

  testWidgets('shows cold-start placeholder with fewer than two submissions', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ReviewRepository(db, settings: FlutterSecureSettingsStore());

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewQueuePage(
          repository: repo,
          registry: buildDefaultTaskRegistry(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Need more comparable runs'), findsOneWidget);
  });

  testWidgets('loads a blind battle and reveals identity after voting', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedRun(db);
    await seedTaskRun(db, id: 'tr-a', providerId: 'openai', modelId: 'gpt-5');
    await seedTaskRun(
      db,
      id: 'tr-b',
      providerId: 'anthropic',
      modelId: 'claude-opus',
    );
    final registry = buildDefaultTaskRegistry();
    for (final task in registry.all()) {
      await task.ensureLoaded();
    }
    final repo = ReviewRepository(db, settings: FlutterSecureSettingsStore());

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewQueuePage(repository: repo, registry: registry),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Submission A'), findsOneWidget);
    expect(find.text('Submission B'), findsOneWidget);
    expect(find.textContaining('openai'), findsNothing);
    expect(find.textContaining('gpt-5'), findsNothing);

    await tester.ensureVisible(find.text('A is better'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A is better'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Identity:'), findsWidgets);
    expect(
      find.textContaining(RegExp('openai|anthropic')),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('opens /review from the app shell', (tester) async {
    final tmp = Directory(
      '/tmp/dart_arena_review_route_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final tmpCache = Directory(
      '/tmp/dart_arena_review_route_cache_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
      tmpCache.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      App(
        database: db,
        workdir: WorkdirManager(root: tmp),
        settings: FlutterSecureSettingsStore(),
        tmpDirManager: TmpDirManager(root: tmpCache),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsWidgets);
    expect(find.text('Need more comparable runs'), findsOneWidget);
  });
}
