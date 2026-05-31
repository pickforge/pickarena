import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/export/artifact_bundle.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:path/path.dart' as p;

Run _run({String? provenanceJson}) => Run(
  id: 'r1',
  startedAt: DateTime.utc(2026, 5, 30, 12),
  completedAt: DateTime.utc(2026, 5, 30, 12, 30),
  judgeModel: null,
  name: 'bundle run',
  provenanceJson: provenanceJson,
);

TaskRun _taskRun({
  required String id,
  required String taskId,
  String responseText = 'response text',
  String? patchText,
  String? trajectoryLogPath,
  String benchmarkTrack = 'codegen',
  String? harnessId,
}) => TaskRun(
  id: id,
  runId: 'r1',
  providerId: 'provider',
  modelId: 'model',
  taskId: taskId,
  responseText: responseText,
  promptTokens: 10,
  completionTokens: 20,
  latencyMs: 1500,
  aggregateScore: 0.9,
  completedAt: DateTime.utc(2026, 5, 30, 12, 1),
  trialIndex: 0,
  taskVersion: 2,
  benchmarkTrack: benchmarkTrack,
  harnessId: harnessId,
  primaryPass: true,
  failureTag: 'pass',
  patchText: patchText,
  trajectoryLogPath: trajectoryLogPath,
);

RunSummary _summary({required Run run, required List<TaskRun> taskRuns}) {
  return RunSummary(
    run: run,
    taskRuns: taskRuns,
    evaluationsByTaskRunId: {
      for (final taskRun in taskRuns)
        taskRun.id: [
          Evaluation(
            id: '${taskRun.id}-compile',
            taskRunId: taskRun.id,
            evaluatorId: 'compile',
            passed: true,
            score: 1,
            rationale: 'ok',
            detailsJson: '{"workspace":"/tmp/should-not-export"}',
          ),
        ],
    },
  );
}

void main() {
  test(
    'exports deterministic bundle files, artifacts, manifest, and checksums',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_bundle_ok_',
      );
      final allowedRoot = Directory(p.join(tmp.path, 'allowed'))..createSync();
      final trajectory = File(p.join(allowedRoot.path, 'tr-a.log'))
        ..writeAsStringSync('trajectory text');
      final target = Directory(p.join(tmp.path, 'bundle'));

      final result = await exportRunBundle(
        summary: _summary(
          run: _run(provenanceJson: '{"schemaVersion":1,"runId":"r1"}'),
          taskRuns: [
            _taskRun(id: 'tr-b', taskId: 'task-b'),
            _taskRun(
              id: 'tr-a',
              taskId: 'task-a',
              benchmarkTrack: 'agentic',
              harnessId: 'droid',
              patchText: 'diff --git a/lib/a.dart b/lib/a.dart\n',
              trajectoryLogPath: trajectory.path,
            ),
          ],
        ),
        targetDirectory: target,
        allowedTrajectoryRoots: [allowedRoot],
        now: () => DateTime.utc(2026, 5, 30, 13),
        environmentProvider: () async => const {'hostPlatform': 'test-os'},
        appVersionProvider: () async => '1.0.0+test',
      );

      expect(result.warnings, isEmpty);
      expect(File(p.join(target.path, 'manifest.json')).existsSync(), isTrue);
      expect(
        File(p.join(target.path, 'run_results.v1.json')).existsSync(),
        isTrue,
      );
      expect(File(p.join(target.path, 'results.csv')).existsSync(), isTrue);
      expect(File(p.join(target.path, 'report.md')).existsSync(), isTrue);
      expect(File(p.join(target.path, 'checksums.json')).existsSync(), isTrue);
      expect(
        File(
          p.join(target.path, 'artifacts', 'responses', 'tr-a.txt'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(target.path, 'artifacts', 'patches', 'tr-a.patch'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(target.path, 'artifacts', 'trajectories', 'tr-a.log'),
        ).readAsStringSync(),
        'trajectory text',
      );

      final manifest =
          jsonDecode(
                File(p.join(target.path, 'manifest.json')).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(manifest['schemaVersion'], 1);
      expect(manifest['appVersion'], '1.0.0+test');
      expect(manifest['driftSchemaVersion'], 7);
      expect(manifest['provenance'], {'schemaVersion': 1, 'runId': 'r1'});
      final manifestTaskRuns = manifest['taskRuns'] as List;
      expect(
        (manifestTaskRuns.first as Map<String, Object?>)['taskRunId'],
        'tr-a',
      );
      expect(
        ((manifest['artifacts'] as List).first as Map<String, Object?>)['path'],
        startsWith('artifacts/'),
      );

      final csv = File(p.join(target.path, 'results.csv')).readAsStringSync();
      final markdown = File(
        p.join(target.path, 'report.md'),
      ).readAsStringSync();
      final runResults = File(
        p.join(target.path, 'run_results.v1.json'),
      ).readAsStringSync();
      expect(csv.indexOf('task-a'), lessThan(csv.indexOf('task-b')));
      expect(markdown.indexOf('task-a'), lessThan(markdown.indexOf('task-b')));
      expect(csv, contains('artifacts/trajectories/tr-a.log'));
      expect(markdown, contains('artifacts/trajectories/tr-a.log'));
      expect(runResults, contains('artifacts/trajectories/tr-a.log'));
      expect(csv, isNot(contains(trajectory.path)));
      expect(markdown, isNot(contains(trajectory.path)));
      expect(runResults, isNot(contains(trajectory.path)));
      expect(runResults, isNot(contains('/tmp/should-not-export')));

      final checksums =
          jsonDecode(
                File(p.join(target.path, 'checksums.json')).readAsStringSync(),
              )
              as Map<String, Object?>;
      final files = checksums['files'] as List;
      final paths = [
        for (final file in files)
          (file as Map<String, Object?>)['path'] as String,
      ];
      expect(paths, orderedEquals(paths.toList()..sort()));
      expect(paths, contains('manifest.json'));
      final manifestEntry = files.cast<Map<String, Object?>>().firstWhere(
        (file) => file['path'] == 'manifest.json',
      );
      final manifestDigest = sha256
          .convert(File(p.join(target.path, 'manifest.json')).readAsBytesSync())
          .toString();
      expect(manifestEntry['sha256'], manifestDigest);
      expect(manifestEntry['sha256'], isNot('$manifestDigest-corrupt'));

      tmp.deleteSync(recursive: true);
    },
  );

  test('warns for missing and malformed provenance without failing', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_bundle_prov_',
    );

    final legacyTarget = Directory(p.join(tmp.path, 'legacy'));
    await exportRunBundle(
      summary: _summary(
        run: _run(),
        taskRuns: [_taskRun(id: 'tr1', taskId: 'task')],
      ),
      targetDirectory: legacyTarget,
      allowedTrajectoryRoots: const [],
      environmentProvider: () async => const {},
      appVersionProvider: () async => 'test',
    );
    var manifest =
        jsonDecode(
              File(
                p.join(legacyTarget.path, 'manifest.json'),
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    var warningCodes = (manifest['warnings'] as List)
        .cast<Map<String, Object?>>()
        .map((warning) => warning['code']);
    expect(warningCodes, contains('missing_run_provenance'));
    expect(manifest.containsKey('provenance'), isFalse);

    final malformedTarget = Directory(p.join(tmp.path, 'malformed'));
    await exportRunBundle(
      summary: _summary(
        run: _run(provenanceJson: '{not json'),
        taskRuns: [_taskRun(id: 'tr1', taskId: 'task')],
      ),
      targetDirectory: malformedTarget,
      allowedTrajectoryRoots: const [],
      environmentProvider: () async => const {},
      appVersionProvider: () async => 'test',
    );
    manifest =
        jsonDecode(
              File(
                p.join(malformedTarget.path, 'manifest.json'),
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    warningCodes = (manifest['warnings'] as List)
        .cast<Map<String, Object?>>()
        .map((warning) => warning['code']);
    expect(warningCodes, contains('malformed_run_provenance'));
    expect(manifest.containsKey('provenance'), isFalse);

    tmp.deleteSync(recursive: true);
  });

  test('trajectory safety warnings do not stop bundle export', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_bundle_paths_',
    );
    final allowedRoot = Directory(p.join(tmp.path, 'allowed'))..createSync();
    final outsideRoot = Directory(p.join(tmp.path, 'outside'))..createSync();
    final outsideFile = File(p.join(outsideRoot.path, 'outside.log'))
      ..writeAsStringSync('outside');
    final symlinkTarget = File(p.join(allowedRoot.path, 'real.log'))
      ..writeAsStringSync('real');
    final symlink = Link(p.join(allowedRoot.path, 'link.log'))
      ..createSync(symlinkTarget.path);
    final directoryPath = Directory(p.join(allowedRoot.path, 'directory'))
      ..createSync();
    final referenceDir = Directory(p.join(allowedRoot.path, 'reference'))
      ..createSync();
    final referenceFile = File(p.join(referenceDir.path, 'secret.log'))
      ..writeAsStringSync('reference-secret');

    final target = Directory(p.join(tmp.path, 'bundle'));
    final result = await exportRunBundle(
      summary: _summary(
        run: _run(provenanceJson: '{"schemaVersion":1}'),
        taskRuns: [
          _taskRun(
            id: 'missing',
            taskId: 'missing',
            trajectoryLogPath: p.join(allowedRoot.path, 'missing.log'),
          ),
          _taskRun(
            id: 'symlink',
            taskId: 'symlink',
            trajectoryLogPath: symlink.path,
          ),
          _taskRun(
            id: 'outside',
            taskId: 'outside',
            trajectoryLogPath: outsideFile.path,
          ),
          _taskRun(
            id: 'directory',
            taskId: 'directory',
            trajectoryLogPath: directoryPath.path,
          ),
          _taskRun(
            id: 'reference',
            taskId: 'reference',
            trajectoryLogPath: referenceFile.path,
          ),
        ],
      ),
      targetDirectory: target,
      allowedTrajectoryRoots: [allowedRoot],
      environmentProvider: () async => const {},
      appVersionProvider: () async => 'test',
    );

    final warningCodes = result.warnings.map((warning) => warning.code).toSet();
    expect(warningCodes, contains('unreadable_trajectory'));
    expect(warningCodes, contains('trajectory_symlink'));
    expect(warningCodes, contains('trajectory_out_of_root'));
    expect(warningCodes, contains('excluded_artifact_path'));
    expect(
      result.artifacts.where((artifact) => artifact.kind == 'trajectory'),
      isEmpty,
    );
    expect(
      File(p.join(target.path, 'manifest.json')).readAsStringSync(),
      contains('excluded_artifact_path'),
    );

    tmp.deleteSync(recursive: true);
  });

  test('does not overwrite an existing bundle directory', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_bundle_exists_',
    );
    final target = Directory(p.join(tmp.path, 'bundle'))..createSync();

    await expectLater(
      exportRunBundle(
        summary: _summary(
          run: _run(provenanceJson: '{"schemaVersion":1}'),
          taskRuns: [_taskRun(id: 'tr1', taskId: 'task')],
        ),
        targetDirectory: target,
      ),
      throwsA(isA<FileSystemException>()),
    );

    tmp.deleteSync(recursive: true);
  });
}
