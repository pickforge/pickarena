import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../support/official_tasks.dart';

void main() {
  test('official corpus QA reports match filesystem-loaded tasks', () async {
    final tasks = await loadOfficialFlutterTasks();
    final reportRoot = Directory('build/corpus_qa');
    await reportRoot.create(recursive: true);

    expect(tasks.map((task) => task.id), officialFlutterTaskIds);

    final taskReports = <Map<String, Object?>>[];
    for (final task in tasks) {
      await task.ensureLoaded();
      final admission = await _readAdmissionReport(task);

      expect(admission['taskId'], task.id);
      expect(admission['taskVersion'], task.version);
      expect(admission['track'], task.track.name);
      expect(admission['status'], 'admitted');
      expect(admission['release'], task.releaseMetadata.toJson());
      final checks = admission['checks'] as Map<String, Object?>;
      expect(checks['baselineHiddenFailed'], isTrue, reason: task.id);
      expect(checks['referencePublicPassed'], isTrue, reason: task.id);
      expect(checks['referenceHiddenPassed'], isTrue, reason: task.id);
      expect(checks['promptSafeContextLeakFree'], isTrue, reason: task.id);
      final promptSafety = admission['promptSafety'] as Map<String, Object?>;
      expect(promptSafety['passed'], isTrue, reason: task.id);
      expect(task.hiddenVerifiers, isNotEmpty, reason: task.id);
      expect(task.referenceSolution, isNotNull, reason: task.id);
      expect(task.negativeCases, isNotEmpty, reason: task.id);
      expect(
        task.fixtures.keys,
        isNot(contains(task.hiddenVerifiers.single.testPath)),
        reason: task.id,
      );

      taskReports.add(_reportJson(task, admission));
    }

    final payload = {
      'generated_at': DateTime.now().toIso8601String(),
      'task_count': taskReports.length,
      'tasks': taskReports,
    };
    await File(
      p.join(reportRoot.path, 'corpus_task_qa_report.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  });
}

Future<Map<String, Object?>> _readAdmissionReport(BenchmarkTask task) async {
  final file = File(
    p.join(
      officialFlutterTaskRoot().path,
      task.id,
      'qa',
      'admission_report.json',
    ),
  );
  return jsonDecode(await file.readAsString()) as Map<String, Object?>;
}

Map<String, Object?> _reportJson(
  BenchmarkTask task,
  Map<String, Object?> admission,
) {
  return {
    'task_id': task.id,
    'version': task.version,
    'category': task.category.name,
    'difficulty': task.difficulty.name,
    'track': task.track.name,
    'tags': task.tags.map((tag) => tag.slug).toList(),
    'timeout_seconds': task.timeout?.inSeconds,
    'platform_requirements': task.platformRequirements
        .map((platform) => platform.name)
        .toList(),
    'execution_policy': {
      'allow_internet': task.allowInternet,
      'resources': task.resourceLimits.toJson(),
    },
    'checks': admission['checks'],
    'prompt_safety': admission['promptSafety'],
    'negative_cases': admission['negativeCases'],
    'failure_messages': admission['failureMessages'],
  };
}
