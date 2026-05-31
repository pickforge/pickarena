import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/recent_runs_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Run _r(String id) => Run(
  id: id,
  startedAt: DateTime(2026, 5, 3),
  completedAt: DateTime(2026, 5, 3, 0, 5),
  judgeModel: null,
  name: id,
);

void main() {
  testWidgets('shows up to 5 rows even when more are provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentRunsStrip(
            runs: [
              for (var i = 0; i < 8; i++) (_r('run-$i'), const <TaskRun>[]),
            ],
            onTapRow: (_) {},
            onViewAll: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('run-'), findsNWidgets(5));
  });

  testWidgets('shows empty-state message when runs is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentRunsStrip(
            runs: const [],
            onTapRow: (_) {},
            onViewAll: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('No runs yet'), findsOneWidget);
  });

  testWidgets('tapping View all triggers onViewAll', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentRunsStrip(
            runs: [(_r('a'), const <TaskRun>[])],
            onTapRow: (_) {},
            onViewAll: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('View all'));
    expect(taps, 1);
  });
}
