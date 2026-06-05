import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/runner/resource_enforcement_policy.dart';
import 'package:dart_arena/runner/task_qa_runner.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official Flutter bundles load as agentic file-backed tasks', () async {
    final tasks = await _loadOfficialTasks();
    final ids = tasks.map((task) => task.id).toList();

    expect(ids, [
      'forms.email_validation',
      'lists.contact_search',
      'navigation.auth_redirect_race',
      'platform.channel_mock',
      'state.selection_controller',
    ]);

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
        {
          TaskNegativeCaseKind.noop,
          TaskNegativeCaseKind.apiBreaking,
          TaskNegativeCaseKind.overfit,
        },
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

  test(
    'official Flutter bundles satisfy their admission reports',
    () async {
      final tasks = await _loadOfficialTasks();

      for (final task in tasks) {
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
        ).run(task);
        final failures = report.failureMessages.join('\n');

        expect(report.baselineHiddenFailed, isTrue, reason: failures);
        expect(report.referencePublicPassed, isTrue, reason: failures);
        expect(report.referenceHiddenPassed, isTrue, reason: failures);
        expect(report.negativeCasesRejected, isTrue, reason: failures);
        expect(
          report.requiredNegativeCaseKindsCovered,
          isTrue,
          reason: failures,
        );
        expect(report.promptSafety.passed, isTrue, reason: failures);
        expect(report.failureMessages, isEmpty, reason: task.id);

        final admission = await _readAdmissionReport(task);
        final checks = admission['checks'] as Map<String, Object?>;
        expect(admission['taskId'], task.id);
        expect(admission['taskVersion'], task.version);
        expect(admission['track'], task.track.name);
        expect(admission['status'], 'admitted');
        expect(
          DateTime.tryParse(admission['generatedAt']! as String),
          isNotNull,
        );
        expect(admission['release'], task.releaseMetadata.toJson());
        final admissionProvenance =
            admission['admission'] as Map<String, Object?>;
        expect(admissionProvenance['tool'], {'name': 'dart_arena_task_qa'});
        expect(admissionProvenance['evaluator'], {
          'schemaVersion': 1,
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
        expect(admission['executionPolicy'], {
          'allowInternet': false,
          'resources': task.resourceLimits.toJson(),
          'resourceEnforcement': taskResourceEnforcementJson(),
        });
        expect(checks['baselineHiddenFailed'], report.baselineHiddenFailed);
        expect(checks['referencePublicPassed'], report.referencePublicPassed);
        expect(checks['referenceHiddenPassed'], report.referenceHiddenPassed);
        expect(
          checks['noopRejected'],
          report.negativeCaseReports
              .singleWhere(
                (negativeCase) =>
                    negativeCase.kind == TaskNegativeCaseKind.noop,
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
                (negativeCase) =>
                    negativeCase.kind == TaskNegativeCaseKind.overfit,
              )
              .rejected,
        );
        expect(checks['hiddenFlakeRuns'], report.hiddenFlakeRuns);
        expect(checks['promptSafeContextLeakFree'], report.promptSafety.passed);
        final hiddenDigests =
            admission['hiddenVerifierDigests'] as Map<String, Object?>;
        expect(hiddenDigests.keys, [task.hiddenVerifiers.single.id]);
        expect(hiddenDigests.values.single, matches(RegExp(r'^[0-9a-f]{64}$')));
        final quality =
            admission['verifierQualityAudit'] as Map<String, Object?>;
        expect(quality['falsePositiveCount'], 0);
        expect(quality['falseNegativeCount'], 0);
        expect(quality['flakeRunCount'], 3);
        expect(quality['flakeFailureCount'], 0);
        expect(quality['negativeCaseCount'], 3);
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
          {'api_breaking', 'noop', 'overfit'},
        );
        expect(
          negativeCases.every((entry) {
            return (entry as Map<String, Object?>)['rejected'] == true;
          }),
          isTrue,
        );
        expect(admission['failureMessages'], isEmpty);
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<List<FileBackedTask>> _loadOfficialTasks() {
  return loadFileBackedTasks(
    Directory(p.join(Directory.current.path, '..', 'tasks', 'flutter')),
  );
}

Future<Map<String, Object?>> _readAdmissionReport(FileBackedTask task) async {
  final file = File(
    p.join(task.bundleDirectory.path, 'qa', 'admission_report.json'),
  );
  return jsonDecode(await file.readAsString()) as Map<String, Object?>;
}
