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
