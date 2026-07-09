import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:test/test.dart';

TaskRun _tr({
  required String id,
  required double aggregate,
  int latencyMs = 5000,
  bool? primaryPass,
}) => TaskRun(
  id: id,
  runId: 'r1',
  providerId: 'p',
  modelId: 'm',
  taskId: 't',
  responseText: '',
  promptTokens: null,
  completionTokens: null,
  latencyMs: latencyMs,
  aggregateScore: aggregate,
  completedAt: DateTime(2026, 5, 3),
  trialIndex: 0,
  taskVersion: 1,
  benchmarkTrack: 'codegen',
  harnessId: null,
  primaryPass: primaryPass,
  failureTag: null,
);

Evaluation _ev({
  required String taskRunId,
  required String evaluatorId,
  required double score,
  bool? passed,
}) => Evaluation(
  id: '$taskRunId-$evaluatorId',
  taskRunId: taskRunId,
  evaluatorId: evaluatorId,
  passed: passed ?? (score >= 0.5),
  score: score,
  rationale: null,
  detailsJson: '{}',
);

void main() {
  test('Dimensions.empty returns all-zero', () {
    final d = Dimensions.fromTaskRuns(const [], const {});
    expect(d.intelligence, 0.0);
    expect(d.speed, 0.0);
    expect(d.elegance, 0.0);
    expect(d.reliability, 0.0);
    expect(d.overall, 0.0);
    expect(d.problems, 0);
  });

  test('ScoreDimension enum exposes the four axes plus overall', () {
    expect(ScoreDimension.values, [
      ScoreDimension.overall,
      ScoreDimension.intelligence,
      ScoreDimension.speed,
      ScoreDimension.elegance,
      ScoreDimension.reliability,
    ]);
  });

  group('reliability', () {
    test('100% pass when all task runs >= threshold', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 0.9),
        _tr(id: '2', aggregate: 0.5),
      ], const {});
      expect(d.reliability, 1.0);
    });

    test('50% pass when half are below threshold', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 0.8),
        _tr(id: '2', aggregate: 0.49),
      ], const {});
      expect(d.reliability, 0.5);
    });

    test('uses primaryPass when present instead of aggregate score', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 0.1, primaryPass: true),
        _tr(id: '2', aggregate: 1.0, primaryPass: false),
        _tr(id: '3', aggregate: 1.0),
      ], const {});
      expect(d.reliability, 0.5);
    });
  });

  group('speed', () {
    test('latency at floor produces speed = 1.0', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: Dimensions.latencyLoMs.toInt()),
      ], const {});
      expect(d.speed, 1.0);
    });

    test('latency at ceiling produces speed = 0.0', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: Dimensions.latencyHiMs.toInt()),
      ], const {});
      expect(d.speed, 0.0);
    });

    test('latency above ceiling clamps to 0.0', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: 120000),
      ], const {});
      expect(d.speed, 0.0);
    });

    test('latency below floor clamps to 1.0', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: 500),
      ], const {});
      expect(d.speed, 1.0);
    });

    test('uses median across task runs', () {
      final d = Dimensions.fromTaskRuns([
        _tr(id: '1', aggregate: 1.0, latencyMs: 1000),
        _tr(id: '2', aggregate: 1.0, latencyMs: 5000),
        _tr(id: '3', aggregate: 1.0, latencyMs: 50000),
      ], const {});
      expect(d.speed, closeTo(0.948, 0.01));
    });
  });

  group('intelligence', () {
    test('mean of correctness evaluators across all task runs', () {
      final tr1 = _tr(id: '1', aggregate: 1.0);
      final tr2 = _tr(id: '2', aggregate: 0.5);
      final d = Dimensions.fromTaskRuns(
        [tr1, tr2],
        {
          '1': [
            _ev(taskRunId: '1', evaluatorId: 'compile', score: 1.0),
            _ev(taskRunId: '1', evaluatorId: 'test', score: 0.5),
          ],
          '2': [
            _ev(taskRunId: '2', evaluatorId: 'compile', score: 1.0),
            _ev(taskRunId: '2', evaluatorId: 'test', score: 0.5),
          ],
        },
      );
      expect(d.intelligence, closeTo(2.0 / 3.0, 0.01));
    });

    test('ignores non-correctness evaluators (judge, diff_size)', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns(
        [tr],
        {
          '1': [
            _ev(taskRunId: '1', evaluatorId: 'compile', score: 1.0),
            _ev(taskRunId: '1', evaluatorId: 'llm_judge', score: 0.0),
            _ev(taskRunId: '1', evaluatorId: 'diff_size', score: 0.0),
          ],
        },
      );
      expect(d.intelligence, 1.0);
    });

    test('includes hidden_test as a correctness evaluator', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns(
        [tr],
        {
          '1': [
            _ev(taskRunId: '1', evaluatorId: 'test', score: 1.0),
            _ev(taskRunId: '1', evaluatorId: 'hidden_test', score: 0.0),
          ],
        },
      );
      expect(d.intelligence, 0.5);
    });

    test('includes custom hidden verifier IDs as correctness evaluators', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns(
        [tr],
        {
          '1': [
            _ev(taskRunId: '1', evaluatorId: 'test', score: 1.0),
            _ev(
              taskRunId: '1',
              evaluatorId: 'task_specific_hidden',
              score: 0.0,
            ),
          ],
        },
      );
      expect(d.intelligence, 0.5);
    });

    test('no correctness evaluators present yields 0.0', () {
      final tr = _tr(id: '1', aggregate: 0.0);
      final d = Dimensions.fromTaskRuns(
        [tr],
        {
          '1': [_ev(taskRunId: '1', evaluatorId: 'llm_judge', score: 1.0)],
        },
      );
      expect(d.intelligence, 0.0);
    });
  });

  group('elegance + problems', () {
    test('mean of llm_judge and diff_size when both present', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns(
        [tr],
        {
          '1': [
            _ev(taskRunId: '1', evaluatorId: 'llm_judge', score: 0.8),
            _ev(taskRunId: '1', evaluatorId: 'diff_size', score: 0.2),
          ],
        },
      );
      expect(d.elegance, closeTo(0.5, 0.0001));
    });

    test('uses only judge when diff_size missing', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns(
        [tr],
        {
          '1': [_ev(taskRunId: '1', evaluatorId: 'llm_judge', score: 0.8)],
        },
      );
      expect(d.elegance, 0.8);
    });

    test('zero when neither judge nor diff_size present', () {
      final tr = _tr(id: '1', aggregate: 1.0);
      final d = Dimensions.fromTaskRuns(
        [tr],
        {
          '1': [_ev(taskRunId: '1', evaluatorId: 'compile', score: 1.0)],
        },
      );
      expect(d.elegance, 0.0);
    });

    test('problems counts failed evaluations across all task runs', () {
      final tr1 = _tr(id: '1', aggregate: 1.0);
      final tr2 = _tr(id: '2', aggregate: 0.0);
      final d = Dimensions.fromTaskRuns(
        [tr1, tr2],
        {
          '1': [
            _ev(
              taskRunId: '1',
              evaluatorId: 'compile',
              score: 1.0,
              passed: true,
            ),
            _ev(
              taskRunId: '1',
              evaluatorId: 'analyze',
              score: 0.0,
              passed: false,
            ),
          ],
          '2': [
            _ev(
              taskRunId: '2',
              evaluatorId: 'compile',
              score: 0.0,
              passed: false,
            ),
            _ev(taskRunId: '2', evaluatorId: 'test', score: 0.0, passed: false),
          ],
        },
      );
      expect(d.problems, 3);
    });
  });

  test('overall is mean of the four dimensions', () {
    const d = Dimensions(
      intelligence: 1.0,
      speed: 0.6,
      elegance: 0.4,
      reliability: 0.0,
      problems: 0,
    );
    expect(d.overall, 0.5);
  });

  test('byDimension dispatches correctly', () {
    const d = Dimensions(
      intelligence: 0.1,
      speed: 0.2,
      elegance: 0.3,
      reliability: 0.4,
      problems: 5,
    );
    expect(d.byDimension(ScoreDimension.intelligence), 0.1);
    expect(d.byDimension(ScoreDimension.speed), 0.2);
    expect(d.byDimension(ScoreDimension.elegance), 0.3);
    expect(d.byDimension(ScoreDimension.reliability), 0.4);
    expect(d.byDimension(ScoreDimension.overall), closeTo(0.25, 0.0001));
  });
}
