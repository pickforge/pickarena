import 'dart:io';

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

class WorkdirManager {
  WorkdirManager({required this.root});

  final Directory root;

  String _sanitizePathSegment(String segment) => Uri.encodeComponent(segment);

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
        _sanitizePathSegment(modelId),
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
        _sanitizePathSegment(modelId),
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
  }) async {
    final exe = isFlutter ? 'flutter' : 'dart';
    final offline = await Process.run(exe, [
      'pub',
      'get',
      '--offline',
    ], workingDirectory: workDir.path);
    if (offline.exitCode == 0) return const PrepareOk();

    final online = await Process.run(exe, [
      'pub',
      'get',
    ], workingDirectory: workDir.path);
    if (online.exitCode == 0) return const PrepareOk();

    return PrepareFailed(
      online.stderr.toString().isEmpty
          ? offline.stderr.toString()
          : online.stderr.toString(),
    );
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
