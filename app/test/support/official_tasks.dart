import 'dart:io';

import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';
import 'package:path/path.dart' as p;

const officialFlutterTaskIds = [
  'accessibility.quantity_stepper_semantics',
  'async.refresh_deduplicator',
  'forms.email_validation',
  'lists.contact_search',
  'navigation.auth_redirect_race',
  'persistence.offline_feed_preferences',
  'platform.channel_mock',
  'refactor.price_label_formatter',
  'state.selection_controller',
  'ui.action_bar_overflow',
];

Directory officialFlutterTaskRoot() {
  return Directory(p.join(Directory.current.path, '..', 'tasks', 'flutter'));
}

Future<List<FileBackedTask>> loadOfficialFlutterTasks() {
  return loadFileBackedTasks(officialFlutterTaskRoot());
}

Future<FileBackedTask> loadOfficialFlutterTask(String taskId) async {
  final tasks = await loadOfficialFlutterTasks();
  final matches = tasks.where((task) => task.id == taskId).toList();
  if (matches.length == 1) return matches.single;

  final loadedIds = tasks.map((task) => task.id).join(', ');
  throw StateError(
    'Expected exactly one official Flutter task with id "$taskId", '
    'but found ${matches.length}. Loaded task ids: [$loadedIds]',
  );
}
