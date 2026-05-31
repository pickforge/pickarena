// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RunsTable extends Runs with TableInfo<$RunsTable, Run> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _judgeModelMeta = const VerificationMeta(
    'judgeModel',
  );
  @override
  late final GeneratedColumn<String> judgeModel = GeneratedColumn<String>(
    'judge_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _provenanceJsonMeta = const VerificationMeta(
    'provenanceJson',
  );
  @override
  late final GeneratedColumn<String> provenanceJson = GeneratedColumn<String>(
    'provenance_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    completedAt,
    judgeModel,
    name,
    provenanceJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Run> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('judge_model')) {
      context.handle(
        _judgeModelMeta,
        judgeModel.isAcceptableOrUnknown(data['judge_model']!, _judgeModelMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('provenance_json')) {
      context.handle(
        _provenanceJsonMeta,
        provenanceJson.isAcceptableOrUnknown(
          data['provenance_json']!,
          _provenanceJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Run map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Run(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      judgeModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}judge_model'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      provenanceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provenance_json'],
      ),
    );
  }

  @override
  $RunsTable createAlias(String alias) {
    return $RunsTable(attachedDatabase, alias);
  }
}

class Run extends DataClass implements Insertable<Run> {
  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? judgeModel;
  final String? name;
  final String? provenanceJson;
  const Run({
    required this.id,
    required this.startedAt,
    this.completedAt,
    this.judgeModel,
    this.name,
    this.provenanceJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || judgeModel != null) {
      map['judge_model'] = Variable<String>(judgeModel);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || provenanceJson != null) {
      map['provenance_json'] = Variable<String>(provenanceJson);
    }
    return map;
  }

  RunsCompanion toCompanion(bool nullToAbsent) {
    return RunsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      judgeModel: judgeModel == null && nullToAbsent
          ? const Value.absent()
          : Value(judgeModel),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      provenanceJson: provenanceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(provenanceJson),
    );
  }

  factory Run.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Run(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      judgeModel: serializer.fromJson<String?>(json['judgeModel']),
      name: serializer.fromJson<String?>(json['name']),
      provenanceJson: serializer.fromJson<String?>(json['provenanceJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'judgeModel': serializer.toJson<String?>(judgeModel),
      'name': serializer.toJson<String?>(name),
      'provenanceJson': serializer.toJson<String?>(provenanceJson),
    };
  }

  Run copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> judgeModel = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> provenanceJson = const Value.absent(),
  }) => Run(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    judgeModel: judgeModel.present ? judgeModel.value : this.judgeModel,
    name: name.present ? name.value : this.name,
    provenanceJson: provenanceJson.present
        ? provenanceJson.value
        : this.provenanceJson,
  );
  Run copyWithCompanion(RunsCompanion data) {
    return Run(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      judgeModel: data.judgeModel.present
          ? data.judgeModel.value
          : this.judgeModel,
      name: data.name.present ? data.name.value : this.name,
      provenanceJson: data.provenanceJson.present
          ? data.provenanceJson.value
          : this.provenanceJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Run(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('judgeModel: $judgeModel, ')
          ..write('name: $name, ')
          ..write('provenanceJson: $provenanceJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, startedAt, completedAt, judgeModel, name, provenanceJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Run &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.judgeModel == this.judgeModel &&
          other.name == this.name &&
          other.provenanceJson == this.provenanceJson);
}

class RunsCompanion extends UpdateCompanion<Run> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<String?> judgeModel;
  final Value<String?> name;
  final Value<String?> provenanceJson;
  final Value<int> rowid;
  const RunsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.judgeModel = const Value.absent(),
    this.name = const Value.absent(),
    this.provenanceJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    this.judgeModel = const Value.absent(),
    this.name = const Value.absent(),
    this.provenanceJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt);
  static Insertable<Run> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<String>? judgeModel,
    Expression<String>? name,
    Expression<String>? provenanceJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (judgeModel != null) 'judge_model': judgeModel,
      if (name != null) 'name': name,
      if (provenanceJson != null) 'provenance_json': provenanceJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<String?>? judgeModel,
    Value<String?>? name,
    Value<String?>? provenanceJson,
    Value<int>? rowid,
  }) {
    return RunsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      judgeModel: judgeModel ?? this.judgeModel,
      name: name ?? this.name,
      provenanceJson: provenanceJson ?? this.provenanceJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (judgeModel.present) {
      map['judge_model'] = Variable<String>(judgeModel.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (provenanceJson.present) {
      map['provenance_json'] = Variable<String>(provenanceJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('judgeModel: $judgeModel, ')
          ..write('name: $name, ')
          ..write('provenanceJson: $provenanceJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlansTable extends Plans with TableInfo<$PlansTable, Plan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plannerModelIdMeta = const VerificationMeta(
    'plannerModelId',
  );
  @override
  late final GeneratedColumn<String> plannerModelId = GeneratedColumn<String>(
    'planner_model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceVersionMeta = const VerificationMeta(
    'referenceVersion',
  );
  @override
  late final GeneratedColumn<int> referenceVersion = GeneratedColumn<int>(
    'reference_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artifactMeta = const VerificationMeta(
    'artifact',
  );
  @override
  late final GeneratedColumn<String> artifact = GeneratedColumn<String>(
    'artifact',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    plannerModelId,
    referenceVersion,
    artifact,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<Plan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('planner_model_id')) {
      context.handle(
        _plannerModelIdMeta,
        plannerModelId.isAcceptableOrUnknown(
          data['planner_model_id']!,
          _plannerModelIdMeta,
        ),
      );
    }
    if (data.containsKey('reference_version')) {
      context.handle(
        _referenceVersionMeta,
        referenceVersion.isAcceptableOrUnknown(
          data['reference_version']!,
          _referenceVersionMeta,
        ),
      );
    }
    if (data.containsKey('artifact')) {
      context.handle(
        _artifactMeta,
        artifact.isAcceptableOrUnknown(data['artifact']!, _artifactMeta),
      );
    } else if (isInserting) {
      context.missing(_artifactMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Plan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      plannerModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}planner_model_id'],
      ),
      referenceVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reference_version'],
      ),
      artifact: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artifact'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlansTable createAlias(String alias) {
    return $PlansTable(attachedDatabase, alias);
  }
}

class Plan extends DataClass implements Insertable<Plan> {
  final String id;
  final String taskId;
  final String? plannerModelId;
  final int? referenceVersion;
  final String artifact;
  final DateTime createdAt;
  const Plan({
    required this.id,
    required this.taskId,
    this.plannerModelId,
    this.referenceVersion,
    required this.artifact,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    if (!nullToAbsent || plannerModelId != null) {
      map['planner_model_id'] = Variable<String>(plannerModelId);
    }
    if (!nullToAbsent || referenceVersion != null) {
      map['reference_version'] = Variable<int>(referenceVersion);
    }
    map['artifact'] = Variable<String>(artifact);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlansCompanion toCompanion(bool nullToAbsent) {
    return PlansCompanion(
      id: Value(id),
      taskId: Value(taskId),
      plannerModelId: plannerModelId == null && nullToAbsent
          ? const Value.absent()
          : Value(plannerModelId),
      referenceVersion: referenceVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceVersion),
      artifact: Value(artifact),
      createdAt: Value(createdAt),
    );
  }

  factory Plan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plan(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      plannerModelId: serializer.fromJson<String?>(json['plannerModelId']),
      referenceVersion: serializer.fromJson<int?>(json['referenceVersion']),
      artifact: serializer.fromJson<String>(json['artifact']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'plannerModelId': serializer.toJson<String?>(plannerModelId),
      'referenceVersion': serializer.toJson<int?>(referenceVersion),
      'artifact': serializer.toJson<String>(artifact),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Plan copyWith({
    String? id,
    String? taskId,
    Value<String?> plannerModelId = const Value.absent(),
    Value<int?> referenceVersion = const Value.absent(),
    String? artifact,
    DateTime? createdAt,
  }) => Plan(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    plannerModelId: plannerModelId.present
        ? plannerModelId.value
        : this.plannerModelId,
    referenceVersion: referenceVersion.present
        ? referenceVersion.value
        : this.referenceVersion,
    artifact: artifact ?? this.artifact,
    createdAt: createdAt ?? this.createdAt,
  );
  Plan copyWithCompanion(PlansCompanion data) {
    return Plan(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      plannerModelId: data.plannerModelId.present
          ? data.plannerModelId.value
          : this.plannerModelId,
      referenceVersion: data.referenceVersion.present
          ? data.referenceVersion.value
          : this.referenceVersion,
      artifact: data.artifact.present ? data.artifact.value : this.artifact,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plan(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('plannerModelId: $plannerModelId, ')
          ..write('referenceVersion: $referenceVersion, ')
          ..write('artifact: $artifact, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    plannerModelId,
    referenceVersion,
    artifact,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plan &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.plannerModelId == this.plannerModelId &&
          other.referenceVersion == this.referenceVersion &&
          other.artifact == this.artifact &&
          other.createdAt == this.createdAt);
}

class PlansCompanion extends UpdateCompanion<Plan> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String?> plannerModelId;
  final Value<int?> referenceVersion;
  final Value<String> artifact;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PlansCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.plannerModelId = const Value.absent(),
    this.referenceVersion = const Value.absent(),
    this.artifact = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlansCompanion.insert({
    required String id,
    required String taskId,
    this.plannerModelId = const Value.absent(),
    this.referenceVersion = const Value.absent(),
    required String artifact,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       artifact = Value(artifact),
       createdAt = Value(createdAt);
  static Insertable<Plan> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? plannerModelId,
    Expression<int>? referenceVersion,
    Expression<String>? artifact,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (plannerModelId != null) 'planner_model_id': plannerModelId,
      if (referenceVersion != null) 'reference_version': referenceVersion,
      if (artifact != null) 'artifact': artifact,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlansCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String?>? plannerModelId,
    Value<int?>? referenceVersion,
    Value<String>? artifact,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PlansCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      plannerModelId: plannerModelId ?? this.plannerModelId,
      referenceVersion: referenceVersion ?? this.referenceVersion,
      artifact: artifact ?? this.artifact,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (plannerModelId.present) {
      map['planner_model_id'] = Variable<String>(plannerModelId.value);
    }
    if (referenceVersion.present) {
      map['reference_version'] = Variable<int>(referenceVersion.value);
    }
    if (artifact.present) {
      map['artifact'] = Variable<String>(artifact.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlansCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('plannerModelId: $plannerModelId, ')
          ..write('referenceVersion: $referenceVersion, ')
          ..write('artifact: $artifact, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskRunsTable extends TaskRuns with TableInfo<$TaskRunsTable, TaskRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES runs (id)',
    ),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseTextMeta = const VerificationMeta(
    'responseText',
  );
  @override
  late final GeneratedColumn<String> responseText = GeneratedColumn<String>(
    'response_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptTokensMeta = const VerificationMeta(
    'promptTokens',
  );
  @override
  late final GeneratedColumn<int> promptTokens = GeneratedColumn<int>(
    'prompt_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completionTokensMeta = const VerificationMeta(
    'completionTokens',
  );
  @override
  late final GeneratedColumn<int> completionTokens = GeneratedColumn<int>(
    'completion_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aggregateScoreMeta = const VerificationMeta(
    'aggregateScore',
  );
  @override
  late final GeneratedColumn<double> aggregateScore = GeneratedColumn<double>(
    'aggregate_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plans (id)',
    ),
  );
  static const VerificationMeta _trialIndexMeta = const VerificationMeta(
    'trialIndex',
  );
  @override
  late final GeneratedColumn<int> trialIndex = GeneratedColumn<int>(
    'trial_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _taskVersionMeta = const VerificationMeta(
    'taskVersion',
  );
  @override
  late final GeneratedColumn<int> taskVersion = GeneratedColumn<int>(
    'task_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _benchmarkTrackMeta = const VerificationMeta(
    'benchmarkTrack',
  );
  @override
  late final GeneratedColumn<String> benchmarkTrack = GeneratedColumn<String>(
    'benchmark_track',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('codegen'),
  );
  static const VerificationMeta _harnessIdMeta = const VerificationMeta(
    'harnessId',
  );
  @override
  late final GeneratedColumn<String> harnessId = GeneratedColumn<String>(
    'harness_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryPassMeta = const VerificationMeta(
    'primaryPass',
  );
  @override
  late final GeneratedColumn<bool> primaryPass = GeneratedColumn<bool>(
    'primary_pass',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("primary_pass" IN (0, 1))',
    ),
  );
  static const VerificationMeta _failureTagMeta = const VerificationMeta(
    'failureTag',
  );
  @override
  late final GeneratedColumn<String> failureTag = GeneratedColumn<String>(
    'failure_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _patchTextMeta = const VerificationMeta(
    'patchText',
  );
  @override
  late final GeneratedColumn<String> patchText = GeneratedColumn<String>(
    'patch_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trajectoryLogPathMeta = const VerificationMeta(
    'trajectoryLogPath',
  );
  @override
  late final GeneratedColumn<String> trajectoryLogPath =
      GeneratedColumn<String>(
        'trajectory_log_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    providerId,
    modelId,
    taskId,
    responseText,
    promptTokens,
    completionTokens,
    latencyMs,
    aggregateScore,
    completedAt,
    planId,
    trialIndex,
    taskVersion,
    benchmarkTrack,
    harnessId,
    primaryPass,
    failureTag,
    patchText,
    trajectoryLogPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('response_text')) {
      context.handle(
        _responseTextMeta,
        responseText.isAcceptableOrUnknown(
          data['response_text']!,
          _responseTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseTextMeta);
    }
    if (data.containsKey('prompt_tokens')) {
      context.handle(
        _promptTokensMeta,
        promptTokens.isAcceptableOrUnknown(
          data['prompt_tokens']!,
          _promptTokensMeta,
        ),
      );
    }
    if (data.containsKey('completion_tokens')) {
      context.handle(
        _completionTokensMeta,
        completionTokens.isAcceptableOrUnknown(
          data['completion_tokens']!,
          _completionTokensMeta,
        ),
      );
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    } else if (isInserting) {
      context.missing(_latencyMsMeta);
    }
    if (data.containsKey('aggregate_score')) {
      context.handle(
        _aggregateScoreMeta,
        aggregateScore.isAcceptableOrUnknown(
          data['aggregate_score']!,
          _aggregateScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aggregateScoreMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    }
    if (data.containsKey('trial_index')) {
      context.handle(
        _trialIndexMeta,
        trialIndex.isAcceptableOrUnknown(data['trial_index']!, _trialIndexMeta),
      );
    }
    if (data.containsKey('task_version')) {
      context.handle(
        _taskVersionMeta,
        taskVersion.isAcceptableOrUnknown(
          data['task_version']!,
          _taskVersionMeta,
        ),
      );
    }
    if (data.containsKey('benchmark_track')) {
      context.handle(
        _benchmarkTrackMeta,
        benchmarkTrack.isAcceptableOrUnknown(
          data['benchmark_track']!,
          _benchmarkTrackMeta,
        ),
      );
    }
    if (data.containsKey('harness_id')) {
      context.handle(
        _harnessIdMeta,
        harnessId.isAcceptableOrUnknown(data['harness_id']!, _harnessIdMeta),
      );
    }
    if (data.containsKey('primary_pass')) {
      context.handle(
        _primaryPassMeta,
        primaryPass.isAcceptableOrUnknown(
          data['primary_pass']!,
          _primaryPassMeta,
        ),
      );
    }
    if (data.containsKey('failure_tag')) {
      context.handle(
        _failureTagMeta,
        failureTag.isAcceptableOrUnknown(data['failure_tag']!, _failureTagMeta),
      );
    }
    if (data.containsKey('patch_text')) {
      context.handle(
        _patchTextMeta,
        patchText.isAcceptableOrUnknown(data['patch_text']!, _patchTextMeta),
      );
    }
    if (data.containsKey('trajectory_log_path')) {
      context.handle(
        _trajectoryLogPathMeta,
        trajectoryLogPath.isAcceptableOrUnknown(
          data['trajectory_log_path']!,
          _trajectoryLogPathMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      responseText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_text'],
      )!,
      promptTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prompt_tokens'],
      ),
      completionTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_tokens'],
      ),
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      )!,
      aggregateScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aggregate_score'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      ),
      trialIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trial_index'],
      )!,
      taskVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_version'],
      )!,
      benchmarkTrack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}benchmark_track'],
      )!,
      harnessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harness_id'],
      ),
      primaryPass: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}primary_pass'],
      ),
      failureTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_tag'],
      ),
      patchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patch_text'],
      ),
      trajectoryLogPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trajectory_log_path'],
      ),
    );
  }

  @override
  $TaskRunsTable createAlias(String alias) {
    return $TaskRunsTable(attachedDatabase, alias);
  }
}

class TaskRun extends DataClass implements Insertable<TaskRun> {
  final String id;
  final String runId;
  final String providerId;
  final String modelId;
  final String taskId;
  final String responseText;
  final int? promptTokens;
  final int? completionTokens;
  final int latencyMs;
  final double aggregateScore;
  final DateTime completedAt;
  final String? planId;
  final int trialIndex;
  final int taskVersion;
  final String benchmarkTrack;
  final String? harnessId;
  final bool? primaryPass;
  final String? failureTag;
  final String? patchText;
  final String? trajectoryLogPath;
  const TaskRun({
    required this.id,
    required this.runId,
    required this.providerId,
    required this.modelId,
    required this.taskId,
    required this.responseText,
    this.promptTokens,
    this.completionTokens,
    required this.latencyMs,
    required this.aggregateScore,
    required this.completedAt,
    this.planId,
    required this.trialIndex,
    required this.taskVersion,
    required this.benchmarkTrack,
    this.harnessId,
    this.primaryPass,
    this.failureTag,
    this.patchText,
    this.trajectoryLogPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['provider_id'] = Variable<String>(providerId);
    map['model_id'] = Variable<String>(modelId);
    map['task_id'] = Variable<String>(taskId);
    map['response_text'] = Variable<String>(responseText);
    if (!nullToAbsent || promptTokens != null) {
      map['prompt_tokens'] = Variable<int>(promptTokens);
    }
    if (!nullToAbsent || completionTokens != null) {
      map['completion_tokens'] = Variable<int>(completionTokens);
    }
    map['latency_ms'] = Variable<int>(latencyMs);
    map['aggregate_score'] = Variable<double>(aggregateScore);
    map['completed_at'] = Variable<DateTime>(completedAt);
    if (!nullToAbsent || planId != null) {
      map['plan_id'] = Variable<String>(planId);
    }
    map['trial_index'] = Variable<int>(trialIndex);
    map['task_version'] = Variable<int>(taskVersion);
    map['benchmark_track'] = Variable<String>(benchmarkTrack);
    if (!nullToAbsent || harnessId != null) {
      map['harness_id'] = Variable<String>(harnessId);
    }
    if (!nullToAbsent || primaryPass != null) {
      map['primary_pass'] = Variable<bool>(primaryPass);
    }
    if (!nullToAbsent || failureTag != null) {
      map['failure_tag'] = Variable<String>(failureTag);
    }
    if (!nullToAbsent || patchText != null) {
      map['patch_text'] = Variable<String>(patchText);
    }
    if (!nullToAbsent || trajectoryLogPath != null) {
      map['trajectory_log_path'] = Variable<String>(trajectoryLogPath);
    }
    return map;
  }

  TaskRunsCompanion toCompanion(bool nullToAbsent) {
    return TaskRunsCompanion(
      id: Value(id),
      runId: Value(runId),
      providerId: Value(providerId),
      modelId: Value(modelId),
      taskId: Value(taskId),
      responseText: Value(responseText),
      promptTokens: promptTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(promptTokens),
      completionTokens: completionTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(completionTokens),
      latencyMs: Value(latencyMs),
      aggregateScore: Value(aggregateScore),
      completedAt: Value(completedAt),
      planId: planId == null && nullToAbsent
          ? const Value.absent()
          : Value(planId),
      trialIndex: Value(trialIndex),
      taskVersion: Value(taskVersion),
      benchmarkTrack: Value(benchmarkTrack),
      harnessId: harnessId == null && nullToAbsent
          ? const Value.absent()
          : Value(harnessId),
      primaryPass: primaryPass == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryPass),
      failureTag: failureTag == null && nullToAbsent
          ? const Value.absent()
          : Value(failureTag),
      patchText: patchText == null && nullToAbsent
          ? const Value.absent()
          : Value(patchText),
      trajectoryLogPath: trajectoryLogPath == null && nullToAbsent
          ? const Value.absent()
          : Value(trajectoryLogPath),
    );
  }

  factory TaskRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRun(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      modelId: serializer.fromJson<String>(json['modelId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      responseText: serializer.fromJson<String>(json['responseText']),
      promptTokens: serializer.fromJson<int?>(json['promptTokens']),
      completionTokens: serializer.fromJson<int?>(json['completionTokens']),
      latencyMs: serializer.fromJson<int>(json['latencyMs']),
      aggregateScore: serializer.fromJson<double>(json['aggregateScore']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      planId: serializer.fromJson<String?>(json['planId']),
      trialIndex: serializer.fromJson<int>(json['trialIndex']),
      taskVersion: serializer.fromJson<int>(json['taskVersion']),
      benchmarkTrack: serializer.fromJson<String>(json['benchmarkTrack']),
      harnessId: serializer.fromJson<String?>(json['harnessId']),
      primaryPass: serializer.fromJson<bool?>(json['primaryPass']),
      failureTag: serializer.fromJson<String?>(json['failureTag']),
      patchText: serializer.fromJson<String?>(json['patchText']),
      trajectoryLogPath: serializer.fromJson<String?>(
        json['trajectoryLogPath'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'providerId': serializer.toJson<String>(providerId),
      'modelId': serializer.toJson<String>(modelId),
      'taskId': serializer.toJson<String>(taskId),
      'responseText': serializer.toJson<String>(responseText),
      'promptTokens': serializer.toJson<int?>(promptTokens),
      'completionTokens': serializer.toJson<int?>(completionTokens),
      'latencyMs': serializer.toJson<int>(latencyMs),
      'aggregateScore': serializer.toJson<double>(aggregateScore),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'planId': serializer.toJson<String?>(planId),
      'trialIndex': serializer.toJson<int>(trialIndex),
      'taskVersion': serializer.toJson<int>(taskVersion),
      'benchmarkTrack': serializer.toJson<String>(benchmarkTrack),
      'harnessId': serializer.toJson<String?>(harnessId),
      'primaryPass': serializer.toJson<bool?>(primaryPass),
      'failureTag': serializer.toJson<String?>(failureTag),
      'patchText': serializer.toJson<String?>(patchText),
      'trajectoryLogPath': serializer.toJson<String?>(trajectoryLogPath),
    };
  }

  TaskRun copyWith({
    String? id,
    String? runId,
    String? providerId,
    String? modelId,
    String? taskId,
    String? responseText,
    Value<int?> promptTokens = const Value.absent(),
    Value<int?> completionTokens = const Value.absent(),
    int? latencyMs,
    double? aggregateScore,
    DateTime? completedAt,
    Value<String?> planId = const Value.absent(),
    int? trialIndex,
    int? taskVersion,
    String? benchmarkTrack,
    Value<String?> harnessId = const Value.absent(),
    Value<bool?> primaryPass = const Value.absent(),
    Value<String?> failureTag = const Value.absent(),
    Value<String?> patchText = const Value.absent(),
    Value<String?> trajectoryLogPath = const Value.absent(),
  }) => TaskRun(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    providerId: providerId ?? this.providerId,
    modelId: modelId ?? this.modelId,
    taskId: taskId ?? this.taskId,
    responseText: responseText ?? this.responseText,
    promptTokens: promptTokens.present ? promptTokens.value : this.promptTokens,
    completionTokens: completionTokens.present
        ? completionTokens.value
        : this.completionTokens,
    latencyMs: latencyMs ?? this.latencyMs,
    aggregateScore: aggregateScore ?? this.aggregateScore,
    completedAt: completedAt ?? this.completedAt,
    planId: planId.present ? planId.value : this.planId,
    trialIndex: trialIndex ?? this.trialIndex,
    taskVersion: taskVersion ?? this.taskVersion,
    benchmarkTrack: benchmarkTrack ?? this.benchmarkTrack,
    harnessId: harnessId.present ? harnessId.value : this.harnessId,
    primaryPass: primaryPass.present ? primaryPass.value : this.primaryPass,
    failureTag: failureTag.present ? failureTag.value : this.failureTag,
    patchText: patchText.present ? patchText.value : this.patchText,
    trajectoryLogPath: trajectoryLogPath.present
        ? trajectoryLogPath.value
        : this.trajectoryLogPath,
  );
  TaskRun copyWithCompanion(TaskRunsCompanion data) {
    return TaskRun(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      responseText: data.responseText.present
          ? data.responseText.value
          : this.responseText,
      promptTokens: data.promptTokens.present
          ? data.promptTokens.value
          : this.promptTokens,
      completionTokens: data.completionTokens.present
          ? data.completionTokens.value
          : this.completionTokens,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      aggregateScore: data.aggregateScore.present
          ? data.aggregateScore.value
          : this.aggregateScore,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      planId: data.planId.present ? data.planId.value : this.planId,
      trialIndex: data.trialIndex.present
          ? data.trialIndex.value
          : this.trialIndex,
      taskVersion: data.taskVersion.present
          ? data.taskVersion.value
          : this.taskVersion,
      benchmarkTrack: data.benchmarkTrack.present
          ? data.benchmarkTrack.value
          : this.benchmarkTrack,
      harnessId: data.harnessId.present ? data.harnessId.value : this.harnessId,
      primaryPass: data.primaryPass.present
          ? data.primaryPass.value
          : this.primaryPass,
      failureTag: data.failureTag.present
          ? data.failureTag.value
          : this.failureTag,
      patchText: data.patchText.present ? data.patchText.value : this.patchText,
      trajectoryLogPath: data.trajectoryLogPath.present
          ? data.trajectoryLogPath.value
          : this.trajectoryLogPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRun(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('providerId: $providerId, ')
          ..write('modelId: $modelId, ')
          ..write('taskId: $taskId, ')
          ..write('responseText: $responseText, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('aggregateScore: $aggregateScore, ')
          ..write('completedAt: $completedAt, ')
          ..write('planId: $planId, ')
          ..write('trialIndex: $trialIndex, ')
          ..write('taskVersion: $taskVersion, ')
          ..write('benchmarkTrack: $benchmarkTrack, ')
          ..write('harnessId: $harnessId, ')
          ..write('primaryPass: $primaryPass, ')
          ..write('failureTag: $failureTag, ')
          ..write('patchText: $patchText, ')
          ..write('trajectoryLogPath: $trajectoryLogPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    providerId,
    modelId,
    taskId,
    responseText,
    promptTokens,
    completionTokens,
    latencyMs,
    aggregateScore,
    completedAt,
    planId,
    trialIndex,
    taskVersion,
    benchmarkTrack,
    harnessId,
    primaryPass,
    failureTag,
    patchText,
    trajectoryLogPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRun &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.providerId == this.providerId &&
          other.modelId == this.modelId &&
          other.taskId == this.taskId &&
          other.responseText == this.responseText &&
          other.promptTokens == this.promptTokens &&
          other.completionTokens == this.completionTokens &&
          other.latencyMs == this.latencyMs &&
          other.aggregateScore == this.aggregateScore &&
          other.completedAt == this.completedAt &&
          other.planId == this.planId &&
          other.trialIndex == this.trialIndex &&
          other.taskVersion == this.taskVersion &&
          other.benchmarkTrack == this.benchmarkTrack &&
          other.harnessId == this.harnessId &&
          other.primaryPass == this.primaryPass &&
          other.failureTag == this.failureTag &&
          other.patchText == this.patchText &&
          other.trajectoryLogPath == this.trajectoryLogPath);
}

class TaskRunsCompanion extends UpdateCompanion<TaskRun> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> providerId;
  final Value<String> modelId;
  final Value<String> taskId;
  final Value<String> responseText;
  final Value<int?> promptTokens;
  final Value<int?> completionTokens;
  final Value<int> latencyMs;
  final Value<double> aggregateScore;
  final Value<DateTime> completedAt;
  final Value<String?> planId;
  final Value<int> trialIndex;
  final Value<int> taskVersion;
  final Value<String> benchmarkTrack;
  final Value<String?> harnessId;
  final Value<bool?> primaryPass;
  final Value<String?> failureTag;
  final Value<String?> patchText;
  final Value<String?> trajectoryLogPath;
  final Value<int> rowid;
  const TaskRunsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.responseText = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.aggregateScore = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.planId = const Value.absent(),
    this.trialIndex = const Value.absent(),
    this.taskVersion = const Value.absent(),
    this.benchmarkTrack = const Value.absent(),
    this.harnessId = const Value.absent(),
    this.primaryPass = const Value.absent(),
    this.failureTag = const Value.absent(),
    this.patchText = const Value.absent(),
    this.trajectoryLogPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskRunsCompanion.insert({
    required String id,
    required String runId,
    required String providerId,
    required String modelId,
    required String taskId,
    required String responseText,
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    required int latencyMs,
    required double aggregateScore,
    required DateTime completedAt,
    this.planId = const Value.absent(),
    this.trialIndex = const Value.absent(),
    this.taskVersion = const Value.absent(),
    this.benchmarkTrack = const Value.absent(),
    this.harnessId = const Value.absent(),
    this.primaryPass = const Value.absent(),
    this.failureTag = const Value.absent(),
    this.patchText = const Value.absent(),
    this.trajectoryLogPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       providerId = Value(providerId),
       modelId = Value(modelId),
       taskId = Value(taskId),
       responseText = Value(responseText),
       latencyMs = Value(latencyMs),
       aggregateScore = Value(aggregateScore),
       completedAt = Value(completedAt);
  static Insertable<TaskRun> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? providerId,
    Expression<String>? modelId,
    Expression<String>? taskId,
    Expression<String>? responseText,
    Expression<int>? promptTokens,
    Expression<int>? completionTokens,
    Expression<int>? latencyMs,
    Expression<double>? aggregateScore,
    Expression<DateTime>? completedAt,
    Expression<String>? planId,
    Expression<int>? trialIndex,
    Expression<int>? taskVersion,
    Expression<String>? benchmarkTrack,
    Expression<String>? harnessId,
    Expression<bool>? primaryPass,
    Expression<String>? failureTag,
    Expression<String>? patchText,
    Expression<String>? trajectoryLogPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (providerId != null) 'provider_id': providerId,
      if (modelId != null) 'model_id': modelId,
      if (taskId != null) 'task_id': taskId,
      if (responseText != null) 'response_text': responseText,
      if (promptTokens != null) 'prompt_tokens': promptTokens,
      if (completionTokens != null) 'completion_tokens': completionTokens,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (aggregateScore != null) 'aggregate_score': aggregateScore,
      if (completedAt != null) 'completed_at': completedAt,
      if (planId != null) 'plan_id': planId,
      if (trialIndex != null) 'trial_index': trialIndex,
      if (taskVersion != null) 'task_version': taskVersion,
      if (benchmarkTrack != null) 'benchmark_track': benchmarkTrack,
      if (harnessId != null) 'harness_id': harnessId,
      if (primaryPass != null) 'primary_pass': primaryPass,
      if (failureTag != null) 'failure_tag': failureTag,
      if (patchText != null) 'patch_text': patchText,
      if (trajectoryLogPath != null) 'trajectory_log_path': trajectoryLogPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? providerId,
    Value<String>? modelId,
    Value<String>? taskId,
    Value<String>? responseText,
    Value<int?>? promptTokens,
    Value<int?>? completionTokens,
    Value<int>? latencyMs,
    Value<double>? aggregateScore,
    Value<DateTime>? completedAt,
    Value<String?>? planId,
    Value<int>? trialIndex,
    Value<int>? taskVersion,
    Value<String>? benchmarkTrack,
    Value<String?>? harnessId,
    Value<bool?>? primaryPass,
    Value<String?>? failureTag,
    Value<String?>? patchText,
    Value<String?>? trajectoryLogPath,
    Value<int>? rowid,
  }) {
    return TaskRunsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      taskId: taskId ?? this.taskId,
      responseText: responseText ?? this.responseText,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      latencyMs: latencyMs ?? this.latencyMs,
      aggregateScore: aggregateScore ?? this.aggregateScore,
      completedAt: completedAt ?? this.completedAt,
      planId: planId ?? this.planId,
      trialIndex: trialIndex ?? this.trialIndex,
      taskVersion: taskVersion ?? this.taskVersion,
      benchmarkTrack: benchmarkTrack ?? this.benchmarkTrack,
      harnessId: harnessId ?? this.harnessId,
      primaryPass: primaryPass ?? this.primaryPass,
      failureTag: failureTag ?? this.failureTag,
      patchText: patchText ?? this.patchText,
      trajectoryLogPath: trajectoryLogPath ?? this.trajectoryLogPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (responseText.present) {
      map['response_text'] = Variable<String>(responseText.value);
    }
    if (promptTokens.present) {
      map['prompt_tokens'] = Variable<int>(promptTokens.value);
    }
    if (completionTokens.present) {
      map['completion_tokens'] = Variable<int>(completionTokens.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (aggregateScore.present) {
      map['aggregate_score'] = Variable<double>(aggregateScore.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (trialIndex.present) {
      map['trial_index'] = Variable<int>(trialIndex.value);
    }
    if (taskVersion.present) {
      map['task_version'] = Variable<int>(taskVersion.value);
    }
    if (benchmarkTrack.present) {
      map['benchmark_track'] = Variable<String>(benchmarkTrack.value);
    }
    if (harnessId.present) {
      map['harness_id'] = Variable<String>(harnessId.value);
    }
    if (primaryPass.present) {
      map['primary_pass'] = Variable<bool>(primaryPass.value);
    }
    if (failureTag.present) {
      map['failure_tag'] = Variable<String>(failureTag.value);
    }
    if (patchText.present) {
      map['patch_text'] = Variable<String>(patchText.value);
    }
    if (trajectoryLogPath.present) {
      map['trajectory_log_path'] = Variable<String>(trajectoryLogPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskRunsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('providerId: $providerId, ')
          ..write('modelId: $modelId, ')
          ..write('taskId: $taskId, ')
          ..write('responseText: $responseText, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('aggregateScore: $aggregateScore, ')
          ..write('completedAt: $completedAt, ')
          ..write('planId: $planId, ')
          ..write('trialIndex: $trialIndex, ')
          ..write('taskVersion: $taskVersion, ')
          ..write('benchmarkTrack: $benchmarkTrack, ')
          ..write('harnessId: $harnessId, ')
          ..write('primaryPass: $primaryPass, ')
          ..write('failureTag: $failureTag, ')
          ..write('patchText: $patchText, ')
          ..write('trajectoryLogPath: $trajectoryLogPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EvaluationsTable extends Evaluations
    with TableInfo<$EvaluationsTable, Evaluation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EvaluationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskRunIdMeta = const VerificationMeta(
    'taskRunId',
  );
  @override
  late final GeneratedColumn<String> taskRunId = GeneratedColumn<String>(
    'task_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_runs (id)',
    ),
  );
  static const VerificationMeta _evaluatorIdMeta = const VerificationMeta(
    'evaluatorId',
  );
  @override
  late final GeneratedColumn<String> evaluatorId = GeneratedColumn<String>(
    'evaluator_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passedMeta = const VerificationMeta('passed');
  @override
  late final GeneratedColumn<bool> passed = GeneratedColumn<bool>(
    'passed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("passed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rationaleMeta = const VerificationMeta(
    'rationale',
  );
  @override
  late final GeneratedColumn<String> rationale = GeneratedColumn<String>(
    'rationale',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsJsonMeta = const VerificationMeta(
    'detailsJson',
  );
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
    'details_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskRunId,
    evaluatorId,
    passed,
    score,
    rationale,
    detailsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'evaluations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Evaluation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_run_id')) {
      context.handle(
        _taskRunIdMeta,
        taskRunId.isAcceptableOrUnknown(data['task_run_id']!, _taskRunIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskRunIdMeta);
    }
    if (data.containsKey('evaluator_id')) {
      context.handle(
        _evaluatorIdMeta,
        evaluatorId.isAcceptableOrUnknown(
          data['evaluator_id']!,
          _evaluatorIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evaluatorIdMeta);
    }
    if (data.containsKey('passed')) {
      context.handle(
        _passedMeta,
        passed.isAcceptableOrUnknown(data['passed']!, _passedMeta),
      );
    } else if (isInserting) {
      context.missing(_passedMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('rationale')) {
      context.handle(
        _rationaleMeta,
        rationale.isAcceptableOrUnknown(data['rationale']!, _rationaleMeta),
      );
    }
    if (data.containsKey('details_json')) {
      context.handle(
        _detailsJsonMeta,
        detailsJson.isAcceptableOrUnknown(
          data['details_json']!,
          _detailsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_detailsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Evaluation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Evaluation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_run_id'],
      )!,
      evaluatorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evaluator_id'],
      )!,
      passed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}passed'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      rationale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rationale'],
      ),
      detailsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details_json'],
      )!,
    );
  }

  @override
  $EvaluationsTable createAlias(String alias) {
    return $EvaluationsTable(attachedDatabase, alias);
  }
}

class Evaluation extends DataClass implements Insertable<Evaluation> {
  final String id;
  final String taskRunId;
  final String evaluatorId;
  final bool passed;
  final double score;
  final String? rationale;
  final String detailsJson;
  const Evaluation({
    required this.id,
    required this.taskRunId,
    required this.evaluatorId,
    required this.passed,
    required this.score,
    this.rationale,
    required this.detailsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_run_id'] = Variable<String>(taskRunId);
    map['evaluator_id'] = Variable<String>(evaluatorId);
    map['passed'] = Variable<bool>(passed);
    map['score'] = Variable<double>(score);
    if (!nullToAbsent || rationale != null) {
      map['rationale'] = Variable<String>(rationale);
    }
    map['details_json'] = Variable<String>(detailsJson);
    return map;
  }

  EvaluationsCompanion toCompanion(bool nullToAbsent) {
    return EvaluationsCompanion(
      id: Value(id),
      taskRunId: Value(taskRunId),
      evaluatorId: Value(evaluatorId),
      passed: Value(passed),
      score: Value(score),
      rationale: rationale == null && nullToAbsent
          ? const Value.absent()
          : Value(rationale),
      detailsJson: Value(detailsJson),
    );
  }

  factory Evaluation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Evaluation(
      id: serializer.fromJson<String>(json['id']),
      taskRunId: serializer.fromJson<String>(json['taskRunId']),
      evaluatorId: serializer.fromJson<String>(json['evaluatorId']),
      passed: serializer.fromJson<bool>(json['passed']),
      score: serializer.fromJson<double>(json['score']),
      rationale: serializer.fromJson<String?>(json['rationale']),
      detailsJson: serializer.fromJson<String>(json['detailsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskRunId': serializer.toJson<String>(taskRunId),
      'evaluatorId': serializer.toJson<String>(evaluatorId),
      'passed': serializer.toJson<bool>(passed),
      'score': serializer.toJson<double>(score),
      'rationale': serializer.toJson<String?>(rationale),
      'detailsJson': serializer.toJson<String>(detailsJson),
    };
  }

  Evaluation copyWith({
    String? id,
    String? taskRunId,
    String? evaluatorId,
    bool? passed,
    double? score,
    Value<String?> rationale = const Value.absent(),
    String? detailsJson,
  }) => Evaluation(
    id: id ?? this.id,
    taskRunId: taskRunId ?? this.taskRunId,
    evaluatorId: evaluatorId ?? this.evaluatorId,
    passed: passed ?? this.passed,
    score: score ?? this.score,
    rationale: rationale.present ? rationale.value : this.rationale,
    detailsJson: detailsJson ?? this.detailsJson,
  );
  Evaluation copyWithCompanion(EvaluationsCompanion data) {
    return Evaluation(
      id: data.id.present ? data.id.value : this.id,
      taskRunId: data.taskRunId.present ? data.taskRunId.value : this.taskRunId,
      evaluatorId: data.evaluatorId.present
          ? data.evaluatorId.value
          : this.evaluatorId,
      passed: data.passed.present ? data.passed.value : this.passed,
      score: data.score.present ? data.score.value : this.score,
      rationale: data.rationale.present ? data.rationale.value : this.rationale,
      detailsJson: data.detailsJson.present
          ? data.detailsJson.value
          : this.detailsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Evaluation(')
          ..write('id: $id, ')
          ..write('taskRunId: $taskRunId, ')
          ..write('evaluatorId: $evaluatorId, ')
          ..write('passed: $passed, ')
          ..write('score: $score, ')
          ..write('rationale: $rationale, ')
          ..write('detailsJson: $detailsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskRunId,
    evaluatorId,
    passed,
    score,
    rationale,
    detailsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Evaluation &&
          other.id == this.id &&
          other.taskRunId == this.taskRunId &&
          other.evaluatorId == this.evaluatorId &&
          other.passed == this.passed &&
          other.score == this.score &&
          other.rationale == this.rationale &&
          other.detailsJson == this.detailsJson);
}

class EvaluationsCompanion extends UpdateCompanion<Evaluation> {
  final Value<String> id;
  final Value<String> taskRunId;
  final Value<String> evaluatorId;
  final Value<bool> passed;
  final Value<double> score;
  final Value<String?> rationale;
  final Value<String> detailsJson;
  final Value<int> rowid;
  const EvaluationsCompanion({
    this.id = const Value.absent(),
    this.taskRunId = const Value.absent(),
    this.evaluatorId = const Value.absent(),
    this.passed = const Value.absent(),
    this.score = const Value.absent(),
    this.rationale = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EvaluationsCompanion.insert({
    required String id,
    required String taskRunId,
    required String evaluatorId,
    required bool passed,
    required double score,
    this.rationale = const Value.absent(),
    required String detailsJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskRunId = Value(taskRunId),
       evaluatorId = Value(evaluatorId),
       passed = Value(passed),
       score = Value(score),
       detailsJson = Value(detailsJson);
  static Insertable<Evaluation> custom({
    Expression<String>? id,
    Expression<String>? taskRunId,
    Expression<String>? evaluatorId,
    Expression<bool>? passed,
    Expression<double>? score,
    Expression<String>? rationale,
    Expression<String>? detailsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskRunId != null) 'task_run_id': taskRunId,
      if (evaluatorId != null) 'evaluator_id': evaluatorId,
      if (passed != null) 'passed': passed,
      if (score != null) 'score': score,
      if (rationale != null) 'rationale': rationale,
      if (detailsJson != null) 'details_json': detailsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EvaluationsCompanion copyWith({
    Value<String>? id,
    Value<String>? taskRunId,
    Value<String>? evaluatorId,
    Value<bool>? passed,
    Value<double>? score,
    Value<String?>? rationale,
    Value<String>? detailsJson,
    Value<int>? rowid,
  }) {
    return EvaluationsCompanion(
      id: id ?? this.id,
      taskRunId: taskRunId ?? this.taskRunId,
      evaluatorId: evaluatorId ?? this.evaluatorId,
      passed: passed ?? this.passed,
      score: score ?? this.score,
      rationale: rationale ?? this.rationale,
      detailsJson: detailsJson ?? this.detailsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskRunId.present) {
      map['task_run_id'] = Variable<String>(taskRunId.value);
    }
    if (evaluatorId.present) {
      map['evaluator_id'] = Variable<String>(evaluatorId.value);
    }
    if (passed.present) {
      map['passed'] = Variable<bool>(passed.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (rationale.present) {
      map['rationale'] = Variable<String>(rationale.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EvaluationsCompanion(')
          ..write('id: $id, ')
          ..write('taskRunId: $taskRunId, ')
          ..write('evaluatorId: $evaluatorId, ')
          ..write('passed: $passed, ')
          ..write('score: $score, ')
          ..write('rationale: $rationale, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewBattlesTable extends ReviewBattles
    with TableInfo<$ReviewBattlesTable, ReviewBattle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewBattlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskVersionMeta = const VerificationMeta(
    'taskVersion',
  );
  @override
  late final GeneratedColumn<int> taskVersion = GeneratedColumn<int>(
    'task_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _benchmarkTrackMeta = const VerificationMeta(
    'benchmarkTrack',
  );
  @override
  late final GeneratedColumn<String> benchmarkTrack = GeneratedColumn<String>(
    'benchmark_track',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leftTaskRunIdMeta = const VerificationMeta(
    'leftTaskRunId',
  );
  @override
  late final GeneratedColumn<String> leftTaskRunId = GeneratedColumn<String>(
    'left_task_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_runs (id)',
    ),
  );
  static const VerificationMeta _rightTaskRunIdMeta = const VerificationMeta(
    'rightTaskRunId',
  );
  @override
  late final GeneratedColumn<String> rightTaskRunId = GeneratedColumn<String>(
    'right_task_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_runs (id)',
    ),
  );
  static const VerificationMeta _canonicalPairKeyMeta = const VerificationMeta(
    'canonicalPairKey',
  );
  @override
  late final GeneratedColumn<String> canonicalPairKey = GeneratedColumn<String>(
    'canonical_pair_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leftLabelMeta = const VerificationMeta(
    'leftLabel',
  );
  @override
  late final GeneratedColumn<String> leftLabel = GeneratedColumn<String>(
    'left_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rightLabelMeta = const VerificationMeta(
    'rightLabel',
  );
  @override
  late final GeneratedColumn<String> rightLabel = GeneratedColumn<String>(
    'right_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewerIdMeta = const VerificationMeta(
    'reviewerId',
  );
  @override
  late final GeneratedColumn<String> reviewerId = GeneratedColumn<String>(
    'reviewer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewerAliasMeta = const VerificationMeta(
    'reviewerAlias',
  );
  @override
  late final GeneratedColumn<String> reviewerAlias = GeneratedColumn<String>(
    'reviewer_alias',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voteMeta = const VerificationMeta('vote');
  @override
  late final GeneratedColumn<String> vote = GeneratedColumn<String>(
    'vote',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rationaleMeta = const VerificationMeta(
    'rationale',
  );
  @override
  late final GeneratedColumn<String> rationale = GeneratedColumn<String>(
    'rationale',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    taskVersion,
    benchmarkTrack,
    leftTaskRunId,
    rightTaskRunId,
    canonicalPairKey,
    leftLabel,
    rightLabel,
    reviewerId,
    reviewerAlias,
    vote,
    rationale,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_battles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewBattle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('task_version')) {
      context.handle(
        _taskVersionMeta,
        taskVersion.isAcceptableOrUnknown(
          data['task_version']!,
          _taskVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_taskVersionMeta);
    }
    if (data.containsKey('benchmark_track')) {
      context.handle(
        _benchmarkTrackMeta,
        benchmarkTrack.isAcceptableOrUnknown(
          data['benchmark_track']!,
          _benchmarkTrackMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_benchmarkTrackMeta);
    }
    if (data.containsKey('left_task_run_id')) {
      context.handle(
        _leftTaskRunIdMeta,
        leftTaskRunId.isAcceptableOrUnknown(
          data['left_task_run_id']!,
          _leftTaskRunIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_leftTaskRunIdMeta);
    }
    if (data.containsKey('right_task_run_id')) {
      context.handle(
        _rightTaskRunIdMeta,
        rightTaskRunId.isAcceptableOrUnknown(
          data['right_task_run_id']!,
          _rightTaskRunIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rightTaskRunIdMeta);
    }
    if (data.containsKey('canonical_pair_key')) {
      context.handle(
        _canonicalPairKeyMeta,
        canonicalPairKey.isAcceptableOrUnknown(
          data['canonical_pair_key']!,
          _canonicalPairKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalPairKeyMeta);
    }
    if (data.containsKey('left_label')) {
      context.handle(
        _leftLabelMeta,
        leftLabel.isAcceptableOrUnknown(data['left_label']!, _leftLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_leftLabelMeta);
    }
    if (data.containsKey('right_label')) {
      context.handle(
        _rightLabelMeta,
        rightLabel.isAcceptableOrUnknown(data['right_label']!, _rightLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_rightLabelMeta);
    }
    if (data.containsKey('reviewer_id')) {
      context.handle(
        _reviewerIdMeta,
        reviewerId.isAcceptableOrUnknown(data['reviewer_id']!, _reviewerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewerIdMeta);
    }
    if (data.containsKey('reviewer_alias')) {
      context.handle(
        _reviewerAliasMeta,
        reviewerAlias.isAcceptableOrUnknown(
          data['reviewer_alias']!,
          _reviewerAliasMeta,
        ),
      );
    }
    if (data.containsKey('vote')) {
      context.handle(
        _voteMeta,
        vote.isAcceptableOrUnknown(data['vote']!, _voteMeta),
      );
    } else if (isInserting) {
      context.missing(_voteMeta);
    }
    if (data.containsKey('rationale')) {
      context.handle(
        _rationaleMeta,
        rationale.isAcceptableOrUnknown(data['rationale']!, _rationaleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {reviewerId, canonicalPairKey},
  ];
  @override
  ReviewBattle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewBattle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      taskVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_version'],
      )!,
      benchmarkTrack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}benchmark_track'],
      )!,
      leftTaskRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}left_task_run_id'],
      )!,
      rightTaskRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}right_task_run_id'],
      )!,
      canonicalPairKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_pair_key'],
      )!,
      leftLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}left_label'],
      )!,
      rightLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}right_label'],
      )!,
      reviewerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewer_id'],
      )!,
      reviewerAlias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewer_alias'],
      ),
      vote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vote'],
      )!,
      rationale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rationale'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReviewBattlesTable createAlias(String alias) {
    return $ReviewBattlesTable(attachedDatabase, alias);
  }
}

class ReviewBattle extends DataClass implements Insertable<ReviewBattle> {
  final String id;
  final String taskId;
  final int taskVersion;
  final String benchmarkTrack;
  final String leftTaskRunId;
  final String rightTaskRunId;
  final String canonicalPairKey;
  final String leftLabel;
  final String rightLabel;
  final String reviewerId;
  final String? reviewerAlias;
  final String vote;
  final String? rationale;
  final DateTime createdAt;
  const ReviewBattle({
    required this.id,
    required this.taskId,
    required this.taskVersion,
    required this.benchmarkTrack,
    required this.leftTaskRunId,
    required this.rightTaskRunId,
    required this.canonicalPairKey,
    required this.leftLabel,
    required this.rightLabel,
    required this.reviewerId,
    this.reviewerAlias,
    required this.vote,
    this.rationale,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['task_version'] = Variable<int>(taskVersion);
    map['benchmark_track'] = Variable<String>(benchmarkTrack);
    map['left_task_run_id'] = Variable<String>(leftTaskRunId);
    map['right_task_run_id'] = Variable<String>(rightTaskRunId);
    map['canonical_pair_key'] = Variable<String>(canonicalPairKey);
    map['left_label'] = Variable<String>(leftLabel);
    map['right_label'] = Variable<String>(rightLabel);
    map['reviewer_id'] = Variable<String>(reviewerId);
    if (!nullToAbsent || reviewerAlias != null) {
      map['reviewer_alias'] = Variable<String>(reviewerAlias);
    }
    map['vote'] = Variable<String>(vote);
    if (!nullToAbsent || rationale != null) {
      map['rationale'] = Variable<String>(rationale);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReviewBattlesCompanion toCompanion(bool nullToAbsent) {
    return ReviewBattlesCompanion(
      id: Value(id),
      taskId: Value(taskId),
      taskVersion: Value(taskVersion),
      benchmarkTrack: Value(benchmarkTrack),
      leftTaskRunId: Value(leftTaskRunId),
      rightTaskRunId: Value(rightTaskRunId),
      canonicalPairKey: Value(canonicalPairKey),
      leftLabel: Value(leftLabel),
      rightLabel: Value(rightLabel),
      reviewerId: Value(reviewerId),
      reviewerAlias: reviewerAlias == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewerAlias),
      vote: Value(vote),
      rationale: rationale == null && nullToAbsent
          ? const Value.absent()
          : Value(rationale),
      createdAt: Value(createdAt),
    );
  }

  factory ReviewBattle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewBattle(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      taskVersion: serializer.fromJson<int>(json['taskVersion']),
      benchmarkTrack: serializer.fromJson<String>(json['benchmarkTrack']),
      leftTaskRunId: serializer.fromJson<String>(json['leftTaskRunId']),
      rightTaskRunId: serializer.fromJson<String>(json['rightTaskRunId']),
      canonicalPairKey: serializer.fromJson<String>(json['canonicalPairKey']),
      leftLabel: serializer.fromJson<String>(json['leftLabel']),
      rightLabel: serializer.fromJson<String>(json['rightLabel']),
      reviewerId: serializer.fromJson<String>(json['reviewerId']),
      reviewerAlias: serializer.fromJson<String?>(json['reviewerAlias']),
      vote: serializer.fromJson<String>(json['vote']),
      rationale: serializer.fromJson<String?>(json['rationale']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'taskVersion': serializer.toJson<int>(taskVersion),
      'benchmarkTrack': serializer.toJson<String>(benchmarkTrack),
      'leftTaskRunId': serializer.toJson<String>(leftTaskRunId),
      'rightTaskRunId': serializer.toJson<String>(rightTaskRunId),
      'canonicalPairKey': serializer.toJson<String>(canonicalPairKey),
      'leftLabel': serializer.toJson<String>(leftLabel),
      'rightLabel': serializer.toJson<String>(rightLabel),
      'reviewerId': serializer.toJson<String>(reviewerId),
      'reviewerAlias': serializer.toJson<String?>(reviewerAlias),
      'vote': serializer.toJson<String>(vote),
      'rationale': serializer.toJson<String?>(rationale),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReviewBattle copyWith({
    String? id,
    String? taskId,
    int? taskVersion,
    String? benchmarkTrack,
    String? leftTaskRunId,
    String? rightTaskRunId,
    String? canonicalPairKey,
    String? leftLabel,
    String? rightLabel,
    String? reviewerId,
    Value<String?> reviewerAlias = const Value.absent(),
    String? vote,
    Value<String?> rationale = const Value.absent(),
    DateTime? createdAt,
  }) => ReviewBattle(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    taskVersion: taskVersion ?? this.taskVersion,
    benchmarkTrack: benchmarkTrack ?? this.benchmarkTrack,
    leftTaskRunId: leftTaskRunId ?? this.leftTaskRunId,
    rightTaskRunId: rightTaskRunId ?? this.rightTaskRunId,
    canonicalPairKey: canonicalPairKey ?? this.canonicalPairKey,
    leftLabel: leftLabel ?? this.leftLabel,
    rightLabel: rightLabel ?? this.rightLabel,
    reviewerId: reviewerId ?? this.reviewerId,
    reviewerAlias: reviewerAlias.present
        ? reviewerAlias.value
        : this.reviewerAlias,
    vote: vote ?? this.vote,
    rationale: rationale.present ? rationale.value : this.rationale,
    createdAt: createdAt ?? this.createdAt,
  );
  ReviewBattle copyWithCompanion(ReviewBattlesCompanion data) {
    return ReviewBattle(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      taskVersion: data.taskVersion.present
          ? data.taskVersion.value
          : this.taskVersion,
      benchmarkTrack: data.benchmarkTrack.present
          ? data.benchmarkTrack.value
          : this.benchmarkTrack,
      leftTaskRunId: data.leftTaskRunId.present
          ? data.leftTaskRunId.value
          : this.leftTaskRunId,
      rightTaskRunId: data.rightTaskRunId.present
          ? data.rightTaskRunId.value
          : this.rightTaskRunId,
      canonicalPairKey: data.canonicalPairKey.present
          ? data.canonicalPairKey.value
          : this.canonicalPairKey,
      leftLabel: data.leftLabel.present ? data.leftLabel.value : this.leftLabel,
      rightLabel: data.rightLabel.present
          ? data.rightLabel.value
          : this.rightLabel,
      reviewerId: data.reviewerId.present
          ? data.reviewerId.value
          : this.reviewerId,
      reviewerAlias: data.reviewerAlias.present
          ? data.reviewerAlias.value
          : this.reviewerAlias,
      vote: data.vote.present ? data.vote.value : this.vote,
      rationale: data.rationale.present ? data.rationale.value : this.rationale,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewBattle(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('taskVersion: $taskVersion, ')
          ..write('benchmarkTrack: $benchmarkTrack, ')
          ..write('leftTaskRunId: $leftTaskRunId, ')
          ..write('rightTaskRunId: $rightTaskRunId, ')
          ..write('canonicalPairKey: $canonicalPairKey, ')
          ..write('leftLabel: $leftLabel, ')
          ..write('rightLabel: $rightLabel, ')
          ..write('reviewerId: $reviewerId, ')
          ..write('reviewerAlias: $reviewerAlias, ')
          ..write('vote: $vote, ')
          ..write('rationale: $rationale, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    taskVersion,
    benchmarkTrack,
    leftTaskRunId,
    rightTaskRunId,
    canonicalPairKey,
    leftLabel,
    rightLabel,
    reviewerId,
    reviewerAlias,
    vote,
    rationale,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewBattle &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.taskVersion == this.taskVersion &&
          other.benchmarkTrack == this.benchmarkTrack &&
          other.leftTaskRunId == this.leftTaskRunId &&
          other.rightTaskRunId == this.rightTaskRunId &&
          other.canonicalPairKey == this.canonicalPairKey &&
          other.leftLabel == this.leftLabel &&
          other.rightLabel == this.rightLabel &&
          other.reviewerId == this.reviewerId &&
          other.reviewerAlias == this.reviewerAlias &&
          other.vote == this.vote &&
          other.rationale == this.rationale &&
          other.createdAt == this.createdAt);
}

class ReviewBattlesCompanion extends UpdateCompanion<ReviewBattle> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<int> taskVersion;
  final Value<String> benchmarkTrack;
  final Value<String> leftTaskRunId;
  final Value<String> rightTaskRunId;
  final Value<String> canonicalPairKey;
  final Value<String> leftLabel;
  final Value<String> rightLabel;
  final Value<String> reviewerId;
  final Value<String?> reviewerAlias;
  final Value<String> vote;
  final Value<String?> rationale;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ReviewBattlesCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.taskVersion = const Value.absent(),
    this.benchmarkTrack = const Value.absent(),
    this.leftTaskRunId = const Value.absent(),
    this.rightTaskRunId = const Value.absent(),
    this.canonicalPairKey = const Value.absent(),
    this.leftLabel = const Value.absent(),
    this.rightLabel = const Value.absent(),
    this.reviewerId = const Value.absent(),
    this.reviewerAlias = const Value.absent(),
    this.vote = const Value.absent(),
    this.rationale = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewBattlesCompanion.insert({
    required String id,
    required String taskId,
    required int taskVersion,
    required String benchmarkTrack,
    required String leftTaskRunId,
    required String rightTaskRunId,
    required String canonicalPairKey,
    required String leftLabel,
    required String rightLabel,
    required String reviewerId,
    this.reviewerAlias = const Value.absent(),
    required String vote,
    this.rationale = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       taskVersion = Value(taskVersion),
       benchmarkTrack = Value(benchmarkTrack),
       leftTaskRunId = Value(leftTaskRunId),
       rightTaskRunId = Value(rightTaskRunId),
       canonicalPairKey = Value(canonicalPairKey),
       leftLabel = Value(leftLabel),
       rightLabel = Value(rightLabel),
       reviewerId = Value(reviewerId),
       vote = Value(vote),
       createdAt = Value(createdAt);
  static Insertable<ReviewBattle> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<int>? taskVersion,
    Expression<String>? benchmarkTrack,
    Expression<String>? leftTaskRunId,
    Expression<String>? rightTaskRunId,
    Expression<String>? canonicalPairKey,
    Expression<String>? leftLabel,
    Expression<String>? rightLabel,
    Expression<String>? reviewerId,
    Expression<String>? reviewerAlias,
    Expression<String>? vote,
    Expression<String>? rationale,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (taskVersion != null) 'task_version': taskVersion,
      if (benchmarkTrack != null) 'benchmark_track': benchmarkTrack,
      if (leftTaskRunId != null) 'left_task_run_id': leftTaskRunId,
      if (rightTaskRunId != null) 'right_task_run_id': rightTaskRunId,
      if (canonicalPairKey != null) 'canonical_pair_key': canonicalPairKey,
      if (leftLabel != null) 'left_label': leftLabel,
      if (rightLabel != null) 'right_label': rightLabel,
      if (reviewerId != null) 'reviewer_id': reviewerId,
      if (reviewerAlias != null) 'reviewer_alias': reviewerAlias,
      if (vote != null) 'vote': vote,
      if (rationale != null) 'rationale': rationale,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewBattlesCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<int>? taskVersion,
    Value<String>? benchmarkTrack,
    Value<String>? leftTaskRunId,
    Value<String>? rightTaskRunId,
    Value<String>? canonicalPairKey,
    Value<String>? leftLabel,
    Value<String>? rightLabel,
    Value<String>? reviewerId,
    Value<String?>? reviewerAlias,
    Value<String>? vote,
    Value<String?>? rationale,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ReviewBattlesCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      taskVersion: taskVersion ?? this.taskVersion,
      benchmarkTrack: benchmarkTrack ?? this.benchmarkTrack,
      leftTaskRunId: leftTaskRunId ?? this.leftTaskRunId,
      rightTaskRunId: rightTaskRunId ?? this.rightTaskRunId,
      canonicalPairKey: canonicalPairKey ?? this.canonicalPairKey,
      leftLabel: leftLabel ?? this.leftLabel,
      rightLabel: rightLabel ?? this.rightLabel,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerAlias: reviewerAlias ?? this.reviewerAlias,
      vote: vote ?? this.vote,
      rationale: rationale ?? this.rationale,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (taskVersion.present) {
      map['task_version'] = Variable<int>(taskVersion.value);
    }
    if (benchmarkTrack.present) {
      map['benchmark_track'] = Variable<String>(benchmarkTrack.value);
    }
    if (leftTaskRunId.present) {
      map['left_task_run_id'] = Variable<String>(leftTaskRunId.value);
    }
    if (rightTaskRunId.present) {
      map['right_task_run_id'] = Variable<String>(rightTaskRunId.value);
    }
    if (canonicalPairKey.present) {
      map['canonical_pair_key'] = Variable<String>(canonicalPairKey.value);
    }
    if (leftLabel.present) {
      map['left_label'] = Variable<String>(leftLabel.value);
    }
    if (rightLabel.present) {
      map['right_label'] = Variable<String>(rightLabel.value);
    }
    if (reviewerId.present) {
      map['reviewer_id'] = Variable<String>(reviewerId.value);
    }
    if (reviewerAlias.present) {
      map['reviewer_alias'] = Variable<String>(reviewerAlias.value);
    }
    if (vote.present) {
      map['vote'] = Variable<String>(vote.value);
    }
    if (rationale.present) {
      map['rationale'] = Variable<String>(rationale.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewBattlesCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('taskVersion: $taskVersion, ')
          ..write('benchmarkTrack: $benchmarkTrack, ')
          ..write('leftTaskRunId: $leftTaskRunId, ')
          ..write('rightTaskRunId: $rightTaskRunId, ')
          ..write('canonicalPairKey: $canonicalPairKey, ')
          ..write('leftLabel: $leftLabel, ')
          ..write('rightLabel: $rightLabel, ')
          ..write('reviewerId: $reviewerId, ')
          ..write('reviewerAlias: $reviewerAlias, ')
          ..write('vote: $vote, ')
          ..write('rationale: $rationale, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RunsTable runs = $RunsTable(this);
  late final $PlansTable plans = $PlansTable(this);
  late final $TaskRunsTable taskRuns = $TaskRunsTable(this);
  late final $EvaluationsTable evaluations = $EvaluationsTable(this);
  late final $ReviewBattlesTable reviewBattles = $ReviewBattlesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    runs,
    plans,
    taskRuns,
    evaluations,
    reviewBattles,
  ];
}

typedef $$RunsTableCreateCompanionBuilder =
    RunsCompanion Function({
      required String id,
      required DateTime startedAt,
      Value<DateTime?> completedAt,
      Value<String?> judgeModel,
      Value<String?> name,
      Value<String?> provenanceJson,
      Value<int> rowid,
    });
typedef $$RunsTableUpdateCompanionBuilder =
    RunsCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<String?> judgeModel,
      Value<String?> name,
      Value<String?> provenanceJson,
      Value<int> rowid,
    });

final class $$RunsTableReferences
    extends BaseReferences<_$AppDatabase, $RunsTable, Run> {
  $$RunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TaskRunsTable, List<TaskRun>> _taskRunsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskRuns,
    aliasName: $_aliasNameGenerator(db.runs.id, db.taskRuns.runId),
  );

  $$TaskRunsTableProcessedTableManager get taskRunsRefs {
    final manager = $$TaskRunsTableTableManager(
      $_db,
      $_db.taskRuns,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RunsTableFilterComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get judgeModel => $composableBuilder(
    column: $table.judgeModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provenanceJson => $composableBuilder(
    column: $table.provenanceJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskRunsRefs(
    Expression<bool> Function($$TaskRunsTableFilterComposer f) f,
  ) {
    final $$TaskRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableFilterComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunsTableOrderingComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get judgeModel => $composableBuilder(
    column: $table.judgeModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provenanceJson => $composableBuilder(
    column: $table.provenanceJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get judgeModel => $composableBuilder(
    column: $table.judgeModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get provenanceJson => $composableBuilder(
    column: $table.provenanceJson,
    builder: (column) => column,
  );

  Expression<T> taskRunsRefs<T extends Object>(
    Expression<T> Function($$TaskRunsTableAnnotationComposer a) f,
  ) {
    final $$TaskRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunsTable,
          Run,
          $$RunsTableFilterComposer,
          $$RunsTableOrderingComposer,
          $$RunsTableAnnotationComposer,
          $$RunsTableCreateCompanionBuilder,
          $$RunsTableUpdateCompanionBuilder,
          (Run, $$RunsTableReferences),
          Run,
          PrefetchHooks Function({bool taskRunsRefs})
        > {
  $$RunsTableTableManager(_$AppDatabase db, $RunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> judgeModel = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> provenanceJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion(
                id: id,
                startedAt: startedAt,
                completedAt: completedAt,
                judgeModel: judgeModel,
                name: name,
                provenanceJson: provenanceJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> judgeModel = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> provenanceJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion.insert(
                id: id,
                startedAt: startedAt,
                completedAt: completedAt,
                judgeModel: judgeModel,
                name: name,
                provenanceJson: provenanceJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RunsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({taskRunsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (taskRunsRefs) db.taskRuns],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (taskRunsRefs)
                    await $_getPrefetchedData<Run, $RunsTable, TaskRun>(
                      currentTable: table,
                      referencedTable: $$RunsTableReferences._taskRunsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$RunsTableReferences(db, table, p0).taskRunsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.runId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunsTable,
      Run,
      $$RunsTableFilterComposer,
      $$RunsTableOrderingComposer,
      $$RunsTableAnnotationComposer,
      $$RunsTableCreateCompanionBuilder,
      $$RunsTableUpdateCompanionBuilder,
      (Run, $$RunsTableReferences),
      Run,
      PrefetchHooks Function({bool taskRunsRefs})
    >;
typedef $$PlansTableCreateCompanionBuilder =
    PlansCompanion Function({
      required String id,
      required String taskId,
      Value<String?> plannerModelId,
      Value<int?> referenceVersion,
      required String artifact,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PlansTableUpdateCompanionBuilder =
    PlansCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String?> plannerModelId,
      Value<int?> referenceVersion,
      Value<String> artifact,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PlansTableReferences
    extends BaseReferences<_$AppDatabase, $PlansTable, Plan> {
  $$PlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TaskRunsTable, List<TaskRun>> _taskRunsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskRuns,
    aliasName: $_aliasNameGenerator(db.plans.id, db.taskRuns.planId),
  );

  $$TaskRunsTableProcessedTableManager get taskRunsRefs {
    final manager = $$TaskRunsTableTableManager(
      $_db,
      $_db.taskRuns,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlansTableFilterComposer extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plannerModelId => $composableBuilder(
    column: $table.plannerModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get referenceVersion => $composableBuilder(
    column: $table.referenceVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artifact => $composableBuilder(
    column: $table.artifact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskRunsRefs(
    Expression<bool> Function($$TaskRunsTableFilterComposer f) f,
  ) {
    final $$TaskRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableFilterComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlansTableOrderingComposer
    extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plannerModelId => $composableBuilder(
    column: $table.plannerModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get referenceVersion => $composableBuilder(
    column: $table.referenceVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artifact => $composableBuilder(
    column: $table.artifact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get plannerModelId => $composableBuilder(
    column: $table.plannerModelId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get referenceVersion => $composableBuilder(
    column: $table.referenceVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artifact =>
      $composableBuilder(column: $table.artifact, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> taskRunsRefs<T extends Object>(
    Expression<T> Function($$TaskRunsTableAnnotationComposer a) f,
  ) {
    final $$TaskRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlansTable,
          Plan,
          $$PlansTableFilterComposer,
          $$PlansTableOrderingComposer,
          $$PlansTableAnnotationComposer,
          $$PlansTableCreateCompanionBuilder,
          $$PlansTableUpdateCompanionBuilder,
          (Plan, $$PlansTableReferences),
          Plan,
          PrefetchHooks Function({bool taskRunsRefs})
        > {
  $$PlansTableTableManager(_$AppDatabase db, $PlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String?> plannerModelId = const Value.absent(),
                Value<int?> referenceVersion = const Value.absent(),
                Value<String> artifact = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion(
                id: id,
                taskId: taskId,
                plannerModelId: plannerModelId,
                referenceVersion: referenceVersion,
                artifact: artifact,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                Value<String?> plannerModelId = const Value.absent(),
                Value<int?> referenceVersion = const Value.absent(),
                required String artifact,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion.insert(
                id: id,
                taskId: taskId,
                plannerModelId: plannerModelId,
                referenceVersion: referenceVersion,
                artifact: artifact,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PlansTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({taskRunsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (taskRunsRefs) db.taskRuns],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (taskRunsRefs)
                    await $_getPrefetchedData<Plan, $PlansTable, TaskRun>(
                      currentTable: table,
                      referencedTable: $$PlansTableReferences
                          ._taskRunsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlansTableReferences(db, table, p0).taskRunsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.planId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlansTable,
      Plan,
      $$PlansTableFilterComposer,
      $$PlansTableOrderingComposer,
      $$PlansTableAnnotationComposer,
      $$PlansTableCreateCompanionBuilder,
      $$PlansTableUpdateCompanionBuilder,
      (Plan, $$PlansTableReferences),
      Plan,
      PrefetchHooks Function({bool taskRunsRefs})
    >;
typedef $$TaskRunsTableCreateCompanionBuilder =
    TaskRunsCompanion Function({
      required String id,
      required String runId,
      required String providerId,
      required String modelId,
      required String taskId,
      required String responseText,
      Value<int?> promptTokens,
      Value<int?> completionTokens,
      required int latencyMs,
      required double aggregateScore,
      required DateTime completedAt,
      Value<String?> planId,
      Value<int> trialIndex,
      Value<int> taskVersion,
      Value<String> benchmarkTrack,
      Value<String?> harnessId,
      Value<bool?> primaryPass,
      Value<String?> failureTag,
      Value<String?> patchText,
      Value<String?> trajectoryLogPath,
      Value<int> rowid,
    });
typedef $$TaskRunsTableUpdateCompanionBuilder =
    TaskRunsCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<String> providerId,
      Value<String> modelId,
      Value<String> taskId,
      Value<String> responseText,
      Value<int?> promptTokens,
      Value<int?> completionTokens,
      Value<int> latencyMs,
      Value<double> aggregateScore,
      Value<DateTime> completedAt,
      Value<String?> planId,
      Value<int> trialIndex,
      Value<int> taskVersion,
      Value<String> benchmarkTrack,
      Value<String?> harnessId,
      Value<bool?> primaryPass,
      Value<String?> failureTag,
      Value<String?> patchText,
      Value<String?> trajectoryLogPath,
      Value<int> rowid,
    });

final class $$TaskRunsTableReferences
    extends BaseReferences<_$AppDatabase, $TaskRunsTable, TaskRun> {
  $$TaskRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RunsTable _runIdTable(_$AppDatabase db) =>
      db.runs.createAlias($_aliasNameGenerator(db.taskRuns.runId, db.runs.id));

  $$RunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$RunsTableTableManager(
      $_db,
      $_db.runs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlansTable _planIdTable(_$AppDatabase db) => db.plans.createAlias(
    $_aliasNameGenerator(db.taskRuns.planId, db.plans.id),
  );

  $$PlansTableProcessedTableManager? get planId {
    final $_column = $_itemColumn<String>('plan_id');
    if ($_column == null) return null;
    final manager = $$PlansTableTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EvaluationsTable, List<Evaluation>>
  _evaluationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.evaluations,
    aliasName: $_aliasNameGenerator(db.taskRuns.id, db.evaluations.taskRunId),
  );

  $$EvaluationsTableProcessedTableManager get evaluationsRefs {
    final manager = $$EvaluationsTableTableManager(
      $_db,
      $_db.evaluations,
    ).filter((f) => f.taskRunId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_evaluationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReviewBattlesTable, List<ReviewBattle>>
  _leftReviewBattlesTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewBattles,
    aliasName: $_aliasNameGenerator(
      db.taskRuns.id,
      db.reviewBattles.leftTaskRunId,
    ),
  );

  $$ReviewBattlesTableProcessedTableManager get leftReviewBattles {
    final manager = $$ReviewBattlesTableTableManager(
      $_db,
      $_db.reviewBattles,
    ).filter((f) => f.leftTaskRunId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_leftReviewBattlesTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReviewBattlesTable, List<ReviewBattle>>
  _rightReviewBattlesTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewBattles,
    aliasName: $_aliasNameGenerator(
      db.taskRuns.id,
      db.reviewBattles.rightTaskRunId,
    ),
  );

  $$ReviewBattlesTableProcessedTableManager get rightReviewBattles {
    final manager = $$ReviewBattlesTableTableManager(
      $_db,
      $_db.reviewBattles,
    ).filter((f) => f.rightTaskRunId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_rightReviewBattlesTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TaskRunsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskRunsTable> {
  $$TaskRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseText => $composableBuilder(
    column: $table.responseText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aggregateScore => $composableBuilder(
    column: $table.aggregateScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trialIndex => $composableBuilder(
    column: $table.trialIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskVersion => $composableBuilder(
    column: $table.taskVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get benchmarkTrack => $composableBuilder(
    column: $table.benchmarkTrack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get harnessId => $composableBuilder(
    column: $table.harnessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get primaryPass => $composableBuilder(
    column: $table.primaryPass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureTag => $composableBuilder(
    column: $table.failureTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patchText => $composableBuilder(
    column: $table.patchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trajectoryLogPath => $composableBuilder(
    column: $table.trajectoryLogPath,
    builder: (column) => ColumnFilters(column),
  );

  $$RunsTableFilterComposer get runId {
    final $$RunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableFilterComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlansTableFilterComposer get planId {
    final $$PlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> evaluationsRefs(
    Expression<bool> Function($$EvaluationsTableFilterComposer f) f,
  ) {
    final $$EvaluationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evaluations,
      getReferencedColumn: (t) => t.taskRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvaluationsTableFilterComposer(
            $db: $db,
            $table: $db.evaluations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> leftReviewBattles(
    Expression<bool> Function($$ReviewBattlesTableFilterComposer f) f,
  ) {
    final $$ReviewBattlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewBattles,
      getReferencedColumn: (t) => t.leftTaskRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewBattlesTableFilterComposer(
            $db: $db,
            $table: $db.reviewBattles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> rightReviewBattles(
    Expression<bool> Function($$ReviewBattlesTableFilterComposer f) f,
  ) {
    final $$ReviewBattlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewBattles,
      getReferencedColumn: (t) => t.rightTaskRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewBattlesTableFilterComposer(
            $db: $db,
            $table: $db.reviewBattles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskRunsTable> {
  $$TaskRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseText => $composableBuilder(
    column: $table.responseText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aggregateScore => $composableBuilder(
    column: $table.aggregateScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trialIndex => $composableBuilder(
    column: $table.trialIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskVersion => $composableBuilder(
    column: $table.taskVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get benchmarkTrack => $composableBuilder(
    column: $table.benchmarkTrack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get harnessId => $composableBuilder(
    column: $table.harnessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get primaryPass => $composableBuilder(
    column: $table.primaryPass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureTag => $composableBuilder(
    column: $table.failureTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patchText => $composableBuilder(
    column: $table.patchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trajectoryLogPath => $composableBuilder(
    column: $table.trajectoryLogPath,
    builder: (column) => ColumnOrderings(column),
  );

  $$RunsTableOrderingComposer get runId {
    final $$RunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableOrderingComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlansTableOrderingComposer get planId {
    final $$PlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskRunsTable> {
  $$TaskRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get responseText => $composableBuilder(
    column: $table.responseText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<double> get aggregateScore => $composableBuilder(
    column: $table.aggregateScore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trialIndex => $composableBuilder(
    column: $table.trialIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taskVersion => $composableBuilder(
    column: $table.taskVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get benchmarkTrack => $composableBuilder(
    column: $table.benchmarkTrack,
    builder: (column) => column,
  );

  GeneratedColumn<String> get harnessId =>
      $composableBuilder(column: $table.harnessId, builder: (column) => column);

  GeneratedColumn<bool> get primaryPass => $composableBuilder(
    column: $table.primaryPass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureTag => $composableBuilder(
    column: $table.failureTag,
    builder: (column) => column,
  );

  GeneratedColumn<String> get patchText =>
      $composableBuilder(column: $table.patchText, builder: (column) => column);

  GeneratedColumn<String> get trajectoryLogPath => $composableBuilder(
    column: $table.trajectoryLogPath,
    builder: (column) => column,
  );

  $$RunsTableAnnotationComposer get runId {
    final $$RunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableAnnotationComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlansTableAnnotationComposer get planId {
    final $$PlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> evaluationsRefs<T extends Object>(
    Expression<T> Function($$EvaluationsTableAnnotationComposer a) f,
  ) {
    final $$EvaluationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evaluations,
      getReferencedColumn: (t) => t.taskRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvaluationsTableAnnotationComposer(
            $db: $db,
            $table: $db.evaluations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> leftReviewBattles<T extends Object>(
    Expression<T> Function($$ReviewBattlesTableAnnotationComposer a) f,
  ) {
    final $$ReviewBattlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewBattles,
      getReferencedColumn: (t) => t.leftTaskRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewBattlesTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewBattles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> rightReviewBattles<T extends Object>(
    Expression<T> Function($$ReviewBattlesTableAnnotationComposer a) f,
  ) {
    final $$ReviewBattlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewBattles,
      getReferencedColumn: (t) => t.rightTaskRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewBattlesTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewBattles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskRunsTable,
          TaskRun,
          $$TaskRunsTableFilterComposer,
          $$TaskRunsTableOrderingComposer,
          $$TaskRunsTableAnnotationComposer,
          $$TaskRunsTableCreateCompanionBuilder,
          $$TaskRunsTableUpdateCompanionBuilder,
          (TaskRun, $$TaskRunsTableReferences),
          TaskRun,
          PrefetchHooks Function({
            bool runId,
            bool planId,
            bool evaluationsRefs,
            bool leftReviewBattles,
            bool rightReviewBattles,
          })
        > {
  $$TaskRunsTableTableManager(_$AppDatabase db, $TaskRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> responseText = const Value.absent(),
                Value<int?> promptTokens = const Value.absent(),
                Value<int?> completionTokens = const Value.absent(),
                Value<int> latencyMs = const Value.absent(),
                Value<double> aggregateScore = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<String?> planId = const Value.absent(),
                Value<int> trialIndex = const Value.absent(),
                Value<int> taskVersion = const Value.absent(),
                Value<String> benchmarkTrack = const Value.absent(),
                Value<String?> harnessId = const Value.absent(),
                Value<bool?> primaryPass = const Value.absent(),
                Value<String?> failureTag = const Value.absent(),
                Value<String?> patchText = const Value.absent(),
                Value<String?> trajectoryLogPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRunsCompanion(
                id: id,
                runId: runId,
                providerId: providerId,
                modelId: modelId,
                taskId: taskId,
                responseText: responseText,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                latencyMs: latencyMs,
                aggregateScore: aggregateScore,
                completedAt: completedAt,
                planId: planId,
                trialIndex: trialIndex,
                taskVersion: taskVersion,
                benchmarkTrack: benchmarkTrack,
                harnessId: harnessId,
                primaryPass: primaryPass,
                failureTag: failureTag,
                patchText: patchText,
                trajectoryLogPath: trajectoryLogPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required String providerId,
                required String modelId,
                required String taskId,
                required String responseText,
                Value<int?> promptTokens = const Value.absent(),
                Value<int?> completionTokens = const Value.absent(),
                required int latencyMs,
                required double aggregateScore,
                required DateTime completedAt,
                Value<String?> planId = const Value.absent(),
                Value<int> trialIndex = const Value.absent(),
                Value<int> taskVersion = const Value.absent(),
                Value<String> benchmarkTrack = const Value.absent(),
                Value<String?> harnessId = const Value.absent(),
                Value<bool?> primaryPass = const Value.absent(),
                Value<String?> failureTag = const Value.absent(),
                Value<String?> patchText = const Value.absent(),
                Value<String?> trajectoryLogPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRunsCompanion.insert(
                id: id,
                runId: runId,
                providerId: providerId,
                modelId: modelId,
                taskId: taskId,
                responseText: responseText,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                latencyMs: latencyMs,
                aggregateScore: aggregateScore,
                completedAt: completedAt,
                planId: planId,
                trialIndex: trialIndex,
                taskVersion: taskVersion,
                benchmarkTrack: benchmarkTrack,
                harnessId: harnessId,
                primaryPass: primaryPass,
                failureTag: failureTag,
                patchText: patchText,
                trajectoryLogPath: trajectoryLogPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                runId = false,
                planId = false,
                evaluationsRefs = false,
                leftReviewBattles = false,
                rightReviewBattles = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (evaluationsRefs) db.evaluations,
                    if (leftReviewBattles) db.reviewBattles,
                    if (rightReviewBattles) db.reviewBattles,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (runId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.runId,
                                    referencedTable: $$TaskRunsTableReferences
                                        ._runIdTable(db),
                                    referencedColumn: $$TaskRunsTableReferences
                                        ._runIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (planId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.planId,
                                    referencedTable: $$TaskRunsTableReferences
                                        ._planIdTable(db),
                                    referencedColumn: $$TaskRunsTableReferences
                                        ._planIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (evaluationsRefs)
                        await $_getPrefetchedData<
                          TaskRun,
                          $TaskRunsTable,
                          Evaluation
                        >(
                          currentTable: table,
                          referencedTable: $$TaskRunsTableReferences
                              ._evaluationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TaskRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).evaluationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (leftReviewBattles)
                        await $_getPrefetchedData<
                          TaskRun,
                          $TaskRunsTable,
                          ReviewBattle
                        >(
                          currentTable: table,
                          referencedTable: $$TaskRunsTableReferences
                              ._leftReviewBattlesTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TaskRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).leftReviewBattles,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.leftTaskRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (rightReviewBattles)
                        await $_getPrefetchedData<
                          TaskRun,
                          $TaskRunsTable,
                          ReviewBattle
                        >(
                          currentTable: table,
                          referencedTable: $$TaskRunsTableReferences
                              ._rightReviewBattlesTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TaskRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).rightReviewBattles,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.rightTaskRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TaskRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskRunsTable,
      TaskRun,
      $$TaskRunsTableFilterComposer,
      $$TaskRunsTableOrderingComposer,
      $$TaskRunsTableAnnotationComposer,
      $$TaskRunsTableCreateCompanionBuilder,
      $$TaskRunsTableUpdateCompanionBuilder,
      (TaskRun, $$TaskRunsTableReferences),
      TaskRun,
      PrefetchHooks Function({
        bool runId,
        bool planId,
        bool evaluationsRefs,
        bool leftReviewBattles,
        bool rightReviewBattles,
      })
    >;
typedef $$EvaluationsTableCreateCompanionBuilder =
    EvaluationsCompanion Function({
      required String id,
      required String taskRunId,
      required String evaluatorId,
      required bool passed,
      required double score,
      Value<String?> rationale,
      required String detailsJson,
      Value<int> rowid,
    });
typedef $$EvaluationsTableUpdateCompanionBuilder =
    EvaluationsCompanion Function({
      Value<String> id,
      Value<String> taskRunId,
      Value<String> evaluatorId,
      Value<bool> passed,
      Value<double> score,
      Value<String?> rationale,
      Value<String> detailsJson,
      Value<int> rowid,
    });

final class $$EvaluationsTableReferences
    extends BaseReferences<_$AppDatabase, $EvaluationsTable, Evaluation> {
  $$EvaluationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TaskRunsTable _taskRunIdTable(_$AppDatabase db) =>
      db.taskRuns.createAlias(
        $_aliasNameGenerator(db.evaluations.taskRunId, db.taskRuns.id),
      );

  $$TaskRunsTableProcessedTableManager get taskRunId {
    final $_column = $_itemColumn<String>('task_run_id')!;

    final manager = $$TaskRunsTableTableManager(
      $_db,
      $_db.taskRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EvaluationsTableFilterComposer
    extends Composer<_$AppDatabase, $EvaluationsTable> {
  $$EvaluationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evaluatorId => $composableBuilder(
    column: $table.evaluatorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get passed => $composableBuilder(
    column: $table.passed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rationale => $composableBuilder(
    column: $table.rationale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$TaskRunsTableFilterComposer get taskRunId {
    final $$TaskRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskRunId,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableFilterComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvaluationsTableOrderingComposer
    extends Composer<_$AppDatabase, $EvaluationsTable> {
  $$EvaluationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evaluatorId => $composableBuilder(
    column: $table.evaluatorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get passed => $composableBuilder(
    column: $table.passed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rationale => $composableBuilder(
    column: $table.rationale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$TaskRunsTableOrderingComposer get taskRunId {
    final $$TaskRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskRunId,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableOrderingComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvaluationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EvaluationsTable> {
  $$EvaluationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get evaluatorId => $composableBuilder(
    column: $table.evaluatorId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get passed =>
      $composableBuilder(column: $table.passed, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get rationale =>
      $composableBuilder(column: $table.rationale, builder: (column) => column);

  GeneratedColumn<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => column,
  );

  $$TaskRunsTableAnnotationComposer get taskRunId {
    final $$TaskRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskRunId,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvaluationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EvaluationsTable,
          Evaluation,
          $$EvaluationsTableFilterComposer,
          $$EvaluationsTableOrderingComposer,
          $$EvaluationsTableAnnotationComposer,
          $$EvaluationsTableCreateCompanionBuilder,
          $$EvaluationsTableUpdateCompanionBuilder,
          (Evaluation, $$EvaluationsTableReferences),
          Evaluation,
          PrefetchHooks Function({bool taskRunId})
        > {
  $$EvaluationsTableTableManager(_$AppDatabase db, $EvaluationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EvaluationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EvaluationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EvaluationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskRunId = const Value.absent(),
                Value<String> evaluatorId = const Value.absent(),
                Value<bool> passed = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<String?> rationale = const Value.absent(),
                Value<String> detailsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EvaluationsCompanion(
                id: id,
                taskRunId: taskRunId,
                evaluatorId: evaluatorId,
                passed: passed,
                score: score,
                rationale: rationale,
                detailsJson: detailsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskRunId,
                required String evaluatorId,
                required bool passed,
                required double score,
                Value<String?> rationale = const Value.absent(),
                required String detailsJson,
                Value<int> rowid = const Value.absent(),
              }) => EvaluationsCompanion.insert(
                id: id,
                taskRunId: taskRunId,
                evaluatorId: evaluatorId,
                passed: passed,
                score: score,
                rationale: rationale,
                detailsJson: detailsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EvaluationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskRunId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskRunId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskRunId,
                                referencedTable: $$EvaluationsTableReferences
                                    ._taskRunIdTable(db),
                                referencedColumn: $$EvaluationsTableReferences
                                    ._taskRunIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EvaluationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EvaluationsTable,
      Evaluation,
      $$EvaluationsTableFilterComposer,
      $$EvaluationsTableOrderingComposer,
      $$EvaluationsTableAnnotationComposer,
      $$EvaluationsTableCreateCompanionBuilder,
      $$EvaluationsTableUpdateCompanionBuilder,
      (Evaluation, $$EvaluationsTableReferences),
      Evaluation,
      PrefetchHooks Function({bool taskRunId})
    >;
typedef $$ReviewBattlesTableCreateCompanionBuilder =
    ReviewBattlesCompanion Function({
      required String id,
      required String taskId,
      required int taskVersion,
      required String benchmarkTrack,
      required String leftTaskRunId,
      required String rightTaskRunId,
      required String canonicalPairKey,
      required String leftLabel,
      required String rightLabel,
      required String reviewerId,
      Value<String?> reviewerAlias,
      required String vote,
      Value<String?> rationale,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ReviewBattlesTableUpdateCompanionBuilder =
    ReviewBattlesCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<int> taskVersion,
      Value<String> benchmarkTrack,
      Value<String> leftTaskRunId,
      Value<String> rightTaskRunId,
      Value<String> canonicalPairKey,
      Value<String> leftLabel,
      Value<String> rightLabel,
      Value<String> reviewerId,
      Value<String?> reviewerAlias,
      Value<String> vote,
      Value<String?> rationale,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ReviewBattlesTableReferences
    extends BaseReferences<_$AppDatabase, $ReviewBattlesTable, ReviewBattle> {
  $$ReviewBattlesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TaskRunsTable _leftTaskRunIdTable(_$AppDatabase db) =>
      db.taskRuns.createAlias(
        $_aliasNameGenerator(db.reviewBattles.leftTaskRunId, db.taskRuns.id),
      );

  $$TaskRunsTableProcessedTableManager get leftTaskRunId {
    final $_column = $_itemColumn<String>('left_task_run_id')!;

    final manager = $$TaskRunsTableTableManager(
      $_db,
      $_db.taskRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_leftTaskRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TaskRunsTable _rightTaskRunIdTable(_$AppDatabase db) =>
      db.taskRuns.createAlias(
        $_aliasNameGenerator(db.reviewBattles.rightTaskRunId, db.taskRuns.id),
      );

  $$TaskRunsTableProcessedTableManager get rightTaskRunId {
    final $_column = $_itemColumn<String>('right_task_run_id')!;

    final manager = $$TaskRunsTableTableManager(
      $_db,
      $_db.taskRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rightTaskRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReviewBattlesTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewBattlesTable> {
  $$ReviewBattlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskVersion => $composableBuilder(
    column: $table.taskVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get benchmarkTrack => $composableBuilder(
    column: $table.benchmarkTrack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalPairKey => $composableBuilder(
    column: $table.canonicalPairKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leftLabel => $composableBuilder(
    column: $table.leftLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rightLabel => $composableBuilder(
    column: $table.rightLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewerId => $composableBuilder(
    column: $table.reviewerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewerAlias => $composableBuilder(
    column: $table.reviewerAlias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vote => $composableBuilder(
    column: $table.vote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rationale => $composableBuilder(
    column: $table.rationale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TaskRunsTableFilterComposer get leftTaskRunId {
    final $$TaskRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leftTaskRunId,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableFilterComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskRunsTableFilterComposer get rightTaskRunId {
    final $$TaskRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rightTaskRunId,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableFilterComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewBattlesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewBattlesTable> {
  $$ReviewBattlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskVersion => $composableBuilder(
    column: $table.taskVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get benchmarkTrack => $composableBuilder(
    column: $table.benchmarkTrack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalPairKey => $composableBuilder(
    column: $table.canonicalPairKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leftLabel => $composableBuilder(
    column: $table.leftLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rightLabel => $composableBuilder(
    column: $table.rightLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewerId => $composableBuilder(
    column: $table.reviewerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewerAlias => $composableBuilder(
    column: $table.reviewerAlias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vote => $composableBuilder(
    column: $table.vote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rationale => $composableBuilder(
    column: $table.rationale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TaskRunsTableOrderingComposer get leftTaskRunId {
    final $$TaskRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leftTaskRunId,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableOrderingComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskRunsTableOrderingComposer get rightTaskRunId {
    final $$TaskRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rightTaskRunId,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableOrderingComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewBattlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewBattlesTable> {
  $$ReviewBattlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<int> get taskVersion => $composableBuilder(
    column: $table.taskVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get benchmarkTrack => $composableBuilder(
    column: $table.benchmarkTrack,
    builder: (column) => column,
  );

  GeneratedColumn<String> get canonicalPairKey => $composableBuilder(
    column: $table.canonicalPairKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leftLabel =>
      $composableBuilder(column: $table.leftLabel, builder: (column) => column);

  GeneratedColumn<String> get rightLabel => $composableBuilder(
    column: $table.rightLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewerId => $composableBuilder(
    column: $table.reviewerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewerAlias => $composableBuilder(
    column: $table.reviewerAlias,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vote =>
      $composableBuilder(column: $table.vote, builder: (column) => column);

  GeneratedColumn<String> get rationale =>
      $composableBuilder(column: $table.rationale, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TaskRunsTableAnnotationComposer get leftTaskRunId {
    final $$TaskRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leftTaskRunId,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskRunsTableAnnotationComposer get rightTaskRunId {
    final $$TaskRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rightTaskRunId,
      referencedTable: $db.taskRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewBattlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewBattlesTable,
          ReviewBattle,
          $$ReviewBattlesTableFilterComposer,
          $$ReviewBattlesTableOrderingComposer,
          $$ReviewBattlesTableAnnotationComposer,
          $$ReviewBattlesTableCreateCompanionBuilder,
          $$ReviewBattlesTableUpdateCompanionBuilder,
          (ReviewBattle, $$ReviewBattlesTableReferences),
          ReviewBattle,
          PrefetchHooks Function({bool leftTaskRunId, bool rightTaskRunId})
        > {
  $$ReviewBattlesTableTableManager(_$AppDatabase db, $ReviewBattlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewBattlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewBattlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewBattlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<int> taskVersion = const Value.absent(),
                Value<String> benchmarkTrack = const Value.absent(),
                Value<String> leftTaskRunId = const Value.absent(),
                Value<String> rightTaskRunId = const Value.absent(),
                Value<String> canonicalPairKey = const Value.absent(),
                Value<String> leftLabel = const Value.absent(),
                Value<String> rightLabel = const Value.absent(),
                Value<String> reviewerId = const Value.absent(),
                Value<String?> reviewerAlias = const Value.absent(),
                Value<String> vote = const Value.absent(),
                Value<String?> rationale = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewBattlesCompanion(
                id: id,
                taskId: taskId,
                taskVersion: taskVersion,
                benchmarkTrack: benchmarkTrack,
                leftTaskRunId: leftTaskRunId,
                rightTaskRunId: rightTaskRunId,
                canonicalPairKey: canonicalPairKey,
                leftLabel: leftLabel,
                rightLabel: rightLabel,
                reviewerId: reviewerId,
                reviewerAlias: reviewerAlias,
                vote: vote,
                rationale: rationale,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required int taskVersion,
                required String benchmarkTrack,
                required String leftTaskRunId,
                required String rightTaskRunId,
                required String canonicalPairKey,
                required String leftLabel,
                required String rightLabel,
                required String reviewerId,
                Value<String?> reviewerAlias = const Value.absent(),
                required String vote,
                Value<String?> rationale = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ReviewBattlesCompanion.insert(
                id: id,
                taskId: taskId,
                taskVersion: taskVersion,
                benchmarkTrack: benchmarkTrack,
                leftTaskRunId: leftTaskRunId,
                rightTaskRunId: rightTaskRunId,
                canonicalPairKey: canonicalPairKey,
                leftLabel: leftLabel,
                rightLabel: rightLabel,
                reviewerId: reviewerId,
                reviewerAlias: reviewerAlias,
                vote: vote,
                rationale: rationale,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReviewBattlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({leftTaskRunId = false, rightTaskRunId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (leftTaskRunId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.leftTaskRunId,
                                    referencedTable:
                                        $$ReviewBattlesTableReferences
                                            ._leftTaskRunIdTable(db),
                                    referencedColumn:
                                        $$ReviewBattlesTableReferences
                                            ._leftTaskRunIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (rightTaskRunId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.rightTaskRunId,
                                    referencedTable:
                                        $$ReviewBattlesTableReferences
                                            ._rightTaskRunIdTable(db),
                                    referencedColumn:
                                        $$ReviewBattlesTableReferences
                                            ._rightTaskRunIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$ReviewBattlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewBattlesTable,
      ReviewBattle,
      $$ReviewBattlesTableFilterComposer,
      $$ReviewBattlesTableOrderingComposer,
      $$ReviewBattlesTableAnnotationComposer,
      $$ReviewBattlesTableCreateCompanionBuilder,
      $$ReviewBattlesTableUpdateCompanionBuilder,
      (ReviewBattle, $$ReviewBattlesTableReferences),
      ReviewBattle,
      PrefetchHooks Function({bool leftTaskRunId, bool rightTaskRunId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RunsTableTableManager get runs => $$RunsTableTableManager(_db, _db.runs);
  $$PlansTableTableManager get plans =>
      $$PlansTableTableManager(_db, _db.plans);
  $$TaskRunsTableTableManager get taskRuns =>
      $$TaskRunsTableTableManager(_db, _db.taskRuns);
  $$EvaluationsTableTableManager get evaluations =>
      $$EvaluationsTableTableManager(_db, _db.evaluations);
  $$ReviewBattlesTableTableManager get reviewBattles =>
      $$ReviewBattlesTableTableManager(_db, _db.reviewBattles);
}
