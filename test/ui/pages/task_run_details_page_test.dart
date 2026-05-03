import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/pages/task_run_details_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubTask extends BenchmarkTask {
  @override
  String get id => 'stub.task';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'fix it';
  @override
  Map<String, String> get fixtures => const {
        'lib/orig.dart': 'int answer() => 41;\n',
      };
  @override
  String get generatedCodePath => 'lib/orig.dart';
  @override
  String? get judgeRubric => 'be strict';
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<({RunDao dao, String taskRunId})> _seed() async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = RunDao(db);
  await dao.startRun(runId: 'r1', startedAt: DateTime(2026, 5, 2));
  await dao.persistTaskRun(TaskRunResult(
    runId: 'r1',
    providerId: 'openai',
    modelId: 'gpt-5',
    taskId: 'stub.task',
    response: const ModelResponse(
      rawText: '```dart\nint answer() => 42;\n```',
      extractedCode: 'int answer() => 42;\n',
      promptTokens: 10,
      completionTokens: 5,
      latency: Duration(milliseconds: 1500),
    ),
    evaluations: const [
      EvaluationResult(
        evaluatorId: 'compile',
        passed: true,
        score: 1.0,
        rationale: 'compiles',
      ),
    ],
    aggregateScore: 0.95,
    completedAt: DateTime(2026, 5, 2, 12),
  ));
  final all = await dao.taskRunsForRun('r1');
  return (dao: dao, taskRunId: all.first.id);
}

void main() {
  testWidgets('header shows provider/model/task and aggregate score',
      (tester) async {
    final seeded = await _seed();
    final reg = TaskRegistry()..register(_StubTask());
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: reg,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('openai'), findsWidgets);
    expect(find.textContaining('gpt-5'), findsWidgets);
    expect(find.textContaining('stub.task'), findsWidgets);
    expect(find.text('0.95'), findsWidgets);
  });

  testWidgets('switching to Diff tab renders diff lines', (tester) async {
    final seeded = await _seed();
    final reg = TaskRegistry()..register(_StubTask());
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: reg,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diff'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+ '), findsWidgets);
    expect(find.textContaining('- '), findsWidgets);
  });

  testWidgets('Diff tab shows empty state when task has no fixture at path',
      (tester) async {
    final seeded = await _seed();
    final emptyReg = TaskRegistry();
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: emptyReg,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diff'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no original'), findsOneWidget);
  });

  testWidgets('Evaluations tab renders one card per evaluator',
      (tester) async {
    final seeded = await _seed();
    final reg = TaskRegistry()..register(_StubTask());
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: reg,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evaluations'));
    await tester.pumpAndSettle();
    expect(find.text('compile'), findsAtLeast(1));
    expect(find.text('PASS'), findsOneWidget);
  });

  testWidgets('Prompt tab shows task prompt and rubric', (tester) async {
    final seeded = await _seed();
    final reg = TaskRegistry()..register(_StubTask());
    await tester.pumpWidget(MaterialApp(
      home: TaskRunDetailsPage(
        runId: 'r1',
        taskRunId: seeded.taskRunId,
        dao: seeded.dao,
        registry: reg,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prompt'));
    await tester.pumpAndSettle();
    expect(find.text('fix it'), findsOneWidget);
    await tester.tap(find.text('Judge rubric'));
    await tester.pumpAndSettle();
    expect(find.text('be strict'), findsOneWidget);
  });
}
