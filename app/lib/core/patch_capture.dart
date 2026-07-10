import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

const patchBaselineRef = 'arena_baseline';

class PatchCaptureResult {
  const PatchCaptureResult({
    required this.patch,
    required this.status,
    required this.patchSha256,
  });

  final String patch;
  final String status;
  final String patchSha256;

  bool get hasMeaningfulDiff => patch.trim().isNotEmpty;
}

class PatchCapture {
  const PatchCapture({
    this.gitExecutable = 'git',
    this.deniedEnvironmentKeys = const [],
    this.baseEnvironment,
    this.timeout = const Duration(seconds: 15),
    this.maxOutputChars = 1024 * 1024,
  }) : assert(maxOutputChars > 0);

  final String gitExecutable;
  final Iterable<String> deniedEnvironmentKeys;
  final Map<String, String>? baseEnvironment;
  final Duration timeout;
  final int maxOutputChars;

  Future<PatchCaptureResult> capture(Directory workspace) async {
    const addIntentArgs = ['add', '-N', '.'];
    final intentToAdd = await _runGit(workspace, addIntentArgs);
    _checkGitResult(intentToAdd, addIntentArgs);
    const statusArgs = ['status', '--porcelain'];
    const diffArgs = ['diff', patchBaselineRef, '--binary'];
    final status = await _runGit(workspace, statusArgs);
    final diff = await _runGit(workspace, diffArgs);
    _checkGitResult(status, statusArgs);
    _checkGitResult(diff, diffArgs);
    final patch = diff.stdout.toString();
    return PatchCaptureResult(
      patch: patch,
      status: status.stdout.toString(),
      patchSha256: sha256.convert(utf8.encode(patch)).toString(),
    );
  }

  Future<_GitProcessResult> _runGit(
    Directory workspace,
    List<String> args,
  ) async {
    final processEnvironment = _gitEnvironment();
    final process = await Process.start(
      gitExecutable,
      args,
      workingDirectory: workspace.path,
      runInShell: false,
      environment: processEnvironment,
      includeParentEnvironment: false,
    );
    final stdoutBuffer = _BoundedTextCollector(maxOutputChars);
    final stderrBuffer = _BoundedTextCollector(maxOutputChars);
    final outputLimitExceeded = Completer<void>();
    void markOutputLimitExceeded() {
      if (!outputLimitExceeded.isCompleted) outputLimitExceeded.complete();
    }

    final stdoutDone = process.stdout.transform(systemEncoding.decoder).listen((
      chunk,
    ) {
      stdoutBuffer.write(chunk);
      if (stdoutBuffer.exceeded) markOutputLimitExceeded();
    }).asFuture<void>();
    final stderrDone = process.stderr.transform(systemEncoding.decoder).listen((
      chunk,
    ) {
      stderrBuffer.write(chunk);
      if (stderrBuffer.exceeded) markOutputLimitExceeded();
    }).asFuture<void>();

    final timeoutExceeded = Completer<void>();
    final timeoutTimer = Timer(timeout, () {
      if (!timeoutExceeded.isCompleted) timeoutExceeded.complete();
    });
    late final Object signal;
    try {
      signal = await Future.any<Object>([
        process.exitCode,
        timeoutExceeded.future.then((_) => const _GitProcessTimedOut()),
        outputLimitExceeded.future.then(
          (_) => const _GitProcessOutputLimitExceeded(),
        ),
      ]);
    } finally {
      timeoutTimer.cancel();
    }

    if (signal is int) {
      await Future.wait([stdoutDone, stderrDone]);
      return _GitProcessResult(
        stdout: stdoutBuffer.text,
        stderr: stderrBuffer.text,
        exitCode: signal,
        timedOut: false,
        outputLimitExceeded: stdoutBuffer.exceeded || stderrBuffer.exceeded,
      );
    }

    await _terminateProcessTree(
      process.pid,
      ProcessSignal.sigterm,
      environment: processEnvironment,
    );
    final exitCode = await _awaitProcessExit(
      process,
      environment: processEnvironment,
    );
    await Future.wait([stdoutDone, stderrDone]);
    return _GitProcessResult(
      stdout: stdoutBuffer.text,
      stderr: stderrBuffer.text,
      exitCode: exitCode,
      timedOut: signal is _GitProcessTimedOut,
      outputLimitExceeded: signal is _GitProcessOutputLimitExceeded,
    );
  }

  void _checkGitResult(_GitProcessResult result, List<String> args) {
    if (result.timedOut) {
      throw TimeoutException('patch capture git command timed out', timeout);
    }
    if (result.outputLimitExceeded) {
      throw ProcessException(
        gitExecutable,
        args,
        'patch capture git output exceeded $maxOutputChars characters\n'
        '${result.stdout}\n${result.stderr}',
        -1,
      );
    }
    if (result.exitCode != 0) {
      throw ProcessException(
        gitExecutable,
        args,
        result.stderr,
        result.exitCode,
      );
    }
  }

  Future<int> _awaitProcessExit(
    Process process, {
    required Map<String, String> environment,
  }) {
    return process.exitCode.timeout(
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

  Map<String, String> _gitEnvironment() {
    return benchmarkSubprocessEnvironment(
      baseEnvironment: baseEnvironment,
      additionalDeniedKeys: {
        ...deniedEnvironmentKeys,
        'HOME',
        'XDG_CONFIG_HOME',
        'XDG_CONFIG_DIRS',
      },
    )..addAll(const {'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TERMINAL_PROMPT': '0'});
  }
}

Future<void> _terminateProcessTree(
  int pid,
  ProcessSignal signal, {
  required Map<String, String> environment,
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
  required Map<String, String> environment,
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

Future<List<int>> _childPids(
  int pid, {
  required Map<String, String> environment,
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
  required Map<String, String> environment,
}) async {
  try {
    return await Process.run(
      executable,
      arguments,
      runInShell: false,
      environment: environment,
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

class _GitProcessResult {
  const _GitProcessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.timedOut,
    required this.outputLimitExceeded,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
  final bool timedOut;
  final bool outputLimitExceeded;
}

class _BoundedTextCollector {
  _BoundedTextCollector(this.maxChars);

  final int maxChars;
  final _buffer = StringBuffer();
  bool exceeded = false;

  String get text => _buffer.toString();

  void write(String chunk) {
    if (exceeded) return;
    final remaining = maxChars - _buffer.length;
    if (chunk.length <= remaining) {
      _buffer.write(chunk);
      return;
    }
    if (remaining > 0) {
      _buffer.write(chunk.substring(0, remaining));
    }
    exceeded = true;
  }
}

class _GitProcessTimedOut {
  const _GitProcessTimedOut();
}

class _GitProcessOutputLimitExceeded {
  const _GitProcessOutputLimitExceeded();
}
