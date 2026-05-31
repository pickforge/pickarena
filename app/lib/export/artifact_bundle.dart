import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/export/csv_exporter.dart';
import 'package:dart_arena/export/json_exporter.dart';
import 'package:dart_arena/export/md_exporter.dart';
import 'package:dart_arena/export/artifact_bundle_defaults.dart';
import 'package:dart_arena/export/run_manifest.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:path/path.dart' as p;

class ExportBundleResult {
  const ExportBundleResult({
    required this.directory,
    required this.warnings,
    required this.artifacts,
    required this.checksums,
  });

  final Directory directory;
  final List<BundleWarning> warnings;
  final List<ArtifactDescriptor> artifacts;
  final Map<String, String> checksums;
}

String runBundleDirectoryName(String runId) {
  return 'dart_arena_run_${_sanitizePathSegment(runId)}';
}

Future<ExportBundleResult> exportRunBundle({
  required RunSummary summary,
  required Directory targetDirectory,
  DateTime Function()? now,
  List<Directory>? allowedTrajectoryRoots,
  Future<Map<String, Object?>> Function()? environmentProvider,
  Future<String> Function()? appVersionProvider,
}) async {
  final existingType = await FileSystemEntity.type(
    targetDirectory.path,
    followLinks: false,
  );
  if (existingType != FileSystemEntityType.notFound) {
    throw FileSystemException(
      'Export bundle target already exists',
      targetDirectory.path,
    );
  }

  await targetDirectory.create(recursive: false);
  final artifactsRoot = Directory(p.join(targetDirectory.path, 'artifacts'));
  final responseDir = Directory(p.join(artifactsRoot.path, 'responses'));
  final patchDir = Directory(p.join(artifactsRoot.path, 'patches'));
  final trajectoryDir = Directory(p.join(artifactsRoot.path, 'trajectories'));
  await responseDir.create(recursive: true);
  await patchDir.create(recursive: true);
  await trajectoryDir.create(recursive: true);

  final taskRuns = _sortedTaskRuns(summary.taskRuns);
  final warnings = <BundleWarning>[];
  final artifacts = <ArtifactDescriptor>[];
  final responsePaths = <String, String>{};
  final patchPaths = <String, String>{};
  final trajectoryPaths = <String, String>{};
  final usedArtifactNames = <String>{};
  final roots = allowedTrajectoryRoots ?? await defaultAllowedTrajectoryRoots();

  for (final taskRun in taskRuns) {
    if (taskRun.responseText.isEmpty) {
      warnings.add(
        BundleWarning(
          code: 'missing_response_text',
          message: 'Task run has no response text to export.',
          taskRunId: taskRun.id,
        ),
      );
    } else {
      final artifact = await _writeTextArtifact(
        targetDirectory: targetDirectory,
        directory: responseDir,
        kind: 'response',
        taskRunId: taskRun.id,
        extension: '.txt',
        text: taskRun.responseText,
        usedNames: usedArtifactNames,
      );
      artifacts.add(artifact);
      responsePaths[taskRun.id] = artifact.path;
    }

    final patchText = taskRun.patchText;
    if (patchText == null || patchText.isEmpty) {
      if (taskRun.benchmarkTrack == 'agentic') {
        warnings.add(
          BundleWarning(
            code: 'missing_patch_text',
            message: 'Agentic task run has no patch text to export.',
            taskRunId: taskRun.id,
          ),
        );
      }
    } else {
      final artifact = await _writeTextArtifact(
        targetDirectory: targetDirectory,
        directory: patchDir,
        kind: 'patch',
        taskRunId: taskRun.id,
        extension: '.patch',
        text: patchText,
        usedNames: usedArtifactNames,
      );
      artifacts.add(artifact);
      patchPaths[taskRun.id] = artifact.path;
      if (patchText.contains('[patch truncated at')) {
        warnings.add(
          BundleWarning(
            code: 'truncated_patch_text',
            message: 'Patch text appears to be truncated.',
            taskRunId: taskRun.id,
          ),
        );
      }
    }

    final trajectoryLogPath = taskRun.trajectoryLogPath;
    if (trajectoryLogPath != null && trajectoryLogPath.isNotEmpty) {
      final artifact = await _copyTrajectoryArtifact(
        targetDirectory: targetDirectory,
        directory: trajectoryDir,
        taskRunId: taskRun.id,
        sourcePath: trajectoryLogPath,
        allowedRoots: roots,
        usedNames: usedArtifactNames,
        warnings: warnings,
      );
      if (artifact != null) {
        artifacts.add(artifact);
        trajectoryPaths[taskRun.id] = artifact.path;
      }
    }
  }

  artifacts.sort((a, b) => a.path.compareTo(b.path));

  String bundleTrajectoryPathFor(TaskRun taskRun) {
    return trajectoryPaths[taskRun.id] ?? '';
  }

  await _writeString(
    File(p.join(targetDirectory.path, 'results.csv')),
    runSummaryToCsv(
      summary,
      taskRuns: taskRuns,
      trajectoryPathFor: bundleTrajectoryPathFor,
    ),
  );
  await _writeString(
    File(p.join(targetDirectory.path, 'report.md')),
    runSummaryToMarkdown(
      summary,
      taskRuns: taskRuns,
      trajectoryPathFor: bundleTrajectoryPathFor,
    ),
  );
  await _writeString(
    File(p.join(targetDirectory.path, 'run_results.v1.json')),
    runResultsToJson(
      summary,
      responseArtifactsByTaskRunId: responsePaths,
      patchArtifactsByTaskRunId: patchPaths,
      trajectoryArtifactsByTaskRunId: trajectoryPaths,
    ),
  );

  final provenance = _decodeProvenance(summary.run.provenanceJson, warnings);
  final manifest = RunManifestV1(
    generatedAt: (now ?? DateTime.now)().toUtc().toIso8601String(),
    run: {
      'id': summary.run.id,
      'name': summary.run.name,
      'startedAt': summary.run.startedAt.toUtc().toIso8601String(),
      'completedAt': summary.run.completedAt?.toUtc().toIso8601String(),
    },
    appVersion: await (appVersionProvider ?? _readAppVersion)(),
    driftSchemaVersion: appDatabaseSchemaVersion,
    exportTool: const {'name': 'dart_arena_export_bundle', 'version': '1'},
    environment: await (environmentProvider ?? _defaultExportEnvironment)(),
    taskRuns: _manifestTaskRuns(taskRuns),
    counts: _counts(summary, taskRuns, artifacts, warnings),
    evaluatorIds: _evaluatorIds(summary),
    passSummary: _passSummary(summary),
    failureSummary: _failureSummary(taskRuns),
    artifacts: artifacts,
    checksumsPath: 'checksums.json',
    warnings: warnings,
    provenance: provenance,
  );
  await _writeString(
    File(p.join(targetDirectory.path, 'manifest.json')),
    const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
  );

  final checksums = await _writeChecksums(targetDirectory);
  return ExportBundleResult(
    directory: targetDirectory,
    warnings: List.unmodifiable(warnings),
    artifacts: List.unmodifiable(artifacts),
    checksums: checksums,
  );
}

Future<ArtifactDescriptor> _writeTextArtifact({
  required Directory targetDirectory,
  required Directory directory,
  required String kind,
  required String taskRunId,
  required String extension,
  required String text,
  required Set<String> usedNames,
}) async {
  final name = _artifactFileName(taskRunId, extension, usedNames);
  final file = File(p.join(directory.path, name));
  await _writeString(file, text);
  return ArtifactDescriptor(
    kind: kind,
    taskRunId: taskRunId,
    path: _relativePath(targetDirectory, file),
    bytes: await file.length(),
  );
}

Future<ArtifactDescriptor?> _copyTrajectoryArtifact({
  required Directory targetDirectory,
  required Directory directory,
  required String taskRunId,
  required String sourcePath,
  required List<Directory> allowedRoots,
  required Set<String> usedNames,
  required List<BundleWarning> warnings,
}) async {
  final canonicalSource = await _canonicalReadableRegularFile(
    sourcePath,
    taskRunId,
    warnings,
  );
  if (canonicalSource == null) return null;
  if (_isExcludedArtifactPath(canonicalSource)) {
    warnings.add(
      BundleWarning(
        code: 'excluded_artifact_path',
        message: 'Artifact path points at hidden, reference, or fixture data.',
        taskRunId: taskRunId,
        path: sourcePath,
      ),
    );
    return null;
  }

  final canonicalRoots = <String>[];
  for (final root in allowedRoots) {
    final canonical = await _canonicalDirectory(root);
    if (canonical != null) canonicalRoots.add(canonical);
  }
  final underAllowedRoot = canonicalRoots.any(
    (root) =>
        p.equals(canonicalSource, root) || p.isWithin(root, canonicalSource),
  );
  if (!underAllowedRoot) {
    warnings.add(
      BundleWarning(
        code: 'trajectory_out_of_root',
        message: 'Trajectory log is outside allowlisted app-controlled roots.',
        taskRunId: taskRunId,
        path: sourcePath,
      ),
    );
    return null;
  }

  final name = _artifactFileName(taskRunId, '.log', usedNames);
  final target = File(p.join(directory.path, name));
  try {
    await File(canonicalSource).copy(target.path);
  } on Object catch (e) {
    warnings.add(
      BundleWarning(
        code: 'unreadable_trajectory',
        message: 'Trajectory log could not be copied: $e',
        taskRunId: taskRunId,
        path: sourcePath,
      ),
    );
    return null;
  }
  return ArtifactDescriptor(
    kind: 'trajectory',
    taskRunId: taskRunId,
    path: _relativePath(targetDirectory, target),
    bytes: await target.length(),
  );
}

bool _isExcludedArtifactPath(String sourcePath) {
  final parts = p
      .split(p.normalize(sourcePath))
      .map((part) => part.toLowerCase())
      .toList();
  return parts.any(
    (part) =>
        part == '_hidden' ||
        part == 'hidden' ||
        part == 'reference' ||
        part == '_reference' ||
        part == 'fixtures',
  );
}

Future<String?> _canonicalReadableRegularFile(
  String sourcePath,
  String taskRunId,
  List<BundleWarning> warnings,
) async {
  if (!p.isAbsolute(sourcePath)) {
    warnings.add(
      BundleWarning(
        code: 'trajectory_relative_path',
        message: 'Trajectory log path is not absolute.',
        taskRunId: taskRunId,
        path: sourcePath,
      ),
    );
    return null;
  }
  final type = await FileSystemEntity.type(sourcePath, followLinks: false);
  if (type == FileSystemEntityType.link) {
    warnings.add(
      BundleWarning(
        code: 'trajectory_symlink',
        message: 'Trajectory log path is a symlink and was not copied.',
        taskRunId: taskRunId,
        path: sourcePath,
      ),
    );
    return null;
  }
  if (type != FileSystemEntityType.file) {
    warnings.add(
      BundleWarning(
        code: 'unreadable_trajectory',
        message: 'Trajectory log path is missing or is not a regular file.',
        taskRunId: taskRunId,
        path: sourcePath,
      ),
    );
    return null;
  }
  try {
    return await File(sourcePath).resolveSymbolicLinks();
  } on Object catch (e) {
    warnings.add(
      BundleWarning(
        code: 'unreadable_trajectory',
        message: 'Trajectory log path could not be canonicalized: $e',
        taskRunId: taskRunId,
        path: sourcePath,
      ),
    );
    return null;
  }
}

Future<String?> _canonicalDirectory(Directory directory) async {
  try {
    if (!await directory.exists()) return null;
    return await directory.resolveSymbolicLinks();
  } on Object {
    return null;
  }
}

Object? _decodeProvenance(
  String? provenanceJson,
  List<BundleWarning> warnings,
) {
  if (provenanceJson == null) {
    warnings.add(
      const BundleWarning(
        code: 'missing_run_provenance',
        message: 'Run has no provenance snapshot.',
      ),
    );
    return null;
  }
  try {
    return jsonDecode(provenanceJson);
  } on FormatException catch (e) {
    warnings.add(
      BundleWarning(
        code: 'malformed_run_provenance',
        message: 'Run provenance snapshot is not valid JSON: ${e.message}',
      ),
    );
    return null;
  }
}

Future<Map<String, String>> _writeChecksums(Directory targetDirectory) async {
  final files = <File>[];
  await for (final entity in targetDirectory.list(recursive: true)) {
    if (entity is! File) continue;
    if (_relativePath(targetDirectory, entity) == 'checksums.json') continue;
    files.add(entity);
  }
  files.sort(
    (a, b) => _relativePath(
      targetDirectory,
      a,
    ).compareTo(_relativePath(targetDirectory, b)),
  );

  final checksums = <String, String>{};
  for (final file in files) {
    checksums[_relativePath(targetDirectory, file)] =
        (await sha256.bind(file.openRead()).first).toString();
  }

  final json = {
    'schemaVersion': 1,
    'algorithm': 'sha256',
    'files': [
      for (final entry in checksums.entries)
        {'path': entry.key, 'sha256': entry.value},
    ],
  };
  await _writeString(
    File(p.join(targetDirectory.path, 'checksums.json')),
    const JsonEncoder.withIndent('  ').convert(json),
  );
  return Map.unmodifiable(checksums);
}

List<TaskRun> _sortedTaskRuns(List<TaskRun> taskRuns) {
  return taskRuns.toList()..sort((a, b) => a.id.compareTo(b.id));
}

List<Map<String, Object?>> _manifestTaskRuns(List<TaskRun> taskRuns) {
  return [
    for (final taskRun in taskRuns)
      {
        'taskRunId': taskRun.id,
        'taskId': taskRun.taskId,
        'taskVersion': taskRun.taskVersion,
        'benchmarkTrack': taskRun.benchmarkTrack,
        'harnessId': taskRun.harnessId,
        'trialIndex': taskRun.trialIndex,
        'providerId': taskRun.providerId,
        'modelId': taskRun.modelId,
      },
  ];
}

Map<String, Object?> _counts(
  RunSummary summary,
  List<TaskRun> taskRuns,
  List<ArtifactDescriptor> artifacts,
  List<BundleWarning> warnings,
) {
  final taskIds = taskRuns.map((taskRun) => taskRun.taskId).toSet();
  final providerIds = taskRuns.map((taskRun) => taskRun.providerId).toSet();
  final modelKeys = taskRuns
      .map((taskRun) => '${taskRun.providerId}\u0000${taskRun.modelId}')
      .toSet();
  final evaluationCount = summary.evaluationsByTaskRunId.values.fold<int>(
    0,
    (sum, evaluations) => sum + evaluations.length,
  );
  return {
    'taskRunCount': taskRuns.length,
    'taskCount': taskIds.length,
    'providerCount': providerIds.length,
    'modelCount': modelKeys.length,
    'evaluationCount': evaluationCount,
    'artifactCount': artifacts.length,
    'warningCount': warnings.length,
  };
}

List<String> _evaluatorIds(RunSummary summary) {
  return summary.evaluationsByTaskRunId.values
      .expand((evaluations) => evaluations)
      .map((evaluation) => evaluation.evaluatorId)
      .toSet()
      .toList()
    ..sort();
}

Map<String, Object?> _passSummary(RunSummary summary) {
  var primaryPassTrue = 0;
  var primaryPassFalse = 0;
  var primaryPassUnknown = 0;
  for (final taskRun in summary.taskRuns) {
    switch (taskRun.primaryPass) {
      case true:
        primaryPassTrue++;
      case false:
        primaryPassFalse++;
      case null:
        primaryPassUnknown++;
    }
  }
  final evaluations = summary.evaluationsByTaskRunId.values.expand(
    (evaluations) => evaluations,
  );
  var evaluationPassCount = 0;
  var evaluationFailCount = 0;
  for (final evaluation in evaluations) {
    if (evaluation.passed) {
      evaluationPassCount++;
    } else {
      evaluationFailCount++;
    }
  }
  return {
    'primaryPassTrue': primaryPassTrue,
    'primaryPassFalse': primaryPassFalse,
    'primaryPassUnknown': primaryPassUnknown,
    'evaluationPassCount': evaluationPassCount,
    'evaluationFailCount': evaluationFailCount,
  };
}

Map<String, int> _failureSummary(List<TaskRun> taskRuns) {
  final counts = <String, int>{};
  for (final taskRun in taskRuns) {
    final tag = taskRun.failureTag ?? 'unknown';
    counts[tag] = (counts[tag] ?? 0) + 1;
  }
  final keys = counts.keys.toList()..sort();
  return {for (final key in keys) key: counts[key]!};
}

Future<Map<String, Object?>> _defaultExportEnvironment() async {
  final gitCommit = await _processLine('git', ['rev-parse', 'HEAD']);
  final gitStatus = await _processLine('git', ['status', '--porcelain']);
  return {
    'dartVersion': Platform.version.split('\n').first,
    'flutterVersion': (await _flutterVersion()) ?? 'unknown',
    'gitCommit': gitCommit ?? 'unknown',
    'gitDirty': gitStatus?.isNotEmpty,
    'hostPlatform': Platform.operatingSystem,
    'locale': Platform.localeName,
    'operatingSystemVersion': Platform.operatingSystemVersion,
  };
}

Future<String> _readAppVersion() async {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (await pubspec.exists()) {
      final lines = await pubspec.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('version:')) {
          final version = trimmed.substring('version:'.length).trim();
          if (version.isNotEmpty) return version;
        }
      }
      return 'unknown';
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return 'unknown';
}

Future<String?> _flutterVersion() async {
  final result = await _runProcess('flutter', ['--version', '--machine']);
  if (result == null || result.exitCode != 0) return null;
  try {
    final decoded = jsonDecode(result.stdout.toString());
    if (decoded is Map<String, Object?>) {
      final version = decoded['frameworkVersion'];
      if (version is String && version.isNotEmpty) return version;
    }
  } on FormatException {
    return null;
  }
  return null;
}

Future<String?> _processLine(String executable, List<String> args) async {
  final result = await _runProcess(executable, args);
  if (result == null || result.exitCode != 0) return null;
  return '${result.stdout}${result.stderr}'.trim();
}

Future<ProcessResult?> _runProcess(String executable, List<String> args) async {
  try {
    return await Process.run(
      executable,
      args,
      runInShell: false,
    ).timeout(const Duration(milliseconds: 800));
  } on Object {
    return null;
  }
}

Future<void> _writeString(File file, String contents) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}

String _artifactFileName(
  String taskRunId,
  String extension,
  Set<String> usedNames,
) {
  final sanitized = _sanitizePathSegment(taskRunId);
  var stem = sanitized.isEmpty ? 'task_run' : sanitized;
  var name = '$stem$extension';
  if (stem != taskRunId || usedNames.contains(name)) {
    stem = '$stem-${_shortDigest(taskRunId)}';
    name = '$stem$extension';
    var suffix = 2;
    while (usedNames.contains(name)) {
      name = '$stem-$suffix$extension';
      suffix++;
    }
  }
  usedNames.add(name);
  return name;
}

String _sanitizePathSegment(String value) {
  final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
}

String _shortDigest(String value) {
  return sha256.convert(utf8.encode(value)).toString().substring(0, 8);
}

String _relativePath(Directory root, File file) {
  return p.relative(file.path, from: root.path).replaceAll('\\', '/');
}
