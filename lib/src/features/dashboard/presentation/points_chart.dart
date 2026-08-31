import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../common/avatar_colors.dart';
import '../../../data/models/member.dart';
import '../application/dashboard_providers.dart';

/// Barras empilhadas: pontos ganhos por dia (14 dias), um segmento por criança
/// na cor do avatar dela. Uma medida, um eixo.
class PointsChart extends StatelessWidget {
  const PointsChart({super.key, required this.days, required this.children});

  final List<DayEarnings> days;
  final List<Member> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = days.fold<int>(0, (m, d) => d.total > m ? d.total : m);
    final axisMax = (maxY <= 0 ? 10 : ((maxY / 10).ceil() * 10)).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pontos ganhos por dia', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: axisMax,
              alignment: BarChartAlignment.spaceBetween,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    '${rod.toY.round()} pts',
                    theme.textTheme.labelMedium ?? const TextStyle(),
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: axisMax / 2,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outlineVariant,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: axisMax / 2,
                    getTitlesWidget: (value, meta) => Text(
                      value.round().toString(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox.shrink();
                      // rótulo só a cada 3 dias, pra não amontoar
                      if (i % 3 != 0 && i != days.length - 1) {
                        return const SizedBox.shrink();
                      }
                      final d = days[i].date;
                      return Text(
                        '${d.day}/${d.month}',
                        style: theme.textTheme.bodySmall,
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [_rod(days[i])],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final child in children)
              _LegendDot(color: colorFromHex(child.avatarColor), label: child.displayName),
          ],
        ),
      ],
    );
  }

  BarChartRodData _rod(DayEarnings day) {
    // Gap de 2px entre segmentos empilhados (spec dataviz).
    const gap = 2.0;
    final visible = [
      for (final child in children)
        if ((day.byChild[child.id] ?? 0) > 0) child,
    ];
    final segments = <BarChartRodStackItem>[];
    var from = 0.0;
    for (var i = 0; i < visible.length; i++) {
      final v = day.byChild[visible[i].id]!.toDouble();
      final start = i == 0 ? from : from + gap;
      segments.add(
        BarChartRodStackItem(start, start + v, colorFromHex(visible[i].avatarColor)),
      );
      from = start + v;
    }
    return BarChartRodData(
      toY: from,
      width: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      rodStackItems: segments,
      color: Colors.transparent,
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
