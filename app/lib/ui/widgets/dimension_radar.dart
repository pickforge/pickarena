import 'package:dart_arena/analytics/dimensions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DimensionRadar extends StatelessWidget {
  const DimensionRadar({
    super.key,
    required this.selected,
    this.pinned,
    this.selectedLabel,
    this.pinnedLabel,
  });

  final Dimensions selected;
  final Dimensions? pinned;
  final String? selectedLabel;
  final String? pinnedLabel;

  static const _titles = ['Intelligence', 'Speed', 'Elegance', 'Reliability'];

  List<double> _values(Dimensions d) => [
    d.intelligence,
    d.speed,
    d.elegance,
    d.reliability,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dataSets = <RadarDataSet>[
      RadarDataSet(
        fillColor: scheme.primary.withValues(alpha: 0.4),
        borderColor: scheme.primary,
        entryRadius: 3,
        dataEntries: _values(
          selected,
        ).map((v) => RadarEntry(value: v)).toList(),
      ),
      if (pinned != null)
        RadarDataSet(
          fillColor: scheme.secondary.withValues(alpha: 0.25),
          borderColor: scheme.secondary,
          entryRadius: 3,
          dataEntries: _values(
            pinned!,
          ).map((v) => RadarEntry(value: v)).toList(),
        ),
    ];

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        tickCount: 4,
        ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
        radarBorderData: BorderSide(color: scheme.outlineVariant),
        gridBorderData: BorderSide(color: scheme.outlineVariant, width: 0.5),
        tickBorderData: BorderSide(color: scheme.outlineVariant, width: 0.5),
        titleTextStyle: Theme.of(context).textTheme.bodySmall,
        getTitle: (i, angle) => RadarChartTitle(text: _titles[i], angle: 0),
        dataSets: dataSets,
      ),
    );
  }
}
