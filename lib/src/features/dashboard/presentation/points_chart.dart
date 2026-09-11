import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../common/avatar_colors.dart';
import '../../../data/models/member.dart';
import '../application/dashboard_providers.dart';

/// No máximo quantos rótulos de data aparecem no eixo X, não importa quantos
/// dias existam — o resto some pra não amontoar.
const int _maxDateLabels = 5;

/// Formata um total de pontos pro eixo Y sem estourar a largura reservada:
/// `999`, `1,2 mil`, `12 mil`, `3,4 mi`.
String formatChartAxisValue(int value) {
  final v = value.abs();
  if (v < 1000) return value.toString();

  double scaled;
  String suffix;
  if (v >= 1000000000) {
    scaled = v / 1000000000;
    suffix = 'bi';
  } else if (v >= 1000000) {
    scaled = v / 1000000;
    suffix = 'mi';
  } else {
    scaled = v / 1000;
    suffix = 'mil';
  }

  var rounded = (scaled * 10).round() / 10;
  // Arredondar pode "carregar" pro próximo patamar (ex.: 999999 -> 1000 mil,
  // que devia virar 1 mi).
  if (suffix == 'mil' && rounded >= 1000) {
    rounded /= 1000;
    suffix = 'mi';
  } else if (suffix == 'mi' && rounded >= 1000) {
    rounded /= 1000;
    suffix = 'bi';
  }

  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
  return '$text $suffix';
}

/// Índices (de 0 a [length] - 1) a rotular no eixo X: no máximo
/// [_maxDateLabels], espaçados o mais uniformemente possível, sempre
/// incluindo o primeiro e o último — nunca dois adjacentes (o que colava as
/// datas quando `length` não era múltiplo do passo fixo antigo).
///
/// Com poucos dias (`length <= _maxDateLabels`) mostra todos: não há
/// amontoamento pra evitar. Do contrário, reduz também a contagem de
/// rótulos (não só o espaçamento) quando `length` é pequeno demais pra
/// [_maxDateLabels] rótulos com vão mínimo de 2 entre eles.
Set<int> chartDateLabelIndices(int length) {
  if (length <= 0) return const {};
  if (length <= _maxDateLabels) {
    return {for (var i = 0; i < length; i++) i};
  }
  final maxByGap = ((length - 1) ~/ 2) + 1;
  final count = maxByGap < _maxDateLabels ? maxByGap : _maxDateLabels;
  return {
    for (var k = 0; k < count; k++) (k * (length - 1) / (count - 1)).round(),
  };
}

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
    // O rótulo do eixo Y no topo (axisMax) é centralizado pelo fl_chart sobre
    // a própria linha de grade — sem folga, metade do texto desenha acima do
    // limite do gráfico e sobrepõe o título. `maxY` maior que `axisMax`
    // empurra essa linha/rótulo pra baixo do topo, sem mudar os valores
    // mostrados (grade/rótulos continuam calculados a partir de `axisMax`).
    final chartMaxY = axisMax * 1.2;
    final dateLabelIndices = chartDateLabelIndices(days.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pontos ganhos por dia', style: theme.textTheme.titleSmall),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: chartMaxY,
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
                    reservedSize: 40,
                    interval: axisMax / 2,
                    getTitlesWidget: (value, meta) => Text(
                      formatChartAxisValue(value.round()),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
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
                      if (!dateLabelIndices.contains(i)) {
                        return const SizedBox.shrink();
                      }
                      final d = days[i].date;
                      return Text(
                        '${d.day}/${d.month}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
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
