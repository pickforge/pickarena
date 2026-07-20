import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const taskBundleInspectionFileRoots = [
  'task.yaml',
  'instruction.md',
  'baseline',
  'hidden_tests',
  'solution',
  'negative_cases',
];

class TaskBundleFileSet {
  const TaskBundleFileSet({required this.root, required this.files});

  final String root;
  final Map<String, String> files;
}

class TaskBundleInspection {
  TaskBundleInspection._({
    required this.bundleDirectory,
    required this.manifest,
    required this.instructionPath,
    required this.judgeRubricPath,
    required this.workspace,
    required this.hiddenVerifiers,
    required this.reference,
    required this.negativeCases,
    required String root,
    required List<String> digestRelativePaths,
  }) : _root = root,
       _digestRelativePaths = digestRelativePaths;

  final Directory bundleDirectory;
  final YamlMap manifest;
  final String instructionPath;
  final String? judgeRubricPath;
  final TaskBundleFileSet workspace;
  final List<TaskBundleFileSet> hiddenVerifiers;
  final TaskBundleFileSet? reference;
  final List<TaskBundleFileSet> negativeCases;
  final String _root;
  final List<String> _digestRelativePaths;

  static Future<TaskBundleInspection> inspect(Directory bundleDirectory) async {
    final root = _validatedBundleRoot(bundleDirectory);
    final manifestFile = _resolveBundleFile(root, 'task.yaml');
    final decoded = loadYaml(await manifestFile.readAsString());
    if (decoded is! YamlMap) {
      throw FormatException(
        'Task manifest must be a YAML map: ${manifestFile.path}',
      );
    }

    final relativePaths = SplayTreeSet<String>()..add('task.yaml');
    final instructionPath = _addDeclaredFile(
      relativePaths,
      _requiredString(decoded, 'instructionPath'),
      field: 'instructionPath',
    );
    final judgeRubricValue = _optionalString(decoded, 'judgeRubricPath');
    final judgeRubricPath = judgeRubricValue == null
        ? null
        : _addDeclaredBundleFile(
            relativePaths,
            judgeRubricValue,
            field: 'judgeRubricPath',
          );
    final workspace = _parseDeclaredFileSet(
      relativePaths,
      _requiredMap(decoded, 'workspace'),
      field: 'workspace',
    );
    final hiddenVerifiers = [
      for (final verifier in _optionalMapList(decoded, 'hiddenVerifiers'))
        _parseDeclaredFileSet(
          relativePaths,
          verifier,
          field: 'hiddenVerifiers',
        ),
    ];
    final referenceYaml = _optionalMap(decoded, 'reference');
    final reference = referenceYaml == null
        ? null
        : _parseReference(relativePaths, referenceYaml);
    final negativeCases = [
      for (final negativeCase in _optionalMapList(decoded, 'negativeCases'))
        _parseDeclaredFileSet(
          relativePaths,
          negativeCase,
          field: 'negativeCases',
        ),
    ];

    return TaskBundleInspection._(
      bundleDirectory: bundleDirectory,
      manifest: decoded,
      instructionPath: instructionPath,
      judgeRubricPath: judgeRubricPath,
      workspace: workspace,
      hiddenVerifiers: List.unmodifiable(hiddenVerifiers),
      reference: reference,
      negativeCases: List.unmodifiable(negativeCases),
      root: root,
      digestRelativePaths: List.unmodifiable(relativePaths),
    );
  }

  Future<void> validateDeclaredFiles() async {
    await _rejectSymlinksInInspectionRoots(bundleDirectory);
    for (final relativePath in _digestRelativePaths) {
      _resolveBundleFile(_root, relativePath);
    }
  }

  Future<String> taskBundleDigestSha256() async {
    await validateDeclaredFiles();
    final bytesBuilder = BytesBuilder(copy: false);
    for (final relativePath in _digestRelativePaths) {
      final file = _resolveBundleFile(_root, relativePath);
      final bytes = await file.readAsBytes();
      bytesBuilder.add(utf8.encode('$relativePath\u0000${bytes.length}\u0000'));
      bytesBuilder.add(bytes);
      bytesBuilder.add(const [0]);
    }
    return sha256.convert(bytesBuilder.takeBytes()).toString();
  }

  Future<String> readText(String relativePath) {
    return _resolveBundleFile(_root, relativePath).readAsString();
  }

  Future<Map<String, String>> readFiles(TaskBundleFileSet fileSet) async {
    final result = <String, String>{};
    for (final entry in fileSet.files.entries) {
      final relativePath = p.posix.join(fileSet.root, entry.key);
      result[entry.value] = await _resolveBundleFile(
        _root,
        relativePath,
      ).readAsString();
    }
    return Map.unmodifiable(result);
  }

  Future<bool> hasAdmittedQaReport({
    required String taskId,
    required int taskVersion,
    required String track,
  }) async {
    try {
      final report = jsonDecode(
        await File(
          p.join(bundleDirectory.path, 'qa', 'admission_report.json'),
        ).readAsString(),
      );
      if (report is! Map ||
          report['status'] != 'admitted' ||
          report['taskId'] != taskId ||
          report['taskVersion'] != taskVersion ||
          report['track'] != track) {
        return false;
      }
      final admission = report['admission'];
      if (admission is! Map) return false;
      return admission['taskBundleDigest'] == await taskBundleDigestSha256();
    } on Object {
      return false;
    }
  }
}

Future<List<TaskBundleInspection>> inspectTaskBundles(Directory root) async {
  if (!await root.exists()) return const [];
  final inspections = <TaskBundleInspection>[];
  await for (final entity in root.list(followLinks: false)) {
    if (entity is! Directory) continue;
    final manifest = File(p.join(entity.path, 'task.yaml'));
    if (!await manifest.exists()) continue;
    inspections.add(await TaskBundleInspection.inspect(entity));
  }
  return inspections;
}

String taskBundleRelativePath(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  if (value.contains('\\')) {
    throw ArgumentError.value(value, field, 'must not contain backslashes');
  }
  final rawParts = value.split('/');
  final normalized = p.posix.normalize(value);
  if (normalized == '.' ||
      p.posix.isAbsolute(value) ||
      rawParts.contains('..')) {
    throw ArgumentError.value(value, field, 'must be a relative file path');
  }
  return normalized;
}

TaskBundleFileSet _parseReference(SplayTreeSet<String> paths, YamlMap yaml) {
  final type = _optionalString(yaml, 'type') ?? 'files';
  if (type != 'files') {
    throw FormatException('Unsupported reference type: $type');
  }
  return _parseDeclaredFileSet(paths, yaml, field: 'reference');
}

TaskBundleFileSet _parseDeclaredFileSet(
  SplayTreeSet<String> paths,
  YamlMap yaml, {
  required String field,
}) {
  final root = taskBundleRelativePath(yaml['root'], '$field.root');
  final files = _requiredMap(yaml, 'files');
  final parsedFiles = <String, String>{};
  for (final entry in files.entries) {
    final source = taskBundleRelativePath(entry.key, '$field.files key');
    final destination = taskBundleRelativePath(
      entry.value,
      '$field.files value',
    );
    _addDeclaredFile(paths, p.posix.join(root, source), field: '$field.files');
    parsedFiles[source] = destination;
  }
  return TaskBundleFileSet(root: root, files: Map.unmodifiable(parsedFiles));
}

String _addDeclaredFile(
  SplayTreeSet<String> paths,
  String relativePath, {
  required String field,
}) {
  final canonical = taskBundleRelativePath(relativePath, field);
  if (!_isAllowedInspectionPath(canonical)) {
    throw ArgumentError.value(
      relativePath,
      field,
      'must resolve inside task bundle digest roots',
    );
  }
  return _addCanonicalBundleFile(paths, canonical, relativePath, field: field);
}

String _addDeclaredBundleFile(
  SplayTreeSet<String> paths,
  String relativePath, {
  required String field,
}) {
  final canonical = taskBundleRelativePath(relativePath, field);
  return _addCanonicalBundleFile(paths, canonical, relativePath, field: field);
}

String _addCanonicalBundleFile(
  SplayTreeSet<String> paths,
  String canonical,
  String relativePath, {
  required String field,
}) {
  if (_isIgnoredBundleFile(canonical)) {
    throw ArgumentError.value(
      relativePath,
      field,
      'must not be an ignored OS metadata file',
    );
  }
  paths.add(canonical);
  return canonical;
}

bool _isAllowedInspectionPath(String relativePath) {
  if (relativePath == 'task.yaml' || relativePath == 'instruction.md') {
    return true;
  }
  return const {
    'baseline',
    'hidden_tests',
    'solution',
    'negative_cases',
  }.any((root) => relativePath.startsWith('$root/'));
}

bool _isIgnoredBundleFile(String relativePath) {
  final basename = p.posix.basename(relativePath);
  return basename == '.DS_Store' ||
      basename == 'Thumbs.db' ||
      basename == 'desktop.ini' ||
      basename.startsWith('._');
}

String _validatedBundleRoot(Directory bundleDirectory) {
  final root = p.normalize(p.absolute(bundleDirectory.path));
  final rootType = FileSystemEntity.typeSync(root, followLinks: false);
  if (rootType == FileSystemEntityType.link) {
    throw ArgumentError.value(
      bundleDirectory.path,
      'bundleDirectory',
      'must not be a symlink',
    );
  }
  if (rootType != FileSystemEntityType.directory) {
    throw ArgumentError.value(
      bundleDirectory.path,
      'bundleDirectory',
      'must be an existing directory',
    );
  }
  return root;
}

Future<void> _rejectSymlinksInInspectionRoots(Directory bundleDirectory) async {
  for (final root in taskBundleInspectionFileRoots) {
    final path = p.join(bundleDirectory.path, root);
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) continue;
    if (type == FileSystemEntityType.link) {
      throw FileSystemException(
        'Task bundle inspection does not support symlinks',
        path,
      );
    }

    if (type == FileSystemEntityType.directory) {
      await for (final entity in Directory(
        path,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! Link) continue;
        throw FileSystemException(
          'Task bundle inspection does not support symlinks',
          entity.path,
        );
      }
    }
  }
}

File _resolveBundleFile(String root, String relativePath) {
  final canonical = taskBundleRelativePath(relativePath, 'relativePath');
  final parts = p.posix.split(canonical);
  var current = root;
  for (var i = 0; i < parts.length; i++) {
    current = p.normalize(p.join(current, parts[i]));
    if (!p.isWithin(root, current)) {
      throw ArgumentError.value(relativePath, 'relativePath', 'escapes bundle');
    }
    final type = FileSystemEntity.typeSync(current, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must not contain symlinks',
      );
    }
    final isLast = i == parts.length - 1;
    if (!isLast && type != FileSystemEntityType.directory) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must have existing parent directories',
      );
    }
    if (isLast && type != FileSystemEntityType.file) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must be an existing file',
      );
    }
  }
  return File(current);
}

YamlMap _requiredMap(YamlMap yaml, String field) {
  final value = yaml[field];
  if (value is YamlMap) return value;
  throw FormatException('$field must be a YAML map');
}

YamlMap? _optionalMap(YamlMap yaml, String field) {
  final value = yaml[field];
  if (value == null) return null;
  if (value is YamlMap) return value;
  throw FormatException('$field must be a YAML map');
}

List<YamlMap> _optionalMapList(YamlMap yaml, String field) {
  final value = yaml[field];
  if (value == null) return const [];
  if (value is! YamlList) throw FormatException('$field must be a YAML list');
  return [
    for (final item in value)
      if (item is YamlMap)
        item
      else
        throw FormatException('$field items must be YAML maps'),
  ];
}

String _requiredString(YamlMap yaml, String field) {
  final value = yaml[field];
  if (value is String) return value;
  throw FormatException('$field must be a string');
}

String? _optionalString(YamlMap yaml, String field) {
  final value = yaml[field];
  if (value == null || value is String) return value as String?;
  throw FormatException('$field must be a string');
}
