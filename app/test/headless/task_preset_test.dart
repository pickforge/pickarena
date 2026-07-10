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

    final selected = await selectTaskPreset('mvp', tasks);

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

  test('mvp excludes metadata-matching tasks without admitted QA', () async {
    final root = Directory(
      p.join(Directory.current.path, '..', 'tasks', 'flutter'),
    );
    final source = (await loadFileBackedTasks(root)).first;
    final tmp = await Directory.systemTemp.createTemp('dart_arena_preset_');
    addTearDown(() => tmp.delete(recursive: true));
    final bundle = Directory(p.join(tmp.path, 'task'));
    await _copyDirectory(source.bundleDirectory, bundle);
    await File(p.join(bundle.path, 'qa', 'admission_report.json')).delete();

    final task = await FileBackedTask.load(bundle);

    expect(await selectTaskPreset('mvp', [task]), isEmpty);
  });
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await for (final entity in source.list(recursive: true)) {
    final relative = p.relative(entity.path, from: source.path);
    final target = p.join(destination.path, relative);
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
    } else if (entity is File) {
      await File(target).parent.create(recursive: true);
      await entity.copy(target);
    }
  }
}
