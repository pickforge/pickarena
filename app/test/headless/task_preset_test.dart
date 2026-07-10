import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/headless/task_preset.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('mvp selects the admitted official Flutter task metadata set', () async {
    final root = Directory(
      p.join(Directory.current.path, '..', 'tasks', 'flutter'),
    );
    final tasks = await loadFileBackedTasks(root);

    final selected = selectTaskPreset('mvp', tasks);

    expect(selected, hasLength(10));
    expect(
      selected.every(
        (task) =>
            task.isFlutter &&
            task.track == BenchmarkTrack.agentic &&
            task.releaseMetadata.corpus == TaskCorpus.privateOfficial &&
            task.releaseMetadata.status == TaskReleaseStatus.active,
      ),
      isTrue,
    );
  });
}
