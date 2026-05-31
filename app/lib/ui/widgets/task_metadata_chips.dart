import 'package:dart_arena/core/benchmark_task.dart';
import 'package:flutter/material.dart';

class TaskMetadataChips extends StatelessWidget {
  const TaskMetadataChips({
    super.key,
    required this.task,
    this.compact = false,
  });

  final BenchmarkTask task;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      'Category: ${task.category.label}',
      'Track: ${task.track.label}',
      'v${task.version}',
      if (task.difficulty != TaskDifficulty.unspecified)
        'Difficulty: ${task.difficulty.label}',
      ...task.tags.map((tag) => 'Tag: ${tag.label}'),
      if (task.timeout != null) '${task.timeout!.inMinutes}m timeout',
      if (task.platformRequirements.isNotEmpty)
        'Platforms: ${task.platformRequirements.map((p) => p.label).join(', ')}',
    ];
    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 2 : 4,
      children: [
        for (final label in labels)
          RawChip(
            label: Text(label),
            visualDensity: compact
                ? VisualDensity.compact
                : VisualDensity.standard,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
