import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
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
      expect(report.negativeCaseReports.single.id, 'noop');
      expect(report.negativeCaseReports.single.publicPassed, isTrue);
      expect(report.negativeCaseReports.single.hiddenPassed, isFalse);
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
      negativeCaseReports: [],
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
      preparePassed: false,
      publicPassed: false,
      hiddenPassed: false,
      publicResults: [],
      hiddenResults: [],
      error: 'failed to apply',
    );

    expect(report.rejected, isFalse);
  });
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
      solution: ReferenceFileSolution({}),
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
