import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/run_row.dart';
import 'package:flutter/material.dart';

class RecentRunsStrip extends StatelessWidget {
  const RecentRunsStrip({
    super.key,
    required this.runs,
    required this.onTapRow,
    required this.onViewAll,
    this.maxRows = 5,
  });

  final List<(Run, List<TaskRun>)> runs;
  final ValueChanged<Run> onTapRow;
  final VoidCallback onViewAll;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Text(
                'Recent runs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(onPressed: onViewAll, child: const Text('View all')),
            ],
          ),
        ),
        if (runs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No runs yet — start one with the New Run button.'),
          )
        else
          for (final r in runs.take(maxRows))
            RunRow(run: r.$1, taskRuns: r.$2, onTap: () => onTapRow(r.$1)),
      ],
    );
  }
}
