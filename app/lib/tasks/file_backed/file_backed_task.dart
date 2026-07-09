import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class FileBackedTask extends BenchmarkTask {
  FileBackedTask._({
    required this.bundleDirectory,
    required this.id,
    required this.version,
    required this.category,
    required this.track,
    required this.tags,
    required this.difficulty,
    required this.timeout,
    required this.platformRequirements,
    required this.releaseMetadata,
    required this.allowInternet,
    required this.resourceLimits,
    required this.generatedCodePath,
    required this.isFlutter,
    required this.judgeRubric,
    required String instructionPath,
    required _WorkspaceSpec workspace,
    required List<_HiddenVerifierSpec> hiddenVerifierSpecs,
    required _ReferenceSpec? referenceSpec,
    required List<_NegativeCaseSpec> negativeCaseSpecs,
    required Set<TaskNegativeCaseKind> requiredNegativeCaseKinds,
  }) : _instructionPath = instructionPath,
       _workspaceSpec = workspace,
       _hiddenVerifierSpecs = hiddenVerifierSpecs,
       _referenceSpec = referenceSpec,
       _negativeCaseSpecs = negativeCaseSpecs,
       _requiredNegativeCaseKinds = requiredNegativeCaseKinds;

  final Directory bundleDirectory;
  final String _instructionPath;
  final _WorkspaceSpec _workspaceSpec;
  final List<_HiddenVerifierSpec> _hiddenVerifierSpecs;
  final _ReferenceSpec? _referenceSpec;
  final List<_NegativeCaseSpec> _negativeCaseSpecs;
  final Set<TaskNegativeCaseKind> _requiredNegativeCaseKinds;

  Map<String, String>? _fixtures;
  String? _prompt;
  List<VerifierFixture>? _hiddenVerifiers;
  ReferenceSolution? _loadedReferenceSolution;
  List<TaskNegativeCase>? _loadedNegativeCases;

  static Future<FileBackedTask> load(Directory bundleDirectory) async {
    final manifest = await _readYamlMap(bundleDirectory, 'task.yaml');
    final judgeRubricPath = _optionalString(manifest, 'judgeRubricPath');
    final id = _requiredString(manifest, 'id');
    _validateTaskId(id, 'id');
    return FileBackedTask._(
      bundleDirectory: bundleDirectory,
      id: id,
      version: _optionalInt(manifest, 'version') ?? 1,
      category: _parseCategory(_requiredString(manifest, 'category')),
      track: _parseTrack(_optionalString(manifest, 'track') ?? 'codegen'),
      tags: {
        for (final tag in _optionalStringList(manifest, 'tags'))
          _parseTaskTag(tag),
      },
      difficulty: _parseDifficulty(
        _optionalString(manifest, 'difficulty') ?? 'unspecified',
      ),
      timeout: switch (_optionalInt(manifest, 'timeoutSeconds')) {
        null => null,
        final seconds => Duration(seconds: seconds),
      },
      platformRequirements: {
        for (final platform in _optionalStringList(
          manifest,
          'platformRequirements',
        ))
          _parseTaskPlatform(platform),
      },
      releaseMetadata: _parseReleaseMetadata(_optionalMap(manifest, 'release')),
      allowInternet: _parseAllowInternet(manifest),
      resourceLimits: _parseResourceLimits(_optionalMap(manifest, 'resources')),
      generatedCodePath: _requiredPathString(
        manifest['generatedCodePath'],
        'generatedCodePath',
      ),
      isFlutter: _optionalBool(manifest, 'isFlutter') ?? false,
      judgeRubric: judgeRubricPath == null
          ? _optionalString(manifest, 'judgeRubric')
          : await _readBundleText(bundleDirectory, judgeRubricPath),
      instructionPath: _requiredString(manifest, 'instructionPath'),
      workspace: _WorkspaceSpec.fromYaml(_requiredMap(manifest, 'workspace')),
      hiddenVerifierSpecs: [
        for (final item in _optionalMapList(manifest, 'hiddenVerifiers'))
          _HiddenVerifierSpec.fromYaml(item),
      ],
      referenceSpec: switch (_optionalMap(manifest, 'reference')) {
        null => null,
        final reference => _ReferenceSpec.fromYaml(reference),
      },
      negativeCaseSpecs: [
        for (final item in _optionalMapList(manifest, 'negativeCases'))
          _NegativeCaseSpec.fromYaml(item),
      ],
      requiredNegativeCaseKinds: {
        for (final kind in _optionalStringList(
          manifest,
          'requiredNegativeCaseKinds',
        ))
          TaskNegativeCaseKindLabel.fromWireName(kind),
      },
    );
  }

  @override
  final String id;

  @override
  final int version;

  @override
  final Category category;

  @override
  final BenchmarkTrack track;

  @override
  final Set<TaskTag> tags;

  @override
  final TaskDifficulty difficulty;

  @override
  final Duration? timeout;

  @override
  final Set<TaskPlatform> platformRequirements;

  @override
  final TaskReleaseMetadata releaseMetadata;

  @override
  final bool allowInternet;

  @override
  final TaskResourceLimits resourceLimits;

  @override
  final String generatedCodePath;

  @override
  final bool isFlutter;

  @override
  final String? judgeRubric;

  @override
  String get prompt => _prompt ?? '';

  @override
  Map<String, String> get fixtures => _fixtures ?? const {};

  @override
  List<VerifierFixture> get hiddenVerifiers => _hiddenVerifiers ?? const [];

  @override
  ReferenceSolution? get referenceSolution => _loadedReferenceSolution;

  @override
  List<TaskNegativeCase> get negativeCases => _loadedNegativeCases ?? const [];

  @override
  Set<TaskNegativeCaseKind> get requiredNegativeCaseKinds =>
      _requiredNegativeCaseKinds.isEmpty
      ? super.requiredNegativeCaseKinds
      : _requiredNegativeCaseKinds;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures != null) return;
    _prompt = await _readBundleText(bundleDirectory, _instructionPath);
    _fixtures = await _readFiles(
      bundleDirectory,
      _workspaceSpec.root,
      _workspaceSpec.files,
    );
    _hiddenVerifiers = [
      for (final verifier in _hiddenVerifierSpecs)
        VerifierFixture(
          id: verifier.id,
          testPath: verifier.testPath,
          files: await _readFiles(
            bundleDirectory,
            verifier.root,
            verifier.files,
          ),
        ),
    ];
    _loadedReferenceSolution = switch (_referenceSpec) {
      null => null,
      final spec => ReferenceFileSolution(
        await _readFiles(bundleDirectory, spec.root, spec.files),
      ),
    };
    _loadedNegativeCases = [
      for (final spec in _negativeCaseSpecs)
        TaskNegativeCase(
          id: spec.id,
          description: spec.description,
          kind: spec.kind,
          rootPath: spec.root,
          solution: ReferenceFileSolution(
            await _readFiles(bundleDirectory, spec.root, spec.files),
          ),
        ),
    ];
  }

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    CompileEvaluator(),
    AnalyzeEvaluator(),
    TestEvaluator(),
    ...hiddenVerifiers.map(HiddenTestEvaluator.new),
    if (config.hasJudge)
      LlmJudgeEvaluator(
        judge: config.judgeProvider!,
        judgeModel: config.judgeModel!,
      ),
    DiffSizeEvaluator(originalFixturePath: generatedCodePath),
  ];
}

Future<List<FileBackedTask>> loadFileBackedTasks(Directory root) async {
  if (!await root.exists()) return const [];
  final tasks = <FileBackedTask>[];
  await for (final entity in root.list(followLinks: false)) {
    if (entity is! Directory) continue;
    final manifest = File(p.join(entity.path, 'task.yaml'));
    if (!await manifest.exists()) continue;
    tasks.add(await FileBackedTask.load(entity));
  }
  tasks.sort((a, b) => a.id.compareTo(b.id));
  return tasks;
}

class _WorkspaceSpec {
  const _WorkspaceSpec({required this.root, required this.files});

  final String root;
  final Map<String, String> files;

  factory _WorkspaceSpec.fromYaml(YamlMap yaml) {
    return _WorkspaceSpec(
      root: _requiredString(yaml, 'root'),
      files: _parseFileMap(yaml['files'], field: 'workspace.files'),
    );
  }
}

class _HiddenVerifierSpec {
  const _HiddenVerifierSpec({
    required this.id,
    required this.testPath,
    required this.root,
    required this.files,
  });

  final String id;
  final String testPath;
  final String root;
  final Map<String, String> files;

  factory _HiddenVerifierSpec.fromYaml(YamlMap yaml) {
    return _HiddenVerifierSpec(
      id: _normalizeHiddenVerifierId(_optionalString(yaml, 'id')),
      testPath: _requiredString(yaml, 'testPath'),
      root: _requiredString(yaml, 'root'),
      files: _parseFileMap(yaml['files'], field: 'hiddenVerifiers.files'),
    );
  }
}

String _normalizeHiddenVerifierId(String? id) {
  final value = (id ?? 'hidden_test').trim();
  if (value.isEmpty) {
    throw const FormatException('hiddenVerifiers.id must not be empty');
  }
  _validateTaskId(value, 'hiddenVerifiers.id');
  if (value == 'hidden_test' || value.endsWith('_hidden')) return value;
  return '${value}_hidden';
}

class _ReferenceSpec {
  const _ReferenceSpec({required this.root, required this.files});

  final String root;
  final Map<String, String> files;

  factory _ReferenceSpec.fromYaml(YamlMap yaml) {
    final type = _optionalString(yaml, 'type') ?? 'files';
    if (type != 'files') {
      throw FormatException('Unsupported reference type: $type');
    }
    return _ReferenceSpec(
      root: _requiredString(yaml, 'root'),
      files: _parseFileMap(yaml['files'], field: 'reference.files'),
    );
  }
}

class _NegativeCaseSpec {
  const _NegativeCaseSpec({
    required this.id,
    required this.description,
    required this.kind,
    required this.root,
    required this.files,
  });

  final String id;
  final String description;
  final TaskNegativeCaseKind kind;
  final String root;
  final Map<String, String> files;

  factory _NegativeCaseSpec.fromYaml(YamlMap yaml) {
    return _NegativeCaseSpec(
      id: _requiredString(yaml, 'id'),
      description: _requiredString(yaml, 'description'),
      kind: TaskNegativeCaseKindLabel.fromWireName(
        _optionalString(yaml, 'kind') ?? 'custom',
      ),
      root: _requiredString(yaml, 'root'),
      files: _parseFileMap(yaml['files'], field: 'negativeCases.files'),
    );
  }
}

Future<YamlMap> _readYamlMap(Directory bundleDirectory, String path) async {
  final filePath = _resolveBundleFilePath(bundleDirectory, path);
  final decoded = loadYaml(await File(filePath).readAsString());
  if (decoded is YamlMap) return decoded;
  throw FormatException('Task manifest must be a YAML map: $filePath');
}

Future<String> _readBundleText(Directory bundleDirectory, String path) async {
  return File(_resolveBundleFilePath(bundleDirectory, path)).readAsString();
}

Future<Map<String, String>> _readFiles(
  Directory bundleDirectory,
  String root,
  Map<String, String> files,
) async {
  final result = <String, String>{};
  for (final entry in files.entries) {
    result[entry.value] = await File(
      _resolveBundleFilePath(bundleDirectory, p.join(root, entry.key)),
    ).readAsString();
  }
  return Map.unmodifiable(result);
}

String _resolveBundleFilePath(Directory bundleDirectory, String relativePath) {
  _validateRelativePath(relativePath, 'bundle path');
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

  var current = root;
  final parts = p.split(p.normalize(relativePath));
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    final candidate = p.normalize(p.join(current, part));
    if (!p.isWithin(root, candidate)) {
      throw ArgumentError.value(relativePath, 'relativePath', 'escapes bundle');
    }
    final type = FileSystemEntity.typeSync(candidate, followLinks: false);
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
    current = candidate;
  }
  final resolved = p.normalize(current);
  if (!p.isWithin(root, resolved)) {
    throw ArgumentError.value(relativePath, 'relativePath', 'escapes bundle');
  }
  return resolved;
}

void _validateRelativePath(String value, String field) {
  final normalized = p.normalize(value);
  if (normalized == '.' ||
      p.isAbsolute(value) ||
      p.split(normalized).contains('..')) {
    throw ArgumentError.value(value, field, 'must be a relative file path');
  }
}

void _validateTaskId(String value, String field) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed == '.' ||
      trimmed == '..' ||
      trimmed.contains('/') ||
      trimmed.contains(r'\')) {
    throw ArgumentError.value(value, field, 'must be a safe task id');
  }
}

Map<String, String> _parseFileMap(Object? yaml, {required String field}) {
  if (yaml is! YamlMap) {
    throw FormatException('$field must be a YAML map');
  }
  return {
    for (final entry in yaml.entries)
      _requiredPathString(entry.key, '$field key'): _requiredPathString(
        entry.value,
        '$field value',
      ),
  };
}

String _requiredPathString(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  _validateRelativePath(value, field);
  return value;
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

List<String> _optionalStringList(YamlMap yaml, String field) {
  final value = yaml[field];
  if (value == null) return const [];
  if (value is! YamlList) throw FormatException('$field must be a YAML list');
  return [
    for (final item in value)
      if (item is String)
        item
      else
        throw FormatException('$field items must be strings'),
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

int? _optionalInt(YamlMap yaml, String field) {
  final value = yaml[field];
  if (value == null || value is int) return value as int?;
  throw FormatException('$field must be an integer');
}

bool? _optionalBool(YamlMap yaml, String field) {
  final value = yaml[field];
  if (value == null || value is bool) return value as bool?;
  throw FormatException('$field must be a boolean');
}

bool _parseAllowInternet(YamlMap yaml) {
  final explicitAllowInternet = _optionalBool(yaml, 'allowInternet');
  if (explicitAllowInternet != null) return explicitAllowInternet;

  final network = yaml['network'];
  if (network == null) return false;
  if (network is bool) return network;
  if (network is YamlMap) {
    final allowInternet = _optionalBool(network, 'allowInternet');
    if (allowInternet != null) return allowInternet;
  }
  throw const FormatException('network must be a boolean or YAML map');
}

TaskReleaseMetadata _parseReleaseMetadata(YamlMap? yaml) {
  if (yaml == null) return const TaskReleaseMetadata();
  return TaskReleaseMetadata(
    corpus: TaskCorpusLabel.fromWireName(
      _optionalString(yaml, 'corpus') ?? TaskCorpus.publicDiagnostic.wireName,
    ),
    status: TaskReleaseStatusLabel.fromWireName(
      _optionalString(yaml, 'status') ?? TaskReleaseStatus.active.wireName,
    ),
    releaseCycle:
        _optionalString(yaml, 'releaseCycle') ??
        _optionalString(yaml, 'release_cycle'),
  );
}

TaskResourceLimits _parseResourceLimits(YamlMap? yaml) {
  if (yaml == null) return const TaskResourceLimits();
  return TaskResourceLimits(
    cpus: _optionalPositiveInt(yaml, const ['cpus'], 'resources.cpus'),
    memoryMb: _optionalPositiveInt(yaml, const [
      'memoryMb',
      'memory_mb',
    ], 'resources.memoryMb'),
    maxProcesses: _optionalPositiveInt(yaml, const [
      'maxProcesses',
      'max_processes',
    ], 'resources.maxProcesses'),
    maxOutputBytes: _optionalPositiveInt(yaml, const [
      'maxOutputBytes',
      'max_output_bytes',
    ], 'resources.maxOutputBytes'),
  );
}

int? _optionalPositiveInt(YamlMap yaml, List<String> keys, String field) {
  Object? value;
  for (final key in keys) {
    if (yaml.containsKey(key)) {
      value = yaml[key];
      break;
    }
  }
  if (value == null) return null;
  if (value is! int) throw FormatException('$field must be an integer');
  if (value <= 0) throw FormatException('$field must be positive');
  return value;
}

Category _parseCategory(String value) {
  return Category.values.firstWhere(
    (category) => _matchesEnumName(category.name, value),
    orElse: () => throw FormatException('Unknown category: $value'),
  );
}

BenchmarkTrack _parseTrack(String value) {
  return BenchmarkTrack.values.firstWhere(
    (track) => _matchesEnumName(track.name, value),
    orElse: () => throw FormatException('Unknown track: $value'),
  );
}

TaskTag _parseTaskTag(String value) {
  return TaskTag.values.firstWhere(
    (tag) => _matchesEnumName(tag.name, value) || tag.slug == value,
    orElse: () => throw FormatException('Unknown task tag: $value'),
  );
}

TaskDifficulty _parseDifficulty(String value) {
  return TaskDifficulty.values.firstWhere(
    (difficulty) => _matchesEnumName(difficulty.name, value),
    orElse: () => throw FormatException('Unknown difficulty: $value'),
  );
}

TaskPlatform _parseTaskPlatform(String value) {
  return TaskPlatform.values.firstWhere(
    (platform) => _matchesEnumName(platform.name, value),
    orElse: () => throw FormatException('Unknown platform: $value'),
  );
}

bool _matchesEnumName(String enumName, String input) {
  return _normalizeEnumName(enumName) == _normalizeEnumName(input);
}

String _normalizeEnumName(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
}
