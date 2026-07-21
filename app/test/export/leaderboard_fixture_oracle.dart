import 'dart:convert';

import 'package:dart_arena/export/leaderboard_exporter.dart';

Map<String, Object?>? normalizeLeaderboardFixture(String text) {
  try {
    final artifact = requiredMap(jsonDecode(text));
    final schemaVersion = requiredCount(artifact, 'schemaVersion');
    if (!supportedLeaderboardArtifactSchemaVersions.contains(schemaVersion)) {
      throw const FormatException();
    }
    final current = schemaVersion == 2;
    final benchmark = requiredMap(artifact['benchmark']);
    final source = requiredMap(artifact['source']);
    final models = mapList(requiredList(artifact, 'models'));
    final tasks = mapList(requiredList(artifact, 'tasks'));
    final cells = mapList(listField(artifact, 'taskModelCells', current));
    final trials = mapList(listField(artifact, 'trialSummaries', current));
    final scoring = mapField(artifact, 'scoring', current);
    final pricing = mapField(artifact, 'pricingRegistry', current);
    final judgeOverhead = mapField(source, 'judgeOverhead', current);
    final runProvenance = mapField(source, 'runProvenance', current);

    return {
      'schemaVersion': schemaVersion,
      'provisional': boolField(artifact, 'provisional', false),
      'generatedAt': nullableString(artifact, 'generatedAt'),
      'benchmark': {
        'title': requiredString(benchmark, 'title'),
        'version': nullableString(benchmark, 'version'),
        'taskSetId': nullableString(benchmark, 'taskSetId'),
        'evaluatorSchemaVersion': countField(
          benchmark,
          'evaluatorSchemaVersion',
          current,
          0,
        ),
        'track': requiredString(benchmark, 'track'),
        'dataPolicy': dataPolicy(benchmark, 'dataPolicy'),
        'preset': nullableString(benchmark, 'preset'),
        'selectedTasks': [
          for (final task in mapList(
            listField(benchmark, 'selectedTasks', false),
          ))
            {
              'taskId': requiredString(task, 'taskId'),
              'taskVersion': nullableVersion(task, 'taskVersion'),
              'taskBundleDigest': nullableString(task, 'taskBundleDigest'),
            },
        ],
        'corpusManifestDigestSha256': nullableString(
          benchmark,
          'corpusManifestDigestSha256',
        ),
      },
      'source': {
        'anchorRunId': nullableString(source, 'anchorRunId'),
        'runIds': stringListField(source, 'runIds', current),
        'taskCount': requiredCount(source, 'taskCount'),
        'taskRunCount': requiredCount(source, 'taskRunCount'),
        'modelCount': countField(source, 'modelCount', current, models.length),
        'trialSummaryCount': countField(
          source,
          'trialSummaryCount',
          current,
          trials.length,
        ),
        'trialSummaryTotalCount': countField(
          source,
          'trialSummaryTotalCount',
          current,
          requiredCount(source, 'taskRunCount'),
        ),
        'trialSummaryTruncated': boolField(
          source,
          'trialSummaryTruncated',
          false,
          current,
        ),
        'trialSummaryLimit': countField(
          source,
          'trialSummaryLimit',
          current,
          0,
        ),
        'warnings': stringListField(source, 'warnings', current),
        'judgeOverhead': projectJudgeOverhead(judgeOverhead, current),
        'runProvenance': projectRunProvenance(runProvenance, current),
      },
      'scoring': projectScoring(scoring, current),
      'pricingRegistry': {
        'version': nullableString(pricing, 'version'),
        'currency': nullableString(pricing, 'currency'),
        'modelCount': countField(pricing, 'modelCount', current, 0),
      },
      'models': [for (final model in models) projectModel(model, current)],
      'tasks': [for (final task in tasks) projectTask(task, current)],
      'taskModelCells': [
        for (final cell in cells) projectTaskModelCell(cell, current),
      ],
      'trialSummaries': [
        for (final trial in trials) projectTrialSummary(trial, current),
      ],
    };
  } on Object {
    return null;
  }
}

Map<String, Object?> projectScoring(Map<String, Object?> value, bool current) =>
    {
      'schemaVersion': countField(value, 'schemaVersion', current, 0),
      'primaryMetric': nullableString(value, 'primaryMetric'),
      'rankingMetric': nullableString(value, 'rankingMetric'),
      'confidenceInterval': nullableString(value, 'confidenceInterval'),
      'llmJudgePolicy': nullableString(value, 'llmJudgePolicy'),
      'objectiveEvaluatorIds': stringListField(
        value,
        'objectiveEvaluatorIds',
        current,
      ),
      'secondaryEvaluatorIds': stringListField(
        value,
        'secondaryEvaluatorIds',
        current,
      ),
      'hiddenVerifierPattern': nullableString(value, 'hiddenVerifierPattern'),
      'failureTags': stringListField(value, 'failureTags', current),
      'objectiveFailureCaps': numberMapField(
        value,
        'objectiveFailureCaps',
        current,
      ),
      'defaultEvaluatorWeights': numberMapField(
        value,
        'defaultEvaluatorWeights',
        current,
      ),
    };

Map<String, Object?> projectJudgeOverhead(
  Map<String, Object?> value,
  bool current,
) => {
  'evaluationCount': countField(value, 'evaluationCount', current, 0),
  'promptTokens': countField(value, 'promptTokens', current, 0),
  'completionTokens': countField(value, 'completionTokens', current, 0),
  'knownEstimatedCostCount': countField(
    value,
    'knownEstimatedCostCount',
    current,
    0,
  ),
  'unknownEstimatedCostCount': countField(
    value,
    'unknownEstimatedCostCount',
    current,
    0,
  ),
  'totalEstimatedCostMicros': countField(
    value,
    'totalEstimatedCostMicros',
    current,
    0,
  ),
  'pricingStatusCounts': countMapField(value, 'pricingStatusCounts', current),
};

Map<String, Object?> projectRunProvenance(
  Map<String, Object?> value,
  bool current,
) => {
  'runCount': countField(value, 'runCount', current, 0),
  'embeddedRunCount': countField(value, 'embeddedRunCount', current, 0),
  'sandboxEnforcedRunCount': countField(
    value,
    'sandboxEnforcedRunCount',
    current,
    0,
  ),
  'taskExecutionPolicyRunCount': countField(
    value,
    'taskExecutionPolicyRunCount',
    current,
    0,
  ),
  'networkDisabledTaskPolicyRunCount': countField(
    value,
    'networkDisabledTaskPolicyRunCount',
    current,
    0,
  ),
  'taskResourceLimitRunCount': countField(
    value,
    'taskResourceLimitRunCount',
    current,
    0,
  ),
  'sdkVersionRunCount': countField(value, 'sdkVersionRunCount', current, 0),
  'dependencySnapshotRunCount': countField(
    value,
    'dependencySnapshotRunCount',
    current,
    0,
  ),
  'pricingRegistryRunCount': countField(
    value,
    'pricingRegistryRunCount',
    current,
    0,
  ),
  'generatedCodeSandboxBackends': stringListField(
    value,
    'generatedCodeSandboxBackends',
    current,
  ),
  'dartVersions': stringListField(value, 'dartVersions', current),
  'flutterVersions': stringListField(value, 'flutterVersions', current),
  'environmentIds': stringListField(value, 'environmentIds', current),
  'warnings': stringListField(value, 'warnings', current),
};

Map<String, Object?> projectModel(Map<String, Object?> value, bool current) {
  final sampleCount = countField(value, 'sampleCount', current, 0);
  return {
    'providerId': requiredString(value, 'providerId'),
    'modelId': requiredString(value, 'modelId'),
    ...modelIdentity(value, current),
    'rank': nullableCount(value, 'rank'),
    'score': nullableNumber(value, 'score'),
    'passRate': nullableNumber(value, 'passRate'),
    'trialCount': countField(value, 'trialCount', current, sampleCount),
    'passCount': countField(value, 'passCount', current, 0),
    'sampleCount': sampleCount,
    'passAtK': projectPassAtK(mapField(value, 'passAtK', current), current),
    'medianStepCount': nullableCount(value, 'medianStepCount'),
    'medianPeakContextTokens': nullableCount(value, 'medianPeakContextTokens'),
    'publicPassCount': countField(value, 'publicPassCount', current, 0),
    'publicSampleCount': countField(value, 'publicSampleCount', current, 0),
    'publicPassRate': nullableNumber(value, 'publicPassRate'),
    'hiddenPassCount': countField(value, 'hiddenPassCount', current, 0),
    'hiddenSampleCount': countField(value, 'hiddenSampleCount', current, 0),
    'hiddenPassRate': nullableNumber(value, 'hiddenPassRate'),
    'confidenceInterval': projectConfidenceInterval(
      mapField(value, 'confidenceInterval', current),
    ),
    'lowSample': boolField(value, 'lowSample', false, current),
    'medianLatencyMs': nullableCount(value, 'medianLatencyMs'),
    'medianPromptTokens': nullableCount(value, 'medianPromptTokens'),
    'medianCompletionTokens': nullableCount(value, 'medianCompletionTokens'),
    'medianEstimatedCostMicros': nullableCount(
      value,
      'medianEstimatedCostMicros',
    ),
    'knownEstimatedCostCount': countField(
      value,
      'knownEstimatedCostCount',
      current,
      0,
    ),
    'unknownEstimatedCostCount': countField(
      value,
      'unknownEstimatedCostCount',
      current,
      0,
    ),
    'totalEstimatedCostMicros': nullableCount(
      value,
      'totalEstimatedCostMicros',
    ),
    'costPerSolvedTaskMicros': nullableCount(value, 'costPerSolvedTaskMicros'),
    'cheapestPassingEstimatedCostMicros': nullableCount(
      value,
      'cheapestPassingEstimatedCostMicros',
    ),
    'failureBreakdown': countMapField(value, 'failureBreakdown', current),
    'blockedEvaluationCount': countField(
      value,
      'blockedEvaluationCount',
      current,
      0,
    ),
    'blockedTaskRunCount': countField(value, 'blockedTaskRunCount', current, 0),
  };
}

Map<String, Object?> projectTask(Map<String, Object?> value, bool current) {
  final sampleCount = countField(value, 'sampleCount', current, 0);
  return {
    'taskId': requiredString(value, 'taskId'),
    'taskVersion': nullableVersion(value, 'taskVersion'),
    'taskBundleDigest': nullableString(value, 'taskBundleDigest'),
    'benchmarkTrack': nullableString(value, 'benchmarkTrack'),
    'trialCount': countField(value, 'trialCount', current, sampleCount),
    'sampleCount': sampleCount,
    'modelCount': countField(value, 'modelCount', current, 0),
    'passRate': nullableNumber(value, 'passRate'),
    'confidenceInterval': projectConfidenceInterval(
      mapField(value, 'confidenceInterval', current),
    ),
    'passAtK': projectPassAtK(mapField(value, 'passAtK', current), current),
    'medianStepCount': nullableCount(value, 'medianStepCount'),
    'medianPeakContextTokens': nullableCount(value, 'medianPeakContextTokens'),
    'publicPassCount': countField(value, 'publicPassCount', current, 0),
    'publicSampleCount': countField(value, 'publicSampleCount', current, 0),
    'publicPassRate': nullableNumber(value, 'publicPassRate'),
    'hiddenPassCount': countField(value, 'hiddenPassCount', current, 0),
    'hiddenSampleCount': countField(value, 'hiddenSampleCount', current, 0),
    'hiddenPassRate': nullableNumber(value, 'hiddenPassRate'),
    'blockedEvaluationCount': countField(
      value,
      'blockedEvaluationCount',
      current,
      0,
    ),
    'blockedTaskRunCount': countField(value, 'blockedTaskRunCount', current, 0),
  };
}

Map<String, Object?> projectTaskModelCell(
  Map<String, Object?> value,
  bool current,
) {
  final sampleCount = countField(value, 'sampleCount', current, 0);
  return {
    'providerId': requiredString(value, 'providerId'),
    'modelId': requiredString(value, 'modelId'),
    ...modelIdentity(value, current),
    'taskId': requiredString(value, 'taskId'),
    'taskVersion': nullableVersion(value, 'taskVersion'),
    'benchmarkTrack': nullableString(value, 'benchmarkTrack'),
    'trialCount': countField(value, 'trialCount', current, sampleCount),
    'passCount': countField(value, 'passCount', current, 0),
    'sampleCount': sampleCount,
    'passRate': nullableNumber(value, 'passRate'),
    'confidenceInterval': projectConfidenceInterval(
      mapField(value, 'confidenceInterval', current),
    ),
    'errorCount': countField(value, 'errorCount', current, 0),
    'passAtK': projectPassAtK(mapField(value, 'passAtK', current), current),
    'medianStepCount': nullableCount(value, 'medianStepCount'),
    'medianPeakContextTokens': nullableCount(value, 'medianPeakContextTokens'),
    'publicPassCount': countField(value, 'publicPassCount', current, 0),
    'publicSampleCount': countField(value, 'publicSampleCount', current, 0),
    'publicPassRate': nullableNumber(value, 'publicPassRate'),
    'hiddenPassCount': countField(value, 'hiddenPassCount', current, 0),
    'hiddenSampleCount': countField(value, 'hiddenSampleCount', current, 0),
    'hiddenPassRate': nullableNumber(value, 'hiddenPassRate'),
    'blockedEvaluationCount': countField(
      value,
      'blockedEvaluationCount',
      current,
      0,
    ),
    'blockedTaskRunCount': countField(value, 'blockedTaskRunCount', current, 0),
    'medianLatencyMs': nullableCount(value, 'medianLatencyMs'),
    'medianPromptTokens': nullableCount(value, 'medianPromptTokens'),
    'medianCompletionTokens': nullableCount(value, 'medianCompletionTokens'),
    'medianEstimatedCostMicros': nullableCount(
      value,
      'medianEstimatedCostMicros',
    ),
    'knownEstimatedCostCount': countField(
      value,
      'knownEstimatedCostCount',
      current,
      0,
    ),
    'unknownEstimatedCostCount': countField(
      value,
      'unknownEstimatedCostCount',
      current,
      0,
    ),
    'failureBreakdown': countMapField(value, 'failureBreakdown', current),
  };
}

Map<String, Object?> projectTrialSummary(
  Map<String, Object?> value,
  bool current,
) => {
  'trialId': requiredString(value, 'trialId'),
  'runId': requiredString(value, 'runId'),
  'providerId': requiredString(value, 'providerId'),
  'modelId': requiredString(value, 'modelId'),
  ...modelIdentity(value, current),
  'taskId': requiredString(value, 'taskId'),
  'taskVersion': nullableVersion(value, 'taskVersion'),
  'benchmarkTrack': nullableString(value, 'benchmarkTrack'),
  'trialIndex': requiredCount(value, 'trialIndex'),
  'completedAt': nullableString(value, 'completedAt'),
  'primaryPass': nullableBool(value, 'primaryPass'),
  'failureTag': requiredString(value, 'failureTag'),
  'aggregateScore': nullableNumber(value, 'aggregateScore'),
  'publicPassed': nullableBool(value, 'publicPassed'),
  'hiddenPassed': nullableBool(value, 'hiddenPassed'),
  'blockedEvaluationCount': countField(
    value,
    'blockedEvaluationCount',
    current,
    0,
  ),
  'stepCount': nullableCount(value, 'stepCount'),
  'peakContextTokens': nullableCount(value, 'peakContextTokens'),
  'latencyMs': nullableCount(value, 'latencyMs'),
  'promptTokens': nullableCount(value, 'promptTokens'),
  'completionTokens': nullableCount(value, 'completionTokens'),
  'estimatedCostMicros': nullableCount(value, 'estimatedCostMicros'),
};

Map<String, Object?> modelIdentity(Map<String, Object?> value, bool current) {
  final config = mapField(value, 'modelConfig', current);
  return {
    'displayName': nullableNonEmptyString(config, 'customModelDisplayName'),
    'providerLabel': nullableNonEmptyString(config, 'customModelProvider'),
  };
}

Map<String, Object?> projectConfidenceInterval(Map<String, Object?> value) => {
  'lower': nullableNumber(value, 'lower'),
  'upper': nullableNumber(value, 'upper'),
};

Map<String, Object?> projectPassAtK(Map<String, Object?> value, bool current) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final item = requiredMap(entry.value);
    final parsedKey = int.tryParse(entry.key);
    final fallback = parsedKey != null && parsedKey >= 0 ? parsedKey : 0;
    result[entry.key] = {
      'k': countField(item, 'k', current, fallback),
      'passCount': countField(item, 'passCount', current, 0),
      'sampleCount': countField(item, 'sampleCount', current, 0),
      'passRate': nullableNumber(item, 'passRate'),
    };
  }
  return result;
}

String dataPolicy(Map<String, Object?> value, String key) {
  final entry = value[key];
  if (entry is! String || !acceptedLeaderboardDataPolicies.contains(entry)) {
    throw const FormatException();
  }
  return entry;
}

Map<String, Object?> objectMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry('$key', value));
}

List<Map<String, Object?>> objectList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final entry in value)
      if (entry is Map) objectMap(entry),
  ];
}

Map<String, Object?> requiredMap(Object? value) {
  if (value is! Map) throw const FormatException();
  return objectMap(value);
}

Map<String, Object?> mapField(
  Map<String, Object?> value,
  String key,
  bool required,
) {
  if (!value.containsKey(key)) {
    if (required) throw const FormatException();
    return const {};
  }
  return requiredMap(value[key]);
}

List<Object?> requiredList(Map<String, Object?> value, String key) {
  final entry = value[key];
  if (entry is! List) throw const FormatException();
  return entry;
}

List<Object?> listField(Map<String, Object?> value, String key, bool required) {
  if (!value.containsKey(key)) {
    if (required) throw const FormatException();
    return const [];
  }
  return requiredList(value, key);
}

List<Map<String, Object?>> mapList(List<Object?> value) => [
  for (final entry in value) requiredMap(entry),
];

List<String> stringListField(
  Map<String, Object?> value,
  String key,
  bool required,
) {
  final entries = listField(value, key, required);
  if (entries.any((entry) => entry is! String)) {
    throw const FormatException();
  }
  return entries.cast<String>();
}

String requiredString(Map<String, Object?> value, String key) {
  final entry = value[key];
  if (entry is! String || entry.trim().isEmpty) {
    throw const FormatException();
  }
  return entry;
}

String? nullableString(Map<String, Object?> value, String key) {
  if (!value.containsKey(key) || value[key] == null) return null;
  final entry = value[key];
  if (entry is! String) throw const FormatException();
  return entry;
}

String? nullableNonEmptyString(Map<String, Object?> value, String key) {
  final entry = nullableString(value, key);
  if (entry != null && entry.trim().isEmpty) throw const FormatException();
  return entry;
}

Object? nullableVersion(Map<String, Object?> value, String key) {
  if (!value.containsKey(key) || value[key] == null) return null;
  final entry = value[key];
  if (entry is String) {
    if (entry.trim().isEmpty) throw const FormatException();
    return entry;
  }
  if (entry is! num || !entry.isFinite) throw const FormatException();
  return entry;
}

int requiredCount(Map<String, Object?> value, String key) {
  final entry = value[key];
  if (entry is! num ||
      !entry.isFinite ||
      entry < 0 ||
      entry != entry.truncate()) {
    throw const FormatException();
  }
  return entry.toInt();
}

int countField(
  Map<String, Object?> value,
  String key,
  bool required,
  int fallback,
) {
  if (!value.containsKey(key)) {
    if (required) throw const FormatException();
    return fallback;
  }
  return requiredCount(value, key);
}

int? nullableCount(Map<String, Object?> value, String key) {
  if (!value.containsKey(key) || value[key] == null) return null;
  return requiredCount(value, key);
}

num? nullableNumber(Map<String, Object?> value, String key) {
  if (!value.containsKey(key) || value[key] == null) return null;
  final entry = value[key];
  if (entry is! num || !entry.isFinite) throw const FormatException();
  return entry;
}

bool boolField(
  Map<String, Object?> value,
  String key,
  bool fallback, [
  bool required = false,
]) {
  if (!value.containsKey(key)) {
    if (required) throw const FormatException();
    return fallback;
  }
  final entry = value[key];
  if (entry is! bool) throw const FormatException();
  return entry;
}

bool? nullableBool(Map<String, Object?> value, String key) {
  if (!value.containsKey(key) || value[key] == null) return null;
  final entry = value[key];
  if (entry is! bool) throw const FormatException();
  return entry;
}

Map<String, num> numberMapField(
  Map<String, Object?> value,
  String key,
  bool required,
) {
  final entries = mapField(value, key, required);
  final result = <String, num>{};
  for (final entry in entries.entries) {
    final number = entry.value;
    if (number is! num || !number.isFinite) throw const FormatException();
    result[entry.key] = number;
  }
  return result;
}

Map<String, int> countMapField(
  Map<String, Object?> value,
  String key,
  bool required,
) {
  final entries = mapField(value, key, required);
  return {
    for (final entry in entries.entries)
      entry.key: requiredCount(entries, entry.key),
  };
}
