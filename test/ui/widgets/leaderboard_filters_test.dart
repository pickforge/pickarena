import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_filter.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/ui/widgets/leaderboard_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('emits new filter when dimension is changed', (tester) async {
    LeaderboardFilter? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LeaderboardFilters(
          filter: const LeaderboardFilter(),
          providerOptions: const ['openai', 'anthropic'],
          onChanged: (f) => captured = f,
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('dim-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speed').last);
    await tester.pumpAndSettle();
    expect(captured?.dimension, ScoreDimension.speed);
  });

  testWidgets('emits new filter when category is set then cleared',
      (tester) async {
    LeaderboardFilter? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return LeaderboardFilters(
            filter: captured ?? const LeaderboardFilter(),
            providerOptions: const ['openai'],
            onChanged: (f) => setState(() => captured = f),
          );
        }),
      ),
    ));
    await tester.tap(find.byKey(const Key('category-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bug fix').last);
    await tester.pumpAndSettle();
    expect(captured?.category, Category.bugFix);
  });

  testWidgets('emits new filter when last 7d chip is tapped', (tester) async {
    LeaderboardFilter? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LeaderboardFilters(
          filter: const LeaderboardFilter(),
          providerOptions: const [],
          onChanged: (f) => captured = f,
        ),
      ),
    ));
    await tester.tap(find.text('7d'));
    await tester.pumpAndSettle();
    expect(captured?.dateRange, DateRange.last7d);
  });
}
