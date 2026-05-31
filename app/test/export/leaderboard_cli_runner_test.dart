import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/export/leaderboard_cli_runner.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('help emits JSON', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final exitCode = await runLeaderboardExportCli(
      ['--help'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    final decoded = jsonDecode(stdoutLines.single) as Map<String, Object?>;
    expect(decoded['status'], 'help');
    expect(
      decoded['usage'].toString(),
      contains('dart_arena_export_leaderboard'),
    );
  });

  test('validates required args and unsupported values', () async {
    await _expectCliFailure([
      '--out',
      'x.json',
      '--track',
      'agentic',
    ], contains('--database is required'));
    await _expectCliFailure([
      '--database',
      'x.sqlite',
      '--out',
      'x.json',
      '--track',
      'mobile',
    ], contains('unsupported track: mobile'));
    await _expectCliFailure([
      '--database',
      'x.sqlite',
      '--out',
      'x.json',
      '--track',
      'agentic',
      '--strategy',
      'latest',
    ], contains('unsupported strategy: latest'));
  });

  test('missing database fails without creating database or parent', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_export_missing_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final databasePath = p.join(tmp.path, 'missing-parent', 'missing.sqlite');
    final outPath = p.join(tmp.path, 'out', 'leaderboard.v1.json');

    final stderrLines = <String>[];
    final exitCode = await runLeaderboardExportCli(
      ['--database', databasePath, '--out', outPath, '--track', 'agentic'],
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(File(databasePath).existsSync(), isFalse);
    expect(Directory(p.dirname(databasePath)).existsSync(), isFalse);
    expect(File(outPath).existsSync(), isFalse);
    expect(stderrLines.single, contains('database file does not exist'));
  });

  test('incompatible database fails without writing output', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_export_incompatible_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final databasePath = p.join(tmp.path, 'old.sqlite');
    final raw = sqlite3.open(databasePath);
    raw.userVersion = appDatabaseSchemaVersion - 1;
    raw.close();
    final outPath = p.join(tmp.path, 'out', 'leaderboard.v1.json');

    final stderrLines = <String>[];
    final exitCode = await runLeaderboardExportCli(
      ['--database', databasePath, '--out', outPath, '--track', 'agentic'],
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(File(outPath).existsSync(), isFalse);
    expect(
      stderrLines.single,
      contains('incompatible appDatabaseSchemaVersion'),
    );
  });

  test('writes pretty JSON to requested output path', () async {
    final tmp = await Directory.systemTemp.createTemp('dart_arena_export_cli_');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath);
    final outPath = p.join(tmp.path, 'nested', 'leaderboard.v1.json');
    final stdoutLines = <String>[];

    final exitCode = await runLeaderboardExportCli(
      [
        '--database',
        databasePath,
        '--out',
        outPath,
        '--track',
        'agentic',
        '--strategy',
        'latest-run',
      ],
      dependencies: LeaderboardCliDependencies(
        now: () => DateTime.utc(2026, 5, 31),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: (_) {},
    );

    expect(exitCode, 0);
    expect(stdoutLines.single, contains('"status":"completed"'));
    final text = File(outPath).readAsStringSync();
    expect(text, startsWith('{\n  "schemaVersion": 1,'));
    final decoded = jsonDecode(text) as Map<String, Object?>;
    expect(decoded['generatedAt'], '2026-05-31T00:00:00.000Z');
    expect((decoded['models']! as List<Object?>), hasLength(1));
  });

  test('empty matching export writes valid JSON with exit code zero', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_export_empty_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final databasePath = p.join(tmp.path, 'dart_arena.sqlite');
    await _seedDatabase(databasePath, track: 'codegen');
    final outPath = p.join(tmp.path, 'leaderboard.v1.json');

    final exitCode = await runLeaderboardExportCli(
      ['--database', databasePath, '--out', outPath, '--track', 'agentic'],
      stdoutWriter: (_) {},
      stderrWriter: (_) {},
    );

    expect(exitCode, 0);
    final decoded =
        jsonDecode(File(outPath).readAsStringSync()) as Map<String, Object?>;
    expect(decoded['models'], isEmpty);
    expect(
      ((decoded['source']! as Map<String, Object?>)['warnings']!
              as List<Object?>)
          .join('\n'),
      contains('No completed task runs'),
    );
  });
}

Future<void> _expectCliFailure(List<String> args, Matcher errorMatcher) async {
  final stdoutLines = <String>[];
  final stderrLines = <String>[];
  final exitCode = await runLeaderboardExportCli(
    args,
    stdoutWriter: stdoutLines.add,
    stderrWriter: stderrLines.add,
  );
  expect(exitCode, 1);
  expect(stdoutLines, isEmpty);
  final decoded = jsonDecode(stderrLines.single) as Map<String, Object?>;
  expect(decoded['status'], 'failed');
  expect(decoded['error'], errorMatcher);
}

Future<void> _seedDatabase(
  String databasePath, {
  String track = 'agentic',
}) async {
  final db = AppDatabase(NativeDatabase(File(databasePath)));
  try {
    await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(
            id: 'run-1',
            startedAt: DateTime.utc(2026, 5, 1, 11),
            completedAt: Value(DateTime.utc(2026, 5, 1, 12)),
            provenanceJson: const Value(
              '{"schemaVersion":1,"config":{"evaluatorWeights":{"compile":1.0}}}',
            ),
          ),
        );
    await db
        .into(db.taskRuns)
        .insert(
          TaskRunsCompanion.insert(
            id: 'task-run-1',
            runId: 'run-1',
            providerId: 'openai',
            modelId: 'gpt-5',
            taskId: 'task.a',
            responseText: 'raw response',
            latencyMs: 1000,
            aggregateScore: 1.0,
            completedAt: DateTime.utc(2026, 5, 1, 12),
            benchmarkTrack: Value(track),
            primaryPass: const Value(true),
          ),
        );
  } finally {
    await db.close();
  }
}
