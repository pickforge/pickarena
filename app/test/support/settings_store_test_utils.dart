import 'dart:io';

import 'package:dart_arena/storage/file_settings_store.dart';
import 'package:test/test.dart';

Future<FileSettingsStore> newFileSettingsStore({
  Map<String, String> environment = const {},
}) async {
  final dir = await Directory.systemTemp.createTemp(
    'dart_arena_settings_test_',
  );
  addTearDown(() => dir.delete(recursive: true));
  return FileSettingsStore(
    path: '${dir.path}/settings.json',
    environment: environment,
  );
}

Future<({Directory dir, String path})> newSettingsFilePath() async {
  final dir = await Directory.systemTemp.createTemp(
    'dart_arena_settings_test_',
  );
  addTearDown(() => dir.delete(recursive: true));
  return (dir: dir, path: '${dir.path}/settings.json');
}
