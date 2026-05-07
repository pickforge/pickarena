import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Runs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get judgeModel => text().nullable()();
  TextColumn get name => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TaskRuns extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text().references(Runs, #id)();
  TextColumn get providerId => text()();
  TextColumn get modelId => text()();
  TextColumn get taskId => text()();
  TextColumn get responseText => text()();
  IntColumn get promptTokens => integer().nullable()();
  IntColumn get completionTokens => integer().nullable()();
  IntColumn get latencyMs => integer()();
  RealColumn get aggregateScore => real()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get planId => text().nullable().references(Plans, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get plannerModelId => text().nullable()();
  IntColumn get referenceVersion => integer().nullable()();
  TextColumn get artifact => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Evaluations extends Table {
  TextColumn get id => text()();
  TextColumn get taskRunId => text().references(TaskRuns, #id)();
  TextColumn get evaluatorId => text()();
  BoolColumn get passed => boolean()();
  RealColumn get score => real()();
  TextColumn get rationale => text().nullable()();
  TextColumn get detailsJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Runs, TaskRuns, Evaluations, Plans])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(runs, runs.name);
      }
      if (from < 3) {
        await m.createTable(plans);
        await m.addColumn(taskRuns, taskRuns.planId);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return NativeDatabase(File(p.join(dir.path, 'dart_arena.sqlite')));
  });
}
