import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

const appDatabaseSchemaVersion = 7;

class Runs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get judgeModel => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get provenanceJson => text().nullable()();

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
  IntColumn get trialIndex => integer().withDefault(const Constant(0))();
  IntColumn get taskVersion => integer().withDefault(const Constant(1))();
  TextColumn get benchmarkTrack =>
      text().withDefault(const Constant('codegen'))();
  TextColumn get harnessId => text().nullable()();
  BoolColumn get primaryPass => boolean().nullable()();
  TextColumn get failureTag => text().nullable()();
  TextColumn get patchText => text().nullable()();
  TextColumn get trajectoryLogPath => text().nullable()();

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

class ReviewBattles extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  IntColumn get taskVersion => integer()();
  TextColumn get benchmarkTrack => text()();
  @ReferenceName('leftReviewBattles')
  TextColumn get leftTaskRunId => text().references(TaskRuns, #id)();
  @ReferenceName('rightReviewBattles')
  TextColumn get rightTaskRunId => text().references(TaskRuns, #id)();
  TextColumn get canonicalPairKey => text()();
  TextColumn get leftLabel => text()();
  TextColumn get rightLabel => text()();
  TextColumn get reviewerId => text()();
  TextColumn get reviewerAlias => text().nullable()();
  TextColumn get vote => text()();
  TextColumn get rationale => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {reviewerId, canonicalPairKey},
  ];
}

@DriftDatabase(tables: [Runs, TaskRuns, Evaluations, Plans, ReviewBattles])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => appDatabaseSchemaVersion;

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
      if (from < 4) {
        await m.addColumn(taskRuns, taskRuns.trialIndex);
        await m.addColumn(taskRuns, taskRuns.taskVersion);
        await m.addColumn(taskRuns, taskRuns.benchmarkTrack);
        await m.addColumn(taskRuns, taskRuns.harnessId);
        await m.addColumn(taskRuns, taskRuns.primaryPass);
        await m.addColumn(taskRuns, taskRuns.failureTag);
      }
      if (from < 5) {
        await m.addColumn(taskRuns, taskRuns.patchText);
        await m.addColumn(taskRuns, taskRuns.trajectoryLogPath);
      }
      if (from < 6) {
        await m.createTable(reviewBattles);
      }
      if (from < 7) {
        await m.addColumn(runs, runs.provenanceJson);
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
