import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/runner/run_event.dart';
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

class DefaultRunProvenanceEnvironmentProvider
    implements RunProvenanceEnvironmentProvider {
  DefaultRunProvenanceEnvironmentProvider({
    this.timeout = const Duration(milliseconds: 800),
  });

  final Duration timeout;
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

    return {
      'hostPlatform': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'dartVersion': dartVersion.isEmpty ? 'unknown' : dartVersion,
      'flutterVersion': flutterVersion ?? 'unknown',
      'gitCommit': gitCommit ?? 'unknown',
      'gitDirty': gitStatus?.isNotEmpty,
    };
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
      ).timeout(timeout);
    } on Object {
      return null;
    }
  }
}

Future<String> buildRunProvenanceJson({
  required String runId,
  required StartRun event,
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
      event.providers
          .where((provider) => selectedProviderIds.contains(provider.id))
          .map(
            (provider) => {
              'id': provider.id,
              'displayName': provider.displayName,
              'mode': provider.mode.name,
              'selectedModels': _sortedStrings(
                normalizedModelsByProvider[provider.id] ?? const <String>[],
              ),
              'secretsRedacted': true,
            },
          )
          .toList()
        ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));

  final tasks = event.tasks.map(_taskJson).toList()
    ..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));

  final sortedCombos = combos.toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  final json = <String, Object?>{
    'schemaVersion': 1,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'runId': runId,
    'config': {
      'name': event.name,
      'maxConcurrency': event.maxConcurrency.clamp(1, 8),
      'trialsPerTask': event.trialsPerTask < 1 ? 1 : event.trialsPerTask,
      'useReferencePlan': event.useReferencePlan,
      'existingRunId': event.existingRunId,
      'modelsByProvider': _sortedModelsMap(normalizedModelsByProvider),
      'evaluatorWeights': _sortedNumberMap(evaluatorWeights),
      'judge': {
        'providerId': event.evaluatorConfig.judgeProvider?.id,
        'modelId': event.evaluatorConfig.judgeModel,
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
          'trialIndex': combo.trialIndex,
          'planId': combo.planId,
        },
    ],
    'environment': _sortedObjectMap(environment),
  };

  return const JsonEncoder.withIndent('  ').convert(json);
}

Map<String, Object?> _taskJson(BenchmarkTask task) {
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
    'generatedCodePath': task.generatedCodePath,
    'isFlutter': task.isFlutter,
    'promptSha256': _sha256(task.prompt),
    'publicFixtureDigests': _fixtureDigests(task.fixtures),
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
