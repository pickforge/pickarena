import 'dart:convert';

import 'package:dart_arena/export/leaderboard_exporter.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('aggregate-compatible aggregates compatible completed runs', () async {
    await _seedRun(
      db,
      id: 'compatible-old',
      completedAt: DateTime.utc(2026, 5, 1),
    );
    await _seedTaskRun(
      db,
      id: 'old-a',
      runId: 'compatible-old',
      taskId: 'task.a',
      primaryPass: true,
    );
    await _seedTaskRun(
      db,
      id: 'old-b',
      runId: 'compatible-old',
      taskId: 'task.b',
      primaryPass: false,
      failureTag: 'test_failed',
    );
    await _seedRun(
      db,
      id: 'compatible-latest',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _presetProvenanceJson(),
    );
    await _seedTaskRun(
      db,
      id: 'latest-a',
      runId: 'compatible-latest',
      taskId: 'task.a',
      primaryPass: true,
    );
    await _seedTaskRun(
      db,
      id: 'latest-b',
      runId: 'compatible-latest',
      taskId: 'task.b',
      primaryPass: null,
      failureTag: 'unknown',
    );
    await _seedRun(
      db,
      id: 'incompatible-version',
      completedAt: DateTime.utc(2026, 4, 30),
    );
    await _seedTaskRun(
      db,
      id: 'incompatible-a',
      runId: 'incompatible-version',
      taskId: 'task.a',
      taskVersion: 2,
      primaryPass: true,
    );
    await _seedTaskRun(
      db,
      id: 'incompatible-b',
      runId: 'incompatible-version',
      taskId: 'task.b',
      primaryPass: true,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
      now: () => DateTime.utc(2026, 5, 31),
    );

    expect(export['generatedAt'], '2026-05-31T00:00:00.000Z');
    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'compatible-latest');
    expect(source['runIds'], ['compatible-latest', 'compatible-old']);
    expect(source['taskCount'], 2);
    expect(source['taskRunCount'], 4);
    expect(source['modelCount'], 1);
    expect(source['warnings'], isEmpty);

    final benchmark = export['benchmark']! as Map<String, Object?>;
    expect(benchmark['dataPolicy'], 'aggregate-compatible');
    expect(benchmark['track'], 'agentic');
    expect(benchmark['version'], '2026-05-31-master-spec');
    expect(benchmark['taskSetId'], startsWith('taskset-'));
    expect(benchmark['evaluatorSchemaVersion'], 2);
    expect(benchmark['preset'], 'mvp');
    expect(benchmark['corpusManifestDigestSha256'], hasLength(64));
    expect(benchmark['selectedTasks'], hasLength(2));

    final pricingRegistry = export['pricingRegistry']! as Map<String, Object?>;
    expect(pricingRegistry['version'], '2026-05-31');
    expect(pricingRegistry['currency'], 'USD');
    expect(pricingRegistry['modelCount'], greaterThan(0));
  });

  test(
    'aggregate-compatible separates harness kinds from provenance',
    () async {
      await _seedRun(
        db,
        id: 'minimal-old',
        completedAt: DateTime.utc(2026, 5, 1),
        provenanceJson: _harnessProvenanceJson('minimal'),
      );
      await _seedTaskRun(
        db,
        id: 'minimal-old-a',
        runId: 'minimal-old',
        taskId: 'task.a',
      );
      await _seedRun(
        db,
        id: 'command-same-kind',
        completedAt: DateTime.utc(2026, 5, 2),
        provenanceJson: _harnessProvenanceJson(
          'command-template',
          agent: 'codex',
          version: '1.0.0',
        ),
      );
      await _seedTaskRun(
        db,
        id: 'command-same-kind-a',
        runId: 'command-same-kind',
        taskId: 'task.a',
      );
      await _seedRun(
        db,
        id: 'command-latest',
        completedAt: DateTime.utc(2026, 5, 3),
        provenanceJson: _harnessProvenanceJson(
          'command-template',
          agent: 'codex',
          version: '1.0.0',
        ),
      );
      await _seedTaskRun(
        db,
        id: 'command-latest-a',
        runId: 'command-latest',
        taskId: 'task.a',
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(track: 'agentic'),
      );

      final source = export['source']! as Map<String, Object?>;
      expect(source['runIds'], ['command-latest', 'command-same-kind']);
      expect(source['taskRunCount'], 2);
    },
  );

  test('aggregate-compatible separates command-template versions', () async {
    for (final entry in [
      ('old', DateTime.utc(2026, 5, 1), '1.0.0'),
      ('latest', DateTime.utc(2026, 5, 2), '2.0.0'),
    ]) {
      await _seedRun(
        db,
        id: 'version-${entry.$1}',
        completedAt: entry.$2,
        provenanceJson: _harnessProvenanceJson(
          'command-template',
          agent: 'codex',
          version: entry.$3,
        ),
      );
      await _seedTaskRun(
        db,
        id: 'version-${entry.$1}-a',
        runId: 'version-${entry.$1}',
        taskId: 'task.a',
      );
    }

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    expect((export['source']! as Map<String, Object?>)['runIds'], [
      'version-latest',
    ]);
  });

  test('aggregate-compatible separates scoring schema versions', () async {
    await _seedRun(
      db,
      id: 'schema-old',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _weightsProvenanceJson(
        evaluatorWeights: {'compile': 1.0, 'diff_size': 0.3},
      ),
    );
    await _seedTaskRun(
      db,
      id: 'schema-old-a',
      runId: 'schema-old',
      taskId: 'task.a',
    );
    await _seedRun(
      db,
      id: 'schema-latest',
      completedAt: DateTime.utc(2026, 5, 2),
      provenanceJson: _weightsProvenanceJson(
        scoringSchemaVersion: 2,
        evaluatorWeights: {'compile': 1.0},
      ),
    );
    await _seedTaskRun(
      db,
      id: 'schema-latest-a',
      runId: 'schema-latest',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'schema-latest');
    expect(source['runIds'], ['schema-latest']);
    expect(source['taskRunCount'], 1);
    expect(source['warnings'], isEmpty);
  });

  test(
    'aggregate-compatible exports schema-1 anchor scoring metadata',
    () async {
      await _seedRun(
        db,
        id: 'legacy-anchor',
        completedAt: DateTime.utc(2026, 5, 2),
        provenanceJson: _weightsProvenanceJson(
          evaluatorWeights: {'compile': 1.0, 'diff_size': 0.3},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'legacy-anchor-a',
        runId: 'legacy-anchor',
        taskId: 'task.a',
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(track: 'agentic'),
      );

      final source = export['source']! as Map<String, Object?>;
      expect(source['anchorRunId'], 'legacy-anchor');
      final scoring = export['scoring']! as Map<String, Object?>;
      expect(scoring['schemaVersion'], 1);
      expect(scoring.containsKey('diffSizePolicy'), isFalse);
      expect(scoring.containsKey('diagnosticOnlyEvaluatorIds'), isFalse);
    },
  );

  test(
    'aggregate-compatible keeps schema-1 diff_size weights significant',
    () async {
      await _seedRun(
        db,
        id: 'legacy-old',
        completedAt: DateTime.utc(2026, 5, 1),
        provenanceJson: _weightsProvenanceJson(
          evaluatorWeights: {'compile': 1.0, 'diff_size': 0.3},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'legacy-old-a',
        runId: 'legacy-old',
        taskId: 'task.a',
      );
      await _seedRun(
        db,
        id: 'legacy-latest',
        completedAt: DateTime.utc(2026, 5, 2),
        provenanceJson: _weightsProvenanceJson(
          evaluatorWeights: {'compile': 1.0, 'diff_size': 0.1},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'legacy-latest-a',
        runId: 'legacy-latest',
        taskId: 'task.a',
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(track: 'agentic'),
      );

      final source = export['source']! as Map<String, Object?>;
      expect(source['anchorRunId'], 'legacy-latest');
      expect(source['runIds'], ['legacy-latest']);
      expect(source['taskRunCount'], 1);
    },
  );

  test(
    'aggregate-compatible ignores schema-2 diagnostic weight differences',
    () async {
      await _seedRun(
        db,
        id: 'diag-old',
        completedAt: DateTime.utc(2026, 5, 1),
        provenanceJson: _weightsProvenanceJson(
          scoringSchemaVersion: 2,
          evaluatorWeights: {'compile': 1.0, 'diff_size': 0.3},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'diag-old-a',
        runId: 'diag-old',
        taskId: 'task.a',
      );
      await _seedRun(
        db,
        id: 'diag-latest',
        completedAt: DateTime.utc(2026, 5, 2),
        provenanceJson: _weightsProvenanceJson(
          scoringSchemaVersion: 2,
          evaluatorWeights: {'compile': 1.0},
        ),
      );
      await _seedTaskRun(
        db,
        id: 'diag-latest-a',
        runId: 'diag-latest',
        taskId: 'task.a',
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(track: 'agentic'),
      );

      final source = export['source']! as Map<String, Object?>;
      expect(source['anchorRunId'], 'diag-latest');
      expect(source['runIds'], ['diag-latest', 'diag-old']);
      expect(source['taskRunCount'], 2);
      expect(source['warnings'], isEmpty);
    },
  );

  test('source includes sanitized run provenance readiness summary', () async {
    await _seedRun(
      db,
      id: 'release-ready',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: _completeRunProvenanceJson(),
    );
    await _seedTaskRun(
      db,
      id: 'release-ready-a',
      runId: 'release-ready',
      taskId: 'task.a',
      primaryPass: true,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    final provenance = source['runProvenance']! as Map<String, Object?>;
    expect(provenance['runCount'], 1);
    expect(provenance['embeddedRunCount'], 1);
    expect(provenance['sandboxEnforcedRunCount'], 1);
    expect(provenance['taskExecutionPolicyRunCount'], 1);
    expect(provenance['networkDisabledTaskPolicyRunCount'], 1);
    expect(provenance['taskResourceLimitRunCount'], 1);
    expect(provenance['sdkVersionRunCount'], 1);
    expect(provenance['dependencySnapshotRunCount'], 1);
    expect(provenance['pricingRegistryRunCount'], 1);
    expect(provenance['generatedCodeSandboxBackends'], ['test-sandbox']);
    expect(provenance['dartVersions'], ['3.11.4']);
    expect(provenance['flutterVersions'], ['3.41.6']);
    expect(provenance['warnings'], isEmpty);
    final environmentIds = provenance['environmentIds']! as List<Object?>;
    expect(environmentIds, hasLength(1));
    expect(environmentIds.single, isA<String>());
    expect((environmentIds.single! as String), hasLength(12));

    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('gitCommit')));
    expect(encoded, isNot(contains('/home/dev/private')));
    expect(encoded, isNot(contains('secret-provider-config')));
  });

  test('latest-run exports only the latest completed run for track', () async {
    await _seedRun(db, id: 'old', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(db, id: 'old-a', runId: 'old', taskId: 'task.a');
    await _seedRun(db, id: 'latest', completedAt: DateTime.utc(2026, 5, 2));
    await _seedTaskRun(db, id: 'latest-a', runId: 'latest', taskId: 'task.a');
    await _seedRun(
      db,
      id: 'new-codegen',
      completedAt: DateTime.utc(2026, 5, 3),
    );
    await _seedTaskRun(
      db,
      id: 'codegen-a',
      runId: 'new-codegen',
      taskId: 'task.a',
      benchmarkTrack: 'codegen',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['anchorRunId'], 'latest');
    expect(source['runIds'], ['latest']);
    expect(source['taskRunCount'], 1);
  });

  test('best-observed selects best task runs and respects run-id', () async {
    await _seedRun(db, id: 'r1', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'r1-fail',
      runId: 'r1',
      taskId: 'task.a',
      primaryPass: false,
      aggregateScore: 0.9,
    );
    await _seedRun(db, id: 'r2', completedAt: DateTime.utc(2026, 5, 2));
    await _seedTaskRun(
      db,
      id: 'r2-pass',
      runId: 'r2',
      taskId: 'task.a',
      primaryPass: true,
      aggregateScore: 0.7,
    );

    final best = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.bestObserved,
      ),
    );

    expect(
      (best['benchmark']! as Map<String, Object?>)['dataPolicy'],
      'best-observed',
    );
    final bestModel =
        ((best['models']! as List<Object?>).single! as Map<String, Object?>);
    expect(bestModel['passCount'], 1);
    expect((best['source']! as Map<String, Object?>)['runIds'], ['r1', 'r2']);

    final scoped = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.bestObserved,
        runId: 'r1',
      ),
    );

    final scopedModel =
        ((scoped['models']! as List<Object?>).single! as Map<String, Object?>);
    expect(scopedModel['passCount'], 0);
    expect((scoped['source']! as Map<String, Object?>)['runIds'], ['r1']);
  });

  test('model rows include metrics and rank by contract comparator', () async {
    await _seedRun(db, id: 'metrics', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'openai-pass',
      runId: 'metrics',
      taskId: 'task.a',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: true,
      latencyMs: 1000,
      promptTokens: 10,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-pass',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-pass',
      evaluatorId: 'hidden_test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-pass',
      evaluatorId: 'llm_judge',
      passed: true,
      details: const {
        'judge_overhead': {
          'provider_id': 'openai',
          'model_id': 'gpt-5',
          'prompt_tokens': 100,
          'completion_tokens': 20,
          'estimated_cost_micros': 325,
          'pricing_status': 'exact',
          'pricing_registry_version': '2026-05-31',
          'pricing_currency': 'USD',
        },
      },
    );
    await _seedTaskRun(
      db,
      id: 'openai-fail',
      runId: 'metrics',
      taskId: 'task.b',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: false,
      failureTag: 'public_tests_failed',
      latencyMs: 3000,
      promptTokens: 30,
      completionTokens: 40,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-fail',
      evaluatorId: 'test',
      passed: false,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-fail',
      evaluatorId: 'hidden_test',
      passed: false,
      details: const {'blocked': true, 'blocked_by': 'test'},
    );
    await _seedTaskRun(
      db,
      id: 'deepseek-pass-a',
      runId: 'metrics',
      taskId: 'task.a',
      providerId: 'deepseek',
      modelId: 'deepseek-v4-pro',
      primaryPass: true,
      latencyMs: 2000,
      promptTokens: 20,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-a',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-a',
      evaluatorId: 'hidden_test',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'deepseek-pass-b',
      runId: 'metrics',
      taskId: 'task.b',
      providerId: 'deepseek',
      modelId: 'deepseek-v4-pro',
      primaryPass: true,
      latencyMs: 2500,
      promptTokens: 20,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-b',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'deepseek-pass-b',
      evaluatorId: 'hidden_test',
      passed: true,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['judgeOverhead'], {
      'evaluationCount': 1,
      'promptTokens': 100,
      'completionTokens': 20,
      'knownEstimatedCostCount': 1,
      'unknownEstimatedCostCount': 0,
      'totalEstimatedCostMicros': 325,
      'pricingStatusCounts': {'exact': 1},
    });
    final scoring = export['scoring']! as Map<String, Object?>;
    expect(scoring['schemaVersion'], 2);
    expect(scoring['primaryMetric'], 'primary_pass');
    expect(scoring['rankingMetric'], 'primary_pass_rate');
    expect(scoring['confidenceInterval'], 'wilson_95');
    expect(scoring['diffSizePolicy'], 'diagnostic_only_full_patch');
    expect(scoring['diagnosticOnlyEvaluatorIds'], ['diff_size']);
    final defaultWeights =
        scoring['defaultEvaluatorWeights']! as Map<String, Object?>;
    expect(defaultWeights, isNot(contains('diff_size')));
    expect(
      scoring['failureTags'],
      containsAll(['pass', 'public_tests_failed', 'hidden_verifier_failed']),
    );

    final models = (export['models']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(models.first['providerId'], 'deepseek');
    expect(models.first['rank'], 1);
    expect(models.first['score'], models.first['passRate']);
    expect(models.first['score'], 1.0);

    final openai = models.singleWhere((row) => row['providerId'] == 'openai');
    expect(openai['passCount'], 1);
    expect(openai['sampleCount'], 2);
    expect(openai['passRate'], 0.5);
    expect(openai['trialCount'], 2);
    expect(openai['passAtK'], {
      '1': {'k': 1, 'passCount': 1, 'sampleCount': 2, 'passRate': 0.5},
    });
    expect(openai['confidenceInterval'], isA<Map<String, Object?>>());
    expect(openai['lowSample'], isTrue);
    expect(openai['medianLatencyMs'], 2000);
    expect(openai['medianPromptTokens'], 20);
    expect(openai['medianCompletionTokens'], 30);
    expect(openai['medianEstimatedCostMicros'], 326);
    expect(openai['knownEstimatedCostCount'], 2);
    expect(openai['unknownEstimatedCostCount'], 0);
    expect(openai['totalEstimatedCostMicros'], 651);
    expect(openai['costPerSolvedTaskMicros'], 651);
    expect(openai['cheapestPassingEstimatedCostMicros'], 213);
    expect(openai['publicPassCount'], 1);
    expect(openai['publicSampleCount'], 2);
    expect(openai['publicPassRate'], 0.5);
    expect(openai['hiddenPassCount'], 1);
    expect(openai['hiddenSampleCount'], 1);
    expect(openai['hiddenPassRate'], 1.0);
    expect(openai['blockedEvaluationCount'], 1);
    expect(openai['blockedTaskRunCount'], 1);
    expect(openai['failureBreakdown'], {'pass': 1, 'public_tests_failed': 1});
  });

  test('model config metadata separates effort variants', () async {
    await _seedRun(
      db,
      id: 'model-config',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: jsonEncode({
        'schemaVersion': 1,
        'providers': [
          {
            'id': 'openai',
            'selectedModelConfigs': [
              {
                'modelId': 'gpt-5::low',
                'baseModelId': 'gpt-5',
                'modelConfig': {
                  'effort': 'low',
                  'maxOutputTokens': 16384,
                  'temperature': {
                    'configured': false,
                    'status': 'provider_default',
                  },
                  'toolPolicy': 'none',
                },
              },
              {
                'modelId': 'gpt-5::high',
                'baseModelId': 'gpt-5',
                'modelConfig': {
                  'effort': 'high',
                  'maxOutputTokens': 16384,
                  'temperature': {
                    'configured': false,
                    'status': 'provider_default',
                  },
                  'toolPolicy': 'none',
                },
              },
            ],
          },
        ],
      }),
    );
    await _seedTaskRun(
      db,
      id: 'effort-low',
      runId: 'model-config',
      taskId: 'task.a',
      modelId: 'gpt-5::low',
      trialIndex: 0,
      primaryPass: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'effort-low',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'effort-high',
      runId: 'model-config',
      taskId: 'task.a',
      modelId: 'gpt-5::high',
      trialIndex: 1,
      primaryPass: false,
      failureTag: 'public_tests_failed',
    );
    await _seedEvaluation(
      db,
      taskRunId: 'effort-high',
      evaluatorId: 'test',
      passed: false,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['modelCount'], 2);
    final models = (export['models']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(
      {for (final row in models) row['modelId']},
      {'gpt-5::low', 'gpt-5::high'},
    );
    final low = models.singleWhere((row) => row['modelId'] == 'gpt-5::low');
    final high = models.singleWhere((row) => row['modelId'] == 'gpt-5::high');
    expect(low['baseModelId'], 'gpt-5');
    expect(low['modelConfig'], {
      'effort': 'low',
      'maxOutputTokens': 16384,
      'temperature': {'configured': false, 'status': 'provider_default'},
      'toolPolicy': 'none',
    });
    expect(high['baseModelId'], 'gpt-5');
    expect(high['modelConfig'], {
      'effort': 'high',
      'maxOutputTokens': 16384,
      'temperature': {'configured': false, 'status': 'provider_default'},
      'toolPolicy': 'none',
    });

    final cells = (export['taskModelCells']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(cells, hasLength(2));
    expect(
      cells.singleWhere((row) => row['modelId'] == 'gpt-5::high'),
      containsPair('modelConfig', {
        'effort': 'high',
        'maxOutputTokens': 16384,
        'temperature': {'configured': false, 'status': 'provider_default'},
        'toolPolicy': 'none',
      }),
    );

    final trials = (export['trialSummaries']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(
      trials.singleWhere((row) => row['modelId'] == 'gpt-5::low'),
      containsPair('modelConfig', {
        'effort': 'low',
        'maxOutputTokens': 16384,
        'temperature': {'configured': false, 'status': 'provider_default'},
        'toolPolicy': 'none',
      }),
    );
  });

  test(
    'task rows aggregate by task/version/track using measured samples',
    () async {
      await _seedRun(db, id: 'tasks', completedAt: DateTime.utc(2026, 5, 1));
      await _seedTaskRun(
        db,
        id: 'task-pass',
        runId: 'tasks',
        taskId: 'task.a',
        primaryPass: true,
      );
      await _seedEvaluation(
        db,
        taskRunId: 'task-pass',
        evaluatorId: 'test',
        passed: true,
      );
      await _seedEvaluation(
        db,
        taskRunId: 'task-pass',
        evaluatorId: 'agent_harness',
        passed: true,
        details: const {
          'steps': ['inspect', 'edit', 'test'],
          'usage': {'peak_context_tokens': 9000},
        },
      );
      await _seedEvaluation(
        db,
        taskRunId: 'task-pass',
        evaluatorId: 'task_hidden',
        passed: true,
      );
      await _seedTaskRun(
        db,
        id: 'task-null',
        runId: 'tasks',
        taskId: 'task.a',
        providerId: 'deepseek',
        modelId: 'deepseek-v4-pro',
        primaryPass: null,
      );
      await _seedTaskRun(
        db,
        id: 'task-fail-v2',
        runId: 'tasks',
        taskId: 'task.a',
        taskVersion: 2,
        primaryPass: false,
      );

      final export = await buildLeaderboardExport(
        db,
        options: const LeaderboardExportOptions(
          track: 'agentic',
          strategy: LeaderboardExportStrategy.latestRun,
        ),
      );

      final tasks = (export['tasks']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(tasks, hasLength(2));
      expect(tasks.first['taskId'], 'task.a');
      expect(tasks.first['taskVersion'], 1);
      expect(tasks.first['trialCount'], 1);
      expect(tasks.first['sampleCount'], 1);
      expect(tasks.first['modelCount'], 2);
      expect(tasks.first['passRate'], 1.0);
      expect(tasks.first['confidenceInterval'], isA<Map<String, Object?>>());
      expect(tasks.first['medianStepCount'], 3);
      expect(tasks.first['medianPeakContextTokens'], 9000);
      expect(tasks.first['publicPassCount'], 1);
      expect(tasks.first['publicSampleCount'], 1);
      expect(tasks.first['hiddenPassCount'], 1);
      expect(tasks.first['hiddenSampleCount'], 1);
      expect(tasks.first['blockedEvaluationCount'], 0);
      expect(tasks.first['blockedTaskRunCount'], 0);
      expect(tasks.last['taskVersion'], 2);
      expect(tasks.last['passRate'], 0.0);
    },
  );

  test('task-model cells expose sanitized aggregate heatmap data', () async {
    await _seedRun(db, id: 'cells', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'openai-a-pass',
      runId: 'cells',
      taskId: 'task.a',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: true,
      latencyMs: 1000,
      promptTokens: 10,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-pass',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-pass',
      evaluatorId: 'agent_harness',
      passed: true,
      details: const {'step_count': 6, 'peak_context_tokens': 12000},
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-pass',
      evaluatorId: 'task_hidden',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'openai-a-fail',
      runId: 'cells',
      taskId: 'task.a',
      providerId: 'openai',
      modelId: 'gpt-5',
      primaryPass: false,
      failureTag: 'public_tests_failed',
      latencyMs: 3000,
      promptTokens: 30,
      completionTokens: 40,
      responseText: 'raw response must not leak',
      patchText: 'diff --git a/private b/private',
      trajectoryLogPath: '/home/dev/private/trajectory.log',
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-fail',
      evaluatorId: 'test',
      passed: false,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-fail',
      evaluatorId: 'agent_harness',
      passed: true,
      details: const {
        'metadata': {'stepCount': 10, 'peakContextTokens': 16000},
      },
    );
    await _seedEvaluation(
      db,
      taskRunId: 'openai-a-fail',
      evaluatorId: 'task_hidden',
      passed: false,
      details: const {'blocked': true, 'blocked_by': 'test'},
    );
    await _seedTaskRun(
      db,
      id: 'deepseek-b-pass',
      runId: 'cells',
      taskId: 'task.b',
      providerId: 'deepseek',
      modelId: 'deepseek-v4-pro',
      primaryPass: true,
      latencyMs: 2000,
      promptTokens: 20,
      completionTokens: 20,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
      ),
    );

    final cells = (export['taskModelCells']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(cells, hasLength(2));

    final openai = cells.singleWhere((row) => row['providerId'] == 'openai');
    expect(openai['modelId'], 'gpt-5');
    expect(openai['taskId'], 'task.a');
    expect(openai['taskVersion'], 1);
    expect(openai['benchmarkTrack'], 'agentic');
    expect(openai['passCount'], 1);
    expect(openai['sampleCount'], 2);
    expect(openai['passRate'], 0.5);
    expect(openai['trialCount'], 2);
    expect(openai['errorCount'], 1);
    expect(openai['passAtK'], {
      '1': {'k': 1, 'passCount': 0, 'sampleCount': 1, 'passRate': 0.0},
      '2': {'k': 2, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
    });
    expect(openai['publicPassCount'], 1);
    expect(openai['publicSampleCount'], 2);
    expect(openai['publicPassRate'], 0.5);
    expect(openai['hiddenPassCount'], 1);
    expect(openai['hiddenSampleCount'], 1);
    expect(openai['hiddenPassRate'], 1.0);
    expect(openai['blockedEvaluationCount'], 1);
    expect(openai['blockedTaskRunCount'], 1);
    expect(openai['medianStepCount'], 8);
    expect(openai['medianPeakContextTokens'], 14000);
    expect(openai['medianLatencyMs'], 2000);
    expect(openai['medianPromptTokens'], 20);
    expect(openai['medianCompletionTokens'], 30);
    expect(openai['medianEstimatedCostMicros'], 326);
    expect(openai['knownEstimatedCostCount'], 2);
    expect(openai['unknownEstimatedCostCount'], 0);
    expect(openai['failureBreakdown'], {'pass': 1, 'public_tests_failed': 1});

    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('raw response must not leak')));
    expect(encoded, isNot(contains('diff --git a/private b/private')));
    expect(encoded, isNot(contains('/home/dev/private/trajectory.log')));
  });

  test('exports pass@k and capped sanitized trial summaries', () async {
    await _seedRun(db, id: 'trials', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'trial-fail',
      runId: 'trials',
      taskId: 'task.a',
      primaryPass: false,
      failureTag: 'public_tests_failed',
      trialIndex: 0,
      latencyMs: 3000,
      promptTokens: 30,
      completionTokens: 40,
      responseText: 'private raw response',
      patchText: 'diff --git private',
      trajectoryLogPath: '/home/dev/private/trial.log',
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-fail',
      evaluatorId: 'test',
      passed: false,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-fail',
      evaluatorId: 'agent_harness',
      passed: false,
      details: const {'step_count': 4, 'peak_context_tokens': 8000},
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-fail',
      evaluatorId: 'task_hidden',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'trial-pass',
      runId: 'trials',
      taskId: 'task.a',
      primaryPass: true,
      trialIndex: 1,
      latencyMs: 1000,
      promptTokens: 10,
      completionTokens: 20,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-pass',
      evaluatorId: 'test',
      passed: true,
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-pass',
      evaluatorId: 'agent_harness',
      passed: true,
      details: const {'stepCount': 8, 'peakContextTokens': 12000},
    );
    await _seedEvaluation(
      db,
      taskRunId: 'trial-pass',
      evaluatorId: 'task_hidden',
      passed: true,
    );
    await _seedTaskRun(
      db,
      id: 'trial-hidden-fail',
      runId: 'trials',
      taskId: 'task.a',
      primaryPass: false,
      failureTag: 'hidden_verifier_failed',
      trialIndex: 2,
      latencyMs: 2000,
      promptTokens: 20,
      completionTokens: 30,
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(
        track: 'agentic',
        strategy: LeaderboardExportStrategy.latestRun,
        trialSummaryLimit: 2,
      ),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['trialSummaryCount'], 2);
    expect(source['trialSummaryTotalCount'], 3);
    expect(source['trialSummaryTruncated'], isTrue);
    expect(source['trialSummaryLimit'], 2);

    final model =
        ((export['models']! as List<Object?>).single! as Map<String, Object?>);
    expect(model['trialCount'], 3);
    expect(model['sampleCount'], 3);
    expect(model['medianStepCount'], 6);
    expect(model['medianPeakContextTokens'], 10000);
    expect(model['passAtK'], {
      '1': {'k': 1, 'passCount': 0, 'sampleCount': 1, 'passRate': 0.0},
      '2': {'k': 2, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
      '3': {'k': 3, 'passCount': 1, 'sampleCount': 1, 'passRate': 1.0},
    });

    final cell =
        ((export['taskModelCells']! as List<Object?>).single!
            as Map<String, Object?>);
    expect(cell['passAtK'], model['passAtK']);
    expect(cell['confidenceInterval'], isA<Map<String, Object?>>());
    expect(cell['medianStepCount'], 6);
    expect(cell['medianPeakContextTokens'], 10000);

    final trials = (export['trialSummaries']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(trials, hasLength(2));
    expect(trials.first['trialId'], isA<String>());
    expect(trials.first['trialId'].toString(), hasLength(12));
    expect(trials.first['trialIndex'], 0);
    expect(trials.first['primaryPass'], isFalse);
    expect(trials.first['failureTag'], 'public_tests_failed');
    expect(trials.first['publicPassed'], isFalse);
    expect(trials.first['hiddenPassed'], isTrue);
    expect(trials.first['stepCount'], 4);
    expect(trials.first['peakContextTokens'], 8000);
    expect(trials.first['latencyMs'], 3000);
    expect(trials.first['promptTokens'], 30);
    expect(trials.first['completionTokens'], 40);
    expect(trials.first['estimatedCostMicros'], isA<int>());
    expect(trials[1]['trialIndex'], 1);
    expect(trials[1]['primaryPass'], isTrue);
    expect(trials[1]['failureTag'], 'pass');
    expect(trials[1]['stepCount'], 8);
    expect(trials[1]['peakContextTokens'], 12000);

    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('private raw response')));
    expect(encoded, isNot(contains('diff --git private')));
    expect(encoded, isNot(contains('/home/dev/private/trial.log')));
  });

  test('public export excludes raw and private task-run fields', () async {
    await _seedRun(db, id: 'safe', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'safe-a',
      runId: 'safe',
      taskId: 'task.a',
      responseText: 'raw prompt secret response',
      patchText: 'diff --git secret patch',
      trajectoryLogPath: '/home/dev/private/trajectory.log',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('raw prompt secret response')));
    expect(encoded, isNot(contains('diff --git secret patch')));
    expect(encoded, isNot(contains('/home/dev/private/trajectory.log')));
  });

  test('malformed or missing provenance warns without excluding', () async {
    await _seedRun(db, id: 'anchor', completedAt: DateTime.utc(2026, 5, 2));
    await _seedTaskRun(db, id: 'anchor-a', runId: 'anchor', taskId: 'task.a');
    await _seedRun(
      db,
      id: 'malformed',
      completedAt: DateTime.utc(2026, 5, 1),
      provenanceJson: '{bad',
    );
    await _seedTaskRun(
      db,
      id: 'malformed-a',
      runId: 'malformed',
      taskId: 'task.a',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['runIds'], ['anchor', 'malformed']);
    expect(source['warnings'].toString(), contains('malformed provenance'));
  });

  test('empty matching result set emits empty JSON with warning', () async {
    await _seedRun(db, id: 'codegen', completedAt: DateTime.utc(2026, 5, 1));
    await _seedTaskRun(
      db,
      id: 'codegen-a',
      runId: 'codegen',
      taskId: 'task.a',
      benchmarkTrack: 'codegen',
    );

    final export = await buildLeaderboardExport(
      db,
      options: const LeaderboardExportOptions(track: 'agentic'),
    );

    final source = export['source']! as Map<String, Object?>;
    expect(source['taskRunCount'], 0);
    expect(export['models'], isEmpty);
    expect(export['tasks'], isEmpty);
    expect(source['warnings'].toString(), contains('No completed task runs'));
  });
}

String _completeRunProvenanceJson() {
  return jsonEncode({
    'schemaVersion': 1,
    'config': {
      'evaluatorWeights': {'compile': 1.0},
      'generatedCodeSandbox': {
        'required': true,
        'enforced': true,
        'backend': 'test-sandbox',
      },
      'pricingRegistry': {
        'version': '2026-05-31',
        'currency': 'USD',
        'modelCount': 2,
      },
      'scoringSchemaVersion': 2,
      'providerConfig': 'secret-provider-config',
    },
    'tasks': [
      {
        'id': 'task.a',
        'executionPolicy': {
          'allowInternet': false,
          'resources': {
            'cpus': 2,
            'memoryMb': 8192,
            'maxProcesses': 64,
            'maxOutputBytes': 1048576,
          },
          'resourceEnforcement': _fullyEnforcedResourcePolicy(),
        },
      },
    ],
    'environment': {
      'hostPlatform': 'linux',
      'dartVersion': '3.11.4 (stable)',
      'flutterVersion': '3.41.6',
      'dependencySnapshot': {
        'status': 'present',
        'files': {
          'pubspec.lock': {
            'sha256':
                '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            'bytes': 123,
          },
        },
      },
      'gitCommit': 'abcdef',
      'privatePath': '/home/dev/private/project',
    },
  });
}

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

Future<void> _seedRun(
  AppDatabase db, {
  required String id,
  required DateTime completedAt,
  String provenanceJson =
      '{"schemaVersion":1,"config":{"scoringSchemaVersion":2,"evaluatorWeights":{"compile":1.0}}}',
}) async {
  await db
      .into(db.runs)
      .insert(
        RunsCompanion.insert(
          id: id,
          startedAt: completedAt.subtract(const Duration(minutes: 5)),
          completedAt: Value(completedAt),
          provenanceJson: Value(provenanceJson),
        ),
      );
}

String _weightsProvenanceJson({
  int? scoringSchemaVersion,
  required Map<String, Object?> evaluatorWeights,
}) {
  return jsonEncode({
    'schemaVersion': 1,
    'config': {
      if (scoringSchemaVersion != null)
        'scoringSchemaVersion': scoringSchemaVersion,
      'evaluatorWeights': evaluatorWeights,
    },
  });
}

String _harnessProvenanceJson(String kind, {String? agent, String? version}) =>
    jsonEncode({
      'schemaVersion': 1,
      'config': {
        'scoringSchemaVersion': 2,
        'evaluatorWeights': {'compile': 1.0},
        'agentHarnesses': {
          'harness-v1': {
            'kind': kind,
            if (agent != null) 'agent': agent,
            if (version != null) 'agentVersion': version,
          },
        },
      },
    });

String _presetProvenanceJson() => jsonEncode({
  'schemaVersion': 2,
  'config': {
    'scoringSchemaVersion': 2,
    'evaluatorWeights': {'compile': 1.0},
    'corpusManifest': {
      'preset': 'mvp',
      'tasks': [
        {
          'taskId': 'task.a',
          'taskVersion': 1,
          'taskBundleDigest': List.filled(64, 'a').join(),
        },
        {
          'taskId': 'task.b',
          'taskVersion': 1,
          'taskBundleDigest': List.filled(64, 'b').join(),
        },
      ],
      'digestSha256': List.filled(64, 'c').join(),
    },
  },
});

Future<void> _seedTaskRun(
  AppDatabase db, {
  required String id,
  required String runId,
  required String taskId,
  String providerId = 'openai',
  String modelId = 'gpt-5',
  int taskVersion = 1,
  String benchmarkTrack = 'agentic',
  String? harnessId = 'harness-v1',
  bool? primaryPass = true,
  String? failureTag,
  int latencyMs = 1000,
  int? promptTokens = 10,
  int? completionTokens = 20,
  double aggregateScore = 1.0,
  String responseText = '',
  String? patchText,
  String? trajectoryLogPath,
  int trialIndex = 0,
  DateTime? completedAt,
}) async {
  await db
      .into(db.taskRuns)
      .insert(
        TaskRunsCompanion.insert(
          id: id,
          runId: runId,
          providerId: providerId,
          modelId: modelId,
          taskId: taskId,
          responseText: responseText,
          latencyMs: latencyMs,
          aggregateScore: aggregateScore,
          completedAt: completedAt ?? DateTime.utc(2026, 5, 1, 12),
          promptTokens: Value(promptTokens),
          completionTokens: Value(completionTokens),
          trialIndex: Value(trialIndex),
          taskVersion: Value(taskVersion),
          benchmarkTrack: Value(benchmarkTrack),
          harnessId: Value(harnessId),
          primaryPass: Value(primaryPass),
          failureTag: Value(failureTag),
          patchText: Value(patchText),
          trajectoryLogPath: Value(trajectoryLogPath),
        ),
      );
}

Future<void> _seedEvaluation(
  AppDatabase db, {
  required String taskRunId,
  required String evaluatorId,
  required bool passed,
  Map<String, Object?> details = const {},
}) async {
  await db
      .into(db.evaluations)
      .insert(
        EvaluationsCompanion.insert(
          id: '$taskRunId-$evaluatorId',
          taskRunId: taskRunId,
          evaluatorId: evaluatorId,
          passed: passed,
          score: passed ? 1.0 : 0.0,
          detailsJson: jsonEncode(details),
        ),
      );
}
