import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/export/leaderboard_exporter.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

typedef LeaderboardCliLineWriter = void Function(String line);

class LeaderboardCliDependencies {
  const LeaderboardCliDependencies({this.now = _now});

  final DateTime Function() now;
}

Future<int> runLeaderboardExportCli(
  List<String> args, {
  LeaderboardCliDependencies dependencies = const LeaderboardCliDependencies(),
  LeaderboardCliLineWriter? stdoutWriter,
  LeaderboardCliLineWriter? stderrWriter,
}) async {
  final out = stdoutWriter ?? stdout.writeln;
  final err = stderrWriter ?? stderr.writeln;
  AppDatabase? database;

  try {
    final parsed = _parseArgs(args);
    if (parsed == null) {
      out(jsonEncode(_helpJson()));
      return 0;
    }

    database = openLeaderboardDatabaseReadOnly(parsed.databasePath);
    final export = await buildLeaderboardExport(
      database,
      options: LeaderboardExportOptions(
        track: parsed.track,
        strategy: parsed.strategy,
        runId: parsed.runId,
      ),
      now: dependencies.now,
    );

    await Directory(p.dirname(parsed.outPath)).create(recursive: true);
    await File(
      parsed.outPath,
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(export)}\n');
    out(
      jsonEncode(<String, Object?>{
        'status': 'completed',
        'out': p.normalize(p.absolute(parsed.outPath)),
      }),
    );
    return 0;
  } on Object catch (error) {
    err(jsonEncode(<String, Object?>{'status': 'failed', 'error': '$error'}));
    return 1;
  } finally {
    await database?.close();
  }
}

AppDatabase openLeaderboardDatabaseReadOnly(String databasePath) {
  final file = File(databasePath);
  if (!file.existsSync()) {
    throw LeaderboardCliException(
      'database file does not exist: $databasePath',
    );
  }

  final raw = sqlite3.open(databasePath, mode: OpenMode.readOnly);
  try {
    if (raw.userVersion != appDatabaseSchemaVersion) {
      throw LeaderboardCliException(
        'incompatible appDatabaseSchemaVersion: expected '
        '$appDatabaseSchemaVersion, found ${raw.userVersion}',
      );
    }
    return AppDatabase(NativeDatabase.opened(raw, enableMigrations: false));
  } on Object {
    raw.close();
    rethrow;
  }
}

_ParsedArgs? _parseArgs(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    return null;
  }

  String? databasePath;
  String? outPath;
  String? track;
  var strategy = LeaderboardExportStrategy.aggregateCompatible;
  String? runId;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--database':
        databasePath = _requiredValue(args, ++i, arg);
      case '--out':
        outPath = _requiredValue(args, ++i, arg);
      case '--track':
        track = _parseTrack(_requiredValue(args, ++i, arg));
      case '--strategy':
        strategy = _parseStrategy(_requiredValue(args, ++i, arg));
      case '--run-id':
        runId = _requiredValue(args, ++i, arg);
      default:
        throw LeaderboardCliException('unknown argument: $arg');
    }
  }

  if (databasePath == null) {
    throw const LeaderboardCliException('--database is required');
  }
  if (outPath == null) {
    throw const LeaderboardCliException('--out is required');
  }
  if (track == null) {
    throw const LeaderboardCliException('--track is required');
  }

  return _ParsedArgs(
    databasePath: databasePath,
    outPath: outPath,
    track: track,
    strategy: strategy,
    runId: runId,
  );
}

String _requiredValue(List<String> args, int index, String option) {
  if (index >= args.length || args[index].startsWith('--')) {
    throw LeaderboardCliException('$option requires a value');
  }
  return args[index];
}

String _parseTrack(String value) {
  switch (value) {
    case 'codegen':
    case 'agentic':
      return value;
    default:
      throw LeaderboardCliException('unsupported track: $value');
  }
}

LeaderboardExportStrategy _parseStrategy(String value) {
  switch (value) {
    case 'aggregate-compatible':
      return LeaderboardExportStrategy.aggregateCompatible;
    case 'latest-run':
      return LeaderboardExportStrategy.latestRun;
    case 'best-observed':
      return LeaderboardExportStrategy.bestObserved;
    default:
      throw LeaderboardCliException('unsupported strategy: $value');
  }
}

Map<String, Object?> _helpJson() {
  return const <String, Object?>{
    'status': 'help',
    'usage':
        'dart run --verbosity=error dart_arena:dart_arena_export_leaderboard --database .dart_arena/dart_arena.sqlite --out ../web/static/data/leaderboard.v1.json --track agentic',
    'options': <Map<String, Object?>>[
      {'name': '--database', 'value': 'path', 'required': true},
      {'name': '--out', 'value': 'path', 'required': true},
      {'name': '--track', 'value': 'codegen|agentic', 'required': true},
      {
        'name': '--strategy',
        'value': 'aggregate-compatible|latest-run|best-observed',
        'required': false,
        'default': 'aggregate-compatible',
      },
      {'name': '--run-id', 'value': 'id', 'required': false},
      {'name': '--help', 'required': false},
    ],
    'outputFormat': 'leaderboard.v1.json',
  };
}

DateTime _now() => DateTime.now();

class LeaderboardCliException implements Exception {
  const LeaderboardCliException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ParsedArgs {
  const _ParsedArgs({
    required this.databasePath,
    required this.outPath,
    required this.track,
    required this.strategy,
    required this.runId,
  });

  final String databasePath;
  final String outPath;
  final String track;
  final LeaderboardExportStrategy strategy;
  final String? runId;
}
