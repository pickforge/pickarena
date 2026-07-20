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
typedef BoundedSubprocessSignalSender =
    bool Function(int pid, ProcessSignal? signal);

int maxEncodedOutputBytes(int maxCharacters) => maxCharacters * 4;

const _linuxHandshakeRoot = '/tmp';
const _execHandshakeTimeout = Duration(seconds: 5);
const _maxExecHandshakeBytes = 4096;
const _solSocket = 1;
const _soPeerCredentials = 17;
const _peerCredentialsSize = 12;

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
  final process = startsProcessGroup
      ? await _startLinuxProcessGroup(
          setsid,
          executable,
          arguments,
          workingDirectory: workingDirectory,
          environment: environment,
          includeParentEnvironment: includeParentEnvironment,
        )
      : await Process.start(
          executable,
          arguments,
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

const _pythonLinuxExecLauncher = r'''
import json
import os
import signal
import socket
import struct
import sys

handshake = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
handshake.set_inheritable(False)
handshake.connect(sys.argv[1])

def read_exact(length):
    chunks = []
    remaining = length
    while remaining:
        chunk = handshake.recv(remaining)
        if not chunk:
            raise RuntimeError('Incomplete target environment')
        chunks.append(chunk)
        remaining -= len(chunk)
    return b''.join(chunks)

environment_length = struct.unpack('!I', read_exact(4))[0]
environment = json.loads(read_exact(environment_length))
executable = sys.argv[2]
target_arguments = sys.argv[2:]
for signal_name in ('SIGPIPE', 'SIGXFSZ'):
    signal_number = getattr(signal, signal_name, None)
    if signal_number is not None:
        signal.signal(signal_number, signal.SIG_DFL)
try:
    if '/' in executable:
        os.execve(executable, target_arguments, environment)
    else:
        os.execvpe(executable, target_arguments, environment)
except OSError as error:
    message = (error.strerror or str(error)).encode('utf-8', 'replace')
    handshake.sendall(struct.pack('!I', error.errno or 0) + message)
    handshake.close()
    raise SystemExit(127 if error.errno == 2 else 126)
''';

const _dartLinuxExecLauncher = r'''
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

typedef _ExecNative = Int32 Function(
  Pointer<Uint8>,
  Pointer<Pointer<Uint8>>,
  Pointer<Pointer<Uint8>>,
);
typedef _ExecDart = int Function(
  Pointer<Uint8>,
  Pointer<Pointer<Uint8>>,
  Pointer<Pointer<Uint8>>,
);
typedef _MallocNative = Pointer<Void> Function(IntPtr);
typedef _MallocDart = Pointer<Void> Function(int);
typedef _ErrnoNative = Pointer<Int32> Function();
typedef _ErrnoDart = Pointer<Int32> Function();
typedef _StrerrorNative = Pointer<Uint8> Function(Int32);
typedef _StrerrorDart = Pointer<Uint8> Function(int);
typedef _SignalNative = Pointer<Void> Function(Int32, Pointer<Void>);
typedef _SignalDart = Pointer<Void> Function(int, Pointer<Void>);

final _libc = DynamicLibrary.process();
final _malloc = _libc.lookupFunction<_MallocNative, _MallocDart>('malloc');
final _execve = _libc.lookupFunction<_ExecNative, _ExecDart>('execve');
final _execvpe = _libc.lookupFunction<_ExecNative, _ExecDart>('execvpe');
final _errno = _libc.lookupFunction<_ErrnoNative, _ErrnoDart>(
  '__errno_location',
);
final _strerror = _libc.lookupFunction<_StrerrorNative, _StrerrorDart>(
  'strerror',
);
final _signal = _libc.lookupFunction<_SignalNative, _SignalDart>('signal');

Pointer<Uint8> _nativeString(String value) {
  final bytes = [...utf8.encode(value), 0];
  final pointer = _malloc(bytes.length).cast<Uint8>();
  pointer.asTypedList(bytes.length).setAll(0, bytes);
  return pointer;
}

Pointer<Pointer<Uint8>> _nativeVector(List<String> values) {
  final pointer = _malloc(
    (values.length + 1) * sizeOf<Pointer<Void>>(),
  ).cast<Pointer<Uint8>>();
  for (var index = 0; index < values.length; index++) {
    pointer[index] = _nativeString(values[index]);
  }
  pointer[values.length] = nullptr;
  return pointer;
}

String _errorMessage(int errorCode) {
  final pointer = _strerror(errorCode);
  final bytes = <int>[];
  for (var index = 0; pointer[index] != 0; index++) {
    bytes.add(pointer[index]);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

Future<Uint8List> _readMessage(Socket socket) {
  final completer = Completer<Uint8List>();
  final bytes = BytesBuilder(copy: false);
  late final StreamSubscription<Uint8List> subscription;
  subscription = socket.listen(
    (chunk) {
      if (completer.isCompleted) return;
      bytes.add(chunk);
      final payload = bytes.toBytes();
      if (payload.length < 4) return;
      final length = ByteData.sublistView(payload).getUint32(0);
      if (payload.length < 4 + length) return;
      subscription.pause();
      completer.complete(Uint8List.sublistView(payload, 4, 4 + length));
    },
    onError: completer.completeError,
    onDone: () {
      if (!completer.isCompleted) {
        completer.completeError(
          const FormatException('Incomplete target environment'),
        );
      }
    },
  );
  return completer.future;
}

Future<void> main(List<String> arguments) async {
  final handshake = await Socket.connect(
    InternetAddress(arguments[0], type: InternetAddressType.unix),
    0,
  );
  final environment = (jsonDecode(
    utf8.decode(await _readMessage(handshake)),
  ) as Map<String, dynamic>).cast<String, String>();
  final executable = arguments[1];
  final targetArguments = arguments.sublist(1);
  final environmentEntries = environment.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .toList(growable: false);

  const signalPipe = 13;
  const signalFileSizeExceeded = 25;
  _signal(signalPipe, nullptr);
  _signal(signalFileSizeExceeded, nullptr);
  final executablePointer = _nativeString(executable);
  final argumentPointers = _nativeVector(targetArguments);
  final environmentPointers = _nativeVector(environmentEntries);
  if (executable.contains('/')) {
    _execve(executablePointer, argumentPointers, environmentPointers);
  } else {
    _execvpe(executablePointer, argumentPointers, environmentPointers);
  }

  final errorCode = _errno().value;
  final message = utf8.encode(_errorMessage(errorCode));
  final response = Uint8List(4 + message.length);
  ByteData.sublistView(response).setUint32(0, errorCode);
  response.setRange(4, response.length, message);
  handshake.add(response);
  await handshake.flush();
  await handshake.close();
  exit(errorCode == 2 ? 127 : 126);
}
''';

Future<Process> _startLinuxProcessGroup(
  String setsid,
  String targetExecutable,
  List<String> arguments, {
  required String workingDirectory,
  required Map<String, String> environment,
  required bool includeParentEnvironment,
}) async {
  final targetEnvironment = <String, String>{
    if (includeParentEnvironment) ...Platform.environment,
    ...environment,
  };
  final handshakeDirectory = await Directory(
    _linuxHandshakeRoot,
  ).createTemp('dart_arena_exec_');
  final launcher = File('${handshakeDirectory.path}/launcher.dart');
  final socketPath = '${handshakeDirectory.path}/handshake.sock';
  ServerSocket? server;
  Process? process;
  try {
    final python = _installedSystemTool('python3');
    if (python == null) {
      await launcher.writeAsString(_dartLinuxExecLauncher);
    }
    server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    process = await Process.start(
      setsid,
      [
        '--wait',
        '--',
        if (python != null) ...[
          python,
          '-I',
          '-S',
          '-c',
          _pythonLinuxExecLauncher,
        ] else ...[
          Platform.resolvedExecutable,
          launcher.path,
        ],
        socketPath,
        targetExecutable,
        ...arguments,
      ],
      workingDirectory: workingDirectory,
      runInShell: false,
      environment: {
        'PATH':
            targetEnvironment['PATH'] ??
            Platform.environment['PATH'] ??
            '/usr/bin:/bin',
      },
      includeParentEnvironment: false,
    );

    late final _ExecHandshake result;
    try {
      result = await _receiveExecHandshake(
        server,
        process.pid,
        targetEnvironment,
        cleanupHandshake: () async {
          if (await handshakeDirectory.exists()) {
            await handshakeDirectory.delete(recursive: true);
          }
        },
      ).timeout(_execHandshakeTimeout);
    } on TimeoutException {
      await _drainFailedLauncher(process, terminate: true);
      throw ProcessException(
        targetExecutable,
        arguments,
        'Subprocess launcher did not complete its exec handshake',
      );
    } on Object catch (error) {
      await _drainFailedLauncher(process, terminate: true);
      throw ProcessException(
        targetExecutable,
        arguments,
        'Subprocess launcher failed: $error',
      );
    }

    final errorCode = result.errorCode;
    if (errorCode != null) {
      final exception = ProcessException(
        targetExecutable,
        arguments,
        result.message,
        errorCode,
      );
      await _drainFailedLauncher(process);
      throw exception;
    }
    return process;
  } finally {
    await server?.close();
    if (await handshakeDirectory.exists()) {
      await handshakeDirectory.delete(recursive: true);
    }
  }
}

Future<_ExecHandshake> _receiveExecHandshake(
  ServerSocket server,
  int expectedPid,
  Map<String, String> targetEnvironment, {
  required Future<void> Function() cleanupHandshake,
}) async {
  await for (final socket in server) {
    final credentials = socket.getRawOption(
      RawSocketOption(
        _solSocket,
        _soPeerCredentials,
        Uint8List(_peerCredentialsSize),
      ),
    );
    final peerPid = ByteData.sublistView(credentials).getInt32(0, Endian.host);
    if (peerPid != expectedPid) {
      socket.destroy();
      continue;
    }

    await cleanupHandshake();
    final bytes = BytesBuilder(copy: false);
    try {
      final environment = utf8.encode(jsonEncode(targetEnvironment));
      final header = ByteData(4)..setUint32(0, environment.length);
      socket.add(header.buffer.asUint8List());
      socket.add(environment);
      await socket.flush();
      await for (final chunk in socket) {
        bytes.add(chunk);
        if (bytes.length > _maxExecHandshakeBytes) break;
      }
    } finally {
      socket.destroy();
    }
    final payload = bytes.takeBytes();
    if (payload.isEmpty) return const _ExecHandshake.success();
    if (payload.length < 4) {
      throw const FormatException('Incomplete exec failure handshake');
    }
    final errorCode = ByteData.sublistView(payload).getUint32(0);
    final message = utf8.decode(payload.sublist(4), allowMalformed: true);
    return _ExecHandshake.failure(errorCode, message);
  }
  throw const SocketException('Exec handshake socket closed unexpectedly');
}

Future<void> _drainFailedLauncher(
  Process process, {
  bool terminate = false,
}) async {
  final drains = Future.wait<void>([
    process.stdout.drain<void>(),
    process.stderr.drain<void>(),
  ]);
  try {
    await process.stdin.close();
  } on Object {
    // The failed launcher may already have closed stdin.
  }
  if (terminate) {
    _tryKillPid(-process.pid, ProcessSignal.sigkill);
    _tryKillPid(process.pid, ProcessSignal.sigkill);
  }
  try {
    await Future.wait<void>([
      drains,
      process.exitCode.then<void>((_) {}),
    ]).timeout(const Duration(seconds: 2));
  } on TimeoutException {
    _tryKillPid(-process.pid, ProcessSignal.sigkill);
    _tryKillPid(process.pid, ProcessSignal.sigkill);
  }
}

class _ExecHandshake {
  const _ExecHandshake.success() : errorCode = null, message = '';

  const _ExecHandshake.failure(this.errorCode, this.message);

  final int? errorCode;
  final String message;
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
