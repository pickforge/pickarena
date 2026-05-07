import 'dart:io';

import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'prepare succeeds for a minimal valid pubspec',
    () async {
      final root = await Directory.systemTemp.createTemp('dart_arena_prep_ok_');
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''');

      final result = await WorkdirManager(root: root).prepare(dir);
      expect(result, isA<PrepareOk>());

      root.deleteSync(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'prepare fails for a malformed pubspec',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_prep_fail_',
      );
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      File(
        p.join(dir.path, 'pubspec.yaml'),
      ).writeAsStringSync('this is not valid pubspec yaml: : :\n');

      final result = await WorkdirManager(root: root).prepare(dir);
      expect(result, isA<PrepareFailed>());
      expect((result as PrepareFailed).stderr, isNotEmpty);

      root.deleteSync(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
