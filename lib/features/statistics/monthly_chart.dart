import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../core/utils/statistics_calculator.dart';

class MonthlyChart extends StatelessWidget {
  final List<MonthlyStat> stats;

  const MonthlyChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = stats.fold<int>(
      0,
      (max, stat) => stat.total > max ? stat.total : max,
    );
    final safeMax = maxValue == 0 ? 1.0 : maxValue * 1.2;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: BarChart(
        BarChartData(
          maxY: safeMax.toDouble(),
          alignment: BarChartAlignment.spaceAround,
          barGroups: [
            for (var i = 0; i < stats.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: stats[i].total.toDouble(),
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
          ],
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= stats.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${stats[index].month}월'),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final stat = stats[group.x.toInt()];
                return BarTooltipItem(
                  '${stat.year}.${stat.month}\n${formatWon(stat.total)}',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
