import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/headless/headless_cli_config.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';

Future<List<BenchmarkTask>> selectTaskPreset(
  String preset,
  Iterable<BenchmarkTask> tasks,
) async {
  if (preset != 'mvp') {
    throw HeadlessCliConfigException('unknown preset: $preset, expected: mvp');
  }
  final selected = <BenchmarkTask>[];
  for (final task in tasks) {
    if (task is! FileBackedTask ||
        !task.isFlutter ||
        task.track != BenchmarkTrack.agentic ||
        task.releaseMetadata.corpus != TaskCorpus.privateOfficial ||
        task.releaseMetadata.status != TaskReleaseStatus.active ||
        !await task.bundleInspection.hasAdmittedQaReport(
          taskId: task.id,
          taskVersion: task.version,
          track: task.track.name,
        )) {
      continue;
    }
    selected.add(task);
  }
  selected.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(selected);
}
