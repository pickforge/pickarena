import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/in_progress_banner.dart';
import 'package:dart_arena/ui/widgets/recent_runs_strip.dart';
import 'package:dart_arena/ui/widgets/showcase_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.registry,
    this.dao,
    this.repository,
  });

  final TaskRegistry registry;
  final RunDao? dao;
  final LeaderboardRepository? repository;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final RunDao _dao;
  late final LeaderboardRepository _repo;
  Future<_DashboardData>? _future;

  @override
  void initState() {
    super.initState();
    _dao = widget.dao ?? context.read<RunDao>();
    _repo = widget.repository ?? context.read<LeaderboardRepository>();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final recentRuns = await _dao.recentRuns(limit: 10);
    final withTaskRuns = <(Run, List<TaskRun>)>[];
    for (final r in recentRuns) {
      withTaskRuns.add((r, await _dao.taskRunsForRun(r.id)));
    }
    final inFlight = await _dao.inProgressRuns();

    final tops = <Category, ModelRanking?>{};
    for (final cat in Category.values) {
      final taskIds = widget.registry.byCategory(cat).map((t) => t.id).toSet();
      if (taskIds.isEmpty) {
        tops[cat] = null;
        continue;
      }
      final ranks = await _repo.rank(
        filter: LeaderboardFilter(category: cat),
        taskIdsForCategory: taskIds,
      );
      tops[cat] = ranks.isEmpty ? null : ranks.first;
    }

    return _DashboardData(
      recentRuns: withTaskRuns,
      inFlight: inFlight,
      topPerCategory: tops,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('dart_arena'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Run history',
            onPressed: () => context.push('/runs'),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Leaderboard',
            onPressed: () => context.push('/leaderboard'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.play_arrow),
        label: const Text('New Run'),
        onPressed: () => context.push('/new-run'),
      ),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.recentRuns.isEmpty) return const _FreshInstall();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InProgressBanner(
                  inFlight: data.inFlight,
                  onTap: (r) => context.push('/runs/${r.id}'),
                ),
                _ShowcaseStrip(
                  topPerCategory: data.topPerCategory,
                  onCategoryTap: (cat) =>
                      context.push('/leaderboard?category=${cat.name}'),
                ),
                RecentRunsStrip(
                  runs: data.recentRuns,
                  onTapRow: (r) => context.push('/runs/${r.id}'),
                  onViewAll: () => context.push('/runs'),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.recentRuns,
    required this.inFlight,
    required this.topPerCategory,
  });
  final List<(Run, List<TaskRun>)> recentRuns;
  final List<Run> inFlight;
  final Map<Category, ModelRanking?> topPerCategory;
}

class _ShowcaseStrip extends StatelessWidget {
  const _ShowcaseStrip({
    required this.topPerCategory,
    required this.onCategoryTap,
  });

  final Map<Category, ModelRanking?> topPerCategory;
  final void Function(Category) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Top model per category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                for (final cat in Category.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 260,
                      child: ShowcaseCard(
                        category: cat,
                        top: topPerCategory[cat],
                        onTap: () => onCategoryTap(cat),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreshInstall extends StatelessWidget {
  const _FreshInstall();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Run your first benchmark',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Once you have data, this dashboard will show top models per '
              'category and your most recent runs.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
