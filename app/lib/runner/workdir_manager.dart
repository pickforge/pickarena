import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/patch_capture.dart';
import 'package:dart_arena/core/path_safety.dart';
import 'package:dart_arena/core/task_workspace.dart';
import 'package:dart_arena/core/workspace_path.dart';
import 'package:dart_arena/runner/bounded_subprocess.dart';
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
    await _sanitizeGradingWorkspace(gradingDir);
  }

  Future<void> _sanitizeGradingWorkspace(Directory dir) async {
    final toRemove = <FileSystemEntity>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      final relative = p
          .relative(entity.path, from: dir.path)
          .replaceAll('\\', '/');
      if (relative.split('/').first == '.git') continue;
      if (entity is Link || _shouldExcludeWorkspacePath(relative)) {
        toRemove.add(entity);
      }
    }
    for (final entity in toRemove) {
      try {
        await entity.delete(recursive: true);
      } on FileSystemException {
        continue;
      }
    }
  }

  Future<WorkdirIsolationEvidence> collectWorkspaceIsolationEvidence(
    Directory workDir, {
    bool ignoreBenchmarkInfrastructure = false,
  }) async {
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

        if (_isRestrictedContentPath(normalizedRelativePath)) {
          restrictedPathCount++;
          continue;
        }
        if (ignoreBenchmarkInfrastructure &&
            _isBenchmarkInfrastructurePath(normalizedRelativePath)) {
          continue;
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
            final fileSize = (await entity.stat()).size;
            final fileDigest = ignoreBenchmarkInfrastructure
                ? sha256
                      .convert(
                        utf8.encode('$normalizedRelativePath\u0000$fileSize'),
                      )
                      .toString()
                : (await sha256.bind(entity.openRead()).first).toString();
            manifestEntries.add(
              '$normalizedRelativePath\u0000$fileDigest\u0000$fileSize',
            );
            visibleFileCount++;
            visibleBytes += fileSize;
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

  Future<String> resetPatchBaseline(Directory workDir) {
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
    final timeout = remainingTimeout?.call();
    final result = await runBoundedSubprocess(
      executable: processStart.executable,
      arguments: processStart.arguments,
      workingDirectory: processStart.workingDirectory,
      environment: processStart.environment,
      maxOutputBytes: prepareMaxOutputChars,
      timeout: timeout,
      cancellationSignal: cancellationSignal,
      helperEnvironment: benchmarkSubprocessEnvironment(
        additionalDeniedKeys: deniedEnvironmentKeys,
      ),
    );
    if (result.termination == BoundedSubprocessTermination.exited) {
      cancellationCheck?.call();
      return _PrepareProcessResult(
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
        outputLimitExceeded: false,
      );
    }
    if (result.termination == BoundedSubprocessTermination.timedOut) {
      throw TimeoutException('prepare timed out', timeout);
    }
    if (result.outputLimitExceeded) {
      return _PrepareProcessResult(
        stdout: result.stdout,
        stderr:
            'prepare output exceeded $prepareMaxOutputChars characters\n'
            '${result.stdout}\n${result.stderr}',
        exitCode: -1,
        outputLimitExceeded: true,
      );
    }
    throw TimeoutException('prepare cancelled');
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

  bool _isBenchmarkInfrastructurePath(String relativePath) {
    final normalized = p
        .normalize(relativePath)
        .replaceAll('\\', '/')
        .toLowerCase();
    final topLevel = normalized.split('/').first;
    if (const {
      '.git',
      '.dart_tool',
      '.dart_arena',
      '.cache',
      '.dartserver',
      'appdata',
      'build',
    }.contains(topLevel)) {
      return true;
    }
    return normalized == '.config/tool_state' ||
        normalized == '.flutter' ||
        normalized == '.flutter-plugins' ||
        normalized == '.flutter-plugins-dependencies' ||
        normalized == '.packages' ||
        normalized == 'pubspec.lock';
  }

  bool _isRestrictedContentPath(String relativePath) {
    final lowerParts = p
        .split(p.normalize(relativePath))
        .map((part) => part.toLowerCase())
        .toList();
    if (lowerParts.any(
      (part) => const {
        '_hidden',
        'reference',
        '_reference',
        'author_notes',
        '_author',
        'task_qa',
      }.contains(part),
    )) {
      return true;
    }
    final basename = lowerParts.isEmpty ? '' : lowerParts.last;
    return const {
      'author_notes.md',
      'qa_report.md',
      'task_qa_report.md',
    }.contains(basename);
  }

  bool _shouldExcludeWorkspacePath(String relativePath) {
    final lowerParts = p
        .split(p.normalize(relativePath))
        .map((part) => part.toLowerCase());
    return lowerParts.contains('.git') ||
        _isRestrictedContentPath(relativePath);
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

  Future<String> _initializeBaselineGit(Directory dir) async {
    await _ensureBaselineGitignore(dir);
    await _runGit(dir, ['init']);
    await _runGit(dir, ['config', 'user.email', 'dart-arena@example.invalid']);
    await _runGit(dir, ['config', 'user.name', 'dart_arena']);
    await _runGit(dir, ['add', '.']);
    await _runGit(dir, ['commit', '--allow-empty', '-m', 'baseline']);
    await _runGit(dir, ['tag', '-f', patchBaselineRef]);
    final head = await _runGit(dir, ['rev-parse', 'HEAD']);
    return head.trim();
  }

  Future<void> _ensureBaselineGitignore(Directory dir) async {
    const ignoredPaths = [
      '.dart_tool/',
      '.dart_arena/',
      '.cache/',
      '.config/tool_state',
      '.dartServer/',
      '.flutter',
      '.flutter-plugins',
      '.flutter-plugins-dependencies',
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

  Future<String> _runGit(
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

    final environment = _baselineGitEnvironment();
    final result = await runBoundedSubprocess(
      executable: gitExecutable,
      arguments: args,
      workingDirectory: dir.path,
      environment: environment,
      maxOutputBytes: gitMaxOutputChars,
      timeout: gitTimeout,
      stdinBytes: stdin == null ? null : utf8.encode(stdin),
      helperEnvironment: environment,
    );
    if (result.termination == BoundedSubprocessTermination.timedOut) {
      throw TimeoutException(
        'baseline git initialization timed out',
        gitTimeout,
      );
    }
    if (result.outputLimitExceeded) {
      throw ProcessException(
        gitExecutable,
        args,
        'baseline git output exceeded $gitMaxOutputChars characters\n'
        '${result.stdout}\n${result.stderr}',
        -1,
      );
    }
    if (result.exitCode != 0) {
      throw ProcessException(
        gitExecutable,
        args,
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }
    return result.stdout;
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
