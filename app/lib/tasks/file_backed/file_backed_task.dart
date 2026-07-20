import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_bundle_inspection.dart';
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
    required this.bundleInspection,
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
    required TaskBundleFileSet workspace,
    required List<_HiddenVerifierSpec> hiddenVerifierSpecs,
    required _ReferenceSpec? referenceSpec,
    required List<_NegativeCaseSpec> negativeCaseSpecs,
    required Set<TaskNegativeCaseKind> requiredNegativeCaseKinds,
  }) : _workspaceSpec = workspace,
       _hiddenVerifierSpecs = hiddenVerifierSpecs,
       _referenceSpec = referenceSpec,
       _negativeCaseSpecs = negativeCaseSpecs,
       _requiredNegativeCaseKinds = requiredNegativeCaseKinds;

  final TaskBundleInspection bundleInspection;
  final TaskBundleFileSet _workspaceSpec;
  final List<_HiddenVerifierSpec> _hiddenVerifierSpecs;
  final _ReferenceSpec? _referenceSpec;
  final List<_NegativeCaseSpec> _negativeCaseSpecs;
  final Set<TaskNegativeCaseKind> _requiredNegativeCaseKinds;

  Map<String, String>? _fixtures;
  String? _prompt;
  List<VerifierFixture>? _hiddenVerifiers;
  ReferenceSolution? _loadedReferenceSolution;
  List<TaskNegativeCase>? _loadedNegativeCases;

  Directory get bundleDirectory => bundleInspection.bundleDirectory;

  static Future<FileBackedTask> load(Directory bundleDirectory) async {
    return fromInspection(await TaskBundleInspection.inspect(bundleDirectory));
  }

  static Future<FileBackedTask> fromInspection(
    TaskBundleInspection inspection,
  ) async {
    final manifest = inspection.manifest;
    final id = _requiredString(manifest, 'id');
    _validateTaskId(id, 'id');
    return FileBackedTask._(
      bundleInspection: inspection,
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
      judgeRubric: inspection.judgeRubricPath == null
          ? _optionalString(manifest, 'judgeRubric')
          : await inspection.readText(inspection.judgeRubricPath!),
      workspace: inspection.workspace,
      hiddenVerifierSpecs: [
        for (final (index, item) in _optionalMapList(
          manifest,
          'hiddenVerifiers',
        ).indexed)
          _HiddenVerifierSpec.fromYaml(item, inspection.hiddenVerifiers[index]),
      ],
      referenceSpec: inspection.reference == null
          ? null
          : _ReferenceSpec(fileSet: inspection.reference!),
      negativeCaseSpecs: [
        for (final (index, item) in _optionalMapList(
          manifest,
          'negativeCases',
        ).indexed)
          _NegativeCaseSpec.fromYaml(item, inspection.negativeCases[index]),
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
    try {
      await bundleInspection.validateDeclaredFiles();
    } on FileSystemException catch (error) {
      throw ArgumentError.value(error.path, 'bundle path', error.message);
    }
    _prompt = await bundleInspection.readText(bundleInspection.instructionPath);
    _fixtures = await bundleInspection.readFiles(_workspaceSpec);
    _hiddenVerifiers = [
      for (final verifier in _hiddenVerifierSpecs)
        VerifierFixture(
          id: verifier.id,
          authoredId: verifier.authoredId,
          testPath: verifier.testPath,
          files: await bundleInspection.readFiles(verifier.fileSet),
        ),
    ];
    _loadedReferenceSolution = switch (_referenceSpec) {
      null => null,
      final spec => ReferenceFileSolution(
        await bundleInspection.readFiles(spec.fileSet),
        rootPath: spec.fileSet.root,
      ),
    };
    _loadedNegativeCases = [
      for (final spec in _negativeCaseSpecs)
        TaskNegativeCase(
          id: spec.id,
          description: spec.description,
          kind: spec.kind,
          rootPath: spec.fileSet.root,
          solution: ReferenceFileSolution(
            await bundleInspection.readFiles(spec.fileSet),
          ),
        ),
    ];
  }

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    const CompileEvaluator(),
    const AnalyzeEvaluator(),
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
  final tasks = <FileBackedTask>[];
  for (final inspection in await inspectTaskBundles(root)) {
    tasks.add(await FileBackedTask.fromInspection(inspection));
  }
  tasks.sort((a, b) => a.id.compareTo(b.id));
  return tasks;
}

class _HiddenVerifierSpec {
  const _HiddenVerifierSpec({
    required this.id,
    required this.authoredId,
    required this.testPath,
    required this.fileSet,
  });

  final String id;
  final String? authoredId;
  final String testPath;
  final TaskBundleFileSet fileSet;

  factory _HiddenVerifierSpec.fromYaml(
    YamlMap yaml,
    TaskBundleFileSet fileSet,
  ) {
    final authoredId = _optionalString(yaml, 'id')?.trim();
    return _HiddenVerifierSpec(
      id: _normalizeHiddenVerifierId(authoredId),
      authoredId: authoredId,
      testPath: _requiredString(yaml, 'testPath'),
      fileSet: fileSet,
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
  const _ReferenceSpec({required this.fileSet});

  final TaskBundleFileSet fileSet;
}

class _NegativeCaseSpec {
  const _NegativeCaseSpec({
    required this.id,
    required this.description,
    required this.kind,
    required this.fileSet,
  });

  final String id;
  final String description;
  final TaskNegativeCaseKind kind;
  final TaskBundleFileSet fileSet;

  factory _NegativeCaseSpec.fromYaml(YamlMap yaml, TaskBundleFileSet fileSet) {
    return _NegativeCaseSpec(
      id: _requiredString(yaml, 'id'),
      description: _requiredString(yaml, 'description'),
      kind: TaskNegativeCaseKindLabel.fromWireName(
        _optionalString(yaml, 'kind') ?? 'custom',
      ),
      fileSet: fileSet,
    );
  }
}

String _requiredPathString(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  final normalized = p.normalize(value);
  if (normalized == '.' ||
      p.isAbsolute(value) ||
      p.split(normalized).contains('..')) {
    throw ArgumentError.value(value, field, 'must be a relative file path');
  }
  return value;
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
