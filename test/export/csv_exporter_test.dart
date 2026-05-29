import 'package:dart_arena/export/csv_exporter.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

RunSummary _summary({String? name}) {
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
    modelId: 'gpt-5',
    taskId: 'bug.off_by_one',
    responseText: 'raw',
    promptTokens: 10,
    completionTokens: 20,
    latencyMs: 1500,
    aggregateScore: 0.85,
    completedAt: DateTime.utc(2026, 5, 2, 14, 24),
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
    expect(firstLine, contains('score_compile,score_analyze,score_test'));
    expect(firstLine, contains('score_hidden_test'));
    expect(firstLine, endsWith('latency_ms,prompt_tokens,completion_tokens'));
  });

  test('writes one row per task run with named run', () {
    final csv = runSummaryToCsv(_summary(name: 'demo'));
    final lines = csv.split('\n');
    expect(lines, hasLength(2));
    final values = lines[1].split(',');
    expect(values[0], 'r1');
    expect(values[1], 'demo');
    expect(values[3], 'bug.off_by_one');
    expect(values[4], 'openai');
    expect(values[5], 'gpt-5');
    expect(values[6], '0.8500');
    expect(values[7], '1.0000'); // compile
    expect(values[8], '0.9000'); // analyze
    expect(values[9], '1.0000'); // test
  });

  test('null run name renders as empty cell', () {
    final csv = runSummaryToCsv(_summary());
    final values = csv.split('\n')[1].split(',');
    expect(values[1], '');
  });

  test('missing evaluator score defaults to 0.0000', () {
    final s = _summary();
    final csv = runSummaryToCsv(s);
    final values = csv.split('\n')[1].split(',');
    // hidden_test, widget_tree, llm_judge, diff_size are missing.
    expect(values[10], '0.0000');
    expect(values[11], '0.0000');
    expect(values[12], '0.0000');
    expect(values[13], '0.0000');
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
