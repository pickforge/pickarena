import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/headless/headless_cli_config.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';

List<BenchmarkTask> selectTaskPreset(
  String preset,
  Iterable<BenchmarkTask> tasks,
) {
  if (preset != 'mvp') {
    throw HeadlessCliConfigException('unknown preset: $preset, expected: mvp');
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
