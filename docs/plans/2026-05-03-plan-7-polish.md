# dart_arena — Plan 7: Polish (Evaluator Weights Editor + DI Refactor)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land two polish items in one cohesive change — (1) an evaluator-weights editor in `SettingsPage`, and (2) a provider-DI refactor that pulls `AppDatabase` / `RunDao` / `WorkdirManager` / `SettingsRepository` / `RunBloc` construction out of `_NewRunPageState._startRun` and into a `MultiRepositoryProvider` + `BlocProvider` seam. The DI refactor also wires saved weights into `RunBloc` so the new editor actually affects runs.

**Architecture:** `main.dart` becomes `async` and builds three singletons (`AppDatabase`, `WorkdirManager`, `SettingsRepository`), passing them into `App`. `App` wraps `MaterialApp.router` in `MultiRepositoryProvider`. The `/run` route uses `BlocProvider(create: ...)` to construct `RunBloc` from a new `StartRunConfig` value object passed via `state.extra`. `NewRunPage._startRun` reads repos via `context.read`, awaits saved weights, builds `StartRunConfig`, and navigates. New `EvaluatorWeightsSection` widget edits `SettingsRepository.getEvaluatorWeights() / setEvaluatorWeights()` against `defaultEvaluatorWeights.keys` as the source of truth.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, `flutter_bloc ^8.1.6` (`MultiRepositoryProvider` / `BlocProvider`), `go_router` (existing), `flutter_secure_storage` (existing), `drift` (existing). No new dependencies.

**Predecessors:** Plan 1 (foundation), Plan 2 (cloud providers), Plan 3 (evaluators + scoring), Plan 4 (data & navigation), Plan 5 (benchmark content), Plan 6 (analytics) — all implemented.

**Spec:** `docs/specs/2026-05-03-plan-7-polish-design.md`.

---

## File map (this plan)

### Created

- `lib/runner/start_run_config.dart` — `StartRunConfig` value object passed via `state.extra` to `/run`
- `lib/ui/widgets/evaluator_weights_section.dart` — settings-page weights editor widget
- `test/ui/widgets/evaluator_weights_section_test.dart` — widget tests for the editor

### Modified

- `lib/main.dart` — becomes `async`, builds singletons, passes to `App`
- `lib/app.dart` — `App` accepts repos, wraps router in `MultiRepositoryProvider`, `/run` route uses `BlocProvider`
- `lib/ui/pages/new_run_page.dart` — `_startRun` reads via `context.read`, awaits weights, builds `StartRunConfig`, navigates with extra
- `lib/ui/pages/run_progress_page.dart` — `const` constructor, drops `bloc` param, reads via `context.read<RunBloc>`
- `lib/ui/pages/settings_page.dart` — adds `EvaluatorWeightsSection` slot; `_SettingsPageState._repo` reads from `context.read`
- `test/ui/pages/new_run_page_test.dart` — wraps under `MultiRepositoryProvider`, adds Run-button → `StartRunConfig.weights` assertion
- `test/runner/run_bloc_test.dart` — adds explicit "custom weights propagate to aggregate" test
- `test/widget_test.dart` — updates `App()` smoke test to provide singletons

### Untouched

- `lib/runner/run_bloc.dart` — `weights` parameter and constructor default already exist
- `lib/runner/run_event.dart` / `run_state.dart` — `StartRun` event payload unchanged
- `lib/storage/settings.dart` — `getEvaluatorWeights` / `setEvaluatorWeights` already exist
- `lib/core/scoring.dart` — `defaultEvaluatorWeights` is the source of truth
- `lib/analytics/dimensions.dart` — keeps using `defaultEvaluatorWeights` directly (intentional, see spec §6)
- All other `SettingsRepository()` ad-hoc constructors in `_JudgeSection` / `_OllamaLocalSection` / `_ApiKeySection` / `_ReadmeSection` (deferred to follow-up)
- All evaluator, provider, task code

---

## Commit plan summary

| # | Title                                                 | Tasks   |
|---|-------------------------------------------------------|---------|
| 1 | App constructor DI plumbing                           | 1       |
| 2 | MultiRepositoryProvider wiring                        | 2       |
| 3 | NewRunPage reads repos via context                    | 3       |
| 4 | StartRunConfig + RunBloc via BlocProvider             | 4, 5, 6 |
| 5 | Wire saved weights into runs                          | 7       |
| 6 | Cover custom-weights propagation                      | 8       |
| 7 | EvaluatorWeightsSection widget + tests                | 9, 10   |
| 8 | Wire weights section into SettingsPage                | 11, 12  |

Each commit is independently shippable. Commits 1–6 fix and cover the dead-code bug (saved weights had no effect at run time). Commits 7–8 add the editor UI on top.

---

## Task 1: Make `main` async and build app-wide singletons

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Modify: `test/widget_test.dart`

This task does **not** add `MultiRepositoryProvider` yet — that lands in Task 2. The point here is just to construct singletons once and thread them through `App`'s constructor with no behavior change.

- [ ] **Step 1: Update `App` to accept singletons via constructor**

Replace the contents of `lib/app.dart` (top of the file, replacing the existing `App` class) with:

```dart
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/pages/dashboard_page.dart';
import 'package:dart_arena/ui/pages/leaderboard_page.dart';
import 'package:dart_arena/ui/pages/new_run_page.dart';
import 'package:dart_arena/ui/pages/run_details_page.dart';
import 'package:dart_arena/ui/pages/task_run_details_page.dart';
import 'package:dart_arena/ui/pages/run_history_page.dart';
import 'package:dart_arena/ui/pages/run_progress_page.dart';
import 'package:dart_arena/ui/pages/settings_page.dart';
import 'package:dart_arena/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final TaskRegistry _registry = buildDefaultTaskRegistry();

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => DashboardPage(registry: _registry),
    ),
    GoRoute(path: '/new-run', builder: (_, __) => const NewRunPage()),
    GoRoute(
      path: '/run',
      builder: (context, state) =>
          RunProgressPage(bloc: state.extra! as RunBloc),
    ),
    GoRoute(path: '/runs', builder: (_, __) => const RunHistoryPage()),
    GoRoute(
      path: '/runs/:runId',
      builder: (c, state) =>
          RunDetailsPage(runId: state.pathParameters['runId']!),
    ),
    GoRoute(
      path: '/runs/:runId/task-runs/:taskRunId',
      builder: (c, state) => TaskRunDetailsPage(
        runId: state.pathParameters['runId']!,
        taskRunId: state.pathParameters['taskRunId']!,
      ),
    ),
    GoRoute(
      path: '/leaderboard',
      builder: (context, state) => LeaderboardPage(
        registry: _registry,
        initialQuery: state.uri.queryParameters,
      ),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
  ],
);

class App extends StatelessWidget {
  const App({
    required this.database,
    required this.workdir,
    required this.settings,
    super.key,
  });

  final AppDatabase database;
  final WorkdirManager workdir;
  final SettingsRepository settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'dart_arena',
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
```

(Note: `RepositoryProvider` is still NOT added in this task — singletons are accepted but unused inside `build`. Task 2 wires them up.)

- [ ] **Step 2: Update `main.dart` to build singletons before `runApp`**

Replace `lib/main.dart` with:

```dart
import 'dart:io';

import 'package:dart_arena/app.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  final supportDir = await getApplicationSupportDirectory();
  final workdirRoot = Directory(p.join(supportDir.path, 'workdirs'))
    ..createSync(recursive: true);
  final workdir = WorkdirManager(root: workdirRoot);
  final settings = SettingsRepository();

  runApp(App(
    database: database,
    workdir: workdir,
    settings: settings,
  ));
}
```

- [ ] **Step 3: Update the smoke test**

Replace `test/widget_test.dart` with:

```dart
import 'dart:io';

import 'package:dart_arena/app.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_smoke_');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(App(
      database: db,
      workdir: WorkdirManager(root: tmp),
      settings: SettingsRepository(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('dart_arena'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: PASS for all existing tests. The smoke test exercises the new `App` constructor signature.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/app.dart test/widget_test.dart
git commit -m "refactor(di): pass database/workdir/settings into App constructor"
```

---

## Task 2: Wrap `MaterialApp.router` in `MultiRepositoryProvider`

**Files:**
- Modify: `lib/app.dart`

This task connects the singletons to widget tree consumers via `flutter_bloc`'s `RepositoryProvider`. No call sites read from it yet (Task 3 is the first consumer), but exposing them now lets the rest of the work happen incrementally.

- [ ] **Step 1: Add `MultiRepositoryProvider` import + body in `App.build`**

Edit `lib/app.dart`. At the top, add the import:

```dart
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
```

Replace `App.build` with:

```dart
@override
Widget build(BuildContext context) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AppDatabase>.value(value: database),
      RepositoryProvider<WorkdirManager>.value(value: workdir),
      RepositoryProvider<SettingsRepository>.value(value: settings),
      RepositoryProvider<RunDao>(
        create: (ctx) => RunDao(ctx.read<AppDatabase>()),
      ),
    ],
    child: MaterialApp.router(
      title: 'dart_arena',
      theme: buildAppTheme(),
      routerConfig: _router,
    ),
  );
}
```

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: PASS. Smoke test still finds `dart_arena` because `MaterialApp.router` is wrapped, not replaced.

- [ ] **Step 3: Commit**

```bash
git add lib/app.dart
git commit -m "refactor(di): expose AppDatabase/WorkdirManager/SettingsRepository/RunDao via MultiRepositoryProvider"
```

---

## Task 3: Refactor `_NewRunPageState._startRun` to read repos via `context.read`

**Files:**
- Modify: `lib/ui/pages/new_run_page.dart`
- Modify: `test/ui/pages/new_run_page_test.dart`

`_startRun` keeps building `RunBloc` inline for now (so we don't need `StartRunConfig` yet — that's Task 4). But it reads its dependencies from `context.read` instead of constructing them.

- [ ] **Step 1: Update the imports and `_startRun` body in `new_run_page.dart`**

Edit `lib/ui/pages/new_run_page.dart`. Update the imports — remove `dart:io`, `path/path.dart`, `path_provider`; add `flutter_bloc`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/provider_factory.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
```

Replace the `_loadProviders` method body so it uses the injected `SettingsRepository`:

```dart
Future<void> _loadProviders() async {
  final settings = context.read<SettingsRepository>();
  final p = await buildEnabledProviders(settings);
  if (!mounted) return;
  setState(() {
    _providers = p;
    _loading = false;
  });
}
```

Replace the `_startRun` method with:

```dart
Future<void> _startRun() async {
  final selectedProviders =
      _providers.where((p) => _checkedProvider[p.id] == true).toList();
  final modelMap = {
    for (final p in selectedProviders) p.id: _models[p.id] ?? '',
  };
  final selectedTasks = _registry
      .all()
      .where((t) => _selectedTaskIds.contains(t.id))
      .toList();

  final settings = context.read<SettingsRepository>();
  final workdir = context.read<WorkdirManager>();
  final runDao = context.read<RunDao>();

  final bloc = RunBloc(
    workdirManager: workdir,
    runDao: runDao,
    now: () => DateTime.now(),
    idGenerator: () => 'run-${DateTime.now().millisecondsSinceEpoch}',
  );

  final judgeProviderId = await settings.getJudgeProviderId();
  final judgeModelId = await settings.getJudgeModelId();
  ModelProvider? judgeProvider;
  if (judgeProviderId != null && judgeModelId != null) {
    for (final candidate in _providers) {
      if (candidate.id == judgeProviderId) {
        judgeProvider = candidate;
        break;
      }
    }
  }
  final evaluatorConfig = EvaluatorConfig(
    judgeProvider: judgeProvider,
    judgeModel: judgeProvider == null ? null : judgeModelId,
  );

  bloc.add(StartRun(
    tasks: selectedTasks,
    providers: selectedProviders,
    modelByProvider: modelMap,
    evaluatorConfig: evaluatorConfig,
    name: _label.trim().isEmpty ? null : _label.trim(),
  ));

  if (!mounted) return;
  final goRouter = GoRouter.of(context);
  goRouter.push('/run', extra: bloc);
}
```

(`_loadProviders` was originally called from `initState`; that call site stays the same, but the implementation now uses `context.read`. `BuildContext.read` is safe inside `initState` *only* if scheduled — see Step 2.)

- [ ] **Step 2: Defer `_loadProviders` to a post-frame callback**

In `_NewRunPageState.initState()`, replace the body so `_loadProviders()` runs after the first frame. This keeps provider loading after the initial build while preserving the existing `initState` setup flow:

```dart
@override
void initState() {
  super.initState();
  _registry = widget.registry ?? buildDefaultTaskRegistry();
  for (final t in _registry.all()) {
    _selectedTaskIds.add(t.id);
  }
  if (widget.providers != null) {
    _providers = widget.providers!;
    _loading = false;
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProviders();
    });
  }
}
```

- [ ] **Step 3: Update `new_run_page_test.dart` to wrap in `MultiRepositoryProvider`**

Edit `test/ui/pages/new_run_page_test.dart`. Add imports at the top:

```dart
import 'dart:io';

import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
```

Add a helper near the top of `main()`:

```dart
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
      RepositoryProvider<WorkdirManager>.value(value: WorkdirManager(root: tmp)),
      RepositoryProvider<SettingsRepository>.value(value: SettingsRepository()),
      RepositoryProvider<RunDao>(create: (ctx) => RunDao(ctx.read<AppDatabase>())),
    ],
    child: MaterialApp(home: child),
  );
}
```

Update each existing `testWidgets(...)` body to call `_wrap` instead of `MaterialApp(home: ...)` directly. For example:

```dart
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
```

Apply the same `await _wrap(...)` pattern to the other two existing tests in this file.

- [ ] **Step 4: Run NewRunPage tests**

Run: `flutter test test/ui/pages/new_run_page_test.dart`
Expected: PASS — all three existing tests.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: PASS — no other test exercises `_startRun`'s internals, so no other test should break.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/new_run_page.dart test/ui/pages/new_run_page_test.dart
git commit -m "refactor(new-run): read repos via context.read instead of inline construction"
```

---

## Task 4: Introduce `StartRunConfig` value object

**Files:**
- Create: `lib/runner/start_run_config.dart`

A small immutable holder. No tests for this in isolation (it's a plain data class with no logic); it's exercised by Task 6's flow tests.

- [ ] **Step 1: Create the file**

Create `lib/runner/start_run_config.dart`:

```dart
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/providers/model_provider.dart';

class StartRunConfig {
  const StartRunConfig({
    required this.tasks,
    required this.providers,
    required this.modelByProvider,
    required this.evaluatorConfig,
    required this.weights,
    this.name,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, String> modelByProvider;
  final EvaluatorConfig evaluatorConfig;
  final Map<String, double> weights;
  final String? name;
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit (squashed with Task 5+6 below — do not commit yet)**

This task's diff alone won't compile-check anything since nothing imports `StartRunConfig` yet. Proceed to Task 5 before committing; commit happens at end of Task 6.

---

## Task 5: Refactor `RunProgressPage` to drop the `bloc` constructor parameter

**Files:**
- Modify: `lib/ui/pages/run_progress_page.dart`

After this task, `RunProgressPage` is a `const` `StatelessWidget` that reads its bloc from `context.read<RunBloc>()`. The owner of the bloc becomes the route builder (Task 6).

- [ ] **Step 1: Replace the `RunProgressPage` class top**

Edit `lib/ui/pages/run_progress_page.dart`. Replace the existing `RunProgressPage` class (the part that takes `bloc` and wraps `BlocProvider.value`) with:

```dart
class RunProgressPage extends StatelessWidget {
  const RunProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run')),
      body: BlocBuilder<RunBloc, RunState>(
        builder: (context, state) {
          return switch (state) {
            RunIdle() => const Center(child: Text('idle')),
            RunInProgress(
              :final completed,
              :final total,
              :final currentLabel,
              :final currentRawResponse,
            ) =>
              _ProgressView(
                completed: completed,
                total: total,
                label: currentLabel,
                rawResponse: currentRawResponse,
              ),
            RunCompleted(:final results) =>
              ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, i) => _ResultCard(result: results[i]),
              ),
            RunFailed(:final error) =>
              Center(child: Text('Failed: $error')),
          };
        },
      ),
    );
  }
}
```

(The inner widgets `_ProgressView` and `_ResultCard` are unchanged — keep them as they already exist below this class.)

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: errors at the `state.extra! as RunBloc` site in `lib/app.dart` and at `goRouter.push('/run', extra: bloc)` in `new_run_page.dart`. **This is expected** — Task 6 fixes both call sites simultaneously. Do not stop here.

---

## Task 6: Update the `/run` route to construct `RunBloc` via `BlocProvider`

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/ui/pages/new_run_page.dart`

This is the task that makes Tasks 4 and 5 compile. The `/run` route's builder reads `StartRunConfig` from `state.extra` and uses `BlocProvider(create: ...)` to build `RunBloc` synchronously, dispatching `StartRun` from inside `create`. `_startRun` constructs `StartRunConfig` and pushes it as `extra` instead of pushing the bloc.

- [ ] **Step 1: Update the `/run` route in `app.dart`**

Edit `lib/app.dart`. Add imports:

```dart
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/start_run_config.dart';
```

Replace the `/run` `GoRoute` entry with:

```dart
GoRoute(
  path: '/run',
  builder: (context, state) {
    final cfg = state.extra! as StartRunConfig;
    return BlocProvider<RunBloc>(
      create: (ctx) {
        final bloc = RunBloc(
          workdirManager: ctx.read<WorkdirManager>(),
          runDao: ctx.read<RunDao>(),
          weights: cfg.weights,
          now: () => DateTime.now(),
          idGenerator: () => 'run-${DateTime.now().millisecondsSinceEpoch}',
        );
        bloc.add(StartRun(
          tasks: cfg.tasks,
          providers: cfg.providers,
          modelByProvider: cfg.modelByProvider,
          evaluatorConfig: cfg.evaluatorConfig,
          name: cfg.name,
        ));
        return bloc;
      },
      child: const RunProgressPage(),
    );
  },
),
```

- [ ] **Step 2: Update `_startRun` in `new_run_page.dart` to push `StartRunConfig` instead of bloc**

Edit `lib/ui/pages/new_run_page.dart`. Add the import:

```dart
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/runner/start_run_config.dart';
```

Remove unused imports — after this change, `run_bloc.dart`, `run_event.dart`, `workdir_manager.dart`, and `dao/run_dao.dart` are no longer imported by this file. Remove those import lines.

Replace `_startRun` with:

```dart
Future<void> _startRun() async {
  final selectedProviders =
      _providers.where((p) => _checkedProvider[p.id] == true).toList();
  final modelMap = {
    for (final p in selectedProviders) p.id: _models[p.id] ?? '',
  };
  final selectedTasks = _registry
      .all()
      .where((t) => _selectedTaskIds.contains(t.id))
      .toList();

  final settings = context.read<SettingsRepository>();

  final judgeProviderId = await settings.getJudgeProviderId();
  final judgeModelId = await settings.getJudgeModelId();
  ModelProvider? judgeProvider;
  if (judgeProviderId != null && judgeModelId != null) {
    for (final candidate in _providers) {
      if (candidate.id == judgeProviderId) {
        judgeProvider = candidate;
        break;
      }
    }
  }
  final evaluatorConfig = EvaluatorConfig(
    judgeProvider: judgeProvider,
    judgeModel: judgeProvider == null ? null : judgeModelId,
  );

  if (!mounted) return;
  final goRouter = GoRouter.of(context);
  goRouter.push(
    '/run',
    extra: StartRunConfig(
      tasks: selectedTasks,
      providers: selectedProviders,
      modelByProvider: modelMap,
      evaluatorConfig: evaluatorConfig,
      weights: defaultEvaluatorWeights,
      name: _label.trim().isEmpty ? null : _label.trim(),
    ),
  );
}
```

(Note: `weights: defaultEvaluatorWeights` is a placeholder for now — Task 7 replaces it with `await settings.getEvaluatorWeights()`. Keeping the placeholder here makes Tasks 4–6 a clean "no behavior change" commit.)

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: PASS. The `RunBloc` lifecycle moved from "owned by the previous page, pushed via `extra`" to "owned by the route's `BlocProvider`". Existing tests don't exercise this seam directly so nothing breaks.

- [ ] **Step 5: Commit**

```bash
git add lib/runner/start_run_config.dart lib/app.dart lib/ui/pages/new_run_page.dart lib/ui/pages/run_progress_page.dart
git commit -m "refactor(run): construct RunBloc via BlocProvider on /run route, pass StartRunConfig as extra"
```

---

## Task 7: Wire saved evaluator weights into the run

**Files:**
- Modify: `lib/ui/pages/new_run_page.dart`

This is the smallest possible "fix the dead-code bug" diff: replace the `weights: defaultEvaluatorWeights` placeholder with an `await` to `SettingsRepository.getEvaluatorWeights()`. After this commit, edits to weights actually take effect on the next run.

- [ ] **Step 1: Read saved weights in `_startRun`**

Edit `lib/ui/pages/new_run_page.dart`. Replace the line `weights: defaultEvaluatorWeights,` with a hoisted variable. Specifically, just above the `if (!mounted) return;` check at the bottom of `_startRun`, insert:

```dart
  final weights = await _safeWeights(settings);
```

And change the `goRouter.push(...)` `extra:` argument to `weights: weights,`.

Then remove the now-unused `import 'package:dart_arena/core/scoring.dart';` (the default map is no longer referenced from this file).

Add a helper method on the state class (place it after `_startRun`):

```dart
Future<Map<String, double>> _safeWeights(SettingsRepository repo) async {
  try {
    return await repo.getEvaluatorWeights();
  } catch (e, st) {
    debugPrint('Failed to load evaluator weights: $e\n$st');
    return const {};
  }
}
```

The `return const {}` empty-map fallback is intentional: `SettingsRepository.getEvaluatorWeights` already merges defaults on top of overrides, but if the *call itself* throws, an empty map flows downstream. `RunBloc` then passes the empty map to `aggregate()`, which falls back to `1.0` per evaluator — equivalent to "all evaluators equally weighted." That's a safe degraded mode and won't block the run.

Add `import 'package:flutter/foundation.dart';` for `debugPrint`.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues. (`scoring.dart` import removed; `foundation.dart` import added.)

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/pages/new_run_page.dart
git commit -m "fix(new-run): load saved evaluator weights from settings before run"
```

---

## Task 8: Add explicit tests covering custom-weights propagation

**Files:**
- Modify: `test/runner/run_bloc_test.dart`
- Modify: `test/ui/pages/new_run_page_test.dart`

Two tests: one at the unit level (custom weights → custom aggregate), one at the widget level (Run-button → `StartRunConfig.weights` matches `SettingsRepository.getEvaluatorWeights()` return).

- [ ] **Step 1: Write the failing unit test**

Edit `test/runner/run_bloc_test.dart`. Add a new test case at the end of `main()`:

```dart
test('custom weights propagate to aggregate', () async {
  final tmp = await Directory.systemTemp.createTemp('dart_arena_bloc_w_');
  final db = AppDatabase(NativeDatabase.memory());

  final passEval = _AlwaysPass();
  final lowEval = _AlwaysLow();

  final bloc = RunBloc(
    workdirManager: WorkdirManager(root: tmp),
    runDao: RunDao(db),
    now: DateTime.now,
    idGenerator: () => 'run-w',
    weights: const {'pass': 4.0, 'low': 1.0},
  );

  final states = <RunState>[];
  final sub = bloc.stream.listen(states.add);

  bloc.add(StartRun(
    tasks: [_TwoEvaluatorTask([passEval, lowEval])],
    providers: [_FakeProvider()],
    modelByProvider: const {'fake': 'fake-1'},
    evaluatorConfig: const EvaluatorConfig(),
  ));

  await Future<void>.delayed(const Duration(seconds: 2));
  expect(states.last, isA<RunCompleted>());
  final completed = states.last as RunCompleted;
  // (1.0 * 4 + 0.2 * 1) / (4 + 1) = 4.2 / 5 = 0.84
  expect(completed.results.single.aggregateScore, closeTo(0.84, 1e-9));

  await sub.cancel();
  await bloc.close();
  await db.close();
  tmp.deleteSync(recursive: true);
});
```

Add the supporting fixtures **above `void main()`** in the same file:

```dart
class _AlwaysLow implements Evaluator {
  @override
  String get id => 'low';
  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async =>
      const EvaluationResult(evaluatorId: 'low', passed: false, score: 0.2);
}

class _TwoEvaluatorTask extends _StubTask {
  _TwoEvaluatorTask(this._evals);
  final List<Evaluator> _evals;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => _evals;
}
```

- [ ] **Step 2: Run the new test (it should already pass — `RunBloc.weights` was already plumbed through; this test just locks the behavior in)**

Run: `flutter test test/runner/run_bloc_test.dart --plain-name "custom weights propagate to aggregate"`
Expected: PASS.

- [ ] **Step 3: Write the failing widget test**

Edit `test/ui/pages/new_run_page_test.dart`. Add at the bottom of `main()`:

```dart
testWidgets('Run button reads weights from SettingsRepository before navigating',
    (tester) async {
  FlutterSecureStorage.setMockInitialValues({
    'evaluator_weights_json': '{"compile":2.5}',
  });

  final reg = TaskRegistry()..register(_StubTaskA());
  final fakeProvider = _FakeProvider();

  // Swap goRouter for a test router that captures `extra`.
  Object? capturedExtra;
  final router = GoRouter(
    initialLocation: '/new-run',
    routes: [
      GoRoute(
        path: '/new-run',
        builder: (_, __) => NewRunPage(
          registry: reg,
          providers: [fakeProvider],
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

  final tmp = await Directory.systemTemp.createTemp('dart_arena_run_btn_');
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  await tester.pumpWidget(MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AppDatabase>.value(value: db),
      RepositoryProvider<WorkdirManager>.value(value: WorkdirManager(root: tmp)),
      RepositoryProvider<SettingsRepository>.value(value: SettingsRepository()),
      RepositoryProvider<RunDao>(create: (ctx) => RunDao(ctx.read<AppDatabase>())),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();

  // Provide model id and check the provider so _canRun is true.
  await tester.tap(find.text('Fake'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Model id'), 'fake-1');
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(FilledButton, 'Run'));
  await tester.pumpAndSettle();

  expect(capturedExtra, isA<StartRunConfig>());
  final cfg = capturedExtra! as StartRunConfig;
  expect(cfg.weights['compile'], 2.5);
  expect(cfg.weights['analyze'], 0.5); // default still merged
});
```

Add the supporting fixture above `void main()`:

```dart
class _FakeProvider implements ModelProvider {
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
  }) async =>
      throw UnimplementedError();
}
```

And add the imports needed by the new test:

```dart
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/start_run_config.dart';
import 'package:go_router/go_router.dart';
```

- [ ] **Step 4: Run NewRunPage tests**

Run: `flutter test test/ui/pages/new_run_page_test.dart`
Expected: PASS — the new test plus the three existing ones.

- [ ] **Step 5: Run full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add test/runner/run_bloc_test.dart test/ui/pages/new_run_page_test.dart
git commit -m "test: cover custom weights propagation from settings to RunBloc"
```

---

## Task 9: `EvaluatorWeightsSection` — failing tests

**Files:**
- Create: `test/ui/widgets/evaluator_weights_section_test.dart`

Six tests describing the full behavior. They will all fail in this task (the widget doesn't exist yet); Task 10 implements the widget.

- [ ] **Step 1: Create the failing-tests file**

Create `test/ui/widgets/evaluator_weights_section_test.dart`:

```dart
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/ui/widgets/evaluator_weights_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(SettingsRepository repo) {
  return MaterialApp(
    home: Scaffold(
      body: RepositoryProvider<SettingsRepository>.value(
        value: repo,
        child: const EvaluatorWeightsSection(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders one row per evaluator id', (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();
    for (final id in defaultEvaluatorWeights.keys) {
      expect(find.text(id), findsOneWidget,
          reason: 'expected row for evaluator id "$id"');
    }
  });

  testWidgets('row badge says Default when value matches default',
      (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsNWidgets(defaultEvaluatorWeights.length));
    expect(find.text('Override'), findsNothing);
  });

  testWidgets('editing a row flips its badge to Override', (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();

    final compileField = find.byKey(const ValueKey('weight-field-compile'));
    await tester.enterText(compileField, '2.0');
    await tester.pumpAndSettle();

    expect(find.text('Override'), findsOneWidget);
    expect(find.text('Default'),
        findsNWidgets(defaultEvaluatorWeights.length - 1));
  });

  testWidgets('per-row Reset clears the override field', (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();

    final compileField = find.byKey(const ValueKey('weight-field-compile'));
    await tester.enterText(compileField, '2.0');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('weight-reset-compile')));
    await tester.pumpAndSettle();

    expect(find.text('Override'), findsNothing);
    expect(
      tester.widget<TextField>(compileField).controller!.text,
      '',
    );
  });

  testWidgets('Save persists only rows that differ from defaults',
      (tester) async {
    final repo = SettingsRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('weight-field-compile')),
      '2.0',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final stored = await repo.getEvaluatorWeights();
    expect(stored['compile'], 2.0);
    // Other rows kept their defaults
    expect(stored['analyze'], defaultEvaluatorWeights['analyze']);
    expect(stored['test'], defaultEvaluatorWeights['test']);
  });

  testWidgets('invalid input disables Save', (tester) async {
    await tester.pumpWidget(_wrap(SettingsRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('weight-field-compile')),
      '-1',
    );
    await tester.pumpAndSettle();

    final btn =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(btn.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run the new test file**

Run: `flutter test test/ui/widgets/evaluator_weights_section_test.dart`
Expected: FAIL (compile error — `package:dart_arena/ui/widgets/evaluator_weights_section.dart` does not exist).

- [ ] **Step 3: Do NOT commit yet**

Tests are failing on a missing target file. Task 10 makes them pass.

---

## Task 10: `EvaluatorWeightsSection` — implementation

**Files:**
- Create: `lib/ui/widgets/evaluator_weights_section.dart`

- [ ] **Step 1: Create the widget**

Create `lib/ui/widgets/evaluator_weights_section.dart`:

```dart
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EvaluatorWeightsSection extends StatefulWidget {
  const EvaluatorWeightsSection({super.key, this.repo});
  final SettingsRepository? repo;

  @override
  State<EvaluatorWeightsSection> createState() =>
      _EvaluatorWeightsSectionState();
}

class _EvaluatorWeightsSectionState extends State<EvaluatorWeightsSection> {
  late final SettingsRepository _repo;
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? context.read<SettingsRepository>();
    for (final id in defaultEvaluatorWeights.keys) {
      _controllers[id] = TextEditingController()
        ..addListener(() => setState(() {}));
    }
    _load();
  }

  Future<void> _load() async {
    final effective = await _repo.getEvaluatorWeights();
    if (!mounted) return;
    setState(() {
      for (final id in defaultEvaluatorWeights.keys) {
        final v = effective[id] ?? defaultEvaluatorWeights[id]!;
        _controllers[id]!.text = _isDefault(id, v) ? '' : v.toString();
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isDefault(String id, double v) {
    final def = defaultEvaluatorWeights[id]!;
    return (v - def).abs() < 1e-9;
  }

  /// Returns the parsed value for [id], or null if the row is invalid.
  /// Empty input returns the default.
  double? _parsed(String id) {
    final text = _controllers[id]!.text.trim();
    if (text.isEmpty) return defaultEvaluatorWeights[id];
    final v = double.tryParse(text);
    if (v == null || v < 0) return null;
    return v;
  }

  bool get _allValid =>
      defaultEvaluatorWeights.keys.every((id) => _parsed(id) != null);

  Map<String, double> _effectiveWeights() {
    final out = <String, double>{};
    for (final id in defaultEvaluatorWeights.keys) {
      out[id] = _parsed(id) ?? defaultEvaluatorWeights[id]!;
    }
    return out;
  }

  Map<String, double> _overrides() {
    final out = <String, double>{};
    for (final id in defaultEvaluatorWeights.keys) {
      final v = _parsed(id);
      if (v == null) continue;
      if (!_isDefault(id, v)) out[id] = v;
    }
    return out;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    await _repo.setEvaluatorWeights(_overrides());
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Evaluator weights saved')),
    );
  }

  void _resetRow(String id) {
    setState(() => _controllers[id]!.text = '');
  }

  void _resetAll() {
    setState(() {
      for (final c in _controllers.values) {
        c.text = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evaluator Weights',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final id in defaultEvaluatorWeights.keys)
              _row(context, id),
            const Divider(height: 32),
            _DistributionPreview(weights: _effectiveWeights()),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _allValid ? _save : null,
                  child: const Text('Save'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _resetAll,
                  child: const Text('Reset all to defaults'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String id) {
    final parsed = _parsed(id);
    final isDefault =
        parsed != null && _isDefault(id, parsed);
    final isInvalid = parsed == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              id,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: ValueKey('weight-field-$id'),
              controller: _controllers[id],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: defaultEvaluatorWeights[id]!.toString(),
                border: const OutlineInputBorder(),
                errorText: isInvalid ? 'must be ≥ 0' : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            label: Text(isDefault ? 'Default' : 'Override'),
            backgroundColor:
                isDefault ? Colors.green.shade700 : Colors.orange.shade800,
          ),
          IconButton(
            key: ValueKey('weight-reset-$id'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to default',
            onPressed: () => _resetRow(id),
          ),
        ],
      ),
    );
  }
}

class _DistributionPreview extends StatelessWidget {
  const _DistributionPreview({required this.weights});
  final Map<String, double> weights;

  @override
  Widget build(BuildContext context) {
    final sum = weights.values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) {
      return const Text(
        'Normalized distribution: (all weights are zero)',
        style: TextStyle(fontSize: 12),
      );
    }
    final colors = <Color>[
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.amber.shade400,
      Colors.green.shade400,
      Colors.teal.shade400,
      Colors.blue.shade400,
      Colors.purple.shade400,
    ];
    final ids = weights.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Normalized distribution',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 16,
          child: Row(
            children: [
              for (var i = 0; i < ids.length; i++)
                Expanded(
                  flex: ((weights[ids[i]]! / sum) * 1000)
                      .round()
                      .clamp(1, 1000)
                      .toInt(),
                  child: Container(color: colors[i % colors.length]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var i = 0; i < ids.length; i++)
              Chip(
                label: Text(
                  '${ids[i]} ${((weights[ids[i]]! / sum) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: colors[i % colors.length].withValues(
                  alpha: 0.2,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Run the widget tests**

Run: `flutter test test/ui/widgets/evaluator_weights_section_test.dart`
Expected: PASS for all six tests.

- [ ] **Step 3: Run full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/evaluator_weights_section.dart test/ui/widgets/evaluator_weights_section_test.dart
git commit -m "feat(settings): EvaluatorWeightsSection widget"
```

---

## Task 11: Wire `EvaluatorWeightsSection` into `SettingsPage`

**Files:**
- Modify: `lib/ui/pages/settings_page.dart`

Two changes: add the new section between `_JudgeSection` and `_OllamaLocalSection`, and migrate `_SettingsPageState._repo` from `final _repo = SettingsRepository()` to `context.read<SettingsRepository>()`. The four subwidgets (`_JudgeSection`, `_OllamaLocalSection`, `_ApiKeySection`, `_ReadmeSection`) keep their own ad-hoc repos for now (per spec scope §2).

- [ ] **Step 1: Add the import**

Edit `lib/ui/pages/settings_page.dart`. Add the imports:

```dart
import 'package:dart_arena/ui/widgets/evaluator_weights_section.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
```

- [ ] **Step 2: Migrate `_SettingsPageState._repo` and add the section slot**

Replace the `_SettingsPageState` class with:

```dart
class _SettingsPageState extends State<SettingsPage> {
  late final SettingsRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = context.read<SettingsRepository>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _JudgeSection(),
          const Divider(),
          const EvaluatorWeightsSection(),
          const Divider(),
          _OllamaLocalSection(repo: _repo),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'ollama_cloud',
            label: 'Ollama Cloud',
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'opencode_zen',
            label: 'OpenCode Zen',
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'openai',
            label: 'OpenAI',
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'openrouter',
            label: 'OpenRouter',
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'deepseek',
            label: 'DeepSeek',
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'anthropic',
            label: 'Anthropic',
          ),
          const Divider(),
          _ReadmeSection(repo: _repo),
          const Divider(),
          const ListTile(
            title: Text('Factory Droid'),
            subtitle: Text('Uses local droid CLI; no key needed in app.'),
          ),
        ],
      ),
    );
  }
}
```

(`context.read` is safe in `initState` only because `MultiRepositoryProvider` wraps the entire `MaterialApp.router` — so by the time `SettingsPage` mounts, the provider is already in scope.)

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 4: Run full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/settings_page.dart
git commit -m "feat(settings): mount EvaluatorWeightsSection in SettingsPage"
```

---

## Task 12: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Lint, analyze, and test**

Run in sequence:

```bash
flutter analyze
flutter test
```

Expected: `flutter analyze` reports 0 issues. `flutter test` reports all tests passing (existing + the new ones in `evaluator_weights_section_test.dart`, the new test in `run_bloc_test.dart`, and the new test in `new_run_page_test.dart`).

- [ ] **Step 2: Manual smoke check (optional but recommended)**

Run: `flutter run -d linux`
- Open Settings → confirm "Evaluator Weights" section appears between "Judge Model" and "Ollama Local".
- Edit `compile` to `2.5`, press Save, navigate away, navigate back → value persists, badge says "Override".
- Press the per-row Reset on `compile` → field clears and falls back to default; press Save again.
- Press "Reset all to defaults" → all fields clear; Save.
- Start a Run with at least one task and one provider → run completes as before (no regression).

- [ ] **Step 3: No commit needed for this task** (verification only).

---

## Self-review notes (post-write)

**Spec coverage check** (every requirement in `docs/specs/2026-05-03-plan-7-polish-design.md` mapped to a task):

- §3.1 dependency graph (`MultiRepositoryProvider`, `BlocProvider` on `/run`) → Tasks 1, 2, 6.
- §3.2 `StartRunConfig` → Task 4.
- §3.3 `EvaluatorWeightsSection` (rows, badges, reset, save, distribution preview, validation) → Tasks 9, 10.
- §3.4 saved weights flow into `RunBloc` only via `_startRun`; analytics untouched → Task 7 (loaded in `_startRun`); analytics is in the "Untouched" file map.
- §4 file-by-file migration → all five touched files covered (Tasks 1, 2, 3, 5, 6, 7, 11).
- §5 testing strategy:
  - `evaluator_weights_section_test.dart` → Task 9.
  - `new_run_page_test.dart` extension (`MultiRepositoryProvider` wrapper + `StartRunConfig.weights` assertion) → Tasks 3, 8.
  - `run_bloc_test.dart` extension (custom-weights propagation) → Task 8.
  - `widget_test.dart` update for new `App` constructor → Task 1.
- §6 risks: empty-map fallback in `_safeWeights` mitigates risk #5 (storage read failure).
- §7 commit plan: 5-commit shape preserved (DI plumbing → StartRunConfig+BlocProvider → wire weights → editor widget → SettingsPage integration), produced by Tasks 1–3, 4–6, 7–8, 9–10, 11.

**Type consistency check**: `StartRunConfig` field names, `RunBloc(weights: ...)` parameter, `SettingsRepository.getEvaluatorWeights()` return shape — all match across tasks.

**Placeholder scan**: no TODO / TBD / "implement later" / "similar to Task N" / "add error handling" patterns. Every code-changing step contains the actual code.
