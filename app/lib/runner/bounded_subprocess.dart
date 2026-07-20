import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_arena/runner/subprocess_environment.dart';
import 'package:path/path.dart' as p;

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
typedef BoundedSubprocessSignalSender =
    bool Function(int pid, ProcessSignal? signal);

int maxEncodedOutputBytes(int maxCharacters) => maxCharacters * 4;

Future<BoundedSubprocessResult> runBoundedSubprocess({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
  required Map<String, String> environment,
  required int maxOutputBytes,
  int? maxOutputCharacters,
  bool includeParentEnvironment = false,
  Duration? timeout,
  Future<void>? cancellationSignal,
  BoundedSubprocessCapture capture = BoundedSubprocessCapture.leading,
  List<int>? stdinBytes,
  Map<String, String>? helperEnvironment,
  BoundedSubprocessMonitorFactory? monitor,
  BoundedSubprocessSignalSender signalSender = _tryKillPid,
}) async {
  assert(maxOutputBytes > 0);
  assert(maxOutputCharacters == null || maxOutputCharacters > 0);
  final setsid = Platform.isLinux ? _installedSystemTool('setsid') : null;
  final startsProcessGroup = setsid != null;
  final targetExecutable = startsProcessGroup
      ? _resolveExecutable(
          executable,
          arguments,
          workingDirectory: workingDirectory,
          environment: environment,
          includeParentEnvironment: includeParentEnvironment,
        )
      : executable;
  final process = await Process.start(
    setsid ?? targetExecutable,
    startsProcessGroup
        ? ['--wait', '--', targetExecutable, ...arguments]
        : arguments,
    workingDirectory: workingDirectory,
    runInShell: false,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
  );
  final processState = _ProcessState(process);
  final stdout = _BoundedByteCollector(
    maxOutputBytes,
    capture,
    maxCharacters: maxOutputCharacters,
  );
  final stderr = _BoundedByteCollector(
    maxOutputBytes,
    capture,
    maxCharacters: maxOutputCharacters,
  );
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
  final streams = _ProcessStreams(
    stdoutSubscription,
    stderrSubscription,
    closeStdout: stdout.close,
    closeStderr: stderr.close,
  );
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
      processState,
      streams,
      stdinDone,
      helperEnvironment: helperEnvironment,
      processGroup: startsProcessGroup,
      signalSender: signalSender,
    );
    rethrow;
  }

  late final _SubprocessSignal signal;
  try {
    signal = timeoutAlreadyExceeded
        ? const _TimedOut()
        : await Future.any<_SubprocessSignal>([
            processState.exitCode.then(_Exited.new),
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
          processState,
          streams,
          stdinDone,
          helperEnvironment: helperEnvironment,
          processGroup: startsProcessGroup,
          signalSender: signalSender,
        );
  if (signal is _Exited) {
    await _drainAfterExit(
      processState,
      streams,
      stdinDone,
      helperEnvironment: helperEnvironment,
      processGroup: startsProcessGroup,
      signalSender: signalSender,
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
  _ProcessState process,
  _ProcessStreams streams,
  Future<void> stdinDone, {
  Map<String, String>? helperEnvironment,
  required bool processGroup,
  required BoundedSubprocessSignalSender signalSender,
}) async {
  if (streams.isDone) {
    await stdinDone;
    return;
  }
  final retainedDescendants = <int>{};
  await _terminateProcessTree(
    process.pid,
    ProcessSignal.sigterm,
    retainedDescendants: retainedDescendants,
    rootExited: () => true,
    environment: helperEnvironment,
    processGroup: processGroup,
    signalSender: signalSender,
  );
  await _awaitDrainWithEscalation(
    process,
    streams,
    stdinDone,
    retainedDescendants: retainedDescendants,
    helperEnvironment: helperEnvironment,
    processGroup: processGroup,
    signalSender: signalSender,
  );
}

Future<int> _stopAndDrain(
  _ProcessState process,
  _ProcessStreams streams,
  Future<void> stdinDone, {
  Map<String, String>? helperEnvironment,
  required bool processGroup,
  required BoundedSubprocessSignalSender signalSender,
}) async {
  final retainedDescendants = <int>{};
  await _terminateProcessTree(
    process.pid,
    ProcessSignal.sigterm,
    retainedDescendants: retainedDescendants,
    rootExited: () => process.exited,
    environment: helperEnvironment,
    processGroup: processGroup,
    signalSender: signalSender,
  );
  return _awaitDrainWithEscalation(
    process,
    streams,
    stdinDone,
    retainedDescendants: retainedDescendants,
    helperEnvironment: helperEnvironment,
    processGroup: processGroup,
    signalSender: signalSender,
  );
}

Future<int> _awaitDrainWithEscalation(
  _ProcessState process,
  _ProcessStreams streams,
  Future<void> stdinDone, {
  required Set<int> retainedDescendants,
  Map<String, String>? helperEnvironment,
  required bool processGroup,
  required BoundedSubprocessSignalSender signalSender,
}) async {
  final completed = await _waitForExitAndDrain(process, streams, stdinDone)
      .then<int?>((value) => value)
      .timeout(const Duration(seconds: 2), onTimeout: () => null);
  if (completed != null) return completed;

  await _terminateProcessTree(
    process.pid,
    ProcessSignal.sigkill,
    retainedDescendants: retainedDescendants,
    rootExited: () => process.exited,
    environment: helperEnvironment,
    processGroup: processGroup,
    signalSender: signalSender,
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
  _ProcessState process,
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
  required Set<int> retainedDescendants,
  required bool Function() rootExited,
  Map<String, String>? environment,
  required bool processGroup,
  required BoundedSubprocessSignalSender signalSender,
}) async {
  if (Platform.isWindows) {
    if (rootExited()) return;
    final args = ['/PID', '$pid', '/T'];
    if (signal == ProcessSignal.sigkill) args.add('/F');
    await _tryRunProcess('taskkill', args, environment: environment);
    return;
  }

  final descendantRoots = {...retainedDescendants};
  if (!rootExited()) descendantRoots.add(pid);
  if (descendantRoots.isNotEmpty) {
    retainedDescendants.addAll(
      await _descendantPids(descendantRoots, environment: environment),
    );
  }
  if (processGroup) signalSender(-pid, signal);
  for (final childPid in retainedDescendants.toList().reversed) {
    _killPid(childPid, signal, signalSender);
  }
  if (!rootExited()) _killPid(pid, signal, signalSender);
}

Future<List<int>> _descendantPids(
  Set<int> roots, {
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
  final pending = roots.toList();
  final seen = {...roots};
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

String _systemTool(String name) => _installedSystemTool(name) ?? name;

String? _installedSystemTool(String name) {
  for (final root in const ['/usr/bin', '/bin']) {
    final path = '$root/$name';
    if (File(path).existsSync()) return path;
  }
  return null;
}

String _resolveExecutable(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required Map<String, String> environment,
  required bool includeParentEnvironment,
}) {
  final candidates = <String>[];
  if (p.isAbsolute(executable) || executable.contains('/')) {
    candidates.add(
      p.isAbsolute(executable)
          ? executable
          : p.join(workingDirectory, executable),
    );
  } else {
    final path =
        environment['PATH'] ??
        (includeParentEnvironment ? Platform.environment['PATH'] : null) ??
        Platform.environment['PATH'] ??
        '/usr/bin:/bin';
    for (final root in path.split(':')) {
      final searchRoot = root.isEmpty || !p.isAbsolute(root)
          ? p.join(workingDirectory, root)
          : root;
      candidates.add(p.join(searchRoot, executable));
    }
  }

  var foundNonExecutable = false;
  for (final candidate in candidates) {
    if (FileSystemEntity.typeSync(candidate, followLinks: true) !=
        FileSystemEntityType.file) {
      continue;
    }
    if (File(candidate).statSync().mode & 0x49 == 0) {
      foundNonExecutable = true;
      continue;
    }
    return p.normalize(p.absolute(candidate));
  }
  throw ProcessException(
    executable,
    arguments,
    foundNonExecutable ? 'Permission denied' : 'No such file or directory',
    foundNonExecutable ? 13 : 2,
  );
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

void _killPid(
  int pid,
  ProcessSignal signal,
  BoundedSubprocessSignalSender signalSender,
) {
  if (!signalSender(pid, signal)) signalSender(pid, null);
}

bool _tryKillPid(int pid, ProcessSignal? signal) {
  try {
    return signal == null ? Process.killPid(pid) : Process.killPid(pid, signal);
  } on Object {
    return false;
  }
}

class _ProcessState {
  _ProcessState(this.process) {
    exitCode = process.exitCode.whenComplete(() => exited = true);
  }

  final Process process;
  late final Future<int> exitCode;
  bool exited = false;

  int get pid => process.pid;
}

class _ProcessStreams {
  _ProcessStreams(
    this._stdout,
    this._stderr, {
    required void Function() closeStdout,
    required void Function() closeStderr,
  }) : _closeStdout = closeStdout,
       _closeStderr = closeStderr {
    done = Future.wait<void>([
      _stdout.asFuture<void>().whenComplete(_closeStdout),
      _stderr.asFuture<void>().whenComplete(_closeStderr),
    ]).whenComplete(() => isDone = true);
  }

  final StreamSubscription<List<int>> _stdout;
  final StreamSubscription<List<int>> _stderr;
  final void Function() _closeStdout;
  final void Function() _closeStderr;
  late final Future<void> done;
  bool isDone = false;

  Future<void> cancel() async {
    await Future.wait<void>([_stdout.cancel(), _stderr.cancel()]);
    _closeStdout();
    _closeStderr();
  }
}

class _BoundedByteCollector {
  _BoundedByteCollector(this.maxBytes, this.capture, {int? maxCharacters})
    : _maxCharacters = maxCharacters,
      _characterLimit = maxCharacters == null
          ? null
          : _CharacterLimitTracker(maxCharacters),
      _tail = capture == BoundedSubprocessCapture.trailing
          ? Uint8List(maxBytes)
          : null;

  final int maxBytes;
  final BoundedSubprocessCapture capture;
  final int? _maxCharacters;
  final _CharacterLimitTracker? _characterLimit;
  final BytesBuilder _head = BytesBuilder(copy: false);
  final Uint8List? _tail;
  var _tailStart = 0;
  var _tailLength = 0;
  var _seenBytes = 0;

  bool get exceeded =>
      _seenBytes > maxBytes || (_characterLimit?.exceeded ?? false);

  void add(List<int> chunk) {
    if (chunk.isEmpty) return;
    _seenBytes += chunk.length;
    _characterLimit?.add(chunk);
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

  void close() => _characterLimit?.close();

  String get text {
    final decoded = _decode(bytes);
    final maxCharacters = _maxCharacters;
    if (maxCharacters == null || decoded.length <= maxCharacters) {
      return decoded;
    }
    return capture == BoundedSubprocessCapture.leading
        ? decoded.substring(0, maxCharacters)
        : decoded.substring(decoded.length - maxCharacters);
  }

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

class _CharacterLimitTracker {
  _CharacterLimitTracker(int maxCharacters)
    : _counter = _CharacterCountingSink(maxCharacters) {
    final decoder = Platform.isWindows
        ? systemEncoding.decoder
        : const Utf8Decoder(allowMalformed: true);
    _sink = decoder.startChunkedConversion(
      StringConversionSink.fromStringSink(_counter),
    );
  }

  final _CharacterCountingSink _counter;
  late final Sink<List<int>> _sink;
  bool _closed = false;

  bool get exceeded => _counter.exceeded;

  void add(List<int> bytes) {
    if (!_closed) _sink.add(bytes);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _sink.close();
  }
}

class _CharacterCountingSink implements StringSink {
  _CharacterCountingSink(this.maxCharacters);

  final int maxCharacters;
  var _length = 0;

  bool get exceeded => _length > maxCharacters;

  @override
  void write(Object? object) {
    _length += object.toString().length;
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    _length += String.fromCharCode(charCode).length;
  }

  @override
  void writeln([Object? object = '']) {
    write(object);
    _length++;
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
