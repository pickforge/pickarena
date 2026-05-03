import 'package:dart_arena/analytics/dimensions.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
