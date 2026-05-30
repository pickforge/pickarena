import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/benchmark_task.dart';
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

({String providerId, String modelId}) splitLeaderboardSelectionKey(String key) {
  final sep = key.indexOf(':');
  return (
    providerId: sep < 0 ? key : key.substring(0, sep),
    modelId: sep < 0 ? '' : key.substring(sep + 1),
  );
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
      track: q['track'] == null
          ? null
          : BenchmarkTrack.values.firstWhere(
              (t) => t.name == q['track'],
              orElse: () => BenchmarkTrack.codegen,
            ),
      difficulty: _difficultyFromQuery(q['difficulty']),
      tags: _tagFromQuery(q['tag']) == null
          ? const {}
          : {_tagFromQuery(q['tag'])!},
      dateRange: DateRange.fromQueryParam(q['since']),
      dimension: ScoreDimension.values.firstWhere(
        (d) => d.name == q['dim'],
        orElse: () => ScoreDimension.overall,
      ),
    );
  }

  TaskDifficulty? _difficultyFromQuery(String? raw) {
    if (raw == null) return null;
    for (final difficulty in TaskDifficulty.values) {
      if (difficulty.name == raw && difficulty != TaskDifficulty.unspecified) {
        return difficulty;
      }
    }
    return null;
  }

  TaskTag? _tagFromQuery(String? raw) {
    if (raw == null) return null;
    for (final tag in TaskTag.values) {
      if (tag.slug == raw || tag.name == raw) return tag;
    }
    return null;
  }

  Set<String>? _taskIdsForCurrentCategory() {
    if (!_filter.hasTaskMetadataFilter) return null;
    return widget.registry
        .query(
          category: _filter.category,
          difficulty: _filter.difficulty,
          tags: _filter.tags,
        )
        .map((t) => t.id)
        .toSet();
  }

  Map<String, Category> _categoryByTaskId() => {
    for (final t in widget.registry.all()) t.id: t.category,
  };

  void _refresh() {
    final taskIds = _taskIdsForCurrentCategory();
    setState(() {
      _rankFuture = _repo!.rank(filter: _filter, taskIdsForCategory: taskIds);
    });
    _rankFuture!.then((rs) {
      if (!mounted) return;
      final newSelection = rs.any((r) => r.key == _selectedKey)
          ? _selectedKey
          : rs.isEmpty
          ? null
          : rs.first.key;
      if (newSelection != _selectedKey) {
        setState(() {
          _selectedKey = newSelection;
        });
        _updateUrl();
      }
      _refreshDetail();
    });
  }

  void _refreshDetail() {
    if (_selectedKey == null) {
      setState(() {
        _detailFuture = Future.value(null);
      });
      return;
    }
    final (:providerId, :modelId) = splitLeaderboardSelectionKey(_selectedKey!);
    final taskIds = _taskIdsForCurrentCategory();
    final categoryByTaskId = _categoryByTaskId();
    final future = _repo!.detail(
      providerId: providerId,
      modelId: modelId,
      filter: _filter,
      taskIdsForCategory: taskIds,
      categoryByTaskId: categoryByTaskId,
    );
    setState(() {
      _detailFuture = future;
    });
  }

  void _updateUrl() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final qp = <String, String>{};
    if (_filter.category != null) qp['category'] = _filter.category!.name;
    if (_filter.providerId != null) qp['provider'] = _filter.providerId!;
    if (_filter.track != null) qp['track'] = _filter.track!.name;
    if (_filter.difficulty != null) {
      qp['difficulty'] = _filter.difficulty!.name;
    }
    if (_filter.tags.length == 1) qp['tag'] = _filter.tags.single.slug;
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
    setState(() {
      _selectedKey = key;
    });
    _refreshDetail();
    _updateUrl();
  }

  void _onTogglePin(String key) {
    setState(() {
      _pinnedKey = _pinnedKey == key ? null : key;
    });
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
          }.toList()..sort();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final radarHeight = constraints.maxHeight < 500 ? 96.0 : 240.0;
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
                    height: radarHeight,
                    child: DimensionRadar(
                      selected: detail.ranking.dimensions,
                      pinned: pinned,
                      selectedLabel: detail.ranking.modelId,
                      pinnedLabel: pinnedKey,
                    ),
                  ),
                ),
                _RankingSummary(ranking: detail.ranking),
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
                    '${detail.ranking.primaryPassSampleCount} pass/fail samples · '
                    '${detail.ranking.dimensions.problems} evaluator problems',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RankingSummary extends StatelessWidget {
  const _RankingSummary({required this.ranking});

  final ModelRanking ranking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodySmall,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reliable pass rate: ${_formatPassRate(ranking)}'),
            Text(
              'Medians: ${_formatDuration(ranking.medianLatencyMs)}, '
              '${_formatTokens(ranking)}, '
              '${_formatCost(ranking.medianEstimatedCostMicros)}',
            ),
            Text(
              'Cost per solved task: ${_formatCost(ranking.costPerSolvedTaskMicros)}',
            ),
            Text(
              'Failures: ${_formatFailureBreakdown(ranking.failureBreakdown)}',
            ),
            if (ranking.lowSample)
              const Text(
                'Low sample: run at least 5 pass/fail samples before comparing.',
              ),
            if (ranking.primaryPassRate != null)
              const Text('Legacy aggregate dimensions are secondary.'),
          ],
        ),
      ),
    );
  }
}

String _formatPassRate(ModelRanking ranking) {
  final passRate = ranking.primaryPassRate;
  if (passRate == null) return 'unknown';
  final interval = ranking.primaryPassInterval;
  final ci = interval == null
      ? ''
      : ' (${_percent(interval.lower)}–${_percent(interval.upper)} Wilson 95%)';
  return '${ranking.primaryPassCount}/${ranking.primaryPassSampleCount} '
      '${_percent(passRate)}$ci';
}

String _formatDuration(int? medianLatencyMs) {
  if (medianLatencyMs == null) return 'duration unknown';
  if (medianLatencyMs < 1000) return '${medianLatencyMs}ms';
  return '${(medianLatencyMs / 1000).toStringAsFixed(1)}s';
}

String _formatTokens(ModelRanking ranking) {
  final prompt = ranking.medianPromptTokens;
  final completion = ranking.medianCompletionTokens;
  if (prompt == null && completion == null) return 'tokens unknown';
  return '${prompt ?? '?'} in / ${completion ?? '?'} out tokens';
}

String _formatCost(int? costMicros) {
  if (costMicros == null) return 'unknown';
  return '\$${(costMicros / 1000000).toStringAsFixed(4)}';
}

String _formatFailureBreakdown(Map<String, int> breakdown) {
  if (breakdown.isEmpty) return 'unknown';
  final entries = breakdown.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((e) => '${e.key} ${e.value}').join(', ');
}

String _percent(double value) => '${(value * 100).toStringAsFixed(0)}%';
