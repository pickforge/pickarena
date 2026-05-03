import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/core/category.dart';
import 'package:flutter/material.dart';

class LeaderboardFilters extends StatelessWidget {
  const LeaderboardFilters({
    super.key,
    required this.filter,
    required this.providerOptions,
    required this.onChanged,
  });

  final LeaderboardFilter filter;
  final List<String> providerOptions;
  final ValueChanged<LeaderboardFilter> onChanged;

  Future<void> _pickCustomRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: filter.dateRange.from != null && filter.dateRange.to != null
          ? DateTimeRange(
              start: filter.dateRange.from!,
              end: filter.dateRange.to!,
            )
          : null,
    );
    if (picked != null) {
      onChanged(filter.copyWith(
        dateRange: DateRange.custom(from: picked.start, to: picked.end),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<Category?>(
            key: const Key('category-dropdown'),
            value: filter.category,
            hint: const Text('All categories'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All categories')),
              for (final c in Category.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (c) => onChanged(filter.copyWith(
              category: c,
              clearCategory: c == null,
            )),
          ),
          DropdownButton<String?>(
            key: const Key('provider-dropdown'),
            value: filter.providerId,
            hint: const Text('All providers'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All providers')),
              for (final p in providerOptions)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (p) => onChanged(filter.copyWith(
              providerId: p,
              clearProviderId: p == null,
            )),
          ),
          _RangeChips(
            range: filter.dateRange,
            onPick: (r) => onChanged(filter.copyWith(dateRange: r)),
            onCustom: () => _pickCustomRange(context),
          ),
          DropdownButton<ScoreDimension>(
            key: const Key('dim-dropdown'),
            value: filter.dimension,
            items: [
              for (final d in ScoreDimension.values)
                DropdownMenuItem(value: d, child: Text(d.label)),
            ],
            onChanged: (d) => d == null
                ? null
                : onChanged(filter.copyWith(dimension: d)),
          ),
        ],
      ),
    );
  }
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({
    required this.range,
    required this.onPick,
    required this.onCustom,
  });
  final DateRange range;
  final ValueChanged<DateRange> onPick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, DateRange value, {VoidCallback? onTapOverride}) {
      return ChoiceChip(
        label: Text(label),
        selected: range == value,
        onSelected: (_) => onTapOverride != null ? onTapOverride() : onPick(value),
      );
    }

    return Wrap(
      spacing: 6,
      children: [
        chip('7d', DateRange.last7d),
        chip('30d', DateRange.last30d),
        chip('All time', DateRange.allTime),
        ChoiceChip(
          label: const Text('Custom…'),
          selected: range.isCustom,
          onSelected: (_) => onCustom(),
        ),
      ],
    );
  }
}
