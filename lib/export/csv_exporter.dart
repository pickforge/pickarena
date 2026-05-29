import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';

const _evaluatorIds = <String>[
  'compile',
  'analyze',
  'test',
  'hidden_test',
  'widget_tree',
  'llm_judge',
  'diff_size',
];

String runSummaryToCsv(RunSummary s) {
  final headers = <String>[
    'run_id',
    'run_name',
    'started_at',
    'task_id',
    'provider_id',
    'model_id',
    'trial_index',
    'task_version',
    'benchmark_track',
    'harness_id',
    'primary_pass',
    'failure_tag',
    'patch_chars',
    'trajectory_log_path',
    'aggregate_score',
    ..._evaluatorIds.map((e) => 'score_$e'),
    'latency_ms',
    'prompt_tokens',
    'completion_tokens',
  ];

  final rows = <List<String>>[headers];
  for (final tr in s.taskRuns) {
    final evals = <String, double>{};
    for (final e in s.evaluationsByTaskRunId[tr.id] ?? const <Evaluation>[]) {
      evals[e.evaluatorId] = e.score;
    }
    rows.add([
      tr.runId,
      s.run.name ?? '',
      s.run.startedAt.toIso8601String(),
      tr.taskId,
      tr.providerId,
      tr.modelId,
      tr.trialIndex.toString(),
      tr.taskVersion.toString(),
      tr.benchmarkTrack,
      tr.harnessId ?? '',
      tr.primaryPass?.toString() ?? '',
      tr.failureTag ?? '',
      (tr.patchText?.length ?? 0).toString(),
      tr.trajectoryLogPath ?? '',
      tr.aggregateScore.toStringAsFixed(4),
      ..._evaluatorIds.map((id) => (evals[id] ?? 0).toStringAsFixed(4)),
      tr.latencyMs.toString(),
      (tr.promptTokens ?? '').toString(),
      (tr.completionTokens ?? '').toString(),
    ]);
  }

  return rows.map(_csvLine).join('\n');
}

String _csvLine(List<String> cells) => cells.map(_csvCell).join(',');

String _csvCell(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}
