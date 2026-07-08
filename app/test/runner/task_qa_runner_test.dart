import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/task_qa_runner.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/tasks/bug_fix/async_race_condition.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:dart_arena/tasks/ui_from_spec/profile_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy task keeps default integrity metadata and evaluator list', () {
    final task = OffByOnePaginationTask();
    expect(task.version, 1);
    expect(task.track, BenchmarkTrack.codegen);
    expect(task.hiddenVerifiers, isEmpty);
    expect(task.referenceSolution, isNull);
    expect(task.evaluatorsFor(const EvaluatorConfig()).map((e) => e.id), [
      'compile',
      'analyze',
      'test',
      'diff_size',
    ]);
  });

  test(
    'converted tasks expose hidden verifier after public test evaluator',
    () async {
      for (final task in [ProfileCardTask(), AsyncRaceConditionTask()]) {
        await task.ensureLoaded();

        expect(task.version, 2);
        expect(task.track, BenchmarkTrack.codegen);
        expect(task.hiddenVerifiers, hasLength(1));
        expect(task.referenceSolution, isNotNull);
        expect(
          task.fixtures.keys,
          isNot(contains(task.hiddenVerifiers.single.testPath)),
        );

        final evaluators = task.evaluatorsFor(const EvaluatorConfig());
        final ids = evaluators.map((e) => e.id).toList();
        expect(ids, contains('hidden_test'));
        expect(ids.indexOf('hidden_test'), ids.indexOf('test') + 1);
        expect(evaluators.whereType<HiddenTestEvaluator>(), hasLength(1));
      }
    },
  );

  test(
    'converted task hidden files are absent from initial workdir',
    () async {
      final root = await Directory.systemTemp.createTemp('task_qa_absent_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final task = ProfileCardTask();
      await task.ensureLoaded();

      final dir = await WorkdirManager(root: root).createTaskWorkdir(
        runId: 'r',
        providerId: 'p',
        modelId: 'm',
        taskId: task.id,
        fixtures: task.fixtures,
        generatedCode: null,
        generatedCodePath: task.generatedCodePath,
      );

      expect(
        File(
          p.join(dir.path, task.hiddenVerifiers.single.testPath),
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          p.join(dir.path, 'reference', 'lib', 'profile_card.dart'),
        ).existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'converted tasks fail baseline and pass reference hidden QA',
    () async {
      for (final task in [ProfileCardTask(), AsyncRaceConditionTask()]) {
        final root = await Directory.systemTemp.createTemp(
          'task_qa_${task.id}_',
        );
        addTearDown(() async {
          if (await root.exists()) await root.delete(recursive: true);
        });
        final report = await TaskQaRunner(
          workdirManager: WorkdirManager(root: root),
        ).run(task);

        final failures = report.failureMessages.join('\n');
        expect(report.taskId, task.id);
        expect(report.taskVersion, 2);
        expect(report.baselineHiddenFailed, isTrue, reason: failures);
        expect(report.referencePublicPassed, isTrue, reason: failures);
        expect(report.referenceHiddenPassed, isTrue, reason: failures);
        expect(report.referencePassed, isTrue, reason: failures);
        expect(report.hiddenFlakeRuns, 3, reason: failures);
        expect(report.failureMessages, isEmpty);
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test(
    'negative cases must be rejected by public or hidden verifiers',
    () async {
      final root = await Directory.systemTemp.createTemp('task_qa_negative_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final report = await TaskQaRunner(
        workdirManager: WorkdirManager(root: root),
        requiredHiddenFlakeRuns: 1,
        requireNegativeCases: true,
      ).run(_NegativeQaTask());

      final failures = report.failureMessages.join('\n');
      expect(report.baselineHiddenFailed, isTrue, reason: failures);
      expect(report.referencePassed, isTrue, reason: failures);
      expect(report.negativeCasesRejected, isTrue, reason: failures);
      expect(report.requiredNegativeCaseKindsCovered, isTrue, reason: failures);
      expect(report.promptSafety.passed, isTrue, reason: failures);
      final noop = report.negativeCaseReports.singleWhere(
        (negative) => negative.kind == TaskNegativeCaseKind.noop,
      );
      expect(noop.id, 'noop');
      expect(noop.publicPassed, isTrue);
      expect(noop.hiddenPassed, isFalse);
      final apiBreaking = report.negativeCaseReports.singleWhere(
        (negative) => negative.kind == TaskNegativeCaseKind.apiBreaking,
      );
      expect(apiBreaking.rejected, isTrue);
      final audit = report.verifierQualityAudit;
      expect(audit.falsePositiveCount, 0);
      expect(audit.falseNegativeCount, 0);
      expect(audit.disagreementCount, 1);
      expect(audit.infrastructureErrorCount, 0);
      expect(audit.flakeRunCount, 1);
      expect(audit.flakeFailureCount, 0);
      expect(audit.negativeCaseCount, 2);
      expect(audit.acceptedNegativeCaseCount, 0);
      final admission = taskQaAdmissionReportJson(
        task: _NegativeQaTask(),
        report: report,
      );
      expect(admission['release'], {
        'corpus': 'public_diagnostic',
        'status': 'active',
      });
      expect(admission['verifierQualityAudit'], {
        'falsePositiveCount': 0,
        'falseNegativeCount': 0,
        'disagreementCount': 1,
        'infrastructureErrorCount': 0,
        'flakeRunCount': 1,
        'flakeFailureCount': 0,
        'flakeRate': 0.0,
        'negativeCaseCount': 2,
        'acceptedNegativeCaseCount': 0,
        'referencePublicFailureCount': 0,
        'referenceHiddenFailureCount': 0,
      });
      expect(report.failureMessages, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'required generated-code sandbox fails before creating workdirs',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'task_qa_required_sandbox_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      await expectLater(
        TaskQaRunner(
          workdirManager: WorkdirManager(root: root),
          generatedCodeSandboxRequired: true,
        ).run(_NegativeQaTask()),
        throwsStateError,
      );
      expect(Directory(p.join(root.path, 'runs')).existsSync(), isFalse);
    },
  );

  test(
    'required generated-code sandbox is recorded in runtime evidence',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'task_qa_recording_sandbox_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final sandbox = _RecordingGeneratedCodeSandbox();

      final task = _NegativeQaTask();
      final report = await TaskQaRunner(
        workdirManager: WorkdirManager(root: root),
        requiredHiddenFlakeRuns: 1,
        requireNegativeCases: true,
        generatedCodeSandboxRequired: true,
        generatedCodeSandbox: sandbox,
      ).run(task);
      final runtimeJson = report.runtimeIsolation.toJson();
      final workspaceEvidence =
          runtimeJson['workspaceEvidence']! as Map<String, Object?>;
      final admission = taskQaAdmissionReportJson(task: task, report: report);
      final runtimeText = jsonEncode(admission['runtimeIsolation']);

      expect(sandbox.calls, isNotEmpty);
      expect(runtimeJson['generatedCodeSandbox'], {
        'required': true,
        'enforced': true,
        'backend': 'test-sandbox',
      });
      expect(workspaceEvidence['workspaceCount'], 4);
      expect(report.runtimeIsolation.workspaceCount, 4);
      expect(report.runtimeIsolation.restrictedPathCount, 0);
      expect(runtimeText, isNot(contains(root.path)));
      expect(runtimeText, isNot(contains(Directory.systemTemp.path)));
      expect(report.failureMessages, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('empty negative case reports are not considered rejected', () {
    const report = TaskQaReport(
      taskId: 'task',
      taskVersion: 1,
      baselineHiddenFailed: true,
      referencePublicPassed: true,
      referenceHiddenPassed: true,
      hiddenFlakeRuns: 1,
      hiddenVerifierDigests: {},
      negativeCaseReports: [],
      promptSafety: TaskQaPromptSafetyReport(
        targetContextPresent: true,
        publicTestContextPresent: true,
        publicTestContextRequired: true,
        implementationBodiesOmitted: true,
        hiddenVerifierLeakFree: true,
        referenceLeakFree: true,
        requiredNegativeCaseKinds: {
          TaskNegativeCaseKind.noop,
          TaskNegativeCaseKind.apiBreaking,
        },
        presentNegativeCaseKinds: {},
        missingNegativeCaseKinds: {
          TaskNegativeCaseKind.noop,
          TaskNegativeCaseKind.apiBreaking,
        },
      ),
      failureMessages: [],
      baselineHiddenResults: [],
      referencePublicResults: [],
      referenceHiddenResults: [],
    );

    expect(report.negativeCasesRejected, isFalse);
  });

  test('invalid negative case reports are not considered rejected', () {
    const report = TaskQaNegativeCaseReport(
      id: 'bad_negative',
      description: 'Invalid negative case.',
      kind: TaskNegativeCaseKind.noop,
      preparePassed: false,
      publicPassed: false,
      hiddenPassed: false,
      publicResults: [],
      hiddenResults: [],
      error: 'failed to apply',
    );

    expect(report.rejected, isFalse);
  });

  test('verifier quality audit counts rationale infrastructure errors', () {
    const report = TaskQaReport(
      taskId: 'task',
      taskVersion: 1,
      baselineHiddenFailed: true,
      referencePublicPassed: true,
      referenceHiddenPassed: true,
      hiddenFlakeRuns: 1,
      hiddenVerifierDigests: {},
      negativeCaseReports: [],
      promptSafety: TaskQaPromptSafetyReport(
        targetContextPresent: true,
        publicTestContextPresent: false,
        publicTestContextRequired: false,
        implementationBodiesOmitted: true,
        hiddenVerifierLeakFree: true,
        referenceLeakFree: true,
        requiredNegativeCaseKinds: {},
        presentNegativeCaseKinds: {},
        missingNegativeCaseKinds: {},
      ),
      failureMessages: [],
      baselineHiddenResults: [
        EvaluationResult(
          evaluatorId: 'test',
          passed: false,
          score: 0,
          rationale: 'prepare failed before verifier execution',
        ),
      ],
      referencePublicResults: [],
      referenceHiddenResults: [],
    );

    expect(report.verifierQualityAudit.infrastructureErrorCount, 1);
  });

  test(
    'required negative case kinds are flagged when missing',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'task_qa_missing_negative_kind_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final report = await TaskQaRunner(
        workdirManager: WorkdirManager(root: root),
        requiredHiddenFlakeRuns: 1,
        requireNegativeCases: true,
      ).run(_MissingApiBreakingNegativeQaTask());

      expect(report.requiredNegativeCaseKindsCovered, isFalse);
      expect(
        report.failureMessages,
        contains('Task has no api_breaking verifier negative case.'),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RecordingGeneratedCodeSandbox extends GeneratedCodeSandbox {
  final calls = <_SandboxCall>[];

  @override
  String get backend => 'test-sandbox';

  @override
  Future<SandboxedProcessStart> wrapProcess({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required Map<String, String> environment,
    required bool allowInternet,
    SandboxResourceLimits? resourceLimits,
    Iterable<String> extraReadOnlyPaths = const [],
  }) async {
    calls.add(
      _SandboxCall(
        executable: executable,
        arguments: List.unmodifiable(arguments),
        workingDirectory: workingDirectory,
        allowInternet: allowInternet,
        resourceLimits: resourceLimits,
        extraReadOnlyPaths: List.unmodifiable(extraReadOnlyPaths),
      ),
    );
    return SandboxedProcessStart(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }
}

class _SandboxCall {
  const _SandboxCall({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.allowInternet,
    required this.resourceLimits,
    required this.extraReadOnlyPaths,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final bool allowInternet;
  final SandboxResourceLimits? resourceLimits;
  final List<String> extraReadOnlyPaths;
}

class _NegativeQaTask extends BenchmarkTask {
  @override
  String get id => 'qa.negative';

  @override
  int get version => 1;

  @override
  Category get category => Category.bugFix;

  @override
  String get prompt => 'Make answer return 42.';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': '''
name: qa_negative
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''',
    'lib/answer.dart': 'int answer() => 41;\n',
    'test/answer_test.dart': '''
import 'package:qa_negative/answer.dart';
import 'package:test/test.dart';

void main() {
  test('answer returns an int', () => expect(answer(), isA<int>()));
}
''',
  };

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  ReferenceSolution? get referenceSolution {
    return const ReferenceFileSolution({
      'lib/answer.dart': 'int answer() => 42;\n',
    });
  }

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
      description: 'Breaks the public answer API.',
      kind: TaskNegativeCaseKind.apiBreaking,
      solution: ReferenceFileSolution({
        'lib/answer.dart': 'void answer() {}\n',
      }),
    ),
  ];

  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      files: {
        'test/_hidden/answer_hidden_test.dart': '''
import 'package:qa_negative/answer.dart';
import 'package:test/test.dart';

void main() {
  test('answer is fixed', () => expect(answer(), 42));
}
''',
      },
      testPath: 'test/_hidden/answer_hidden_test.dart',
    ),
  ];

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) {
    return [TestEvaluator(), ...hiddenVerifiers.map(HiddenTestEvaluator.new)];
  }
}

class _MissingApiBreakingNegativeQaTask extends _NegativeQaTask {
  @override
  String get id => 'qa.missing_api_breaking_negative';

  @override
  List<TaskNegativeCase> get negativeCases => const [
    TaskNegativeCase(
      id: 'noop',
      description: 'Leaves the baseline answer unchanged.',
      kind: TaskNegativeCaseKind.noop,
      solution: ReferenceFileSolution({}),
    ),
  ];
}
