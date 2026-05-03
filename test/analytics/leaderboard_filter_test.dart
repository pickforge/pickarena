import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/core/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default filter matches all data', () {
    const f = LeaderboardFilter();
    expect(f.category, isNull);
    expect(f.providerId, isNull);
    expect(f.dateRange, DateRange.allTime);
    expect(f.dimension, ScoreDimension.overall);
  });

  test('DateRange.last7d.from is 7 days before now', () {
    final now = DateTime(2026, 5, 3);
    expect(DateRange.last7d.fromForNow(now), DateTime(2026, 4, 26));
    expect(DateRange.last7d.toForNow(now), DateTime(2026, 5, 3));
  });

  test('DateRange.allTime has null bounds', () {
    expect(DateRange.allTime.fromForNow(DateTime.now()), isNull);
    expect(DateRange.allTime.toForNow(DateTime.now()), isNull);
  });

  test('DateRange.custom uses the configured bounds', () {
    final from = DateTime(2026, 4, 1);
    final to = DateTime(2026, 5, 1);
    final r = DateRange.custom(from: from, to: to);
    expect(r.fromForNow(DateTime.now()), from);
    expect(r.toForNow(DateTime.now()), to);
    expect(r.isCustom, isTrue);
  });

  test('LeaderboardFilter.copyWith preserves untouched fields', () {
    const f = LeaderboardFilter();
    final f2 = f.copyWith(category: Category.bugFix);
    expect(f2.category, Category.bugFix);
    expect(f2.providerId, isNull);
    expect(f2.dateRange, DateRange.allTime);
    expect(f2.dimension, ScoreDimension.overall);
  });
}
