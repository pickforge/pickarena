import 'package:dart_arena/core/scoring.dart';
import 'package:test/test.dart';

void main() {
  group('combineStages', () {
    test('geometric mean of equal stages equals each stage', () {
      expect(
        combineStages(planScore: 0.8, executeScore: 0.8),
        closeTo(0.8, 1e-9),
      );
    });

    test('geometric mean of (0.5, 0.9) ~ 0.6708', () {
      expect(
        combineStages(planScore: 0.5, executeScore: 0.9),
        closeTo(0.6708203932, 1e-9),
      );
    });

    test('floor-clamp prevents zero from collapsing the score', () {
      expect(
        combineStages(planScore: 0.0, executeScore: 0.9),
        closeTo(0.0948683298, 1e-9),
      );
    });

    test('product mode multiplies clamped values', () {
      expect(
        combineStages(
          planScore: 0.5,
          executeScore: 0.5,
          mode: StageCombine.product,
        ),
        closeTo(0.25, 1e-9),
      );
    });

    test('weightedSum mode is 0.5 * plan + 0.5 * execute', () {
      expect(
        combineStages(
          planScore: 0.4,
          executeScore: 1.0,
          mode: StageCombine.weightedSum,
        ),
        closeTo(0.7, 1e-9),
      );
    });

    test('values above 1.0 are clamped to 1.0', () {
      expect(
        combineStages(planScore: 2.0, executeScore: 1.0),
        closeTo(1.0, 1e-9),
      );
    });
  });
}
