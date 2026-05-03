import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/ui/widgets/dimension_radar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sample = Dimensions(
    intelligence: 0.8,
    speed: 0.6,
    elegance: 0.4,
    reliability: 1.0,
    problems: 0,
  );

  testWidgets('renders a RadarChart with the four dimension labels',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: DimensionRadar(selected: sample, selectedLabel: 'gpt-5'),
        ),
      ),
    ));
    expect(find.byType(RadarChart), findsOneWidget);
    final chart = tester.widget<RadarChart>(find.byType(RadarChart));
    expect(chart.data.getTitle!(0, 0).text, 'Intelligence');
    expect(chart.data.getTitle!(1, 0).text, 'Speed');
    expect(chart.data.getTitle!(2, 0).text, 'Elegance');
    expect(chart.data.getTitle!(3, 0).text, 'Reliability');
  });

  testWidgets('renders an overlay polygon when pinned is provided',
      (tester) async {
    const pinned = Dimensions(
      intelligence: 0.5,
      speed: 0.5,
      elegance: 0.5,
      reliability: 0.5,
      problems: 0,
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: DimensionRadar(
            selected: sample,
            pinned: pinned,
            selectedLabel: 'gpt-5',
            pinnedLabel: 'opus',
          ),
        ),
      ),
    ));
    final chart = tester.widget<RadarChart>(find.byType(RadarChart));
    expect(chart.data.dataSets.length, 2);
  });
}
