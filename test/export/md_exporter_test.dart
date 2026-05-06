import 'package:dart_arena/export/md_exporter.dart';
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
  test('renders heading, label, and metadata line', () {
    final md = runSummaryToMarkdown(_summary(name: 'demo'));
    expect(md, contains('# Benchmark run'));
    expect(md, contains('**demo**'));
    expect(md, contains('Started:'));
    expect(md, contains('Task-runs: 1'));
  });

  test('omits label line when name is null', () {
    final md = runSummaryToMarkdown(_summary());
    // No line should be exclusively a bold label (starts and ends with **)
    final hasBoldLabelLine = md
        .split('\n')
        .any((l) => l.startsWith('**') && l.endsWith('**'));
    expect(hasBoldLabelLine, isFalse);
  });

  test('renders a markdown table with one data row', () {
    final md = runSummaryToMarkdown(_summary());
    expect(md, contains('| Task | Provider | Model |'));
    expect(md, contains('|------|'));
    expect(md, contains('| bug.off_by_one | openai | gpt-5'));
    expect(md, contains('**0.85**'));
  });

  test('missing evaluator score renders as 0.00', () {
    final md = runSummaryToMarkdown(_summary());
    final dataLine = md
        .split('\n')
        .firstWhere((l) => l.contains('bug.off_by_one'));
    // widget_tree, llm_judge, diff_size missing => 0.00
    final zeroOccurrences = '0.00'.allMatches(dataLine).length;
    expect(zeroOccurrences, greaterThanOrEqualTo(3));
  });

  test('empty task-runs renders heading + empty table header', () {
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
    final md = runSummaryToMarkdown(empty);
    expect(md, contains('# Benchmark run'));
    expect(md, contains('Task-runs: 0'));
    expect(md, contains('| Task |'));
  });
}
