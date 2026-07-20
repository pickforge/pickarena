import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/runner/bounded_subprocess.dart';
import 'package:test/test.dart';

void main() {
  test(
    'propagates missing absolute and PATH executable spawn failures',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'dart_arena_subprocess_missing_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final missingAbsolute = '${temp.path}/missing-command';

      for (final executable in [missingAbsolute, 'missing-path-command']) {
        await expectLater(
          runBoundedSubprocess(
            executable: executable,
            arguments: const ['argument'],
            workingDirectory: temp.path,
            environment: {'PATH': temp.path},
            maxOutputBytes: 128,
            timeout: const Duration(seconds: 2),
          ),
          throwsA(
            isA<ProcessException>().having(
              (error) => error.executable,
              'executable',
              executable,
            ),
          ),
        );
      }
    },
    skip: Platform.isWindows,
  );

  test(
    'propagates a missing shebang interpreter as an exec failure',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'dart_arena_subprocess_shebang_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final script = await _writeFile(
        temp,
        'missing-interpreter',
        '#!/definitely/missing/interpreter\nexit 0\n',
        executable: true,
      );

      await expectLater(
        runBoundedSubprocess(
          executable: script.path,
          arguments: const [],
          workingDirectory: temp.path,
          environment: const {'PATH': '/usr/bin:/bin'},
          maxOutputBytes: 128,
          timeout: const Duration(seconds: 2),
        ),
        throwsA(
          isA<ProcessException>()
              .having((error) => error.executable, 'executable', script.path)
              .having((error) => error.errorCode, 'errorCode', 2),
        ),
      );
    },
    skip: !Platform.isLinux,
  );

  test(
    'propagates a non-executable target as an exec failure',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'dart_arena_subprocess_permissions_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final script = await _writeFile(
        temp,
        'non-executable',
        '#!/bin/sh\nexit 0\n',
      );

      await expectLater(
        runBoundedSubprocess(
          executable: script.path,
          arguments: const [],
          workingDirectory: temp.path,
          environment: const {'PATH': '/usr/bin:/bin'},
          maxOutputBytes: 128,
          timeout: const Duration(seconds: 2),
        ),
        throwsA(
          isA<ProcessException>()
              .having((error) => error.executable, 'executable', script.path)
              .having((error) => error.errorCode, 'errorCode', 13),
        ),
      );
    },
    skip: !Platform.isLinux,
  );

  test(
    'uses execvp permission precedence across PATH candidates',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'dart_arena_subprocess_path_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final blocked = Directory('${temp.path}/blocked')..createSync();
      final runnable = Directory('${temp.path}/runnable')..createSync();
      await _writeFile(blocked, 'candidate', '#!/bin/sh\nexit 1\n');
      await _writeFile(
        runnable,
        'candidate',
        '#!/bin/sh\nprintf fallback\n',
        executable: true,
      );

      final result = await runBoundedSubprocess(
        executable: 'candidate',
        arguments: const [],
        workingDirectory: temp.path,
        environment: {'PATH': '${blocked.path}:${runnable.path}'},
        maxOutputBytes: 128,
        timeout: const Duration(seconds: 2),
      );

      expect(result.termination, BoundedSubprocessTermination.exited);
      expect(result.exitCode, 0);
      expect(result.stdout, 'fallback');
    },
    skip: !Platform.isLinux,
  );

  test(
    'preserves the exact target environment across the launcher',
    () async {
      final result = await runBoundedSubprocess(
        executable: '/usr/bin/env',
        arguments: const [],
        workingDirectory: Directory.current.path,
        environment: const {'ONLY_TARGET_VALUE': 'preserved'},
        includeParentEnvironment: false,
        maxOutputBytes: 128,
        timeout: const Duration(seconds: 2),
      );

      expect(result.termination, BoundedSubprocessTermination.exited);
      expect(result.exitCode, 0);
      expect(result.stdout, 'ONLY_TARGET_VALUE=preserved\n');
    },
    skip: !Platform.isLinux,
  );

  test(
    'keeps legitimate target exits 126 and 127 as ordinary exits',
    () async {
      for (final exitCode in const [126, 127]) {
        final result = await _runShell(
          'exit $exitCode',
          maxOutputBytes: 128,
          timeout: const Duration(seconds: 2),
        );

        expect(result.termination, BoundedSubprocessTermination.exited);
        expect(result.exitCode, exitCode);
      }
    },
    skip: !Platform.isLinux,
  );

  test(
    'drains stdout and stderr concurrently without backpressure hangs',
    () async {
      final result = await _runShell(
        r'''
(head -c 1048576 /dev/zero | tr '\0' o) &
(head -c 1048576 /dev/zero | tr '\0' e >&2) &
wait
''',
        maxOutputBytes: 2 * 1024 * 1024,
        timeout: const Duration(seconds: 5),
      );

      expect(result.termination, BoundedSubprocessTermination.exited);
      expect(result.exitCode, 0);
      expect(result.stdout.length, 1024 * 1024);
      expect(result.stderr.length, 1024 * 1024);
    },
    skip: Platform.isWindows,
  );

  test(
    'bounds finite excess output regardless of exit arbitration',
    () async {
      final result = await _runShell(
        'head -c 4096 /dev/zero | tr \'\\0\' x',
        maxOutputBytes: 128,
        timeout: const Duration(seconds: 5),
      );

      expect(
        result.termination,
        anyOf(
          BoundedSubprocessTermination.exited,
          BoundedSubprocessTermination.outputLimitExceeded,
        ),
      );
      expect(result.stdoutLimitExceeded, isTrue);
      expect(result.stdout.length, 128);
    },
    skip: Platform.isWindows,
  );

  test(
    'preserves character-based adapter limits within a raw-byte bound',
    () async {
      final result = await runBoundedSubprocess(
        executable: 'sh',
        arguments: const [
          '-c',
          r"printf '\342\230\203\342\230\203\342\230\203\342\230\203\342\230\203'",
        ],
        workingDirectory: Directory.current.path,
        environment: {'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin'},
        maxOutputBytes: maxEncodedOutputBytes(4),
        maxOutputCharacters: 4,
        timeout: const Duration(seconds: 5),
      );

      expect(result.stdoutLimitExceeded, isTrue);
      expect(result.stdout, '☃☃☃☃');
      expect(utf8.encode(result.stdout).length, 12);
    },
    skip: Platform.isWindows,
  );

  test(
    'keeps readable multibyte text when capture ends mid-sequence',
    () async {
      final result = await _runShell(
        r"printf '\342\230\203\342\230\203'",
        maxOutputBytes: 4,
        timeout: const Duration(seconds: 5),
      );

      expect(result.stdout, startsWith('☃'));
      expect(result.stdout, endsWith('�'));
    },
    skip: Platform.isWindows,
  );

  test(
    'retains an observed external limit when process exit wins',
    () async {
      const observedLimit = 'process-limit';
      final signal = Completer<Object>();
      final result = await runBoundedSubprocess(
        executable: 'sh',
        arguments: const ['-c', 'exit 0'],
        workingDirectory: Directory.current.path,
        environment: {'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin'},
        maxOutputBytes: 128,
        timeout: const Duration(seconds: 5),
        monitor: (_) => BoundedSubprocessMonitor(
          signal: signal.future,
          observed: () => observedLimit,
          dispose: () {},
        ),
      );

      expect(result.termination, BoundedSubprocessTermination.exited);
      expect(result.externalLimit, observedLimit);
    },
    skip: Platform.isWindows,
  );

  test(
    'an already-expired timeout takes precedence over cancellation',
    () async {
      final cancellation = Completer<void>()..complete();
      final result = await _runShell(
        'sleep 20',
        maxOutputBytes: 128,
        timeout: Duration.zero,
        cancellationSignal: cancellation.future,
      );

      expect(result.termination, BoundedSubprocessTermination.timedOut);
    },
    skip: Platform.isWindows,
  );

  test(
    'cancellation takes precedence over a subsequent output flood',
    () async {
      final cancellation = Completer<void>()..complete();
      final result = await _runShell(
        'while :; do printf xxxxxxxxxxxxxxxx; done',
        maxOutputBytes: 128,
        timeout: const Duration(seconds: 5),
        cancellationSignal: cancellation.future,
      );

      expect(result.termination, BoundedSubprocessTermination.cancelled);
    },
    skip: Platform.isWindows,
  );

  test(
    'cleans up descendants that keep streams open after parent exit',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'dart_arena_subprocess_drain_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final pidFile = File('${temp.path}/child.pid');
      final stopwatch = Stopwatch()..start();

      final result = await _runShell(
        'sleep 20 & echo \$! > \'${pidFile.path}\'; exit 0',
        maxOutputBytes: 128,
        timeout: const Duration(seconds: 5),
      );
      stopwatch.stop();

      expect(result.termination, BoundedSubprocessTermination.exited);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      final pid = int.parse((await pidFile.readAsString()).trim());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await _pidIsRunning(pid), isFalse);
    },
    skip: Platform.isWindows,
  );

  test(
    'does not direct-signal a root whose exit code already completed',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'dart_arena_subprocess_reaped_root_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final pidFile = File('${temp.path}/child.pid');
      final monitorSignal = Completer<Object>();
      final sentSignals = <({int pid, ProcessSignal? signal})>[];
      int? rootPid;

      final result = await _runShell(
        "sleep 20 & echo \$! > '${pidFile.path}'; exit 0",
        maxOutputBytes: 128,
        timeout: const Duration(seconds: 5),
        monitor: (pid) {
          rootPid = pid;
          return BoundedSubprocessMonitor(
            signal: monitorSignal.future,
            observed: () => null,
            dispose: () {},
          );
        },
        signalSender: (pid, signal) {
          sentSignals.add((pid: pid, signal: signal));
          try {
            return signal == null
                ? Process.killPid(pid)
                : Process.killPid(pid, signal);
          } on Object {
            return false;
          }
        },
      );

      expect(result.termination, BoundedSubprocessTermination.exited);
      expect(rootPid, isNotNull);
      expect(
        sentSignals,
        contains((pid: -rootPid!, signal: ProcessSignal.sigterm)),
      );
      expect(sentSignals.where((sent) => sent.pid > 0), isEmpty);
      final childPid = int.parse((await pidFile.readAsString()).trim());
      expect(await _pidIsRunning(childPid), isFalse);
    },
    skip: Platform.isWindows,
  );

  test(
    'escalates to KILL when both root and child ignore TERM',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'dart_arena_subprocess_kill_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final pidFile = File('${temp.path}/child.pid');
      final sentSignals = <({int pid, ProcessSignal? signal})>[];

      final result = await _runShell(
        "trap '' TERM; sh -c 'trap \"\" TERM; echo \$\$ > \"${pidFile.path}\"; while :; do sleep 1; done' & while [ ! -s '${pidFile.path}' ]; do sleep 0.01; done; wait",
        maxOutputBytes: 128,
        timeout: const Duration(milliseconds: 200),
        signalSender: (pid, signal) {
          sentSignals.add((pid: pid, signal: signal));
          return _sendSignal(pid, signal);
        },
      );

      expect(result.termination, BoundedSubprocessTermination.timedOut);
      expect(
        sentSignals.any((sent) => sent.signal == ProcessSignal.sigkill),
        isTrue,
      );
      final pid = int.parse((await pidFile.readAsString()).trim());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await _pidIsRunning(pid), isFalse);
    },
    skip: Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'kills a TERM-ignoring descendant that escapes the root session',
    () async {
      final setsid = _setsidPath();
      if (setsid == null) return;
      final temp = await Directory.systemTemp.createTemp(
        'dart_arena_subprocess_escaped_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final pidFile = File('${temp.path}/child.pid');
      final sentSignals = <({int pid, ProcessSignal? signal})>[];

      final result = await _runShell(
        "trap '' TERM; '$setsid' sh -c 'trap \"\" TERM; echo \$\$ > \"${pidFile.path}\"; while :; do sleep 1; done' & while [ ! -s '${pidFile.path}' ]; do sleep 0.01; done; wait",
        maxOutputBytes: 128,
        timeout: const Duration(milliseconds: 200),
        signalSender: (pid, signal) {
          sentSignals.add((pid: pid, signal: signal));
          return _sendSignal(pid, signal);
        },
      );

      expect(result.termination, BoundedSubprocessTermination.timedOut);
      final pid = int.parse((await pidFile.readAsString()).trim());
      expect(sentSignals, contains((pid: pid, signal: ProcessSignal.sigkill)));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await _pidIsRunning(pid), isFalse);
    },
    skip: Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 8)),
  );
}

Future<File> _writeFile(
  Directory directory,
  String name,
  String contents, {
  bool executable = false,
}) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString(contents);
  if (executable) {
    final chmod = await Process.run('chmod', ['+x', file.path]);
    expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  }
  return file;
}

Future<BoundedSubprocessResult> _runShell(
  String command, {
  required int maxOutputBytes,
  required Duration timeout,
  Future<void>? cancellationSignal,
  BoundedSubprocessMonitorFactory? monitor,
  BoundedSubprocessSignalSender? signalSender,
}) {
  return runBoundedSubprocess(
    executable: 'sh',
    arguments: ['-c', command],
    workingDirectory: Directory.current.path,
    environment: {'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin'},
    maxOutputBytes: maxOutputBytes,
    timeout: timeout,
    cancellationSignal: cancellationSignal,
    monitor: monitor,
    signalSender: signalSender ?? _sendSignal,
  );
}

bool _sendSignal(int pid, ProcessSignal? signal) {
  try {
    return signal == null ? Process.killPid(pid) : Process.killPid(pid, signal);
  } on Object {
    return false;
  }
}

String? _setsidPath() {
  for (final path in const ['/usr/bin/setsid', '/bin/setsid']) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

Future<bool> _pidIsRunning(int pid) async {
  final result = await Process.run('ps', ['-p', '$pid', '-o', 'stat=']);
  if (result.exitCode != 0) return false;
  final state = result.stdout.toString().trim();
  return state.isNotEmpty && !state.startsWith('Z');
}
