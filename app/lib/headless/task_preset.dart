import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';

List<BenchmarkTask> selectTaskPreset(
  String preset,
  Iterable<BenchmarkTask> tasks,
) {
  if (preset != 'mvp') {
    throw ArgumentError.value(preset, 'preset', 'unsupported preset');
  }
  final selected =
      tasks
          .where(
            (task) =>
                task is FileBackedTask &&
                task.isFlutter &&
                task.track == BenchmarkTrack.agentic &&
                task.releaseMetadata.corpus == TaskCorpus.privateOfficial &&
                task.releaseMetadata.status == TaskReleaseStatus.active,
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(selected);
}
