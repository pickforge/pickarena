import 'dart:async';
import 'dart:io';

import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:test/test.dart';
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

  test(
    'prepare does not retry online pub get when network is disabled',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_prep_no_network_',
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
      final invocations = File(p.join(root.path, 'invocations.txt'));
      final fakeDart = await _writeFailingPubExecutable(root, invocations);
      final manager = WorkdirManager(root: root, dartExecutable: fakeDart.path);

      final result = await manager.prepare(dir, allowInternet: false);

      expect(result, isA<PrepareFailed>());
      expect((result as PrepareFailed).stderr, contains('network access'));
      expect(invocations.readAsLinesSync(), ['pub get --offline']);
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
  );

  test(
    'prepare isolates home and user config environment',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_prep_isolated_home_',
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
      final envFile = File(p.join(root.path, 'env.txt'));
      final fakeDart = await _writeEnvDumpExecutable(root, envFile);
      final manager = WorkdirManager(root: root, dartExecutable: fakeDart.path);

      final result = await manager.prepare(dir);

      expect(result, isA<PrepareOk>());
      final env = await envFile.readAsString();
      expect(env, contains('HOME=${dir.path}'));
      expect(env, contains('USERPROFILE=${dir.path}'));
      expect(env, contains('XDG_CONFIG_HOME=${p.join(dir.path, '.config')}'));
      expect(env, contains('XDG_CACHE_HOME=${p.join(dir.path, '.cache')}'));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
  );

  test(
    'prepare terminates output-flooding pub get without retrying online',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_prep_output_flood_',
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
      final invocations = File(p.join(root.path, 'invocations.txt'));
      final fakeDart = await _writeFloodingPubExecutable(root, invocations);
      final manager = WorkdirManager(
        root: root,
        dartExecutable: fakeDart.path,
        prepareMaxOutputChars: 128,
      );

      final result = await manager.prepare(dir);

      expect(result, isA<PrepareFailed>());
      expect(
        (result as PrepareFailed).stderr,
        contains('prepare output exceeded 128 characters'),
      );
      expect(invocations.readAsLinesSync(), ['pub get --offline']);
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'prepare retries online pub get when network is enabled',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_prep_network_',
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
      final invocations = File(p.join(root.path, 'invocations.txt'));
      final fakeDart = await _writeFailingPubExecutable(root, invocations);
      final manager = WorkdirManager(root: root, dartExecutable: fakeDart.path);

      final result = await manager.prepare(dir);

      expect(result, isA<PrepareFailed>());
      expect(invocations.readAsLinesSync(), ['pub get --offline', 'pub get']);
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
  );

  test(
    'prepare can run a minimal package through Bubblewrap',
    () async {
      if (!await _skipUnlessBubblewrapAvailable()) return;
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_prep_bwrap_',
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

      final result = await WorkdirManager(root: root).prepare(
        dir,
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
      );

      expect(result, isA<PrepareOk>());
      expect(File(p.join(dir.path, 'pubspec.lock')).existsSync(), isTrue);
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
    timeout: const Timeout(Duration(minutes: 2)),
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

Future<File> _writeFailingPubExecutable(
  Directory root,
  File invocations,
) async {
  final script = File(p.join(root.path, 'fake_pub.sh'));
  await script.writeAsString('''
#!/bin/sh
printf '%s\\n' "\$*" >> '${invocations.path}'
if [ "\$3" = "--offline" ]; then
  echo offline failed >&2
  exit 69
fi
echo online failed >&2
exit 70
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}

Future<File> _writeEnvDumpExecutable(Directory root, File envFile) async {
  final script = File(p.join(root.path, 'fake_pub_env.sh'));
  await script.writeAsString('''
#!/bin/sh
env > '${envFile.path}'
exit 0
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}

Future<File> _writeFloodingPubExecutable(
  Directory root,
  File invocations,
) async {
  final script = File(p.join(root.path, 'fake_pub_flood.sh'));
  await script.writeAsString('''
#!/bin/sh
printf '%s\\n' "\$*" >> '${invocations.path}'
while :; do
  printf '0123456789abcdef0123456789abcdef\\n'
done
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}

Future<bool> _skipUnlessBubblewrapAvailable() async {
  try {
    await BubblewrapGeneratedCodeSandbox.ensureAvailable();
  } on Object catch (error) {
    markTestSkipped(error.toString());
    return false;
  }
  final probe = await Process.run('bwrap', const [
    '--ro-bind',
    '/',
    '/',
    '--unshare-pid',
    '--unshare-ipc',
    '--unshare-net',
    '/bin/true',
  ], runInShell: false);
  if (probe.exitCode != 0) {
    markTestSkipped(
      'bwrap functional probe failed with exit code ${probe.exitCode}',
    );
    return false;
  }
  return true;
}
