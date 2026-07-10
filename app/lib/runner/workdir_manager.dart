import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/patch_capture.dart';
import 'package:dart_arena/core/path_safety.dart';
import 'package:dart_arena/core/task_workspace.dart';
import 'package:dart_arena/core/workspace_path.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';
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

class WorkdirIsolationEvidence {
  const WorkdirIsolationEvidence({
    required this.workdirUnderRunsRoot,
    required this.rootConfined,
    required this.relativePathsOnly,
    required this.restrictedPathsAbsent,
    required this.symlinksFollowed,
    required this.restrictedPathCount,
    required this.symlinkCount,
    required this.unreadableFileCount,
    required this.visibleFileCount,
    required this.visibleBytes,
    required this.visibleManifestSha256,
  });

  final bool workdirUnderRunsRoot;
  final bool rootConfined;
  final bool relativePathsOnly;
  final bool restrictedPathsAbsent;
  final bool symlinksFollowed;
  final int restrictedPathCount;
  final int symlinkCount;
  final int unreadableFileCount;
  final int visibleFileCount;
  final int visibleBytes;
  final String visibleManifestSha256;

  Map<String, Object?> toJson() => {
    'workdirUnderRunsRoot': workdirUnderRunsRoot,
    'rootConfined': rootConfined,
    'relativePathsOnly': relativePathsOnly,
    'restrictedPathsAbsent': restrictedPathsAbsent,
    'restrictedPathCount': restrictedPathCount,
    'symlinkCount': symlinkCount,
    'unreadableFileCount': unreadableFileCount,
    'visibleFileCount': visibleFileCount,
    'visibleBytes': visibleBytes,
    'visibleManifestSha256': visibleManifestSha256,
    'symlinksFollowed': symlinksFollowed,
  };
}

typedef WorkdirCancellationCheck = void Function();
typedef WorkdirRemainingTimeout = Duration? Function();

class WorkdirManager {
  WorkdirManager({
    required this.root,
    this.dartExecutable = 'dart',
    this.flutterExecutable = 'flutter',
    this.gitExecutable = 'git',
    this.gitTimeout = const Duration(seconds: 15),
    this.gitMaxOutputChars = 64 * 1024,
    this.prepareMaxOutputChars = 1024 * 1024,
    Iterable<String> deniedEnvironmentKeys = const [],
    this.allowReentrantFlutterTool = false,
    this.pathSegmentStemChars = 8,
  }) : assert(gitMaxOutputChars > 0),
       assert(prepareMaxOutputChars > 0),
       assert(pathSegmentStemChars > 0),
       deniedEnvironmentKeys = Set.unmodifiable(deniedEnvironmentKeys);

  final Directory root;
  final String dartExecutable;
  final String flutterExecutable;
  final String gitExecutable;
  final Duration gitTimeout;
  final int gitMaxOutputChars;
  final int prepareMaxOutputChars;
  final Set<String> deniedEnvironmentKeys;
  final bool allowReentrantFlutterTool;
  final int pathSegmentStemChars;

  String _workdirPathSegment(String segment, {String prefix = 'segment'}) =>
      safePathSegment(
        segment,
        prefix: prefix,
        maxStemChars: pathSegmentStemChars,
      );

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
    final taskSegment = _workdirPathSegment(taskId);
    final taskPath = trialIndex == 0
        ? taskSegment
        : p.join(taskSegment, 'trial_$trialIndex');
    final dir = Directory(
      p.join(
        root.path,
        'runs',
        _workdirPathSegment(runId),
        _workdirPathSegment(providerId),
        _workdirPathSegment(modelId, prefix: 'model'),
        taskPath,
      ),
    );
    await _recreateCleanRunDirectory(dir);

    for (final entry in fixtures.entries) {
      final f = resolveWorkspaceFile(dir, entry.key);
      await f.parent.create(recursive: true);
      await f.writeAsString(entry.value);
    }

    if (generatedCode != null) {
      final f = resolveWorkspaceFile(dir, generatedCodePath);
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
    final taskPath = p.join(_workdirPathSegment(taskId), 'trial_$trialIndex');
    final dir = Directory(
      p.join(
        root.path,
        'runs',
        _workdirPathSegment(runId),
        _workdirPathSegment(providerId),
        _workdirPathSegment(modelId, prefix: 'model'),
        taskPath,
      ),
    );
    return _assembleAgenticWorkspace(dir, workspace);
  }

  Future<Directory> createAgenticGradingWorkdir({
    required String runId,
    required String providerId,
    required String modelId,
    required String taskId,
    required TaskWorkspace workspace,
    int trialIndex = 0,
  }) {
    final taskPath = p.join(
      _workdirPathSegment(taskId),
      'trial_${trialIndex}_grading',
    );
    final dir = Directory(
      p.join(
        root.path,
        'runs',
        _workdirPathSegment(runId),
        _workdirPathSegment(providerId),
        _workdirPathSegment(modelId, prefix: 'model'),
        taskPath,
      ),
    );
    return _assembleAgenticWorkspace(dir, workspace);
  }

  Future<void> applyCapturedPatch(Directory gradingDir, String patch) async {
    if (patch.isEmpty) return;
    await _runGit(gradingDir, [
      'apply',
      '--binary',
      '--whitespace=nowarn',
      '-',
    ], stdin: patch);
  }

  Future<WorkdirIsolationEvidence> collectWorkspaceIsolationEvidence(
    Directory workDir,
  ) async {
    final rootPath = p.normalize(p.absolute(root.path));
    final runsRoot = p.normalize(p.join(rootPath, 'runs'));
    final workDirPath = p.normalize(p.absolute(workDir.path));
    final workdirUnderRunsRoot = p.isWithin(runsRoot, workDirPath);
    var rootConfined = _isSameOrWithin(rootPath, workDirPath);
    var relativePathsOnly = true;
    var restrictedPathCount = 0;
    var symlinkCount = 0;
    var unreadableFileCount = 0;
    var visibleFileCount = 0;
    var visibleBytes = 0;
    final manifestEntries = <String>[];

    try {
      await for (final entity in workDir.list(
        recursive: true,
        followLinks: false,
      )) {
        final entityPath = p.normalize(p.absolute(entity.path));
        if (!_isSameOrWithin(workDirPath, entityPath)) {
          rootConfined = false;
        }
        final relativePath = p.normalize(
          p.relative(entityPath, from: workDirPath),
        );
        final normalizedRelativePath = relativePath.replaceAll('\\', '/');
        if (p.isAbsolute(relativePath) ||
            normalizedRelativePath == '.' ||
            normalizedRelativePath.split('/').contains('..')) {
          relativePathsOnly = false;
        }

        final restricted = _shouldExcludeWorkspacePath(normalizedRelativePath);
        if (restricted) {
          restrictedPathCount++;
          continue;
        }

        if (entity is Link) {
          symlinkCount++;
          continue;
        }

        if (entity is File) {
          try {
            final bytes = await entity.readAsBytes();
            final fileDigest = sha256.convert(bytes).toString();
            manifestEntries.add(
              '$normalizedRelativePath\u0000$fileDigest\u0000${bytes.length}',
            );
            visibleFileCount++;
            visibleBytes += bytes.length;
          } on FileSystemException {
            unreadableFileCount++;
          }
        }
      }
    } on FileSystemException {
      unreadableFileCount++;
      rootConfined = false;
    }

    manifestEntries.sort();
    final visibleManifestSha256 = sha256
        .convert(utf8.encode(manifestEntries.join('\n')))
        .toString();

    return WorkdirIsolationEvidence(
      workdirUnderRunsRoot: workdirUnderRunsRoot,
      rootConfined: rootConfined,
      relativePathsOnly: relativePathsOnly,
      restrictedPathsAbsent: restrictedPathCount == 0,
      symlinksFollowed: false,
      restrictedPathCount: restrictedPathCount,
      symlinkCount: symlinkCount,
      unreadableFileCount: unreadableFileCount,
      visibleFileCount: visibleFileCount,
      visibleBytes: visibleBytes,
      visibleManifestSha256: visibleManifestSha256,
    );
  }

  Future<PrepareResult> prepare(
    Directory workDir, {
    bool isFlutter = false,
    bool allowInternet = true,
    WorkdirRemainingTimeout? remainingTimeout,
    WorkdirCancellationCheck? cancellationCheck,
    Future<void>? cancellationSignal,
    GeneratedCodeSandbox? generatedCodeSandbox,
    int? maxCpuCores,
  }) async {
    final exe = isFlutter ? flutterExecutable : dartExecutable;
    final offline = await _runPrepareProcess(
      exe,
      ['pub', 'get', '--offline'],
      workDir,
      remainingTimeout: remainingTimeout,
      cancellationCheck: cancellationCheck,
      cancellationSignal: cancellationSignal,
      allowReentrantFlutterTool: isFlutter && allowReentrantFlutterTool,
      generatedCodeSandbox: generatedCodeSandbox,
      sandboxAllowInternet: allowInternet,
      maxCpuCores: maxCpuCores,
    );
    if (offline.exitCode == 0) return const PrepareOk();
    if (offline.outputLimitExceeded) return PrepareFailed(offline.stderr);

    if (!allowInternet) {
      return PrepareFailed(_networkDisabledPrepareFailure(offline.stderr));
    }

    final online = await _runPrepareProcess(
      exe,
      ['pub', 'get'],
      workDir,
      remainingTimeout: remainingTimeout,
      cancellationCheck: cancellationCheck,
      cancellationSignal: cancellationSignal,
      allowReentrantFlutterTool: isFlutter && allowReentrantFlutterTool,
      generatedCodeSandbox: generatedCodeSandbox,
      sandboxAllowInternet: true,
      maxCpuCores: maxCpuCores,
    );
    if (online.exitCode == 0) return const PrepareOk();
    if (online.outputLimitExceeded) return PrepareFailed(online.stderr);

    return PrepareFailed(
      online.stderr.toString().isEmpty
          ? offline.stderr.toString()
          : online.stderr.toString(),
    );
  }

  Future<void> resetPatchBaseline(Directory workDir) {
    return _initializeBaselineGit(workDir);
  }

  String _networkDisabledPrepareFailure(Object stderr) {
    final message = stderr.toString();
    if (message.trim().isEmpty) {
      return 'Offline dependency resolution failed and network access is disabled by task policy.';
    }
    return '$message\nOffline dependency resolution failed and network access is disabled by task policy.';
  }

  Future<_PrepareProcessResult> _runPrepareProcess(
    String executable,
    List<String> args,
    Directory workDir, {
    WorkdirRemainingTimeout? remainingTimeout,
    WorkdirCancellationCheck? cancellationCheck,
    Future<void>? cancellationSignal,
    bool allowReentrantFlutterTool = false,
    GeneratedCodeSandbox? generatedCodeSandbox,
    bool sandboxAllowInternet = false,
    int? maxCpuCores,
  }) async {
    cancellationCheck?.call();
    final environment = benchmarkSubprocessEnvironment(
      additionalDeniedKeys: deniedEnvironmentKeys,
      allowReentrantFlutterTool: allowReentrantFlutterTool,
      homeDirectory: workDir.path,
    );
    final processStart = generatedCodeSandbox == null
        ? SandboxedProcessStart(
            executable: executable,
            arguments: args,
            workingDirectory: workDir.path,
            environment: environment,
          )
        : await generatedCodeSandbox.wrapProcess(
            executable: executable,
            arguments: args,
            workingDirectory: workDir.path,
            environment: environment,
            allowInternet: sandboxAllowInternet,
            resourceLimits: SandboxResourceLimits(cpuCores: maxCpuCores),
          );
    final process = await Process.start(
      processStart.executable,
      processStart.arguments,
      workingDirectory: processStart.workingDirectory,
      runInShell: false,
      environment: processStart.environment,
      includeParentEnvironment: false,
    );
    final stdoutBuffer = _BoundedTextCollector(prepareMaxOutputChars);
    final stderrBuffer = _BoundedTextCollector(prepareMaxOutputChars);
    final outputLimitExceeded = Completer<_PrepareProcessSignal>();
    void markOutputLimitExceeded() {
      if (!outputLimitExceeded.isCompleted) {
        outputLimitExceeded.complete(
          const _PrepareProcessOutputLimitExceeded(),
        );
      }
    }

    final stdoutText = process.stdout.transform(systemEncoding.decoder);
    final stderrText = process.stderr.transform(systemEncoding.decoder);
    final stdoutDone = stdoutText.listen((chunk) {
      stdoutBuffer.write(chunk);
      if (stdoutBuffer.exceeded) markOutputLimitExceeded();
    }).asFuture<void>();
    final stderrDone = stderrText.listen((chunk) {
      stderrBuffer.write(chunk);
      if (stderrBuffer.exceeded) markOutputLimitExceeded();
    }).asFuture<void>();

    final timeout = remainingTimeout?.call();
    if (timeout != null && timeout.compareTo(Duration.zero) <= 0) {
      await _terminateProcessTree(process.pid, ProcessSignal.sigterm);
      await _awaitProcessExit(process);
      await Future.wait([stdoutDone, stderrDone]);
      throw TimeoutException('prepare timed out', timeout);
    }

    final timeoutExceeded = Completer<_PrepareProcessSignal>();
    final timeoutTimer = timeout == null
        ? null
        : Timer(timeout, () {
            if (!timeoutExceeded.isCompleted) {
              timeoutExceeded.complete(_PrepareProcessTimedOut(timeout));
            }
          });
    late final _PrepareProcessSignal signal;
    try {
      signal = await Future.any<_PrepareProcessSignal>([
        process.exitCode.then(_PrepareProcessExit.new),
        if (timeout != null) timeoutExceeded.future,
        outputLimitExceeded.future,
        if (cancellationSignal != null)
          cancellationSignal.then((_) => const _PrepareProcessCancelled()),
      ]);
    } finally {
      timeoutTimer?.cancel();
    }

    if (signal is _PrepareProcessExit) {
      await Future.wait([stdoutDone, stderrDone]);
      cancellationCheck?.call();
      return _PrepareProcessResult(
        stdout: stdoutBuffer.text,
        stderr: stderrBuffer.text,
        exitCode: signal.exitCode,
        outputLimitExceeded: false,
      );
    }

    await _terminateProcessTree(process.pid, ProcessSignal.sigterm);
    await _awaitProcessExit(process);
    await Future.wait([stdoutDone, stderrDone]);
    if (signal is _PrepareProcessTimedOut) {
      throw TimeoutException('prepare timed out', signal.timeout);
    }
    if (signal is _PrepareProcessOutputLimitExceeded) {
      return _PrepareProcessResult(
        stdout: stdoutBuffer.text,
        stderr:
            'prepare output exceeded $prepareMaxOutputChars characters\n'
            '${stdoutBuffer.text}\n${stderrBuffer.text}',
        exitCode: -1,
        outputLimitExceeded: true,
      );
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
      return await Process.run(
        executable,
        arguments,
        runInShell: false,
        environment: benchmarkSubprocessEnvironment(
          additionalDeniedKeys: deniedEnvironmentKeys,
        ),
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
    await for (final entity in sourceRoot.list(
      recursive: true,
      followLinks: false,
    )) {
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

  Future<Directory> _assembleAgenticWorkspace(
    Directory dir,
    TaskWorkspace workspace,
  ) async {
    await _recreateCleanRunDirectory(dir);

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

  bool _isSameOrWithin(String parent, String child) {
    return p.equals(parent, child) || p.isWithin(parent, child);
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

  Future<void> _recreateCleanRunDirectory(Directory dir) async {
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
    await _ensureBaselineGitignore(dir);
    await _runGit(dir, ['init']);
    await _runGit(dir, ['config', 'user.email', 'dart-arena@example.invalid']);
    await _runGit(dir, ['config', 'user.name', 'dart_arena']);
    await _runGit(dir, ['add', '.']);
    await _runGit(dir, ['commit', '--allow-empty', '-m', 'baseline']);
    await _runGit(dir, ['tag', '-f', patchBaselineRef]);
  }

  Future<void> _ensureBaselineGitignore(Directory dir) async {
    const ignoredPaths = [
      '.dart_tool/',
      '.dart_arena/',
      '.cache/',
      '.config/tool_state',
      '.dartServer/',
      '.flutter',
      'AppData/',
      'build/',
      '.packages',
      'pubspec.lock',
    ];
    final gitignore = File(p.join(dir.path, '.gitignore'));
    final existing = await gitignore.exists()
        ? await gitignore.readAsString()
        : '';
    final lines = existing
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();
    final missing = ignoredPaths.where((path) => !lines.contains(path));
    if (missing.isEmpty && existing.isNotEmpty) return;
    final buffer = StringBuffer();
    if (existing.isNotEmpty) {
      buffer.write(existing);
      if (!existing.endsWith('\n')) buffer.writeln();
    }
    for (final path in missing) {
      buffer.writeln(path);
    }
    await gitignore.writeAsString(buffer.toString());
  }

  Future<void> _runGit(
    Directory dir,
    List<String> args, {
    String? stdin,
  }) async {
    if (gitTimeout.compareTo(Duration.zero) <= 0) {
      throw TimeoutException(
        'baseline git initialization timed out',
        gitTimeout,
      );
    }

    final process = await Process.start(
      gitExecutable,
      args,
      workingDirectory: dir.path,
      runInShell: false,
      environment: _baselineGitEnvironment(),
      includeParentEnvironment: false,
    );
    if (stdin != null) {
      process.stdin.add(utf8.encode(stdin));
      await process.stdin.close();
    }

    final stdoutBuffer = _BoundedTextCollector(gitMaxOutputChars);
    final stderrBuffer = _BoundedTextCollector(gitMaxOutputChars);
    final outputLimitExceeded = Completer<_GitProcessSignal>();
    void markOutputLimitExceeded() {
      if (!outputLimitExceeded.isCompleted) {
        outputLimitExceeded.complete(const _GitProcessOutputLimitExceeded());
      }
    }

    final stdoutText = process.stdout.transform(systemEncoding.decoder);
    final stderrText = process.stderr.transform(systemEncoding.decoder);
    final stdoutDone = stdoutText.listen((chunk) {
      stdoutBuffer.write(chunk);
      if (stdoutBuffer.exceeded) markOutputLimitExceeded();
    }).asFuture<void>();
    final stderrDone = stderrText.listen((chunk) {
      stderrBuffer.write(chunk);
      if (stderrBuffer.exceeded) markOutputLimitExceeded();
    }).asFuture<void>();

    final timeoutExceeded = Completer<_GitProcessSignal>();
    final timeoutTimer = Timer(gitTimeout, () {
      if (!timeoutExceeded.isCompleted) {
        timeoutExceeded.complete(_GitProcessTimedOut(gitTimeout));
      }
    });
    final signal = await Future.any<_GitProcessSignal>([
      process.exitCode.then(_GitProcessExit.new),
      timeoutExceeded.future,
      outputLimitExceeded.future,
    ]);
    timeoutTimer.cancel();

    if (signal is _GitProcessExit) {
      await Future.wait([stdoutDone, stderrDone]);
      if (signal.exitCode != 0) {
        throw ProcessException(
          gitExecutable,
          args,
          '${stdoutBuffer.text}\n${stderrBuffer.text}',
          signal.exitCode,
        );
      }
      return;
    }

    await _terminateProcessTree(process.pid, ProcessSignal.sigterm);
    await _awaitProcessExit(process);
    await Future.wait([stdoutDone, stderrDone]);

    if (signal is _GitProcessTimedOut) {
      throw TimeoutException(
        'baseline git initialization timed out',
        signal.timeout,
      );
    }

    throw ProcessException(
      gitExecutable,
      args,
      'baseline git output exceeded $gitMaxOutputChars characters\n'
      '${stdoutBuffer.text}\n${stderrBuffer.text}',
      -1,
    );
  }

  Map<String, String> _baselineGitEnvironment() {
    return benchmarkSubprocessEnvironment(
      additionalDeniedKeys: {
        ...deniedEnvironmentKeys,
        'HOME',
        'XDG_CONFIG_HOME',
        'XDG_CONFIG_DIRS',
      },
    )..addAll(const {'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TERMINAL_PROMPT': '0'});
  }
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

sealed class _GitProcessSignal {
  const _GitProcessSignal();
}

class _GitProcessExit extends _GitProcessSignal {
  const _GitProcessExit(this.exitCode);

  final int exitCode;
}

class _GitProcessTimedOut extends _GitProcessSignal {
  const _GitProcessTimedOut(this.timeout);

  final Duration timeout;
}

class _GitProcessOutputLimitExceeded extends _GitProcessSignal {
  const _GitProcessOutputLimitExceeded();
}

class _PrepareProcessResult {
  const _PrepareProcessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.outputLimitExceeded,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
  final bool outputLimitExceeded;
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

class _PrepareProcessOutputLimitExceeded extends _PrepareProcessSignal {
  const _PrepareProcessOutputLimitExceeded();
}
