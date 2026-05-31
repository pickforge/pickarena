import 'dart:async';
import 'dart:io';

import 'package:dart_arena/core/path_safety.dart';
import 'package:dart_arena/core/task_workspace.dart';
import 'package:dart_arena/core/workspace_path.dart';
import 'package:path/path.dart' as p;

sealed class PrepareResult {
  const PrepareResult();
}

class PrepareOk extends PrepareResult {
  const PrepareOk();
}

class PrepareFailed extends PrepareResult {
  const PrepareFailed(this.stderr);
  final String stderr;
}

typedef WorkdirCancellationCheck = void Function();
typedef WorkdirRemainingTimeout = Duration? Function();

class WorkdirManager {
  WorkdirManager({
    required this.root,
    this.dartExecutable = 'dart',
    this.flutterExecutable = 'flutter',
  });

  final Directory root;
  final String dartExecutable;
  final String flutterExecutable;

  String _sanitizePathSegment(String segment) =>
      safePathSegment(segment, prefix: 'segment');

  Future<Directory> createTaskWorkdir({
    required String runId,
    required String providerId,
    required String modelId,
    required String taskId,
    required Map<String, String> fixtures,
    required String? generatedCode,
    required String generatedCodePath,
    int trialIndex = 0,
  }) async {
    final taskPath = trialIndex == 0
        ? taskId
        : p.join(taskId, 'trial_$trialIndex');
    final dir = Directory(
      p.join(
        root.path,
        'runs',
        runId,
        providerId,
        safePathSegment(modelId, prefix: 'model'),
        taskPath,
      ),
    );
    await dir.create(recursive: true);

    for (final entry in fixtures.entries) {
      final f = File(p.join(dir.path, entry.key));
      await f.parent.create(recursive: true);
      await f.writeAsString(entry.value);
    }

    if (generatedCode != null) {
      final f = File(p.join(dir.path, generatedCodePath));
      await f.parent.create(recursive: true);
      await f.writeAsString(generatedCode);
    }

    return dir;
  }

  Future<Directory> createAgenticTaskWorkdir({
    required String runId,
    required String providerId,
    required String modelId,
    required String taskId,
    required TaskWorkspace workspace,
    int trialIndex = 0,
  }) async {
    final taskPath = p.join(_sanitizePathSegment(taskId), 'trial_$trialIndex');
    final dir = Directory(
      p.join(
        root.path,
        'runs',
        runId,
        providerId,
        safePathSegment(modelId, prefix: 'model'),
        taskPath,
      ),
    );
    await _recreateCleanAgenticDirectory(dir);

    final fixtureRootPath = workspace.fixtureRootPath;
    if (fixtureRootPath != null) {
      await _copyFixtureRoot(Directory(fixtureRootPath), dir);
    }

    for (final entry in workspace.files.entries) {
      final f = resolveWorkspaceFile(dir, entry.key);
      if (_shouldExcludeWorkspacePath(entry.key)) continue;
      await f.parent.create(recursive: true);
      await f.writeAsString(entry.value);
    }

    await _initializeBaselineGit(dir);
    return dir;
  }

  Future<PrepareResult> prepare(
    Directory workDir, {
    bool isFlutter = false,
    WorkdirRemainingTimeout? remainingTimeout,
    WorkdirCancellationCheck? cancellationCheck,
    Future<void>? cancellationSignal,
  }) async {
    final exe = isFlutter ? flutterExecutable : dartExecutable;
    final offline = await _runPrepareProcess(
      exe,
      ['pub', 'get', '--offline'],
      workDir,
      remainingTimeout: remainingTimeout,
      cancellationCheck: cancellationCheck,
      cancellationSignal: cancellationSignal,
    );
    if (offline.exitCode == 0) return const PrepareOk();

    final online = await _runPrepareProcess(
      exe,
      ['pub', 'get'],
      workDir,
      remainingTimeout: remainingTimeout,
      cancellationCheck: cancellationCheck,
      cancellationSignal: cancellationSignal,
    );
    if (online.exitCode == 0) return const PrepareOk();

    return PrepareFailed(
      online.stderr.toString().isEmpty
          ? offline.stderr.toString()
          : online.stderr.toString(),
    );
  }

  Future<_PrepareProcessResult> _runPrepareProcess(
    String executable,
    List<String> args,
    Directory workDir, {
    WorkdirRemainingTimeout? remainingTimeout,
    WorkdirCancellationCheck? cancellationCheck,
    Future<void>? cancellationSignal,
  }) async {
    cancellationCheck?.call();
    final process = await Process.start(
      executable,
      args,
      workingDirectory: workDir.path,
      runInShell: false,
    );
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout
        .transform(systemEncoding.decoder)
        .listen(stdoutBuffer.write)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(systemEncoding.decoder)
        .listen(stderrBuffer.write)
        .asFuture<void>();

    final timeout = remainingTimeout?.call();
    if (timeout != null && timeout.compareTo(Duration.zero) <= 0) {
      await _terminateProcessTree(process.pid, ProcessSignal.sigterm);
      await _awaitProcessExit(process);
      await Future.wait([stdoutDone, stderrDone]);
      throw TimeoutException('prepare timed out', timeout);
    }

    final signal = await Future.any<_PrepareProcessSignal>([
      process.exitCode.then(_PrepareProcessExit.new),
      if (timeout != null)
        Future<void>.delayed(
          timeout,
        ).then((_) => _PrepareProcessTimedOut(timeout)),
      if (cancellationSignal != null)
        cancellationSignal.then((_) => const _PrepareProcessCancelled()),
    ]);

    if (signal is _PrepareProcessExit) {
      await Future.wait([stdoutDone, stderrDone]);
      cancellationCheck?.call();
      return _PrepareProcessResult(
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        exitCode: signal.exitCode,
      );
    }

    await _terminateProcessTree(process.pid, ProcessSignal.sigterm);
    await _awaitProcessExit(process);
    await Future.wait([stdoutDone, stderrDone]);
    if (signal is _PrepareProcessTimedOut) {
      throw TimeoutException('prepare timed out', signal.timeout);
    }
    throw TimeoutException('prepare cancelled');
  }

  Future<void> _awaitProcessExit(Process process) async {
    await process.exitCode.timeout(
      const Duration(seconds: 2),
      onTimeout: () async {
        await _terminateProcessTree(process.pid, ProcessSignal.sigkill);
        return -1;
      },
    );
  }

  Future<void> _terminateProcessTree(int pid, ProcessSignal signal) async {
    if (Platform.isWindows) {
      final args = ['/PID', '$pid', '/T'];
      if (signal == ProcessSignal.sigkill) args.add('/F');
      await _tryRunProcess('taskkill', args);
      return;
    }

    final descendants = await _descendantPids(pid);
    for (final childPid in descendants.reversed) {
      _killPid(childPid, signal);
    }
    _killPid(pid, signal);
  }

  Future<List<int>> _descendantPids(int pid) async {
    final descendants = <int>[];
    for (final childPid in await _childPids(pid)) {
      descendants.add(childPid);
      descendants.addAll(await _descendantPids(childPid));
    }
    return descendants;
  }

  Future<List<int>> _childPids(int pid) async {
    final pgrep = await _tryRunProcess('pgrep', ['-P', '$pid']);
    if (pgrep?.exitCode == 0) {
      return _parsePids(pgrep!.stdout.toString());
    }

    final ps = await _tryRunProcess('ps', ['-o', 'pid=', '--ppid', '$pid']);
    if (ps?.exitCode == 0) {
      return _parsePids(ps!.stdout.toString());
    }
    return const [];
  }

  Future<ProcessResult?> _tryRunProcess(
    String executable,
    List<String> arguments,
  ) async {
    try {
      return await Process.run(executable, arguments);
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
    if (!_tryKillPid(pid, signal)) {
      _tryKillPid(pid, null);
    }
  }

  bool _tryKillPid(int pid, ProcessSignal? signal) {
    try {
      return signal == null
          ? Process.killPid(pid)
          : Process.killPid(pid, signal);
    } on Object {
      return false;
    }
  }

  Future<void> _copyFixtureRoot(Directory sourceRoot, Directory target) async {
    if (!await sourceRoot.exists()) {
      throw ArgumentError.value(
        sourceRoot.path,
        'fixtureRootPath',
        'must exist',
      );
    }
    await for (final entity in sourceRoot.list(recursive: true)) {
      if (entity is Link) continue;
      final relative = p.relative(entity.path, from: sourceRoot.path);
      if (_shouldExcludeWorkspacePath(relative)) continue;
      if (entity is Directory) {
        await Directory(p.join(target.path, relative)).create(recursive: true);
      } else if (entity is File) {
        final file = resolveWorkspaceFile(target, relative);
        await file.parent.create(recursive: true);
        await entity.copy(file.path);
      }
    }
  }

  bool _shouldExcludeWorkspacePath(String relativePath) {
    final parts = p.split(p.normalize(relativePath));
    final lowerParts = parts.map((s) => s.toLowerCase()).toList();
    if (lowerParts.any(
      (s) =>
          s == '.git' ||
          s == '_hidden' ||
          s == 'reference' ||
          s == '_reference' ||
          s == 'author_notes' ||
          s == '_author' ||
          s == 'task_qa',
    )) {
      return true;
    }
    final basename = lowerParts.isEmpty ? '' : lowerParts.last;
    return basename == 'author_notes.md' ||
        basename == 'qa_report.md' ||
        basename == 'task_qa_report.md';
  }

  Future<void> _recreateCleanAgenticDirectory(Directory dir) async {
    final runsRoot = p.normalize(p.join(p.absolute(root.path), 'runs'));
    final targetPath = p.normalize(p.absolute(dir.path));
    if (!p.isWithin(runsRoot, targetPath)) {
      throw StateError(
        'refusing to clean workdir outside runs root: $targetPath',
      );
    }
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  }

  Future<void> _initializeBaselineGit(Directory dir) async {
    final gitignore = File(p.join(dir.path, '.gitignore'));
    if (!await gitignore.exists()) {
      await gitignore.writeAsString(
        '.dart_tool/\nbuild/\n.packages\npubspec.lock\n',
      );
    }
    await _runGit(dir, ['init']);
    await _runGit(dir, ['config', 'user.email', 'dart-arena@example.invalid']);
    await _runGit(dir, ['config', 'user.name', 'dart_arena']);
    await _runGit(dir, ['add', '.']);
    await _runGit(dir, ['commit', '--allow-empty', '-m', 'baseline']);
  }

  Future<void> _runGit(Directory dir, List<String> args) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: dir.path,
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        args,
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }
  }
}

class _PrepareProcessResult {
  const _PrepareProcessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
}

sealed class _PrepareProcessSignal {
  const _PrepareProcessSignal();
}

class _PrepareProcessExit extends _PrepareProcessSignal {
  const _PrepareProcessExit(this.exitCode);

  final int exitCode;
}

class _PrepareProcessTimedOut extends _PrepareProcessSignal {
  const _PrepareProcessTimedOut(this.timeout);

  final Duration timeout;
}

class _PrepareProcessCancelled extends _PrepareProcessSignal {
  const _PrepareProcessCancelled();
}
