import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/task_bundle_digest.dart';
import 'package:dart_arena/export/leaderboard_cli_runner.dart';
import 'package:dart_arena/export/release_report.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

typedef ReleaseReportCliLineWriter = void Function(String line);

class ReleaseReportCliDependencies {
  const ReleaseReportCliDependencies({this.now = _now});

  final DateTime Function() now;
}

Future<int> runReleaseReportCli(
  List<String> args, {
  ReleaseReportCliDependencies dependencies =
      const ReleaseReportCliDependencies(),
  ReleaseReportCliLineWriter? stdoutWriter,
  ReleaseReportCliLineWriter? stderrWriter,
}) async {
  final out = stdoutWriter ?? stdout.writeln;
  final err = stderrWriter ?? stderr.writeln;
  AppDatabase? database;

  try {
    final parsed = _parseArgs(args);
    if (parsed == null) {
      out(jsonEncode(_helpJson()));
      return 0;
    }

    final leaderboard = _readJsonObject(parsed.leaderboardPath);
    final artifactBundles = await _loadArtifactBundleInputs(
      parsed.artifactBundleRoots,
    );
    final artifactManifest = parsed.artifactManifestPath == null
        ? null
        : _readJsonObject(parsed.artifactManifestPath!);
    final artifactChecksums = parsed.artifactChecksumsPath == null
        ? null
        : _readJsonObject(parsed.artifactChecksumsPath!);
    final artifactRunResults = parsed.artifactRunResultsPath == null
        ? null
        : _readJsonObject(parsed.artifactRunResultsPath!);
    final artifactResultsCsv = parsed.artifactResultsCsvPath == null
        ? null
        : File(parsed.artifactResultsCsvPath!).readAsStringSync();
    final artifactReport = parsed.artifactReportPath == null
        ? null
        : File(parsed.artifactReportPath!).readAsStringSync();
    final artifactFileInputs = parsed.artifactManifestPath == null
        ? const <Map<String, Object?>>[]
        : await _artifactFileInputs(
            artifactManifest,
            p.dirname(parsed.artifactManifestPath!),
          );
    final taskQaReports = <Map<String, Object?>>[];
    final taskQaReportInputs = <Map<String, Object?>>[];
    final taskBundleDigestEvidence = <Map<String, Object?>>[];
    final reportReadErrors = <String>[];
    final directTaskQaReportPaths = parsed.taskQaSummaryPath == null
        ? await _directTaskQaReportPaths(
            reportPaths: parsed.taskQaReportPaths,
            reportRoots: parsed.taskQaReportRoots,
          )
        : const <String>[];
    final taskQaSummary = parsed.taskQaSummaryPath == null
        ? await _loadDirectTaskQaReports(
            directTaskQaReportPaths,
            taskQaReports: taskQaReports,
            taskQaReportInputs: taskQaReportInputs,
            taskBundleDigestEvidence: taskBundleDigestEvidence,
            reportReadErrors: reportReadErrors,
            fallbackGeneratedAt: dependencies.now().toUtc(),
          )
        : await _loadTaskQaSummaryReports(
            parsed.taskQaSummaryPath!,
            taskQaReports: taskQaReports,
            taskQaReportInputs: taskQaReportInputs,
            taskBundleDigestEvidence: taskBundleDigestEvidence,
            reportReadErrors: reportReadErrors,
          );

    Map<String, Map<String, Object?>>? runProvenanceById;
    if (parsed.databasePath != null) {
      database = openLeaderboardDatabaseReadOnly(parsed.databasePath!);
      runProvenanceById = await _loadRunProvenance(
        database,
        _leaderboardRunIds(leaderboard),
      );
    }

    final report = buildReleaseReport(
      leaderboard: leaderboard,
      taskQaSummary: taskQaSummary,
      taskQaReports: taskQaReports,
      taskBundleDigestEvidence: taskBundleDigestEvidence,
      taskQaReportReadErrors: reportReadErrors,
      runProvenanceById: runProvenanceById,
      artifactManifest: artifactManifest,
      artifactChecksums: artifactChecksums,
      artifactRunResults: artifactRunResults,
      artifactResultsCsv: artifactResultsCsv,
      artifactReport: artifactReport,
      artifactBundles: artifactBundles,
      inputs: {
        'leaderboard': await _fileInputArtifact(
          parsed.leaderboardPath,
          displayPath: p.basename(parsed.leaderboardPath),
        ),
        if (parsed.taskQaSummaryPath != null)
          'taskQaSummary': await _fileInputArtifact(
            parsed.taskQaSummaryPath!,
            displayPath: p.basename(parsed.taskQaSummaryPath!),
          ),
        'taskQaReports': taskQaReportInputs,
        if (reportReadErrors.isNotEmpty)
          'taskQaReportReadErrors': reportReadErrors,
        if (parsed.artifactManifestPath != null)
          'artifactManifest': await _fileInputArtifact(
            parsed.artifactManifestPath!,
            displayPath: p.basename(parsed.artifactManifestPath!),
          ),
        if (parsed.artifactChecksumsPath != null)
          'artifactChecksums': await _fileInputArtifact(
            parsed.artifactChecksumsPath!,
            displayPath: p.basename(parsed.artifactChecksumsPath!),
          ),
        if (parsed.artifactRunResultsPath != null)
          'artifactRunResults': await _fileInputArtifact(
            parsed.artifactRunResultsPath!,
            displayPath: p.basename(parsed.artifactRunResultsPath!),
          ),
        if (parsed.artifactResultsCsvPath != null)
          'artifactResultsCsv': await _fileInputArtifact(
            parsed.artifactResultsCsvPath!,
            displayPath: p.basename(parsed.artifactResultsCsvPath!),
          ),
        if (parsed.artifactReportPath != null)
          'artifactReport': await _fileInputArtifact(
            parsed.artifactReportPath!,
            displayPath: p.basename(parsed.artifactReportPath!),
          ),
        if (artifactFileInputs.isNotEmpty) 'artifactFiles': artifactFileInputs,
        if (artifactBundles.isNotEmpty)
          'artifactBundles': [
            for (final bundle in artifactBundles) bundle.toInputJson(),
          ],
        if (parsed.databasePath != null)
          'database': await _fileInputArtifact(
            parsed.databasePath!,
            displayPath: p.basename(parsed.databasePath!),
          ),
      },
      options: ReleaseReportOptions(
        releaseId: parsed.releaseId,
        minSamplesPerModel: parsed.minSamplesPerModel,
        minHiddenFlakeRunsPerTask: parsed.minHiddenFlakeRunsPerTask,
      ),
      now: dependencies.now,
    );

    await Directory(p.dirname(parsed.outPath)).create(recursive: true);
    await File(parsed.outPath).writeAsString(_prettyJson(report));
    final status = report['status'];
    final line = jsonEncode({
      'status': status,
      'out': p.normalize(p.absolute(parsed.outPath)),
    });
    if (status == 'blocked' && parsed.failOnBlocked) {
      err(line);
      return 1;
    }
    out(line);
    return 0;
  } on Object catch (error) {
    err(jsonEncode({'status': 'failed', 'error': error.toString()}));
    return 1;
  } finally {
    await database?.close();
  }
}

Map<String, Object?> _readJsonObject(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw ReleaseReportCliException('expected JSON object: $path');
  }
  return decoded;
}

Future<Map<String, Object?>> _loadTaskQaSummaryReports(
  String taskQaSummaryPath, {
  required List<Map<String, Object?>> taskQaReports,
  required List<Map<String, Object?>> taskQaReportInputs,
  required List<Map<String, Object?>> taskBundleDigestEvidence,
  required List<String> reportReadErrors,
}) async {
  final taskQaSummary = _readJsonObject(taskQaSummaryPath);
  final summaryDir = p.dirname(taskQaSummaryPath);
  for (final reportPath in _taskQaReportPaths(taskQaSummary, summaryDir)) {
    final displayPath = _displayPath(reportPath, summaryDir);
    try {
      final report = _readJsonObject(reportPath);
      taskQaReports.add(report);
      taskQaReportInputs.add(
        await _fileInputArtifact(reportPath, displayPath: displayPath),
      );
      final digestEvidence = await _taskBundleDigestEvidence(
        report,
        reportPath,
      );
      if (digestEvidence != null) {
        taskBundleDigestEvidence.add(digestEvidence);
      }
    } on Object {
      reportReadErrors.add(displayPath);
    }
  }
  return taskQaSummary;
}

Future<Map<String, Object?>> _loadDirectTaskQaReports(
  List<String> taskQaReportPaths, {
  required List<Map<String, Object?>> taskQaReports,
  required List<Map<String, Object?>> taskQaReportInputs,
  required List<Map<String, Object?>> taskBundleDigestEvidence,
  required List<String> reportReadErrors,
  required DateTime fallbackGeneratedAt,
}) async {
  for (final reportPath in taskQaReportPaths) {
    final displayPath = _directTaskQaReportDisplayPath(reportPath);
    try {
      final report = _readJsonObject(reportPath);
      taskQaReports.add(report);
      taskQaReportInputs.add(
        await _fileInputArtifact(reportPath, displayPath: displayPath),
      );
      final digestEvidence = await _taskBundleDigestEvidence(
        report,
        reportPath,
      );
      if (digestEvidence != null) {
        taskBundleDigestEvidence.add(digestEvidence);
      }
    } on Object {
      reportReadErrors.add(displayPath);
    }
  }
  return _taskQaSummaryFromReports(
    taskQaReports,
    fallbackGeneratedAt: fallbackGeneratedAt,
  );
}

Future<Map<String, Object?>?> _taskBundleDigestEvidence(
  Map<String, Object?> report,
  String reportPath,
) async {
  final bundleDirectory = _taskBundleDirectoryForAdmissionReport(reportPath);
  if (bundleDirectory == null) return null;
  return {
    'taskId': report['taskId'],
    'taskVersion': report['taskVersion'],
    'track': report['track'],
    'taskBundleDigest': await taskBundleDigestSha256(bundleDirectory),
  };
}

Directory? _taskBundleDirectoryForAdmissionReport(String reportPath) {
  final normalized = p.normalize(p.absolute(reportPath));
  if (p.basename(normalized) != 'admission_report.json') return null;
  final reportDirectory = p.dirname(normalized);
  final bundleDirectory = Directory(
    p.basename(reportDirectory) == 'qa'
        ? p.dirname(reportDirectory)
        : reportDirectory,
  );
  if (!File(p.join(bundleDirectory.path, 'task.yaml')).existsSync()) {
    return null;
  }
  return bundleDirectory;
}

Future<List<ReleaseArtifactBundleInput>> _loadArtifactBundleInputs(
  List<String> bundleRoots,
) async {
  final bundles = <ReleaseArtifactBundleInput>[];
  for (final bundleRoot in bundleRoots) {
    final manifestPath = p.join(bundleRoot, 'manifest.json');
    final checksumsPath = p.join(bundleRoot, 'checksums.json');
    final runResultsPath = p.join(bundleRoot, 'run_results.v1.json');
    final resultsCsvPath = p.join(bundleRoot, 'results.csv');
    final reportPath = p.join(bundleRoot, 'report.md');
    final manifest = _readJsonObject(manifestPath);
    final artifactFileInputs = await _artifactFileInputs(manifest, bundleRoot);
    bundles.add(
      ReleaseArtifactBundleInput(
        manifest: manifest,
        checksums: _readJsonObject(checksumsPath),
        runResults: _readJsonObject(runResultsPath),
        resultsCsv: await File(resultsCsvPath).readAsString(),
        reportMarkdown: await File(reportPath).readAsString(),
        manifestInput: await _fileInputArtifact(
          manifestPath,
          displayPath: 'manifest.json',
        ),
        checksumsInput: await _fileInputArtifact(
          checksumsPath,
          displayPath: 'checksums.json',
        ),
        runResultsInput: await _fileInputArtifact(
          runResultsPath,
          displayPath: 'run_results.v1.json',
        ),
        resultsCsvInput: await _fileInputArtifact(
          resultsCsvPath,
          displayPath: 'results.csv',
        ),
        reportInput: await _fileInputArtifact(
          reportPath,
          displayPath: 'report.md',
        ),
        artifactFileInputs: _artifactFileInputMap(artifactFileInputs),
        rootInput: {'path': p.basename(bundleRoot)},
      ),
    );
  }
  return bundles;
}

Map<String, Map<String, Object?>> _artifactFileInputMap(
  List<Map<String, Object?>> artifactFileInputs,
) => {
  for (final input in artifactFileInputs)
    if (_nonEmptyString(input['path']) case final path?) path: input,
};

Future<List<String>> _directTaskQaReportPaths({
  required List<String> reportPaths,
  required List<String> reportRoots,
}) async {
  final paths = <String>{...reportPaths};
  for (final root in reportRoots) {
    paths.addAll(await _taskQaReportPathsFromRoot(root));
  }
  return paths.toList()..sort();
}

Future<List<String>> _taskQaReportPathsFromRoot(String rootPath) async {
  final root = Directory(rootPath);
  if (!await root.exists()) return const [];
  final paths = <String>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final normalized = p.normalize(p.absolute(entity.path));
    if (p.basename(normalized) != 'admission_report.json') continue;
    if (p.basename(p.dirname(normalized)) != 'qa') continue;
    paths.add(normalized);
  }
  return paths..sort();
}

Map<String, Object?> _taskQaSummaryFromReports(
  List<Map<String, Object?>> reports, {
  required DateTime fallbackGeneratedAt,
}) {
  var admittedCount = 0;
  var rejectedCount = 0;
  DateTime? generatedAt;
  final entries = <Map<String, Object?>>[];

  for (final report in reports) {
    if (report['status'] == 'admitted') {
      admittedCount++;
    } else if (report['status'] == 'rejected') {
      rejectedCount++;
    }
    final reportGeneratedAt = _parsedDateTime(report['generatedAt']);
    if (reportGeneratedAt != null &&
        (generatedAt == null || reportGeneratedAt.isAfter(generatedAt))) {
      generatedAt = reportGeneratedAt;
    }
    entries.add({
      'taskId': report['taskId'],
      'taskVersion': report['taskVersion'],
      'track': report['track'],
      'status': report['status'],
      'failureCount': _listLength(report['failureMessages']),
      'reportPath': _directTaskQaSummaryReportPath(report),
    });
  }

  return {
    'schemaVersion': 1,
    'status': rejectedCount == 0 ? 'completed' : 'failed',
    'generatedAt': (generatedAt ?? fallbackGeneratedAt)
        .toUtc()
        .toIso8601String(),
    'taskCount': reports.length,
    'admittedTaskCount': admittedCount,
    'rejectedTaskCount': rejectedCount,
    'reports': entries,
  };
}

String _directTaskQaReportDisplayPath(String reportPath) {
  final normalized = p.normalize(reportPath).replaceAll('\\', '/');
  final parts = normalized.split('/');
  final taskIndex = parts.indexOf('tasks');
  if (taskIndex >= 0 && taskIndex < parts.length - 1) {
    return parts.sublist(taskIndex).join('/');
  }
  return 'tasks/${_safeTaskQaSummarySegment(p.basenameWithoutExtension(reportPath))}/admission_report.json';
}

String _directTaskQaSummaryReportPath(Map<String, Object?> report) {
  final taskId = _nonEmptyString(report['taskId']) ?? 'task';
  final taskVersion = report['taskVersion']?.toString() ?? 'unknown';
  final track = _nonEmptyString(report['track']) ?? 'track';
  final segment = _safeTaskQaSummarySegment('${taskId}_v${taskVersion}_$track');
  return 'tasks/$segment/admission_report.json';
}

String _safeTaskQaSummarySegment(String value) {
  final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final trimmed = safe.replaceAll(RegExp(r'^_+|_+$'), '');
  return trimmed.isEmpty ? 'task' : trimmed;
}

DateTime? _parsedDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

int _listLength(Object? value) => value is List ? value.length : 0;

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Future<List<Map<String, Object?>>> _artifactFileInputs(
  Map<String, Object?>? manifest,
  String bundleDir,
) async {
  final artifacts = manifest?['artifacts'];
  if (artifacts is! List) return const [];
  final inputs = <Map<String, Object?>>[];
  final seenPaths = <String>{};
  for (final artifact in artifacts) {
    if (artifact is! Map || artifact['path'] is! String) continue;
    final artifactPath = _safeArtifactFilePath(artifact['path']! as String);
    if (artifactPath == null || !seenPaths.add(artifactPath)) continue;
    final filePath = p.join(bundleDir, artifactPath);
    if (!await File(filePath).exists()) continue;
    inputs.add(await _fileInputArtifact(filePath, displayPath: artifactPath));
  }
  return inputs;
}

String? _safeArtifactFilePath(String path) {
  final normalized = p.posix.normalize(path.replaceAll('\\', '/'));
  if (normalized.startsWith('/') ||
      normalized.startsWith('../') ||
      normalized == '..' ||
      !normalized.startsWith('artifacts/')) {
    return null;
  }
  final parts = normalized.split('/');
  if (parts.any((part) => part == '..' || part.isEmpty)) return null;
  return normalized;
}

Future<Map<String, Object?>> _fileInputArtifact(
  String path, {
  required String displayPath,
}) async {
  final file = File(path);
  final digest = await sha256.bind(file.openRead()).first;
  return {
    'path': displayPath,
    'bytes': await file.length(),
    'sha256': digest.toString(),
  };
}

List<String> _taskQaReportPaths(
  Map<String, Object?> taskQaSummary,
  String summaryDir,
) {
  final reports = taskQaSummary['reports'];
  if (reports is! List) return const [];
  return [
    for (final report in reports)
      if (report is Map && report['reportPath'] is String)
        if (_taskQaReportPath(report['reportPath']! as String, summaryDir)
            case final reportPath?)
          reportPath,
  ];
}

String? _taskQaReportPath(String path, String summaryDir) {
  if (p.isAbsolute(path)) return null;
  final normalized = path.replaceAll('\\', '/');
  if (!_isSafeRelativeTaskQaReportPath(normalized)) return null;
  return p.normalize(p.join(summaryDir, p.posix.normalize(normalized)));
}

bool _isSafeRelativeTaskQaReportPath(String path) {
  final parts = path.split('/');
  return path.startsWith('tasks/') &&
      !path.startsWith('/') &&
      !RegExp(r'^[A-Za-z]:/').hasMatch(path) &&
      !path.contains('\u0000') &&
      parts.every((part) => part.isNotEmpty && part != '.' && part != '..');
}

List<String> _leaderboardRunIds(Map<String, Object?> leaderboard) {
  final source = leaderboard['source'];
  if (source is! Map) return const [];
  final runIds = source['runIds'];
  if (runIds is! List) return const [];
  return [
    for (final runId in runIds)
      if (runId is String) runId,
  ];
}

Future<Map<String, Map<String, Object?>>> _loadRunProvenance(
  AppDatabase db,
  List<String> runIds,
) async {
  if (runIds.isEmpty) return const {};
  final rows = await (db.select(
    db.runs,
  )..where((run) => run.id.isIn(runIds))).get();
  final provenanceById = <String, Map<String, Object?>>{};
  for (final row in rows) {
    final provenanceJson = row.provenanceJson;
    if (provenanceJson == null || provenanceJson.trim().isEmpty) continue;
    try {
      final decoded = jsonDecode(provenanceJson);
      if (decoded is Map<String, Object?>) {
        provenanceById[row.id] = decoded;
      }
    } on Object {
      continue;
    }
  }
  return provenanceById;
}

_ParsedArgs? _parseArgs(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    return null;
  }

  String? leaderboardPath;
  String? taskQaSummaryPath;
  final taskQaReportPaths = <String>[];
  final taskQaReportRoots = <String>[];
  final artifactBundleRoots = <String>[];
  String? outPath;
  String? databasePath;
  String? artifactManifestPath;
  String? artifactChecksumsPath;
  String? artifactRunResultsPath;
  String? artifactResultsCsvPath;
  String? artifactReportPath;
  var releaseId = 'local-candidate';
  var minSamplesPerModel = 2;
  var minHiddenFlakeRunsPerTask = 3;
  var failOnBlocked = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--leaderboard':
        leaderboardPath = _requiredValue(args, ++i, arg);
      case '--task-qa-summary':
        taskQaSummaryPath = _requiredValue(args, ++i, arg);
      case '--task-qa-report':
        taskQaReportPaths.add(_requiredValue(args, ++i, arg));
      case '--task-qa-report-root':
        taskQaReportRoots.add(_requiredValue(args, ++i, arg));
      case '--out':
        outPath = _requiredValue(args, ++i, arg);
      case '--database':
        databasePath = _requiredValue(args, ++i, arg);
      case '--artifact-manifest':
        artifactManifestPath = _requiredValue(args, ++i, arg);
      case '--artifact-checksums':
        artifactChecksumsPath = _requiredValue(args, ++i, arg);
      case '--artifact-run-results':
        artifactRunResultsPath = _requiredValue(args, ++i, arg);
      case '--artifact-results-csv':
        artifactResultsCsvPath = _requiredValue(args, ++i, arg);
      case '--artifact-report':
        artifactReportPath = _requiredValue(args, ++i, arg);
      case '--artifact-bundle-root':
        artifactBundleRoots.add(_requiredValue(args, ++i, arg));
      case '--release-id':
        releaseId = _requiredValue(args, ++i, arg);
      case '--min-samples-per-model':
        minSamplesPerModel = _positiveInt(_requiredValue(args, ++i, arg), arg);
      case '--min-hidden-flake-runs-per-task':
        minHiddenFlakeRunsPerTask = _positiveInt(
          _requiredValue(args, ++i, arg),
          arg,
        );
      case '--fail-on-blocked':
        failOnBlocked = true;
      default:
        throw ReleaseReportCliException('unknown argument: $arg');
    }
  }

  if (leaderboardPath == null) {
    throw const ReleaseReportCliException('--leaderboard is required');
  }
  if (taskQaSummaryPath == null &&
      taskQaReportPaths.isEmpty &&
      taskQaReportRoots.isEmpty) {
    throw const ReleaseReportCliException(
      '--task-qa-summary, --task-qa-report, or --task-qa-report-root is required',
    );
  }
  if (taskQaSummaryPath != null &&
      (taskQaReportPaths.isNotEmpty || taskQaReportRoots.isNotEmpty)) {
    throw const ReleaseReportCliException(
      'use either --task-qa-summary or direct task QA report inputs, not both',
    );
  }
  if (outPath == null) {
    throw const ReleaseReportCliException('--out is required');
  }
  if (artifactBundleRoots.isNotEmpty &&
      (artifactManifestPath != null ||
          artifactChecksumsPath != null ||
          artifactRunResultsPath != null ||
          artifactResultsCsvPath != null ||
          artifactReportPath != null)) {
    throw const ReleaseReportCliException(
      'use either --artifact-bundle-root or individual artifact bundle file inputs, not both',
    );
  }

  return _ParsedArgs(
    leaderboardPath: p.normalize(p.absolute(leaderboardPath)),
    taskQaSummaryPath: taskQaSummaryPath == null
        ? null
        : p.normalize(p.absolute(taskQaSummaryPath)),
    taskQaReportPaths: [
      for (final path in taskQaReportPaths) p.normalize(p.absolute(path)),
    ],
    taskQaReportRoots: [
      for (final path in taskQaReportRoots) p.normalize(p.absolute(path)),
    ],
    artifactBundleRoots: [
      for (final path in artifactBundleRoots) p.normalize(p.absolute(path)),
    ],
    outPath: p.normalize(p.absolute(outPath)),
    databasePath: databasePath == null
        ? null
        : p.normalize(p.absolute(databasePath)),
    artifactManifestPath: artifactManifestPath == null
        ? null
        : p.normalize(p.absolute(artifactManifestPath)),
    artifactChecksumsPath: artifactChecksumsPath == null
        ? null
        : p.normalize(p.absolute(artifactChecksumsPath)),
    artifactRunResultsPath: artifactRunResultsPath == null
        ? null
        : p.normalize(p.absolute(artifactRunResultsPath)),
    artifactResultsCsvPath: artifactResultsCsvPath == null
        ? null
        : p.normalize(p.absolute(artifactResultsCsvPath)),
    artifactReportPath: artifactReportPath == null
        ? null
        : p.normalize(p.absolute(artifactReportPath)),
    releaseId: releaseId,
    minSamplesPerModel: minSamplesPerModel,
    minHiddenFlakeRunsPerTask: minHiddenFlakeRunsPerTask,
    failOnBlocked: failOnBlocked,
  );
}

String _requiredValue(List<String> args, int index, String option) {
  if (index >= args.length || args[index].startsWith('--')) {
    throw ReleaseReportCliException('$option requires a value');
  }
  return args[index];
}

int _positiveInt(String value, String option) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) {
    throw ReleaseReportCliException('$option must be a positive integer');
  }
  return parsed;
}

String _displayPath(String path, String baseDir) {
  final relative = p.relative(path, from: baseDir);
  return relative.startsWith('..') ? p.basename(path) : relative;
}

String _prettyJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

Map<String, Object?> _helpJson() {
  return const {
    'status': 'help',
    'usage':
        'dart run --verbosity=error dart_arena:dart_arena_release_report --leaderboard ../web/static/data/leaderboard.v1.json --task-qa-summary build/task_qa/admission_summary.json --database .dart_arena/dart_arena.sqlite --artifact-manifest build/release/manifest.json --artifact-checksums build/release/checksums.json --artifact-run-results build/release/run_results.v1.json --artifact-results-csv build/release/results.csv --artifact-report build/release/report.md --out build/release/release_report.v1.json',
    'taskQaInputs':
        'Use --task-qa-summary for a generated admission summary, repeat --task-qa-report for stored per-task admission_report.json files, or repeat --task-qa-report-root to discover qa/admission_report.json files under task roots.',
    'artifactBundleInputs':
        'Use individual artifact bundle files for a single run, or repeat --artifact-bundle-root for aggregate-compatible releases spanning multiple run bundles.',
    'options': [
      {'name': '--leaderboard', 'value': 'path', 'required': true},
      {'name': '--task-qa-summary', 'value': 'path', 'required': false},
      {
        'name': '--task-qa-report',
        'value': 'path',
        'required': false,
        'repeatable': true,
      },
      {
        'name': '--task-qa-report-root',
        'value': 'path',
        'required': false,
        'repeatable': true,
      },
      {'name': '--out', 'value': 'path', 'required': true},
      {'name': '--database', 'value': 'path', 'required': false},
      {'name': '--artifact-manifest', 'value': 'path', 'required': false},
      {'name': '--artifact-checksums', 'value': 'path', 'required': false},
      {'name': '--artifact-run-results', 'value': 'path', 'required': false},
      {'name': '--artifact-results-csv', 'value': 'path', 'required': false},
      {'name': '--artifact-report', 'value': 'path', 'required': false},
      {
        'name': '--artifact-bundle-root',
        'value': 'path',
        'required': false,
        'repeatable': true,
      },
      {'name': '--release-id', 'value': 'id', 'required': false},
      {
        'name': '--min-samples-per-model',
        'value': 'count',
        'required': false,
        'default': 2,
      },
      {
        'name': '--min-hidden-flake-runs-per-task',
        'value': 'count',
        'required': false,
        'default': 3,
      },
      {'name': '--fail-on-blocked', 'required': false},
      {'name': '--help', 'required': false},
    ],
    'outputFormat': 'release_report.v1.json',
  };
}

DateTime _now() => DateTime.now();

class ReleaseReportCliException implements Exception {
  const ReleaseReportCliException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ParsedArgs {
  const _ParsedArgs({
    required this.leaderboardPath,
    required this.taskQaSummaryPath,
    required this.taskQaReportPaths,
    required this.taskQaReportRoots,
    required this.artifactBundleRoots,
    required this.outPath,
    required this.databasePath,
    required this.artifactManifestPath,
    required this.artifactChecksumsPath,
    required this.artifactRunResultsPath,
    required this.artifactResultsCsvPath,
    required this.artifactReportPath,
    required this.releaseId,
    required this.minSamplesPerModel,
    required this.minHiddenFlakeRunsPerTask,
    required this.failOnBlocked,
  });

  final String leaderboardPath;
  final String? taskQaSummaryPath;
  final List<String> taskQaReportPaths;
  final List<String> taskQaReportRoots;
  final List<String> artifactBundleRoots;
  final String outPath;
  final String? databasePath;
  final String? artifactManifestPath;
  final String? artifactChecksumsPath;
  final String? artifactRunResultsPath;
  final String? artifactResultsCsvPath;
  final String? artifactReportPath;
  final String releaseId;
  final int minSamplesPerModel;
  final int minHiddenFlakeRunsPerTask;
  final bool failOnBlocked;
}
