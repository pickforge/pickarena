import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_arena/analytics/cost_estimator.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_identity.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/core/task_integrity.dart';
import 'package:dart_arena/core/task_run_result.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/resource_enforcement_policy.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';
import 'package:path/path.dart' as p;

class RunProvenanceCombo {
  const RunProvenanceCombo({
    required this.index,
    required this.task,
    required this.providerId,
    required this.modelId,
    required this.trialIndex,
    required this.planId,
  });

  final int index;
  final BenchmarkTask task;
  final String providerId;
  final String modelId;
  final int trialIndex;
  final String? planId;
}

abstract class RunProvenanceEnvironmentProvider {
  Future<Map<String, Object?>> capture();
}

class RunProvenanceConfig {
  const RunProvenanceConfig({
    required this.tasks,
    required this.providers,
    required this.evaluatorConfig,
    this.useReferencePlan = false,
    this.name,
    this.maxConcurrency = 4,
    this.trialsPerTask = 1,
    this.generatedCodeSandboxRequired = false,
    this.generatedCodeSandboxEnforced = false,
    this.generatedCodeSandboxBackend,
    this.agentHarnessProvenance = const {},
    this.preset,
    this.corpusManifest,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final EvaluatorConfig evaluatorConfig;
  final bool useReferencePlan;
  final String? name;
  final int maxConcurrency;
  final int trialsPerTask;
  final bool generatedCodeSandboxRequired;
  final bool generatedCodeSandboxEnforced;
  final String? generatedCodeSandboxBackend;
  final Map<String, Map<String, Object?>> agentHarnessProvenance;
  final String? preset;
  final Map<String, Object?>? corpusManifest;
}

class DefaultRunProvenanceEnvironmentProvider
    implements RunProvenanceEnvironmentProvider {
  DefaultRunProvenanceEnvironmentProvider({
    this.timeout = const Duration(milliseconds: 800),
    Directory? dependencyRoot,
    Map<String, String>? baseEnvironment,
  }) : _dependencyRoot = dependencyRoot,
       _baseEnvironment = baseEnvironment;

  final Duration timeout;
  final Directory? _dependencyRoot;
  final Map<String, String>? _baseEnvironment;
  Future<Map<String, Object?>>? _cached;

  @override
  Future<Map<String, Object?>> capture() {
    return _cached ??= _capture();
  }

  Future<Map<String, Object?>> _capture() async {
    final dartVersion = Platform.version.split('\n').first;
    final flutterVersion = await _flutterVersion();
    final gitCommit = await _processLine('git', ['rev-parse', 'HEAD']);
    final gitStatus = await _processLine('git', ['status', '--porcelain']);
    final dependencySnapshot = await _dependencySnapshot();

    return {
      'hostPlatform': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'dartVersion': dartVersion.isEmpty ? 'unknown' : dartVersion,
      'flutterVersion': flutterVersion ?? 'unknown',
      'gitCommit': gitCommit ?? 'unknown',
      'gitDirty': gitStatus?.isNotEmpty,
      'dependencySnapshot': dependencySnapshot,
    };
  }

  Future<Map<String, Object?>> _dependencySnapshot() async {
    final root = await _firstDependencyRoot();
    if (root == null) {
      return const {'status': 'missing', 'files': <String, Object?>{}};
    }

    final files = <String, Object?>{};
    for (final name in const ['pubspec.yaml', 'pubspec.lock']) {
      final file = File(p.join(root.path, name));
      try {
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        files[name] = {
          'sha256': sha256.convert(bytes).toString(),
          'bytes': bytes.length,
        };
      } on Object {
        continue;
      }
    }

    return {'status': files.isEmpty ? 'missing' : 'present', 'files': files};
  }

  Future<Directory?> _firstDependencyRoot() async {
    final roots = <String, Directory>{};
    void addRoot(Directory? directory) {
      if (directory == null) return;
      roots[p.normalize(p.absolute(directory.path))] = directory;
    }

    addRoot(_dependencyRoot);
    addRoot(await _packageRoot());
    addRoot(Directory.current);
    addRoot(Directory(p.join(Directory.current.path, 'app')));

    for (final root in roots.values) {
      if (await File(p.join(root.path, 'pubspec.lock')).exists() ||
          await File(p.join(root.path, 'pubspec.yaml')).exists()) {
        return root;
      }
    }
    return null;
  }

  Future<Directory?> _packageRoot() async {
    try {
      final uri = await Isolate.resolvePackageUri(
        Uri.parse('package:dart_arena/runner/run_provenance.dart'),
      );
      if (uri == null || !uri.isScheme('file')) return null;
      final path = p.fromUri(uri);
      return Directory(p.dirname(p.dirname(p.dirname(path))));
    } on Object {
      return null;
    }
  }

  Future<String?> _flutterVersion() async {
    final result = await _run('flutter', ['--version', '--machine']);
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
    final result = await _run(executable, args);
    if (result == null || result.exitCode != 0) return null;
    return '${result.stdout}${result.stderr}'.trim();
  }

  Future<ProcessResult?> _run(String executable, List<String> args) async {
    try {
      return await Process.run(
        executable,
        args,
        runInShell: false,
        environment: benchmarkSubprocessEnvironment(
          baseEnvironment: _baseEnvironment,
        ),
        includeParentEnvironment: false,
      ).timeout(timeout);
    } on Object {
      return null;
    }
  }
}

Future<String> buildRunProvenanceJson({
  required String runId,
  required RunProvenanceConfig config,
  required Map<String, List<String>> normalizedModelsByProvider,
  required List<RunProvenanceCombo> combos,
  required Map<String, double> evaluatorWeights,
  required DateTime capturedAt,
  RunProvenanceEnvironmentProvider? environmentProvider,
}) async {
  final environment =
      await (environmentProvider ?? DefaultRunProvenanceEnvironmentProvider())
          .capture();

  final selectedProviderIds = normalizedModelsByProvider.keys.toSet();
  final providers =
      config.providers
          .where((provider) => selectedProviderIds.contains(provider.id))
          .map((provider) {
            final runtimeConfig = _providerRuntimeConfig(provider);
            return {
              'id': provider.id,
              'displayName': provider.displayName,
              'mode': provider.mode.name,
              if (runtimeConfig.isNotEmpty) 'runtimeConfig': runtimeConfig,
              'selectedModels': _sortedStrings(
                normalizedModelsByProvider[provider.id] ?? const <String>[],
              ),
              'selectedModelConfigs': _sortedModelConfigs(
                provider,
                normalizedModelsByProvider[provider.id] ?? const <String>[],
              ),
              'secretsRedacted': true,
            };
          })
          .toList()
        ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));

  final tasks =
      config.tasks
          .map(
            (task) => _taskJson(
              task,
              kernelEnforcementAvailable: config.generatedCodeSandboxEnforced,
            ),
          )
          .toList()
        ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));

  final sortedCombos = combos.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  final selectedProvidersById = {
    for (final provider in config.providers)
      if (selectedProviderIds.contains(provider.id)) provider.id: provider,
  };

  final json = <String, Object?>{
    'schemaVersion': 2,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'runId': runId,
    'config': {
      'name': config.name,
      'maxConcurrency': config.maxConcurrency.clamp(1, 8),
      'trialsPerTask': config.trialsPerTask < 1 ? 1 : config.trialsPerTask,
      'useReferencePlan': config.useReferencePlan,
      'scoringSchemaVersion': dartArenaScoringSchemaVersion,
      'generatedCodeSandbox': {
        'required': config.generatedCodeSandboxRequired,
        'enforced': config.generatedCodeSandboxEnforced,
        if (config.generatedCodeSandboxBackend != null)
          'backend': config.generatedCodeSandboxBackend,
      },
      'agentHarnesses': config.agentHarnessProvenance,
      if (config.preset != null) 'preset': config.preset,
      if (config.corpusManifest != null)
        'corpusManifest': config.corpusManifest,
      'pricingRegistry': pricingRegistryProvenance(),
      'modelsByProvider': _sortedModelsMap(normalizedModelsByProvider),
      'evaluatorWeights': _sortedNumberMap(evaluatorWeights),
      'judge': {
        'providerId': config.evaluatorConfig.judgeProvider?.id,
        'modelId': config.evaluatorConfig.judgeModel,
      },
    },
    'providers': providers,
    'tasks': tasks,
    'combos': [
      for (final combo in sortedCombos)
        {
          'index': combo.index,
          'taskId': combo.task.id,
          'providerId': combo.providerId,
          'modelId': combo.modelId,
          ...modelIdentityExportJson(
            providerId: combo.providerId,
            modelId: combo.modelId,
            additionalModelConfig: _modelRuntimeConfig(
              selectedProvidersById[combo.providerId],
              combo.modelId,
            ),
          ),
          'trialIndex': combo.trialIndex,
          'planId': combo.planId,
        },
    ],
    'environment': _sortedObjectMap(environment),
  };

  return const JsonEncoder.withIndent('  ').convert(json);
}

String appendResultProvenance(
  String provenanceJson,
  Iterable<TaskRunResult> results,
) {
  final decoded = jsonDecode(provenanceJson);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('run provenance must be a JSON object');
  }
  final resultProvenance =
      [
        for (final result in results)
          {
            'taskId': result.taskId,
            'taskVersion': result.taskVersion,
            'providerId': result.providerId,
            'modelId': result.modelId,
            'trialIndex': result.trialIndex,
            'benchmarkTrack': result.benchmarkTrack,
            ...result.provenance,
          },
      ]..sort((a, b) {
        final task = (a['taskId']! as String).compareTo(b['taskId']! as String);
        if (task != 0) return task;
        final provider = (a['providerId']! as String).compareTo(
          b['providerId']! as String,
        );
        if (provider != 0) return provider;
        final model = (a['modelId']! as String).compareTo(
          b['modelId']! as String,
        );
        if (model != 0) return model;
        return (a['trialIndex']! as int).compareTo(b['trialIndex']! as int);
      });
  return const JsonEncoder.withIndent(
    '  ',
  ).convert({...decoded, 'resultProvenance': resultProvenance});
}

Map<String, Object?> _taskJson(
  BenchmarkTask task, {
  required bool kernelEnforcementAvailable,
}) {
  final timeout = task.timeout;
  return {
    'id': task.id,
    'version': task.version,
    'category': task.category.name,
    'track': task.track.name,
    'tags': _sortedStrings(task.tags.map((tag) => tag.slug)),
    'difficulty': task.difficulty.name,
    'timeoutMs': timeout?.inMilliseconds,
    'platformRequirements': _sortedStrings(
      task.platformRequirements.map((platform) => platform.name),
    ),
    'executionPolicy': {
      'allowInternet': task.allowInternet,
      'resources': task.effectiveResourceLimits.toJson(),
      'resourceEnforcement': taskResourceEnforcementJson(
        kernelEnforcementAvailable: kernelEnforcementAvailable,
      ),
    },
    'generatedCodePath': task.generatedCodePath,
    'isFlutter': task.isFlutter,
    'promptSha256': _sha256(task.prompt),
    'publicFixtureDigests': _fixtureDigests(task.fixtures),
    'hiddenVerifierDigests': hiddenVerifierDigests(task),
    'hiddenAssetsExcluded': true,
  };
}

Map<String, String> _fixtureDigests(Map<String, String> fixtures) {
  final entries =
      fixtures.entries
          .where((entry) => _isPublicFixturePath(entry.key))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  return {for (final entry in entries) entry.key: _sha256(entry.value)};
}

bool _isPublicFixturePath(String path) {
  final parts = p
      .split(p.normalize(path))
      .map((part) => part.toLowerCase())
      .toList();
  return !parts.any(
    (part) =>
        part == '_hidden' ||
        part == 'hidden' ||
        part == 'reference' ||
        part == '_reference' ||
        part == 'author_notes' ||
        part == '_author' ||
        part == 'task_qa',
  );
}

Map<String, List<String>> _sortedModelsMap(
  Map<String, List<String>> modelsByProvider,
) {
  final keys = modelsByProvider.keys.toList()..sort();
  return {for (final key in keys) key: _sortedStrings(modelsByProvider[key]!)};
}

Map<String, Object?> _providerRuntimeConfig(ModelProvider provider) {
  if (provider is! ModelRuntimeMetadataProvider) return const {};
  final metadataProvider = provider as ModelRuntimeMetadataProvider;
  return normalizeModelMetadataJson(metadataProvider.providerRuntimeConfig());
}

Map<String, Object?> _modelRuntimeConfig(
  ModelProvider? provider,
  String modelId,
) {
  if (provider is! ModelRuntimeMetadataProvider) return const {};
  final metadataProvider = provider as ModelRuntimeMetadataProvider;
  return normalizeModelMetadataJson(
    metadataProvider.modelRuntimeConfig(modelId),
  );
}

List<Map<String, Object?>> _sortedModelConfigs(
  ModelProvider provider,
  Iterable<String> modelIds,
) {
  final identities = [
    for (final modelId in modelIds)
      ModelIdentity.from(
        providerId: provider.id,
        modelId: modelId,
        additionalModelConfig: _modelRuntimeConfig(provider, modelId),
      ),
  ]..sort((a, b) => a.modelId.compareTo(b.modelId));
  return [
    for (final identity in identities)
      {'modelId': identity.modelId, ...identity.exportJson},
  ];
}

Map<String, num> _sortedNumberMap(Map<String, double> values) {
  final keys = values.keys.toList()..sort();
  return {for (final key in keys) key: values[key]!};
}

Map<String, Object?> _sortedObjectMap(Map<String, Object?> values) {
  final keys = values.keys.toList()..sort();
  return {for (final key in keys) key: values[key]};
}

List<String> _sortedStrings(Iterable<String> values) {
  return values.toList()..sort();
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();
