import 'dart:convert';

import 'package:dart_arena/export/json_exporter.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

void main() {
  test('exports readable blocked evaluator status without raw details', () {
    final summary = RunSummary(
      run: Run(
        id: 'r1',
        startedAt: DateTime.utc(2026, 6, 2),
        completedAt: DateTime.utc(2026, 6, 2, 1),
        judgeModel: null,
        name: 'json',
        provenanceJson: jsonEncode({
          'schemaVersion': 1,
          'providers': [
            {
              'id': 'provider',
              'selectedModelConfigs': [
                {
                  'modelId': 'model::high',
                  'baseModelId': 'model',
                  'modelConfig': {
                    'effort': 'high',
                    'maxOutputTokens': 4096,
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
      ),
      taskRuns: [
        TaskRun(
          id: 'tr1',
          runId: 'r1',
          providerId: 'provider',
          modelId: 'model::high',
          taskId: 'task',
          responseText: 'response',
          promptTokens: 1,
          completionTokens: 2,
          latencyMs: 3,
          aggregateScore: 0,
          completedAt: DateTime.utc(2026, 6, 2, 1),
          trialIndex: 0,
          taskVersion: 1,
          benchmarkTrack: 'codegen',
          harnessId: null,
          primaryPass: false,
          failureTag: 'compile_failed',
          patchText: null,
          trajectoryLogPath: null,
        ),
      ],
      evaluationsByTaskRunId: const {
        'tr1': [
          Evaluation(
            id: 'e0',
            taskRunId: 'tr1',
            evaluatorId: 'agent_harness',
            passed: false,
            score: 0,
            rationale: 'agent harness failed',
            detailsJson:
                '{"status":"failure","exit_code":1,"stdout_preview":"","stderr_preview":"private stderr","trajectory_log_path":"/tmp/private/trace.log","workspace":"/tmp/private/workspace"}',
          ),
          Evaluation(
            id: 'e1',
            taskRunId: 'tr1',
            evaluatorId: 'test',
            passed: false,
            score: 0,
            rationale: 'blocked by compile',
            detailsJson:
                '{"blocked":true,"blocked_by":"compile","reason":"/tmp/private/path","stderr":"/tmp/private/path"}',
          ),
          Evaluation(
            id: 'e2',
            taskRunId: 'tr1',
            evaluatorId: 'llm_judge',
            passed: true,
            score: 1,
            rationale: 'judge ok',
            detailsJson:
                '{"raw_judge_response":"private judge text","judge_overhead":{"provider_id":"openai","model_id":"gpt-5","prompt_tokens":10,"completion_tokens":2,"estimated_cost_micros":33,"pricing_status":"exact","pricing_registry_version":"2026-05-31","pricing_currency":"USD"}}',
          ),
        ],
      },
    );

    final decoded =
        jsonDecode(runResultsToJson(summary)) as Map<String, Object?>;
    final taskRuns = decoded['taskRuns'] as List<Object?>;
    final taskRun = taskRuns.single as Map<String, Object?>;
    expect(taskRun['modelId'], 'model::high');
    expect(taskRun['baseModelId'], 'model');
    expect(taskRun['modelConfig'], {
      'effort': 'high',
      'maxOutputTokens': 4096,
      'temperature': {'configured': false, 'status': 'provider_default'},
      'toolPolicy': 'none',
    });
    final evaluations = taskRun['evaluations'] as List<Object?>;
    final evaluation = evaluations.cast<Map<String, Object?>>().singleWhere(
      (row) => row['evaluatorId'] == 'test',
    );

    expect(evaluation['status'], 'blocked');
    expect(evaluation['blockedBy'], 'compile');
    expect(evaluation['blockedReason'], 'blocked by compile');
    expect(evaluation.containsKey('detailsJsonSha256'), isTrue);
    final judge = evaluations.cast<Map<String, Object?>>().singleWhere(
      (row) => row['evaluatorId'] == 'llm_judge',
    );
    expect(judge['judgeOverhead'], {
      'providerId': 'openai',
      'modelId': 'gpt-5',
      'promptTokens': 10,
      'completionTokens': 2,
      'estimatedCostMicros': 33,
      'pricingStatus': 'exact',
      'pricingRegistryVersion': '2026-05-31',
      'pricingCurrency': 'USD',
    });
    final harness = evaluations.cast<Map<String, Object?>>().singleWhere(
      (row) => row['evaluatorId'] == 'agent_harness',
    );
    expect(harness['agentHarness'], {
      'status': 'failure',
      'exitCode': 1,
      'stdoutPreviewPresent': false,
      'stderrPreviewPresent': true,
      'trajectoryLogPresent': true,
    });
    expect(jsonEncode(decoded), isNot(contains('/tmp/private/path')));
    expect(jsonEncode(decoded), isNot(contains('/tmp/private/trace.log')));
    expect(jsonEncode(decoded), isNot(contains('/tmp/private/workspace')));
    expect(jsonEncode(decoded), isNot(contains('private stderr')));
    expect(jsonEncode(decoded), isNot(contains('private judge text')));
  });
}
