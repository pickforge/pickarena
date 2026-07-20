import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_arena/runner/subprocess_environment.dart';

enum BoundedSubprocessTermination {
  exited,
  timedOut,
  cancelled,
  outputLimitExceeded,
  externalLimitExceeded,
}

enum BoundedSubprocessCapture { leading, trailing }

class BoundedSubprocessResult {
  const BoundedSubprocessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.termination,
    required this.stdoutLimitExceeded,
    required this.stderrLimitExceeded,
    this.externalLimit,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
  final BoundedSubprocessTermination termination;
  final bool stdoutLimitExceeded;
  final bool stderrLimitExceeded;
  final Object? externalLimit;

  bool get outputLimitExceeded =>
      termination == BoundedSubprocessTermination.outputLimitExceeded;
}

class BoundedSubprocessMonitor {
  const BoundedSubprocessMonitor({
    required this.signal,
    required this.observed,
    required this.dispose,
  });

  final Future<Object> signal;
  final Object? Function() observed;
  final void Function() dispose;
}

typedef BoundedSubprocessMonitorFactory =
    BoundedSubprocessMonitor Function(int pid);

Future<BoundedSubprocessResult> runBoundedSubprocess({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
  required Map<String, String> environment,
  required int maxOutputBytes,
  bool includeParentEnvironment = false,
  Duration? timeout,
  Future<void>? cancellationSignal,
  BoundedSubprocessCapture capture = BoundedSubprocessCapture.leading,
  List<int>? stdinBytes,
  Map<String, String>? helperEnvironment,
  BoundedSubprocessMonitorFactory? monitor,
}) async {
  assert(maxOutputBytes > 0);
  final startsProcessGroup =
      Platform.isLinux && File('/usr/bin/setsid').existsSync();
  final process = await Process.start(
    startsProcessGroup ? '/usr/bin/setsid' : executable,
    startsProcessGroup ? ['--wait', executable, ...arguments] : arguments,
    workingDirectory: workingDirectory,
    runInShell: false,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
  );
  final stdout = _BoundedByteCollector(maxOutputBytes, capture);
  final stderr = _BoundedByteCollector(maxOutputBytes, capture);
  final outputLimitExceeded = Completer<_SubprocessSignal>();

  void collect(_BoundedByteCollector collector, List<int> chunk) {
    collector.add(chunk);
    if (collector.exceeded && !outputLimitExceeded.isCompleted) {
      outputLimitExceeded.complete(const _OutputLimitExceeded());
    }
  }

  final stdoutSubscription = process.stdout.listen(
    (chunk) => collect(stdout, chunk),
  );
  final stderrSubscription = process.stderr.listen(
    (chunk) => collect(stderr, chunk),
  );
  final streams = _ProcessStreams(stdoutSubscription, stderrSubscription);
  final stdinDone = _writeStdin(process, stdinBytes);
  final timeoutExceeded = Completer<_SubprocessSignal>();
  final timeoutAlreadyExceeded =
      timeout != null && timeout.compareTo(Duration.zero) <= 0;
  final timeoutTimer = timeout == null || timeoutAlreadyExceeded
      ? null
      : Timer(timeout, () {
          if (!timeoutExceeded.isCompleted) {
            timeoutExceeded.complete(const _TimedOut());
          }
        });

  BoundedSubprocessMonitor? activeMonitor;
  try {
    activeMonitor = monitor?.call(process.pid);
  } on Object {
    timeoutTimer?.cancel();
    await _stopAndDrain(
      process,
      streams,
      stdinDone,
      helperEnvironment: helperEnvironment,
      processGroup: startsProcessGroup,
    );
    rethrow;
  }

  late final _SubprocessSignal signal;
  try {
    signal = timeoutAlreadyExceeded
        ? const _TimedOut()
        : await Future.any<_SubprocessSignal>([
            process.exitCode.then(_Exited.new),
            if (timeout != null) timeoutExceeded.future,
            if (cancellationSignal != null)
              cancellationSignal.then((_) => const _Cancelled()),
            outputLimitExceeded.future,
            if (activeMonitor != null)
              activeMonitor.signal.then(_ExternalLimitExceeded.new),
          ]);
  } finally {
    timeoutTimer?.cancel();
    activeMonitor?.dispose();
  }

  final exitCode = signal is _Exited
      ? signal.exitCode
      : await _stopAndDrain(
          process,
          streams,
          stdinDone,
          helperEnvironment: helperEnvironment,
          processGroup: startsProcessGroup,
        );
  if (signal is _Exited) {
    await _drainAfterExit(
      process,
      streams,
      stdinDone,
      helperEnvironment: helperEnvironment,
      processGroup: startsProcessGroup,
    );
  }

  final termination = switch (signal) {
    _Exited() => BoundedSubprocessTermination.exited,
    _TimedOut() => BoundedSubprocessTermination.timedOut,
    _Cancelled() => BoundedSubprocessTermination.cancelled,
    _OutputLimitExceeded() => BoundedSubprocessTermination.outputLimitExceeded,
    _ExternalLimitExceeded() =>
      BoundedSubprocessTermination.externalLimitExceeded,
  };
  final externalLimit = switch (signal) {
    _ExternalLimitExceeded() => signal.value,
    _Exited() => activeMonitor?.observed(),
    _ => null,
  };
  return BoundedSubprocessResult(
    stdout: stdout.text,
    stderr: stderr.text,
    exitCode: exitCode,
    termination: termination,
    stdoutLimitExceeded: stdout.exceeded,
    stderrLimitExceeded: stderr.exceeded,
    externalLimit: externalLimit,
  );
}

Future<void> _writeStdin(Process process, List<int>? bytes) async {
  try {
    if (bytes != null && bytes.isNotEmpty) process.stdin.add(bytes);
    await process.stdin.close();
  } on Object {
    // Process termination can close stdin while supervision is still draining.
  }
}

Future<void> _drainAfterExit(
  Process process,
  _ProcessStreams streams,
  Future<void> stdinDone, {
  Map<String, String>? helperEnvironment,
  required bool processGroup,
}) async {
  if (streams.isDone) {
    await stdinDone;
    return;
  }
  await _terminateProcessTree(
    process.pid,
    ProcessSignal.sigterm,
    environment: helperEnvironment,
    processGroup: processGroup,
  );
  await _awaitDrainWithEscalation(
    process,
    streams,
    stdinDone,
    helperEnvironment: helperEnvironment,
    processGroup: processGroup,
  );
}

Future<int> _stopAndDrain(
  Process process,
  _ProcessStreams streams,
  Future<void> stdinDone, {
  Map<String, String>? helperEnvironment,
  required bool processGroup,
}) async {
  await _terminateProcessTree(
    process.pid,
    ProcessSignal.sigterm,
    environment: helperEnvironment,
    processGroup: processGroup,
  );
  return _awaitDrainWithEscalation(
    process,
    streams,
    stdinDone,
    helperEnvironment: helperEnvironment,
    processGroup: processGroup,
  );
}

Future<int> _awaitDrainWithEscalation(
  Process process,
  _ProcessStreams streams,
  Future<void> stdinDone, {
  Map<String, String>? helperEnvironment,
  required bool processGroup,
}) async {
  final completed = await _waitForExitAndDrain(process, streams, stdinDone)
      .then<int?>((value) => value)
      .timeout(const Duration(seconds: 2), onTimeout: () => null);
  if (completed != null) return completed;

  await _terminateProcessTree(
    process.pid,
    ProcessSignal.sigkill,
    environment: helperEnvironment,
    processGroup: processGroup,
  );
  final killed = await _waitForExitAndDrain(process, streams, stdinDone)
      .then<int?>((value) => value)
      .timeout(const Duration(seconds: 2), onTimeout: () => null);
  if (killed != null) return killed;

  await streams.cancel();
  return process.exitCode.timeout(
    const Duration(seconds: 1),
    onTimeout: () => -1,
  );
}

Future<int> _waitForExitAndDrain(
  Process process,
  _ProcessStreams streams,
  Future<void> stdinDone,
) async {
  final exitCode = await process.exitCode;
  await Future.wait<void>([streams.done, stdinDone]);
  return exitCode;
}

Future<void> _terminateProcessTree(
  int pid,
  ProcessSignal signal, {
  Map<String, String>? environment,
  required bool processGroup,
}) async {
  if (Platform.isWindows) {
    final args = ['/PID', '$pid', '/T'];
    if (signal == ProcessSignal.sigkill) args.add('/F');
    await _tryRunProcess('taskkill', args, environment: environment);
    return;
  }

  if (processGroup) {
    _tryKillPid(-pid, signal);
    _killPid(pid, signal);
  }
  final descendants = await _descendantPids(pid, environment: environment);
  for (final childPid in descendants.reversed) {
    _killPid(childPid, signal);
  }
  if (!processGroup) _killPid(pid, signal);
}

Future<List<int>> _descendantPids(
  int pid, {
  Map<String, String>? environment,
}) async {
  final ps = await _tryRunProcess(_systemTool('ps'), const [
    '-eo',
    'pid=,ppid=',
  ], environment: environment);
  if (ps?.exitCode != 0) return const [];
  final childrenByParent = <int, List<int>>{};
  for (final line in ps!.stdout.toString().split('\n')) {
    final values = _parsePids(line);
    if (values.length != 2) continue;
    childrenByParent.putIfAbsent(values[1], () => []).add(values[0]);
  }
  final descendants = <int>[];
  final pending = <int>[pid];
  final seen = <int>{pid};
  while (pending.isNotEmpty) {
    final parent = pending.removeLast();
    for (final child in childrenByParent[parent] ?? const <int>[]) {
      if (!seen.add(child)) continue;
      descendants.add(child);
      pending.add(child);
    }
  }
  return descendants;
}

String _systemTool(String name) {
  for (final root in const ['/usr/bin', '/bin']) {
    final path = '$root/$name';
    if (File(path).existsSync()) return path;
  }
  return name;
}

Future<ProcessResult?> _tryRunProcess(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  try {
    return await Process.run(
      executable,
      arguments,
      runInShell: false,
      environment: environment ?? benchmarkSubprocessEnvironment(),
      includeParentEnvironment: false,
    ).timeout(const Duration(milliseconds: 500));
  } on Object {
    return null;
  }
}

List<int> _parsePids(String output) => output
    .split(RegExp(r'\s+'))
    .map((value) => int.tryParse(value.trim()))
    .whereType<int>()
    .toList(growable: false);

void _killPid(int pid, ProcessSignal signal) {
  if (!_tryKillPid(pid, signal)) _tryKillPid(pid, null);
}

bool _tryKillPid(int pid, ProcessSignal? signal) {
  try {
    return signal == null ? Process.killPid(pid) : Process.killPid(pid, signal);
  } on Object {
    return false;
  }
}

class _ProcessStreams {
  _ProcessStreams(this._stdout, this._stderr) {
    done = Future.wait<void>([
      _stdout.asFuture<void>(),
      _stderr.asFuture<void>(),
    ]).whenComplete(() => isDone = true);
  }

  final StreamSubscription<List<int>> _stdout;
  final StreamSubscription<List<int>> _stderr;
  late final Future<void> done;
  bool isDone = false;

  Future<void> cancel() =>
      Future.wait<void>([_stdout.cancel(), _stderr.cancel()]);
}

class _BoundedByteCollector {
  _BoundedByteCollector(this.maxBytes, this.capture)
    : _tail = capture == BoundedSubprocessCapture.trailing
          ? Uint8List(maxBytes)
          : null;

  final int maxBytes;
  final BoundedSubprocessCapture capture;
  final BytesBuilder _head = BytesBuilder(copy: false);
  final Uint8List? _tail;
  var _tailStart = 0;
  var _tailLength = 0;
  var _seenBytes = 0;

  bool get exceeded => _seenBytes > maxBytes;

  void add(List<int> chunk) {
    if (chunk.isEmpty) return;
    _seenBytes += chunk.length;
    if (capture == BoundedSubprocessCapture.leading) {
      final remaining = maxBytes - _head.length;
      if (remaining > 0) {
        _head.add(
          chunk.length <= remaining ? chunk : chunk.sublist(0, remaining),
        );
      }
      return;
    }
    _addTrailing(chunk);
  }

  void _addTrailing(List<int> chunk) {
    final tail = _tail!;
    if (chunk.length >= maxBytes) {
      tail.setRange(0, maxBytes, chunk, chunk.length - maxBytes);
      _tailStart = 0;
      _tailLength = maxBytes;
      return;
    }
    final overflow = (_tailLength + chunk.length - maxBytes).clamp(0, maxBytes);
    _tailStart = (_tailStart + overflow) % maxBytes;
    _tailLength = (_tailLength + chunk.length).clamp(0, maxBytes);
    final writeStart = (_tailStart + _tailLength - chunk.length) % maxBytes;
    final firstLength = (maxBytes - writeStart).clamp(0, chunk.length);
    tail.setRange(writeStart, writeStart + firstLength, chunk);
    if (firstLength < chunk.length) {
      tail.setRange(0, chunk.length - firstLength, chunk, firstLength);
    }
  }

  String get text => _decode(bytes);

  List<int> get bytes {
    if (capture == BoundedSubprocessCapture.leading) return _head.toBytes();
    if (_tailLength == 0) return const [];
    final tail = _tail!;
    if (_tailStart + _tailLength <= maxBytes) {
      return tail.sublist(_tailStart, _tailStart + _tailLength);
    }
    return [
      ...tail.sublist(_tailStart),
      ...tail.sublist(0, (_tailStart + _tailLength) % maxBytes),
    ];
  }

  String _decode(List<int> bytes) {
    try {
      if (!Platform.isWindows) {
        return utf8.decode(bytes, allowMalformed: true);
      }
      return systemEncoding.decode(bytes);
    } on Object {
      return String.fromCharCodes(bytes);
    }
  }
}

sealed class _SubprocessSignal {
  const _SubprocessSignal();
}

class _Exited extends _SubprocessSignal {
  const _Exited(this.exitCode);

  final int exitCode;
}

class _TimedOut extends _SubprocessSignal {
  const _TimedOut();
}

class _Cancelled extends _SubprocessSignal {
  const _Cancelled();
}

class _OutputLimitExceeded extends _SubprocessSignal {
  const _OutputLimitExceeded();
}

class _ExternalLimitExceeded extends _SubprocessSignal {
  const _ExternalLimitExceeded(this.value);

  final Object value;
}
