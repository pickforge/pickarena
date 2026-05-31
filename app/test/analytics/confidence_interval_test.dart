import 'package:dart_arena/analytics/confidence_interval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Wilson interval is unknown for zero samples', () {
    expect(wilsonPassRateInterval(successes: 0, samples: 0), isNull);
  });

  test('Wilson interval has width for all failures and all passes', () {
    final allFail = wilsonPassRateInterval(successes: 0, samples: 10)!;
    final allPass = wilsonPassRateInterval(successes: 10, samples: 10)!;

    expect(allFail.lower, 0);
    expect(allFail.upper, greaterThan(0));
    expect(allPass.lower, lessThan(1));
    expect(allPass.upper, 1);
  });

  test('Wilson interval computes the 95 percent midpoint case', () {
    final interval = wilsonPassRateInterval(successes: 5, samples: 10)!;

    expect(interval.lower, closeTo(0.2366, 0.001));
    expect(interval.upper, closeTo(0.7634, 0.001));
    expect(interval.confidenceLevel, 0.95);
  });

  test('low sample threshold is below five samples', () {
    expect(isLowSample(0), isTrue);
    expect(isLowSample(1), isTrue);
    expect(isLowSample(4), isTrue);
    expect(isLowSample(5), isFalse);
  });
}
