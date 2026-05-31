import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/ui/widgets/showcase_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders category, model, and score', (tester) async {
    const ranking = ModelRanking(
      providerId: 'openai',
      modelId: 'gpt-5',
      dimensions: Dimensions(
        intelligence: 0.9,
        speed: 0.6,
        elegance: 0.7,
        reliability: 1.0,
        problems: 0,
      ),
      taskRunCount: 3,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 220,
            child: ShowcaseCard(
              category: Category.bugFix,
              top: ranking,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Bug fix'), findsOneWidget);
    expect(find.text('gpt-5'), findsOneWidget);
    expect(find.textContaining('0.80'), findsOneWidget);
  });

  testWidgets('renders empty placeholder when top is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 220,
            child: ShowcaseCard(
              category: Category.bugFix,
              top: null,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('No data'), findsOneWidget);
  });

  testWidgets('tapping invokes onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShowcaseCard(
            category: Category.bugFix,
            top: null,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
