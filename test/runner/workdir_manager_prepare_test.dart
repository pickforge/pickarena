import 'dart:async';
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

  test(
    'prepare kills pub get when remaining timeout expires',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_prep_timeout_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dir = Directory(p.join(root.path, 'pkg'))..createSync();
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
      final marker = File(p.join(root.path, 'marker.txt'));
      final fakeDart = await _writeHangingExecutable(root, marker);
      final manager = WorkdirManager(root: root, dartExecutable: fakeDart.path);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        manager.prepare(
          dir,
          remainingTimeout: () => const Duration(milliseconds: 120),
        ),
        throwsA(isA<TimeoutException>()),
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(marker.readAsStringSync(), contains('started'));
      expect(marker.readAsStringSync(), isNot(contains('done')));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 5)),
  );
}

Future<File> _writeHangingExecutable(Directory root, File marker) async {
  final script = File(p.join(root.path, 'fake_dart.sh'));
  await script.writeAsString('''
#!/bin/sh
echo started >> '${marker.path}'
sleep 20
echo done >> '${marker.path}'
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}
