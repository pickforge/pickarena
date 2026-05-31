import 'package:dart_arena/export/csv_exporter.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

RunSummary _summary({
  String? name,
  String modelId = 'gpt-5',
  int? promptTokens = 10,
  int? completionTokens = 20,
  bool? primaryPass = true,
  String? failureTag = 'pass',
}) {
  final run = Run(
    id: 'r1',
    startedAt: DateTime.utc(2026, 5, 2, 14, 23),
    completedAt: DateTime.utc(2026, 5, 2, 14, 31),
    judgeModel: null,
    name: name,
  );
  final taskRun = TaskRun(
    id: 'tr1',
    runId: 'r1',
    providerId: 'openai',
    modelId: modelId,
    taskId: 'bug.off_by_one',
    responseText: 'raw',
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    latencyMs: 1500,
    aggregateScore: 0.85,
    completedAt: DateTime.utc(2026, 5, 2, 14, 24),
    trialIndex: 1,
    taskVersion: 2,
    benchmarkTrack: 'codegen',
    harnessId: 'h1',
    primaryPass: primaryPass,
    failureTag: failureTag,
    patchText: 'abc',
    trajectoryLogPath: '/tmp/trajectory.log',
  );
  return RunSummary(
    run: run,
    taskRuns: [taskRun],
    evaluationsByTaskRunId: const {
      'tr1': [
        Evaluation(
          id: 'e1',
          taskRunId: 'tr1',
          evaluatorId: 'compile',
          passed: true,
          score: 1.0,
          rationale: null,
          detailsJson: '{}',
        ),
        Evaluation(
          id: 'e2',
          taskRunId: 'tr1',
          evaluatorId: 'analyze',
          passed: true,
          score: 0.9,
          rationale: null,
          detailsJson: '{}',
        ),
        Evaluation(
          id: 'e3',
          taskRunId: 'tr1',
          evaluatorId: 'test',
          passed: true,
          score: 1.0,
          rationale: null,
          detailsJson: '{}',
        ),
      ],
    },
  );
}

void main() {
  test('header row contains all expected columns', () {
    final csv = runSummaryToCsv(_summary());
    final firstLine = csv.split('\n').first;
    expect(firstLine, startsWith('run_id,run_name,started_at,task_id'));
    expect(firstLine, contains('trial_index,task_version,benchmark_track'));
    expect(firstLine, contains('harness_id,primary_pass,failure_tag'));
    expect(firstLine, contains('patch_chars,trajectory_log_path'));
    expect(firstLine, contains('score_compile,score_analyze,score_test'));
    expect(firstLine, contains('score_hidden_test'));
    expect(firstLine, endsWith('latency_ms,prompt_tokens,completion_tokens'));
  });

  test('writes one row per task run with named run', () {
    final csv = runSummaryToCsv(_summary(name: 'demo'));
    final lines = csv.split('\n');
    expect(lines.length, greaterThan(2));
    final values = lines[1].split(',');
    expect(values[0], 'r1');
    expect(values[1], 'demo');
    expect(values[3], 'bug.off_by_one');
    expect(values[4], 'openai');
    expect(values[5], 'gpt-5');
    expect(values[6], '1');
    expect(values[7], '2');
    expect(values[8], 'codegen');
    expect(values[9], 'h1');
    expect(values[10], 'true');
    expect(values[11], 'pass');
    expect(values[12], '3');
    expect(values[13], '/tmp/trajectory.log');
    expect(values[14], '0.8500');
    expect(values[15], '1.0000'); // compile
    expect(values[16], '0.9000'); // analyze
    expect(values[17], '1.0000'); // test
  });

  test('null run name renders as empty cell', () {
    final csv = runSummaryToCsv(_summary());
    final values = csv.split('\n')[1].split(',');
    expect(values[1], '');
  });

  test('missing evaluator score renders as empty', () {
    final s = _summary();
    final csv = runSummaryToCsv(s);
    final values = csv.split('\n')[1].split(',');
    // hidden_test, widget_tree, llm_judge, diff_size are missing.
    expect(values[18], '');
    expect(values[19], '');
    expect(values[20], '');
    expect(values[21], '');
  });

  test('includes aggregate leaderboard summary fields', () {
    final csv = runSummaryToCsv(_summary());
    final lines = csv.split('\n');
    final marker = lines.indexOf('leaderboard_summary');
    expect(marker, greaterThan(0));
    final headers = lines[marker + 1].split(',');
    final values = lines[marker + 2].split(',');

    expect(headers, contains('primary_pass_rate'));
    expect(headers, contains('wilson_low'));
    expect(headers, contains('median_estimated_cost'));
    expect(headers, contains('cost_per_solved_task'));
    expect(headers, contains('failure_pass'));
    expect(values[headers.indexOf('provider_id')], 'openai');
    expect(values[headers.indexOf('model_id')], 'gpt-5');
    expect(values[headers.indexOf('task_run_count')], '1');
    expect(values[headers.indexOf('primary_pass_count')], '1');
    expect(values[headers.indexOf('primary_pass_sample_count')], '1');
    expect(values[headers.indexOf('primary_pass_rate')], '1.0000');
    expect(values[headers.indexOf('low_sample')], 'true');
    expect(values[headers.indexOf('median_latency_ms')], '1500');
    expect(values[headers.indexOf('median_prompt_tokens')], '10');
    expect(values[headers.indexOf('median_completion_tokens')], '20');
    expect(values[headers.indexOf('failure_pass')], '1');
  });

  test('summary leaves unknown legacy values empty instead of zero', () {
    final csv = runSummaryToCsv(
      _summary(
        modelId: 'unpriced',
        promptTokens: null,
        completionTokens: null,
        primaryPass: null,
        failureTag: null,
      ),
    );
    final lines = csv.split('\n');
    final marker = lines.indexOf('leaderboard_summary');
    final headers = lines[marker + 1].split(',');
    final values = lines[marker + 2].split(',');

    expect(values[headers.indexOf('primary_pass_rate')], '');
    expect(values[headers.indexOf('wilson_low')], '');
    expect(values[headers.indexOf('wilson_high')], '');
    expect(values[headers.indexOf('median_prompt_tokens')], '');
    expect(values[headers.indexOf('median_completion_tokens')], '');
    expect(values[headers.indexOf('median_estimated_cost')], '');
    expect(values[headers.indexOf('cost_per_solved_task')], '');
    expect(values[headers.indexOf('failure_unknown')], '1');
  });

  test('CSV cells with commas are quoted', () {
    final s = _summary(name: 'one, two');
    final csv = runSummaryToCsv(s);
    expect(csv, contains('"one, two"'));
  });

  test('CSV cells with quotes have quotes doubled', () {
    final s = _summary(name: 'a "b" c');
    final csv = runSummaryToCsv(s);
    expect(csv, contains('"a ""b"" c"'));
  });

  test('empty task-runs produces only the header row', () {
    final empty = RunSummary(
      run: Run(
        id: 'r0',
        startedAt: DateTime.utc(2026, 5, 2),
        completedAt: null,
        judgeModel: null,
        name: null,
      ),
      taskRuns: const [],
      evaluationsByTaskRunId: const {},
    );
    final csv = runSummaryToCsv(empty);
    expect(csv.split('\n'), hasLength(1));
  });
}
