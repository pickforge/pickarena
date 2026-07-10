import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/task_bundle_digest.dart';
import 'package:dart_arena/export/release_report_cli_runner.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('release report CLI help emits JSON', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      ['--help'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    final decoded = jsonDecode(stdoutLines.single) as Map<String, Object?>;
    expect(decoded['status'], 'help');
    expect(decoded['usage'].toString(), contains('dart_arena_release_report'));
    expect(
      decoded['options'].toString(),
      contains('--min-hidden-flake-runs-per-task'),
    );
    expect(decoded['options'].toString(), contains('--task-qa-report'));
    expect(decoded['options'].toString(), contains('--task-qa-report-root'));
    expect(decoded['options'].toString(), contains('--artifact-bundle-root'));
  });

  test(
    'loads direct task QA admission reports without a summary file',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_direct_task_qa_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final reportPath = p.join(
        tmp.path,
        'tasks',
        'task.a',
        'qa',
        'admission_report.json',
      );
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-report',
          reportPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-direct-task-qa',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 12),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final taskQa = report['taskQa']! as Map<String, Object?>;
      expect(taskQa['status'], 'completed');
      expect(taskQa['taskCount'], 1);
      expect(taskQa['loadedReportCount'], 1);
      final summaryIntegrity =
          taskQa['summaryIntegrity']! as Map<String, Object?>;
      expect(summaryIntegrity['status'], 'valid');
      expect(summaryIntegrity['generatedAtStatus'], 'present');
      final reportPathAudit =
          taskQa['reportPathAudit']! as Map<String, Object?>;
      expect(reportPathAudit['unsafeReportPathCount'], 0);
      final summaryConsistency =
          taskQa['summaryReportConsistency']! as Map<String, Object?>;
      expect(summaryConsistency['matchedReportCount'], 1);
      expect(summaryConsistency['missingLoadedReportCount'], 0);

      final inputs = report['inputs']! as Map<String, Object?>;
      expect(inputs, isNot(contains('taskQaSummary')));
      final taskQaReports = inputs['taskQaReports']! as List<Object?>;
      _expectFingerprint(
        taskQaReports.single! as Map<String, Object?>,
        path: 'tasks/task.a/qa/admission_report.json',
      );
    },
  );

  test('discovers direct task QA admission reports under roots', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_direct_task_qa_root_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final reportRoot = p.join(tmp.path, 'corpus');
    final reportPath = p.join(
      reportRoot,
      'tasks',
      'task.a',
      'qa',
      'admission_report.json',
    );
    final ignoredWrongNamePath = p.join(
      reportRoot,
      'tasks',
      'task.b',
      'qa',
      'not_report.json',
    );
    final ignoredWrongDirPath = p.join(
      reportRoot,
      'tasks',
      'task.c',
      'evidence',
      'admission_report.json',
    );
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await Directory(p.dirname(ignoredWrongNamePath)).create(recursive: true);
    await Directory(p.dirname(ignoredWrongDirPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    await File(
      ignoredWrongNamePath,
    ).writeAsString(_prettyJson(_taskQaReportJson(taskId: 'task.b')));
    await File(
      ignoredWrongDirPath,
    ).writeAsString(_prettyJson(_taskQaReportJson(taskId: 'task.c')));
    final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
    final stdoutLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-report-root',
        reportRoot,
        '--out',
        outPath,
        '--release-id',
        '2026-06-direct-task-qa-root',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 12, 5),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: (_) {},
    );

    expect(exitCode, 0);
    expect(stdoutLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final taskQa = report['taskQa']! as Map<String, Object?>;
    expect(taskQa['status'], 'completed');
    expect(taskQa['taskCount'], 1);
    expect(taskQa['loadedReportCount'], 1);
    final summaryIntegrity =
        taskQa['summaryIntegrity']! as Map<String, Object?>;
    expect(summaryIntegrity['status'], 'valid');
    final summaryConsistency =
        taskQa['summaryReportConsistency']! as Map<String, Object?>;
    expect(summaryConsistency['matchedReportCount'], 1);
    expect(summaryConsistency['missingLoadedReportCount'], 0);

    final inputs = report['inputs']! as Map<String, Object?>;
    expect(inputs, isNot(contains('taskQaSummary')));
    final taskQaReports = inputs['taskQaReports']! as List<Object?>;
    _expectFingerprint(
      taskQaReports.single! as Map<String, Object?>,
      path: 'tasks/task.a/qa/admission_report.json',
    );
  });

  test(
    'writes blocked report without leaking absolute task QA paths',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_blocked_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(taskQaSummaryPath).writeAsString(
        _prettyJson(
          _taskQaSummaryJson(
            reportPath: p
                .relative(reportPath, from: taskQaDir.path)
                .replaceAll('\\', '/'),
          ),
        ),
      );
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-candidate',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 3, 15),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final text = await File(outPath).readAsString();
      expect(text, isNot(contains(tmp.path)));
      final report = jsonDecode(text) as Map<String, Object?>;
      expect(report['releaseId'], '2026-06-candidate');
      expect(report['status'], 'blocked');
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(blockers, contains('Run provenance database was not provided'));
      expect(blockers, contains('below the required 2'));
      final inputs = report['inputs']! as Map<String, Object?>;
      _expectFingerprint(
        inputs['leaderboard']! as Map<String, Object?>,
        path: 'leaderboard.v1.json',
      );
      _expectFingerprint(
        inputs['taskQaSummary']! as Map<String, Object?>,
        path: 'admission_summary.json',
      );
      final taskQaReports = inputs['taskQaReports']! as List<Object?>;
      _expectFingerprint(
        taskQaReports.single! as Map<String, Object?>,
        path: 'tasks/a/report.json',
      );
      expect(inputs, isNot(contains('database')));
    },
  );

  test('blocks report when task QA summary uses unsafe report paths', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_unsafe_task_qa_path_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final outsideReportPath = p.join(tmp.path, 'outside', 'report.json');
    await Directory(p.dirname(outsideReportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
    await File(taskQaSummaryPath).writeAsString(
      _prettyJson(_taskQaSummaryJson(reportPath: '../outside/report.json')),
    );
    await File(
      outsideReportPath,
    ).writeAsString(_prettyJson(_taskQaReportJson()));
    final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
    final stdoutLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-unsafe-task-qa-path',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 2),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: (_) {},
    );

    expect(exitCode, 0);
    expect(stdoutLines.single, contains('"status":"blocked"'));
    final text = await File(outPath).readAsString();
    expect(text, isNot(contains(tmp.path)));
    expect(text, isNot(contains('../outside/report.json')));
    final report = jsonDecode(text) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Task QA summary has 1 parent-traversing report path(s).'),
    );
    expect(
      blockers,
      contains('Task QA summary has 1 report path(s) outside tasks/.'),
    );
    final taskQa = report['taskQa']! as Map<String, Object?>;
    expect(taskQa['loadedReportCount'], 0);
    expect(taskQa['reportPathAudit'], {
      'reportPathCount': 1,
      'missingReportPathCount': 0,
      'absoluteReportPathCount': 0,
      'parentReportPathCount': 1,
      'malformedReportPathCount': 0,
      'outsideTaskQaRootReportPathCount': 1,
      'unsafeReportPathCount': 1,
      'unsafeReportPaths': [
        {'taskId': 'task.a', 'taskVersion': 1, 'reason': 'parent_traversal'},
      ],
    });
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
    expect(corpusGate['status'], 'blocked');
    expect(corpusGate['parentReportPathCount'], 1);
    expect(corpusGate['outsideTaskQaRootReportPathCount'], 1);
    expect(corpusGate['unsafeReportPathCount'], 1);
  });

  test(
    'blocks report when task QA summary uses absolute report paths',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_absolute_task_qa_path_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(taskQaSummaryPath).writeAsString(
        _prettyJson(
          _taskQaSummaryJson(reportPath: reportPath, preserveReportPath: true),
        ),
      );
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-absolute-task-qa-path',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 2, 15),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final text = await File(outPath).readAsString();
      expect(text, isNot(contains(tmp.path)));
      final report = jsonDecode(text) as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Task QA summary has 1 absolute report path(s).'),
      );
      final taskQa = report['taskQa']! as Map<String, Object?>;
      expect(taskQa['loadedReportCount'], 0);
      expect(taskQa['reportPathAudit'], {
        'reportPathCount': 1,
        'missingReportPathCount': 0,
        'absoluteReportPathCount': 1,
        'parentReportPathCount': 0,
        'malformedReportPathCount': 0,
        'outsideTaskQaRootReportPathCount': 0,
        'unsafeReportPathCount': 1,
        'unsafeReportPaths': [
          {'taskId': 'task.a', 'taskVersion': 1, 'reason': 'absolute'},
        ],
      });
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['absoluteReportPathCount'], 1);
      expect(corpusGate['unsafeReportPathCount'], 1);
    },
  );

  test('blocks report when task QA summary metadata is inconsistent', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_task_qa_summary_integrity_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
    final taskQaSummary = _taskQaSummaryJson(reportPath: reportPath);
    taskQaSummary['schemaVersion'] = 2;
    taskQaSummary['taskCount'] = 2;
    taskQaSummary['admittedTaskCount'] = 2;
    taskQaSummary['reports'] = [
      ...List<Object?>.from(taskQaSummary['reports']! as List),
      'not a report object',
    ];
    await File(taskQaSummaryPath).writeAsString(_prettyJson(taskQaSummary));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
    final stdoutLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-task-qa-summary-integrity',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 2, 30),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: (_) {},
    );

    expect(exitCode, 0);
    expect(stdoutLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Task QA summary schema version 2 is unsupported.'),
    );
    expect(blockers, contains('Task QA summary has 1 invalid report entry.'));
    expect(
      blockers,
      contains('Task QA summary task count does not match its report entries.'),
    );
    expect(
      blockers,
      contains(
        'Task QA summary admitted/rejected counts do not match report statuses.',
      ),
    );
    final taskQa = report['taskQa']! as Map<String, Object?>;
    expect(taskQa['summaryIntegrity'], {
      'status': 'invalid',
      'schemaVersion': 2,
      'schemaVersionStatus': 'unsupported',
      'generatedAtStatus': 'present',
      'reportListStatus': 'present',
      'rawReportEntryCount': 2,
      'reportEntryCount': 1,
      'invalidReportEntryCount': 1,
      'taskCount': 2,
      'admittedTaskCount': 2,
      'rejectedTaskCount': 0,
      'taskCountPresent': true,
      'admittedCountPresent': true,
      'rejectedCountPresent': true,
      'reportCountMatchesTaskCount': false,
      'admissionCountsMatchTaskCount': true,
      'admittedReportStatusCount': 1,
      'rejectedReportStatusCount': 0,
      'unknownReportStatusCount': 0,
      'admissionCountsMatchReportStatuses': false,
    });
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
    expect(corpusGate['status'], 'blocked');
    expect(corpusGate['summaryIntegrityStatus'], 'invalid');
    expect(corpusGate['summarySchemaVersion'], 2);
    expect(corpusGate['invalidSummaryReportEntryCount'], 1);
    expect(corpusGate['summaryReportCountMatchesTaskCount'], false);
    expect(corpusGate['summaryAdmissionCountsMatchReportStatuses'], false);
  });

  test(
    'blocks report when task QA summary generatedAt is future dated',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_future_generated_at_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      final taskQaSummary = _taskQaSummaryJson(reportPath: reportPath);
      taskQaSummary['generatedAt'] = '2026-06-05T00:00:00.000Z';
      await File(taskQaSummaryPath).writeAsString(_prettyJson(taskQaSummary));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-future-generated-at',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 2, 45),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Task QA summary generatedAt timestamp is future.'),
      );
      final taskQa = report['taskQa']! as Map<String, Object?>;
      final summaryIntegrity =
          taskQa['summaryIntegrity']! as Map<String, Object?>;
      expect(summaryIntegrity['status'], 'invalid');
      expect(summaryIntegrity['generatedAtStatus'], 'future');
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['summaryIntegrityStatus'], 'invalid');
      expect(corpusGate['summaryGeneratedAtStatus'], 'future');
    },
  );

  test(
    'blocks report when loaded task QA report generatedAt is future dated',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_report_future_generated_at_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(_taskQaReportJson(generatedAt: '2026-06-05T00:00:00.000Z')),
      );
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-report-future-generated-at',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 2, 45),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Task QA report task.a@v1 generatedAt timestamp is future.'),
      );
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      final taskReportTimestamps =
          verifierAudit['taskReportTimestamps']! as Map<String, Object?>;
      expect(taskReportTimestamps['presentCount'], 0);
      expect(taskReportTimestamps['futureCount'], 1);
      expect(taskReportTimestamps['tasksWithInvalidGeneratedAt'], [
        {'taskId': 'task.a', 'taskVersion': 1, 'status': 'future'},
      ]);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['taskReportGeneratedAtPresentCount'], 0);
      expect(corpusGate['taskReportGeneratedAtFutureCount'], 1);
    },
  );

  test(
    'blocks report when loaded task QA report schema or status is unsupported',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_report_integrity_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(_taskQaReportJson(schemaVersion: 2, status: 'pending')),
      );
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-report-integrity',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 2, 50),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Task QA report task.a@v1 schema version 2 is unsupported.'),
      );
      expect(
        blockers,
        contains('Task QA report task.a@v1 status is not admitted.'),
      );
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      final taskReportIntegrity =
          verifierAudit['taskReportIntegrity']! as Map<String, Object?>;
      expect(taskReportIntegrity['supportedSchemaVersionCount'], 0);
      expect(taskReportIntegrity['unsupportedSchemaVersionCount'], 1);
      expect(taskReportIntegrity['admittedStatusCount'], 0);
      expect(taskReportIntegrity['unknownStatusCount'], 1);
      expect(taskReportIntegrity['tasksWithSchemaVersionIssues'], [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'status': 'unsupported',
          'schemaVersion': 2,
        },
      ]);
      expect(taskReportIntegrity['tasksWithStatusIssues'], [
        {'taskId': 'task.a', 'taskVersion': 1, 'status': 'unknown'},
      ]);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['taskReportSupportedSchemaVersionCount'], 0);
      expect(corpusGate['taskReportUnsupportedSchemaVersionCount'], 1);
      expect(corpusGate['taskReportAdmittedStatusCount'], 0);
      expect(corpusGate['taskReportUnknownStatusCount'], 1);
    },
  );

  test(
    'blocks report when task QA summary mismatches loaded report evidence',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_summary_report_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(taskQaSummaryPath).writeAsString(
        _prettyJson(
          _taskQaSummaryJson(reportPath: reportPath, failureCount: 2),
        ),
      );
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-summary-report-mismatch',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 2, 55),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task QA summary failure count does not match loaded report for task.a@v1.',
        ),
      );
      final taskQa = report['taskQa']! as Map<String, Object?>;
      final summaryReportConsistency =
          taskQa['summaryReportConsistency']! as Map<String, Object?>;
      expect(summaryReportConsistency['matchedReportCount'], 1);
      expect(summaryReportConsistency['failureCountMismatchCount'], 1);
      expect(summaryReportConsistency['tasksWithFailureCountMismatches'], [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'summaryFailureCount': 2,
          'reportFailureCount': 0,
        },
      ]);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['matchedSummaryReportCount'], 1);
      expect(corpusGate['summaryReportFailureCountMismatchCount'], 1);
    },
  );

  test('blocks report when task QA report is newer than its summary', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_task_qa_report_newer_than_summary_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
    await File(taskQaSummaryPath).writeAsString(
      _prettyJson(
        _taskQaSummaryJson(
          reportPath: reportPath,
          generatedAt: '2026-06-03T12:00:00.000Z',
        ),
      ),
    );
    await File(reportPath).writeAsString(
      _prettyJson(_taskQaReportJson(generatedAt: '2026-06-03T12:10:00.000Z')),
    );
    final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
    final stdoutLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-task-qa-report-newer-than-summary',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 3),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: (_) {},
    );

    expect(exitCode, 0);
    expect(stdoutLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Task QA report generatedAt is after summary generatedAt for task.a@v1.',
      ),
    );
    final taskQa = report['taskQa']! as Map<String, Object?>;
    final summaryReportConsistency =
        taskQa['summaryReportConsistency']! as Map<String, Object?>;
    expect(summaryReportConsistency['reportGeneratedAfterSummaryCount'], 1);
    expect(summaryReportConsistency['tasksWithReportGeneratedAfterSummary'], [
      {
        'taskId': 'task.a',
        'taskVersion': 1,
        'summaryGeneratedAt': '2026-06-03T12:00:00.000Z',
        'reportGeneratedAt': '2026-06-03T12:10:00.000Z',
      },
    ]);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
    expect(corpusGate['status'], 'blocked');
    expect(corpusGate['summaryReportGeneratedAfterSummaryCount'], 1);
  });

  test(
    'blocks report when loaded task QA report admission checks fail',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_admission_checks_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(checksOverride: {'referenceHiddenPassed': false}),
        ),
      );
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-admission-checks',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3, 5),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 admission check referenceHiddenPassed is failed.',
        ),
      );
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      final admissionChecks =
          verifierAudit['admissionChecks']! as Map<String, Object?>;
      expect(admissionChecks['requiredCheckCount'], 6);
      expect(admissionChecks['passedRequiredCheckCount'], 5);
      expect(admissionChecks['failedRequiredCheckCount'], 1);
      expect(admissionChecks['tasksWithAdmissionCheckIssues'], [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'check': 'referenceHiddenPassed',
          'status': 'failed',
        },
      ]);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['requiredAdmissionCheckCount'], 6);
      expect(corpusGate['passedRequiredAdmissionCheckCount'], 5);
      expect(corpusGate['failedRequiredAdmissionCheckCount'], 1);
    },
  );

  test(
    'blocks report when loaded task QA admission provenance is incomplete',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_admission_provenance_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            admissionProvenanceOverride: {
              'tool': {'name': 'wrong_tool'},
              'evaluator': {'schemaVersion': 0, 'version': ''},
              'environment': {
                'dartVersion': 'unknown',
                'flutterVersion': '',
                'dependencySnapshot': {'status': 'missing'},
              },
            },
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-admission-provenance',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3, 8),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 admission tool metadata is invalid.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 admission evaluator metadata is invalid.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 admission environment SDK metadata is incomplete.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 admission environment dependency snapshot metadata is incomplete.',
        ),
      );
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      final admissionProvenance =
          verifierAudit['admissionProvenance']! as Map<String, Object?>;
      expect(admissionProvenance['presentCount'], 1);
      expect(admissionProvenance['missingCount'], 0);
      expect(admissionProvenance['invalidToolCount'], 1);
      expect(admissionProvenance['invalidEvaluatorCount'], 1);
      expect(admissionProvenance['environmentPresentCount'], 1);
      expect(admissionProvenance['environmentMissingCount'], 0);
      expect(admissionProvenance['sdkVersionPresentCount'], 0);
      expect(admissionProvenance['sdkVersionIncompleteCount'], 1);
      expect(admissionProvenance['dependencySnapshotPresentCount'], 0);
      expect(admissionProvenance['dependencySnapshotIncompleteCount'], 1);
      expect(
        admissionProvenance['tasksWithAdmissionProvenanceIssues'],
        containsAll([
          isA<Map<String, Object?>>().having(
            (issue) => issue['status'],
            'status',
            'invalid_tool',
          ),
          isA<Map<String, Object?>>().having(
            (issue) => issue['status'],
            'status',
            'invalid_evaluator',
          ),
          isA<Map<String, Object?>>().having(
            (issue) => issue['status'],
            'status',
            'incomplete_sdk_versions',
          ),
          isA<Map<String, Object?>>().having(
            (issue) => issue['status'],
            'status',
            'incomplete_dependency_snapshot',
          ),
        ]),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['admissionProvenancePresentCount'], 1);
      expect(corpusGate['invalidAdmissionToolCount'], 1);
      expect(corpusGate['invalidAdmissionEvaluatorCount'], 1);
      expect(corpusGate['admissionEnvironmentSdkVersionPresentCount'], 0);
      expect(corpusGate['admissionEnvironmentSdkVersionIncompleteCount'], 1);
      expect(
        corpusGate['admissionEnvironmentDependencySnapshotPresentCount'],
        0,
      );
      expect(
        corpusGate['admissionEnvironmentDependencySnapshotIncompleteCount'],
        1,
      );
    },
  );

  test(
    'blocks report when task QA admission evaluator schema is stale',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_admission_schema_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            admissionProvenanceOverride: {
              'tool': {'name': 'dart_arena_task_qa'},
              'evaluator': {
                'schemaVersion': 1,
                'version': '2026-05-31-master-spec',
              },
              'environment': {
                'dartVersion': '3.9.0',
                'flutterVersion': '3.35.0',
                'dependencySnapshot': {
                  'status': 'present',
                  'files': {
                    'pubspec.lock': {
                      'sha256':
                          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                      'bytes': 12345,
                    },
                  },
                },
              },
            },
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-admission-schema',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3, 9),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 admission evaluator metadata is invalid.',
        ),
      );
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      final admissionProvenance =
          verifierAudit['admissionProvenance']! as Map<String, Object?>;
      expect(admissionProvenance['invalidEvaluatorCount'], 1);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['invalidAdmissionEvaluatorCount'], 1);
    },
  );

  test('blocks report when task bundle digest is absent', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_task_bundle_digest_absent_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    final report = await _runTaskBundleIntegrityReleaseReport(
      tmp,
      includeDigest: false,
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Task QA report task.a@v1 task bundle digest is missing.'),
    );
    final audit = report['verifierAudit']! as Map<String, Object?>;
    final integrity = audit['taskBundleIntegrity']! as Map<String, Object?>;
    expect(integrity['digestMissingCount'], 1);
    expect(integrity['digestMatchedCount'], 0);
  });

  test('blocks report when task bundle digest mismatches disk', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_task_bundle_digest_mismatch_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    final report = await _runTaskBundleIntegrityReleaseReport(
      tmp,
      includeDigest: true,
      digestOverride:
          '0000000000000000000000000000000000000000000000000000000000000000',
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Task QA report task.a@v1 task bundle digest does not match the disk bundle.',
      ),
    );
    final audit = report['verifierAudit']! as Map<String, Object?>;
    final integrity = audit['taskBundleIntegrity']! as Map<String, Object?>;
    expect(integrity['digestMismatchedCount'], 1);
    expect(integrity['digestMatchedCount'], 0);
  });

  test('blocks report when admission environment is dirty', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_task_bundle_git_dirty_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    final report = await _runTaskBundleIntegrityReleaseReport(
      tmp,
      includeDigest: true,
      admissionGitDirty: true,
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Task QA report task.a@v1 admission environment gitDirty must be false.',
      ),
    );
    final audit = report['verifierAudit']! as Map<String, Object?>;
    final integrity = audit['taskBundleIntegrity']! as Map<String, Object?>;
    expect(integrity['admissionEnvironmentGitDirtyCount'], 1);
    expect(integrity['digestMatchedCount'], 1);
  });

  test(
    'blocks report when admission environment gitDirty is not false',
    () async {
      Future<void> expectBlocked({
        required String suffix,
        required Object? gitDirty,
        bool includeGitDirty = true,
      }) async {
        final tmp = await Directory.systemTemp.createTemp(
          'release_report_task_bundle_git_dirty_${suffix}_',
        );
        addTearDown(() async {
          if (await tmp.exists()) await tmp.delete(recursive: true);
        });

        final report = await _runTaskBundleIntegrityReleaseReport(
          tmp,
          includeDigest: true,
          admissionGitDirty: gitDirty,
          includeAdmissionGitDirty: includeGitDirty,
        );

        final blockers = (report['blockers']! as List<Object?>).join('\n');
        expect(
          blockers,
          contains(
            'Task QA report task.a@v1 admission environment gitDirty must be false.',
          ),
        );
        final audit = report['verifierAudit']! as Map<String, Object?>;
        final integrity = audit['taskBundleIntegrity']! as Map<String, Object?>;
        expect(integrity['admissionEnvironmentGitDirtyCount'], 1);
        expect(integrity['digestMatchedCount'], 1);
      }

      await expectBlocked(
        suffix: 'missing',
        gitDirty: false,
        includeGitDirty: false,
      );
      await expectBlocked(suffix: 'null', gitDirty: null);
      await expectBlocked(suffix: 'invalid', gitDirty: 'unknown');
    },
  );

  test(
    'recomputes task bundle digest through every task QA ingestion path',
    () async {
      for (final inputMode in _TaskQaInputMode.values) {
        final tmp = await Directory.systemTemp.createTemp(
          'release_report_task_bundle_${inputMode.name}_',
        );
        addTearDown(() async {
          if (await tmp.exists()) await tmp.delete(recursive: true);
        });

        final report = await _runTaskBundleIntegrityReleaseReport(
          tmp,
          includeDigest: true,
          inputMode: inputMode,
          useBuildOutputLayout: true,
        );

        final audit = report['verifierAudit']! as Map<String, Object?>;
        final integrity = audit['taskBundleIntegrity']! as Map<String, Object?>;
        expect(integrity['digestMatchedCount'], 1, reason: inputMode.name);
        expect(
          integrity['digestRecomputeMissingCount'],
          0,
          reason: inputMode.name,
        );
      }
    },
  );

  test('reports why build-output digest evidence is unavailable', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_task_bundle_unavailable_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    final report = await _runTaskBundleIntegrityReleaseReport(
      tmp,
      includeDigest: true,
      useBuildOutputLayout: true,
      includeTaskBundleRoot: false,
    );

    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Task QA report task.a@v1 digest evidence unavailable: task bundle root was not provided and report is not beside a task bundle.',
      ),
    );
  });

  test('blocks report when loaded task QA execution policy is unsafe', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_task_qa_execution_policy_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(
      _prettyJson(
        _taskQaReportJson(
          executionPolicyOverride: {
            'allowInternet': true,
            'resources': {'cpus': 2},
          },
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
    final stdoutLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-task-qa-execution-policy',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 3, 9),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: (_) {},
    );

    expect(exitCode, 0);
    expect(stdoutLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Task QA report task.a@v1 allows generated-code networking.'),
    );
    expect(
      blockers,
      contains(
        'Task QA report task.a@v1 has incomplete task resource limit metadata.',
      ),
    );
    final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
    final taskExecutionPolicy =
        verifierAudit['taskExecutionPolicy']! as Map<String, Object?>;
    expect(taskExecutionPolicy['presentCount'], 1);
    expect(taskExecutionPolicy['missingCount'], 0);
    expect(taskExecutionPolicy['incompleteCount'], 0);
    expect(taskExecutionPolicy['networkDisabledCount'], 0);
    expect(taskExecutionPolicy['networkEnabledCount'], 1);
    expect(taskExecutionPolicy['resourceLimitPresentCount'], 0);
    expect(taskExecutionPolicy['resourceLimitIncompleteCount'], 1);
    expect(
      taskExecutionPolicy['tasksWithExecutionPolicyIssues'],
      containsAll([
        isA<Map<String, Object?>>().having(
          (issue) => issue['status'],
          'status',
          'network_enabled',
        ),
        isA<Map<String, Object?>>().having(
          (issue) => issue['status'],
          'status',
          'incomplete_resource_limits',
        ),
      ]),
    );
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
    expect(corpusGate['status'], 'blocked');
    expect(corpusGate['taskExecutionPolicyPresentCount'], 1);
    expect(corpusGate['taskExecutionPolicyNetworkDisabledCount'], 0);
    expect(corpusGate['taskExecutionPolicyNetworkEnabledCount'], 1);
    expect(corpusGate['taskResourceLimitPresentCount'], 0);
    expect(corpusGate['taskResourceLimitIncompleteCount'], 1);
  });

  test(
    'blocks report when loaded task QA prompt safety evidence mismatches checks',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_prompt_safety_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            promptSafetyOverride: {
              'target_context_present': true,
              'public_test_context_present': true,
              'public_test_context_required': true,
              'implementation_bodies_omitted': true,
              'hidden_verifier_leak_free': true,
              'reference_leak_free': true,
              'passed': false,
              'required_negative_case_kinds': [
                'api_breaking',
                'noop',
                'overfit',
              ],
              'present_negative_case_kinds': ['api_breaking', 'noop'],
              'missing_negative_case_kinds': ['overfit'],
            },
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-prompt-safety',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3, 10),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 prompt-safety evidence did not pass.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 promptSafeContextLeakFree check does not match prompt-safety evidence.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 prompt-safety evidence is missing required negative case kind(s): overfit.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 requiredNegativeCaseKindsCovered check does not match prompt-safety evidence.',
        ),
      );
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      final promptSafety =
          verifierAudit['promptSafety']! as Map<String, Object?>;
      expect(promptSafety['presentCount'], 1);
      expect(promptSafety['missingCount'], 0);
      expect(promptSafety['failedCount'], 1);
      expect(promptSafety['invalidPassedFlagCount'], 0);
      expect(promptSafety['missingRequiredNegativeKindCount'], 1);
      expect(promptSafety['promptSafeCheckMismatchCount'], 1);
      expect(promptSafety['requiredKindCoverageMismatchCount'], 1);
      final promptSafetyIssues =
          promptSafety['tasksWithPromptSafetyIssues']! as List<Object?>;
      expect(
        promptSafetyIssues,
        contains(
          isA<Map<String, Object?>>()
              .having((issue) => issue['taskId'], 'taskId', 'task.a')
              .having((issue) => issue['taskVersion'], 'taskVersion', 1)
              .having(
                (issue) => issue['status'],
                'status',
                'missing_required_negative_case_kinds',
              )
              .having((issue) => issue['missingKinds'], 'missingKinds', [
                'overfit',
              ]),
        ),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['promptSafetyPresentCount'], 1);
      expect(corpusGate['failedPromptSafetyCount'], 1);
      expect(corpusGate['missingPromptSafetyRequiredNegativeKindCount'], 1);
      expect(corpusGate['promptSafeCheckMismatchCount'], 1);
      expect(corpusGate['requiredKindCoverageMismatchCount'], 1);
    },
  );

  test(
    'blocks report when loaded task QA prompt safety kind metadata is inconsistent',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_prompt_safety_kinds_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            promptSafetyOverride: {
              'target_context_present': true,
              'public_test_context_present': true,
              'public_test_context_required': true,
              'implementation_bodies_omitted': true,
              'hidden_verifier_leak_free': true,
              'reference_leak_free': true,
              'passed': true,
              'required_negative_case_kinds': [
                'noop',
                'overfit',
                'unknown_kind',
              ],
              'present_negative_case_kinds': ['noop'],
              'missing_negative_case_kinds': <String>[],
            },
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-prompt-safety-kinds',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3, 15),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 prompt-safety negative-case kind metadata is invalid.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 prompt-safety present negative-case kinds do not match loaded evidence.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 prompt-safety missing negative-case kinds do not match required/present evidence.',
        ),
      );
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      final promptSafety =
          verifierAudit['promptSafety']! as Map<String, Object?>;
      expect(promptSafety['invalidKindCount'], 1);
      expect(promptSafety['presentKindMismatchCount'], 1);
      expect(promptSafety['missingKindMismatchCount'], 1);
      final promptSafetyIssues =
          promptSafety['tasksWithPromptSafetyIssues']! as List<Object?>;
      expect(
        promptSafetyIssues,
        contains(
          isA<Map<String, Object?>>()
              .having(
                (issue) => issue['status'],
                'status',
                'invalid_negative_case_kinds',
              )
              .having((issue) => issue['kinds'], 'kinds', ['unknown_kind']),
        ),
      );
      expect(
        promptSafetyIssues,
        contains(
          isA<Map<String, Object?>>().having(
            (issue) => issue['status'],
            'status',
            'present_negative_case_kind_mismatch',
          ),
        ),
      );
      expect(
        promptSafetyIssues,
        contains(
          isA<Map<String, Object?>>().having(
            (issue) => issue['status'],
            'status',
            'missing_negative_case_kind_mismatch',
          ),
        ),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['promptSafetyInvalidKindCount'], 1);
      expect(corpusGate['promptSafetyPresentKindMismatchCount'], 1);
      expect(corpusGate['promptSafetyMissingKindMismatchCount'], 1);
    },
  );

  test(
    'blocks report when loaded task QA prompt safety passed flag mismatches components',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_prompt_safety_components_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            promptSafetyOverride: {
              'target_context_present': true,
              'public_test_context_present': true,
              'public_test_context_required': true,
              'implementation_bodies_omitted': true,
              'hidden_verifier_leak_free': false,
              'reference_leak_free': true,
              'required_negative_case_kinds': [
                'api_breaking',
                'noop',
                'overfit',
              ],
              'present_negative_case_kinds': [
                'api_breaking',
                'noop',
                'overfit',
              ],
              'missing_negative_case_kinds': <String>[],
              'passed': true,
            },
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
      final stdoutLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-prompt-safety-components',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3, 18),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 prompt-safety passed flag does not match component evidence.',
        ),
      );
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      final promptSafety =
          verifierAudit['promptSafety']! as Map<String, Object?>;
      expect(promptSafety['invalidComponentFieldCount'], 0);
      expect(promptSafety['passedComputationMismatchCount'], 1);
      expect(
        promptSafety['tasksWithPromptSafetyIssues'],
        contains(
          isA<Map<String, Object?>>()
              .having(
                (issue) => issue['status'],
                'status',
                'passed_computation_mismatch',
              )
              .having((issue) => issue['expected'], 'expected', false)
              .having((issue) => issue['actual'], 'actual', true),
        ),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['promptSafetyInvalidComponentFieldCount'], 0);
      expect(corpusGate['promptSafetyPassedComputationMismatchCount'], 1);
    },
  );

  test('writes ready report with sanitized run provenance', () async {
    final tmp = await Directory.systemTemp.createTemp('release_report_ready_');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final taskBundle = Directory(p.join(taskQaDir.path, 'tasks', 'task.a'));
    final taskBundleDigest = await _writeReleaseTaskBundle(taskBundle);
    final reportPath = p.join(taskBundle.path, 'qa', 'admission_report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(taskQaSummaryPath).writeAsString(
      _prettyJson(
        _taskQaSummaryJson(
          reportPath: p
              .relative(reportPath, from: taskQaDir.path)
              .replaceAll('\\', '/'),
        ),
      ),
    );
    await File(reportPath).writeAsString(
      _prettyJson(_taskQaReportJson(taskBundleDigest: taskBundleDigest)),
    );
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-ready',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 3, 16),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(stdoutLines.single, contains('"status":"ready"'));
    final text = await File(outPath).readAsString();
    expect(text, isNot(contains('sk-live')));
    expect(text, isNot(contains(tmp.path)));
    final report = jsonDecode(text) as Map<String, Object?>;
    expect(report['status'], 'ready');
    expect(report['blockers'], isEmpty);
    final inputs = report['inputs']! as Map<String, Object?>;
    _expectFingerprint(
      inputs['leaderboard']! as Map<String, Object?>,
      path: 'leaderboard.v1.json',
    );
    _expectFingerprint(
      inputs['taskQaSummary']! as Map<String, Object?>,
      path: 'admission_summary.json',
    );
    _expectFingerprint(
      inputs['database']! as Map<String, Object?>,
      path: 'dart_arena.sqlite',
    );
    _expectFingerprint(
      inputs['artifactManifest']! as Map<String, Object?>,
      path: 'manifest.json',
    );
    _expectFingerprint(
      inputs['artifactChecksums']! as Map<String, Object?>,
      path: 'checksums.json',
    );
    _expectFingerprint(
      inputs['artifactRunResults']! as Map<String, Object?>,
      path: 'run_results.v1.json',
    );
    _expectFingerprint(
      inputs['artifactResultsCsv']! as Map<String, Object?>,
      path: 'results.csv',
    );
    _expectFingerprint(
      inputs['artifactReport']! as Map<String, Object?>,
      path: 'report.md',
    );
    final artifactFiles = inputs['artifactFiles']! as List<Object?>;
    expect(artifactFiles.length, 4);
    _expectFingerprint(
      artifactFiles.first! as Map<String, Object?>,
      path: 'artifacts/responses/task-run-1.txt',
    );
    final taskQaReports = inputs['taskQaReports']! as List<Object?>;
    _expectFingerprint(
      taskQaReports.single! as Map<String, Object?>,
      path: 'tasks/task.a/qa/admission_report.json',
    );
    final provenance = report['provenance']! as Map<String, Object?>;
    expect(provenance['embeddedRunCount'], 1);
    expect(provenance['sandboxEnforcedRunCount'], 1);
    expect(provenance['taskExecutionPolicyRunCount'], 1);
    expect(provenance['networkDisabledTaskPolicyRunCount'], 1);
    expect(provenance['taskResourceLimitRunCount'], 1);
    expect(provenance['sdkVersionRunCount'], 1);
    expect(provenance['dependencySnapshotRunCount'], 1);
    expect(provenance['pricingRegistryRunCount'], 1);
    final leaderboard = report['leaderboard']! as Map<String, Object?>;
    final benchmark = leaderboard['benchmark']! as Map<String, Object?>;
    final source = leaderboard['source']! as Map<String, Object?>;
    final scoring = leaderboard['scoring']! as Map<String, Object?>;
    expect(benchmark['version'], '2026-05-31-master-spec');
    expect(benchmark['taskSetId'], 'taskset-test');
    expect(benchmark['evaluatorSchemaVersion'], 2);
    expect(scoring['primaryMetric'], 'primary_pass');
    expect(scoring['rankingMetric'], 'primary_pass_rate');
    expect(scoring['confidenceInterval'], 'wilson_95');
    expect(
      scoring['failureTags'],
      containsAll(['pass', 'public_tests_failed', 'hidden_verifier_failed']),
    );
    expect(source['judgeOverhead'], {
      'status': 'present',
      'evaluationCount': 1,
      'promptTokens': 100,
      'completionTokens': 20,
      'knownEstimatedCostCount': 1,
      'unknownEstimatedCostCount': 0,
      'totalEstimatedCostMicros': 325,
      'pricingStatusCounts': {'exact': 1},
    });
    expect(source['runProvenance'], {
      'runCount': 1,
      'embeddedRunCount': 1,
      'sandboxEnforcedRunCount': 1,
      'taskExecutionPolicyRunCount': 1,
      'networkDisabledTaskPolicyRunCount': 1,
      'taskResourceLimitRunCount': 1,
      'sdkVersionRunCount': 1,
      'dependencySnapshotRunCount': 1,
      'pricingRegistryRunCount': 1,
      'generatedCodeSandboxBackends': ['test-sandbox'],
      'dartVersions': ['3.9.0'],
      'flutterVersions': ['3.35.0'],
      'environmentIds': ['test-env-1'],
      'warnings': <Object?>[],
    });
    expect(leaderboard['taskModelCells'], {
      'cellCount': 1,
      'expectedCellCount': 1,
      'missingCellCount': 0,
      'sampleCount': 2,
      'errorCount': 0,
      'unknownCostCellCount': 0,
      'unknownTraceMetricCellCount': 0,
      'unknownTokenUsageCellCount': 0,
      'missingMetricCellCount': 0,
    });
    expect(leaderboard['modelIdentity'], {
      'status': 'present',
      'invalidModelRowCount': 0,
      'invalidTaskModelCellCount': 0,
      'invalidTrialSummaryCount': 0,
      'invalidModelIdentityCount': 0,
    });
    expect(leaderboard['trialTransparency'], {
      'trialSummaryCount': 2,
      'trialSummaryTotalCount': 2,
      'trialSummaryLimit': 1000,
      'trialSummaryTruncated': false,
      'missingMetricTrialCount': 0,
      'unknownCostTrialCount': 0,
      'unknownTraceMetricTrialCount': 0,
      'unknownTokenUsageTrialCount': 0,
      'missingModelPassAtKCount': 0,
      'missingTaskPassAtKCount': 0,
      'missingCellPassAtKCount': 0,
      'missingModelConfidenceIntervalCount': 0,
      'missingTaskConfidenceIntervalCount': 0,
      'missingCellConfidenceIntervalCount': 0,
    });
    expect(leaderboard['privacy'], {
      'status': 'passed',
      'issueCount': 0,
      'secretKeyCount': 0,
      'secretValueCount': 0,
      'absolutePathCount': 0,
      'hiddenVerifierMarkerCount': 0,
      'privatePromptFieldCount': 0,
      'sensitiveModelOutputFieldCount': 0,
    });
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'present');
    expect(artifactBundle['runId'], 'run-1');
    expect(artifactBundle['runIdStatus'], 'present');
    expect(artifactBundle['runIdInLeaderboardSource'], true);
    expect(artifactBundle['taskRunCount'], 2);
    expect(artifactBundle['agenticTaskRunCount'], 2);
    expect(artifactBundle['evaluationCount'], 4);
    expect(artifactBundle['manifestPopulationSummaryStatus'], 'present');
    expect(artifactBundle['manifestTaskCountStatus'], 'present');
    expect(artifactBundle['manifestProviderCountStatus'], 'present');
    expect(artifactBundle['manifestModelCountStatus'], 'present');
    expect(artifactBundle['manifestTaskCount'], 1);
    expect(artifactBundle['manifestProviderCount'], 1);
    expect(artifactBundle['manifestModelCount'], 1);
    expect(artifactBundle['manifestDistinctTaskCount'], 1);
    expect(artifactBundle['manifestDistinctProviderCount'], 1);
    expect(artifactBundle['manifestDistinctModelCount'], 1);
    expect(artifactBundle['manifestPopulationCountMismatchCount'], 0);
    expect(artifactBundle['manifestEvaluatorIdCount'], 2);
    expect(artifactBundle['invalidManifestEvaluatorIdCount'], 0);
    expect(artifactBundle['duplicateManifestEvaluatorIdCount'], 0);
    expect(artifactBundle['artifactCount'], 4);
    expect(artifactBundle['artifactKindCounts'], {'patch': 2, 'response': 2});
    expect(artifactBundle['warningCount'], 0);
    expect(artifactBundle['checksumsStatus'], 'present');
    expect(artifactBundle['checksumSchemaVersion'], 1);
    expect(artifactBundle['checksumAlgorithm'], 'sha256');
    expect(artifactBundle['checksumFileCount'], 8);
    expect(artifactBundle['manifestChecksumStatus'], 'present');
    expect(artifactBundle['manifestChecksumDigestStatus'], 'matched');
    expect(artifactBundle['checksumsPathMatchesInput'], true);
    expect(artifactBundle['coveredArtifactChecksumCount'], 4);
    expect(artifactBundle['missingArtifactChecksumCount'], 0);
    expect(artifactBundle['coveredStandardChecksumCount'], 4);
    expect(artifactBundle['missingStandardChecksumCount'], 0);
    expect(artifactBundle['verifiedStandardChecksumCount'], 3);
    expect(artifactBundle['missingStandardInputCount'], 0);
    expect(artifactBundle['mismatchedStandardChecksumCount'], 0);
    expect(artifactBundle['standardInputPathMismatchCount'], 0);
    expect(artifactBundle['verifiedArtifactFileCount'], 4);
    expect(artifactBundle['missingArtifactFileCount'], 0);
    expect(artifactBundle['mismatchedArtifactFileByteCount'], 0);
    expect(artifactBundle['mismatchedArtifactFileDigestCount'], 0);
    expect(artifactBundle['unexpectedChecksumPathCount'], 0);
    expect(artifactBundle['unsafeChecksumPathCount'], 0);
    expect(artifactBundle['absoluteChecksumPathCount'], 0);
    expect(artifactBundle['parentChecksumPathCount'], 0);
    expect(artifactBundle['privateChecksumPathCount'], 0);
    expect(artifactBundle['outsideArtifactRootChecksumPathCount'], 0);
    expect(artifactBundle['resultsCsvStatus'], 'present');
    expect(artifactBundle['resultsCsvTaskRunCount'], 2);
    expect(artifactBundle['missingResultsCsvHeaderCount'], 0);
    expect(artifactBundle['invalidResultsCsvTaskRunCount'], 0);
    expect(artifactBundle['duplicateResultsCsvTaskRunCount'], 0);
    expect(artifactBundle['missingResultsCsvTaskRunCount'], 0);
    expect(artifactBundle['extraResultsCsvTaskRunCount'], 0);
    expect(artifactBundle['mismatchedResultsCsvRunResultsCount'], 0);
    expect(artifactBundle['invalidResultsCsvOutcomeCount'], 0);
    expect(artifactBundle['reportMarkdownStatus'], 'present');
    expect(artifactBundle['reportMarkdownDeclaredTaskRunCount'], 2);
    expect(artifactBundle['reportMarkdownTaskRunCount'], 2);
    expect(artifactBundle['missingReportMarkdownSectionCount'], 0);
    expect(artifactBundle['missingReportMarkdownColumnCount'], 0);
    expect(artifactBundle['invalidReportMarkdownTaskRunCount'], 0);
    expect(artifactBundle['duplicateReportMarkdownTaskRunCount'], 0);
    expect(artifactBundle['missingReportMarkdownTaskRunCount'], 0);
    expect(artifactBundle['extraReportMarkdownTaskRunCount'], 0);
    expect(artifactBundle['mismatchedReportMarkdownRunResultsCount'], 0);
    expect(artifactBundle['invalidReportMarkdownOutcomeCount'], 0);
    expect(artifactBundle['runResultsStatus'], 'present');
    expect(artifactBundle['runResultsSchemaVersion'], 1);
    expect(artifactBundle['runResultsRunId'], 'run-1');
    expect(artifactBundle['runResultsRunIdMatchesManifest'], true);
    expect(artifactBundle['runResultsRunMetadataStatus'], 'present');
    expect(artifactBundle['runResultsRunNameMatchesManifest'], true);
    expect(artifactBundle['runResultsRunStartedAtMatchesManifest'], true);
    expect(artifactBundle['runResultsRunCompletedAtMatchesManifest'], true);
    expect(artifactBundle['mismatchedRunResultsRunMetadataFieldCount'], 0);
    expect(artifactBundle['runResultsTaskRunCount'], 2);
    expect(artifactBundle['runResultsEvaluationCount'], 4);
    expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
    expect(artifactBundle['runResultsEvaluatorIdCount'], 2);
    expect(artifactBundle['runResultsEvaluatorIdsMatchManifest'], true);
    expect(artifactBundle['missingRunResultsEvaluatorIdCount'], 0);
    expect(artifactBundle['extraRunResultsEvaluatorIdCount'], 0);
    expect(artifactBundle['missingRunResultsTaskRunCount'], 0);
    expect(artifactBundle['extraRunResultsTaskRunCount'], 0);
    expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
    expect(artifactBundle['missingRunResultsAgenticHarnessMetadataCount'], 0);
    expect(
      artifactBundle['mismatchedRunResultsAgenticHarnessMetadataCount'],
      0,
    );
    expect(artifactBundle['mismatchedRunResultsTaskRunRunIdCount'], 0);
    expect(artifactBundle['mismatchedRunResultsTrialOutcomeCount'], 0);
    expect(artifactBundle['invalidRunResultsTrialOutcomeCount'], 0);
    expect(artifactBundle['invalidRunResultsTimingTaskRunCount'], 0);
    expect(artifactBundle['invalidRunResultsTokenUsageTaskRunCount'], 0);
    expect(artifactBundle['missingRunResultsEvaluationTaskRunCount'], 0);
    expect(artifactBundle['invalidRunResultsEvaluationCount'], 0);
    expect(artifactBundle['invalidRunResultsEvaluationRationaleCount'], 0);
    expect(
      artifactBundle['invalidRunResultsEvaluationDetailsMetadataCount'],
      0,
    );
    expect(
      artifactBundle['invalidRunResultsBlockedEvaluationMetadataCount'],
      0,
    );
    expect(artifactBundle['invalidRunResultsJudgeOverheadMetadataCount'], 0);
    expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
    expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
    expect(artifactBundle['invalidRunResultsTaskRunCount'], 0);
    expect(artifactBundle['invalidRunResultsTaskRunModelIdentityCount'], 0);
    expect(artifactBundle['duplicateRunResultsTaskRunCount'], 0);
    expect(artifactBundle['missingRunResultsArtifactCount'], 0);
    expect(artifactBundle['extraRunResultsArtifactCount'], 0);
    expect(artifactBundle['mismatchedRunResultsArtifactCount'], 0);
    expect(artifactBundle['invalidRunResultsArtifactMetadataCount'], 0);
    expect(artifactBundle['mismatchedRunResultsArtifactByteCount'], 0);
    expect(artifactBundle['mismatchedRunResultsArtifactDigestCount'], 0);
    expect(artifactBundle['unsafeArtifactPathCount'], 0);
    expect(artifactBundle['absoluteArtifactPathCount'], 0);
    expect(artifactBundle['parentArtifactPathCount'], 0);
    expect(artifactBundle['privateArtifactPathCount'], 0);
    expect(artifactBundle['outsideArtifactRootPathCount'], 0);
    expect(artifactBundle['manifestMetadataStatus'], 'present');
    expect(artifactBundle['manifestRunMetadataStatus'], 'present');
    expect(artifactBundle['manifestRunNameStatus'], 'present');
    expect(artifactBundle['manifestRunStartedAtStatus'], 'present');
    expect(artifactBundle['manifestRunCompletedAtStatus'], 'present');
    expect(artifactBundle['manifestRunDurationStatus'], 'valid');
    expect(
      artifactBundle['manifestRunCompletedBeforeGeneratedAtStatus'],
      'valid',
    );
    expect(artifactBundle['manifestOutcomeSummaryStatus'], 'present');
    expect(artifactBundle['manifestPassSummaryStatus'], 'present');
    expect(artifactBundle['manifestFailureSummaryStatus'], 'present');
    expect(artifactBundle['manifestPassSummaryMismatchCount'], 0);
    expect(artifactBundle['manifestFailureSummaryMismatchCount'], 0);
    expect(artifactBundle['manifestGeneratedAtStatus'], 'present');
    expect(artifactBundle['manifestAppVersionStatus'], 'present');
    expect(artifactBundle['manifestDriftSchemaVersionStatus'], 'present');
    expect(artifactBundle['manifestExportToolStatus'], 'present');
    expect(artifactBundle['manifestExportEnvironmentStatus'], 'present');
    expect(artifactBundle['manifestExportEnvironmentGitStatus'], 'clean');
    expect(artifactBundle['manifestProvenanceStatus'], 'present');
    expect(artifactBundle['manifestProvenanceRunId'], 'run-1');
    expect(artifactBundle['manifestProvenanceRunIdMatchesManifest'], true);
    expect(artifactBundle['manifestProvenanceSandboxStatus'], 'enforced');
    expect(artifactBundle['manifestProvenanceSandboxBackend'], 'test-sandbox');
    expect(
      artifactBundle['manifestProvenanceTaskExecutionPolicyStatus'],
      'present',
    );
    expect(
      artifactBundle['manifestProvenanceNetworkDisabledTaskPolicyStatus'],
      'disabled',
    );
    expect(
      artifactBundle['manifestProvenanceTaskResourceLimitStatus'],
      'present',
    );
    expect(artifactBundle['manifestProvenanceSdkVersionStatus'], 'present');
    expect(
      artifactBundle['manifestProvenanceDependencySnapshotStatus'],
      'present',
    );
    expect(
      artifactBundle['manifestProvenancePricingRegistryStatus'],
      'present',
    );
    expect(artifactBundle['missingResponseArtifactCount'], 0);
    expect(artifactBundle['missingAgenticPatchArtifactCount'], 0);
    expect(artifactBundle['missingAgenticHarnessMetadataCount'], 0);
    expect(artifactBundle['missingLeaderboardTrialSummaryTaskRunCount'], 0);
    expect(artifactBundle['extraLeaderboardTrialSummaryTaskRunCount'], 0);
    expect(artifactBundle['invalidTaskRunModelIdentityCount'], 0);
    expect(artifactBundle['invalidTaskRunCount'], 0);
    expect(artifactBundle['duplicateTaskRunCount'], 0);
    expect(artifactBundle['unknownArtifactKindCount'], 0);
    expect(artifactBundle['duplicateArtifactReferenceCount'], 0);
    final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
    expect(corpusGate['status'], 'passed');
    expect(corpusGate['taskCount'], 1);
    expect(corpusGate['leaderboardTaskCount'], 1);
    expect(corpusGate['coveredLeaderboardTaskCount'], 1);
    expect(corpusGate['missingLeaderboardTaskQaCount'], 0);
    expect(corpusGate['extraTaskQaReportCount'], 0);
    expect(corpusGate['invalidLeaderboardTaskRowCount'], 0);
    expect(corpusGate['invalidTaskQaReportRowCount'], 0);
    expect(corpusGate['summaryIntegrityStatus'], 'valid');
    expect(corpusGate['summarySchemaVersion'], 1);
    expect(corpusGate['summaryGeneratedAtStatus'], 'present');
    expect(corpusGate['summaryReportListStatus'], 'present');
    expect(corpusGate['summaryReportEntryCount'], 1);
    expect(corpusGate['invalidSummaryReportEntryCount'], 0);
    expect(corpusGate['summaryReportCountMatchesTaskCount'], true);
    expect(corpusGate['summaryAdmissionCountsMatchTaskCount'], true);
    expect(corpusGate['summaryAdmissionCountsMatchReportStatuses'], true);
    expect(corpusGate['matchedSummaryReportCount'], 1);
    expect(corpusGate['missingLoadedReportForSummaryCount'], 0);
    expect(corpusGate['unreferencedLoadedReportCount'], 0);
    expect(corpusGate['duplicateSummaryReportKeyCount'], 0);
    expect(corpusGate['duplicateLoadedReportKeyCount'], 0);
    expect(corpusGate['invalidSummaryFailureCountCount'], 0);
    expect(corpusGate['summaryReportStatusMismatchCount'], 0);
    expect(corpusGate['summaryReportFailureCountMismatchCount'], 0);
    expect(corpusGate['summaryReportGeneratedAfterSummaryCount'], 0);
    expect(corpusGate['missingReportPathCount'], 0);
    expect(corpusGate['absoluteReportPathCount'], 0);
    expect(corpusGate['parentReportPathCount'], 0);
    expect(corpusGate['malformedReportPathCount'], 0);
    expect(corpusGate['outsideTaskQaRootReportPathCount'], 0);
    expect(corpusGate['unsafeReportPathCount'], 0);
    expect(corpusGate['loadedReportCount'], 1);
    expect(corpusGate['hiddenVerifierDigestCount'], 1);
    expect(corpusGate['invalidHiddenVerifierDigestCount'], 0);
    expect(corpusGate['negativeCaseCount'], 3);
    expect(corpusGate['acceptedNegativeCaseCount'], 0);
    expect(corpusGate['malformedNegativeCaseEvidenceCount'], 0);
    expect(corpusGate['unsupportedNegativeCaseKindCount'], 0);
    expect(corpusGate['negativeCaseOutcomeMismatchCount'], 0);
    expect(corpusGate['privateOfficialTaskCount'], 1);
    expect(corpusGate['activeTaskCount'], 1);
    expect(corpusGate['tasksOutsidePrivateOfficialCorpusCount'], 0);
    expect(corpusGate['retiredTaskCount'], 0);
    expect(corpusGate['minHiddenFlakeRunsPerTask'], 3);
    expect(corpusGate['tasksBelowHiddenFlakeRunMinimumCount'], 0);
    expect(corpusGate['missingVerifierQualityAuditCount'], 0);
    expect(corpusGate['invalidVerifierQualityFieldCount'], 0);
    expect(corpusGate['verifierQualityMismatchCount'], 0);
    expect(corpusGate['requiredAdmissionCheckCount'], 6);
    expect(corpusGate['passedRequiredAdmissionCheckCount'], 6);
    expect(corpusGate['missingRequiredAdmissionCheckCount'], 0);
    expect(corpusGate['failedRequiredAdmissionCheckCount'], 0);
    expect(corpusGate['invalidRequiredAdmissionCheckCount'], 0);
    expect(corpusGate['failedOptionalAdmissionCheckCount'], 0);
    expect(corpusGate['invalidOptionalAdmissionCheckCount'], 0);
    expect(corpusGate['admittedReportWithFailureMessagesCount'], 0);
    expect(corpusGate['promptSafetyPresentCount'], 1);
    expect(corpusGate['missingPromptSafetyCount'], 0);
    expect(corpusGate['failedPromptSafetyCount'], 0);
    expect(corpusGate['invalidPromptSafetyPassedFlagCount'], 0);
    expect(corpusGate['missingPromptSafetyRequiredNegativeKindCount'], 0);
    expect(corpusGate['promptSafeCheckMismatchCount'], 0);
    expect(corpusGate['requiredKindCoverageMismatchCount'], 0);
    expect(corpusGate['promptSafetyInvalidKindCount'], 0);
    expect(corpusGate['promptSafetyPresentKindMismatchCount'], 0);
    expect(corpusGate['promptSafetyMissingKindMismatchCount'], 0);
    expect(corpusGate['promptSafetyInvalidComponentFieldCount'], 0);
    expect(corpusGate['promptSafetyPassedComputationMismatchCount'], 0);
    expect(corpusGate['admissionProvenancePresentCount'], 1);
    expect(corpusGate['missingAdmissionProvenanceCount'], 0);
    expect(corpusGate['invalidAdmissionToolCount'], 0);
    expect(corpusGate['invalidAdmissionEvaluatorCount'], 0);
    expect(corpusGate['admissionEnvironmentPresentCount'], 1);
    expect(corpusGate['admissionEnvironmentMissingCount'], 0);
    expect(corpusGate['admissionEnvironmentSdkVersionPresentCount'], 1);
    expect(corpusGate['admissionEnvironmentSdkVersionIncompleteCount'], 0);
    expect(corpusGate['admissionEnvironmentDependencySnapshotPresentCount'], 1);
    expect(
      corpusGate['admissionEnvironmentDependencySnapshotIncompleteCount'],
      0,
    );
    expect(corpusGate['taskExecutionPolicyPresentCount'], 1);
    expect(corpusGate['taskExecutionPolicyMissingCount'], 0);
    expect(corpusGate['taskExecutionPolicyIncompleteCount'], 0);
    expect(corpusGate['taskExecutionPolicyNetworkDisabledCount'], 1);
    expect(corpusGate['taskExecutionPolicyNetworkEnabledCount'], 0);
    expect(corpusGate['taskResourceLimitPresentCount'], 1);
    expect(corpusGate['taskResourceLimitIncompleteCount'], 0);
    expect(corpusGate['taskReportSupportedSchemaVersionCount'], 1);
    expect(corpusGate['taskReportMissingSchemaVersionCount'], 0);
    expect(corpusGate['taskReportUnsupportedSchemaVersionCount'], 0);
    expect(corpusGate['taskReportAdmittedStatusCount'], 1);
    expect(corpusGate['taskReportRejectedStatusCount'], 0);
    expect(corpusGate['taskReportUnknownStatusCount'], 0);
    expect(corpusGate['taskReportGeneratedAtPresentCount'], 1);
    expect(corpusGate['taskReportGeneratedAtMissingCount'], 0);
    expect(corpusGate['taskReportGeneratedAtInvalidCount'], 0);
    expect(corpusGate['taskReportGeneratedAtFutureCount'], 0);
    final executionGate = readinessGates['execution']! as Map<String, Object?>;
    expect(executionGate['status'], 'passed');
    expect(executionGate['runCount'], 1);
    expect(executionGate['sourceSandboxEnforcedRunCount'], 1);
    expect(executionGate['storedSandboxEnforcedRunCount'], 1);
    expect(executionGate['sourceNetworkDisabledTaskPolicyRunCount'], 1);
    expect(executionGate['storedNetworkDisabledTaskPolicyRunCount'], 1);
    expect(executionGate['sourceTaskResourceLimitRunCount'], 1);
    expect(executionGate['storedTaskResourceLimitRunCount'], 1);
    expect(executionGate['sandboxBackendCount'], 1);
    final scoringGate = readinessGates['scoring']! as Map<String, Object?>;
    expect(scoringGate['status'], 'passed');
    expect(scoringGate['primaryMetric'], 'primary_pass');
    expect(scoringGate['requiredFailureTagsPresent'], true);
    expect(scoringGate['lowSampleModelCount'], 0);
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'passed');
    expect(reportingGate['judgeOverheadStatus'], 'present');
    expect(reportingGate['judgeOverheadEvaluationCount'], 1);
    expect(reportingGate['artifactBundleStatus'], 'present');
    expect(reportingGate['artifactBundleRunIdStatus'], 'present');
    expect(reportingGate['artifactBundleRunIdInLeaderboardSource'], true);
    expect(reportingGate['artifactCount'], 4);
    expect(reportingGate['artifactBundleEvaluationCount'], 4);
    expect(reportingGate['manifestPopulationSummaryStatus'], 'present');
    expect(reportingGate['manifestTaskCountStatus'], 'present');
    expect(reportingGate['manifestProviderCountStatus'], 'present');
    expect(reportingGate['manifestModelCountStatus'], 'present');
    expect(reportingGate['manifestTaskCount'], 1);
    expect(reportingGate['manifestProviderCount'], 1);
    expect(reportingGate['manifestModelCount'], 1);
    expect(reportingGate['manifestDistinctTaskCount'], 1);
    expect(reportingGate['manifestDistinctProviderCount'], 1);
    expect(reportingGate['manifestDistinctModelCount'], 1);
    expect(reportingGate['manifestPopulationCountMismatchCount'], 0);
    expect(reportingGate['manifestEvaluatorIdCount'], 2);
    expect(reportingGate['invalidManifestEvaluatorIdCount'], 0);
    expect(reportingGate['duplicateManifestEvaluatorIdCount'], 0);
    expect(reportingGate['artifactBundleWarningCount'], 0);
    expect(reportingGate['artifactChecksumsStatus'], 'present');
    expect(reportingGate['artifactChecksumSchemaVersion'], 1);
    expect(reportingGate['artifactChecksumFileCount'], 8);
    expect(reportingGate['manifestChecksumStatus'], 'present');
    expect(reportingGate['manifestChecksumDigestStatus'], 'matched');
    expect(reportingGate['checksumsPathMatchesInput'], true);
    expect(reportingGate['coveredArtifactChecksumCount'], 4);
    expect(reportingGate['missingArtifactChecksumCount'], 0);
    expect(reportingGate['coveredStandardChecksumCount'], 4);
    expect(reportingGate['missingStandardChecksumCount'], 0);
    expect(reportingGate['verifiedStandardChecksumCount'], 3);
    expect(reportingGate['missingStandardInputCount'], 0);
    expect(reportingGate['mismatchedStandardChecksumCount'], 0);
    expect(reportingGate['standardInputPathMismatchCount'], 0);
    expect(reportingGate['verifiedArtifactFileCount'], 4);
    expect(reportingGate['missingArtifactFileCount'], 0);
    expect(reportingGate['mismatchedArtifactFileByteCount'], 0);
    expect(reportingGate['mismatchedArtifactFileDigestCount'], 0);
    expect(reportingGate['unexpectedChecksumPathCount'], 0);
    expect(reportingGate['unsafeChecksumPathCount'], 0);
    expect(reportingGate['absoluteChecksumPathCount'], 0);
    expect(reportingGate['parentChecksumPathCount'], 0);
    expect(reportingGate['privateChecksumPathCount'], 0);
    expect(reportingGate['outsideArtifactRootChecksumPathCount'], 0);
    expect(reportingGate['artifactResultsCsvStatus'], 'present');
    expect(reportingGate['resultsCsvTaskRunCount'], 2);
    expect(reportingGate['missingResultsCsvHeaderCount'], 0);
    expect(reportingGate['invalidResultsCsvTaskRunCount'], 0);
    expect(reportingGate['duplicateResultsCsvTaskRunCount'], 0);
    expect(reportingGate['missingResultsCsvTaskRunCount'], 0);
    expect(reportingGate['extraResultsCsvTaskRunCount'], 0);
    expect(reportingGate['mismatchedResultsCsvRunResultsCount'], 0);
    expect(reportingGate['invalidResultsCsvOutcomeCount'], 0);
    expect(reportingGate['artifactReportMarkdownStatus'], 'present');
    expect(reportingGate['reportMarkdownDeclaredTaskRunCount'], 2);
    expect(reportingGate['reportMarkdownTaskRunCount'], 2);
    expect(reportingGate['missingReportMarkdownSectionCount'], 0);
    expect(reportingGate['missingReportMarkdownColumnCount'], 0);
    expect(reportingGate['invalidReportMarkdownTaskRunCount'], 0);
    expect(reportingGate['duplicateReportMarkdownTaskRunCount'], 0);
    expect(reportingGate['missingReportMarkdownTaskRunCount'], 0);
    expect(reportingGate['extraReportMarkdownTaskRunCount'], 0);
    expect(reportingGate['mismatchedReportMarkdownRunResultsCount'], 0);
    expect(reportingGate['invalidReportMarkdownOutcomeCount'], 0);
    expect(reportingGate['runResultsStatus'], 'present');
    expect(reportingGate['runResultsSchemaVersion'], 1);
    expect(reportingGate['runResultsRunIdMatchesManifest'], true);
    expect(reportingGate['runResultsRunMetadataStatus'], 'present');
    expect(reportingGate['runResultsRunNameMatchesManifest'], true);
    expect(reportingGate['runResultsRunStartedAtMatchesManifest'], true);
    expect(reportingGate['runResultsRunCompletedAtMatchesManifest'], true);
    expect(reportingGate['mismatchedRunResultsRunMetadataFieldCount'], 0);
    expect(reportingGate['runResultsTaskRunCount'], 2);
    expect(reportingGate['runResultsEvaluationCount'], 4);
    expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
    expect(reportingGate['runResultsEvaluatorIdCount'], 2);
    expect(reportingGate['runResultsEvaluatorIdsMatchManifest'], true);
    expect(reportingGate['missingRunResultsEvaluatorIdCount'], 0);
    expect(reportingGate['extraRunResultsEvaluatorIdCount'], 0);
    expect(reportingGate['missingRunResultsTaskRunCount'], 0);
    expect(reportingGate['extraRunResultsTaskRunCount'], 0);
    expect(reportingGate['mismatchedRunResultsTaskRunCount'], 0);
    expect(reportingGate['mismatchedRunResultsTaskRunRunIdCount'], 0);
    expect(reportingGate['mismatchedRunResultsTrialOutcomeCount'], 0);
    expect(reportingGate['invalidRunResultsTrialOutcomeCount'], 0);
    expect(reportingGate['invalidRunResultsTimingTaskRunCount'], 0);
    expect(reportingGate['invalidRunResultsTokenUsageTaskRunCount'], 0);
    expect(reportingGate['missingRunResultsEvaluationTaskRunCount'], 0);
    expect(reportingGate['invalidRunResultsEvaluationCount'], 0);
    expect(reportingGate['invalidRunResultsEvaluationRationaleCount'], 0);
    expect(reportingGate['invalidRunResultsEvaluationDetailsMetadataCount'], 0);
    expect(reportingGate['invalidRunResultsBlockedEvaluationMetadataCount'], 0);
    expect(reportingGate['invalidRunResultsJudgeOverheadMetadataCount'], 0);
    expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
    expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
    expect(reportingGate['invalidRunResultsTaskRunCount'], 0);
    expect(reportingGate['invalidRunResultsTaskRunModelIdentityCount'], 0);
    expect(reportingGate['duplicateRunResultsTaskRunCount'], 0);
    expect(reportingGate['missingRunResultsArtifactCount'], 0);
    expect(reportingGate['extraRunResultsArtifactCount'], 0);
    expect(reportingGate['mismatchedRunResultsArtifactCount'], 0);
    expect(reportingGate['invalidRunResultsArtifactMetadataCount'], 0);
    expect(reportingGate['mismatchedRunResultsArtifactByteCount'], 0);
    expect(reportingGate['mismatchedRunResultsArtifactDigestCount'], 0);
    expect(reportingGate['unsafeArtifactPathCount'], 0);
    expect(reportingGate['absoluteArtifactPathCount'], 0);
    expect(reportingGate['parentArtifactPathCount'], 0);
    expect(reportingGate['privateArtifactPathCount'], 0);
    expect(reportingGate['outsideArtifactRootPathCount'], 0);
    expect(reportingGate['artifactManifestMetadataStatus'], 'present');
    expect(reportingGate['manifestRunMetadataStatus'], 'present');
    expect(reportingGate['manifestRunNameStatus'], 'present');
    expect(reportingGate['manifestRunStartedAtStatus'], 'present');
    expect(reportingGate['manifestRunCompletedAtStatus'], 'present');
    expect(reportingGate['manifestRunDurationStatus'], 'valid');
    expect(
      reportingGate['manifestRunCompletedBeforeGeneratedAtStatus'],
      'valid',
    );
    expect(reportingGate['manifestOutcomeSummaryStatus'], 'present');
    expect(reportingGate['manifestPassSummaryStatus'], 'present');
    expect(reportingGate['manifestFailureSummaryStatus'], 'present');
    expect(reportingGate['manifestPassSummaryMismatchCount'], 0);
    expect(reportingGate['manifestFailureSummaryMismatchCount'], 0);
    expect(reportingGate['manifestGeneratedAtStatus'], 'present');
    expect(reportingGate['manifestAppVersionStatus'], 'present');
    expect(reportingGate['manifestDriftSchemaVersionStatus'], 'present');
    expect(reportingGate['manifestExportToolStatus'], 'present');
    expect(reportingGate['manifestExportEnvironmentStatus'], 'present');
    expect(reportingGate['manifestExportEnvironmentGitStatus'], 'clean');
    expect(reportingGate['artifactManifestProvenanceStatus'], 'present');
    expect(reportingGate['manifestProvenanceRunIdMatchesManifest'], true);
    expect(reportingGate['manifestProvenanceSandboxStatus'], 'enforced');
    expect(reportingGate['manifestProvenanceSandboxBackend'], 'test-sandbox');
    expect(
      reportingGate['manifestProvenanceTaskExecutionPolicyStatus'],
      'present',
    );
    expect(
      reportingGate['manifestProvenanceNetworkDisabledTaskPolicyStatus'],
      'disabled',
    );
    expect(
      reportingGate['manifestProvenanceTaskResourceLimitStatus'],
      'present',
    );
    expect(reportingGate['manifestProvenanceSdkVersionStatus'], 'present');
    expect(
      reportingGate['manifestProvenanceDependencySnapshotStatus'],
      'present',
    );
    expect(reportingGate['manifestProvenancePricingRegistryStatus'], 'present');
    expect(reportingGate['missingResponseArtifactCount'], 0);
    expect(reportingGate['missingAgenticPatchArtifactCount'], 0);
    expect(reportingGate['missingAgenticHarnessMetadataCount'], 0);
    expect(reportingGate['missingRunResultsAgenticHarnessMetadataCount'], 0);
    expect(reportingGate['mismatchedRunResultsAgenticHarnessMetadataCount'], 0);
    expect(reportingGate['missingLeaderboardTrialSummaryTaskRunCount'], 0);
    expect(reportingGate['extraLeaderboardTrialSummaryTaskRunCount'], 0);
    expect(reportingGate['invalidArtifactBundleTaskRunCount'], 0);
    expect(reportingGate['invalidArtifactBundleTaskRunModelIdentityCount'], 0);
    expect(reportingGate['duplicateArtifactBundleTaskRunCount'], 0);
    expect(reportingGate['unknownArtifactKindCount'], 0);
    expect(reportingGate['duplicateArtifactReferenceCount'], 0);
    expect(reportingGate['privacyStatus'], 'passed');
    expect(reportingGate['modelIdentityStatus'], 'present');
    expect(reportingGate['invalidModelIdentityCount'], 0);
    expect(reportingGate['invalidModelIdentityModelRowCount'], 0);
    expect(reportingGate['invalidModelIdentityTaskModelCellCount'], 0);
    expect(reportingGate['invalidModelIdentityTrialSummaryCount'], 0);
    expect(reportingGate['trialSummaryCount'], 2);
    expect(reportingGate['missingPassAtKCount'], 0);
    expect(reportingGate['missingConfidenceIntervalCount'], 0);
    expect(reportingGate['inputFingerprintCount'], 13);
    final runs = provenance['runs']! as List<Object?>;
    final run = runs.single! as Map<String, Object?>;
    expect(run['generatedCodeSandbox'], {
      'status': 'enforced',
      'required': true,
      'enforced': true,
      'backend': 'test-sandbox',
    });
    expect(run['networkDisabledTaskPolicyStatus'], 'disabled');
    expect(run['taskResourceLimitStatus'], 'present');
    final audit = report['verifierAudit']! as Map<String, Object?>;
    expect(audit['hiddenVerifierDigestCount'], 1);
    expect(audit['tasksMissingHiddenVerifierDigests'], isEmpty);
    expect(audit['invalidHiddenVerifierDigestCount'], 0);
    expect(audit['tasksWithInvalidHiddenVerifierDigests'], isEmpty);
    expect(audit['releaseMetadata'], {
      'privateOfficialTaskCount': 1,
      'activeTaskCount': 1,
      'tasksMissingReleaseMetadata': <Object?>[],
      'tasksOutsidePrivateOfficialCorpus': <Object?>[],
      'retiredTasks': <Object?>[],
    });
    expect(audit['hiddenFlakeRuns'], {
      'minimumPerTask': 3,
      'min': 3,
      'max': 3,
      'total': 3,
      'tasksBelowMinimum': <Object?>[],
    });
    final negativeCases = audit['negativeCases']! as Map<String, Object?>;
    expect(negativeCases['total'], 3);
    expect(negativeCases['rejected'], 3);
    expect(negativeCases['accepted'], 0);
    expect(negativeCases['invalid'], 0);
    expect(negativeCases['malformedEvidenceCount'], 0);
    expect(negativeCases['unsupportedKindCount'], 0);
    expect(negativeCases['outcomeMismatchCount'], 0);
    expect(negativeCases['tasksMissingNegativeCases'], isEmpty);
    expect(negativeCases['tasksWithNegativeCaseEvidenceIssues'], isEmpty);
    final byKind = negativeCases['byKind']! as Map<String, Object?>;
    expect(byKind['noop'], {
      'total': 1,
      'rejected': 1,
      'accepted': 0,
      'invalid': 0,
      'publicRejected': 0,
      'hiddenRejected': 1,
    });
    final quality = audit['quality']! as Map<String, Object?>;
    expect(quality['falsePositiveCount'], 0);
    expect(quality['falseNegativeCount'], 0);
    expect(quality['disagreementCount'], 2);
    expect(quality['infrastructureErrorCount'], 0);
    expect(quality['flakeRunCount'], 3);
    expect(quality['flakeFailureCount'], 0);
    expect(quality['tasksMissingVerifierQualityAudit'], isEmpty);
    expect(audit['qualityConsistency'], {
      'requiredFieldIds': [
        'falsePositiveCount',
        'falseNegativeCount',
        'disagreementCount',
        'infrastructureErrorCount',
        'flakeRunCount',
        'flakeFailureCount',
        'negativeCaseCount',
        'acceptedNegativeCaseCount',
        'referencePublicFailureCount',
        'referenceHiddenFailureCount',
      ],
      'invalidFieldCount': 0,
      'mismatchCount': 0,
      'tasksWithVerifierQualityIssues': <Object?>[],
    });
    expect(audit['promptSafety'], {
      'presentCount': 1,
      'missingCount': 0,
      'failedCount': 0,
      'invalidPassedFlagCount': 0,
      'missingRequiredNegativeKindCount': 0,
      'promptSafeCheckMismatchCount': 0,
      'requiredKindCoverageMismatchCount': 0,
      'invalidKindCount': 0,
      'presentKindMismatchCount': 0,
      'missingKindMismatchCount': 0,
      'invalidComponentFieldCount': 0,
      'passedComputationMismatchCount': 0,
      'tasksMissingPromptSafety': <Object?>[],
      'tasksWithPromptSafetyIssues': <Object?>[],
    });
    expect(audit['admissionProvenance'], {
      'presentCount': 1,
      'missingCount': 0,
      'invalidToolCount': 0,
      'invalidEvaluatorCount': 0,
      'environmentPresentCount': 1,
      'environmentMissingCount': 0,
      'sdkVersionPresentCount': 1,
      'sdkVersionIncompleteCount': 0,
      'dependencySnapshotPresentCount': 1,
      'dependencySnapshotIncompleteCount': 0,
      'tasksWithAdmissionProvenanceIssues': <Object?>[],
    });
    expect(audit['taskExecutionPolicy'], {
      'presentCount': 1,
      'missingCount': 0,
      'incompleteCount': 0,
      'networkDisabledCount': 1,
      'networkEnabledCount': 0,
      'resourceLimitPresentCount': 1,
      'resourceLimitIncompleteCount': 0,
      'tasksWithExecutionPolicyIssues': <Object?>[],
    });
  });

  test(
    'validates aggregate-compatible release with multiple artifact bundle roots',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_multi_artifact_bundle_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final taskBundle = Directory(p.join(taskQaDir.path, 'tasks', 'task.a'));
      final taskBundleDigest = await _writeReleaseTaskBundle(taskBundle);
      final reportPath = p.join(taskBundle.path, 'qa', 'admission_report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_multiRunLeaderboardJson()));
      await File(taskQaSummaryPath).writeAsString(
        _prettyJson(
          _taskQaSummaryJson(
            reportPath: p
                .relative(reportPath, from: taskQaDir.path)
                .replaceAll('\\', '/'),
          ),
        ),
      );
      await File(reportPath).writeAsString(
        _prettyJson(_taskQaReportJson(taskBundleDigest: taskBundleDigest)),
      );
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath, runIds: const ['run-1', 'run-2']);
      final firstBundleRoot = p.join(tmp.path, 'bundle_run_1');
      final secondBundleRoot = p.join(tmp.path, 'bundle_run_2');
      await _writeCompleteArtifactBundle(firstBundleRoot, runId: 'run-1');
      await _writeCompleteArtifactBundle(secondBundleRoot, runId: 'run-2');
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stdoutLines = <String>[];
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-bundle-root',
          firstBundleRoot,
          '--artifact-bundle-root',
          secondBundleRoot,
          '--out',
          outPath,
          '--release-id',
          '2026-06-ready-multi-bundle',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 3, 16),
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(stdoutLines.single, contains('"status":"ready"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      expect(report['status'], 'ready');
      expect(report['blockers'], isEmpty);
      final inputs = report['inputs']! as Map<String, Object?>;
      final artifactBundleInputs = inputs['artifactBundles']! as List<Object?>;
      expect(artifactBundleInputs.length, 2);
      _expectFingerprint(
        (artifactBundleInputs.first!
                as Map<String, Object?>)['artifactManifest']!
            as Map<String, Object?>,
        path: 'manifest.json',
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'present');
      expect(artifactBundle['bundleCount'], 2);
      expect(artifactBundle['runId'], null);
      expect(artifactBundle['runIds'], ['run-1', 'run-2']);
      expect(artifactBundle['runIdStatus'], 'present');
      expect(artifactBundle['runIdInLeaderboardSource'], true);
      expect(artifactBundle['missingSourceRunBundleCount'], 0);
      expect(artifactBundle['extraSourceRunBundleCount'], 0);
      expect(artifactBundle['duplicateBundleRunIdCount'], 0);
      expect(artifactBundle['taskRunCount'], 4);
      expect(artifactBundle['agenticTaskRunCount'], 4);
      expect(artifactBundle['evaluationCount'], 8);
      expect(artifactBundle['artifactCount'], 8);
      expect(artifactBundle['artifactKindCounts'], {'patch': 4, 'response': 4});
      expect(artifactBundle['warningCount'], 0);
      expect(artifactBundle['warningCodeCounts'], <String, Object?>{});
      expect(artifactBundle['checksumFileCount'], 16);
      expect(artifactBundle['coveredArtifactChecksumCount'], 8);
      expect(artifactBundle['missingArtifactChecksumCount'], 0);
      expect(artifactBundle['verifiedStandardChecksumCount'], 6);
      expect(artifactBundle['verifiedArtifactFileCount'], 8);
      expect(artifactBundle['resultsCsvTaskRunCount'], 4);
      expect(artifactBundle['reportMarkdownTaskRunCount'], 4);
      expect(artifactBundle['runResultsTaskRunCount'], 4);
      expect(artifactBundle['runResultsEvaluationCount'], 8);
      expect(artifactBundle['runResultsRunIdMatchesManifest'], true);
      expect(artifactBundle['runResultsRunMetadataStatus'], 'present');
      expect(artifactBundle['runResultsEvaluatorIdsMatchManifest'], true);
      expect(artifactBundle['missingResponseArtifactCount'], 0);
      expect(artifactBundle['missingAgenticPatchArtifactCount'], 0);
      expect(artifactBundle['missingAgenticHarnessMetadataCount'], 0);
      expect(artifactBundle['missingLeaderboardTrialSummaryTaskRunCount'], 0);
      expect(artifactBundle['extraLeaderboardTrialSummaryTaskRunCount'], 0);
      final bundles = artifactBundle['bundles']! as List<Object?>;
      expect(
        bundles,
        containsAll([
          containsPair('runId', 'run-1'),
          containsPair('runId', 'run-2'),
        ]),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'passed');
      expect(reportingGate['artifactBundleStatus'], 'present');
      expect(reportingGate['artifactCount'], 8);
      expect(reportingGate['artifactBundleEvaluationCount'], 8);
      expect(
        reportingGate['artifactBundleWarningCodeCounts'],
        <String, Object?>{},
      );
      expect(reportingGate['missingLeaderboardTrialSummaryTaskRunCount'], 0);
      expect(reportingGate['extraLeaderboardTrialSummaryTaskRunCount'], 0);
    },
  );

  test(
    'aggregates artifact bundle warning code counts across run bundles',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_multi_artifact_bundle_warnings_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_multiRunLeaderboardJson()));
      await File(taskQaSummaryPath).writeAsString(
        _prettyJson(
          _taskQaSummaryJson(
            reportPath: p
                .relative(reportPath, from: taskQaDir.path)
                .replaceAll('\\', '/'),
          ),
        ),
      );
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath, runIds: const ['run-1', 'run-2']);
      final firstBundleRoot = p.join(tmp.path, 'bundle_run_1');
      final secondBundleRoot = p.join(tmp.path, 'bundle_run_2');
      await _writeCompleteArtifactBundle(
        firstBundleRoot,
        runId: 'run-1',
        warningCount: 1,
        warningCode: 'missing_patch_text',
      );
      await _writeCompleteArtifactBundle(
        secondBundleRoot,
        runId: 'run-2',
        warningCount: 2,
        warningCode: 'missing_response_text',
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-bundle-root',
          firstBundleRoot,
          '--artifact-bundle-root',
          secondBundleRoot,
          '--out',
          outPath,
          '--release-id',
          '2026-06-multi-bundle-warnings-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['warningCount'], 3);
      expect(artifactBundle['warningCodeCounts'], {
        'missing_patch_text': 1,
        'missing_response_text': 2,
      });
      final bundles = artifactBundle['bundles']! as List<Object?>;
      expect(
        bundles,
        contains(
          allOf(
            containsPair('runId', 'run-1'),
            containsPair('warningCodeCounts', {'missing_patch_text': 1}),
          ),
        ),
      );
      expect(
        bundles,
        contains(
          allOf(
            containsPair('runId', 'run-2'),
            containsPair('warningCodeCounts', {'missing_response_text': 2}),
          ),
        ),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleWarningCount'], 3);
      expect(reportingGate['artifactBundleWarningCodeCounts'], {
        'missing_patch_text': 1,
        'missing_response_text': 2,
      });
    },
  );

  test('blocks report when artifact bundle manifest is incomplete', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_bundle_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(artifactManifestPath).writeAsString(
      _prettyJson(
        _artifactManifestJson(includeSecondPatch: false, warningCount: 1),
      ),
    );
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          includeSecondPatch: false,
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-bundle-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Run artifact bundle manifest contains 1 warning(s).'),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle manifest is missing patch artifacts for '
        '1 agentic task run(s).',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['warningCount'], 1);
    expect(artifactBundle['warningCodeCounts'], {'test_bundle_warning': 1});
    expect(artifactBundle['missingAgenticPatchArtifactCount'], 1);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['artifactBundleWarningCount'], 1);
    expect(reportingGate['artifactBundleWarningCodeCounts'], {
      'test_bundle_warning': 1,
    });
    expect(reportingGate['missingAgenticPatchArtifactCount'], 1);
  });

  test(
    'blocks report when artifact bundle manifest metadata is incomplete',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_manifest_metadata_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(
          _artifactManifestJson(
            generatedAt: 'not-a-date',
            appVersion: 'unknown',
            driftSchemaVersion: 0,
            exportTool: const {'name': 'other_exporter', 'version': '1'},
            exportEnvironment: _artifactManifestEnvironmentJson(
              dartVersion: 'unknown',
              flutterVersion: 'unknown',
              gitDirty: true,
              hostPlatform: '',
              locale: '',
              operatingSystemVersion: '',
            ),
          ),
        ),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-manifest-metadata-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 19),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest generatedAt timestamp is invalid.',
        ),
      );
      expect(
        blockers,
        contains('Run artifact bundle manifest app version is unknown.'),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest drift schema version is missing.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest export tool metadata is unsupported.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest export environment metadata is incomplete.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest export environment records a dirty git worktree.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['manifestMetadataStatus'], 'incomplete');
      expect(artifactBundle['manifestGeneratedAtStatus'], 'invalid');
      expect(artifactBundle['manifestAppVersionStatus'], 'unknown');
      expect(artifactBundle['manifestDriftSchemaVersionStatus'], 'missing');
      expect(artifactBundle['manifestExportToolStatus'], 'unsupported');
      expect(artifactBundle['manifestExportEnvironmentStatus'], 'incomplete');
      expect(artifactBundle['manifestExportEnvironmentGitStatus'], 'dirty');
      expect(artifactBundle['manifestProvenanceStatus'], 'present');
      expect(artifactBundle['runResultsStatus'], 'present');
      expect(artifactBundle['resultsCsvStatus'], 'present');
      expect(artifactBundle['reportMarkdownStatus'], 'present');
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactManifestMetadataStatus'], 'incomplete');
      expect(reportingGate['manifestGeneratedAtStatus'], 'invalid');
      expect(reportingGate['manifestAppVersionStatus'], 'unknown');
      expect(reportingGate['manifestDriftSchemaVersionStatus'], 'missing');
      expect(reportingGate['manifestExportToolStatus'], 'unsupported');
      expect(reportingGate['manifestExportEnvironmentStatus'], 'incomplete');
      expect(reportingGate['manifestExportEnvironmentGitStatus'], 'dirty');
    },
  );

  test(
    'blocks report when artifact bundle manifest metadata is invalid',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_manifest_invalid_metadata_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(
          _artifactManifestJson(
            generatedAt: '2026-06-05T00:00:00.000Z',
            appVersion: 'test',
            exportTool: const {
              'name': 'dart_arena_export_bundle',
              'version': 'dev',
            },
            exportEnvironment: _artifactManifestEnvironmentJson(
              gitCommit: 'not-a-sha',
            ),
          ),
        ),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-manifest-invalid-metadata-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 19),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest generatedAt timestamp is future.',
        ),
      );
      expect(
        blockers,
        contains('Run artifact bundle manifest app version is invalid.'),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest export tool metadata is invalid.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest export environment git metadata is invalid.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['manifestMetadataStatus'], 'incomplete');
      expect(artifactBundle['manifestGeneratedAtStatus'], 'future');
      expect(artifactBundle['manifestAppVersionStatus'], 'invalid');
      expect(artifactBundle['manifestDriftSchemaVersionStatus'], 'present');
      expect(artifactBundle['manifestExportToolStatus'], 'invalid');
      expect(artifactBundle['manifestExportEnvironmentStatus'], 'present');
      expect(artifactBundle['manifestExportEnvironmentGitStatus'], 'invalid');
      expect(artifactBundle['manifestProvenanceStatus'], 'present');
      expect(artifactBundle['runResultsStatus'], 'present');
      expect(artifactBundle['resultsCsvStatus'], 'present');
      expect(artifactBundle['reportMarkdownStatus'], 'present');
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactManifestMetadataStatus'], 'incomplete');
      expect(reportingGate['manifestGeneratedAtStatus'], 'future');
      expect(reportingGate['manifestAppVersionStatus'], 'invalid');
      expect(reportingGate['manifestDriftSchemaVersionStatus'], 'present');
      expect(reportingGate['manifestExportToolStatus'], 'invalid');
      expect(reportingGate['manifestExportEnvironmentStatus'], 'present');
      expect(reportingGate['manifestExportEnvironmentGitStatus'], 'invalid');
    },
  );

  test(
    'blocks report when artifact bundle manifest run metadata is invalid',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_manifest_run_metadata_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(
          _artifactManifestJson(
            generatedAt: '2026-06-03T11:50:00.000Z',
            runName: '',
            runStartedAt: '2026-06-03T12:30:00.000Z',
            runCompletedAt: '2026-06-03T12:00:00.000Z',
          ),
        ),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-manifest-run-metadata-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 19),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Run artifact bundle manifest run name is missing.'),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest run completedAt timestamp is before startedAt.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest run completedAt timestamp is after generatedAt.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['manifestMetadataStatus'], 'present');
      expect(artifactBundle['manifestRunMetadataStatus'], 'incomplete');
      expect(artifactBundle['manifestRunNameStatus'], 'missing');
      expect(artifactBundle['manifestRunStartedAtStatus'], 'present');
      expect(artifactBundle['manifestRunCompletedAtStatus'], 'present');
      expect(artifactBundle['manifestRunDurationStatus'], 'invalid');
      expect(
        artifactBundle['manifestRunCompletedBeforeGeneratedAtStatus'],
        'invalid',
      );
      expect(artifactBundle['manifestProvenanceStatus'], 'present');
      expect(artifactBundle['runResultsStatus'], 'present');
      expect(artifactBundle['resultsCsvStatus'], 'present');
      expect(artifactBundle['reportMarkdownStatus'], 'present');
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactManifestMetadataStatus'], 'present');
      expect(reportingGate['manifestRunMetadataStatus'], 'incomplete');
      expect(reportingGate['manifestRunNameStatus'], 'missing');
      expect(reportingGate['manifestRunStartedAtStatus'], 'present');
      expect(reportingGate['manifestRunCompletedAtStatus'], 'present');
      expect(reportingGate['manifestRunDurationStatus'], 'invalid');
      expect(
        reportingGate['manifestRunCompletedBeforeGeneratedAtStatus'],
        'invalid',
      );
    },
  );

  test(
    'blocks report when artifact bundle manifest outcome summaries mismatch run results',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_manifest_summary_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(
          _artifactManifestJson(
            passSummary: const {
              'primaryPassTrue': 1,
              'primaryPassFalse': 1,
              'primaryPassUnknown': 0,
              'evaluationPassCount': 3,
              'evaluationFailCount': 1,
            },
            failureSummary: const {'pass': 1, 'public_tests_failed': 1},
          ),
        ),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-manifest-summary-mismatch-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 19),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest pass summary mismatches run results in 4 field(s).',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest failure summary mismatches run results in 2 tag(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['manifestMetadataStatus'], 'present');
      expect(artifactBundle['manifestRunMetadataStatus'], 'present');
      expect(artifactBundle['manifestOutcomeSummaryStatus'], 'incomplete');
      expect(artifactBundle['manifestPassSummaryStatus'], 'present');
      expect(artifactBundle['manifestFailureSummaryStatus'], 'present');
      expect(artifactBundle['manifestPassSummaryMismatchCount'], 4);
      expect(artifactBundle['manifestFailureSummaryMismatchCount'], 2);
      expect(artifactBundle['manifestProvenanceStatus'], 'present');
      expect(artifactBundle['runResultsStatus'], 'present');
      expect(artifactBundle['resultsCsvStatus'], 'present');
      expect(artifactBundle['reportMarkdownStatus'], 'present');
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactManifestMetadataStatus'], 'present');
      expect(reportingGate['manifestRunMetadataStatus'], 'present');
      expect(reportingGate['manifestOutcomeSummaryStatus'], 'incomplete');
      expect(reportingGate['manifestPassSummaryStatus'], 'present');
      expect(reportingGate['manifestFailureSummaryStatus'], 'present');
      expect(reportingGate['manifestPassSummaryMismatchCount'], 4);
      expect(reportingGate['manifestFailureSummaryMismatchCount'], 2);
    },
  );

  test(
    'blocks report when artifact bundle manifest population counts mismatch task runs',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_manifest_population_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(
          _artifactManifestJson(
            countOverrides: const {
              'taskCount': 2,
              'providerCount': 2,
              'modelCount': 2,
            },
          ),
        ),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-manifest-population-mismatch-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 20),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest task count does not match taskRuns.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest provider count does not match taskRuns.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest model count does not match taskRuns.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['manifestPopulationSummaryStatus'], 'incomplete');
      expect(artifactBundle['manifestTaskCountStatus'], 'mismatched');
      expect(artifactBundle['manifestProviderCountStatus'], 'mismatched');
      expect(artifactBundle['manifestModelCountStatus'], 'mismatched');
      expect(artifactBundle['manifestTaskCount'], 2);
      expect(artifactBundle['manifestProviderCount'], 2);
      expect(artifactBundle['manifestModelCount'], 2);
      expect(artifactBundle['manifestDistinctTaskCount'], 1);
      expect(artifactBundle['manifestDistinctProviderCount'], 1);
      expect(artifactBundle['manifestDistinctModelCount'], 1);
      expect(artifactBundle['manifestPopulationCountMismatchCount'], 3);
      expect(artifactBundle['manifestMetadataStatus'], 'present');
      expect(artifactBundle['manifestRunMetadataStatus'], 'present');
      expect(artifactBundle['manifestOutcomeSummaryStatus'], 'present');
      expect(artifactBundle['manifestProvenanceStatus'], 'present');
      expect(artifactBundle['runResultsStatus'], 'present');
      expect(artifactBundle['resultsCsvStatus'], 'present');
      expect(artifactBundle['reportMarkdownStatus'], 'present');
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['manifestPopulationSummaryStatus'], 'incomplete');
      expect(reportingGate['manifestTaskCountStatus'], 'mismatched');
      expect(reportingGate['manifestProviderCountStatus'], 'mismatched');
      expect(reportingGate['manifestModelCountStatus'], 'mismatched');
      expect(reportingGate['manifestTaskCount'], 2);
      expect(reportingGate['manifestProviderCount'], 2);
      expect(reportingGate['manifestModelCount'], 2);
      expect(reportingGate['manifestDistinctTaskCount'], 1);
      expect(reportingGate['manifestDistinctProviderCount'], 1);
      expect(reportingGate['manifestDistinctModelCount'], 1);
      expect(reportingGate['manifestPopulationCountMismatchCount'], 3);
    },
  );

  test('blocks report when artifact bundle manifest provenance is incomplete', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_manifest_provenance_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(artifactManifestPath).writeAsString(
      _prettyJson(
        _artifactManifestJson(
          provenanceSandboxEnforced: false,
          includeProvenanceTaskExecutionPolicy: false,
          includeProvenanceSdkVersions: false,
          includeProvenanceDependencySnapshot: false,
          includeProvenancePricingRegistry: false,
        ),
      ),
    );
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-manifest-provenance-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 18),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle manifest provenance does not record generated-code sandbox enforcement.',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle manifest provenance has incomplete task execution policy.',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle manifest provenance has incomplete network-disabled task policy.',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle manifest provenance has incomplete or unenforced task resource limits.',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle manifest provenance has incomplete SDK versions.',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle manifest provenance has incomplete dependency lockfile snapshot.',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle manifest provenance has incomplete pricing registry.',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['manifestProvenanceStatus'], 'incomplete');
    expect(artifactBundle['manifestProvenanceRunId'], 'run-1');
    expect(artifactBundle['manifestProvenanceRunIdMatchesManifest'], true);
    expect(artifactBundle['manifestProvenanceSandboxStatus'], 'not_enforced');
    expect(artifactBundle['manifestProvenanceSandboxBackend'], null);
    expect(
      artifactBundle['manifestProvenanceTaskExecutionPolicyStatus'],
      'incomplete',
    );
    expect(
      artifactBundle['manifestProvenanceNetworkDisabledTaskPolicyStatus'],
      'incomplete',
    );
    expect(
      artifactBundle['manifestProvenanceTaskResourceLimitStatus'],
      'incomplete',
    );
    expect(artifactBundle['manifestProvenanceSdkVersionStatus'], 'incomplete');
    expect(
      artifactBundle['manifestProvenanceDependencySnapshotStatus'],
      'incomplete',
    );
    expect(
      artifactBundle['manifestProvenancePricingRegistryStatus'],
      'incomplete',
    );
    expect(artifactBundle['runResultsStatus'], 'present');
    expect(artifactBundle['resultsCsvStatus'], 'present');
    expect(artifactBundle['reportMarkdownStatus'], 'present');
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['artifactManifestProvenanceStatus'], 'incomplete');
    expect(reportingGate['manifestProvenanceSandboxStatus'], 'not_enforced');
    expect(
      reportingGate['manifestProvenanceTaskExecutionPolicyStatus'],
      'incomplete',
    );
    expect(
      reportingGate['manifestProvenanceNetworkDisabledTaskPolicyStatus'],
      'incomplete',
    );
    expect(
      reportingGate['manifestProvenanceTaskResourceLimitStatus'],
      'incomplete',
    );
    expect(reportingGate['manifestProvenanceSdkVersionStatus'], 'incomplete');
    expect(
      reportingGate['manifestProvenanceDependencySnapshotStatus'],
      'incomplete',
    );
    expect(
      reportingGate['manifestProvenancePricingRegistryStatus'],
      'incomplete',
    );
  });

  test(
    'blocks report when artifact bundle manifest duplicates task runs',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_duplicate_task_run_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(_artifactManifestJson(duplicateFirstTaskRun: true)),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-duplicate-task-run-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest has 1 duplicate task run id(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['taskRunCount'], 3);
      expect(artifactBundle['duplicateTaskRunCount'], 1);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['duplicateArtifactBundleTaskRunCount'], 1);
    },
  );

  test(
    'blocks report when artifact bundle task run metadata is invalid',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_invalid_task_run_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(_artifactManifestJson(omitSecondTaskMetadata: true)),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        omitSecondTaskMetadata: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-invalid-task-run-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Run artifact bundle manifest has 1 invalid task run(s).'),
      );
      expect(
        blockers,
        contains('Run artifact bundle run results have 1 invalid task run(s).'),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['invalidTaskRunCount'], 1);
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['invalidRunResultsTaskRunCount'], 1);
      expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['invalidArtifactBundleTaskRunCount'], 1);
      expect(reportingGate['invalidRunResultsTaskRunCount'], 1);
    },
  );

  test(
    'blocks report when artifact bundle model identity metadata is invalid',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_model_identity_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);

      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      final artifactManifest = _artifactManifestJson();
      final manifestTaskRuns = (artifactManifest['taskRuns']! as List<Object?>)
          .cast<Map<String, Object?>>();
      manifestTaskRuns.first['baseModelId'] = 'gpt-4';
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(artifactManifest));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);

      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final runResultsFile = File(standardBundleFiles['run_results.v1.json']!);
      await _writeRunResultsFile(runResultsFile.path);
      final runResults =
          jsonDecode(await runResultsFile.readAsString())
              as Map<String, Object?>;
      final runResultTaskRuns = (runResults['taskRuns']! as List<Object?>)
          .cast<Map<String, Object?>>();
      runResultTaskRuns.first['baseModelId'] = 'gpt-4';
      await runResultsFile.writeAsString(_prettyJson(runResults));

      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-model-identity-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 4, 30),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest has 1 task run(s) with invalid model identity metadata.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 1 task run(s) with invalid model identity metadata.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['invalidTaskRunModelIdentityCount'], 1);
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['invalidRunResultsTaskRunModelIdentityCount'], 1);
      expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(
        reportingGate['invalidArtifactBundleTaskRunModelIdentityCount'],
        1,
      );
      expect(reportingGate['invalidRunResultsTaskRunModelIdentityCount'], 1);
    },
  );

  test('blocks report when artifact bundle run ids mismatch', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_run_id_mismatch_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    await _writeRunResultsFile(
      standardBundleFiles['run_results.v1.json']!,
      runId: 'other-run',
    );
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-run-id-mismatch-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 5),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle run results run id does not match the manifest.',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['runId'], 'run-1');
    expect(artifactBundle['runResultsRunId'], 'other-run');
    expect(artifactBundle['runResultsRunIdMatchesManifest'], false);
    expect(artifactBundle['runResultsStatus'], 'incomplete');
    expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
    expect(artifactBundle['mismatchedRunResultsArtifactCount'], 0);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['runResultsRunIdMatchesManifest'], false);
  });

  test(
    'blocks report when run results run metadata mismatches manifest',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_run_results_metadata_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        runName: 'Different release run',
        runStartedAt: '2026-06-03T10:59:00.000Z',
        runCompletedAt: '2026-06-03T11:54:00.000Z',
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-run-results-metadata-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 21),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results run metadata mismatches manifest in 3 field(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['runResultsRunIdMatchesManifest'], true);
      expect(artifactBundle['runResultsRunMetadataStatus'], 'mismatched');
      expect(artifactBundle['runResultsRunNameMatchesManifest'], false);
      expect(artifactBundle['runResultsRunStartedAtMatchesManifest'], false);
      expect(artifactBundle['runResultsRunCompletedAtMatchesManifest'], false);
      expect(artifactBundle['mismatchedRunResultsRunMetadataFieldCount'], 3);
      expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
      expect(artifactBundle['mismatchedRunResultsArtifactCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsRunMetadataStatus'], 'mismatched');
      expect(reportingGate['runResultsRunNameMatchesManifest'], false);
      expect(reportingGate['runResultsRunStartedAtMatchesManifest'], false);
      expect(reportingGate['runResultsRunCompletedAtMatchesManifest'], false);
      expect(reportingGate['mismatchedRunResultsRunMetadataFieldCount'], 3);
    },
  );

  test(
    'blocks report when artifact bundle run is not in leaderboard source',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_source_run_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson(runId: 'other-run')));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        runId: 'other-run',
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-source-run-mismatch-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 6),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest run id is not listed in leaderboard source run ids.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runId'], 'other-run');
      expect(artifactBundle['runIdInLeaderboardSource'], false);
      expect(artifactBundle['runResultsRunId'], 'other-run');
      expect(artifactBundle['runResultsRunIdMatchesManifest'], true);
      expect(artifactBundle['runResultsStatus'], 'present');
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactBundleRunIdInLeaderboardSource'], false);
      expect(reportingGate['runResultsRunIdMatchesManifest'], true);
    },
  );

  test('blocks report when run results task run rows mismatch run id', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_row_run_id_mismatch_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    await _writeRunResultsFile(
      standardBundleFiles['run_results.v1.json']!,
      secondTaskRunRowRunId: 'other-run',
    );
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-row-run-id-mismatch-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 7),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle run results have 1 task run(s) with missing or mismatched run id.',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['runResultsStatus'], 'incomplete');
    expect(artifactBundle['mismatchedRunResultsTaskRunRunIdCount'], 1);
    expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
    expect(artifactBundle['missingLeaderboardTrialSummaryTaskRunCount'], 0);
    expect(artifactBundle['extraLeaderboardTrialSummaryTaskRunCount'], 0);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['mismatchedRunResultsTaskRunRunIdCount'], 1);
  });

  test(
    'blocks report when run results agentic harness metadata is missing or mismatched',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_run_results_harness_metadata_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        firstHarnessId: 'other-harness',
        secondHarnessId: null,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-run-results-harness-metadata-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 8),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 1 agentic task run(s) with missing harness metadata.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle run results mismatch 1 manifest agentic harness metadata record(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['missingAgenticHarnessMetadataCount'], 0);
      expect(artifactBundle['missingRunResultsAgenticHarnessMetadataCount'], 1);
      expect(
        artifactBundle['mismatchedRunResultsAgenticHarnessMetadataCount'],
        1,
      );
      expect(artifactBundle['invalidRunResultsTaskRunCount'], 0);
      expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsStatus'], 'incomplete');
      expect(reportingGate['missingAgenticHarnessMetadataCount'], 0);
      expect(reportingGate['missingRunResultsAgenticHarnessMetadataCount'], 1);
      expect(
        reportingGate['mismatchedRunResultsAgenticHarnessMetadataCount'],
        1,
      );
    },
  );

  test(
    'blocks report when run results agent harness status metadata is missing',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_run_results_harness_status_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(
          _artifactManifestJson(
            evaluatorIds: const ['agent_harness', 'compile', 'test'],
            countOverrides: const {'evaluationCount': 6},
          ),
        ),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        includeAgentHarnessEvaluations: true,
        omitAgentHarnessStatusMetadata: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-run-results-harness-status-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 8),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 2 agent harness evaluation record(s) with missing status metadata.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(
        artifactBundle['missingRunResultsAgentHarnessStatusMetadataCount'],
        2,
      );
      expect(
        artifactBundle['invalidRunResultsAgentHarnessStatusMetadataCount'],
        0,
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(
        reportingGate['missingRunResultsAgentHarnessStatusMetadataCount'],
        2,
      );
      expect(
        reportingGate['invalidRunResultsAgentHarnessStatusMetadataCount'],
        0,
      );
    },
  );

  test('blocks report when run results outcomes mismatch trials', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_outcome_mismatch_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(
      tmp.path,
      corruptSecondCsvOutcome: true,
      corruptSecondReportOutcome: true,
    );
    await _writeRunResultsFile(
      standardBundleFiles['run_results.v1.json']!,
      corruptSecondOutcome: true,
    );
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-outcome-mismatch-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 8),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle run results mismatch 1 leaderboard trial outcome(s).',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['runResultsStatus'], 'incomplete');
    expect(artifactBundle['mismatchedRunResultsTrialOutcomeCount'], 1);
    expect(artifactBundle['invalidRunResultsTrialOutcomeCount'], 0);
    expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
    expect(artifactBundle['missingLeaderboardTrialSummaryTaskRunCount'], 0);
    expect(artifactBundle['extraLeaderboardTrialSummaryTaskRunCount'], 0);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['mismatchedRunResultsTrialOutcomeCount'], 1);
    expect(reportingGate['invalidRunResultsTrialOutcomeCount'], 0);
  });

  test(
    'blocks report when run results outcomes use unsupported tags',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_invalid_trial_outcome_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(leaderboardPath).writeAsString(
        _prettyJson(
          _leaderboardJson(
            sampleCount: 2,
            trialPrimaryPass: false,
            trialFailureTag: 'unsupported_failure',
            trialAggregateScore: 0.25,
          ),
        ),
      );
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(
        tmp.path,
        unsupportedCsvFailureTag: true,
        unsupportedReportFailureTag: true,
      );
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        unsupportedFailureTag: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-invalid-trial-outcome-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 15),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 2 invalid task-run outcome(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['mismatchedRunResultsTrialOutcomeCount'], 0);
      expect(artifactBundle['invalidRunResultsTrialOutcomeCount'], 2);
      expect(artifactBundle['runResultsEvaluationCount'], 4);
      expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
      expect(artifactBundle['invalidRunResultsEvaluationCount'], 0);
      expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
      expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['mismatchedRunResultsTrialOutcomeCount'], 0);
      expect(reportingGate['invalidRunResultsTrialOutcomeCount'], 2);
      expect(reportingGate['runResultsEvaluationCount'], 4);
      expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
      expect(reportingGate['invalidRunResultsEvaluationCount'], 0);
      expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
      expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
    },
  );

  test('blocks report when results CSV outcomes mismatch run results', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_results_csv_mismatch_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(
      tmp.path,
      corruptSecondCsvOutcome: true,
    );
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-results-csv-mismatch-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 16),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle results CSV mismatches 1 run results task outcome(s).',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['resultsCsvStatus'], 'incomplete');
    expect(artifactBundle['resultsCsvTaskRunCount'], 2);
    expect(artifactBundle['missingResultsCsvHeaderCount'], 0);
    expect(artifactBundle['invalidResultsCsvTaskRunCount'], 0);
    expect(artifactBundle['duplicateResultsCsvTaskRunCount'], 0);
    expect(artifactBundle['missingResultsCsvTaskRunCount'], 0);
    expect(artifactBundle['extraResultsCsvTaskRunCount'], 0);
    expect(artifactBundle['mismatchedResultsCsvRunResultsCount'], 1);
    expect(artifactBundle['invalidResultsCsvOutcomeCount'], 0);
    expect(artifactBundle['runResultsStatus'], 'present');
    expect(artifactBundle['mismatchedRunResultsTrialOutcomeCount'], 0);
    expect(artifactBundle['invalidRunResultsTrialOutcomeCount'], 0);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['artifactResultsCsvStatus'], 'incomplete');
    expect(reportingGate['resultsCsvTaskRunCount'], 2);
    expect(reportingGate['missingResultsCsvHeaderCount'], 0);
    expect(reportingGate['invalidResultsCsvTaskRunCount'], 0);
    expect(reportingGate['duplicateResultsCsvTaskRunCount'], 0);
    expect(reportingGate['missingResultsCsvTaskRunCount'], 0);
    expect(reportingGate['extraResultsCsvTaskRunCount'], 0);
    expect(reportingGate['mismatchedResultsCsvRunResultsCount'], 1);
    expect(reportingGate['invalidResultsCsvOutcomeCount'], 0);
  });

  test(
    'blocks report when markdown report outcomes mismatch run results',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_markdown_report_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(
        tmp.path,
        corruptSecondReportOutcome: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-markdown-report-mismatch-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 17),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle report markdown mismatches 1 run results task outcome(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['reportMarkdownStatus'], 'incomplete');
      expect(artifactBundle['reportMarkdownDeclaredTaskRunCount'], 2);
      expect(artifactBundle['reportMarkdownTaskRunCount'], 2);
      expect(artifactBundle['missingReportMarkdownSectionCount'], 0);
      expect(artifactBundle['missingReportMarkdownColumnCount'], 0);
      expect(artifactBundle['invalidReportMarkdownTaskRunCount'], 0);
      expect(artifactBundle['duplicateReportMarkdownTaskRunCount'], 0);
      expect(artifactBundle['missingReportMarkdownTaskRunCount'], 0);
      expect(artifactBundle['extraReportMarkdownTaskRunCount'], 0);
      expect(artifactBundle['mismatchedReportMarkdownRunResultsCount'], 1);
      expect(artifactBundle['invalidReportMarkdownOutcomeCount'], 0);
      expect(artifactBundle['runResultsStatus'], 'present');
      expect(artifactBundle['resultsCsvStatus'], 'present');
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactReportMarkdownStatus'], 'incomplete');
      expect(reportingGate['reportMarkdownDeclaredTaskRunCount'], 2);
      expect(reportingGate['reportMarkdownTaskRunCount'], 2);
      expect(reportingGate['missingReportMarkdownSectionCount'], 0);
      expect(reportingGate['missingReportMarkdownColumnCount'], 0);
      expect(reportingGate['invalidReportMarkdownTaskRunCount'], 0);
      expect(reportingGate['duplicateReportMarkdownTaskRunCount'], 0);
      expect(reportingGate['missingReportMarkdownTaskRunCount'], 0);
      expect(reportingGate['extraReportMarkdownTaskRunCount'], 0);
      expect(reportingGate['mismatchedReportMarkdownRunResultsCount'], 1);
      expect(reportingGate['invalidReportMarkdownOutcomeCount'], 0);
    },
  );

  test('blocks report when run results omit evaluation evidence', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_missing_evaluations_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    await _writeRunResultsFile(
      standardBundleFiles['run_results.v1.json']!,
      omitSecondEvaluations: true,
    );
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-missing-evaluations-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 9),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle run results have 1 task run(s) without evaluation evidence.',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle manifest evaluation count does not match run results.',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['evaluationCount'], 4);
    expect(artifactBundle['runResultsStatus'], 'incomplete');
    expect(artifactBundle['runResultsEvaluationCount'], 2);
    expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], false);
    expect(artifactBundle['missingRunResultsEvaluationTaskRunCount'], 1);
    expect(artifactBundle['invalidRunResultsEvaluationCount'], 0);
    expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
    expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['artifactBundleEvaluationCount'], 4);
    expect(reportingGate['runResultsEvaluationCount'], 2);
    expect(reportingGate['runResultsEvaluationCountMatchesManifest'], false);
    expect(reportingGate['missingRunResultsEvaluationTaskRunCount'], 1);
    expect(reportingGate['invalidRunResultsEvaluationCount'], 0);
    expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
    expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
  });

  test(
    'blocks report when run results evaluation scores are out of range',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_invalid_evaluation_score_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        outOfRangeEvaluationScore: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-invalid-evaluation-score-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 13),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 2 invalid evaluation record(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['runResultsEvaluationCount'], 4);
      expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
      expect(artifactBundle['missingRunResultsEvaluationTaskRunCount'], 0);
      expect(artifactBundle['invalidRunResultsEvaluationCount'], 2);
      expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
      expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsEvaluationCount'], 4);
      expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
      expect(reportingGate['missingRunResultsEvaluationTaskRunCount'], 0);
      expect(reportingGate['invalidRunResultsEvaluationCount'], 2);
      expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
      expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
    },
  );

  test(
    'blocks report when run results evaluation statuses mismatch pass flags',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_invalid_evaluation_status_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        mismatchedEvaluationStatus: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-invalid-evaluation-status-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 14),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 2 invalid evaluation record(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['runResultsEvaluationCount'], 4);
      expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
      expect(artifactBundle['missingRunResultsEvaluationTaskRunCount'], 0);
      expect(artifactBundle['invalidRunResultsEvaluationCount'], 2);
      expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
      expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsEvaluationCount'], 4);
      expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
      expect(reportingGate['missingRunResultsEvaluationTaskRunCount'], 0);
      expect(reportingGate['invalidRunResultsEvaluationCount'], 2);
      expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
      expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
    },
  );

  test(
    'blocks report when run results evaluation rationale is missing',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_missing_evaluation_rationale_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        omitSecondEvaluationRationale: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-missing-evaluation-rationale-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 15),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 1 evaluation record(s) with missing rationale.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['runResultsEvaluationCount'], 4);
      expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
      expect(artifactBundle['invalidRunResultsEvaluationCount'], 0);
      expect(artifactBundle['invalidRunResultsEvaluationRationaleCount'], 1);
      expect(
        artifactBundle['invalidRunResultsEvaluationDetailsMetadataCount'],
        0,
      );
      expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
      expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsEvaluationCount'], 4);
      expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
      expect(reportingGate['invalidRunResultsEvaluationCount'], 0);
      expect(reportingGate['invalidRunResultsEvaluationRationaleCount'], 1);
      expect(
        reportingGate['invalidRunResultsEvaluationDetailsMetadataCount'],
        0,
      );
      expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
      expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
    },
  );

  test(
    'blocks report when run results blocked evaluation metadata is missing',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_missing_blocked_evaluation_metadata_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(
          _artifactManifestJson(
            passSummary: const {
              'primaryPassTrue': 2,
              'primaryPassFalse': 0,
              'primaryPassUnknown': 0,
              'evaluationPassCount': 3,
              'evaluationFailCount': 1,
            },
          ),
        ),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        blockedSecondEvaluation: true,
        omitSecondBlockedEvaluationMetadata: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-missing-blocked-evaluation-metadata-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 17),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 1 evaluation record(s) with invalid blocked metadata.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['manifestPassSummaryMismatchCount'], 0);
      expect(artifactBundle['runResultsEvaluationCount'], 4);
      expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
      expect(artifactBundle['invalidRunResultsEvaluationCount'], 0);
      expect(artifactBundle['invalidRunResultsEvaluationRationaleCount'], 0);
      expect(
        artifactBundle['invalidRunResultsEvaluationDetailsMetadataCount'],
        0,
      );
      expect(
        artifactBundle['invalidRunResultsBlockedEvaluationMetadataCount'],
        1,
      );
      expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
      expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsEvaluationCount'], 4);
      expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
      expect(reportingGate['invalidRunResultsEvaluationCount'], 0);
      expect(reportingGate['invalidRunResultsEvaluationRationaleCount'], 0);
      expect(
        reportingGate['invalidRunResultsEvaluationDetailsMetadataCount'],
        0,
      );
      expect(
        reportingGate['invalidRunResultsBlockedEvaluationMetadataCount'],
        1,
      );
      expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
      expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
    },
  );

  test(
    'blocks report when run results judge overhead metadata is invalid',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_invalid_judge_overhead_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        corruptSecondJudgeOverhead: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-invalid-judge-overhead-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 18),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 1 evaluation record(s) with invalid judge overhead metadata.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['runResultsEvaluationCount'], 4);
      expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
      expect(artifactBundle['invalidRunResultsEvaluationCount'], 0);
      expect(artifactBundle['invalidRunResultsEvaluationRationaleCount'], 0);
      expect(
        artifactBundle['invalidRunResultsEvaluationDetailsMetadataCount'],
        0,
      );
      expect(
        artifactBundle['invalidRunResultsBlockedEvaluationMetadataCount'],
        0,
      );
      expect(artifactBundle['invalidRunResultsJudgeOverheadMetadataCount'], 1);
      expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
      expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsEvaluationCount'], 4);
      expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
      expect(reportingGate['invalidRunResultsEvaluationCount'], 0);
      expect(reportingGate['invalidRunResultsEvaluationRationaleCount'], 0);
      expect(
        reportingGate['invalidRunResultsEvaluationDetailsMetadataCount'],
        0,
      );
      expect(
        reportingGate['invalidRunResultsBlockedEvaluationMetadataCount'],
        0,
      );
      expect(reportingGate['invalidRunResultsJudgeOverheadMetadataCount'], 1);
      expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
      expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
    },
  );

  test(
    'blocks report when run results evaluation details metadata is invalid',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_invalid_evaluation_details_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        corruptSecondEvaluationDetailsMetadata: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-invalid-evaluation-details-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 16),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 1 evaluation record(s) with invalid details metadata.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['runResultsEvaluationCount'], 4);
      expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
      expect(artifactBundle['invalidRunResultsEvaluationCount'], 0);
      expect(
        artifactBundle['invalidRunResultsEvaluationDetailsMetadataCount'],
        1,
      );
      expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
      expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsEvaluationCount'], 4);
      expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
      expect(reportingGate['invalidRunResultsEvaluationCount'], 0);
      expect(
        reportingGate['invalidRunResultsEvaluationDetailsMetadataCount'],
        1,
      );
      expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
      expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
    },
  );

  test('blocks report when run results duplicate evaluation ids', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_duplicate_evaluation_id_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    await _writeRunResultsFile(
      standardBundleFiles['run_results.v1.json']!,
      duplicateSecondEvaluationId: true,
    );
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-duplicate-evaluation-id-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 11),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle run results have 1 duplicate evaluation id(s).',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['runResultsStatus'], 'incomplete');
    expect(artifactBundle['runResultsEvaluationCount'], 4);
    expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
    expect(artifactBundle['invalidRunResultsEvaluationCount'], 0);
    expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 1);
    expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 0);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['runResultsEvaluationCount'], 4);
    expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
    expect(reportingGate['invalidRunResultsEvaluationCount'], 0);
    expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 1);
    expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 0);
  });

  test(
    'blocks report when run results duplicate task-run evaluator ids',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_duplicate_task_evaluator_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(_artifactManifestJson(evaluatorIds: const ['compile'])),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        duplicateEvaluatorIds: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-duplicate-task-evaluator-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 12),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 2 duplicate task-run evaluator id(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['manifestEvaluatorIdCount'], 1);
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['runResultsEvaluationCount'], 4);
      expect(artifactBundle['runResultsEvaluationCountMatchesManifest'], true);
      expect(artifactBundle['runResultsEvaluatorIdCount'], 1);
      expect(artifactBundle['runResultsEvaluatorIdsMatchManifest'], true);
      expect(artifactBundle['invalidRunResultsEvaluationCount'], 0);
      expect(artifactBundle['duplicateRunResultsEvaluationIdCount'], 0);
      expect(artifactBundle['duplicateRunResultsTaskEvaluatorCount'], 2);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['manifestEvaluatorIdCount'], 1);
      expect(reportingGate['runResultsEvaluationCount'], 4);
      expect(reportingGate['runResultsEvaluationCountMatchesManifest'], true);
      expect(reportingGate['runResultsEvaluatorIdCount'], 1);
      expect(reportingGate['runResultsEvaluatorIdsMatchManifest'], true);
      expect(reportingGate['invalidRunResultsEvaluationCount'], 0);
      expect(reportingGate['duplicateRunResultsEvaluationIdCount'], 0);
      expect(reportingGate['duplicateRunResultsTaskEvaluatorCount'], 2);
    },
  );

  test(
    'blocks report when run results evaluator ids mismatch manifest',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_evaluator_id_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(_artifactManifestJson(evaluatorIds: const ['compile'])),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-evaluator-id-mismatch-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 10),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results contain 1 evaluator id(s) not listed in the manifest.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['manifestEvaluatorIdCount'], 1);
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['runResultsEvaluatorIdCount'], 2);
      expect(artifactBundle['runResultsEvaluatorIdsMatchManifest'], false);
      expect(artifactBundle['missingRunResultsEvaluatorIdCount'], 0);
      expect(artifactBundle['extraRunResultsEvaluatorIdCount'], 1);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['manifestEvaluatorIdCount'], 1);
      expect(reportingGate['runResultsEvaluatorIdCount'], 2);
      expect(reportingGate['runResultsEvaluatorIdsMatchManifest'], false);
      expect(reportingGate['missingRunResultsEvaluatorIdCount'], 0);
      expect(reportingGate['extraRunResultsEvaluatorIdCount'], 1);
    },
  );

  test(
    'blocks report when artifact bundle task runs miss leaderboard trials',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_trial_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson(secondTrialIndex: 99)));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        secondTrialIndex: 99,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-trial-mismatch-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 7),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest has 1 task run(s) not represented '
          'in leaderboard trial summaries.',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest is missing 1 leaderboard trial summary task run(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'present');
      expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
      expect(artifactBundle['missingLeaderboardTrialSummaryTaskRunCount'], 1);
      expect(artifactBundle['extraLeaderboardTrialSummaryTaskRunCount'], 1);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['missingLeaderboardTrialSummaryTaskRunCount'], 1);
      expect(reportingGate['extraLeaderboardTrialSummaryTaskRunCount'], 1);
    },
  );

  test(
    'blocks report when artifact bundle manifest duplicates artifact references',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_duplicate_reference_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(
          _artifactManifestJson(duplicateSecondResponseArtifact: true),
        ),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-duplicate-reference-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest has 1 duplicate artifact reference(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['artifactCount'], 5);
      expect(artifactBundle['duplicateArtifactReferenceCount'], 1);
      expect(artifactBundle['runResultsStatus'], 'present');
      expect(artifactBundle['mismatchedRunResultsArtifactCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['duplicateArtifactReferenceCount'], 1);
    },
  );

  test(
    'blocks report when artifact bundle manifest has unknown artifact kinds',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_unknown_kind_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(_artifactManifestJson(includeDebugArtifact: true)),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        extraSecondArtifacts: const {
          'debug': 'artifacts/trajectories/task-run-2-debug.log',
        },
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
            extraPaths: const ['artifacts/trajectories/task-run-2-debug.log'],
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-unknown-kind-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 5),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest has 1 unknown artifact kind(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['artifactCount'], 5);
      expect(artifactBundle['unknownArtifactKindCount'], 1);
      expect(artifactBundle['runResultsStatus'], 'present');
      expect(artifactBundle['extraRunResultsArtifactCount'], 0);
      expect(artifactBundle['missingArtifactChecksumCount'], 0);
      expect(artifactBundle['unexpectedChecksumPathCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['unknownArtifactKindCount'], 1);
    },
  );

  test('blocks report when artifact bundle schemas are unsupported', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_schema_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson(schemaVersion: 2)));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    await _writeRunResultsFile(
      standardBundleFiles['run_results.v1.json']!,
      schemaVersion: 2,
    );
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          schemaVersion: 2,
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-schema-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 6),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle checksums schema version 2 is unsupported.',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle run results schema version 2 is unsupported.',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['schemaVersion'], 2);
    expect(artifactBundle['checksumSchemaVersion'], 2);
    expect(artifactBundle['checksumsStatus'], 'incomplete');
    expect(artifactBundle['runResultsSchemaVersion'], 2);
    expect(artifactBundle['runResultsStatus'], 'incomplete');
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['artifactChecksumSchemaVersion'], 2);
    expect(reportingGate['artifactChecksumsStatus'], 'incomplete');
    expect(reportingGate['runResultsSchemaVersion'], 2);
    expect(reportingGate['runResultsStatus'], 'incomplete');
  });

  test(
    'blocks report when artifact bundle manifest has unsafe paths',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_paths_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      const unsafePatchPath = '/tmp/private/_hidden/task-run-2.patch';
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(_artifactManifestJson(secondPatchPath: unsafePatchPath)),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
            secondPatchPath: unsafePatchPath,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-paths-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Run artifact bundle manifest has 1 unsafe artifact path(s).'),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest is missing patch artifacts for '
          '1 agentic task run(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['unsafeArtifactPathCount'], 1);
      expect(artifactBundle['absoluteArtifactPathCount'], 1);
      expect(artifactBundle['privateArtifactPathCount'], 1);
      expect(artifactBundle['outsideArtifactRootPathCount'], 1);
      expect(artifactBundle['missingAgenticPatchArtifactCount'], 1);
      expect(artifactBundle['missingArtifactChecksumCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['unsafeArtifactPathCount'], 1);
      expect(reportingGate['absoluteArtifactPathCount'], 1);
      expect(reportingGate['privateArtifactPathCount'], 1);
      expect(reportingGate['outsideArtifactRootPathCount'], 1);
    },
  );

  test('blocks report when artifact bundle checksums are incomplete', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_checksums_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          includeSecondPatch: false,
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-checksums-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Run artifact bundle checksums are missing 1 artifact file(s).'),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['checksumsStatus'], 'incomplete');
    expect(artifactBundle['checksumFileCount'], 7);
    expect(artifactBundle['coveredArtifactChecksumCount'], 3);
    expect(artifactBundle['missingArtifactChecksumCount'], 1);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['artifactChecksumsStatus'], 'incomplete');
    expect(reportingGate['missingArtifactChecksumCount'], 1);
  });

  test(
    'blocks report when artifact bundle checksums omit standard files',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_standard_checksums_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            includeRunResults: false,
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-standard-checksums-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle checksums are missing 1 standard bundle file(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['checksumsStatus'], 'incomplete');
      expect(artifactBundle['coveredStandardChecksumCount'], 3);
      expect(artifactBundle['missingStandardChecksumCount'], 1);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactChecksumsStatus'], 'incomplete');
      expect(reportingGate['missingStandardChecksumCount'], 1);
    },
  );

  test(
    'blocks report when standard bundle file checksum mismatches input',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_standard_digest_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: {
              ...standardBundleDigests,
              'report.md':
                  'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            },
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-standard-digest-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle standard file checksums mismatch 1 input file(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['checksumsStatus'], 'incomplete');
      expect(artifactBundle['verifiedStandardChecksumCount'], 2);
      expect(artifactBundle['mismatchedStandardChecksumCount'], 1);
      expect(artifactBundle['missingStandardInputCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactChecksumsStatus'], 'incomplete');
      expect(reportingGate['mismatchedStandardChecksumCount'], 1);
    },
  );

  test('blocks report when artifact files are missing or changed', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_artifact_files_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    await File(
      p.join(tmp.path, 'artifacts/responses/task-run-1.txt'),
    ).writeAsString('changed');
    await File(p.join(tmp.path, 'artifacts/patches/task-run-2.patch')).delete();
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-artifact-files-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle artifact file inputs are missing 1 file(s).',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle artifact file byte counts mismatch 1 file(s).',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle artifact file checksums mismatch 1 file(s).',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['checksumsStatus'], 'incomplete');
    expect(artifactBundle['verifiedArtifactFileCount'], 2);
    expect(artifactBundle['missingArtifactFileCount'], 1);
    expect(artifactBundle['mismatchedArtifactFileByteCount'], 1);
    expect(artifactBundle['mismatchedArtifactFileDigestCount'], 1);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['artifactChecksumsStatus'], 'incomplete');
    expect(reportingGate['verifiedArtifactFileCount'], 2);
    expect(reportingGate['missingArtifactFileCount'], 1);
    expect(reportingGate['mismatchedArtifactFileByteCount'], 1);
    expect(reportingGate['mismatchedArtifactFileDigestCount'], 1);
  });

  test(
    'blocks report when manifest artifact digests are invalid or mismatched',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_manifest_artifact_digests_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final manifest = _artifactManifestJson();
      final artifacts = (manifest['artifacts']! as List<Object?>)
          .cast<Map<String, Object?>>();
      artifacts.first['sha256'] = '';
      artifacts.last['sha256'] = '0' * 64;
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(_prettyJson(manifest));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeDefaultArtifactFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-manifest-artifact-digests-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 22),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest has 1 invalid artifact digest(s).',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest artifact digests mismatch 1 checksum entry(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['invalidArtifactDigestCount'], 1);
      expect(artifactBundle['mismatchedManifestArtifactDigestCount'], 1);
      expect(artifactBundle['checksumsStatus'], 'incomplete');
      expect(artifactBundle['verifiedArtifactFileCount'], 4);
      expect(artifactBundle['mismatchedArtifactFileDigestCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactChecksumsStatus'], 'incomplete');
      expect(reportingGate['invalidManifestArtifactDigestCount'], 1);
      expect(reportingGate['mismatchedManifestArtifactDigestCount'], 1);
    },
  );

  test(
    'blocks report when manifest artifact ids are invalid or duplicated',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_manifest_artifact_ids_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final manifest = _artifactManifestJson();
      final artifacts = (manifest['artifacts']! as List<Object?>)
          .cast<Map<String, Object?>>();
      artifacts.first.remove('artifactId');
      final duplicateArtifactId = artifacts[1]['artifactId']! as String;
      artifacts.last['artifactId'] = duplicateArtifactId;
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(_prettyJson(manifest));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final runResultsFile = File(standardBundleFiles['run_results.v1.json']!);
      final runResults =
          jsonDecode(await runResultsFile.readAsString())
              as Map<String, Object?>;
      final taskRuns = (runResults['taskRuns']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final secondMetadata =
          taskRuns[1]['artifactMetadata']! as Map<String, Object?>;
      final secondPatchMetadata =
          secondMetadata['patch']! as Map<String, Object?>;
      secondPatchMetadata['artifactId'] = duplicateArtifactId;
      await runResultsFile.writeAsString(_prettyJson(runResults));
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-manifest-artifact-ids-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 22, 15),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Run artifact bundle manifest has 1 invalid artifact id(s).'),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest has 1 duplicate artifact id(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['invalidArtifactIdCount'], 1);
      expect(artifactBundle['duplicateArtifactIdCount'], 1);
      expect(artifactBundle['runResultsStatus'], 'present');
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['invalidManifestArtifactIdCount'], 1);
      expect(reportingGate['duplicateManifestArtifactIdCount'], 1);
    },
  );

  test(
    'blocks report when agentic failure bundle has response but no patch',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_agentic_missing_patch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(artifactManifestPath).writeAsString(
        _prettyJson(
          _artifactManifestJson(
            includeSecondPatch: false,
            warningCount: 1,
            warningCode: 'missing_patch_text',
          ),
        ),
      );
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      for (final path in [
        'artifacts/responses/task-run-1.txt',
        'artifacts/patches/task-run-1.patch',
        'artifacts/responses/task-run-2.txt',
      ]) {
        final file = File(p.join(tmp.path, path));
        await file.parent.create(recursive: true);
        await file.writeAsString(_artifactFileContent);
      }
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            includeReport: false,
            includeResultsCsv: false,
            includeRunResults: false,
            includeSecondPatch: false,
            manifestSha256: artifactManifestSha256,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-agentic-missing-patch-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Run artifact bundle manifest contains 1 warning(s).'),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest is missing patch artifacts for 1 agentic task run(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['artifactKindCounts'], {'patch': 1, 'response': 2});
      expect(artifactBundle['warningCount'], 1);
      expect(artifactBundle['warningCodeCounts'], {'missing_patch_text': 1});
      expect(artifactBundle['missingResponseArtifactCount'], 0);
      expect(artifactBundle['missingAgenticPatchArtifactCount'], 1);
      expect(artifactBundle['verifiedArtifactFileCount'], 3);
      expect(artifactBundle['missingArtifactFileCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactBundleWarningCount'], 1);
      expect(reportingGate['artifactBundleWarningCodeCounts'], {
        'missing_patch_text': 1,
      });
      expect(reportingGate['missingResponseArtifactCount'], 0);
      expect(reportingGate['missingAgenticPatchArtifactCount'], 1);
    },
  );

  test(
    'blocks report when run results artifact references mismatch manifest',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_run_results_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        secondPatchPath: 'artifacts/patches/task-run-2-corrupt.patch',
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-run-results-mismatch-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results mismatch 1 manifest artifact reference(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['mismatchedRunResultsArtifactCount'], 1);
      expect(artifactBundle['verifiedStandardChecksumCount'], 3);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsStatus'], 'incomplete');
      expect(reportingGate['mismatchedRunResultsArtifactCount'], 1);
    },
  );

  test(
    'blocks report when run results artifact bytes or digests mismatch bundle metadata',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_run_results_artifact_metadata_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        corruptSecondResponseDigest: true,
        corruptSecondPatchBytes: true,
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-run-results-artifact-metadata-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 22),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 1 response/patch artifact byte count mismatch(es).',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 1 response/patch artifact checksum mismatch(es).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['mismatchedRunResultsArtifactCount'], 0);
      expect(artifactBundle['invalidRunResultsArtifactMetadataCount'], 0);
      expect(artifactBundle['mismatchedRunResultsArtifactByteCount'], 1);
      expect(artifactBundle['mismatchedRunResultsArtifactDigestCount'], 1);
      expect(artifactBundle['verifiedStandardChecksumCount'], 3);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsStatus'], 'incomplete');
      expect(reportingGate['mismatchedRunResultsArtifactCount'], 0);
      expect(reportingGate['invalidRunResultsArtifactMetadataCount'], 0);
      expect(reportingGate['mismatchedRunResultsArtifactByteCount'], 1);
      expect(reportingGate['mismatchedRunResultsArtifactDigestCount'], 1);
    },
  );

  test(
    'blocks report when run results artifact metadata is missing or mismatched',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_run_results_artifact_metadata_records_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final runResultsFile = File(standardBundleFiles['run_results.v1.json']!);
      await _writeRunResultsFile(runResultsFile.path);
      final runResults =
          jsonDecode(await runResultsFile.readAsString())
              as Map<String, Object?>;
      final taskRuns = (runResults['taskRuns']! as List<Object?>)
          .cast<Map<String, Object?>>();
      taskRuns.first.remove('artifactMetadata');
      final secondMetadata =
          taskRuns[1]['artifactMetadata']! as Map<String, Object?>;
      final secondPatchMetadata =
          secondMetadata['patch']! as Map<String, Object?>;
      secondPatchMetadata['sha256'] = '0' * 64;
      await runResultsFile.writeAsString(_prettyJson(runResults));
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-run-results-artifact-metadata-records-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 22),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results are missing 2 artifact metadata record(s).',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle run results mismatch 1 artifact metadata record(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['missingRunResultsArtifactMetadataCount'], 2);
      expect(artifactBundle['mismatchedRunResultsArtifactMetadataCount'], 1);
      expect(artifactBundle['invalidRunResultsArtifactMetadataEntryCount'], 0);
      expect(artifactBundle['invalidRunResultsArtifactMetadataCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsStatus'], 'incomplete');
      expect(reportingGate['missingRunResultsArtifactMetadataCount'], 2);
      expect(reportingGate['mismatchedRunResultsArtifactMetadataCount'], 1);
      expect(reportingGate['invalidRunResultsArtifactMetadataEntryCount'], 0);
    },
  );

  test(
    'blocks report when run results artifact ids are invalid or mismatched',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_run_results_artifact_ids_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final runResultsFile = File(standardBundleFiles['run_results.v1.json']!);
      await _writeRunResultsFile(runResultsFile.path);
      final runResults =
          jsonDecode(await runResultsFile.readAsString())
              as Map<String, Object?>;
      final taskRuns = (runResults['taskRuns']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final firstMetadata =
          taskRuns.first['artifactMetadata']! as Map<String, Object?>;
      final firstResponseMetadata =
          firstMetadata['response']! as Map<String, Object?>;
      firstResponseMetadata.remove('artifactId');
      final secondMetadata =
          taskRuns[1]['artifactMetadata']! as Map<String, Object?>;
      final secondPatchMetadata =
          secondMetadata['patch']! as Map<String, Object?>;
      secondPatchMetadata['artifactId'] = _artifactId('task-run-1', 'patch');
      await runResultsFile.writeAsString(_prettyJson(runResults));
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-run-results-artifact-ids-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 22, 30),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results have 1 invalid artifact id metadata record(s).',
        ),
      );
      expect(
        blockers,
        contains(
          'Run artifact bundle run results mismatch 1 artifact id metadata record(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['invalidRunResultsArtifactIdCount'], 1);
      expect(artifactBundle['mismatchedRunResultsArtifactIdCount'], 1);
      expect(artifactBundle['mismatchedRunResultsArtifactMetadataCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsStatus'], 'incomplete');
      expect(reportingGate['invalidRunResultsArtifactIdCount'], 1);
      expect(reportingGate['mismatchedRunResultsArtifactIdCount'], 1);
      expect(reportingGate['mismatchedRunResultsArtifactMetadataCount'], 0);
    },
  );

  test('blocks report when run results task telemetry is invalid', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_run_results_task_telemetry_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    await _writeRunResultsFile(
      standardBundleFiles['run_results.v1.json']!,
      secondTaskRunCompletedAt: '2026-06-03T12:05:00.000Z',
      secondLatencyMs: 0,
      secondPromptTokens: -1,
      secondCompletionTokens: 'twenty',
    );
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-run-results-task-telemetry-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 23),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle run results have 1 task run(s) with invalid timing metadata.',
      ),
    );
    expect(
      blockers,
      contains(
        'Run artifact bundle run results have 1 task run(s) with invalid token usage metadata.',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['runResultsStatus'], 'incomplete');
    expect(artifactBundle['invalidRunResultsTimingTaskRunCount'], 1);
    expect(artifactBundle['invalidRunResultsTokenUsageTaskRunCount'], 1);
    expect(artifactBundle['invalidRunResultsTaskRunCount'], 0);
    expect(artifactBundle['mismatchedRunResultsTaskRunCount'], 0);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['runResultsStatus'], 'incomplete');
    expect(reportingGate['invalidRunResultsTimingTaskRunCount'], 1);
    expect(reportingGate['invalidRunResultsTokenUsageTaskRunCount'], 1);
  });

  test('blocks report when run results duplicate task run ids', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_run_results_duplicate_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final artifactManifestPath = p.join(tmp.path, 'manifest.json');
    await File(
      artifactManifestPath,
    ).writeAsString(_prettyJson(_artifactManifestJson()));
    final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
    final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
    await _writeRunResultsFile(
      standardBundleFiles['run_results.v1.json']!,
      duplicateFirstTaskRun: true,
    );
    final standardBundleDigests = await _standardBundleFileDigests(
      standardBundleFiles,
    );
    final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
    await File(artifactChecksumsPath).writeAsString(
      _prettyJson(
        _artifactChecksumsJson(
          manifestSha256: artifactManifestSha256,
          standardSha256ByPath: standardBundleDigests,
        ),
      ),
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--artifact-manifest',
        artifactManifestPath,
        '--artifact-checksums',
        artifactChecksumsPath,
        ..._standardBundleCliArgs(standardBundleFiles),
        '--out',
        outPath,
        '--release-id',
        '2026-06-run-results-duplicate-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 2),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains(
        'Run artifact bundle run results have 1 duplicate task run id(s).',
      ),
    );
    final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
    expect(artifactBundle['status'], 'incomplete');
    expect(artifactBundle['runResultsStatus'], 'incomplete');
    expect(artifactBundle['duplicateRunResultsTaskRunCount'], 1);
    expect(artifactBundle['missingRunResultsTaskRunCount'], 0);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['artifactBundleStatus'], 'incomplete');
    expect(reportingGate['runResultsStatus'], 'incomplete');
    expect(reportingGate['duplicateRunResultsTaskRunCount'], 1);
  });

  test(
    'blocks report when run results include unmanifested artifact references',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_run_results_extra_artifact_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      await _writeRunResultsFile(
        standardBundleFiles['run_results.v1.json']!,
        extraSecondArtifacts: const {
          'hidden': 'artifacts/responses/task-run-2-extra.txt',
        },
      );
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-run-results-extra-artifact-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 1),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle run results contain 1 extra artifact reference(s).',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['runResultsStatus'], 'incomplete');
      expect(artifactBundle['extraRunResultsArtifactCount'], 1);
      expect(artifactBundle['mismatchedRunResultsArtifactCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['runResultsStatus'], 'incomplete');
      expect(reportingGate['extraRunResultsArtifactCount'], 1);
    },
  );

  test(
    'blocks report when artifact bundle checksums include unsafe extra paths',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_extra_checksums_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      const extraPath = 'artifacts/../_hidden/secret.txt';
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final artifactManifestSha256 = await _fileSha256(artifactManifestPath);
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(
            extraPaths: [extraPath],
            manifestSha256: artifactManifestSha256,
            standardSha256ByPath: standardBundleDigests,
          ),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-extra-checksums-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle checksums have 1 unexpected file path(s).',
        ),
      );
      expect(
        blockers,
        contains('Run artifact bundle checksums have 1 unsafe file path(s).'),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['checksumsStatus'], 'incomplete');
      expect(artifactBundle['checksumFileCount'], 9);
      expect(artifactBundle['unexpectedChecksumPathCount'], 1);
      expect(artifactBundle['unsafeChecksumPathCount'], 1);
      expect(artifactBundle['parentChecksumPathCount'], 1);
      expect(artifactBundle['privateChecksumPathCount'], 1);
      expect(artifactBundle['missingArtifactChecksumCount'], 0);
      expect(artifactBundle['missingStandardChecksumCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactChecksumsStatus'], 'incomplete');
      expect(reportingGate['unexpectedChecksumPathCount'], 1);
      expect(reportingGate['unsafeChecksumPathCount'], 1);
    },
  );

  test(
    'blocks report when artifact manifest checksum mismatches input',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_artifact_digest_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final artifactManifestPath = p.join(tmp.path, 'manifest.json');
      await File(
        artifactManifestPath,
      ).writeAsString(_prettyJson(_artifactManifestJson()));
      final standardBundleFiles = await _writeStandardBundleFiles(tmp.path);
      final standardBundleDigests = await _standardBundleFileDigests(
        standardBundleFiles,
      );
      final artifactChecksumsPath = p.join(tmp.path, 'checksums.json');
      await File(artifactChecksumsPath).writeAsString(
        _prettyJson(
          _artifactChecksumsJson(standardSha256ByPath: standardBundleDigests),
        ),
      );
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--artifact-manifest',
          artifactManifestPath,
          '--artifact-checksums',
          artifactChecksumsPath,
          ..._standardBundleCliArgs(standardBundleFiles),
          '--out',
          outPath,
          '--release-id',
          '2026-06-artifact-digest-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run artifact bundle manifest checksum does not match the provided manifest input.',
        ),
      );
      final artifactBundle = report['artifactBundle']! as Map<String, Object?>;
      expect(artifactBundle['status'], 'incomplete');
      expect(artifactBundle['checksumsStatus'], 'incomplete');
      expect(artifactBundle['manifestChecksumDigestStatus'], 'mismatched');
      expect(artifactBundle['missingArtifactChecksumCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['artifactBundleStatus'], 'incomplete');
      expect(reportingGate['artifactChecksumsStatus'], 'incomplete');
      expect(reportingGate['manifestChecksumDigestStatus'], 'mismatched');
    },
  );

  test('blocks report when public leaderboard contains leak markers', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_privacy_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    final leaderboard =
        jsonDecode(jsonEncode(_leaderboardJson(sampleCount: 2)))
            as Map<String, Object?>;
    leaderboard['leakedDiagnostics'] = {
      'apiKey': 'sk-live-private-token-1234567890',
      'workdir': tmp.path,
      'hiddenVerifierFiles': ['test/_hidden/secret_hidden_test.dart'],
      'prompt': 'private corpus prompt should not be public',
      'rawResponse': 'full model response should not be public',
    };
    await File(leaderboardPath).writeAsString(_prettyJson(leaderboard));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-privacy-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final text = await File(outPath).readAsString();
    expect(text, isNot(contains(tmp.path)));
    expect(text, isNot(contains('sk-live-private-token')));
    expect(text, isNot(contains('secret_hidden_test')));
    expect(text, isNot(contains('private corpus prompt')));
    expect(text, isNot(contains('full model response')));
    final report = jsonDecode(text) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(blockers, contains('privacy audit found secret-looking content'));
    expect(
      blockers,
      contains('privacy audit found private local path content'),
    );
    expect(
      blockers,
      contains('privacy audit found hidden verifier content markers'),
    );
    expect(
      blockers,
      contains('privacy audit found private prompt or model output fields'),
    );
    final leaderboardSummary = report['leaderboard']! as Map<String, Object?>;
    final privacy = leaderboardSummary['privacy']! as Map<String, Object?>;
    expect(privacy['status'], 'blocked');
    expect(privacy['issueCount'], 7);
    expect(privacy['secretKeyCount'], 1);
    expect(privacy['secretValueCount'], 1);
    expect(privacy['absolutePathCount'], 1);
    expect(privacy['hiddenVerifierMarkerCount'], 2);
    expect(privacy['privatePromptFieldCount'], 1);
    expect(privacy['sensitiveModelOutputFieldCount'], 1);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['privacyStatus'], 'blocked');
    expect(reportingGate['privacyIssueCount'], 7);
  });

  test('blocks report when run provenance lacks release safety gates', () async {
    final tmp = await Directory.systemTemp.createTemp('release_report_gate_');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(leaderboardPath).writeAsString(
      _prettyJson(
        _leaderboardJson(sampleCount: 2, includeJudgeOverhead: false),
      ),
    );
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(
      databasePath,
      sandboxEnforced: false,
      includeTaskExecutionPolicy: false,
      includeSdkVersions: false,
      includeDependencySnapshot: false,
      includePricingRegistry: false,
    );
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 3, 17),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stdoutLines, isEmpty);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    expect(report['status'], 'blocked');
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Run run-1 does not record generated-code sandbox enforcement'),
    );
    expect(
      blockers,
      contains('Run run-1 has incomplete task execution policy provenance'),
    );
    expect(
      blockers,
      contains(
        'Run run-1 has incomplete network-disabled task policy provenance',
      ),
    );
    expect(
      blockers,
      contains(
        'Run run-1 has incomplete or unenforced task resource limit provenance',
      ),
    );
    expect(
      blockers,
      contains('Run run-1 has incomplete SDK version provenance'),
    );
    expect(
      blockers,
      contains('Run run-1 has incomplete dependency lockfile provenance'),
    );
    expect(
      blockers,
      contains('Run run-1 has incomplete pricing registry provenance'),
    );
    expect(
      blockers,
      contains('Leaderboard source has incomplete judge overhead summary'),
    );
    final provenance = report['provenance']! as Map<String, Object?>;
    expect(provenance['sandboxEnforcedRunCount'], 0);
    expect(provenance['taskExecutionPolicyRunCount'], 0);
    expect(provenance['networkDisabledTaskPolicyRunCount'], 0);
    expect(provenance['taskResourceLimitRunCount'], 0);
    expect(provenance['sdkVersionRunCount'], 0);
    expect(provenance['dependencySnapshotRunCount'], 0);
    expect(provenance['pricingRegistryRunCount'], 0);
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final executionGate = readinessGates['execution']! as Map<String, Object?>;
    expect(executionGate['status'], 'blocked');
    expect(executionGate['sourceSandboxEnforcedRunCount'], 1);
    expect(executionGate['storedSandboxEnforcedRunCount'], 0);
    expect(executionGate['storedTaskExecutionPolicyRunCount'], 0);
    expect(executionGate['storedNetworkDisabledTaskPolicyRunCount'], 0);
    expect(executionGate['storedTaskResourceLimitRunCount'], 0);
    expect(executionGate['storedSdkVersionRunCount'], 0);
    expect(executionGate['storedDependencySnapshotRunCount'], 0);
    expect(executionGate['storedPricingRegistryRunCount'], 0);
    final reportingGate = readinessGates['reporting']! as Map<String, Object?>;
    expect(reportingGate['status'], 'blocked');
    expect(reportingGate['judgeOverheadStatus'], 'incomplete');
  });

  test(
    'blocks report when hidden verifier flake evidence is below release minimum',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_flake_minimum_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(
        reportPath,
      ).writeAsString(_prettyJson(_taskQaReportJson(hiddenFlakeRuns: 1)));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-flake-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 1),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task task.a@v1 has 1 hidden verifier flake run(s), below the required 3.',
        ),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['flakeRunCount'], 1);
      expect(corpusGate['minHiddenFlakeRunsPerTask'], 3);
      expect(corpusGate['tasksBelowHiddenFlakeRunMinimumCount'], 1);
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      expect(verifierAudit['hiddenFlakeRuns'], {
        'minimumPerTask': 3,
        'min': 1,
        'max': 1,
        'total': 1,
        'tasksBelowMinimum': [
          {
            'taskId': 'task.a',
            'taskVersion': 1,
            'hiddenFlakeRuns': 1,
            'minimum': 3,
          },
        ],
      });
    },
  );

  test(
    'blocks report when leaderboard task lacks matching task QA evidence',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_task_qa_mismatch_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(
        reportPath,
      ).writeAsString(_prettyJson(_taskQaReportJson(taskId: 'task.b')));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-task-qa-mismatch-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 1, 45),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Leaderboard task task.a@v1/agentic has no loaded task QA admission report.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.b@v1 is not present in the leaderboard task set.',
        ),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['leaderboardTaskCount'], 1);
      expect(corpusGate['coveredLeaderboardTaskCount'], 0);
      expect(corpusGate['missingLeaderboardTaskQaCount'], 1);
      expect(corpusGate['extraTaskQaReportCount'], 1);
      final taskQa = report['taskQa']! as Map<String, Object?>;
      expect(taskQa['leaderboardTasksMissingTaskQa'], [
        {'taskId': 'task.a', 'taskVersion': 1, 'track': 'agentic'},
      ]);
      expect(taskQa['taskQaReportsOutsideLeaderboard'], [
        {'taskId': 'task.b', 'taskVersion': 1},
      ]);
    },
  );

  test(
    'blocks report when task QA evidence is not private official corpus',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_public_corpus_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            releaseCorpus: 'public_diagnostic',
            releaseStatus: 'retired',
          ),
        ),
      );
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-public-corpus-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 1, 30),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Task task.a@v1 is not in the private official corpus.'),
      );
      expect(
        blockers,
        contains(
          'Task task.a@v1 is retired and cannot be used for an official release.',
        ),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['privateOfficialTaskCount'], 0);
      expect(corpusGate['activeTaskCount'], 0);
      expect(corpusGate['tasksOutsidePrivateOfficialCorpusCount'], 1);
      expect(corpusGate['retiredTaskCount'], 1);
      final verifierAudit = report['verifierAudit']! as Map<String, Object?>;
      expect(verifierAudit['releaseMetadata'], {
        'privateOfficialTaskCount': 0,
        'activeTaskCount': 0,
        'tasksMissingReleaseMetadata': <Object?>[],
        'tasksOutsidePrivateOfficialCorpus': [
          {'taskId': 'task.a', 'taskVersion': 1, 'corpus': 'public_diagnostic'},
        ],
        'retiredTasks': [
          {'taskId': 'task.a', 'taskVersion': 1},
        ],
      });
    },
  );

  test(
    'blocks report when stored task policy allows generated-code networking',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_network_policy_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath, taskAllowInternet: true);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-network-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 3, 18),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run run-1 records network-enabled generated-code task policy',
        ),
      );
      expect(
        blockers,
        contains(
          'Leaderboard source run provenance network-disabled task policy count does not match stored run provenance',
        ),
      );
      final provenance = report['provenance']! as Map<String, Object?>;
      expect(provenance['taskExecutionPolicyRunCount'], 1);
      expect(provenance['networkDisabledTaskPolicyRunCount'], 0);
      expect(provenance['taskResourceLimitRunCount'], 1);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final executionGate =
          readinessGates['execution']! as Map<String, Object?>;
      expect(executionGate['status'], 'blocked');
      expect(executionGate['sourceNetworkDisabledTaskPolicyRunCount'], 1);
      expect(executionGate['storedNetworkDisabledTaskPolicyRunCount'], 0);
      expect(executionGate['storedTaskResourceLimitRunCount'], 1);
    },
  );

  test(
    'blocks report when stored task policy lacks concrete resource limits',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_resource_policy_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath, useIncompleteTaskResourceLimits: true);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-resource-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 3, 18, 30),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Run run-1 has incomplete or unenforced task resource limit provenance.',
        ),
      );
      expect(
        blockers,
        contains(
          'Leaderboard source run provenance enforced task resource limits count does not match stored run provenance.',
        ),
      );
      final provenance = report['provenance']! as Map<String, Object?>;
      expect(provenance['taskExecutionPolicyRunCount'], 1);
      expect(provenance['networkDisabledTaskPolicyRunCount'], 1);
      expect(provenance['taskResourceLimitRunCount'], 0);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final executionGate =
          readinessGates['execution']! as Map<String, Object?>;
      expect(executionGate['status'], 'blocked');
      expect(executionGate['sourceTaskResourceLimitRunCount'], 1);
      expect(executionGate['storedNetworkDisabledTaskPolicyRunCount'], 1);
      expect(executionGate['storedTaskResourceLimitRunCount'], 0);
    },
  );

  test(
    'blocks report when leaderboard source run provenance is incomplete',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_source_provenance_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(leaderboardPath).writeAsString(
        _prettyJson(
          _leaderboardJson(sampleCount: 2, includeSourceRunProvenance: false),
        ),
      );
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-source-provenance-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 3, 19),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Leaderboard source has incomplete run provenance summary'),
      );
      expect(
        blockers,
        contains(
          'Leaderboard source run provenance count does not match runIds',
        ),
      );
      expect(
        blockers,
        contains(
          'Leaderboard source run provenance embedded run count does not match stored run provenance',
        ),
      );
      final leaderboard = report['leaderboard']! as Map<String, Object?>;
      final source = leaderboard['source']! as Map<String, Object?>;
      final runProvenance = source['runProvenance']! as Map<String, Object?>;
      expect(runProvenance['runCount'], 0);
      expect(runProvenance['embeddedRunCount'], 0);
    },
  );

  test('blocks report when task-model cells are missing', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_task_cells_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(leaderboardPath).writeAsString(
      _prettyJson(
        _leaderboardJson(sampleCount: 2, includeTaskModelCells: false),
      ),
    );
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-task-cells-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 3, 20),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Leaderboard export has no task-model cell summary'),
    );
    expect(
      blockers,
      contains('Leaderboard task-model cells are missing 1 expected'),
    );
    final leaderboard = report['leaderboard']! as Map<String, Object?>;
    final cells = leaderboard['taskModelCells']! as Map<String, Object?>;
    expect(cells['cellCount'], 0);
    expect(cells['expectedCellCount'], 1);
    expect(cells['missingCellCount'], 1);
  });

  test(
    'blocks report when leaderboard model identity metadata is invalid',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_model_identity_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      final leaderboard = _leaderboardJson(sampleCount: 2);
      final modelRows = (leaderboard['models']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final taskModelCells = (leaderboard['taskModelCells']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final trialSummaries = (leaderboard['trialSummaries']! as List<Object?>)
          .cast<Map<String, Object?>>();
      modelRows.first['baseModelId'] = 'gpt-4';
      taskModelCells.first.remove('modelConfig');
      trialSummaries.first['modelConfig'] = {'effort': 'high'};
      await File(leaderboardPath).writeAsString(_prettyJson(leaderboard));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-model-identity-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 3, 20, 30),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Leaderboard model identity metadata is invalid for 3 public row(s).',
        ),
      );
      final leaderboardSummary = report['leaderboard']! as Map<String, Object?>;
      final modelIdentity =
          leaderboardSummary['modelIdentity']! as Map<String, Object?>;
      expect(modelIdentity['status'], 'invalid');
      expect(modelIdentity['invalidModelRowCount'], 1);
      expect(modelIdentity['invalidTaskModelCellCount'], 1);
      expect(modelIdentity['invalidTrialSummaryCount'], 1);
      expect(modelIdentity['invalidModelIdentityCount'], 3);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final reportingGate =
          readinessGates['reporting']! as Map<String, Object?>;
      expect(reportingGate['status'], 'blocked');
      expect(reportingGate['modelIdentityStatus'], 'invalid');
      expect(reportingGate['invalidModelIdentityCount'], 3);
      expect(reportingGate['invalidModelIdentityModelRowCount'], 1);
      expect(reportingGate['invalidModelIdentityTaskModelCellCount'], 1);
      expect(reportingGate['invalidModelIdentityTrialSummaryCount'], 1);
    },
  );

  test('blocks report when trial summaries are missing', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_trial_summaries_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(leaderboardPath).writeAsString(
      _prettyJson(
        _leaderboardJson(sampleCount: 2, includeTrialSummaries: false),
      ),
    );
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-trial-summaries-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 3, 21),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Leaderboard export has incomplete trial summary metadata'),
    );
    expect(
      blockers,
      contains('Leaderboard trial summary total does not match taskRunCount'),
    );
    final leaderboard = report['leaderboard']! as Map<String, Object?>;
    final transparency =
        leaderboard['trialTransparency']! as Map<String, Object?>;
    expect(transparency['trialSummaryCount'], 0);
    expect(transparency['trialSummaryTotalCount'], 0);
  });

  test('blocks report when trial trace metrics are incomplete', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_trial_trace_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(leaderboardPath).writeAsString(
      _prettyJson(_leaderboardJson(sampleCount: 2, includeTraceMetrics: false)),
    );
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-trial-trace-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 3, 22),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(blockers, contains('Leaderboard task-model cells have 1 cell(s)'));
    expect(blockers, contains('Leaderboard trial summaries have 2 trial(s)'));
    final leaderboard = report['leaderboard']! as Map<String, Object?>;
    final transparency =
        leaderboard['trialTransparency']! as Map<String, Object?>;
    expect(transparency['missingMetricTrialCount'], 2);
  });

  test(
    'allows explicitly unknown public telemetry without missing metrics',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_unknown_public_telemetry_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      final leaderboard =
          jsonDecode(jsonEncode(_leaderboardJson(sampleCount: 2)))
              as Map<String, Object?>;
      _markLeaderboardPublicTelemetryUnknown(leaderboard);
      await File(leaderboardPath).writeAsString(_prettyJson(leaderboard));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-unknown-public-telemetry',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 3, 22),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(blockers, isNot(contains('Leaderboard task-model cells have')));
      expect(blockers, isNot(contains('Leaderboard trial summaries have')));
      final warnings = (report['warnings']! as List<Object?>).join('\n');
      expect(warnings, contains('unknown agent trace metrics'));
      expect(warnings, contains('unknown token usage'));
      final leaderboardSummary = report['leaderboard']! as Map<String, Object?>;
      final cells =
          leaderboardSummary['taskModelCells']! as Map<String, Object?>;
      expect(cells['missingMetricCellCount'], 0);
      expect(cells['unknownTraceMetricCellCount'], 1);
      expect(cells['unknownTokenUsageCellCount'], 1);
      final transparency =
          leaderboardSummary['trialTransparency']! as Map<String, Object?>;
      expect(transparency['missingMetricTrialCount'], 0);
      expect(transparency['unknownTraceMetricTrialCount'], 2);
      expect(transparency['unknownTokenUsageTrialCount'], 2);
    },
  );

  test('blocks report when confidence intervals are missing', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_confidence_intervals_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(leaderboardPath).writeAsString(
      _prettyJson(
        _leaderboardJson(sampleCount: 2, includeConfidenceIntervals: false),
      ),
    );
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-confidence-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 3, 23, 30),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Leaderboard confidence intervals are missing or incomplete'),
    );
    final leaderboard = report['leaderboard']! as Map<String, Object?>;
    final transparency =
        leaderboard['trialTransparency']! as Map<String, Object?>;
    expect(transparency['missingModelConfidenceIntervalCount'], 1);
    expect(transparency['missingTaskConfidenceIntervalCount'], 1);
    expect(transparency['missingCellConfidenceIntervalCount'], 1);
  });

  test('blocks report when benchmark release metadata is missing', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_benchmark_metadata_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(leaderboardPath).writeAsString(
      _prettyJson(
        _leaderboardJson(
          sampleCount: 2,
          includeBenchmarkReleaseMetadata: false,
        ),
      ),
    );
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-benchmark-metadata-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 2),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Leaderboard benchmark version metadata is missing.'),
    );
    expect(
      blockers,
      contains('Leaderboard benchmark task set id metadata is missing.'),
    );
    expect(
      blockers,
      contains(
        'Leaderboard benchmark evaluator schema version metadata is missing.',
      ),
    );
    final benchmark =
        (report['leaderboard']! as Map<String, Object?>)['benchmark']!
            as Map<String, Object?>;
    expect(benchmark['version'], null);
    expect(benchmark['taskSetId'], null);
    expect(benchmark['evaluatorSchemaVersion'], 0);
  });

  test('blocks report when benchmark evaluator schema is stale', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_benchmark_evaluator_schema_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    final leaderboard = _leaderboardJson(sampleCount: 2);
    final benchmark = leaderboard['benchmark']! as Map<String, Object?>;
    benchmark['evaluatorSchemaVersion'] = 1;
    await File(leaderboardPath).writeAsString(_prettyJson(leaderboard));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-benchmark-evaluator-schema-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 4, 2, 1),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Leaderboard benchmark evaluator schema version is stale.'),
    );
    final reportBenchmark =
        (report['leaderboard']! as Map<String, Object?>)['benchmark']!
            as Map<String, Object?>;
    expect(reportBenchmark['evaluatorSchemaVersion'], 1);
  });

  test('blocks report when scoring metadata is missing', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_scoring_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(leaderboardPath).writeAsString(
      _prettyJson(_leaderboardJson(sampleCount: 2, includeScoring: false)),
    );
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-scoring-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 3, 23, 45),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Leaderboard export has incomplete scoring metadata'),
    );
  });

  test('blocks report when scoring schema is stale', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_scoring_schema_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    final leaderboard = _leaderboardJson(sampleCount: 2);
    final scoring = leaderboard['scoring']! as Map<String, Object?>;
    scoring['schemaVersion'] = 1;
    scoring.remove('diffSizePolicy');
    scoring.remove('diagnosticOnlyEvaluatorIds');
    await File(leaderboardPath).writeAsString(_prettyJson(leaderboard));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(reportPath).writeAsString(_prettyJson(_taskQaReportJson()));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-scoring-schema-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 3, 23, 46),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(blockers, contains('Leaderboard scoring schema version is stale.'));
    final readinessGates = report['readinessGates']! as Map<String, Object?>;
    final scoringGate = readinessGates['scoring']! as Map<String, Object?>;
    expect(scoringGate['status'], 'blocked');
    expect(scoringGate['diffSizePolicy'], null);
    expect(scoringGate['diffSizeDiagnosticOnly'], isFalse);
  });

  test(
    'blocks report when loaded task QA report lacks verifier audit evidence',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_verifier_audit_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            includeHiddenDigests: false,
            includeNegativeCases: false,
            includePromptSafety: false,
          ),
        ),
      );
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-audit-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 3, 18),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Task task.a@v1 has no hidden verifier digest metadata'),
      );
      expect(
        blockers,
        contains('Task task.a@v1 has no loaded negative-case audit entries'),
      );
      expect(
        blockers,
        contains('Task task.a@v1 has no verifier-quality audit summary'),
      );
      expect(
        blockers,
        contains('Task QA report task.a@v1 has no prompt-safety evidence.'),
      );
      final audit = report['verifierAudit']! as Map<String, Object?>;
      expect(audit['tasksMissingHiddenVerifierDigests'], [
        {'taskId': 'task.a', 'taskVersion': 1},
      ]);
      final negativeCases = audit['negativeCases']! as Map<String, Object?>;
      expect(negativeCases['tasksMissingNegativeCases'], [
        {'taskId': 'task.a', 'taskVersion': 1},
      ]);
      final quality = audit['quality']! as Map<String, Object?>;
      expect(quality['tasksMissingVerifierQualityAudit'], [
        {'taskId': 'task.a', 'taskVersion': 1},
      ]);
      final promptSafety = audit['promptSafety']! as Map<String, Object?>;
      expect(promptSafety['missingCount'], 1);
      expect(promptSafety['tasksMissingPromptSafety'], [
        {'taskId': 'task.a', 'taskVersion': 1},
      ]);
    },
  );

  test(
    'blocks report when loaded task QA hidden verifier digests are malformed',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_hidden_digest_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            hiddenDigestsOverride: {
              'hidden_test': 'abc123',
              'hidden_reference': _artifactFixtureSha256,
            },
          ),
        ),
      );
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-hidden-digest-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3, 20),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains('Task task.a@v1 has invalid hidden verifier digest metadata.'),
      );
      final audit = report['verifierAudit']! as Map<String, Object?>;
      expect(audit['hiddenVerifierDigestCount'], 1);
      expect(audit['invalidHiddenVerifierDigestCount'], 1);
      expect(audit['tasksWithInvalidHiddenVerifierDigests'], [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'verifierId': 'hidden_test',
          'status': 'invalid',
        },
      ]);
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['hiddenVerifierDigestCount'], 1);
      expect(corpusGate['invalidHiddenVerifierDigestCount'], 1);
    },
  );

  test(
    'blocks report when loaded task QA verifier quality summary is inconsistent',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_quality_consistency_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            verifierQualityAuditOverride: {
              'acceptedNegativeCaseCount': 'zero',
              'negativeCaseCount': 2,
            },
          ),
        ),
      );
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-quality-consistency-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3, 30),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 verifier-quality field acceptedNegativeCaseCount is invalid.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 verifier-quality field negativeCaseCount does not match loaded evidence.',
        ),
      );
      final audit = report['verifierAudit']! as Map<String, Object?>;
      final qualityConsistency =
          audit['qualityConsistency']! as Map<String, Object?>;
      expect(qualityConsistency['invalidFieldCount'], 1);
      expect(qualityConsistency['mismatchCount'], 1);
      expect(
        qualityConsistency['tasksWithVerifierQualityIssues'],
        contains(
          isA<Map<String, Object?>>()
              .having(
                (issue) => issue['field'],
                'field',
                'acceptedNegativeCaseCount',
              )
              .having((issue) => issue['status'], 'status', 'invalid'),
        ),
      );
      expect(
        qualityConsistency['tasksWithVerifierQualityIssues'],
        contains(
          isA<Map<String, Object?>>()
              .having((issue) => issue['field'], 'field', 'negativeCaseCount')
              .having((issue) => issue['status'], 'status', 'mismatch')
              .having((issue) => issue['expected'], 'expected', 3)
              .having((issue) => issue['actual'], 'actual', 2),
        ),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['invalidVerifierQualityFieldCount'], 1);
      expect(corpusGate['verifierQualityMismatchCount'], 1);
    },
  );

  test(
    'blocks report when loaded task QA negative-case evidence is malformed',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'release_report_negative_case_integrity_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
      final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
      await taskQaDir.create(recursive: true);
      final taskQaSummaryPath = p.join(
        taskQaDir.path,
        'admission_summary.json',
      );
      final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
      await Directory(p.dirname(reportPath)).create(recursive: true);
      await File(
        leaderboardPath,
      ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
      await File(
        taskQaSummaryPath,
      ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
      await File(reportPath).writeAsString(
        _prettyJson(
          _taskQaReportJson(
            negativeCasesOverride: [
              {
                'kind': 'unsupported',
                'prepare_passed': true,
                'public_passed': true,
                'hidden_passed': true,
                'rejected': true,
              },
              {
                'id': 'missing_hidden',
                'kind': 'noop',
                'prepare_passed': true,
                'public_passed': true,
                'rejected': true,
              },
            ],
            verifierQualityAuditOverride: {
              'negativeCaseCount': 2,
              'acceptedNegativeCaseCount': 0,
              'falsePositiveCount': 0,
              'disagreementCount': 0,
            },
          ),
        ),
      );
      final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
      await _seedDatabase(databasePath);
      final outPath = p.join(tmp.path, 'release_report.v1.json');
      final stderrLines = <String>[];

      final exitCode = await runReleaseReportCli(
        [
          '--leaderboard',
          leaderboardPath,
          '--task-qa-summary',
          taskQaSummaryPath,
          '--database',
          databasePath,
          '--out',
          outPath,
          '--release-id',
          '2026-06-negative-case-integrity-gated',
          '--fail-on-blocked',
        ],
        dependencies: ReleaseReportCliDependencies(
          now: () => DateTime.utc(2026, 6, 4, 3, 40),
        ),
        stdoutWriter: (_) {},
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('"status":"blocked"'));
      final report =
          jsonDecode(await File(outPath).readAsString())
              as Map<String, Object?>;
      final blockers = (report['blockers']! as List<Object?>).join('\n');
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 has malformed negative-case evidence.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 has unsupported negative-case kind metadata.',
        ),
      );
      expect(
        blockers,
        contains(
          'Task QA report task.a@v1 negative-case rejection does not match loaded outcomes.',
        ),
      );
      final audit = report['verifierAudit']! as Map<String, Object?>;
      final negativeCases = audit['negativeCases']! as Map<String, Object?>;
      expect(negativeCases['malformedEvidenceCount'], 2);
      expect(negativeCases['unsupportedKindCount'], 1);
      expect(negativeCases['outcomeMismatchCount'], 1);
      expect(
        negativeCases['tasksWithNegativeCaseEvidenceIssues'],
        contains(
          isA<Map<String, Object?>>().having(
            (issue) => issue['status'],
            'status',
            'missing_id',
          ),
        ),
      );
      expect(
        negativeCases['tasksWithNegativeCaseEvidenceIssues'],
        contains(
          isA<Map<String, Object?>>()
              .having((issue) => issue['status'], 'status', 'unsupported_kind')
              .having((issue) => issue['kind'], 'kind', 'unsupported'),
        ),
      );
      expect(
        negativeCases['tasksWithNegativeCaseEvidenceIssues'],
        contains(
          isA<Map<String, Object?>>()
              .having(
                (issue) => issue['status'],
                'status',
                'missing_outcome_field',
              )
              .having(
                (issue) => issue['negativeCaseId'],
                'negativeCaseId',
                'missing_hidden',
              ),
        ),
      );
      final readinessGates = report['readinessGates']! as Map<String, Object?>;
      final corpusGate = readinessGates['corpus']! as Map<String, Object?>;
      expect(corpusGate['status'], 'blocked');
      expect(corpusGate['malformedNegativeCaseEvidenceCount'], 2);
      expect(corpusGate['unsupportedNegativeCaseKindCount'], 1);
      expect(corpusGate['negativeCaseOutcomeMismatchCount'], 1);
    },
  );

  test('blocks report when verifier audit records false positives', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'release_report_false_positive_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
    final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
    await taskQaDir.create(recursive: true);
    final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
    final reportPath = p.join(taskQaDir.path, 'tasks', 'a', 'report.json');
    await Directory(p.dirname(reportPath)).create(recursive: true);
    await File(
      leaderboardPath,
    ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 2)));
    await File(
      taskQaSummaryPath,
    ).writeAsString(_prettyJson(_taskQaSummaryJson(reportPath: reportPath)));
    await File(
      reportPath,
    ).writeAsString(_prettyJson(_taskQaReportJson(falsePositiveCount: 1)));
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'release_report.v1.json');
    final stderrLines = <String>[];

    final exitCode = await runReleaseReportCli(
      [
        '--leaderboard',
        leaderboardPath,
        '--task-qa-summary',
        taskQaSummaryPath,
        '--database',
        databasePath,
        '--out',
        outPath,
        '--release-id',
        '2026-06-false-positive-gated',
        '--fail-on-blocked',
      ],
      dependencies: ReleaseReportCliDependencies(
        now: () => DateTime.utc(2026, 6, 3, 23),
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('"status":"blocked"'));
    final report =
        jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
    final blockers = (report['blockers']! as List<Object?>).join('\n');
    expect(
      blockers,
      contains('Verifier audit found 1 false-positive acceptance'),
    );
    final audit = report['verifierAudit']! as Map<String, Object?>;
    final quality = audit['quality']! as Map<String, Object?>;
    expect(quality['falsePositiveCount'], 1);
  });
}

Map<String, Object?> _leaderboardJson({
  required int sampleCount,
  bool includeJudgeOverhead = true,
  bool includeSourceRunProvenance = true,
  bool includeTaskModelCells = true,
  bool includeTrialSummaries = true,
  bool includeTraceMetrics = true,
  bool includeConfidenceIntervals = true,
  bool includeScoring = true,
  bool includeBenchmarkReleaseMetadata = true,
  bool trialPrimaryPass = true,
  String trialFailureTag = 'pass',
  double trialAggregateScore = 1.0,
}) => {
  'schemaVersion': 1,
  'generatedAt': '2026-06-03T12:00:00.000Z',
  'benchmark': {
    'name': 'PickArena',
    'brand': 'Pickforge Studio',
    'title': 'PickArena by Pickforge Studio',
    if (includeBenchmarkReleaseMetadata) ...{
      'version': '2026-05-31-master-spec',
      'taskSetId': 'taskset-test',
      'evaluatorSchemaVersion': 2,
    },
    'track': 'agentic',
    'dataPolicy': 'aggregate-compatible',
  },
  'source': {
    'anchorRunId': 'run-1',
    'runIds': ['run-1'],
    'taskCount': 1,
    'taskRunCount': sampleCount,
    'modelCount': 1,
    if (includeTrialSummaries) ...{
      'trialSummaryCount': sampleCount,
      'trialSummaryTotalCount': sampleCount,
      'trialSummaryTruncated': false,
      'trialSummaryLimit': 1000,
    },
    'warnings': <String>[],
    if (includeJudgeOverhead)
      'judgeOverhead': {
        'evaluationCount': 1,
        'promptTokens': 100,
        'completionTokens': 20,
        'knownEstimatedCostCount': 1,
        'unknownEstimatedCostCount': 0,
        'totalEstimatedCostMicros': 325,
        'pricingStatusCounts': {'exact': 1},
      },
    if (includeSourceRunProvenance)
      'runProvenance': {
        'runCount': 1,
        'embeddedRunCount': 1,
        'sandboxEnforcedRunCount': 1,
        'taskExecutionPolicyRunCount': 1,
        'networkDisabledTaskPolicyRunCount': 1,
        'taskResourceLimitRunCount': 1,
        'sdkVersionRunCount': 1,
        'dependencySnapshotRunCount': 1,
        'pricingRegistryRunCount': 1,
        'generatedCodeSandboxBackends': ['test-sandbox'],
        'dartVersions': ['3.9.0'],
        'flutterVersions': ['3.35.0'],
        'environmentIds': ['test-env-1'],
        'warnings': <String>[],
      },
  },
  if (includeScoring) 'scoring': _scoringJson(),
  'models': [
    {
      'providerId': 'openai',
      'modelId': 'gpt-5',
      ..._modelIdentityJson(),
      'trialCount': sampleCount,
      'sampleCount': sampleCount,
      'passRate': 1.0,
      'passCount': sampleCount,
      'passAtK': {
        '1': {'k': 1, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
        if (sampleCount >= 2)
          '2': {'k': 2, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
      },
      if (includeConfidenceIntervals)
        'confidenceInterval': {'lower': 0.3424, 'upper': 1.0},
      if (includeTraceMetrics) ...{
        'medianStepCount': 8,
        'medianPeakContextTokens': 12000,
        'traceMetricCoverage': {
          'sampleCount': sampleCount,
          'stepCountKnownCount': sampleCount,
          'stepCountUnknownCount': 0,
          'peakContextTokensKnownCount': sampleCount,
          'peakContextTokensUnknownCount': 0,
          'completeTraceMetricCount': sampleCount,
        },
      },
      'tokenUsageCoverage': {
        'sampleCount': sampleCount,
        'promptTokensKnownCount': sampleCount,
        'promptTokensUnknownCount': 0,
        'completionTokensKnownCount': sampleCount,
        'completionTokensUnknownCount': 0,
        'completeTokenUsageCount': sampleCount,
      },
      'unknownEstimatedCostCount': 0,
    },
  ],
  'tasks': [
    {
      'taskId': 'task.a',
      'taskVersion': 1,
      'benchmarkTrack': 'agentic',
      'trialCount': sampleCount,
      'sampleCount': sampleCount,
      'passRate': 1.0,
      'passAtK': {
        '1': {'k': 1, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
        if (sampleCount >= 2)
          '2': {'k': 2, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
      },
      if (includeConfidenceIntervals)
        'confidenceInterval': {'lower': 0.3424, 'upper': 1.0},
      if (includeTraceMetrics) ...{
        'medianStepCount': 8,
        'medianPeakContextTokens': 12000,
        'traceMetricCoverage': {
          'sampleCount': sampleCount,
          'stepCountKnownCount': sampleCount,
          'stepCountUnknownCount': 0,
          'peakContextTokensKnownCount': sampleCount,
          'peakContextTokensUnknownCount': 0,
          'completeTraceMetricCount': sampleCount,
        },
      },
      'tokenUsageCoverage': {
        'sampleCount': sampleCount,
        'promptTokensKnownCount': sampleCount,
        'promptTokensUnknownCount': 0,
        'completionTokensKnownCount': sampleCount,
        'completionTokensUnknownCount': 0,
        'completeTokenUsageCount': sampleCount,
      },
    },
  ],
  if (includeTaskModelCells)
    'taskModelCells': [
      {
        'providerId': 'openai',
        'modelId': 'gpt-5',
        ..._modelIdentityJson(),
        'taskId': 'task.a',
        'taskVersion': 1,
        'benchmarkTrack': 'agentic',
        'trialCount': sampleCount,
        'passCount': sampleCount,
        'sampleCount': sampleCount,
        'passRate': 1.0,
        if (includeConfidenceIntervals)
          'confidenceInterval': {'lower': 0.3424, 'upper': 1.0},
        'errorCount': 0,
        'passAtK': {
          '1': {'k': 1, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
          if (sampleCount >= 2)
            '2': {'k': 2, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
        },
        if (includeTraceMetrics) ...{
          'medianStepCount': 8,
          'medianPeakContextTokens': 12000,
          'traceMetricCoverage': {
            'sampleCount': sampleCount,
            'stepCountKnownCount': sampleCount,
            'stepCountUnknownCount': 0,
            'peakContextTokensKnownCount': sampleCount,
            'peakContextTokensUnknownCount': 0,
            'completeTraceMetricCount': sampleCount,
          },
        },
        'tokenUsageCoverage': {
          'sampleCount': sampleCount,
          'promptTokensKnownCount': sampleCount,
          'promptTokensUnknownCount': 0,
          'completionTokensKnownCount': sampleCount,
          'completionTokensUnknownCount': 0,
          'completeTokenUsageCount': sampleCount,
        },
        'publicPassCount': sampleCount,
        'publicSampleCount': sampleCount,
        'publicPassRate': 1.0,
        'hiddenPassCount': sampleCount,
        'hiddenSampleCount': sampleCount,
        'hiddenPassRate': 1.0,
        'blockedEvaluationCount': 0,
        'blockedTaskRunCount': 0,
        'medianLatencyMs': 1000,
        'medianPromptTokens': 10,
        'medianCompletionTokens': 20,
        'medianEstimatedCostMicros': 213,
        'knownEstimatedCostCount': sampleCount,
        'unknownEstimatedCostCount': 0,
        'failureBreakdown': {'pass': sampleCount},
      },
    ],
  if (includeTrialSummaries)
    'trialSummaries': [
      for (var i = 0; i < sampleCount; i++)
        {
          'trialId': 'trial-${i + 1}',
          'runId': 'run-1',
          'providerId': 'openai',
          'modelId': 'gpt-5',
          ..._modelIdentityJson(),
          'taskId': 'task.a',
          'taskVersion': 1,
          'benchmarkTrack': 'agentic',
          'trialIndex': i,
          'completedAt': '2026-06-03T12:0$i:00.000Z',
          'primaryPass': trialPrimaryPass,
          'failureTag': trialFailureTag,
          'aggregateScore': trialAggregateScore,
          'publicPassed': true,
          'hiddenPassed': true,
          'blockedEvaluationCount': 0,
          if (includeTraceMetrics) ...{
            'stepCount': 8,
            'peakContextTokens': 12000,
            'traceMetricStatus': {
              'stepCount': 'reported',
              'peakContextTokens': 'reported',
            },
          },
          'latencyMs': 1000,
          'promptTokens': 10,
          'completionTokens': 20,
          'tokenUsageStatus': {
            'promptTokens': 'reported',
            'completionTokens': 'reported',
          },
          'estimatedCostMicros': 213,
        },
    ],
};

Map<String, Object?> _multiRunLeaderboardJson() {
  final leaderboard =
      jsonDecode(jsonEncode(_leaderboardJson(sampleCount: 4)))
          as Map<String, Object?>;
  final source = leaderboard['source']! as Map<String, Object?>;
  source['anchorRunId'] = 'run-2';
  source['runIds'] = ['run-1', 'run-2'];
  final runProvenance = source['runProvenance']! as Map<String, Object?>;
  for (final key in [
    'runCount',
    'embeddedRunCount',
    'sandboxEnforcedRunCount',
    'taskExecutionPolicyRunCount',
    'networkDisabledTaskPolicyRunCount',
    'taskResourceLimitRunCount',
    'sdkVersionRunCount',
    'dependencySnapshotRunCount',
    'pricingRegistryRunCount',
  ]) {
    runProvenance[key] = 2;
  }

  final trialSummaries = source['trialSummaryCount'] == null
      ? const <Object?>[]
      : leaderboard['trialSummaries']! as List<Object?>;
  for (var i = 0; i < trialSummaries.length; i++) {
    final trial = trialSummaries[i]! as Map<String, Object?>;
    final runId = i < 2 ? 'run-1' : 'run-2';
    final trialIndex = i % 2;
    trial['trialId'] = 'trial-$runId-${trialIndex + 1}';
    trial['runId'] = runId;
    trial['trialIndex'] = trialIndex;
    trial['completedAt'] =
        '2026-06-03T12:${i.toString().padLeft(2, '0')}:00.000Z';
  }
  return leaderboard;
}

void _markLeaderboardPublicTelemetryUnknown(Map<String, Object?> leaderboard) {
  const sampleCount = 2;
  final unknownTraceCoverage = {
    'sampleCount': sampleCount,
    'stepCountKnownCount': 0,
    'stepCountUnknownCount': sampleCount,
    'peakContextTokensKnownCount': 0,
    'peakContextTokensUnknownCount': sampleCount,
    'completeTraceMetricCount': 0,
  };
  final unknownTokenCoverage = {
    'sampleCount': sampleCount,
    'promptTokensKnownCount': 0,
    'promptTokensUnknownCount': sampleCount,
    'completionTokensKnownCount': 0,
    'completionTokensUnknownCount': sampleCount,
    'completeTokenUsageCount': 0,
  };

  for (final row in [
    ...(leaderboard['models']! as List<Object?>),
    ...(leaderboard['tasks']! as List<Object?>),
    ...(leaderboard['taskModelCells']! as List<Object?>),
  ]) {
    final map = row! as Map<String, Object?>;
    map['medianStepCount'] = null;
    map['medianPeakContextTokens'] = null;
    map['traceMetricCoverage'] = Map<String, Object?>.of(unknownTraceCoverage);
    map['medianPromptTokens'] = null;
    map['medianCompletionTokens'] = null;
    map['tokenUsageCoverage'] = Map<String, Object?>.of(unknownTokenCoverage);
    if (map.containsKey('knownEstimatedCostCount')) {
      map['knownEstimatedCostCount'] = 0;
      map['unknownEstimatedCostCount'] = sampleCount;
      map['medianEstimatedCostMicros'] = null;
    }
  }

  for (final row in leaderboard['trialSummaries']! as List<Object?>) {
    final trial = row! as Map<String, Object?>;
    trial['stepCount'] = null;
    trial['peakContextTokens'] = null;
    trial['traceMetricStatus'] = {
      'stepCount': 'unknown',
      'peakContextTokens': 'unknown',
    };
    trial['promptTokens'] = null;
    trial['completionTokens'] = null;
    trial['tokenUsageStatus'] = {
      'promptTokens': 'unknown',
      'completionTokens': 'unknown',
    };
    trial['estimatedCostMicros'] = null;
  }
}

Map<String, Object?> _scoringJson() => {
  'schemaVersion': 2,
  'primaryMetric': 'primary_pass',
  'rankingMetric': 'primary_pass_rate',
  'confidenceInterval': 'wilson_95',
  'llmJudgePolicy': 'diagnostic_only',
  'diffSizePolicy': 'diagnostic_only_full_patch',
  'objectiveEvaluatorIds': [
    'analyze',
    'compile',
    'hidden_test',
    'test',
    'test_author',
    'widget_tree',
  ],
  'secondaryEvaluatorIds': ['diff_size', 'llm_judge'],
  'diagnosticOnlyEvaluatorIds': ['diff_size'],
  'hiddenVerifierPattern': '*_hidden',
  'failureTags': [
    'pass',
    'hidden_verifier_failed',
    'public_tests_failed',
    'analysis_failed',
    'compile_failed',
    'harness_timeout',
    'harness_error',
    'no_patch',
    'invalid_output',
    'environment_error',
    'unknown',
  ],
  'objectiveFailureCaps': {
    'compile': 0.2,
    'analyze': 0.35,
    'public_test': 0.6,
    'hidden_verifier': 0.6,
  },
  'defaultEvaluatorWeights': {
    'analyze': 0.5,
    'compile': 0.5,
    'hidden_test': 1.0,
    'llm_judge': 0.7,
    'test': 1.0,
    'test_author': 4.0,
    'widget_tree': 1.0,
  },
};

Map<String, Object?> _modelIdentityJson() => {
  'baseModelId': 'gpt-5',
  'modelConfig': {
    'maxOutputTokens': 16384,
    'temperature': {'configured': false, 'status': 'provider_default'},
    'toolPolicy': 'none',
  },
};

Map<String, Object?> _fullyEnforcedResourcePolicy() => const {
  'cpus': {'enforced': true, 'mechanism': 'cpuQuota', 'kernelEnforced': true},
  'memoryMb': {
    'enforced': true,
    'mechanism': 'memoryLimit',
    'kernelEnforced': true,
  },
  'maxProcesses': {
    'enforced': true,
    'mechanism': 'processLimit',
    'kernelEnforced': true,
  },
  'maxOutputBytes': {
    'enforced': true,
    'mechanism': 'boundedOutputCapture',
    'kernelEnforced': false,
  },
};

Map<String, Object?> _taskQaSummaryJson({
  required String reportPath,
  bool preserveReportPath = false,
  Object? failureCount = 0,
  String generatedAt = '2026-06-03T12:10:00.000Z',
}) => {
  'schemaVersion': 1,
  'status': 'completed',
  'generatedAt': generatedAt,
  'taskCount': 1,
  'admittedTaskCount': 1,
  'rejectedTaskCount': 0,
  'reports': [
    {
      'taskId': 'task.a',
      'taskVersion': 1,
      'track': 'agentic',
      'status': 'admitted',
      if (failureCount != null) 'failureCount': failureCount,
      'reportPath': preserveReportPath
          ? reportPath
          : _portableTaskQaReportPath(reportPath),
    },
  ],
};

String _portableTaskQaReportPath(String reportPath) {
  final normalized = reportPath.replaceAll('\\', '/');
  final parts = normalized.split('/');
  final taskQaIndex = parts.lastIndexOf('task_qa');
  if (taskQaIndex < 0 || taskQaIndex == parts.length - 1) {
    return normalized;
  }
  return parts.skip(taskQaIndex + 1).join('/');
}

Map<String, Object?> _artifactManifestJson({
  int schemaVersion = 1,
  String? runId = 'run-1',
  bool includeSecondPatch = true,
  bool duplicateFirstTaskRun = false,
  bool duplicateSecondResponseArtifact = false,
  bool includeDebugArtifact = false,
  bool omitSecondTaskMetadata = false,
  int secondTrialIndex = 1,
  int warningCount = 0,
  String warningCode = 'test_bundle_warning',
  Map<String, Object?>? countOverrides,
  String secondPatchPath = 'artifacts/patches/task-run-2.patch',
  String? firstHarnessId = 'droid',
  String? secondHarnessId = 'droid',
  List<String> evaluatorIds = const ['compile', 'test'],
  String? generatedAt = '2026-06-03T12:00:00.000Z',
  String? runName = 'Release smoke run',
  String? runStartedAt = '2026-06-03T11:00:00.000Z',
  String? runCompletedAt = '2026-06-03T11:55:00.000Z',
  String? appVersion = '1.0.0',
  int driftSchemaVersion = 1,
  Map<String, Object?>? exportTool,
  Map<String, Object?>? exportEnvironment,
  Map<String, Object?>? passSummary,
  Map<String, Object?>? failureSummary,
  bool includeProvenance = true,
  bool provenanceSandboxEnforced = true,
  bool includeProvenanceTaskExecutionPolicy = true,
  bool provenanceTaskAllowInternet = false,
  bool includeProvenanceTaskResourceLimits = true,
  bool useIncompleteProvenanceTaskResourceLimits = false,
  bool includeProvenanceSdkVersions = true,
  bool includeProvenanceDependencySnapshot = true,
  bool includeProvenancePricingRegistry = true,
  String? secondPatchManifestSha256,
}) {
  const artifactSha256 = _artifactFixtureSha256;
  final artifacts = <Map<String, Object?>>[
    {
      'artifactId': _artifactId('task-run-1', 'response'),
      'kind': 'response',
      'taskRunId': 'task-run-1',
      'path': 'artifacts/responses/task-run-1.txt',
      'bytes': 10,
      'sha256': artifactSha256,
    },
    {
      'artifactId': _artifactId('task-run-1', 'patch'),
      'kind': 'patch',
      'taskRunId': 'task-run-1',
      'path': 'artifacts/patches/task-run-1.patch',
      'bytes': 10,
      'sha256': artifactSha256,
    },
    {
      'artifactId': _artifactId('task-run-2', 'response'),
      'kind': 'response',
      'taskRunId': 'task-run-2',
      'path': 'artifacts/responses/task-run-2.txt',
      'bytes': 10,
      'sha256': artifactSha256,
    },
    if (duplicateSecondResponseArtifact)
      {
        'artifactId': _artifactId('task-run-2', 'response'),
        'kind': 'response',
        'taskRunId': 'task-run-2',
        'path': 'artifacts/responses/task-run-2.txt',
        'bytes': 10,
        'sha256': artifactSha256,
      },
    if (includeSecondPatch)
      {
        'artifactId': _artifactId('task-run-2', 'patch'),
        'kind': 'patch',
        'taskRunId': 'task-run-2',
        'path': secondPatchPath,
        'bytes': 10,
        'sha256': secondPatchManifestSha256 ?? artifactSha256,
      },
    if (includeDebugArtifact)
      {
        'artifactId': _artifactId('task-run-2', 'debug'),
        'kind': 'debug',
        'taskRunId': 'task-run-2',
        'path': 'artifacts/trajectories/task-run-2-debug.log',
        'bytes': 10,
        'sha256': artifactSha256,
      },
  ];
  final warnings = [
    for (var i = 0; i < warningCount; i++)
      {
        'code': warningCode,
        'message': 'Test bundle warning ${i + 1}.',
        'taskRunId': 'task-run-2',
      },
  ];
  final firstTaskRun = {
    'taskRunId': 'task-run-1',
    'taskId': 'task.a',
    'providerId': 'openai',
    'modelId': 'gpt-5',
    ..._modelIdentityJson(),
    'trialIndex': 0,
    'taskVersion': 1,
    'benchmarkTrack': 'agentic',
    if (firstHarnessId != null) 'harnessId': firstHarnessId,
  };
  final taskRuns = [
    firstTaskRun,
    if (duplicateFirstTaskRun) firstTaskRun,
    {
      'taskRunId': 'task-run-2',
      if (!omitSecondTaskMetadata) 'taskId': 'task.a',
      if (!omitSecondTaskMetadata) 'providerId': 'openai',
      if (!omitSecondTaskMetadata) 'modelId': 'gpt-5',
      if (!omitSecondTaskMetadata) ..._modelIdentityJson(),
      if (!omitSecondTaskMetadata) 'trialIndex': secondTrialIndex,
      if (!omitSecondTaskMetadata) 'taskVersion': 1,
      if (!omitSecondTaskMetadata) 'benchmarkTrack': 'agentic',
      if (!omitSecondTaskMetadata && secondHarnessId != null)
        'harnessId': secondHarnessId,
    },
  ];
  final counts = {
    'taskRunCount': taskRuns.length,
    'taskCount': 1,
    'providerCount': 1,
    'modelCount': 1,
    'evaluationCount': taskRuns.length * 2,
    'artifactCount': artifacts.length,
    'warningCount': warnings.length,
    if (countOverrides != null) ...countOverrides,
  };
  return {
    'schemaVersion': schemaVersion,
    if (generatedAt != null) 'generatedAt': generatedAt,
    if (runId != null)
      'run': {
        'id': runId,
        if (runName != null) 'name': runName,
        if (runStartedAt != null) 'startedAt': runStartedAt,
        if (runCompletedAt != null) 'completedAt': runCompletedAt,
      },
    if (appVersion != null) 'appVersion': appVersion,
    'driftSchemaVersion': driftSchemaVersion,
    'exportTool':
        exportTool ??
        const {'name': 'dart_arena_export_bundle', 'version': '1'},
    'environment': exportEnvironment ?? _artifactManifestEnvironmentJson(),
    'counts': counts,
    'evaluatorIds': evaluatorIds,
    'passSummary':
        passSummary ??
        const {
          'primaryPassTrue': 2,
          'primaryPassFalse': 0,
          'primaryPassUnknown': 0,
          'evaluationPassCount': 4,
          'evaluationFailCount': 0,
        },
    'failureSummary': failureSummary ?? const {'pass': 2},
    'checksumsPath': 'checksums.json',
    'taskRuns': taskRuns,
    'artifacts': artifacts,
    'warnings': warnings,
    if (includeProvenance)
      'provenance': _artifactManifestProvenanceJson(
        runId: runId,
        sandboxEnforced: provenanceSandboxEnforced,
        includeTaskExecutionPolicy: includeProvenanceTaskExecutionPolicy,
        taskAllowInternet: provenanceTaskAllowInternet,
        includeTaskResourceLimits: includeProvenanceTaskResourceLimits,
        useIncompleteTaskResourceLimits:
            useIncompleteProvenanceTaskResourceLimits,
        includeSdkVersions: includeProvenanceSdkVersions,
        includeDependencySnapshot: includeProvenanceDependencySnapshot,
        includePricingRegistry: includeProvenancePricingRegistry,
      ),
  };
}

Map<String, Object?> _artifactManifestEnvironmentJson({
  String dartVersion = '3.9.0',
  String flutterVersion = '3.35.0',
  String gitCommit = '0123456789abcdef0123456789abcdef01234567',
  bool gitDirty = false,
  String hostPlatform = 'linux',
  String locale = 'en_US',
  String operatingSystemVersion = 'Linux 6.0.0',
}) => {
  'dartVersion': dartVersion,
  'flutterVersion': flutterVersion,
  'gitCommit': gitCommit,
  'gitDirty': gitDirty,
  'hostPlatform': hostPlatform,
  'locale': locale,
  'operatingSystemVersion': operatingSystemVersion,
};

Map<String, Object?> _artifactManifestProvenanceJson({
  required String? runId,
  bool sandboxEnforced = true,
  bool includeTaskExecutionPolicy = true,
  bool taskAllowInternet = false,
  bool includeTaskResourceLimits = true,
  bool useIncompleteTaskResourceLimits = false,
  bool includeSdkVersions = true,
  bool includeDependencySnapshot = true,
  bool includePricingRegistry = true,
}) => {
  'schemaVersion': 1,
  if (runId != null) 'runId': runId,
  'environment': {
    'workspacePath': '/tmp/dart_arena_test',
    if (includeSdkVersions) ...{
      'dartVersion': '3.9.0',
      'flutterVersion': '3.35.0',
    },
    if (includeDependencySnapshot)
      'dependencySnapshot': {
        'status': 'present',
        'files': {
          'pubspec.lock': {
            'sha256':
                '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            'bytes': 12345,
          },
        },
      },
  },
  'config': {
    'trialsPerTask': 2,
    'generatedCodeSandbox': {
      'required': sandboxEnforced,
      'enforced': sandboxEnforced,
      if (sandboxEnforced) 'backend': 'test-sandbox',
    },
    'evaluatorWeights': {'compile': 1.0},
    if (includePricingRegistry)
      'pricingRegistry': {
        'version': '2026-05-31',
        'currency': 'USD',
        'modelCount': 1,
        'models': {
          'openai:gpt-5': {
            'inputCostPerMToken': 1.25,
            'outputCostPerMToken': 10,
            'source': 'manual',
            'effectiveFrom': '2026-05-31',
          },
        },
      },
  },
  'tasks': [
    {
      'id': 'task.a',
      'version': 1,
      if (includeTaskExecutionPolicy)
        'executionPolicy': {
          'allowInternet': taskAllowInternet,
          if (includeTaskResourceLimits)
            'resources': useIncompleteTaskResourceLimits
                ? {'cpus': 0}
                : {
                    'cpus': 2,
                    'memoryMb': 8192,
                    'maxProcesses': 64,
                    'maxOutputBytes': 1048576,
                  },
          if (includeTaskResourceLimits && !useIncompleteTaskResourceLimits)
            'resourceEnforcement': _fullyEnforcedResourcePolicy(),
        },
    },
  ],
};

const _artifactFileContent = '0123456789';
const _artifactFixtureSha256 =
    '84d89877f0d4041efb6bf91a16f0248f2fd573e6af05c19f96bedb9f882f7882';

String _artifactId(String taskRunId, String kind, [String? sha256Digest]) {
  final source = '$taskRunId\n$kind\n${sha256Digest ?? _artifactFixtureSha256}';
  return 'artifact_${sha256.convert(utf8.encode(source)).toString().substring(0, 16)}';
}

Map<String, Object?> _artifactChecksumsJson({
  int schemaVersion = 1,
  bool includeManifest = true,
  bool includeReport = true,
  bool includeResultsCsv = true,
  bool includeRunResults = true,
  bool includeSecondPatch = true,
  String algorithm = 'sha256',
  String? manifestSha256,
  String secondPatchPath = 'artifacts/patches/task-run-2.patch',
  Map<String, String> standardSha256ByPath = const {},
  List<String> extraPaths = const [],
}) {
  const digest = _artifactFixtureSha256;
  String standardDigest(String path) => standardSha256ByPath[path] ?? digest;
  return {
    'schemaVersion': schemaVersion,
    'algorithm': algorithm,
    'files': [
      if (includeManifest)
        {'path': 'manifest.json', 'sha256': manifestSha256 ?? digest},
      if (includeReport)
        {'path': 'report.md', 'sha256': standardDigest('report.md')},
      if (includeResultsCsv)
        {'path': 'results.csv', 'sha256': standardDigest('results.csv')},
      if (includeRunResults)
        {
          'path': 'run_results.v1.json',
          'sha256': standardDigest('run_results.v1.json'),
        },
      {'path': 'artifacts/responses/task-run-1.txt', 'sha256': digest},
      {'path': 'artifacts/patches/task-run-1.patch', 'sha256': digest},
      {'path': 'artifacts/responses/task-run-2.txt', 'sha256': digest},
      if (includeSecondPatch) {'path': secondPatchPath, 'sha256': digest},
      for (final path in extraPaths) {'path': path, 'sha256': digest},
    ],
  };
}

Future<String> _fileSha256(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();

Future<Map<String, String>> _writeStandardBundleFiles(
  String dir, {
  bool corruptSecondCsvOutcome = false,
  bool unsupportedCsvFailureTag = false,
  bool corruptSecondReportOutcome = false,
  bool unsupportedReportFailureTag = false,
}) async {
  await _writeDefaultArtifactFiles(dir);
  final files = {
    'run_results.v1.json': p.join(dir, 'run_results.v1.json'),
    'results.csv': p.join(dir, 'results.csv'),
    'report.md': p.join(dir, 'report.md'),
  };
  await _writeRunResultsFile(files['run_results.v1.json']!);
  await _writeResultsCsvFile(
    files['results.csv']!,
    corruptSecondOutcome: corruptSecondCsvOutcome,
    unsupportedFailureTag: unsupportedCsvFailureTag,
  );
  await _writeReportMarkdownFile(
    files['report.md']!,
    corruptSecondOutcome: corruptSecondReportOutcome,
    unsupportedFailureTag: unsupportedReportFailureTag,
  );
  return files;
}

Future<void> _writeCompleteArtifactBundle(
  String dir, {
  required String runId,
  int warningCount = 0,
  String warningCode = 'test_bundle_warning',
}) async {
  await Directory(dir).create(recursive: true);
  final manifestPath = p.join(dir, 'manifest.json');
  await File(manifestPath).writeAsString(
    _prettyJson(
      _artifactManifestJson(
        runId: runId,
        warningCount: warningCount,
        warningCode: warningCode,
      ),
    ),
  );
  final manifestSha256 = await _fileSha256(manifestPath);
  final files = await _writeStandardBundleFiles(dir);
  await _writeRunResultsFile(files['run_results.v1.json']!, runId: runId);
  if (runId != 'run-1') {
    final resultsCsvFile = File(files['results.csv']!);
    final resultsCsv = await resultsCsvFile.readAsString();
    await resultsCsvFile.writeAsString(resultsCsv.replaceAll('run-1', runId));
  }
  final standardSha256ByPath = await _standardBundleFileDigests(files);
  await File(p.join(dir, 'checksums.json')).writeAsString(
    _prettyJson(
      _artifactChecksumsJson(
        manifestSha256: manifestSha256,
        standardSha256ByPath: standardSha256ByPath,
      ),
    ),
  );
}

Future<void> _writeDefaultArtifactFiles(String dir) async {
  final paths = [
    'artifacts/responses/task-run-1.txt',
    'artifacts/patches/task-run-1.patch',
    'artifacts/responses/task-run-2.txt',
    'artifacts/patches/task-run-2.patch',
  ];
  for (final path in paths) {
    final file = File(p.join(dir, path));
    await file.parent.create(recursive: true);
    await file.writeAsString(_artifactFileContent);
  }
}

Future<void> _writeReportMarkdownFile(
  String path, {
  bool corruptSecondOutcome = false,
  bool unsupportedFailureTag = false,
}) async {
  final secondPrimaryPass = !(unsupportedFailureTag || corruptSecondOutcome);
  final secondFailureTag = unsupportedFailureTag
      ? 'unsupported_failure'
      : corruptSecondOutcome
      ? 'public_tests_failed'
      : 'pass';
  final secondAggregateScore = unsupportedFailureTag || corruptSecondOutcome
      ? '0.25'
      : '1.00';
  await File(path).writeAsString(
    '# Benchmark run\n'
    '**Test run**\n'
    'Started: `2026-06-03T12:00:00.000`  Task-runs: 2\n'
    '\n'
    '## Leaderboard summary\n'
    '| Provider | Model | Task-runs | Primary Pass | Pass Rate | Wilson 95% | Low Sample | Median Latency | Median Tokens | Median Cost | Cost/Solved | Failures |\n'
    '|----------|-------|-----------|--------------|-----------|------------|------------|----------------|---------------|-------------|-------------|----------|\n'
    '| openai | gpt-5 | 2 | 2/2 | 100% | 34%-100% | yes | 1.0s | 10 in / 20 out | \$0.000213 | \$0.000213 | pass: 2 |\n'
    '\n'
    '## Task runs\n'
    '| Task | Provider | Model | Trial | Task Version | Track | Harness | Primary Pass | Failure | Patch Chars | Trajectory | Aggregate | Public Pass | Hidden Pass | compile | analyze | test | hidden_test | widget_tree | llm_judge | diff_size | Latency |\n'
    '|------|----------|-------|-------|--------------|-------|---------|--------------|---------|-------------|------------|-----------|-------------|-------------|---------|---------|------|-------------|-------------|-----------|-----------|---------|\n'
    '| task.a | openai | gpt-5 | 0 | 1 | agentic |  | true | pass | 10 |  | **1.00** | true | unknown | 1.00 | unknown | 1.00 | unknown | unknown | unknown | unknown | 1000ms |\n'
    '| task.a | openai | gpt-5 | 1 | 1 | agentic |  | $secondPrimaryPass | $secondFailureTag | 10 |  | **$secondAggregateScore** | true | unknown | 1.00 | unknown | 1.00 | unknown | unknown | unknown | unknown | 1000ms |\n',
  );
}

Future<void> _writeResultsCsvFile(
  String path, {
  bool corruptSecondOutcome = false,
  bool unsupportedFailureTag = false,
}) async {
  final secondPrimaryPass = !(unsupportedFailureTag || corruptSecondOutcome);
  final secondFailureTag = unsupportedFailureTag
      ? 'unsupported_failure'
      : corruptSecondOutcome
      ? 'public_tests_failed'
      : 'pass';
  final secondAggregateScore = unsupportedFailureTag
      ? '0.2500'
      : corruptSecondOutcome
      ? '0.2500'
      : '1.0000';
  await File(path).writeAsString(
    'run_id,run_name,started_at,task_id,provider_id,model_id,trial_index,'
    'task_version,benchmark_track,harness_id,primary_pass,failure_tag,'
    'patch_chars,trajectory_log_path,aggregate_score,score_compile,'
    'score_analyze,score_test,score_hidden_test,score_widget_tree,'
    'score_llm_judge,score_diff_size,status_compile,status_analyze,'
    'status_test,status_hidden_test,status_widget_tree,status_llm_judge,'
    'status_diff_size,public_pass,hidden_pass,latency_ms,prompt_tokens,'
    'completion_tokens\n'
    'run-1,Test run,2026-06-03T12:00:00.000,task.a,openai,gpt-5,0,'
    '1,agentic,,true,pass,10,,1.0000,1.0000,,1.0000,,,,,passed,,'
    'passed,,,,,true,,1000,10,20\n'
    'run-1,Test run,2026-06-03T12:01:00.000,task.a,openai,gpt-5,1,'
    '1,agentic,,$secondPrimaryPass,$secondFailureTag,10,,'
    '$secondAggregateScore,1.0000,,1.0000,,,,,passed,,passed,,,,,'
    'true,,1000,10,20\n'
    '\n'
    'leaderboard_summary\n'
    'provider_id,model_id,task_run_count,primary_pass_count,'
    'primary_pass_sample_count,primary_pass_rate,wilson_low,wilson_high,'
    'low_sample,median_latency_ms,median_prompt_tokens,'
    'median_completion_tokens,median_estimated_cost,cost_per_solved_task,'
    'failure_pass,failure_hidden_verifier_failed,'
    'failure_public_tests_failed,failure_analysis_failed,'
    'failure_compile_failed,failure_harness_timeout,failure_harness_error,'
    'failure_no_patch,failure_invalid_output,failure_environment_error,'
    'failure_unknown\n'
    'openai,gpt-5,2,2,2,1.0000,0.3424,1.0000,false,1000,10,20,'
    '0.000213,0.000213,2,0,0,0,0,0,0,0,0,0,0\n',
  );
}

Future<void> _writeRunResultsFile(
  String path, {
  int schemaVersion = 1,
  String? runId = 'run-1',
  String? runName = 'Release smoke run',
  String? runStartedAt = '2026-06-03T11:00:00.000Z',
  String? runCompletedAt = '2026-06-03T11:55:00.000Z',
  String secondPatchPath = 'artifacts/patches/task-run-2.patch',
  Map<String, String> extraSecondArtifacts = const {},
  bool duplicateFirstTaskRun = false,
  bool omitSecondTaskMetadata = false,
  int secondTrialIndex = 1,
  String? secondTaskRunRowRunId,
  bool corruptSecondOutcome = false,
  bool omitSecondEvaluations = false,
  bool duplicateSecondEvaluationId = false,
  bool duplicateEvaluatorIds = false,
  bool outOfRangeEvaluationScore = false,
  bool mismatchedEvaluationStatus = false,
  bool omitSecondEvaluationRationale = false,
  bool corruptSecondEvaluationDetailsMetadata = false,
  bool blockedSecondEvaluation = false,
  bool omitSecondBlockedEvaluationMetadata = false,
  bool includeSecondJudgeOverhead = false,
  bool corruptSecondJudgeOverhead = false,
  bool unsupportedFailureTag = false,
  bool corruptSecondResponseDigest = false,
  bool corruptSecondPatchBytes = false,
  bool omitSecondArtifactMetadata = false,
  bool corruptSecondArtifactMetadataDigest = false,
  String? firstHarnessId = 'droid',
  String? secondHarnessId = 'droid',
  String? firstTaskRunCompletedAt = '2026-06-03T11:30:00.000Z',
  String? secondTaskRunCompletedAt = '2026-06-03T11:40:00.000Z',
  Object? firstLatencyMs = 1000,
  Object? secondLatencyMs = 1000,
  Object? firstPromptTokens = 10,
  Object? secondPromptTokens = 10,
  Object? firstCompletionTokens = 20,
  Object? secondCompletionTokens = 20,
  bool includeAgentHarnessEvaluations = false,
  bool omitAgentHarnessStatusMetadata = false,
  bool corruptAgentHarnessStatusMetadata = false,
}) async {
  const artifactDigest = _artifactFixtureSha256;
  const corruptArtifactDigest =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  final firstPrimaryPass = !unsupportedFailureTag;
  final firstFailureTag = unsupportedFailureTag
      ? 'unsupported_failure'
      : 'pass';
  final firstAggregateScore = unsupportedFailureTag ? 0.25 : 1.0;
  final secondPrimaryPass = !(unsupportedFailureTag || corruptSecondOutcome);
  final secondFailureTag = unsupportedFailureTag
      ? 'unsupported_failure'
      : corruptSecondOutcome
      ? 'public_tests_failed'
      : 'pass';
  final secondAggregateScore = unsupportedFailureTag
      ? 0.25
      : corruptSecondOutcome
      ? 0.25
      : 1.0;
  final firstTaskRun = {
    'id': 'task-run-1',
    if (runId != null) 'runId': runId,
    'taskId': 'task.a',
    'providerId': 'openai',
    'modelId': 'gpt-5',
    ..._modelIdentityJson(),
    'trialIndex': 0,
    'taskVersion': 1,
    'benchmarkTrack': 'agentic',
    if (firstHarnessId != null) 'harnessId': firstHarnessId,
    'primaryPass': firstPrimaryPass,
    'failureTag': firstFailureTag,
    'aggregateScore': firstAggregateScore,
    if (firstTaskRunCompletedAt != null) 'completedAt': firstTaskRunCompletedAt,
    if (firstLatencyMs != null) 'latencyMs': firstLatencyMs,
    'promptTokens': firstPromptTokens,
    'completionTokens': firstCompletionTokens,
    'responseTextSha256': artifactDigest,
    'responseTextBytes': 10,
    'patchTextSha256': artifactDigest,
    'patchTextBytes': 10,
    'artifacts': {
      'response': 'artifacts/responses/task-run-1.txt',
      'patch': 'artifacts/patches/task-run-1.patch',
    },
    'artifactMetadata': _runResultArtifactMetadata(
      taskRunId: 'task-run-1',
      responsePath: 'artifacts/responses/task-run-1.txt',
      patchPath: 'artifacts/patches/task-run-1.patch',
    ),
    'evaluations': _runResultEvaluations(
      'task-run-1',
      includeAgentHarnessEvaluation: includeAgentHarnessEvaluations,
      omitAgentHarnessStatusMetadata: omitAgentHarnessStatusMetadata,
      corruptAgentHarnessStatusMetadata: corruptAgentHarnessStatusMetadata,
      duplicateEvaluatorId: duplicateEvaluatorIds,
      outOfRangeSecondScore: outOfRangeEvaluationScore,
      mismatchedSecondStatus: mismatchedEvaluationStatus,
    ),
  };
  await File(path).writeAsString(
    _prettyJson({
      'schemaVersion': schemaVersion,
      if (runId != null)
        'run': {
          'id': runId,
          if (runName != null) 'name': runName,
          if (runStartedAt != null) 'startedAt': runStartedAt,
          if (runCompletedAt != null) 'completedAt': runCompletedAt,
        },
      'taskRuns': [
        firstTaskRun,
        if (duplicateFirstTaskRun) firstTaskRun,
        {
          'id': 'task-run-2',
          if ((secondTaskRunRowRunId ?? runId) != null)
            'runId': secondTaskRunRowRunId ?? runId,
          if (!omitSecondTaskMetadata) 'taskId': 'task.a',
          if (!omitSecondTaskMetadata) 'providerId': 'openai',
          if (!omitSecondTaskMetadata) 'modelId': 'gpt-5',
          if (!omitSecondTaskMetadata) ..._modelIdentityJson(),
          if (!omitSecondTaskMetadata) 'trialIndex': secondTrialIndex,
          if (!omitSecondTaskMetadata) 'taskVersion': 1,
          if (!omitSecondTaskMetadata) 'benchmarkTrack': 'agentic',
          if (!omitSecondTaskMetadata && secondHarnessId != null)
            'harnessId': secondHarnessId,
          'primaryPass': secondPrimaryPass,
          'failureTag': secondFailureTag,
          'aggregateScore': secondAggregateScore,
          if (secondTaskRunCompletedAt != null)
            'completedAt': secondTaskRunCompletedAt,
          if (secondLatencyMs != null) 'latencyMs': secondLatencyMs,
          'promptTokens': secondPromptTokens,
          'completionTokens': secondCompletionTokens,
          'responseTextSha256': corruptSecondResponseDigest
              ? corruptArtifactDigest
              : artifactDigest,
          'responseTextBytes': 10,
          'patchTextSha256': artifactDigest,
          'patchTextBytes': corruptSecondPatchBytes ? 9 : 10,
          'artifacts': {
            'response': 'artifacts/responses/task-run-2.txt',
            'patch': secondPatchPath,
            ...extraSecondArtifacts,
          },
          if (!omitSecondArtifactMetadata)
            'artifactMetadata': _runResultArtifactMetadata(
              taskRunId: 'task-run-2',
              responsePath: 'artifacts/responses/task-run-2.txt',
              patchPath: secondPatchPath,
              extraArtifacts: extraSecondArtifacts,
              corruptPatchDigest: corruptSecondArtifactMetadataDigest,
            ),
          if (!omitSecondEvaluations)
            'evaluations': _runResultEvaluations(
              'task-run-2',
              includeAgentHarnessEvaluation: includeAgentHarnessEvaluations,
              omitAgentHarnessStatusMetadata: omitAgentHarnessStatusMetadata,
              corruptAgentHarnessStatusMetadata:
                  corruptAgentHarnessStatusMetadata,
              duplicateFirstId: duplicateSecondEvaluationId,
              duplicateEvaluatorId: duplicateEvaluatorIds,
              outOfRangeSecondScore: outOfRangeEvaluationScore,
              mismatchedSecondStatus: mismatchedEvaluationStatus,
              omitSecondRationale: omitSecondEvaluationRationale,
              invalidSecondDetailsMetadata:
                  corruptSecondEvaluationDetailsMetadata,
              blockedSecondEvaluation: blockedSecondEvaluation,
              omitSecondBlockedMetadata: omitSecondBlockedEvaluationMetadata,
              includeSecondJudgeOverhead: includeSecondJudgeOverhead,
              corruptSecondJudgeOverhead: corruptSecondJudgeOverhead,
            ),
        },
      ],
    }),
  );
}

Map<String, Map<String, Object?>> _runResultArtifactMetadata({
  required String taskRunId,
  required String responsePath,
  required String patchPath,
  Map<String, String> extraArtifacts = const {},
  bool corruptPatchDigest = false,
}) {
  const artifactDigest = _artifactFixtureSha256;
  const corruptArtifactDigest =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  return {
    'response': {
      'artifactId': _artifactId(taskRunId, 'response'),
      'path': responsePath,
      'bytes': 10,
      'sha256': artifactDigest,
    },
    'patch': {
      'artifactId': _artifactId(taskRunId, 'patch'),
      'path': patchPath,
      'bytes': 10,
      'sha256': corruptPatchDigest ? corruptArtifactDigest : artifactDigest,
    },
    for (final entry in extraArtifacts.entries)
      entry.key: {
        'artifactId': _artifactId(taskRunId, entry.key),
        'path': entry.value,
        'bytes': 10,
        'sha256': artifactDigest,
      },
  };
}

List<Map<String, Object?>> _runResultEvaluations(
  String taskRunId, {
  bool duplicateFirstId = false,
  bool duplicateEvaluatorId = false,
  bool outOfRangeSecondScore = false,
  bool mismatchedSecondStatus = false,
  bool omitSecondRationale = false,
  bool invalidSecondDetailsMetadata = false,
  bool blockedSecondEvaluation = false,
  bool omitSecondBlockedMetadata = false,
  bool includeSecondJudgeOverhead = false,
  bool corruptSecondJudgeOverhead = false,
  bool includeAgentHarnessEvaluation = false,
  bool omitAgentHarnessStatusMetadata = false,
  bool corruptAgentHarnessStatusMetadata = false,
}) => [
  if (includeAgentHarnessEvaluation)
    {
      'id': '$taskRunId-agent-harness',
      'evaluatorId': 'agent_harness',
      'passed': !corruptAgentHarnessStatusMetadata,
      'score': corruptAgentHarnessStatusMetadata ? 0.0 : 1.0,
      'status': corruptAgentHarnessStatusMetadata ? 'failed' : 'passed',
      'rationale': corruptAgentHarnessStatusMetadata
          ? 'agent harness failed'
          : 'agent harness completed',
      if (!omitAgentHarnessStatusMetadata)
        'agentHarness': corruptAgentHarnessStatusMetadata
            ? const {
                'status': '',
                'exitCode': 'one',
                'stdoutPreviewPresent': 'false',
                'stderrPreviewPresent': false,
                'trajectoryLogPresent': false,
              }
            : const {
                'status': 'success',
                'exitCode': 0,
                'stdoutPreviewPresent': false,
                'stderrPreviewPresent': false,
                'trajectoryLogPresent': false,
              },
      'detailsJsonSha256':
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      'detailsJsonBytes': 2,
    },
  {
    'id': '$taskRunId-compile',
    'evaluatorId': 'compile',
    'passed': true,
    'score': 1.0,
    'status': 'passed',
    'rationale': 'ok',
    'detailsJsonSha256':
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    'detailsJsonBytes': 2,
  },
  {
    'id': duplicateFirstId ? '$taskRunId-compile' : '$taskRunId-test',
    'evaluatorId': duplicateEvaluatorId ? 'compile' : 'test',
    'passed': !blockedSecondEvaluation,
    'score': blockedSecondEvaluation
        ? 0.0
        : outOfRangeSecondScore
        ? 1.25
        : 1.0,
    'status': blockedSecondEvaluation
        ? 'blocked'
        : mismatchedSecondStatus
        ? 'failed'
        : 'passed',
    if (!omitSecondRationale) 'rationale': 'ok',
    if (blockedSecondEvaluation && !omitSecondBlockedMetadata)
      'blockedBy': 'compile',
    if (blockedSecondEvaluation && !omitSecondBlockedMetadata)
      'blockedReason': 'blocked by compile',
    if (includeSecondJudgeOverhead || corruptSecondJudgeOverhead)
      'judgeOverhead': corruptSecondJudgeOverhead
          ? const {
              'providerId': '',
              'modelId': 'gpt-5',
              'promptTokens': -1,
              'completionTokens': 'twenty',
              'estimatedCostMicros': -325,
              'pricingStatus': '',
              'pricingRegistryVersion': '',
              'pricingCurrency': '',
            }
          : const {
              'providerId': 'openai',
              'modelId': 'gpt-5',
              'promptTokens': 100,
              'completionTokens': 20,
              'estimatedCostMicros': 325,
              'pricingStatus': 'exact',
              'pricingRegistryVersion': '2026-05-31',
              'pricingCurrency': 'USD',
            },
    'detailsJsonSha256': invalidSecondDetailsMetadata
        ? 'invalid-sha'
        : '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    'detailsJsonBytes': invalidSecondDetailsMetadata ? 0 : 2,
  },
];

Future<Map<String, String>> _standardBundleFileDigests(
  Map<String, String> files,
) async {
  return {
    for (final entry in files.entries)
      entry.key: await _fileSha256(entry.value),
  };
}

List<String> _standardBundleCliArgs(Map<String, String> files) => [
  '--artifact-run-results',
  files['run_results.v1.json']!,
  '--artifact-results-csv',
  files['results.csv']!,
  '--artifact-report',
  files['report.md']!,
];

Future<Map<String, Object?>> _runTaskBundleIntegrityReleaseReport(
  Directory tmp, {
  required bool includeDigest,
  String? digestOverride,
  Object? admissionGitDirty = false,
  bool includeAdmissionGitDirty = true,
  _TaskQaInputMode inputMode = _TaskQaInputMode.summary,
  bool useBuildOutputLayout = false,
  bool includeTaskBundleRoot = true,
}) async {
  final leaderboardPath = p.join(tmp.path, 'leaderboard.v1.json');
  final taskQaDir = Directory(p.join(tmp.path, 'task_qa'));
  await taskQaDir.create(recursive: true);
  final taskQaSummaryPath = p.join(taskQaDir.path, 'admission_summary.json');
  final taskBundleRoot = Directory(p.join(tmp.path, 'task_bundles'));
  final taskBundle = Directory(
    useBuildOutputLayout
        ? p.join(taskBundleRoot.path, 'task.a')
        : p.join(taskQaDir.path, 'tasks', 'task.a'),
  );
  final taskBundleDigest = await _writeReleaseTaskBundle(taskBundle);
  final reportPath = useBuildOutputLayout
      ? p.join(
          taskQaDir.path,
          'tasks',
          'task_task.a_96ed8d5fca07',
          'admission_report.json',
        )
      : p.join(taskBundle.path, 'qa', 'admission_report.json');
  await Directory(p.dirname(reportPath)).create(recursive: true);
  await File(
    leaderboardPath,
  ).writeAsString(_prettyJson(_leaderboardJson(sampleCount: 1)));
  await File(taskQaSummaryPath).writeAsString(
    _prettyJson(
      _taskQaSummaryJson(
        reportPath: p
            .relative(reportPath, from: taskQaDir.path)
            .replaceAll('\\', '/'),
      ),
    ),
  );
  await File(reportPath).writeAsString(
    _prettyJson(
      _taskQaReportJson(
        taskBundleDigest: includeDigest
            ? digestOverride ?? taskBundleDigest
            : null,
        admissionGitDirty: admissionGitDirty,
        includeAdmissionGitDirty: includeAdmissionGitDirty,
      ),
    ),
  );
  final outPath = p.join(tmp.path, 'release', 'release_report.v1.json');
  final stdoutLines = <String>[];

  final exitCode = await runReleaseReportCli(
    [
      '--leaderboard',
      leaderboardPath,
      ...switch (inputMode) {
        _TaskQaInputMode.summary => ['--task-qa-summary', taskQaSummaryPath],
        _TaskQaInputMode.report => ['--task-qa-report', reportPath],
        _TaskQaInputMode.reportRoot => [
          '--task-qa-report-root',
          taskQaDir.path,
        ],
      },
      if (useBuildOutputLayout && includeTaskBundleRoot) ...[
        '--task-bundle-root',
        taskBundleRoot.path,
      ],
      '--out',
      outPath,
      '--release-id',
      '2026-06-task-bundle-integrity',
    ],
    dependencies: ReleaseReportCliDependencies(
      now: () => DateTime.utc(2026, 6, 4, 3, 10),
    ),
    stdoutWriter: stdoutLines.add,
    stderrWriter: (_) {},
  );

  expect(exitCode, 0);
  expect(stdoutLines.single, contains('"status":"blocked"'));
  return jsonDecode(await File(outPath).readAsString()) as Map<String, Object?>;
}

enum _TaskQaInputMode { summary, report, reportRoot }

Future<String> _writeReleaseTaskBundle(Directory bundle) async {
  await _writeTaskBundleFile(bundle, 'task.yaml', '''
schemaVersion: 1
id: task.a
version: 1
category: bug_fix
track: agentic
tags:
  - bugfix
difficulty: easy
platformRequirements:
  - linux
timeoutSeconds: 60
release:
  corpus: private_official
  status: active
network: false
resources:
  cpus: 2
  memory_mb: 8192
  max_processes: 64
  max_output_bytes: 1048576
generatedCodePath: lib/answer.dart
isFlutter: false
instructionPath: instruction.md
workspace:
  root: baseline
  files:
    pubspec.yaml: pubspec.yaml
    lib/answer.dart: lib/answer.dart
hiddenVerifiers:
  - id: hidden_test
    testPath: test/_hidden/answer_hidden_test.dart
    root: hidden_tests
    files:
      test/_hidden/answer_hidden_test.dart: test/_hidden/answer_hidden_test.dart
reference:
  type: files
  root: solution
  files:
    lib/answer.dart: lib/answer.dart
requiredNegativeCaseKinds:
  - noop
  - api_breaking
  - overfit
negativeCases:
  - id: noop
    kind: noop
    description: Leaves the original answer unchanged.
    root: negative_cases/noop
    files:
      lib/answer.dart: lib/answer.dart
  - id: api_breaking
    kind: api_breaking
    description: Breaks the answer API.
    root: negative_cases/api_breaking
    files:
      lib/answer.dart: lib/answer.dart
  - id: overfit_public_surface
    kind: overfit
    description: Matches public behavior while missing hidden behavior.
    root: negative_cases/overfit
    files:
      lib/answer.dart: lib/answer.dart
''');
  await _writeTaskBundleFile(
    bundle,
    'instruction.md',
    'Make answer return 42.\n',
  );
  await _writeTaskBundleFile(bundle, 'baseline/pubspec.yaml', '''
name: release_task
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
  await _writeTaskBundleFile(
    bundle,
    'baseline/lib/answer.dart',
    'int answer() => 41;\n',
  );
  await _writeTaskBundleFile(
    bundle,
    'hidden_tests/test/_hidden/answer_hidden_test.dart',
    'void main() {}\n',
  );
  await _writeTaskBundleFile(
    bundle,
    'solution/lib/answer.dart',
    'int answer() => 42;\n',
  );
  await _writeTaskBundleFile(
    bundle,
    'negative_cases/noop/lib/answer.dart',
    'int answer() => 41;\n',
  );
  await _writeTaskBundleFile(
    bundle,
    'negative_cases/api_breaking/lib/answer.dart',
    'void answer() {}\n',
  );
  await _writeTaskBundleFile(
    bundle,
    'negative_cases/overfit/lib/answer.dart',
    'int answer() => 0;\n',
  );
  await _writeTaskBundleFile(bundle, 'qa/notes.txt', 'not release evidence\n');
  return taskBundleDigestSha256(bundle);
}

Future<void> _writeTaskBundleFile(
  Directory bundle,
  String relativePath,
  String content,
) async {
  final file = File(p.join(bundle.path, relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

Map<String, Object?> _taskQaReportJson({
  Object? schemaVersion = 1,
  bool includeHiddenDigests = true,
  Map<String, Object?> hiddenDigestsOverride = const {
    'hidden_test': _artifactFixtureSha256,
  },
  bool includeNegativeCases = true,
  String taskId = 'task.a',
  int taskVersion = 1,
  String track = 'agentic',
  String status = 'admitted',
  String? generatedAt = '2026-06-03T12:10:00.000Z',
  Map<String, Object?> checksOverride = const {},
  bool includePromptSafety = true,
  Map<String, Object?>? promptSafetyOverride,
  List<Map<String, Object?>>? negativeCasesOverride,
  Map<String, Object?> verifierQualityAuditOverride = const {},
  int falsePositiveCount = 0,
  int hiddenFlakeRuns = 3,
  String releaseCorpus = 'private_official',
  String releaseStatus = 'active',
  bool includeAdmissionProvenance = true,
  String? taskBundleDigest,
  Object? admissionGitDirty = false,
  bool includeAdmissionGitDirty = true,
  Map<String, Object?>? admissionProvenanceOverride,
  bool includeExecutionPolicy = true,
  Map<String, Object?>? executionPolicyOverride,
}) => {
  if (schemaVersion != null) 'schemaVersion': schemaVersion,
  'taskId': taskId,
  'taskVersion': taskVersion,
  'track': track,
  'status': status,
  if (generatedAt != null) 'generatedAt': generatedAt,
  'release': {'corpus': releaseCorpus, 'status': releaseStatus},
  if (includeAdmissionProvenance)
    'admission':
        admissionProvenanceOverride ??
        {
          'tool': {'name': 'dart_arena_task_qa'},
          'evaluator': {
            'schemaVersion': 2,
            'version': '2026-05-31-master-spec',
          },
          if (taskBundleDigest != null) 'taskBundleDigest': taskBundleDigest,
          'environment': {
            'dartVersion': '3.9.0',
            'flutterVersion': '3.35.0',
            if (includeAdmissionGitDirty) 'gitDirty': admissionGitDirty,
            'dependencySnapshot': {
              'status': 'present',
              'files': {
                'pubspec.lock': {
                  'sha256':
                      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                  'bytes': 12345,
                },
              },
            },
          },
        },
  if (includeExecutionPolicy)
    'executionPolicy':
        executionPolicyOverride ??
        {
          'allowInternet': false,
          'resources': {
            'cpus': 2,
            'memoryMb': 4096,
            'maxProcesses': 64,
            'maxOutputBytes': 1048576,
          },
        },
  'checks': {
    'baselineHiddenFailed': true,
    'referencePublicPassed': true,
    'referenceHiddenPassed': true,
    'negativeCasesRejected': true,
    'requiredNegativeCaseKindsCovered': true,
    'hiddenFlakeRuns': hiddenFlakeRuns,
    'promptSafeContextLeakFree': true,
    ...checksOverride,
  },
  if (includePromptSafety)
    'promptSafety':
        promptSafetyOverride ??
        {
          'target_context_present': true,
          'public_test_context_present': true,
          'public_test_context_required': true,
          'implementation_bodies_omitted': true,
          'hidden_verifier_leak_free': true,
          'reference_leak_free': true,
          'required_negative_case_kinds': ['api_breaking', 'noop', 'overfit'],
          'present_negative_case_kinds': ['api_breaking', 'noop', 'overfit'],
          'missing_negative_case_kinds': <String>[],
          'passed': true,
        },
  if (includeHiddenDigests) 'hiddenVerifierDigests': hiddenDigestsOverride,
  if (includeHiddenDigests && includeNegativeCases)
    'verifierQualityAudit': {
      'falsePositiveCount': falsePositiveCount,
      'falseNegativeCount': 0,
      'disagreementCount': falsePositiveCount > 0 ? 1 : 2,
      'infrastructureErrorCount': 0,
      'flakeRunCount': hiddenFlakeRuns,
      'flakeFailureCount': 0,
      'flakeRate': 0.0,
      'negativeCaseCount': 3,
      'acceptedNegativeCaseCount': falsePositiveCount,
      'referencePublicFailureCount': 0,
      'referenceHiddenFailureCount': 0,
      ...verifierQualityAuditOverride,
    },
  if (includeNegativeCases)
    'negativeCases':
        negativeCasesOverride ??
        [
          {
            'id': 'noop',
            'kind': 'noop',
            'prepare_passed': true,
            'public_passed': true,
            'hidden_passed': falsePositiveCount > 0,
            'rejected': falsePositiveCount == 0,
          },
          {
            'id': 'api_breaking',
            'kind': 'api_breaking',
            'prepare_passed': true,
            'public_passed': false,
            'hidden_passed': false,
            'rejected': true,
          },
          {
            'id': 'overfit_public_surface',
            'kind': 'overfit',
            'prepare_passed': true,
            'public_passed': true,
            'hidden_passed': false,
            'rejected': true,
          },
        ],
  'failureMessages': <String>[],
};

Future<void> _seedDatabase(
  String databasePath, {
  List<String> runIds = const ['run-1'],
  bool sandboxEnforced = true,
  bool includeTaskExecutionPolicy = true,
  bool taskAllowInternet = false,
  bool includeTaskResourceLimits = true,
  bool useIncompleteTaskResourceLimits = false,
  bool includeSdkVersions = true,
  bool includeDependencySnapshot = true,
  bool includePricingRegistry = true,
}) async {
  final db = AppDatabase(NativeDatabase(File(databasePath)));
  try {
    for (var i = 0; i < runIds.length; i++) {
      final runId = runIds[i];
      await db
          .into(db.runs)
          .insert(
            RunsCompanion.insert(
              id: runId,
              startedAt: DateTime.utc(2026, 6, 3, 12).add(Duration(hours: i)),
              completedAt: Value(
                DateTime.utc(2026, 6, 3, 13).add(Duration(hours: i)),
              ),
              provenanceJson: Value(
                jsonEncode({
                  'schemaVersion': 1,
                  'runId': runId,
                  'apiToken': 'sk-live',
                  'environment': {
                    'workspacePath': p.dirname(databasePath),
                    if (includeSdkVersions) ...{
                      'dartVersion': '3.9.0',
                      'flutterVersion': '3.35.0',
                    },
                    if (includeDependencySnapshot)
                      'dependencySnapshot': {
                        'status': 'present',
                        'files': {
                          'pubspec.lock': {
                            'sha256':
                                '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                            'bytes': 12345,
                          },
                        },
                      },
                  },
                  'config': {
                    'trialsPerTask': 2,
                    'generatedCodeSandbox': {
                      'required': sandboxEnforced,
                      'enforced': sandboxEnforced,
                      if (sandboxEnforced) 'backend': 'test-sandbox',
                    },
                    'evaluatorWeights': {'compile': 1.0},
                    if (includePricingRegistry)
                      'pricingRegistry': {
                        'version': '2026-05-31',
                        'currency': 'USD',
                        'modelCount': 1,
                        'models': {
                          'openai:gpt-5': {
                            'inputCostPerMToken': 1.25,
                            'outputCostPerMToken': 10,
                            'source': 'manual',
                            'effectiveFrom': '2026-05-31',
                          },
                        },
                      },
                  },
                  'tasks': [
                    {
                      'id': 'task.a',
                      'version': 1,
                      if (includeTaskExecutionPolicy)
                        'executionPolicy': {
                          'allowInternet': taskAllowInternet,
                          if (includeTaskResourceLimits)
                            'resources': useIncompleteTaskResourceLimits
                                ? {'cpus': 0}
                                : {
                                    'cpus': 2,
                                    'memoryMb': 8192,
                                    'maxProcesses': 64,
                                    'maxOutputBytes': 1048576,
                                  },
                          if (includeTaskResourceLimits &&
                              !useIncompleteTaskResourceLimits)
                            'resourceEnforcement':
                                _fullyEnforcedResourcePolicy(),
                        },
                    },
                  ],
                }),
              ),
            ),
          );
    }
  } finally {
    await db.close();
  }
}

String _prettyJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

void _expectFingerprint(Map<String, Object?> value, {required String path}) {
  expect(value['path'], path);
  expect(
    value['bytes'],
    isA<int>().having((bytes) => bytes, 'bytes', greaterThan(0)),
  );
  expect(value['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
}
