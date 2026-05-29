import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/runner/task_qa_runner.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/tasks/flutter_corpus/phase3_seed_tasks.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'registered phase 3 corpus tasks pass task QA',
    () async {
      final registry = buildDefaultTaskRegistry();
      final tasks = [for (final id in Phase3SeedTaskIds.all) registry.byId(id)!]
        ..sort((a, b) {
          final category = a.category.name.compareTo(b.category.name);
          if (category != 0) return category;
          final difficulty = a.difficulty.name.compareTo(b.difficulty.name);
          if (difficulty != 0) return difficulty;
          return a.id.compareTo(b.id);
        });
      final reportRoot = Directory('build/corpus_qa');
      await reportRoot.create(recursive: true);
      final workdirRoot = Directory('${reportRoot.path}/workdirs');
      if (await workdirRoot.exists()) {
        await workdirRoot.delete(recursive: true);
      }
      final runner = TaskQaRunner(
        workdirManager: WorkdirManager(root: workdirRoot),
      );
      final reports = <TaskQaReport>[];

      for (final task in tasks) {
        reports.add(await runner.run(task));
      }

      final payload = {
        'generated_at': DateTime.now().toIso8601String(),
        'task_count': reports.length,
        'tasks': [
          for (final report in reports)
            _reportJson(registry.byId(report.taskId)!, report),
        ],
      };
      await File(
        '${reportRoot.path}/corpus_task_qa_report.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

      for (final report in reports) {
        expect(report.baselineHiddenFailed, isTrue, reason: report.taskId);
        expect(report.referencePublicPassed, isTrue, reason: report.taskId);
        expect(report.referenceHiddenPassed, isTrue, reason: report.taskId);
        expect(report.failureMessages, isEmpty, reason: report.taskId);
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

Map<String, Object?> _reportJson(BenchmarkTask task, TaskQaReport report) {
  return {
    'task_id': report.taskId,
    'version': report.taskVersion,
    'category': task.category.name,
    'difficulty': task.difficulty.name,
    'track': task.track.name,
    'tags': task.tags.map((tag) => tag.slug).toList(),
    'timeout_seconds': task.timeout?.inSeconds,
    'platform_requirements': task.platformRequirements
        .map((platform) => platform.name)
        .toList(),
    'baseline_hidden_failed': report.baselineHiddenFailed,
    'reference_public_passed': report.referencePublicPassed,
    'reference_hidden_passed': report.referenceHiddenPassed,
    'hidden_flake_runs': report.hiddenFlakeRuns,
    'failure_messages': report.failureMessages,
  };
}
