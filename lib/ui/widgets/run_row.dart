import 'package:dart_arena/storage/database.dart';
import 'package:flutter/material.dart';

class RunRow extends StatelessWidget {
  const RunRow({
    super.key,
    required this.run,
    required this.taskRuns,
    required this.onTap,
    this.trailing,
  });

  final Run run;
  final List<TaskRun> taskRuns;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final title = run.name ?? 'Run ${run.id}';
    final taskCount = taskRuns.map((t) => t.taskId).toSet().length;
    final modelCount = taskRuns
        .map((t) => '${t.providerId}/${t.modelId}')
        .toSet()
        .length;
    final avg = taskRuns.isEmpty
        ? null
        : taskRuns.map((t) => t.aggregateScore).reduce((a, b) => a + b) /
              taskRuns.length;
    final ts = run.startedAt.toIso8601String();
    return ListTile(
      title: Text(title),
      subtitle: Text(
        '$ts \u00b7 $taskCount tasks \u00b7 $modelCount models'
        '${avg == null ? '' : ' \u00b7 avg ${avg.toStringAsFixed(2)}'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (run.completedAt == null)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (trailing != null) trailing!,
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
