import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/resource_enforcement_policy.dart';
import 'package:dart_arena/runner/task_qa_runner.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../support/official_tasks.dart';

void main() {
  final sandboxValidation = _generatedCodeSandboxValidation();

  group('official admission sandbox claim verification', () {
    test('asserts checked-in claims against the validating run', () {
      final verification = _verifyOfficialSandboxClaims(
        taskId: 'task.a',
        admission: _admissionWithSandboxClaim(
          requiredClaim: true,
          enforcedClaim: true,
          backend: bubblewrapGeneratedCodeSandboxBackend,
        ),
        validatingRuntimeIsolation: const TaskQaRuntimeIsolationReport(
          generatedCodeSandboxRequired: true,
          generatedCodeSandboxEnforced: true,
          generatedCodeSandboxBackend: bubblewrapGeneratedCodeSandboxBackend,
        ),
        sandboxValidation: const _GeneratedCodeSandboxValidation.enforced(
          BubblewrapGeneratedCodeSandbox(),
        ),
      );

      expect(verification.enforcementAsserted, isTrue);
      expect(verification.skipReason, isNull);
    });

    test('returns a visible skip when the validating run cannot enforce', () {
      final verification = _verifyOfficialSandboxClaims(
        taskId: 'task.a',
        admission: _admissionWithSandboxClaim(
          requiredClaim: true,
          enforcedClaim: true,
          backend: bubblewrapGeneratedCodeSandboxBackend,
        ),
        validatingRuntimeIsolation: const TaskQaRuntimeIsolationReport(),
        sandboxValidation: const _GeneratedCodeSandboxValidation.unavailable(
          'bwrap is not available on PATH',
        ),
      );

      expect(verification.enforcementAsserted, isFalse);
      expect(verification.skipReason, contains('bwrap is not available'));
    });

    test('returns a visible skip when the functional probe fails', () async {
      final sandboxValidation = await _generatedCodeSandboxValidation(
        isLinux: true,
        ensureAvailable: () async {},
        functionalProbe: () async {
          return 'bwrap functional probe failed with exit code 1: denied';
        },
      );
      final verification = _verifyOfficialSandboxClaims(
        taskId: 'task.a',
        admission: _admissionWithSandboxClaim(
          requiredClaim: true,
          enforcedClaim: true,
          backend: bubblewrapGeneratedCodeSandboxBackend,
        ),
        validatingRuntimeIsolation: const TaskQaRuntimeIsolationReport(),
        sandboxValidation: sandboxValidation,
      );

      expect(sandboxValidation.enforcementAvailable, isFalse);
      expect(verification.enforcementAsserted, isFalse);
      expect(verification.skipReason, contains('functional probe failed'));
    });

    test('fails when checked-in claims disagree with real enforcement', () {
      expect(
        () => _verifyOfficialSandboxClaims(
          taskId: 'task.a',
          admission: _admissionWithSandboxClaim(
            requiredClaim: true,
            enforcedClaim: true,
            backend: bubblewrapGeneratedCodeSandboxBackend,
          ),
          validatingRuntimeIsolation: const TaskQaRuntimeIsolationReport(
            generatedCodeSandboxRequired: true,
            generatedCodeSandboxEnforced: false,
            generatedCodeSandboxBackend: bubblewrapGeneratedCodeSandboxBackend,
          ),
          sandboxValidation: const _GeneratedCodeSandboxValidation.enforced(
            BubblewrapGeneratedCodeSandbox(),
          ),
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  test('official Flutter bundles load as agentic file-backed tasks', () async {
    final tasks = await _loadOfficialTasks();
    final ids = tasks.map((task) => task.id).toList();

    expect(ids, officialFlutterTaskIds);

    for (final task in tasks) {
      await task.ensureLoaded();
      expect(task.track, BenchmarkTrack.agentic, reason: task.id);
      expect(task.isFlutter, isTrue, reason: task.id);
      expect(task.releaseMetadata.toJson(), {
        'corpus': 'private_official',
        'status': 'active',
      }, reason: task.id);
      expect(task.allowInternet, isFalse, reason: task.id);
      expect(task.resourceLimits.toJson(), {
        'cpus': 2,
        'memoryMb': 8192,
        'maxProcesses': 64,
        'maxOutputBytes': 1048576,
      }, reason: task.id);
      expect(task.hiddenVerifiers, hasLength(1), reason: task.id);
      expect(task.referenceSolution, isNotNull, reason: task.id);
      expect(
        task.negativeCases.map((negativeCase) => negativeCase.kind).toSet(),
        containsAll({
          TaskNegativeCaseKind.noop,
          TaskNegativeCaseKind.apiBreaking,
          TaskNegativeCaseKind.overfit,
        }),
        reason: task.id,
      );
      expect(task.requiredNegativeCaseKinds, {
        TaskNegativeCaseKind.noop,
        TaskNegativeCaseKind.apiBreaking,
        TaskNegativeCaseKind.overfit,
      }, reason: task.id);
      expect(task.prompt.trim(), isNotEmpty, reason: task.id);
      expect(task.fixtures, contains('pubspec.yaml'), reason: task.id);
      expect(
        task.fixtures.keys,
        isNot(contains(task.hiddenVerifiers.single.testPath)),
        reason: task.id,
      );

      final evaluatorIds = task
          .evaluatorsFor(const EvaluatorConfig())
          .map((evaluator) => evaluator.id)
          .toList();
      expect(evaluatorIds, [
        'compile',
        'analyze',
        'test',
        task.hiddenVerifiers.single.id,
        'diff_size',
      ], reason: task.id);
    }
  });

  group('official Flutter bundles satisfy their admission reports', () {
    for (final taskId in officialFlutterTaskIds) {
      test(taskId, () async {
        final task = await _loadOfficialTask(taskId);
        await _expectOfficialAdmissionReportSatisfied(
          task,
          await sandboxValidation,
        );
      }, timeout: const Timeout(Duration(minutes: 8)));
    }
  });
}

Future<FileBackedTask> _loadOfficialTask(String taskId) async {
  return loadOfficialFlutterTask(taskId);
}

Future<void> _expectOfficialAdmissionReportSatisfied(
  FileBackedTask task,
  _GeneratedCodeSandboxValidation sandboxValidation,
) async {
  final root = await Directory.systemTemp.createTemp(
    'official_file_backed_${task.id}_',
  );
  addTearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  final report = await TaskQaRunner(
    workdirManager: WorkdirManager(root: root),
    requiredHiddenFlakeRuns: 3,
    requireNegativeCases: true,
    generatedCodeSandboxRequired: sandboxValidation.enforcementAvailable,
    generatedCodeSandbox: sandboxValidation.generatedCodeSandbox,
  ).run(task);
  final failures = report.failureMessages.join('\n');

  expect(report.baselineHiddenFailed, isTrue, reason: failures);
  expect(report.referencePublicPassed, isTrue, reason: failures);
  expect(report.referenceHiddenPassed, isTrue, reason: failures);
  expect(report.negativeCasesRejected, isTrue, reason: failures);
  expect(report.requiredNegativeCaseKindsCovered, isTrue, reason: failures);
  expect(report.promptSafety.passed, isTrue, reason: failures);
  expect(report.failureMessages, isEmpty, reason: task.id);

  final admission = await _readAdmissionReport(task);
  final checks = admission['checks'] as Map<String, Object?>;
  expect(admission['taskId'], task.id);
  expect(admission['taskVersion'], task.version);
  expect(admission['track'], task.track.name);
  expect(admission['status'], 'admitted');
  expect(DateTime.tryParse(admission['generatedAt']! as String), isNotNull);
  expect(admission['release'], task.releaseMetadata.toJson());
  final admissionProvenance = admission['admission'] as Map<String, Object?>;
  expect(admissionProvenance['tool'], {'name': 'dart_arena_task_qa'});
  expect(admissionProvenance['evaluator'], {
    'schemaVersion': 2,
    'version': '2026-05-31-master-spec',
  });
  final environment =
      admissionProvenance['environment'] as Map<String, Object?>;
  expect(environment['dartVersion'], isA<String>());
  expect(environment['flutterVersion'], isA<String>());
  final dependencySnapshot =
      environment['dependencySnapshot'] as Map<String, Object?>;
  expect(dependencySnapshot['status'], 'present');
  expect(
    dependencySnapshot['files'],
    containsPair('pubspec.lock', isA<Map<String, Object?>>()),
  );
  // The checked-in report was generated with the claimed sandbox state; the
  // claim itself is verified against reality by _verifyOfficialSandboxClaims.
  final admissionSandboxClaim =
      ((admission['runtimeIsolation']
              as Map<String, Object?>)['generatedCodeSandbox']
          as Map<String, Object?>);
  expect(admission['executionPolicy'], {
    'allowInternet': false,
    'resources': task.resourceLimits.toJson(),
    'resourceEnforcement': taskResourceEnforcementJson(
      kernelEnforcementAvailable: admissionSandboxClaim['enforced'] == true,
    ),
  });
  final sandboxClaims = _verifyOfficialSandboxClaims(
    taskId: task.id,
    admission: admission,
    validatingRuntimeIsolation: report.runtimeIsolation,
    sandboxValidation: sandboxValidation,
  );
  expect(checks['baselineHiddenFailed'], report.baselineHiddenFailed);
  expect(checks['referencePublicPassed'], report.referencePublicPassed);
  expect(checks['referenceHiddenPassed'], report.referenceHiddenPassed);
  expect(
    checks['noopRejected'],
    report.negativeCaseReports
        .singleWhere(
          (negativeCase) => negativeCase.kind == TaskNegativeCaseKind.noop,
        )
        .rejected,
  );
  expect(
    checks['apiBreakingRejected'],
    report.negativeCaseReports
        .singleWhere(
          (negativeCase) =>
              negativeCase.kind == TaskNegativeCaseKind.apiBreaking,
        )
        .rejected,
  );
  expect(
    checks['overfitRejected'],
    report.negativeCaseReports
        .singleWhere(
          (negativeCase) => negativeCase.kind == TaskNegativeCaseKind.overfit,
        )
        .rejected,
  );
  expect(checks['hiddenFlakeRuns'], report.hiddenFlakeRuns);
  expect(checks['promptSafeContextLeakFree'], report.promptSafety.passed);
  final hiddenDigests =
      admission['hiddenVerifierDigests'] as Map<String, Object?>;
  expect(hiddenDigests.keys, [task.hiddenVerifiers.single.id]);
  expect(hiddenDigests.values.single, matches(RegExp(r'^[0-9a-f]{64}$')));
  final quality = admission['verifierQualityAudit'] as Map<String, Object?>;
  expect(quality['falsePositiveCount'], 0);
  expect(quality['falseNegativeCount'], 0);
  expect(quality['flakeRunCount'], 3);
  expect(quality['flakeFailureCount'], 0);
  expect(quality['negativeCaseCount'], task.negativeCases.length);
  expect(quality['acceptedNegativeCaseCount'], 0);
  final promptSafety = admission['promptSafety'] as Map<String, Object?>;
  expect(promptSafety['passed'], isTrue);
  expect(promptSafety['required_negative_case_kinds'], [
    'api_breaking',
    'noop',
    'overfit',
  ]);
  expect(promptSafety['missing_negative_case_kinds'], isEmpty);
  final negativeCases = admission['negativeCases'] as List<Object?>;
  expect(
    negativeCases.map((entry) {
      return (entry as Map<String, Object?>)['kind'];
    }).toSet(),
    containsAll({'api_breaking', 'noop', 'overfit'}),
  );
  expect(
    negativeCases.every((entry) {
      return (entry as Map<String, Object?>)['rejected'] == true;
    }),
    isTrue,
  );
  expect(admission['failureMessages'], isEmpty);
  final skipReason = sandboxClaims.skipReason;
  if (skipReason != null) markTestSkipped(skipReason);
}

Future<List<FileBackedTask>> _loadOfficialTasks() {
  return loadOfficialFlutterTasks();
}

Future<Map<String, Object?>> _readAdmissionReport(FileBackedTask task) async {
  final file = File(
    p.join(task.bundleDirectory.path, 'qa', 'admission_report.json'),
  );
  return jsonDecode(await file.readAsString()) as Map<String, Object?>;
}

typedef _SandboxAvailabilityCheck = Future<void> Function();
typedef _SandboxFunctionalProbe = Future<String?> Function();

Future<_GeneratedCodeSandboxValidation> _generatedCodeSandboxValidation({
  bool? isLinux,
  _SandboxAvailabilityCheck? ensureAvailable,
  _SandboxFunctionalProbe? functionalProbe,
}) async {
  if (!(isLinux ?? Platform.isLinux)) {
    return const _GeneratedCodeSandboxValidation.unavailable(
      'Bubblewrap generated-code sandbox requires Linux',
    );
  }

  try {
    await (ensureAvailable ?? BubblewrapGeneratedCodeSandbox.ensureAvailable)();
  } on Object catch (error) {
    return _GeneratedCodeSandboxValidation.unavailable(
      'Bubblewrap generated-code sandbox preflight failed: $error',
    );
  }

  final functionalProbeFailure =
      await (functionalProbe ?? _bubblewrapFunctionalProbe)();
  if (functionalProbeFailure != null) {
    return _GeneratedCodeSandboxValidation.unavailable(functionalProbeFailure);
  }

  return const _GeneratedCodeSandboxValidation.enforced(
    BubblewrapGeneratedCodeSandbox(),
  );
}

Future<String?> _bubblewrapFunctionalProbe() async {
  try {
    final result = await Process.run('bwrap', const [
      '--ro-bind',
      '/',
      '/',
      '--unshare-pid',
      '--unshare-ipc',
      '/bin/true',
    ], runInShell: false);
    if (result.exitCode == 0) return null;
    return 'bwrap functional probe failed with exit code ${result.exitCode}: '
        '${_compactProbeOutput(result)}';
  } on Object catch (error) {
    return 'bwrap functional probe could not start: $error';
  }
}

String _compactProbeOutput(ProcessResult result) {
  final output = [result.stderr, result.stdout]
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (output.isEmpty) return 'no output';
  return output.length <= 400 ? output : '${output.substring(0, 400)}...';
}

_SandboxClaimVerification _verifyOfficialSandboxClaims({
  required String taskId,
  required Map<String, Object?> admission,
  required TaskQaRuntimeIsolationReport validatingRuntimeIsolation,
  required _GeneratedCodeSandboxValidation sandboxValidation,
}) {
  final runtimeIsolation = _requiredMap(
    admission,
    'runtimeIsolation',
    'admission',
  );
  final generatedCodeSandbox = _requiredMap(
    runtimeIsolation,
    'generatedCodeSandbox',
    'admission.runtimeIsolation',
  );
  final checks = _requiredMap(admission, 'checks', 'admission');

  final checkedInRequired = _requiredBool(
    generatedCodeSandbox,
    'required',
    'admission.runtimeIsolation.generatedCodeSandbox',
  );
  final checkedInEnforced = _requiredBool(
    generatedCodeSandbox,
    'enforced',
    'admission.runtimeIsolation.generatedCodeSandbox',
  );
  final checkedInBackend = _requiredString(
    generatedCodeSandbox,
    'backend',
    'admission.runtimeIsolation.generatedCodeSandbox',
  );
  final checksRequired = _requiredBool(
    checks,
    'generatedCodeSandboxRequired',
    'admission.checks',
  );
  final checksEnforced = _requiredBool(
    checks,
    'generatedCodeSandboxEnforced',
    'admission.checks',
  );

  expect(
    checksRequired,
    checkedInRequired,
    reason:
        '$taskId checks.generatedCodeSandboxRequired must mirror '
        'runtimeIsolation.generatedCodeSandbox.required.',
  );
  expect(
    checksEnforced,
    checkedInEnforced,
    reason:
        '$taskId checks.generatedCodeSandboxEnforced must mirror '
        'runtimeIsolation.generatedCodeSandbox.enforced.',
  );
  expect(
    checkedInRequired,
    isTrue,
    reason:
        '$taskId official admission must require generated-code sandboxing.',
  );
  expect(
    checkedInEnforced,
    isTrue,
    reason: '$taskId checked-in admission must come from a sandboxed run.',
  );
  expect(
    checkedInBackend,
    bubblewrapGeneratedCodeSandboxBackend,
    reason: '$taskId official admission must name the Bubblewrap backend.',
  );

  if (!sandboxValidation.enforcementAvailable) {
    expect(
      validatingRuntimeIsolation.generatedCodeSandboxRequired,
      isFalse,
      reason: '$taskId validating run must not claim an unavailable sandbox.',
    );
    expect(
      validatingRuntimeIsolation.generatedCodeSandboxEnforced,
      isFalse,
      reason: '$taskId validating run must not claim an unavailable sandbox.',
    );
    return _SandboxClaimVerification.skipped(
      'Generated-code sandbox enforcement was not asserted for $taskId: '
      '${sandboxValidation.unavailableReason}. Checked-in sandbox fields were '
      'validated, but sandbox enforcement preflight did not pass.',
    );
  }

  expect(
    validatingRuntimeIsolation.generatedCodeSandboxRequired,
    checkedInRequired,
    reason:
        '$taskId checked-in sandbox requirement must match the validating '
        'run.',
  );
  expect(
    validatingRuntimeIsolation.generatedCodeSandboxEnforced,
    checkedInEnforced,
    reason:
        '$taskId checked-in sandbox enforcement must match the validating '
        'run.',
  );
  expect(
    validatingRuntimeIsolation.generatedCodeSandboxBackend,
    checkedInBackend,
    reason: '$taskId checked-in sandbox backend must match the validating run.',
  );
  return const _SandboxClaimVerification.asserted();
}

Map<String, Object?> _requiredMap(
  Map<String, Object?> parent,
  String key,
  String path,
) {
  final value = parent[key];
  expect(value, isA<Map<String, Object?>>(), reason: '$path.$key');
  return value! as Map<String, Object?>;
}

bool _requiredBool(Map<String, Object?> parent, String key, String path) {
  final value = parent[key];
  expect(value, isA<bool>(), reason: '$path.$key');
  return value! as bool;
}

String _requiredString(Map<String, Object?> parent, String key, String path) {
  final value = parent[key];
  expect(value, isA<String>(), reason: '$path.$key');
  final text = value! as String;
  expect(text.trim(), isNotEmpty, reason: '$path.$key');
  return text;
}

Map<String, Object?> _admissionWithSandboxClaim({
  required bool requiredClaim,
  required bool enforcedClaim,
  required String backend,
  bool? checksRequired,
  bool? checksEnforced,
}) {
  return {
    'runtimeIsolation': {
      'generatedCodeSandbox': {
        'required': requiredClaim,
        'enforced': enforcedClaim,
        'backend': backend,
      },
    },
    'checks': {
      'generatedCodeSandboxRequired': checksRequired ?? requiredClaim,
      'generatedCodeSandboxEnforced': checksEnforced ?? enforcedClaim,
    },
  };
}

class _GeneratedCodeSandboxValidation {
  const _GeneratedCodeSandboxValidation.enforced(this.generatedCodeSandbox)
    : unavailableReason = null;

  const _GeneratedCodeSandboxValidation.unavailable(this.unavailableReason)
    : generatedCodeSandbox = null;

  final GeneratedCodeSandbox? generatedCodeSandbox;
  final String? unavailableReason;

  bool get enforcementAvailable => generatedCodeSandbox != null;
}

class _SandboxClaimVerification {
  const _SandboxClaimVerification.asserted()
    : enforcementAsserted = true,
      skipReason = null;

  const _SandboxClaimVerification.skipped(this.skipReason)
    : enforcementAsserted = false;

  final bool enforcementAsserted;
  final String? skipReason;
}
