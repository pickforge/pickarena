import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/agent/droid_agent_harness.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/review/review_repository.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/start_run_config.dart';
import 'package:dart_arena/runner/tmpdir_manager.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:dart_arena/ui/pages/dashboard_page.dart';
import 'package:dart_arena/ui/pages/leaderboard_page.dart';
import 'package:dart_arena/ui/pages/new_run_page.dart';
import 'package:dart_arena/ui/pages/review_queue_page.dart';
import 'package:dart_arena/ui/pages/run_details_page.dart';
import 'package:dart_arena/ui/pages/task_run_details_page.dart';
import 'package:dart_arena/ui/pages/run_history_page.dart';
import 'package:dart_arena/ui/pages/run_progress_page.dart';
import 'package:dart_arena/ui/pages/settings_page.dart';
import 'package:dart_arena/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final TaskRegistry _registry = buildDefaultTaskRegistry();

final routeObserver = RouteObserver<PageRoute<void>>();

final _router = GoRouter(
  initialLocation: '/',
  observers: [routeObserver],
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => DashboardPage(registry: _registry),
    ),
    GoRoute(path: '/new-run', builder: (_, __) => const NewRunPage()),
    GoRoute(
      path: '/review',
      builder: (_, __) => ReviewQueuePage(registry: _registry),
    ),
    GoRoute(
      path: '/run',
      builder: (context, state) {
        final cfg = state.extra! as StartRunConfig;
        return BlocProvider<RunBloc>(
          create: (ctx) {
            final bloc = RunBloc(
              workdirManager: ctx.read<WorkdirManager>(),
              runDao: ctx.read<RunDao>(),
              planDao: ctx.read<PlanDao>(),
              weights: cfg.weights,
              now: () => DateTime.now(),
              idGenerator: () => 'run-${DateTime.now().millisecondsSinceEpoch}',
              agentHarnesses: [DroidAgentHarness()],
            );
            bloc.add(
              StartRun(
                tasks: cfg.tasks,
                providers: cfg.providers,
                modelsByProvider: cfg.modelsByProvider,
                evaluatorConfig: cfg.evaluatorConfig,
                useReferencePlan: cfg.useReferencePlan,
                name: cfg.name,
                maxConcurrency: cfg.maxConcurrency,
                existingRunId: cfg.existingRunId,
                trialsPerTask: cfg.trialsPerTask,
              ),
            );
            return bloc;
          },
          child: const RunProgressPage(),
        );
      },
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
    required this.tmpDirManager,
    super.key,
  });

  final AppDatabase database;
  final WorkdirManager workdir;
  final SettingsRepository settings;
  final TmpDirManager tmpDirManager;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppDatabase>.value(value: database),
        RepositoryProvider<WorkdirManager>.value(value: workdir),
        RepositoryProvider<TmpDirManager>.value(value: tmpDirManager),
        RepositoryProvider<SettingsRepository>.value(value: settings),
        RepositoryProvider<RunDao>(
          create: (ctx) => RunDao(ctx.read<AppDatabase>()),
        ),
        RepositoryProvider<PlanDao>(
          create: (ctx) => PlanDao(ctx.read<AppDatabase>()),
        ),
        RepositoryProvider<LeaderboardRepository>(
          create: (ctx) => LeaderboardRepository(ctx.read<AppDatabase>()),
        ),
        RepositoryProvider<ReviewRepository>(
          create: (ctx) => ReviewRepository(
            ctx.read<AppDatabase>(),
            settings: ctx.read<SettingsRepository>(),
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Dart Arena',
        theme: buildAppTheme(),
        routerConfig: _router,
      ),
    );
  }
}
