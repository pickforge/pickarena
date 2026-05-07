import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/ui/widgets/dimension_radar.dart';
import 'package:flutter/material.dart';

class ShowcaseCard extends StatelessWidget {
  const ShowcaseCard({
    super.key,
    required this.category,
    required this.top,
    required this.onTap,
  });

  final Category category;
  final ModelRanking? top;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category.label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (top == null)
                const Expanded(
                  child: Center(
                    child: Text('No data', style: TextStyle(fontSize: 12)),
                  ),
                )
              else ...[
                Text(
                  top!.modelId,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(top!.providerId, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  top!.dimensions.overall.toStringAsFixed(2),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: DimensionRadar(
                    selected: top!.dimensions,
                    selectedLabel: top!.modelId,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
