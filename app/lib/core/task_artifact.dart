import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_verifier.dart';

class TaskArtifactExportOptions {
  const TaskArtifactExportOptions({
    this.includeHiddenVerifiers = false,
    this.includeReferenceSolution = false,
    this.includeFixtureRootPath = false,
  });

  final bool includeHiddenVerifiers;
  final bool includeReferenceSolution;
  final bool includeFixtureRootPath;
}

class TaskArtifactManifest {
  const TaskArtifactManifest({
    required this.schemaVersion,
    required this.id,
    required this.version,
    required this.category,
    required this.track,
    required this.tags,
    required this.difficulty,
    required this.generatedCodePath,
    required this.isFlutter,
    required this.prompt,
    required this.workspace,
    required this.hiddenVerifiers,
    required this.referenceFiles,
    required this.environment,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final int version;
  final String category;
  final String track;
  final List<String> tags;
  final String difficulty;
  final String generatedCodePath;
  final bool isFlutter;
  final TaskArtifactPrompt prompt;
  final TaskArtifactWorkspace workspace;
  final List<TaskArtifactVerifier> hiddenVerifiers;
  final List<TaskArtifactFile> referenceFiles;
  final TaskArtifactEnvironment environment;

  static Future<TaskArtifactManifest> fromTask(
    BenchmarkTask task, {
    TaskArtifactExportOptions options = const TaskArtifactExportOptions(),
  }) async {
    await task.ensureLoaded();
    return TaskArtifactManifest.fromLoadedTask(task, options: options);
  }

  factory TaskArtifactManifest.fromLoadedTask(
    BenchmarkTask task, {
    TaskArtifactExportOptions options = const TaskArtifactExportOptions(),
  }) {
    final workspace = task.workspace;
    final publicFiles = _descriptorsForWorkspaceFiles(
      workspace.files,
    ).where((file) => file.visibility == 'public').toList();
    final hiddenVerifiers =
        task.hiddenVerifiers
            .map(
              (verifier) => TaskArtifactVerifier.fromVerifier(
                verifier,
                includeFiles: options.includeHiddenVerifiers,
              ),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    return TaskArtifactManifest(
      schemaVersion: currentSchemaVersion,
      id: task.id,
      version: task.version,
      category: task.category.name,
      track: task.track.name,
      tags: task.tags.map((tag) => tag.slug).toList()..sort(),
      difficulty: task.difficulty.name,
      generatedCodePath: task.generatedCodePath,
      isFlutter: task.isFlutter,
      prompt: TaskArtifactPrompt.inline(task.prompt),
      workspace: TaskArtifactWorkspace(
        fixtureRootPath: options.includeFixtureRootPath
            ? workspace.fixtureRootPath
            : null,
        files: publicFiles,
      ),
      hiddenVerifiers: hiddenVerifiers,
      referenceFiles: options.includeReferenceSolution
          ? _referenceDescriptors(task.referenceSolution)
          : const [],
      environment: TaskArtifactEnvironment(
        timeoutSeconds: task.timeout?.inSeconds,
        platformRequirements:
            task.platformRequirements.map((platform) => platform.name).toList()
              ..sort(),
        setupCommands: workspace.setupCommands,
        allowInternet: false,
      ),
    );
  }

  factory TaskArtifactManifest.fromJson(Map<String, Object?> json) {
    return TaskArtifactManifest(
      schemaVersion: _int(json['schemaVersion'], 'schemaVersion'),
      id: _string(json['id'], 'id'),
      version: _int(json['version'], 'version'),
      category: _string(json['category'], 'category'),
      track: _string(json['track'], 'track'),
      tags: _stringList(json['tags'], 'tags'),
      difficulty: _string(json['difficulty'], 'difficulty'),
      generatedCodePath: _string(
        json['generatedCodePath'],
        'generatedCodePath',
      ),
      isFlutter: _bool(json['isFlutter'], 'isFlutter'),
      prompt: TaskArtifactPrompt.fromJson(_map(json['prompt'], 'prompt')),
      workspace: TaskArtifactWorkspace.fromJson(
        _map(json['workspace'], 'workspace'),
      ),
      hiddenVerifiers: _mapList(
        json['hiddenVerifiers'],
        'hiddenVerifiers',
      ).map(TaskArtifactVerifier.fromJson).toList(),
      referenceFiles: _mapList(
        json['referenceFiles'],
        'referenceFiles',
      ).map(TaskArtifactFile.fromJson).toList(),
      environment: TaskArtifactEnvironment.fromJson(
        _map(json['environment'], 'environment'),
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'version': version,
    'category': category,
    'track': track,
    'tags': tags,
    'difficulty': difficulty,
    'generatedCodePath': generatedCodePath,
    'isFlutter': isFlutter,
    'prompt': prompt.toJson(),
    'workspace': workspace.toJson(),
    'hiddenVerifiers': hiddenVerifiers
        .map((verifier) => verifier.toJson())
        .toList(),
    'referenceFiles': referenceFiles.map((file) => file.toJson()).toList(),
    'environment': environment.toJson(),
  };
}

class TaskArtifactPrompt {
  const TaskArtifactPrompt({
    required this.storage,
    required this.sha256,
    this.text,
    this.path,
  });

  factory TaskArtifactPrompt.inline(String text) {
    return TaskArtifactPrompt(
      storage: 'inline',
      text: text,
      sha256: _sha256(text),
    );
  }

  final String storage;
  final String sha256;
  final String? text;
  final String? path;

  factory TaskArtifactPrompt.fromJson(Map<String, Object?> json) {
    return TaskArtifactPrompt(
      storage: _string(json['storage'], 'storage'),
      sha256: _string(json['sha256'], 'sha256'),
      text: _nullableString(json['text'], 'text'),
      path: _nullableString(json['path'], 'path'),
    );
  }

  Map<String, Object?> toJson() => {
    'storage': storage,
    'sha256': sha256,
    if (text != null) 'text': text,
    if (path != null) 'path': path,
  };
}

class TaskArtifactWorkspace {
  const TaskArtifactWorkspace({this.fixtureRootPath, required this.files});

  final String? fixtureRootPath;
  final List<TaskArtifactFile> files;

  factory TaskArtifactWorkspace.fromJson(Map<String, Object?> json) {
    return TaskArtifactWorkspace(
      fixtureRootPath: _nullableString(
        json['fixtureRootPath'],
        'fixtureRootPath',
      ),
      files: _mapList(
        json['files'],
        'files',
      ).map(TaskArtifactFile.fromJson).toList(),
    );
  }

  Map<String, Object?> toJson() => {
    if (fixtureRootPath != null) 'fixtureRootPath': fixtureRootPath,
    'files': files.map((file) => file.toJson()).toList(),
  };
}

class TaskArtifactFile {
  const TaskArtifactFile({
    required this.path,
    required this.role,
    required this.visibility,
    required this.sha256,
    required this.bytes,
  });

  factory TaskArtifactFile.fromContent({
    required String path,
    required String role,
    required String visibility,
    required String content,
  }) {
    return TaskArtifactFile(
      path: path,
      role: role,
      visibility: visibility,
      sha256: _sha256(content),
      bytes: utf8.encode(content).length,
    );
  }

  final String path;
  final String role;
  final String visibility;
  final String sha256;
  final int bytes;

  factory TaskArtifactFile.fromJson(Map<String, Object?> json) {
    return TaskArtifactFile(
      path: _string(json['path'], 'path'),
      role: _string(json['role'], 'role'),
      visibility: _string(json['visibility'], 'visibility'),
      sha256: _string(json['sha256'], 'sha256'),
      bytes: _int(json['bytes'], 'bytes'),
    );
  }

  Map<String, Object?> toJson() => {
    'path': path,
    'role': role,
    'visibility': visibility,
    'sha256': sha256,
    'bytes': bytes,
  };
}

class TaskArtifactVerifier {
  const TaskArtifactVerifier({
    required this.id,
    required this.testPath,
    required this.visibility,
    required this.files,
  });

  factory TaskArtifactVerifier.fromVerifier(
    VerifierFixture verifier, {
    required bool includeFiles,
  }) {
    return TaskArtifactVerifier(
      id: verifier.id,
      testPath: verifier.testPath,
      visibility: 'hidden',
      files: includeFiles
          ? _descriptorsForFiles(
              verifier.files,
              role: 'hidden_test',
              visibility: 'hidden',
            )
          : const [],
    );
  }

  final String id;
  final String testPath;
  final String visibility;
  final List<TaskArtifactFile> files;

  factory TaskArtifactVerifier.fromJson(Map<String, Object?> json) {
    return TaskArtifactVerifier(
      id: _string(json['id'], 'id'),
      testPath: _string(json['testPath'], 'testPath'),
      visibility: _string(json['visibility'], 'visibility'),
      files: _mapList(
        json['files'],
        'files',
      ).map(TaskArtifactFile.fromJson).toList(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'testPath': testPath,
    'visibility': visibility,
    'files': files.map((file) => file.toJson()).toList(),
  };
}

class TaskArtifactEnvironment {
  const TaskArtifactEnvironment({
    required this.timeoutSeconds,
    required this.platformRequirements,
    required this.setupCommands,
    required this.allowInternet,
  });

  final int? timeoutSeconds;
  final List<String> platformRequirements;
  final List<List<String>> setupCommands;
  final bool allowInternet;

  factory TaskArtifactEnvironment.fromJson(Map<String, Object?> json) {
    return TaskArtifactEnvironment(
      timeoutSeconds: _nullableInt(json['timeoutSeconds'], 'timeoutSeconds'),
      platformRequirements: _stringList(
        json['platformRequirements'],
        'platformRequirements',
      ),
      setupCommands: _nestedStringList(json['setupCommands'], 'setupCommands'),
      allowInternet: _bool(json['allowInternet'], 'allowInternet'),
    );
  }

  Map<String, Object?> toJson() => {
    if (timeoutSeconds != null) 'timeoutSeconds': timeoutSeconds,
    'platformRequirements': platformRequirements,
    'setupCommands': setupCommands,
    'allowInternet': allowInternet,
  };
}

Future<void> writeTaskManifestJson(
  File file,
  TaskArtifactManifest manifest,
) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
  );
}

Future<TaskArtifactManifest> readTaskManifestJson(File file) async {
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Task manifest root must be a JSON object.');
  }
  return TaskArtifactManifest.fromJson(decoded);
}

List<TaskArtifactFile> _descriptorsForWorkspaceFiles(
  Map<String, String> files,
) {
  return _descriptorsForFiles(
    files,
    roleForPath: _workspaceRoleForPath,
    visibilityForPath: _workspaceVisibilityForPath,
  );
}

List<TaskArtifactFile> _descriptorsForFiles(
  Map<String, String> files, {
  String? role,
  String? visibility,
  String Function(String path)? roleForPath,
  String Function(String path)? visibilityForPath,
}) {
  final descriptors =
      files.entries
          .map(
            (entry) => TaskArtifactFile.fromContent(
              path: entry.key,
              role: role ?? roleForPath!(entry.key),
              visibility: visibility ?? visibilityForPath!(entry.key),
              content: entry.value,
            ),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return descriptors;
}

List<TaskArtifactFile> _referenceDescriptors(ReferenceSolution? solution) {
  return switch (solution) {
    null => const [],
    ReferenceFileSolution(:final files) => _descriptorsForFiles(
      files,
      role: 'reference_solution',
      visibility: 'private',
    ),
    ReferencePatchSolution(:final patch) => [
      TaskArtifactFile.fromContent(
        path: 'solution.patch',
        role: 'reference_solution',
        visibility: 'private',
        content: patch,
      ),
    ],
  };
}

String _workspaceRoleForPath(String path) {
  final normalized = path.toLowerCase();
  if (normalized == 'pubspec.yaml') return 'pubspec';
  if (normalized.startsWith('test/')) return 'public_test';
  if (normalized.startsWith('lib/')) return 'source';
  return 'fixture';
}

String _workspaceVisibilityForPath(String path) {
  return _isPrivateWorkspacePath(path) ? 'private' : 'public';
}

bool _isPrivateWorkspacePath(String path) {
  final parts = path
      .replaceAll('\\', '/')
      .split('/')
      .where((part) => part.isNotEmpty && part != '.')
      .map((part) => part.toLowerCase())
      .toList(growable: false);
  if (parts.any(_isPrivateWorkspaceSegment)) return true;
  final basename = parts.isEmpty ? '' : parts.last;
  return basename == 'author_notes.md' ||
      basename == 'qa_report.md' ||
      basename == 'task_qa_report.md';
}

bool _isPrivateWorkspaceSegment(String segment) {
  return segment == '.git' ||
      segment == '_hidden' ||
      segment == 'hidden' ||
      segment == 'reference' ||
      segment == '_reference' ||
      segment == 'author_notes' ||
      segment == '_author' ||
      segment == 'task_qa';
}

String _sha256(String content) =>
    sha256.convert(utf8.encode(content)).toString();

String _string(Object? value, String field) {
  if (value is String) return value;
  throw FormatException('Expected string field "$field".');
}

String? _nullableString(Object? value, String field) {
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$field".');
}

int _int(Object? value, String field) {
  if (value is int) return value;
  throw FormatException('Expected integer field "$field".');
}

int? _nullableInt(Object? value, String field) {
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected nullable integer field "$field".');
}

bool _bool(Object? value, String field) {
  if (value is bool) return value;
  throw FormatException('Expected boolean field "$field".');
}

List<String> _stringList(Object? value, String field) {
  if (value is List && value.every((item) => item is String)) {
    return List<String>.from(value);
  }
  throw FormatException('Expected string list field "$field".');
}

List<List<String>> _nestedStringList(Object? value, String field) {
  if (value is List) {
    return value.map((item) {
      if (item is List && item.every((part) => part is String)) {
        return List<String>.from(item);
      }
      throw FormatException('Expected nested string list field "$field".');
    }).toList();
  }
  throw FormatException('Expected nested string list field "$field".');
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw FormatException('Expected object field "$field".');
}

List<Map<String, Object?>> _mapList(Object? value, String field) {
  if (value is List) {
    return value.map((item) => _map(item, field)).toList();
  }
  throw FormatException('Expected object list field "$field".');
}
