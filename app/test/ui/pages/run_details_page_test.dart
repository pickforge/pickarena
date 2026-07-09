import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/flutter_secure_settings_store.dart';
import 'package:dart_arena/ui/pages/run_details_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RunDao> _seedRun({bool completed = true}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(
    runId: 'r1',
    startedAt: DateTime(2026, 5, 2, 14, 23),
    name: 'demo',
  );
  await dao.persistTaskRun(
    TaskRunResult(
      runId: 'r1',
      providerId: 'openai',
      modelId: 'gpt-5',
      taskId: 'bug.a',
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
      aggregateScore: 0.92,
      completedAt: DateTime(2026, 5, 2, 14, 24),
    ),
  );
  if (completed) {
    await dao.finishRun('r1', DateTime(2026, 5, 2, 14, 31));
  }
  return dao;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders title, header, and matrix score', (tester) async {
    final dao = await _seedRun();
    await tester.pumpWidget(
      MaterialApp(
        home: RunDetailsPage(
          runId: 'r1',
          dao: dao,
          settings: FlutterSecureSettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('demo'), findsOneWidget);
    expect(find.text('bug.a'), findsOneWidget);
    expect(find.text('openai/gpt-5'), findsOneWidget);
    expect(find.text('0.92'), findsOneWidget);
  });

  testWidgets('publish to README disabled when path unset', (tester) async {
    final dao = await _seedRun();
    await tester.pumpWidget(
      MaterialApp(
        home: RunDetailsPage(
          runId: 'r1',
          dao: dao,
          settings: FlutterSecureSettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final btn = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Publish to README'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('Export Bundle is enabled only after completion', (tester) async {
    final completedDao = await _seedRun();
    await tester.pumpWidget(
      MaterialApp(
        home: RunDetailsPage(
          runId: 'r1',
          dao: completedDao,
          settings: FlutterSecureSettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    var btn = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Export Bundle'),
    );
    expect(btn.onPressed, isNotNull);

    final inProgressDao = await _seedRun(completed: false);
    await tester.pumpWidget(
      MaterialApp(
        home: RunDetailsPage(
          key: UniqueKey(),
          runId: 'r1',
          dao: inProgressDao,
          settings: FlutterSecureSettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    btn = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Export Bundle'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('shows missing-run banner for unknown id', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      MaterialApp(
        home: RunDetailsPage(
          runId: 'nope',
          dao: RunDao(db),
          settings: FlutterSecureSettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Run not found'), findsOneWidget);
  });
}
