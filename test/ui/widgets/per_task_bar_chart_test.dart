import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/ui/widgets/per_task_bar_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PerTaskScore _s(String taskId, double v, {Category? c}) => PerTaskScore(
      taskId: taskId,
      category: c,
      aggregateScore: v,
      lastRunId: 'r',
      lastTaskRunId: 'tr-$taskId',
    );

void main() {
  testWidgets('renders one bar per score', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: PerTaskBarChart(
            scores: [
              _s('a', 0.9),
              _s('b', 0.5),
              _s('c', 0.2),
            ],
            onTap: (_) {},
          ),
        ),
      ),
    ));
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.length, 3);
  });

  testWidgets('shows empty-state text when scores list is empty',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PerTaskBarChart(scores: const [], onTap: (_) {}),
      ),
    ));
    expect(find.textContaining('No task data'), findsOneWidget);
  });
}
