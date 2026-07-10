import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const taskBundleDigestFileRoots = [
  'task.yaml',
  'instruction.md',
  'baseline',
  'hidden_tests',
  'solution',
  'negative_cases',
];

class CorpusManifestEntry {
  const CorpusManifestEntry({
    required this.taskId,
    required this.taskVersion,
    required this.taskBundleDigest,
  });

  final String taskId;
  final int taskVersion;
  final String taskBundleDigest;

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'taskVersion': taskVersion,
    'taskBundleDigest': taskBundleDigest,
  };
}

String corpusManifestDigestSha256(Iterable<CorpusManifestEntry> entries) {
  final sorted = entries.toList()
    ..sort((a, b) {
      final id = a.taskId.compareTo(b.taskId);
      if (id != 0) return id;
      final version = a.taskVersion.compareTo(b.taskVersion);
      if (version != 0) return version;
      return a.taskBundleDigest.compareTo(b.taskBundleDigest);
    });
  return sha256
      .convert(
        utf8.encode(
          sorted
              .map(
                (entry) =>
                    '${entry.taskId}\u0000${entry.taskVersion}\u0000${entry.taskBundleDigest}',
              )
              .join('\n'),
        ),
      )
      .toString();
}

Future<String> taskBundleDigestSha256(Directory bundleDirectory) async {
  final files = await _taskBundleDigestFiles(bundleDirectory);
  final bytesBuilder = BytesBuilder(copy: false);
  for (final file in files) {
    final bytes = await file.file.readAsBytes();
    bytesBuilder.add(
      utf8.encode('${file.relativePath}\u0000${bytes.length}\u0000'),
    );
    bytesBuilder.add(bytes);
    bytesBuilder.add(const [0]);
  }
  return sha256.convert(bytesBuilder.takeBytes()).toString();
}

Future<List<_TaskBundleDigestFile>> _taskBundleDigestFiles(
  Directory bundleDirectory,
) async {
  final root = _validatedBundleRoot(bundleDirectory);
  await _rejectSymlinksInDigestRoots(bundleDirectory);
  final relativePaths = SplayTreeSet<String>();
  relativePaths.add('task.yaml');

  final manifestFile = _resolveBundleFile(root, 'task.yaml');
  final manifest = loadYaml(await manifestFile.readAsString());
  if (manifest is! YamlMap) {
    throw FormatException(
      'Task manifest must be a YAML map: ${manifestFile.path}',
    );
  }

  _addDeclaredFile(
    relativePaths,
    _requiredString(manifest, 'instructionPath'),
    field: 'instructionPath',
  );
  final judgeRubricPath = _optionalString(manifest, 'judgeRubricPath');
  if (judgeRubricPath != null) {
    _addDeclaredBundleFile(
      relativePaths,
      judgeRubricPath,
      field: 'judgeRubricPath',
    );
  }
  _addDeclaredFileMap(
    relativePaths,
    _requiredMap(manifest, 'workspace'),
    field: 'workspace',
  );
  for (final verifier in _optionalMapList(manifest, 'hiddenVerifiers')) {
    _addDeclaredFileMap(relativePaths, verifier, field: 'hiddenVerifiers');
  }
  final reference = _optionalMap(manifest, 'reference');
  if (reference != null) {
    final type = _optionalString(reference, 'type') ?? 'files';
    if (type != 'files') {
      throw FormatException('Unsupported reference type: $type');
    }
    _addDeclaredFileMap(relativePaths, reference, field: 'reference');
  }
  for (final negativeCase in _optionalMapList(manifest, 'negativeCases')) {
    _addDeclaredFileMap(relativePaths, negativeCase, field: 'negativeCases');
  }

  final files = <_TaskBundleDigestFile>[];
  for (final relativePath in relativePaths) {
    files.add(
      _TaskBundleDigestFile(
        relativePath,
        _resolveBundleFile(root, relativePath),
      ),
    );
  }
  return files;
}

String _validatedBundleRoot(Directory bundleDirectory) {
  final root = p.normalize(p.absolute(bundleDirectory.path));
  final rootType = FileSystemEntity.typeSync(root, followLinks: false);
  if (rootType == FileSystemEntityType.link) {
    throw FileSystemException(
      'Task bundle digest does not support symlinks',
      root,
    );
  }
  if (rootType != FileSystemEntityType.directory) {
    throw FileSystemException('Task bundle is not a directory', root);
  }
  return root;
}

Future<void> _rejectSymlinksInDigestRoots(Directory bundleDirectory) async {
  for (final root in taskBundleDigestFileRoots) {
    final path = p.join(bundleDirectory.path, root);
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) continue;
    if (type == FileSystemEntityType.link) {
      throw FileSystemException(
        'Task bundle digest does not support symlinks',
        path,
      );
    }

    if (type == FileSystemEntityType.directory) {
      await for (final entity in Directory(
        path,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! Link) continue;
        throw FileSystemException(
          'Task bundle digest does not support symlinks',
          entity.path,
        );
      }
    }
  }
}

void _addDeclaredFileMap(
  SplayTreeSet<String> paths,
  YamlMap yaml, {
  required String field,
}) {
  final root = _requiredPathString(yaml['root'], '$field.root');
  final files = _requiredMap(yaml, 'files');
  for (final entry in files.entries) {
    final source = _requiredPathString(entry.key, '$field.files key');
    _requiredPathString(entry.value, '$field.files value');
    _addDeclaredFile(paths, p.posix.join(root, source), field: '$field.files');
  }
}

void _addDeclaredFile(
  SplayTreeSet<String> paths,
  String relativePath, {
  required String field,
}) {
  final canonical = _requiredPathString(relativePath, field);
  if (!_isAllowedDigestPath(canonical)) {
    throw ArgumentError.value(
      relativePath,
      field,
      'must resolve inside task bundle digest roots',
    );
  }
  _addCanonicalBundleFile(paths, canonical, relativePath, field: field);
}

String _addDeclaredBundleFile(
  SplayTreeSet<String> paths,
  String relativePath, {
  required String field,
}) {
  final canonical = _requiredPathString(relativePath, field);
  _addCanonicalBundleFile(paths, canonical, relativePath, field: field);
  return canonical;
}

void _addCanonicalBundleFile(
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
}

bool _isAllowedDigestPath(String relativePath) {
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

File _resolveBundleFile(String root, String relativePath) {
  final parts = p.posix.split(relativePath);
  var current = root;
  for (var i = 0; i < parts.length; i++) {
    current = p.normalize(p.join(current, parts[i]));
    if (!p.isWithin(root, current)) {
      throw ArgumentError.value(relativePath, 'relativePath', 'escapes bundle');
    }
    final type = FileSystemEntity.typeSync(current, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw FileSystemException(
        'Task bundle digest does not support symlinks',
        current,
      );
    }
    final isLast = i == parts.length - 1;
    if (!isLast && type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Task bundle digest parent path is not a directory',
        current,
      );
    }
    if (isLast && type != FileSystemEntityType.file) {
      throw FileSystemException('Task bundle digest file is missing', current);
    }
  }
  return File(current);
}

String _requiredPathString(Object? value, String field) {
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

class _TaskBundleDigestFile {
  const _TaskBundleDigestFile(this.relativePath, this.file);

  final String relativePath;
  final File file;
}
