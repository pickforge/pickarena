import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

const defaultEvaluatorProcessTimeout = Duration(minutes: 5);
const defaultEvaluatorMaxOutputChars = 1024 * 1024;

class EvaluatorProcessResult {
  const EvaluatorProcessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.timedOut,
    required this.outputLimitExceeded,
    required this.processLimitExceeded,
    required this.memoryLimitExceeded,
    required this.observedProcessCount,
    required this.observedMemoryMb,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
  final bool timedOut;
  final bool outputLimitExceeded;
  final bool processLimitExceeded;
  final bool memoryLimitExceeded;
  final int? observedProcessCount;
  final int? observedMemoryMb;
}

Future<EvaluatorProcessResult> runEvaluatorProcess(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required Map<String, String> environment,
  bool includeParentEnvironment = false,
  Duration? timeout = defaultEvaluatorProcessTimeout,
  int maxOutputChars = defaultEvaluatorMaxOutputChars,
  int? maxCpuCores,
  int? maxProcesses,
  int? maxMemoryMb,
  Map<String, String>? helperBaseEnvironment,
  Iterable<String> helperDeniedEnvironmentKeys = const [],
  GeneratedCodeSandbox? generatedCodeSandbox,
  bool allowInternet = false,
  Iterable<String> extraReadOnlyPaths = const [],
}) async {
  final helperEnvironment = benchmarkSubprocessEnvironment(
    baseEnvironment: helperBaseEnvironment,
    additionalDeniedKeys: helperDeniedEnvironmentKeys,
  );
  final processStart = generatedCodeSandbox == null
      ? SandboxedProcessStart(
          executable: executable,
          arguments: arguments,
          workingDirectory: workingDirectory,
          environment: environment,
        )
      : await generatedCodeSandbox.wrapProcess(
          executable: executable,
          arguments: arguments,
          workingDirectory: workingDirectory,
          environment: environment,
          allowInternet: allowInternet,
          resourceLimits: SandboxResourceLimits(
            cpuCores: maxCpuCores,
            memoryMb: maxMemoryMb,
            maxProcesses: maxProcesses,
          ),
          extraReadOnlyPaths: extraReadOnlyPaths,
        );
  final process = await Process.start(
    processStart.executable,
    processStart.arguments,
    workingDirectory: processStart.workingDirectory,
    runInShell: false,
    environment: processStart.environment,
    includeParentEnvironment: generatedCodeSandbox == null
        ? includeParentEnvironment
        : false,
  );
  final stdoutBuffer = _BoundedTextCollector(maxOutputChars);
  final stderrBuffer = _BoundedTextCollector(maxOutputChars);
  final outputLimitExceeded = Completer<_EvaluatorProcessSignal>();
  final processLimitExceeded = Completer<_EvaluatorProcessSignal>();
  final memoryLimitExceeded = Completer<_EvaluatorProcessSignal>();
  int? observedProcessCount;
  int? observedMemoryMb;
  void markOutputLimitExceeded() {
    if (!outputLimitExceeded.isCompleted) {
      outputLimitExceeded.complete(
        const _EvaluatorProcessOutputLimitExceeded(),
      );
    }
  }

  void markProcessLimitExceeded(int count) {
    observedProcessCount = count;
    if (!processLimitExceeded.isCompleted) {
      processLimitExceeded.complete(
        _EvaluatorProcessLimitExceeded(processCount: count),
      );
    }
  }

  void markMemoryLimitExceeded(int memoryMb) {
    observedMemoryMb = memoryMb;
    if (!memoryLimitExceeded.isCompleted) {
      memoryLimitExceeded.complete(
        _EvaluatorMemoryLimitExceeded(memoryMb: memoryMb),
      );
    }
  }

  final stdoutDone = process.stdout.listen((chunk) {
    stdoutBuffer.writeBytes(chunk);
    if (stdoutBuffer.exceeded) markOutputLimitExceeded();
  }).asFuture<void>();
  final stderrDone = process.stderr.listen((chunk) {
    stderrBuffer.writeBytes(chunk);
    if (stderrBuffer.exceeded) markOutputLimitExceeded();
  }).asFuture<void>();

  if (timeout != null && timeout.compareTo(Duration.zero) <= 0) {
    await _terminateProcessTree(
      process.pid,
      ProcessSignal.sigterm,
      environment: helperEnvironment,
    );
    await _awaitProcessExit(process, environment: helperEnvironment);
    await Future.wait([stdoutDone, stderrDone]);
    return EvaluatorProcessResult(
      stdout: stdoutBuffer.text,
      stderr: stderrBuffer.text,
      exitCode: -1,
      timedOut: true,
      outputLimitExceeded: false,
      processLimitExceeded: false,
      memoryLimitExceeded: false,
      observedProcessCount: null,
      observedMemoryMb: null,
    );
  }

  Timer? resourceLimitTimer;
  var resourceCheckRunning = false;
  if (maxProcesses != null || maxMemoryMb != null) {
    resourceLimitTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      if (resourceCheckRunning) return;
      resourceCheckRunning = true;
      try {
        final descendants = await _descendantPids(
          process.pid,
          environment: helperEnvironment,
        );
        final processCount = 1 + descendants.length;
        if (maxProcesses != null && processCount > maxProcesses) {
          markProcessLimitExceeded(processCount);
        }
        if (maxMemoryMb != null) {
          final memoryMb = await _processTreeMemoryMb(
            process.pid,
            descendants,
            environment: helperEnvironment,
          );
          if (memoryMb != null && memoryMb > maxMemoryMb) {
            markMemoryLimitExceeded(memoryMb);
          }
        }
      } finally {
        resourceCheckRunning = false;
      }
    });
  }
  final timeoutExceeded = Completer<_EvaluatorProcessSignal>();
  final timeoutTimer = timeout == null
      ? null
      : Timer(timeout, () {
          if (!timeoutExceeded.isCompleted) {
            timeoutExceeded.complete(const _EvaluatorProcessTimedOut());
          }
        });
  late final _EvaluatorProcessSignal signal;
  try {
    signal = await Future.any<_EvaluatorProcessSignal>([
      process.exitCode.then(_EvaluatorProcessExit.new),
      if (timeout != null) timeoutExceeded.future,
      outputLimitExceeded.future,
      if (maxProcesses != null) processLimitExceeded.future,
      if (maxMemoryMb != null) memoryLimitExceeded.future,
    ]);
  } finally {
    timeoutTimer?.cancel();
    resourceLimitTimer?.cancel();
  }

  if (signal is _EvaluatorProcessExit) {
    await Future.wait([stdoutDone, stderrDone]);
    return EvaluatorProcessResult(
      stdout: stdoutBuffer.text,
      stderr: stderrBuffer.text,
      exitCode: signal.exitCode,
      timedOut: false,
      outputLimitExceeded: stdoutBuffer.exceeded || stderrBuffer.exceeded,
      processLimitExceeded: observedProcessCount != null,
      memoryLimitExceeded: observedMemoryMb != null,
      observedProcessCount: observedProcessCount,
      observedMemoryMb: observedMemoryMb,
    );
  }

  await _terminateProcessTree(
    process.pid,
    ProcessSignal.sigterm,
    environment: helperEnvironment,
  );
  await _awaitProcessExit(process, environment: helperEnvironment);
  await Future.wait([stdoutDone, stderrDone]);
  return EvaluatorProcessResult(
    stdout: stdoutBuffer.text,
    stderr: stderrBuffer.text,
    exitCode: -1,
    timedOut: signal is _EvaluatorProcessTimedOut,
    outputLimitExceeded: signal is _EvaluatorProcessOutputLimitExceeded,
    processLimitExceeded: signal is _EvaluatorProcessLimitExceeded,
    memoryLimitExceeded: signal is _EvaluatorMemoryLimitExceeded,
    observedProcessCount: signal is _EvaluatorProcessLimitExceeded
        ? signal.processCount
        : null,
    observedMemoryMb: signal is _EvaluatorMemoryLimitExceeded
        ? signal.memoryMb
        : null,
  );
}

Future<void> _awaitProcessExit(
  Process process, {
  Map<String, String>? environment,
}) async {
  await process.exitCode.timeout(
    const Duration(seconds: 2),
    onTimeout: () async {
      await _terminateProcessTree(
        process.pid,
        ProcessSignal.sigkill,
        environment: environment,
      );
      return -1;
    },
  );
}

Future<void> _terminateProcessTree(
  int pid,
  ProcessSignal signal, {
  Map<String, String>? environment,
}) async {
  if (Platform.isWindows) {
    final args = ['/PID', '$pid', '/T'];
    if (signal == ProcessSignal.sigkill) args.add('/F');
    await _tryRunProcess('taskkill', args, environment: environment);
    return;
  }

  final descendants = await _descendantPids(pid, environment: environment);
  for (final childPid in descendants.reversed) {
    _killPid(childPid, signal);
  }
  _killPid(pid, signal);
}

Future<List<int>> _descendantPids(
  int pid, {
  Map<String, String>? environment,
}) async {
  final descendants = <int>[];
  for (final childPid in await _childPids(pid, environment: environment)) {
    descendants.add(childPid);
    descendants.addAll(
      await _descendantPids(childPid, environment: environment),
    );
  }
  return descendants;
}

Future<int?> _processTreeMemoryMb(
  int pid,
  List<int> descendants, {
  Map<String, String>? environment,
}) async {
  if (Platform.isWindows) return null;
  final pids = [pid, ...descendants];
  if (pids.isEmpty) return null;
  final ps = await _tryRunProcess('ps', [
    '-o',
    'rss=',
    '-p',
    pids.join(','),
  ], environment: environment);
  if (ps?.exitCode != 0) return null;
  final rssKb = _parsePids(
    ps!.stdout.toString(),
  ).fold<int>(0, (sum, value) => sum + value);
  if (rssKb <= 0) return null;
  return (rssKb / 1024).ceil();
}

Future<List<int>> _childPids(
  int pid, {
  Map<String, String>? environment,
}) async {
  final pgrep = await _tryRunProcess('pgrep', [
    '-P',
    '$pid',
  ], environment: environment);
  if (pgrep?.exitCode == 0) return _parsePids(pgrep!.stdout.toString());

  final ps = await _tryRunProcess('ps', [
    '-o',
    'pid=',
    '--ppid',
    '$pid',
  ], environment: environment);
  if (ps?.exitCode == 0) return _parsePids(ps!.stdout.toString());
  return const [];
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
    );
  } on Object {
    return null;
  }
}

List<int> _parsePids(String output) => output
    .split(RegExp(r'\s+'))
    .map((s) => int.tryParse(s.trim()))
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

/// Collects raw process output, enforcing the limit on undecoded bytes so
/// multibyte encodings cannot exceed the byte contract before decode.
class _BoundedTextCollector {
  _BoundedTextCollector(this.maxBytes) : assert(maxBytes > 0);

  final int maxBytes;
  final _bytes = BytesBuilder(copy: false);
  bool exceeded = false;

  String get text {
    final bytes = _bytes.toBytes();
    try {
      return systemEncoding.decode(bytes);
    } on Object {
      return String.fromCharCodes(bytes);
    }
  }

  void writeBytes(List<int> chunk) {
    if (exceeded) return;
    final remaining = maxBytes - _bytes.length;
    if (remaining <= 0) {
      exceeded = true;
      return;
    }
    if (chunk.length <= remaining) {
      _bytes.add(chunk);
      return;
    }
    _bytes.add(chunk.sublist(0, remaining));
    exceeded = true;
  }
}

sealed class _EvaluatorProcessSignal {
  const _EvaluatorProcessSignal();
}

class _EvaluatorProcessExit extends _EvaluatorProcessSignal {
  const _EvaluatorProcessExit(this.exitCode);

  final int exitCode;
}

class _EvaluatorProcessTimedOut extends _EvaluatorProcessSignal {
  const _EvaluatorProcessTimedOut();
}

class _EvaluatorProcessOutputLimitExceeded extends _EvaluatorProcessSignal {
  const _EvaluatorProcessOutputLimitExceeded();
}

class _EvaluatorProcessLimitExceeded extends _EvaluatorProcessSignal {
  const _EvaluatorProcessLimitExceeded({required this.processCount});

  final int processCount;
}

class _EvaluatorMemoryLimitExceeded extends _EvaluatorProcessSignal {
  const _EvaluatorMemoryLimitExceeded({required this.memoryMb});

  final int memoryMb;
}
