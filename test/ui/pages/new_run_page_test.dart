import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/ui/pages/new_run_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubTaskA extends BenchmarkTask {
  @override
  String get id => 'bug.a';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/x.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

class _StubTaskB extends BenchmarkTask {
  @override
  String get id => 'state.b';
  @override
  Category get category => Category.stateManagement;
  @override
  String get prompt => '';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/x.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

Future<Widget> _wrap(Widget child) async {
  final tmp = await Directory.systemTemp.createTemp('dart_arena_newrun_test_');
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AppDatabase>.value(value: db),
      RepositoryProvider<WorkdirManager>.value(
          value: WorkdirManager(root: tmp)),
      RepositoryProvider<SettingsRepository>.value(
          value: SettingsRepository()),
      RepositoryProvider<RunDao>(
          create: (ctx) => RunDao(ctx.read<AppDatabase>())),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders task picker with category groups', (tester) async {
    final reg = TaskRegistry()
      ..register(_StubTaskA())
      ..register(_StubTaskB());
    await tester.pumpWidget(await _wrap(
      NewRunPage(registry: reg, providers: const []),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bug fix'), findsOneWidget);
    expect(find.text('State management'), findsOneWidget);
    expect(find.text('bug.a'), findsOneWidget);
    expect(find.text('state.b'), findsOneWidget);
  });

  testWidgets('label TextField is present', (tester) async {
    final reg = TaskRegistry()..register(_StubTaskA());
    await tester.pumpWidget(await _wrap(
      NewRunPage(registry: reg, providers: const []),
    ));
    await tester.pumpAndSettle();
    // Look for the label field by its label text
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('Run button is disabled when no tasks selected',
      (tester) async {
    final reg = TaskRegistry()..register(_StubTaskA());
    await tester.pumpWidget(await _wrap(
      NewRunPage(registry: reg, providers: const []),
    ));
    await tester.pumpAndSettle();
    // Deselect the pre-selected task by tapping its checkbox
    await tester.tap(find.text('bug.a'));
    await tester.pumpAndSettle();
    final btn =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Run'));
    expect(btn.onPressed, isNull);
  });
}
