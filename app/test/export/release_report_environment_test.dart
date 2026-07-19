import 'package:dart_arena/export/release_report.dart';
import 'package:test/test.dart';

void main() {
  test('blocks aggregates spanning multiple environments by default', () {
    final report = _buildReport(const ReleaseReportOptions(releaseId: 'test'));

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(blockers, contains('Leaderboard aggregate spans 2 environment IDs'));
    expect(blockers, contains('Leaderboard aggregate spans 2 Dart versions'));
    expect(
      blockers,
      contains('Leaderboard aggregate spans 2 Flutter versions'),
    );
  });

  test('mixed environments are warnings under the explicit policy flag', () {
    final report = _buildReport(
      const ReleaseReportOptions(
        releaseId: 'test',
        allowMixedEnvironmentAggregates: true,
      ),
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(blockers, isNot(contains('Leaderboard aggregate spans')));
    final warnings = (report['warnings']! as List<Object?>).join('\n');
    expect(warnings, contains('Leaderboard aggregate spans 2 environment IDs'));
    expect(
      warnings,
      contains('Permitted by allowMixedEnvironmentAggregates policy.'),
    );
  });

  test('single-environment aggregates are not blocked', () {
    final report = _buildReport(
      const ReleaseReportOptions(releaseId: 'test'),
      environmentIds: const ['env-1'],
      dartVersions: const ['3.11.4'],
      flutterVersions: const ['3.41.6'],
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(blockers, isNot(contains('Leaderboard aggregate spans')));
  });

  test('stored environments are cross-checked against the leaderboard', () {
    final report = _buildReport(
      const ReleaseReportOptions(releaseId: 'test'),
      environmentIds: const ['forged-single-environment'],
      dartVersions: const ['3.11.4'],
      flutterVersions: const ['3.41.6'],
      runProvenanceById: {
        'run-1': _storedProvenance(lockDigestChar: 'a'),
        'run-2': _storedProvenance(lockDigestChar: 'b'),
      },
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Leaderboard source run provenance environment IDs do not match stored run provenance.',
      ),
    );
  });

  test('legacy polling-only task QA evidence is blocked', () {
    final report = _buildReport(
      const ReleaseReportOptions(releaseId: 'test'),
      taskQaReports: [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'track': 'agentic',
          'executionPolicy': {
            'allowInternet': false,
            'resources': {
              'cpus': 2,
              'memoryMb': 8192,
              'maxProcesses': 64,
              'maxOutputBytes': 1048576,
            },
            'resourceEnforcement': {
              'cpus': {
                'enforced': true,
                'mechanism': 'systemdCpuQuota',
                'kernelEnforced': true,
              },
              'memoryMb': {
                'enforced': true,
                'mechanism': 'rssPolling',
                'kernelEnforced': false,
              },
              'maxProcesses': {
                'enforced': true,
                'mechanism': 'processTreePolling',
                'kernelEnforced': false,
              },
              'maxOutputBytes': {
                'enforced': true,
                'mechanism': 'boundedOutputCapture',
                'kernelEnforced': false,
              },
            },
          },
        },
      ],
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Task QA report task.a@v1 has incomplete or unenforced task resource limit provenance.',
      ),
    );
  });
}

Map<String, Object?> _buildReport(
  ReleaseReportOptions options, {
  List<String> environmentIds = const ['env-1', 'env-2'],
  List<String> dartVersions = const ['3.11.3', '3.11.4'],
  List<String> flutterVersions = const ['3.41.5', '3.41.6'],
  List<Map<String, Object?>> taskQaReports = const [],
  Map<String, Map<String, Object?>>? runProvenanceById,
}) {
  return buildReleaseReport(
    leaderboard: {
      'benchmark': const {
        'dataPolicy': 'aggregate-compatible',
        'version': 'v1',
        'taskSetId': 'set',
        'evaluatorSchemaVersion': 2,
      },
      'source': {
        'runIds': const ['run-1', 'run-2'],
        'taskRunCount': 2,
        'runProvenance': {
          'runCount': 2,
          'embeddedRunCount': 2,
          'sandboxEnforcedRunCount': 2,
          'taskExecutionPolicyRunCount': 2,
          'networkDisabledTaskPolicyRunCount': 2,
          'taskResourceLimitRunCount': 2,
          'sdkVersionRunCount': 2,
          'dependencySnapshotRunCount': 2,
          'pricingRegistryRunCount': 2,
          'generatedCodeSandboxBackends': const ['bubblewrap'],
          'dartVersions': dartVersions,
          'flutterVersions': flutterVersions,
          'environmentIds': environmentIds,
          'warnings': const <Object?>[],
        },
      },
      'models': const <Object?>[],
      'tasks': const <Object?>[],
    },
    taskQaSummary: const <String, Object?>{},
    taskQaReports: taskQaReports,
    options: options,
    runProvenanceById: runProvenanceById,
  );
}

Map<String, Object?> _storedProvenance({required String lockDigestChar}) => {
  'environment': {
    'hostPlatform': 'linux',
    'dartVersion': '3.11.4 (stable)',
    'flutterVersion': '3.41.6',
    'dependencySnapshot': {
      'status': 'present',
      'files': {
        'pubspec.lock': {
          'sha256': List.filled(64, lockDigestChar).join(),
          'bytes': 123,
        },
      },
    },
  },
};
