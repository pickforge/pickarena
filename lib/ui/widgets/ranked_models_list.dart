import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:flutter/material.dart';

class RankedModelsList extends StatelessWidget {
  const RankedModelsList({
    super.key,
    required this.rankings,
    required this.dimension,
    required this.selectedKey,
    required this.pinnedKey,
    required this.onSelect,
    required this.onTogglePin,
  });

  final List<ModelRanking> rankings;
  final ScoreDimension dimension;
  final String? selectedKey;
  final String? pinnedKey;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onTogglePin;

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) {
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
    return ListView.separated(
      itemCount: rankings.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rankings[i];
        final score = r.dimensions.byDimension(dimension);
        final isSelected = r.key == selectedKey;
        final isPinned = r.key == pinnedKey;
        final passRate = r.primaryPassRate;
        final subtitle = passRate == null
            ? r.providerId
            : '${r.providerId} · pass ${r.primaryPassCount}/${r.primaryPassSampleCount} '
                  '(${(passRate * 100).toStringAsFixed(0)}%)';
        return ListTile(
          selected: isSelected,
          leading: SizedBox(
            width: 24,
            child: Text('${i + 1}', textAlign: TextAlign.right),
          ),
          title: Text(r.modelId),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                ),
                onPressed: () => onTogglePin(r.key),
              ),
            ],
          ),
          onTap: () => onSelect(r.key),
        );
      },
    );
  }
}
