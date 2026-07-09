import 'dart:async';
import 'dart:io';

import 'package:dart_arena/evaluators/evaluator_process.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'no-network policy binds host pub cache read-only',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_policy_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();
      final pubCache = Directory(p.join(root.path, 'pub-cache'))
        ..createSync(recursive: true);
      Directory(p.join(pubCache.path, 'active_roots')).createSync();

      final spec =
          await const BubblewrapGeneratedCodeSandbox(
            bwrapExecutable: 'bwrap-test',
          ).wrapProcess(
            executable: '/usr/bin/env',
            arguments: const ['true'],
            workingDirectory: workDir.path,
            environment: {'PATH': '/usr/bin:/bin', 'PUB_CACHE': pubCache.path},
            allowInternet: false,
            resourceLimits: null,
          );

      expect(spec.executable, 'bwrap-test');
      expect(spec.arguments, contains('--unshare-net'));
      expect(spec.arguments, containsAllInOrder(['--ro-bind', pubCache.path]));
      expect(
        spec.arguments,
        containsAllInOrder([
          '--bind',
          p.join(workDir.path, '.dart_arena', 'pub-cache-active-roots'),
          p.join(pubCache.path, 'active_roots'),
        ]),
      );
      expect(spec.environment['PUB_CACHE'], pubCache.path);
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'sandbox temp environment points at sandbox tmpfs',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_temp_policy_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();
      final hostTmp = Directory(p.join(root.path, 'host-tmp'))
        ..createSync(recursive: true);

      final spec =
          await const BubblewrapGeneratedCodeSandbox(
            bwrapExecutable: 'bwrap-test',
          ).wrapProcess(
            executable: '/usr/bin/env',
            arguments: const ['true'],
            workingDirectory: workDir.path,
            environment: {
              'PATH': '/usr/bin:/bin',
              'TMPDIR': hostTmp.path,
              'TMP': hostTmp.path,
              'TEMP': hostTmp.path,
            },
            allowInternet: false,
            resourceLimits: null,
          );

      expect(spec.environment['TMPDIR'], '/tmp');
      expect(spec.environment['TMP'], '/tmp');
      expect(spec.environment['TEMP'], '/tmp');
      expect(spec.arguments, containsAllInOrder(['--tmpfs', '/tmp']));
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'network-allowed policy uses workdir-local pub cache',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_network_policy_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();
      final pubCache = Directory(p.join(root.path, 'pub-cache'))
        ..createSync(recursive: true);

      final spec =
          await const BubblewrapGeneratedCodeSandbox(
            bwrapExecutable: 'bwrap-test',
          ).wrapProcess(
            executable: '/usr/bin/env',
            arguments: const ['true'],
            workingDirectory: workDir.path,
            environment: {'PATH': '/usr/bin:/bin', 'PUB_CACHE': pubCache.path},
            allowInternet: true,
            resourceLimits: null,
          );

      expect(spec.arguments, isNot(contains('--unshare-net')));
      expect(spec.arguments, isNot(contains(pubCache.path)));
      expect(
        spec.environment['PUB_CACHE'],
        p.join(workDir.path, '.dart_arena', 'pub-cache'),
      );
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'CPU policy wraps Bubblewrap with a systemd user scope',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_cpu_policy_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();

      final spec =
          await const BubblewrapGeneratedCodeSandbox(
            bwrapExecutable: 'bwrap-test',
            systemdRunExecutable: 'systemd-run-test',
          ).wrapProcess(
            executable: '/usr/bin/env',
            arguments: const ['sh', '-c', 'echo "\$\$"'],
            workingDirectory: workDir.path,
            environment: {'PATH': '/usr/bin:/bin'},
            allowInternet: false,
            resourceLimits: const SandboxResourceLimits(cpuCores: 2),
          );

      expect(spec.executable, 'systemd-run-test');
      expect(spec.arguments.take(7).toList(), [
        '--user',
        '--scope',
        '--quiet',
        '--expand-environment=no',
        '-p',
        'CPUQuota=200%',
        'bwrap-test',
      ]);
      expect(spec.arguments, contains('--unshare-net'));
      expect(spec.arguments, containsAllInOrder(['/usr/bin/env', 'sh', '-c']));
      expect(spec.arguments.last, 'echo "\$\$"');
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'extra read-only paths are mounted without binding their parent roots',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_extra_ro_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();
      final hiddenRoot = Directory(p.join(root.path, 'hidden-root'))
        ..createSync();

      final spec =
          await const BubblewrapGeneratedCodeSandbox(
            bwrapExecutable: 'bwrap-test',
          ).wrapProcess(
            executable: '/usr/bin/env',
            arguments: const ['true'],
            workingDirectory: workDir.path,
            environment: {'PATH': '/usr/bin:/bin'},
            allowInternet: false,
            resourceLimits: null,
            extraReadOnlyPaths: [hiddenRoot.path],
          );

      expect(spec.executable, 'bwrap-test');
      expect(
        spec.arguments,
        containsAllInOrder(['--ro-bind', hiddenRoot.path, hiddenRoot.path]),
      );
      expect(
        spec.arguments,
        isNot(containsAllInOrder(['--bind', root.path, root.path])),
      );
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'Flutter cache lockfile is backed by a writable sandbox-local overlay',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_flutter_cache_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();
      final flutterRoot = Directory(p.join(root.path, 'flutter'));
      Directory(p.join(flutterRoot.path, 'bin')).createSync(recursive: true);
      final cacheDir = Directory(p.join(flutterRoot.path, 'bin', 'cache'))
        ..createSync(recursive: true);
      File(p.join(flutterRoot.path, 'bin', 'flutter')).writeAsStringSync('');
      File(p.join(cacheDir.path, 'engine.realm')).writeAsStringSync('stable');
      File(p.join(cacheDir.path, 'dart-sdk.stamp')).writeAsStringSync('sdk');

      final spec =
          await const BubblewrapGeneratedCodeSandbox(
            bwrapExecutable: 'bwrap-test',
          ).wrapProcess(
            executable: p.join(flutterRoot.path, 'bin', 'flutter'),
            arguments: const ['--version'],
            workingDirectory: workDir.path,
            environment: {'PATH': '/usr/bin:/bin'},
            allowInternet: false,
            resourceLimits: null,
          );

      final overlayDir = p.join(
        workDir.path,
        '.dart_arena',
        'flutter-cache-files',
      );
      final lockfileOverlay = p.join(overlayDir, 'lockfile');
      expect(File(lockfileOverlay).existsSync(), isTrue);
      expect(
        spec.arguments,
        containsAllInOrder([
          '--bind',
          lockfileOverlay,
          p.join(cacheDir.path, 'lockfile'),
        ]),
      );
      expect(
        spec.arguments,
        containsAllInOrder([
          '--bind',
          p.join(overlayDir, 'engine.realm'),
          p.join(cacheDir.path, 'engine.realm'),
        ]),
      );
      expect(
        spec.arguments,
        containsAllInOrder([
          '--bind',
          p.join(overlayDir, 'dart-sdk.stamp'),
          p.join(cacheDir.path, 'dart-sdk.stamp'),
        ]),
      );
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'evaluator process runs inside Bubblewrap without host file access',
    () async {
      await _skipUnlessBubblewrapAvailable();
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_eval_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();
      final secret = File(p.join(root.path, 'secret.txt'))
        ..writeAsStringSync('secret');
      final outsideWrite = p.join(root.path, 'outside.txt');
      final tool = File(p.join(workDir.path, 'probe.sh'));
      await tool.writeAsString('''
#!/bin/sh
set -eu
if [ -e "\$SECRET_PATH" ]; then
  echo leaked
  exit 2
fi
printf ok > inside.txt
printf bad > "\$OUTSIDE_WRITE" 2>/dev/null || true
echo sandbox-ok
''');
      final chmod = await Process.run('chmod', ['+x', tool.path]);
      expect(chmod.exitCode, 0, reason: chmod.stderr.toString());

      final result = await runEvaluatorProcess(
        tool.path,
        const [],
        workingDirectory: workDir.path,
        environment: {
          'PATH': '/usr/bin:/bin',
          'HOME': workDir.path,
          'SECRET_PATH': secret.path,
          'OUTSIDE_WRITE': outsideWrite,
        },
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
        allowInternet: false,
        timeout: const Duration(seconds: 5),
      );

      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('sandbox-ok'));
      expect(File(p.join(workDir.path, 'inside.txt')).readAsStringSync(), 'ok');
      expect(File(outsideWrite).existsSync(), isFalse);
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'evaluator process cannot reach loopback when network is disabled',
    () async {
      await _skipUnlessBubblewrapAvailable();
      await _skipUnlessExecutableAvailable('python3');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_net_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();

      final result = await runEvaluatorProcess(
        'python3',
        [
          '-c',
          '''
import socket
try:
    socket.create_connection(("127.0.0.1", ${server.port}), timeout=1.0)
except OSError:
    print("network-blocked")
    raise SystemExit(0)
print("network-reachable")
raise SystemExit(4)
''',
        ],
        workingDirectory: workDir.path,
        environment: {'PATH': '/usr/bin:/bin', 'HOME': workDir.path},
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
        allowInternet: false,
        timeout: const Duration(seconds: 5),
      );

      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('network-blocked'));
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'evaluator process can reach loopback when network is allowed',
    () async {
      await _skipUnlessBubblewrapAvailable();
      await _skipUnlessExecutableAvailable('python3');
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(
        server.first.then((socket) async {
          socket.write('ok');
          await socket.close();
        }),
      );
      addTearDown(() async {
        await server.close();
      });
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_net_allowed_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();

      final result = await runEvaluatorProcess(
        'python3',
        [
          '-c',
          '''
import socket
s = socket.create_connection(("127.0.0.1", ${server.port}), timeout=2.0)
data = s.recv(128)
if b"ok" not in data:
    raise SystemExit(5)
print("network-reachable")
''',
        ],
        workingDirectory: workDir.path,
        environment: {'PATH': '/usr/bin:/bin', 'HOME': workDir.path},
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
        allowInternet: true,
        timeout: const Duration(seconds: 5),
      );

      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('network-reachable'));
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'evaluator process uses private temp and read-only system binds',
    () async {
      await _skipUnlessBubblewrapAvailable();
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_mounts_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();
      final hostTmpProbe = p.join(
        '/tmp',
        'dart_arena_bwrap_tmp_${pid}_${DateTime.now().microsecondsSinceEpoch}',
      );
      addTearDown(() async {
        final probe = File(hostTmpProbe);
        if (await probe.exists()) await probe.delete();
      });
      final hostEtcProbe = File('/etc/dart_arena_bwrap_write_probe');

      final result = await runEvaluatorProcess(
        'sh',
        [
          '-c',
          '''
set -eu
printf inside > "\$HOST_TMP_PROBE"
if [ "\$(cat "\$HOST_TMP_PROBE")" != inside ]; then
  exit 4
fi
if printf bad > /etc/dart_arena_bwrap_write_probe 2>/dev/null; then
  echo etc-writable
  exit 5
fi
echo private-temp-read-only-system
''',
        ],
        workingDirectory: workDir.path,
        environment: {
          'PATH': '/usr/bin:/bin',
          'HOME': workDir.path,
          'HOST_TMP_PROBE': hostTmpProbe,
        },
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
        allowInternet: false,
        timeout: const Duration(seconds: 5),
      );

      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('private-temp-read-only-system'));
      expect(File(hostTmpProbe).existsSync(), isFalse);
      expect(hostEtcProbe.existsSync(), isFalse);
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'evaluator process enforces process count inside Bubblewrap',
    () async {
      await _skipUnlessBubblewrapAvailable();
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_process_limit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();

      final result = await runEvaluatorProcess(
        'sh',
        const ['-c', 'sleep 10 & sleep 10 & wait'],
        workingDirectory: workDir.path,
        environment: {'PATH': '/usr/bin:/bin', 'HOME': workDir.path},
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
        allowInternet: false,
        timeout: const Duration(seconds: 5),
        maxProcesses: 1,
      );

      final reason =
          'stdout=${result.stdout} stderr=${result.stderr} '
          'timedOut=${result.timedOut} processLimit=${result.processLimitExceeded}';
      expect(result.exitCode, -1, reason: reason);
      expect(result.processLimitExceeded, isTrue, reason: reason);
      expect(result.observedProcessCount, greaterThan(1));
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'evaluator process runs through CPU cgroup wrapper inside Bubblewrap',
    () async {
      await _skipUnlessBubblewrapAvailable();
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_cpu_process_limit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();

      final result = await runEvaluatorProcess(
        'sh',
        const ['-c', 'echo cpu-cgroup-bwrap-ok'],
        workingDirectory: workDir.path,
        environment: {'PATH': '/usr/bin:/bin', 'HOME': workDir.path},
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
        allowInternet: false,
        timeout: const Duration(seconds: 5),
        maxCpuCores: 1,
      );

      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('cpu-cgroup-bwrap-ok'));
      expect(result.stderr, isEmpty);
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'evaluator process enforces output limit inside Bubblewrap',
    () async {
      await _skipUnlessBubblewrapAvailable();
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_output_limit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();

      final result = await runEvaluatorProcess(
        'sh',
        const ['-c', 'while :; do printf 0123456789; done'],
        workingDirectory: workDir.path,
        environment: {'PATH': '/usr/bin:/bin', 'HOME': workDir.path},
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
        allowInternet: false,
        timeout: const Duration(seconds: 5),
        maxOutputChars: 128,
      );

      expect(result.exitCode, -1);
      expect(result.outputLimitExceeded, isTrue);
      expect(result.stdout.length, 128);
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );

  test(
    'evaluator process enforces memory limit inside Bubblewrap',
    () async {
      await _skipUnlessBubblewrapAvailable();
      await _skipUnlessExecutableAvailable('python3');
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_bwrap_memory_limit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final workDir = Directory(p.join(root.path, 'work'))..createSync();

      final result = await runEvaluatorProcess(
        'python3',
        const [
          '-c',
          '''
import time
chunks = []
while True:
    chunks.append(bytearray(1024 * 1024))
    time.sleep(0.01)
''',
        ],
        workingDirectory: workDir.path,
        environment: {'PATH': '/usr/bin:/bin', 'HOME': workDir.path},
        generatedCodeSandbox: const BubblewrapGeneratedCodeSandbox(),
        allowInternet: false,
        timeout: const Duration(seconds: 10),
        maxMemoryMb: 48,
      );

      expect(result.exitCode, -1);
      expect(result.memoryLimitExceeded, isTrue);
      expect(result.observedMemoryMb, greaterThan(48));
    },
    skip: Platform.isLinux ? false : 'Bubblewrap is Linux-only',
  );
}

Future<void> _skipUnlessBubblewrapAvailable() async {
  try {
    await BubblewrapGeneratedCodeSandbox.ensureAvailable();
  } on Object catch (error) {
    markTestSkipped(error.toString());
  }
}

Future<void> _skipUnlessExecutableAvailable(String executable) async {
  final result = await Process.run('sh', [
    '-c',
    'command -v "\$1"',
    'sh',
    executable,
  ]);
  if (result.exitCode != 0) {
    markTestSkipped('$executable is not available');
  }
}
