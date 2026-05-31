import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/export/run_summary_leaderboard_summary.dart';
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

String runSummaryToCsv(
  RunSummary s, {
  List<TaskRun>? taskRuns,
  String Function(TaskRun taskRun)? trajectoryPathFor,
}) {
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
  for (final tr in taskRuns ?? s.taskRuns) {
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
      trajectoryPathFor?.call(tr) ?? tr.trajectoryLogPath ?? '',
      tr.aggregateScore.toStringAsFixed(4),
      ..._evaluatorIds.map((id) => evals[id]?.toStringAsFixed(4) ?? ''),
      tr.latencyMs.toString(),
      (tr.promptTokens ?? '').toString(),
      (tr.completionTokens ?? '').toString(),
    ]);
  }

  final summaryRows = runSummaryLeaderboardRows(s);
  if (summaryRows.isEmpty) return rows.map(_csvLine).join('\n');

  final leaderboardHeaders = <String>[
    'provider_id',
    'model_id',
    'task_run_count',
    'primary_pass_count',
    'primary_pass_sample_count',
    'primary_pass_rate',
    'wilson_low',
    'wilson_high',
    'low_sample',
    'median_latency_ms',
    'median_prompt_tokens',
    'median_completion_tokens',
    'median_estimated_cost',
    'cost_per_solved_task',
    ...supportedFailureTags.map((tag) => 'failure_$tag'),
  ];
  rows
    ..add(const [])
    ..add(const ['leaderboard_summary'])
    ..add(leaderboardHeaders);
  for (final row in summaryRows) {
    final metrics = row.metrics;
    rows.add([
      row.providerId,
      row.modelId,
      metrics.taskRunCount.toString(),
      metrics.primaryPassCount.toString(),
      metrics.primaryPassSampleCount.toString(),
      exportRate(metrics.primaryPassRate),
      exportRate(metrics.primaryPassInterval?.lower),
      exportRate(metrics.primaryPassInterval?.upper),
      metrics.lowSample.toString(),
      exportInt(metrics.medianLatencyMs),
      exportInt(metrics.medianPromptTokens),
      exportInt(metrics.medianCompletionTokens),
      exportCostDollars(metrics.medianEstimatedCostMicros),
      exportCostDollars(metrics.costPerSolvedTaskMicros),
      ...supportedFailureTags.map(
        (tag) => (metrics.failureBreakdown[tag] ?? 0).toString(),
      ),
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
