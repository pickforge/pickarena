import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/start_run_config.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/ui/pages/new_run_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _NoPlanTask extends BenchmarkTask {
  @override
  String get id => 'no-plan';
  @override
  Category get category => Category.bugFix;
  @override
  String get prompt => 'no plan';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/x.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [];
}

class _PlanTask extends BenchmarkTask {
  @override
  String get id => 'with-plan';
  @override
  Category get category => Category.planningAndExecution;
  @override
  String get prompt => 'plan';
  @override
  Map<String, String> get fixtures => const {};
  @override
  String get generatedCodePath => 'lib/y.dart';
  @override
  String? get judgeRubric => null;
  @override
  bool get hasReferencePlan => true;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [];
}

class _FakeProvider implements ModelProvider {
  const _FakeProvider();
  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<String>> listModels() async => const [];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => throw UnimplementedError();
}

Future<Widget> _wrap(Widget child) async {
  final tmp =
      Directory('/tmp/dart_arena_planto_${DateTime.now().microsecondsSinceEpoch}')
        ..createSync(recursive: true);
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
      RepositoryProvider<PlanDao>(
          create: (ctx) => PlanDao(ctx.read<AppDatabase>())),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('toggle disabled when no selected task hasReferencePlan',
      (tester) async {
    final reg = TaskRegistry()..register(_NoPlanTask());
    await tester.pumpWidget(await _wrap(
      NewRunPage(registry: reg, providers: const []),
    ));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.onChanged, isNull);
    expect(find.text('Select a planning task to enable.'), findsOneWidget);
  });

  testWidgets('toggle enabled when at least one selected task hasReferencePlan',
      (tester) async {
    final reg = TaskRegistry()
      ..register(_PlanTask())
      ..register(_NoPlanTask());
    await tester.pumpWidget(await _wrap(
      NewRunPage(registry: reg, providers: const []),
    ));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.onChanged, isNotNull);
    expect(
      find.textContaining('1 of 2 selected tasks'),
      findsOneWidget,
    );
  });

  testWidgets('toggling propagates useReferencePlan into StartRunConfig',
      (tester) async {
    final reg = TaskRegistry()..register(_PlanTask());

    Object? capturedExtra;
    final router = GoRouter(
      initialLocation: '/new-run',
      routes: [
        GoRoute(
          path: '/new-run',
          builder: (_, __) => NewRunPage(
            registry: reg,
            providers: const [_FakeProvider()],
          ),
        ),
        GoRoute(
          path: '/run',
          builder: (context, state) {
            capturedExtra = state.extra;
            return const Scaffold(body: Text('captured'));
          },
        ),
      ],
    );

    final tmp =
        Directory('/tmp/dart_arena_planc_${DateTime.now().microsecondsSinceEpoch}')
          ..createSync(recursive: true);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppDatabase>.value(value: db),
        RepositoryProvider<WorkdirManager>.value(
            value: WorkdirManager(root: tmp)),
        RepositoryProvider<SettingsRepository>.value(
            value: SettingsRepository()),
        RepositoryProvider<RunDao>(
            create: (ctx) => RunDao(ctx.read<AppDatabase>())),
        RepositoryProvider<PlanDao>(
            create: (ctx) => PlanDao(ctx.read<AppDatabase>())),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fake'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Model id'),
      'fake-1',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Run'));
    await tester.pumpAndSettle();

    expect(capturedExtra, isA<StartRunConfig>());
    expect((capturedExtra! as StartRunConfig).useReferencePlan, isTrue);
  });
}
