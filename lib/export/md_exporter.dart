import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';

String runSummaryToMarkdown(RunSummary s) {
  final buf = StringBuffer();
  final ts = s.run.startedAt.toIso8601String();
  buf.writeln('# Benchmark run');
  if (s.run.name != null) {
    buf.writeln('**${s.run.name}**');
  }
  buf.writeln('Started: `$ts`  ·  Task-runs: ${s.taskRuns.length}');
  buf.writeln();

  buf.writeln(
    '| Task | Provider | Model | Aggregate '
    '| compile | analyze | test | hidden_test | widget_tree | llm_judge | diff_size '
    '| Latency |',
  );
  buf.writeln(
    '|------|----------|-------|-----------'
    '|---------|---------|------|-------------|-------------|-----------|-----------'
    '|---------|',
  );
  for (final tr in s.taskRuns) {
    final evals = <String, double>{};
    for (final e in s.evaluationsByTaskRunId[tr.id] ?? const <Evaluation>[]) {
      evals[e.evaluatorId] = e.score;
    }
    String fmt(String id) => (evals[id] ?? 0).toStringAsFixed(2);
    buf.writeln(
      '| ${tr.taskId} | ${tr.providerId} | ${tr.modelId} '
      '| **${tr.aggregateScore.toStringAsFixed(2)}** '
      '| ${fmt('compile')} | ${fmt('analyze')} | ${fmt('test')} '
      '| ${fmt('hidden_test')} | ${fmt('widget_tree')} '
      '| ${fmt('llm_judge')} | ${fmt('diff_size')} '
      '| ${tr.latencyMs}ms |',
    );
  }

  return buf.toString();
}
