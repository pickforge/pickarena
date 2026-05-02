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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    completedAt,
    judgeModel,
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
  const Run({
    required this.id,
    required this.startedAt,
    this.completedAt,
    this.judgeModel,
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
    };
  }

  Run copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> judgeModel = const Value.absent(),
  }) => Run(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    judgeModel: judgeModel.present ? judgeModel.value : this.judgeModel,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('Run(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('judgeModel: $judgeModel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startedAt, completedAt, judgeModel);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Run &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.judgeModel == this.judgeModel);
}

class RunsCompanion extends UpdateCompanion<Run> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<String?> judgeModel;
  final Value<int> rowid;
  const RunsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.judgeModel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    this.judgeModel = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt);
  static Insertable<Run> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<String>? judgeModel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (judgeModel != null) 'judge_model': judgeModel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<String?>? judgeModel,
    Value<int>? rowid,
  }) {
    return RunsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      judgeModel: judgeModel ?? this.judgeModel,
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
          ..write('completedAt: $completedAt')
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
          other.completedAt == this.completedAt);
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RunsTable runs = $RunsTable(this);
  late final $TaskRunsTable taskRuns = $TaskRunsTable(this);
  late final $EvaluationsTable evaluations = $EvaluationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    runs,
    taskRuns,
    evaluations,
  ];
}

typedef $$RunsTableCreateCompanionBuilder =
    RunsCompanion Function({
      required String id,
      required DateTime startedAt,
      Value<DateTime?> completedAt,
      Value<String?> judgeModel,
      Value<int> rowid,
    });
typedef $$RunsTableUpdateCompanionBuilder =
    RunsCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<String?> judgeModel,
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
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion(
                id: id,
                startedAt: startedAt,
                completedAt: completedAt,
                judgeModel: judgeModel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> judgeModel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion.insert(
                id: id,
                startedAt: startedAt,
                completedAt: completedAt,
                judgeModel: judgeModel,
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
          PrefetchHooks Function({bool runId, bool evaluationsRefs})
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
          prefetchHooksCallback: ({runId = false, evaluationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (evaluationsRefs) db.evaluations],
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
                      managerFromTypedResult: (p0) => $$TaskRunsTableReferences(
                        db,
                        table,
                        p0,
                      ).evaluationsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.taskRunId == item.id),
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
      PrefetchHooks Function({bool runId, bool evaluationsRefs})
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RunsTableTableManager get runs => $$RunsTableTableManager(_db, _db.runs);
  $$TaskRunsTableTableManager get taskRuns =>
      $$TaskRunsTableTableManager(_db, _db.taskRuns);
  $$EvaluationsTableTableManager get evaluations =>
      $$EvaluationsTableTableManager(_db, _db.evaluations);
}
