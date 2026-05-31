import 'package:dart_arena/analytics/benchmark_statistics.dart';
import 'package:dart_arena/export/run_summary_leaderboard_summary.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';

String runSummaryToMarkdown(
  RunSummary s, {
  List<TaskRun>? taskRuns,
  String Function(TaskRun taskRun)? trajectoryPathFor,
}) {
  final buf = StringBuffer();
  final ts = s.run.startedAt.toIso8601String();
  buf.writeln('# Benchmark run');
  if (s.run.name != null) {
    buf.writeln('**${s.run.name}**');
  }
  final taskRunRows = taskRuns ?? s.taskRuns;
  buf.writeln('Started: `$ts`  ·  Task-runs: ${taskRunRows.length}');
  buf.writeln();

  final summaryRows = runSummaryLeaderboardRows(s);
  if (summaryRows.isNotEmpty) {
    buf.writeln('## Leaderboard summary');
    buf.writeln(
      '| Provider | Model | Task-runs | Primary Pass | Pass Rate | Wilson 95% | Low Sample | Median Latency | Median Tokens | Median Cost | Cost/Solved | Failures |',
    );
    buf.writeln(
      '|----------|-------|-----------|--------------|-----------|------------|------------|----------------|---------------|-------------|-------------|----------|',
    );
    for (final row in summaryRows) {
      final metrics = row.metrics;
      buf.writeln(
        '| ${row.providerId} | ${row.modelId} | ${metrics.taskRunCount} '
        '| ${metrics.primaryPassCount}/${metrics.primaryPassSampleCount} '
        '| ${_mdRate(metrics.primaryPassRate)} '
        '| ${_mdInterval(metrics)} '
        '| ${metrics.lowSample ? 'yes' : 'no'} '
        '| ${_mdLatency(metrics.medianLatencyMs)} '
        '| ${_mdTokens(metrics.medianPromptTokens, metrics.medianCompletionTokens)} '
        '| ${_mdCost(metrics.medianEstimatedCostMicros)} '
        '| ${_mdCost(metrics.costPerSolvedTaskMicros)} '
        '| ${_mdFailures(metrics.failureBreakdown)} |',
      );
    }
    if (summaryRows.any((row) => row.metrics.lowSample)) {
      buf.writeln();
      buf.writeln('Low-sample rows have fewer than 5 pass/fail samples.');
    }
    buf.writeln();
  }

  buf.writeln('## Task runs');
  buf.writeln(
    '| Task | Provider | Model | Trial | Task Version | Track | Harness | Primary Pass | Failure | Patch Chars | Trajectory | Aggregate '
    '| compile | analyze | test | hidden_test | widget_tree | llm_judge | diff_size '
    '| Latency |',
  );
  buf.writeln(
    '|------|----------|-------|-------|--------------|-------|---------|--------------|---------|-------------|------------|-----------'
    '|---------|---------|------|-------------|-------------|-----------|-----------'
    '|---------|',
  );
  for (final tr in taskRunRows) {
    final evals = <String, double>{};
    for (final e in s.evaluationsByTaskRunId[tr.id] ?? const <Evaluation>[]) {
      evals[e.evaluatorId] = e.score;
    }
    String fmt(String id) => evals[id]?.toStringAsFixed(2) ?? 'unknown';
    buf.writeln(
      '| ${tr.taskId} | ${tr.providerId} | ${tr.modelId} '
      '| ${tr.trialIndex} | ${tr.taskVersion} | ${tr.benchmarkTrack} '
      '| ${tr.harnessId ?? ''} | ${tr.primaryPass?.toString() ?? ''} '
      '| ${tr.failureTag ?? ''} '
      '| ${tr.patchText?.length ?? 0} '
      '| ${trajectoryPathFor?.call(tr) ?? tr.trajectoryLogPath ?? ''} '
      '| **${tr.aggregateScore.toStringAsFixed(2)}** '
      '| ${fmt('compile')} | ${fmt('analyze')} | ${fmt('test')} '
      '| ${fmt('hidden_test')} | ${fmt('widget_tree')} '
      '| ${fmt('llm_judge')} | ${fmt('diff_size')} '
      '| ${tr.latencyMs}ms |',
    );
  }

  return buf.toString();
}

String _mdRate(double? value) {
  if (value == null) return 'unknown';
  return '${(value * 100).toStringAsFixed(0)}%';
}

String _mdInterval(RankingMetrics metrics) {
  final interval = metrics.primaryPassInterval;
  if (interval == null) return 'unknown';
  return '${_mdRate(interval.lower)}–${_mdRate(interval.upper)}';
}

String _mdLatency(int? latencyMs) {
  if (latencyMs == null) return 'unknown';
  if (latencyMs < 1000) return '${latencyMs}ms';
  return '${(latencyMs / 1000).toStringAsFixed(1)}s';
}

String _mdTokens(int? promptTokens, int? completionTokens) {
  if (promptTokens == null && completionTokens == null) return 'unknown';
  return '${promptTokens ?? '?'} in / ${completionTokens ?? '?'} out';
}

String _mdCost(int? costMicros) {
  if (costMicros == null) return 'unknown';
  return '\$${(costMicros / 1000000).toStringAsFixed(6)}';
}

String _mdFailures(Map<String, int> breakdown) {
  if (breakdown.isEmpty) return 'unknown';
  final entries = breakdown.entries.where((entry) => entry.value > 0).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (entries.isEmpty) return 'unknown';
  return entries.map((entry) => '${entry.key}: ${entry.value}').join('<br>');
}
