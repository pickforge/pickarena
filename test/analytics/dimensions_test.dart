import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:flutter_test/flutter_test.dart';

TaskRun _tr({
  required String id,
  required double aggregate,
  int latencyMs = 5000,
}) =>
    TaskRun(
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
}
