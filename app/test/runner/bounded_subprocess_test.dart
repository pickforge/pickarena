import 'dart:async';
import 'dart:io';

import 'package:dart_arena/runner/bounded_subprocess.dart';
import 'package:test/test.dart';

void main() {
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
    'escalates from TERM to KILL for an unresponsive process group',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'dart_arena_subprocess_kill_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final pidFile = File('${temp.path}/child.pid');

      final result = await _runShell(
        "trap '' TERM; sleep 20 & echo \$! > '${pidFile.path}'; wait",
        maxOutputBytes: 128,
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.termination, BoundedSubprocessTermination.timedOut);
      final pid = int.parse((await pidFile.readAsString()).trim());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await _pidIsRunning(pid), isFalse);
    },
    skip: Platform.isWindows,
  );
}

Future<BoundedSubprocessResult> _runShell(
  String command, {
  required int maxOutputBytes,
  required Duration timeout,
  Future<void>? cancellationSignal,
}) {
  return runBoundedSubprocess(
    executable: 'sh',
    arguments: ['-c', command],
    workingDirectory: Directory.current.path,
    environment: {'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin'},
    maxOutputBytes: maxOutputBytes,
    timeout: timeout,
    cancellationSignal: cancellationSignal,
  );
}

Future<bool> _pidIsRunning(int pid) async {
  final result = await Process.run('ps', ['-p', '$pid', '-o', 'stat=']);
  if (result.exitCode != 0) return false;
  final state = result.stdout.toString().trim();
  return state.isNotEmpty && !state.startsWith('Z');
}
