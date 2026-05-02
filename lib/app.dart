import 'package:dart_arena/ui/pages/home_page.dart';
import 'package:dart_arena/ui/pages/new_run_page.dart';
import 'package:dart_arena/ui/pages/run_progress_page.dart';
import 'package:dart_arena/ui/pages/settings_page.dart';
import 'package:dart_arena/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/new-run', builder: (_, __) => const NewRunPage()),
    GoRoute(path: '/run', builder: (_, __) => const RunProgressPage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
  ],
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'dart_arena',
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
