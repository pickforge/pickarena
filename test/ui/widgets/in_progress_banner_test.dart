import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/in_progress_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Run _r(String id, {DateTime? completedAt}) => Run(
      id: id,
      startedAt: DateTime(2026, 5, 3),
      completedAt: completedAt,
      judgeModel: null,
      name: id,
    );

void main() {
  testWidgets('renders when one in-flight run is provided', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InProgressBanner(
          inFlight: [_r('a')],
          onTap: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('a'), findsOneWidget);
  });

  testWidgets('shows count badge when multiple are in flight', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InProgressBanner(
          inFlight: [_r('a'), _r('b'), _r('c')],
          onTap: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('3 runs'), findsOneWidget);
  });

  testWidgets('renders nothing when inFlight is empty', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InProgressBanner(inFlight: const [], onTap: (_) {}),
      ),
    ));
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('tapping calls onTap with the most-recent run', (tester) async {
    String? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InProgressBanner(
          inFlight: [_r('a'), _r('b')],
          onTap: (r) => tapped = r.id,
        ),
      ),
    ));
    await tester.tap(find.byType(ListTile));
    await tester.pump();
    expect(tapped, isNotNull);
  });
}
