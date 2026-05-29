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

class _ListModelsProvider with Disposable implements ModelProvider {
  @override
  String get id => 'list';
  @override
  String get displayName => 'ListProv';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<ModelInfo>> listModels() async => const [
    ModelInfo(id: 'model-a'),
    ModelInfo(id: 'model-b', efforts: ['low', 'high']),
    ModelInfo(id: 'model-c'),
  ];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => throw UnimplementedError();
}

class _EmptyListProvider with Disposable implements ModelProvider {
  @override
  String get id => 'empty';
  @override
  String get displayName => 'Empty';
  @override
  ProviderMode get mode => ProviderMode.rawApi;
  @override
  Future<List<ModelInfo>> listModels() async => [];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async => throw UnimplementedError();
}

Future<Widget> _wrap(Widget child) async {
  final tmp = Directory(
    '/tmp/dart_arena_newrun_${DateTime.now().microsecondsSinceEpoch}',
  )..createSync(recursive: true);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AppDatabase>.value(value: db),
      RepositoryProvider<WorkdirManager>.value(
        value: WorkdirManager(root: tmp),
      ),
      RepositoryProvider<SettingsRepository>.value(value: SettingsRepository()),
      RepositoryProvider<RunDao>(
        create: (ctx) => RunDao(ctx.read<AppDatabase>()),
      ),
      RepositoryProvider<PlanDao>(
        create: (ctx) => PlanDao(ctx.read<AppDatabase>()),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

Future<void> _tapCheckboxTileByText(WidgetTester tester, String text) async {
  final textFinder = find.text(text);
  await tester.dragUntilVisible(
    textFinder,
    find.byType(ListView),
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
  final tile = find
      .ancestor(of: textFinder, matching: find.byType(CheckboxListTile))
      .last;
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders task picker with category groups', (tester) async {
    final reg = TaskRegistry()
      ..register(_StubTaskA())
      ..register(_StubTaskB());
    await tester.pumpWidget(
      await _wrap(NewRunPage(registry: reg, providers: const [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bug fix'), findsOneWidget);
    expect(find.text('State management'), findsOneWidget);
    expect(find.text('bug.a'), findsOneWidget);
    expect(find.text('state.b'), findsOneWidget);
  });

  testWidgets('label TextField is present', (tester) async {
    final reg = TaskRegistry()..register(_StubTaskA());
    await tester.pumpWidget(
      await _wrap(NewRunPage(registry: reg, providers: const [])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('Run button is disabled when no tasks selected', (tester) async {
    final reg = TaskRegistry()..register(_StubTaskA());
    await tester.pumpWidget(
      await _wrap(NewRunPage(registry: reg, providers: const [])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('bug.a'));
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Run'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('chip multi-select toggles populate the selection set', (
    tester,
  ) async {
    final reg = TaskRegistry()..register(_StubTaskA());

    await tester.pumpWidget(
      await _wrap(
        NewRunPage(registry: reg, providers: [_ListModelsProvider()]),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCheckboxTileByText(tester, 'ListProv');

    expect(find.byType(FilterChip), findsNWidgets(4));

    await tester.dragUntilVisible(
      find.byType(FilterChip).first,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    // Tap model-a (first chip) and model-c (fourth chip)
    final chips = find.byType(FilterChip);
    await tester.tap(chips.first);
    await tester.pumpAndSettle();
    await tester.tap(chips.at(3));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text(
        'Will run 2 (provider, model) pairs'
        ' × 1 tasks = 2 combos, ≈ 4× parallel',
      ),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Will run 2 (provider, model) pairs'
        ' × 1 tasks = 2 combos, ≈ 4× parallel',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Select all and Clear buttons work', (tester) async {
    final reg = TaskRegistry()..register(_StubTaskA());

    await tester.pumpWidget(
      await _wrap(
        NewRunPage(registry: reg, providers: [_ListModelsProvider()]),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCheckboxTileByText(tester, 'ListProv');

    expect(find.byType(FilterChip), findsNWidgets(4));

    await tester.dragUntilVisible(
      find.widgetWithText(TextButton, 'Select all'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Select all'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.textContaining('Will run'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Will run'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Run'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('comma-separated fallback trims and dedupes', (tester) async {
    final reg = TaskRegistry()..register(_StubTaskA());

    await tester.pumpWidget(
      await _wrap(NewRunPage(registry: reg, providers: [_EmptyListProvider()])),
    );
    await tester.pumpAndSettle();

    await _tapCheckboxTileByText(tester, 'Empty');

    expect(find.text('Custom model ids (comma-separated)'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Custom model ids (comma-separated)'),
      'm1, m1 ,  , m2',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsNWidgets(2));
    expect(find.text('m1'), findsOneWidget);
    expect(find.text('m2'), findsOneWidget);
  });

  testWidgets('summary combo count updates', (tester) async {
    final reg = TaskRegistry()
      ..register(_StubTaskA())
      ..register(_StubTaskB());

    await tester.pumpWidget(
      await _wrap(
        NewRunPage(registry: reg, providers: [_ListModelsProvider()]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('ListProv'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await _tapCheckboxTileByText(tester, 'ListProv');

    await tester.dragUntilVisible(
      find.text('model-a'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('model-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('model-a'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text(
        'Will run 1 (provider, model) pairs'
        ' × 2 tasks = 2 combos, ≈ 4× parallel',
      ),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Will run 1 (provider, model) pairs'
        ' × 2 tasks = 2 combos, ≈ 4× parallel',
      ),
      findsOneWidget,
    );

    await tester.dragUntilVisible(
      find.text('state.b'),
      find.byType(ListView),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('state.b'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Will run 1 (provider, model) pairs'
        ' × 1 tasks = 1 combos, ≈ 4× parallel',
      ),
      findsOneWidget,
    );
  });

  testWidgets('StartRunConfig carries modelsByProvider and maxConcurrency', (
    tester,
  ) async {
    final reg = TaskRegistry()..register(_StubTaskA());

    Object? capturedExtra;
    final router = GoRouter(
      initialLocation: '/new-run',
      routes: [
        GoRoute(
          path: '/new-run',
          builder: (_, __) =>
              NewRunPage(registry: reg, providers: [_ListModelsProvider()]),
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

    final tmp = Directory(
      '/tmp/dart_arena_cfg_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AppDatabase>.value(value: db),
          RepositoryProvider<WorkdirManager>.value(
            value: WorkdirManager(root: tmp),
          ),
          RepositoryProvider<SettingsRepository>.value(
            value: SettingsRepository(),
          ),
          RepositoryProvider<RunDao>(
            create: (ctx) => RunDao(ctx.read<AppDatabase>()),
          ),
          RepositoryProvider<PlanDao>(
            create: (ctx) => PlanDao(ctx.read<AppDatabase>()),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCheckboxTileByText(tester, 'ListProv');

    await tester.ensureVisible(find.text('model-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('model-a'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Run'));
    await tester.pumpAndSettle();

    expect(capturedExtra, isA<StartRunConfig>());
    final cfg = capturedExtra! as StartRunConfig;
    expect(cfg.modelsByProvider, contains('list'));
    expect(cfg.modelsByProvider['list'], ['model-a']);
    expect(cfg.maxConcurrency, 4);
  });
}
