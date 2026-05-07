import 'package:dart_arena/analytics/leaderboard_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PerTaskBarChart extends StatelessWidget {
  const PerTaskBarChart({super.key, required this.scores, required this.onTap});

  final List<PerTaskScore> scores;
  final void Function(PerTaskScore) onTap;

  Color _tint(double v) {
    if (v >= 0.8) return Colors.green.shade700;
    if (v >= 0.5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const Center(child: Text('No task data for this filter.'));
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.0,
          minY: 0.0,
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (event is FlTapUpEvent) {
                final spot = response?.spot;
                if (spot == null) return;
                onTap(scores[spot.touchedBarGroupIndex]);
              }
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= scores.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      scores[i].taskId.split('.').last,
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barGroups: [
            for (var i = 0; i < scores.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: scores[i].aggregateScore,
                    color: _tint(scores[i].aggregateScore),
                    width: 16,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
