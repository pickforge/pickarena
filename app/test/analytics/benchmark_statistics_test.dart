import 'package:dart_arena/analytics/benchmark_statistics.dart';
import 'package:dart_arena/analytics/cost_estimator.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:test/test.dart';

TaskRun _taskRun({
  required String id,
  bool? primaryPass,
  String? failureTag,
  int latencyMs = 1000,
  int? promptTokens,
  int? completionTokens,
}) {
  return TaskRun(
    id: id,
    runId: 'r',
    providerId: 'p',
    modelId: 'm',
    taskId: 'task',
    responseText: '',
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    latencyMs: latencyMs,
    aggregateScore: primaryPass == false ? 0 : 1,
    completedAt: DateTime.utc(2026),
    trialIndex: 0,
    taskVersion: 1,
    benchmarkTrack: 'codegen',
    harnessId: null,
    primaryPass: primaryPass,
    failureTag: failureTag,
    patchText: null,
    trajectoryLogPath: null,
  );
}

void main() {
  test('builds pass-rate, Wilson, median, and failure metrics', () {
    const estimator = CostEstimator(
      pricingRegistry: {
        'p:m': ModelPricing(inputCostPerMToken: 1, outputCostPerMToken: 3),
      },
    );

    final metrics = buildRankingMetrics([
      _taskRun(
        id: 'a',
        primaryPass: true,
        latencyMs: 1000,
        promptTokens: 10,
        completionTokens: 20,
      ),
      _taskRun(
        id: 'b',
        primaryPass: false,
        failureTag: 'public_tests_failed',
        latencyMs: 3000,
        promptTokens: 30,
        completionTokens: 40,
      ),
      _taskRun(
        id: 'c',
        primaryPass: true,
        latencyMs: 5000,
        promptTokens: 50,
        completionTokens: 60,
      ),
    ], costEstimator: estimator);

    expect(metrics.taskRunCount, 3);
    expect(metrics.primaryPassCount, 2);
    expect(metrics.primaryPassSampleCount, 3);
    expect(metrics.primaryPassRate, closeTo(2 / 3, 0.001));
    expect(metrics.primaryPassInterval, isNotNull);
    expect(metrics.lowSample, isTrue);
    expect(metrics.medianLatencyMs, 3000);
    expect(metrics.medianPromptTokens, 30);
    expect(metrics.medianCompletionTokens, 40);
    expect(metrics.medianEstimatedCostMicros, 150);
    expect(metrics.knownEstimatedCostCount, 3);
    expect(metrics.unknownEstimatedCostCount, 0);
    expect(metrics.totalEstimatedCostMicros, 450);
    expect(metrics.costPerSolvedTaskMicros, 225);
    expect(metrics.cheapestPassingEstimatedCostMicros, 70);
    expect(metrics.failureBreakdown['pass'], 2);
    expect(metrics.failureBreakdown['public_tests_failed'], 1);
  });

  test('missing token or pricing data leaves cost metrics unknown', () {
    final metrics = buildRankingMetrics([
      _taskRun(id: 'a', primaryPass: true, promptTokens: 10),
      _taskRun(id: 'b', primaryPass: true, completionTokens: 10),
    ]);

    expect(metrics.medianEstimatedCostMicros, isNull);
    expect(metrics.knownEstimatedCostCount, 0);
    expect(metrics.unknownEstimatedCostCount, 2);
    expect(metrics.totalEstimatedCostMicros, isNull);
    expect(metrics.costPerSolvedTaskMicros, isNull);
    expect(metrics.cheapestPassingEstimatedCostMicros, isNull);
  });

  test('normalizes unsupported failure tags to unknown', () {
    final breakdown = buildFailureBreakdown([
      _taskRun(id: 'a', primaryPass: false, failureTag: 'suspected_cheating'),
      _taskRun(id: 'b', primaryPass: null, failureTag: null),
    ]);

    expect(breakdown, {'unknown': 2});
  });

  test('median ignores unknown values and averages even samples', () {
    expect(medianInt([10, null, 20]), 15);
    expect(medianInt([null]), isNull);
  });
}
