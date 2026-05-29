import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
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
}
