import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/ui/widgets/dimension_radar.dart';
import 'package:dart_arena/ui/widgets/leaderboard_filters.dart';
import 'package:dart_arena/ui/widgets/per_task_bar_chart.dart';
import 'package:dart_arena/ui/widgets/ranked_models_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({
    super.key,
    required this.registry,
    required this.initialQuery,
    this.repository,
  });

  final TaskRegistry registry;
  final Map<String, String> initialQuery;
  final LeaderboardRepository? repository;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  LeaderboardRepository? _repo;
  late LeaderboardFilter _filter;
  String? _selectedKey;
  String? _pinnedKey;
  Future<List<ModelRanking>>? _rankFuture;
  Future<ModelDetail?>? _detailFuture;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? context.read<LeaderboardRepository>();
    _filter = _filterFromQuery(widget.initialQuery);
    _selectedKey = widget.initialQuery['sel'];
    _pinnedKey = widget.initialQuery['pin'];
    _refresh();
  }

  LeaderboardFilter _filterFromQuery(Map<String, String> q) {
    return LeaderboardFilter(
      category: q['category'] == null
          ? null
          : Category.values.firstWhere(
              (c) => c.name == q['category'],
              orElse: () => Category.bugFix,
            ),
      providerId: q['provider'],
      dateRange: DateRange.fromQueryParam(q['since']),
      dimension: ScoreDimension.values.firstWhere(
        (d) => d.name == q['dim'],
        orElse: () => ScoreDimension.overall,
      ),
    );
  }

  Set<String>? _taskIdsForCurrentCategory() {
    if (_filter.category == null) return null;
    return widget.registry
        .byCategory(_filter.category!)
        .map((t) => t.id)
        .toSet();
  }

  Map<String, Category> _categoryByTaskId() => {
        for (final t in widget.registry.all()) t.id: t.category,
      };

  void _refresh() {
    final taskIds = _taskIdsForCurrentCategory();
    setState(() {
      _rankFuture =
          _repo!.rank(filter: _filter, taskIdsForCategory: taskIds);
    });
    _rankFuture!.then((rs) {
      if (!mounted) return;
      final newSelection = rs.any((r) => r.key == _selectedKey)
          ? _selectedKey
          : rs.isEmpty
              ? null
              : rs.first.key;
      if (newSelection != _selectedKey) {
        setState(() { _selectedKey = newSelection; });
        _updateUrl();
      }
      _refreshDetail();
    });
  }

  void _refreshDetail() {
    if (_selectedKey == null) {
      setState(() { _detailFuture = Future.value(null); });
      return;
    }
    final parts = _selectedKey!.split(':');
    final taskIds = _taskIdsForCurrentCategory();
    final categoryByTaskId = _categoryByTaskId();
    final future = _repo!.detail(
      providerId: parts[0],
      modelId: parts[1],
      filter: _filter,
      taskIdsForCategory: taskIds,
      categoryByTaskId: categoryByTaskId,
    );
    setState(() { _detailFuture = future; });
  }

  void _updateUrl() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final qp = <String, String>{};
    if (_filter.category != null) qp['category'] = _filter.category!.name;
    if (_filter.providerId != null) qp['provider'] = _filter.providerId!;
    if (_filter.dateRange != DateRange.allTime) {
      qp['since'] = _filter.dateRange.toQueryParam();
    }
    if (_filter.dimension != ScoreDimension.overall) {
      qp['dim'] = _filter.dimension.name;
    }
    if (_selectedKey != null) qp['sel'] = _selectedKey!;
    if (_pinnedKey != null) qp['pin'] = _pinnedKey!;
    router.replace<void>(
      Uri(path: '/leaderboard', queryParameters: qp).toString(),
    );
  }

  void _onFilterChanged(LeaderboardFilter f) {
    setState(() {
      _filter = f;
      _selectedKey = null;
    });
    _refresh();
    _updateUrl();
  }

  void _onSelect(String key) {
    setState(() { _selectedKey = key; });
    _refreshDetail();
    _updateUrl();
  }

  void _onTogglePin(String key) {
    setState(() { _pinnedKey = _pinnedKey == key ? null : key; });
    _updateUrl();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: FutureBuilder<List<ModelRanking>>(
        future: _rankFuture,
        builder: (context, snap) {
          final rows = snap.data ?? const [];
          final providerOptions = {
            if (_filter.providerId != null) _filter.providerId!,
            ...rows.map((r) => r.providerId),
          }.toList()
            ..sort();
          return Column(
            children: [
              LeaderboardFilters(
                filter: _filter,
                providerOptions: providerOptions,
                onChanged: _onFilterChanged,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 55,
                      child: RankedModelsList(
                        rankings: rows,
                        dimension: _filter.dimension,
                        selectedKey: _selectedKey,
                        pinnedKey: _pinnedKey,
                        onSelect: _onSelect,
                        onTogglePin: _onTogglePin,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 45,
                      child: _DetailPane(
                        detailFuture: _detailFuture,
                        rankings: rows,
                        pinnedKey: _pinnedKey,
                        onTaskTap: (s) => context.push(
                          '/runs/${s.lastRunId}/task-runs/${s.lastTaskRunId}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.detailFuture,
    required this.rankings,
    required this.pinnedKey,
    required this.onTaskTap,
  });

  final Future<ModelDetail?>? detailFuture;
  final List<ModelRanking> rankings;
  final String? pinnedKey;
  final void Function(PerTaskScore) onTaskTap;

  @override
  Widget build(BuildContext context) {
    if (detailFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<ModelDetail?>(
      future: detailFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final detail = snap.data;
        if (detail == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No models match this filter — try widening the date range.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final pinned = pinnedKey == null
            ? null
            : rankings
                .where((r) => r.key == pinnedKey)
                .map((r) => r.dimensions)
                .firstOrNull;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 240,
                child: DimensionRadar(
                  selected: detail.ranking.dimensions,
                  pinned: pinned,
                  selectedLabel: detail.ranking.modelId,
                  pinnedLabel: pinnedKey,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: PerTaskBarChart(
                scores: detail.perTask,
                onTap: onTaskTap,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${detail.ranking.taskRunCount} task-runs · '
                '${detail.ranking.dimensions.problems} problems',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}
