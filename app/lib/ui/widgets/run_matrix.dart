import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/task_metadata_chips.dart';
import 'package:flutter/material.dart';

typedef RunMatrixCellTap = void Function(TaskRun taskRun);

class RunMatrix extends StatelessWidget {
  const RunMatrix({
    super.key,
    required this.taskRuns,
    required this.onCellTap,
    this.taskById = const {},
  });

  final List<TaskRun> taskRuns;
  final RunMatrixCellTap onCellTap;
  final Map<String, BenchmarkTask> taskById;

  List<String> get _taskIds {
    final seen = <String>{};
    final out = <String>[];
    for (final tr in taskRuns) {
      if (seen.add(tr.taskId)) out.add(tr.taskId);
    }
    return out;
  }

  List<String> get _columnKeys {
    final seen = <String>{};
    final out = <String>[];
    for (final tr in taskRuns) {
      final k = '${tr.providerId}/${tr.modelId}';
      if (seen.add(k)) out.add(k);
    }
    return out;
  }

  Color _tint(double s) {
    if (s >= 0.8) return Colors.green.withValues(alpha: 0.25);
    if (s >= 0.5) return Colors.orange.withValues(alpha: 0.25);
    return Colors.red.withValues(alpha: 0.25);
  }

  TaskRun? _cell(String taskId, String columnKey) {
    for (final tr in taskRuns) {
      if (tr.taskId == taskId &&
          '${tr.providerId}/${tr.modelId}' == columnKey) {
        return tr;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final taskIds = _taskIds;
    final columns = _columnKeys;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Task')),
            ...columns.map((c) => DataColumn(label: Text(c))),
          ],
          rows: [
            for (final taskId in taskIds)
              DataRow(
                cells: [
                  DataCell(_TaskCell(taskId: taskId, task: taskById[taskId])),
                  ...columns.map((c) {
                    final tr = _cell(taskId, c);
                    if (tr == null) {
                      return const DataCell(Text('\u2014'));
                    }
                    return DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _tint(tr.aggregateScore),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tr.aggregateScore.toStringAsFixed(2)),
                      ),
                      onTap: () => onCellTap(tr),
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskCell extends StatelessWidget {
  const _TaskCell({required this.taskId, required this.task});

  final String taskId;
  final BenchmarkTask? task;

  @override
  Widget build(BuildContext context) {
    final task = this.task;
    if (task == null) return Text(taskId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(taskId),
          TaskMetadataChips(task: task, compact: true),
        ],
      ),
    );
  }
}
