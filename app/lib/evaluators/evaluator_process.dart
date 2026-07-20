import 'dart:async';
import 'dart:io';
import 'package:dart_arena/runner/bounded_subprocess.dart';
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
  BoundedSubprocessMonitor resourceMonitor(int pid) {
    final limitExceeded = Completer<Object>();
    Object? observedLimit;
    var resourceCheckRunning = false;
    final timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (resourceCheckRunning) return;
      resourceCheckRunning = true;
      try {
        final descendants = await _descendantPids(
          pid,
          environment: helperEnvironment,
        );
        final processCount = 1 + descendants.length;
        if (maxProcesses != null && processCount > maxProcesses) {
          observedLimit = _EvaluatorProcessLimitExceeded(
            processCount: processCount,
          );
          if (!limitExceeded.isCompleted) {
            limitExceeded.complete(observedLimit!);
          }
          return;
        }
        if (maxMemoryMb != null) {
          final memoryMb = await _processTreeMemoryMb(
            pid,
            descendants,
            environment: helperEnvironment,
          );
          if (memoryMb != null && memoryMb > maxMemoryMb) {
            observedLimit = _EvaluatorMemoryLimitExceeded(memoryMb: memoryMb);
            if (!limitExceeded.isCompleted) {
              limitExceeded.complete(observedLimit!);
            }
          }
        }
      } finally {
        resourceCheckRunning = false;
      }
    });
    return BoundedSubprocessMonitor(
      signal: limitExceeded.future,
      observed: () => observedLimit,
      dispose: timer.cancel,
    );
  }

  final result = await runBoundedSubprocess(
    executable: processStart.executable,
    arguments: processStart.arguments,
    workingDirectory: processStart.workingDirectory,
    environment: processStart.environment,
    includeParentEnvironment: generatedCodeSandbox == null
        ? includeParentEnvironment
        : false,
    timeout: timeout,
    maxOutputBytes: maxOutputChars,
    helperEnvironment: helperEnvironment,
    monitor: maxProcesses != null || maxMemoryMb != null
        ? resourceMonitor
        : null,
  );
  final externalLimit = result.externalLimit;
  return EvaluatorProcessResult(
    stdout: result.stdout,
    stderr: result.stderr,
    exitCode: result.termination == BoundedSubprocessTermination.exited
        ? result.exitCode
        : -1,
    timedOut: result.termination == BoundedSubprocessTermination.timedOut,
    outputLimitExceeded:
        result.outputLimitExceeded ||
        (result.termination == BoundedSubprocessTermination.exited &&
            (result.stdoutLimitExceeded || result.stderrLimitExceeded)),
    processLimitExceeded: externalLimit is _EvaluatorProcessLimitExceeded,
    memoryLimitExceeded: externalLimit is _EvaluatorMemoryLimitExceeded,
    observedProcessCount: externalLimit is _EvaluatorProcessLimitExceeded
        ? externalLimit.processCount
        : null,
    observedMemoryMb: externalLimit is _EvaluatorMemoryLimitExceeded
        ? externalLimit.memoryMb
        : null,
  );
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

class _EvaluatorProcessLimitExceeded {
  const _EvaluatorProcessLimitExceeded({required this.processCount});

  final int processCount;
}

class _EvaluatorMemoryLimitExceeded {
  const _EvaluatorMemoryLimitExceeded({required this.memoryMb});

  final int memoryMb;
}
