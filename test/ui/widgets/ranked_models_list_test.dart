import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/ui/widgets/ranked_models_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ModelRanking _r(String model, double overall) => ModelRanking(
      providerId: 'p',
      modelId: model,
      dimensions: Dimensions(
        intelligence: overall,
        speed: overall,
        elegance: overall,
        reliability: overall,
        problems: 0,
      ),
      taskRunCount: 1,
    );

void main() {
  testWidgets('renders one row per ranking with rank index', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RankedModelsList(
          rankings: [_r('alpha', 0.9), _r('beta', 0.5)],
          dimension: ScoreDimension.overall,
          selectedKey: 'p:alpha',
          pinnedKey: null,
          onSelect: (_) {},
          onTogglePin: (_) {},
        ),
      ),
    ));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
  });

  testWidgets('shows score by current dimension', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RankedModelsList(
          rankings: [_r('alpha', 0.9)],
          dimension: ScoreDimension.intelligence,
          selectedKey: null,
          pinnedKey: null,
          onSelect: (_) {},
          onTogglePin: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('0.90'), findsOneWidget);
  });

  testWidgets('renders empty-state text when rankings is empty',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RankedModelsList(
          rankings: const [],
          dimension: ScoreDimension.overall,
          selectedKey: null,
          pinnedKey: null,
          onSelect: (_) {},
          onTogglePin: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('No models match'), findsOneWidget);
  });

  testWidgets('tapping a row calls onSelect with model key', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RankedModelsList(
          rankings: [_r('alpha', 0.9)],
          dimension: ScoreDimension.overall,
          selectedKey: null,
          pinnedKey: null,
          onSelect: (k) => selected = k,
          onTogglePin: (_) {},
        ),
      ),
    ));
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();
    expect(selected, 'p:alpha');
  });
}
