import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/path_safety.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/runner/resource_enforcement_policy.dart';
import 'package:dart_arena/runner/run_provenance.dart';
import 'package:dart_arena/runner/task_qa_cli_runner.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('task QA CLI help emits one JSON object', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final exitCode = await runTaskQaCli(
      ['--help'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(stdoutLines, hasLength(1));
    final decoded = jsonDecode(stdoutLines.single) as Map<String, Object?>;
    expect(decoded['status'], 'help');
    expect(
      decoded['usage'],
      'dart run --verbosity=error dart_arena:dart_arena_task_qa --out build/task_qa',
    );
  });

  test(
    'dart run task QA help works without UI startup',
    () async {
      final result = await Process.run('dart', [
        'run',
        '--verbosity=error',
        'dart_arena:dart_arena_task_qa',
        '--help',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stderr.toString(), isEmpty);
      final decoded =
          jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      expect(decoded['status'], 'help');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'writes per-task admission report and aggregate summary',
    () async {
      final tmp = await Directory.systemTemp.createTemp('task_qa_cli_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final outputDir = Directory(p.join(tmp.path, 'reports'));
      final stdoutLines = <String>[];
      final stderrLines = <String>[];

      final exitCode = await runTaskQaCli(
        [
          '--out',
          outputDir.path,
          '--task',
          _CliQaTask.taskId,
          '--hidden-flake-runs',
          '1',
          '--evaluator-timeout-seconds',
          '30',
        ],
        dependencies: TaskQaCliDependencies(
          taskRegistryBuilder: () => TaskRegistry()..register(_CliQaTask()),
          environmentProviderBuilder: () =>
              const _FixedTaskQaEnvironmentProvider(),
          now: () => DateTime.utc(2026, 6, 3, 12),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(stdoutLines, hasLength(1));
      final cliResult = jsonDecode(stdoutLines.single) as Map<String, Object?>;
      expect(cliResult['status'], 'completed');
      expect(cliResult['taskCount'], 1);

      final summaryPath = cliResult['admissionSummaryPath']! as String;
      final summary =
          jsonDecode(await File(summaryPath).readAsString())
              as Map<String, Object?>;
      expect(summary['status'], 'completed');
      expect(summary['taskCount'], 1);
      expect(summary['generatedCodeSandbox'], {
        'required': false,
        'enforced': false,
        'backend': 'bubblewrap',
      });
      final reports = summary['reports']! as List<Object?>;
      final reportEntry = reports.single! as Map<String, Object?>;
      final taskRuntimeIsolation =
          reportEntry['runtimeIsolation']! as Map<String, Object?>;
      expect(taskRuntimeIsolation['generatedCodeSandboxEnforced'], isFalse);
      expect(taskRuntimeIsolation['workspaceEvidenceCount'], 5);
      expect(
        taskRuntimeIsolation['workspaceManifestSha256'],
        isA<String>().having((value) => value.length, 'length', 64),
      );
      expect(taskRuntimeIsolation['restrictedPathCount'], 0);
      final reportPath = reportEntry['reportPath']! as String;
      expect(p.isAbsolute(reportPath), isFalse);
      expect(
        reportPath,
        'tasks/${safePathSegment(_CliQaTask.taskId, prefix: 'task')}/'
        'admission_report.json',
      );
      final report =
          jsonDecode(
                await File(p.join(outputDir.path, reportPath)).readAsString(),
              )
              as Map<String, Object?>;
      final checks = report['checks']! as Map<String, Object?>;
      final reportRuntimeIsolation =
          report['runtimeIsolation']! as Map<String, Object?>;
      final reportRuntimeText = jsonEncode(reportRuntimeIsolation);
      final reportWorkspaceEvidence =
          reportRuntimeIsolation['workspaceEvidence']! as Map<String, Object?>;

      expect(report['taskId'], _CliQaTask.taskId);
      expect(report['status'], 'admitted');
      expect(report['generatedAt'], '2026-06-03T12:00:00.000Z');
      expect(report['executionPolicy'], {
        'allowInternet': false,
        'resources': defaultTaskResourceLimits.toJson(),
        'resourceEnforcement': taskResourceEnforcementJson(),
      });
      expect(report['release'], {
        'corpus': 'public_diagnostic',
        'status': 'active',
      });
      expect(report['admission'], {
        'tool': {'name': 'dart_arena_task_qa'},
        'evaluator': {'schemaVersion': 2, 'version': '2026-05-31-master-spec'},
        'environment': {
          'dartVersion': 'test-dart',
          'dependencySnapshot': {
            'status': 'present',
            'files': {
              'pubspec.lock': {
                'sha256':
                    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                'bytes': 123,
              },
            },
          },
          'flutterVersion': 'test-flutter',
        },
      });
      expect(checks['baselineHiddenFailed'], isTrue);
      expect(checks['referencePublicPassed'], isTrue);
      expect(checks['referenceHiddenPassed'], isTrue);
      expect(checks['noopRejected'], isTrue);
      expect(checks['apiBreakingRejected'], isTrue);
      expect(checks['overfitRejected'], isTrue);
      expect(checks['promptSafeContextLeakFree'], isTrue);
      expect(checks['generatedCodeSandboxRequired'], isFalse);
      expect(checks['generatedCodeSandboxEnforced'], isFalse);
      expect(checks['workspaceEvidenceCollected'], isTrue);
      expect(checks['workspaceRestrictedPathsAbsent'], isTrue);
      expect(reportRuntimeIsolation['generatedCodeSandbox'], {
        'required': false,
        'enforced': false,
        'backend': 'bubblewrap',
      });
      expect(reportWorkspaceEvidence['workspaceCount'], 5);
      expect(reportWorkspaceEvidence['restrictedPathCount'], 0);
      expect(reportRuntimeText, isNot(contains(outputDir.path)));
      expect(reportRuntimeText, isNot(contains(tmp.path)));
      expect(report['verifierQualityAudit'], {
        'falsePositiveCount': 0,
        'falseNegativeCount': 0,
        'disagreementCount': 2,
        'infrastructureErrorCount': 0,
        'flakeRunCount': 1,
        'flakeFailureCount': 0,
        'flakeRate': 0.0,
        'negativeCaseCount': 3,
        'acceptedNegativeCaseCount': 0,
        'referencePublicFailureCount': 0,
        'referenceHiddenFailureCount': 0,
      });
      expect(report['failureMessages'], isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'required generated-code sandbox failure does not recreate workdir root',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'task_qa_cli_sandbox_required_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final outputDir = Directory(p.join(tmp.path, 'reports'));
      final workdirRoot = Directory(p.join(tmp.path, 'workdirs'));
      await workdirRoot.create(recursive: true);
      final marker = File(p.join(workdirRoot.path, 'marker.txt'));
      await marker.writeAsString('keep');
      final stdoutLines = <String>[];
      final stderrLines = <String>[];

      final exitCode = await runTaskQaCli(
        [
          '--out',
          outputDir.path,
          '--workdir-root',
          workdirRoot.path,
          '--task',
          _CliQaTask.taskId,
          '--require-generated-code-sandbox',
        ],
        dependencies: TaskQaCliDependencies(
          generatedCodeSandboxBuilder: (_) async => null,
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stdoutLines, isEmpty);
      expect(stderrLines, hasLength(1));
      final error = jsonDecode(stderrLines.single) as Map<String, Object?>;
      expect(error['status'], 'failed');
      expect(error['error'].toString(), contains('sandbox is required'));
      expect(marker.existsSync(), isTrue);
      expect(await marker.readAsString(), 'keep');
    },
  );
}

class _FixedTaskQaEnvironmentProvider
    implements RunProvenanceEnvironmentProvider {
  const _FixedTaskQaEnvironmentProvider();

  @override
  Future<Map<String, Object?>> capture() async {
    return const {
      'flutterVersion': 'test-flutter',
      'dartVersion': 'test-dart',
      'dependencySnapshot': {
        'status': 'present',
        'files': {
          'pubspec.lock': {
            'sha256':
                '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            'bytes': 123,
          },
        },
      },
    };
  }
}

class _CliQaTask extends BenchmarkTask {
  static const taskId = 'qa.cli_admission';

  @override
  String get id => taskId;

  @override
  int get version => 1;

  @override
  Category get category => Category.widgetTesting;

  @override
  Set<TaskTag> get tags => const {TaskTag.testing};

  @override
  TaskDifficulty get difficulty => TaskDifficulty.easy;

  @override
  Duration? get timeout => const Duration(minutes: 2);

  @override
  String get prompt => 'Make answer return the hidden expected value.';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': '''
name: task_qa_cli_fixture
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: any
''',
    'lib/answer.dart': 'int answer() => 0;\n',
    'test/answer_test.dart': '''
import 'package:test/test.dart';
import 'package:task_qa_cli_fixture/answer.dart';

void main() {
  test('answer is non-negative', () {
    expect(answer(), greaterThanOrEqualTo(0));
  });
}
''',
  };

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      id: 'answer_hidden',
      testPath: 'test/_hidden/answer_hidden_test.dart',
      files: {
        'test/_hidden/answer_hidden_test.dart': '''
import 'package:test/test.dart';
import 'package:task_qa_cli_fixture/answer.dart';

void main() {
  test('answer matches hidden expectation', () {
    expect(answer(), 1);
  });
}
''',
      },
    ),
  ];

  @override
  ReferenceSolution get referenceSolution =>
      const ReferenceFileSolution({'lib/answer.dart': 'int answer() => 1;\n'});

  @override
  List<TaskNegativeCase> get negativeCases => const [
    TaskNegativeCase(
      id: 'noop',
      description: 'Leaves the baseline answer unchanged.',
      kind: TaskNegativeCaseKind.noop,
      solution: ReferenceFileSolution({}),
    ),
    TaskNegativeCase(
      id: 'api_breaking',
      description: 'Breaks the answer API.',
      kind: TaskNegativeCaseKind.apiBreaking,
      solution: ReferenceFileSolution({
        'lib/answer.dart': 'void answer() {}\n',
      }),
    ),
    TaskNegativeCase(
      id: 'overfit_public_surface',
      description: 'Matches the public non-negative check only.',
      kind: TaskNegativeCaseKind.overfit,
      solution: ReferenceFileSolution({
        'lib/answer.dart': 'int answer() => 0;\n',
      }),
    ),
  ];

  @override
  Set<TaskNegativeCaseKind> get requiredNegativeCaseKinds => const {
    TaskNegativeCaseKind.noop,
    TaskNegativeCaseKind.apiBreaking,
    TaskNegativeCaseKind.overfit,
  };

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    TestEvaluator(),
    ...hiddenVerifiers.map(HiddenTestEvaluator.new),
    const _AlwaysPassingEvaluator(),
  ];
}

class _AlwaysPassingEvaluator implements Evaluator {
  const _AlwaysPassingEvaluator();

  @override
  String get id => 'qa_cli_static_check';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    return EvaluationResult(
      evaluatorId: id,
      passed: true,
      score: 1,
      rationale: 'static check passed',
    );
  }
}
