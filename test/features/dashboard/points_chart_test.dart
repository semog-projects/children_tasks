import 'package:childrentasks/src/features/dashboard/application/dashboard_providers.dart';
import 'package:childrentasks/src/features/dashboard/presentation/points_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'o topo do eixo Y fica acima de axisMax — o rótulo não encosta no título (#77)',
      (tester) async {
    final days = [
      DayEarnings(date: DateTime(2026, 1, 1), byChild: const {'m1': 23}),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PointsChart(days: days, children: const [])),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    // axisMax = ceil(23/10)*10 = 30 (mesma regra do widget).
    const axisMax = 30.0;
    expect(chart.data.maxY, greaterThan(axisMax));
    // headroom de ~20%, sem mudar os valores das linhas de grade.
    expect(chart.data.maxY, closeTo(axisMax * 1.2, 0.01));
  });

  testWidgets('sem dados, o eixo padrão (10) também tem folga', (tester) async {
    final days = [DayEarnings(date: DateTime(2026, 1, 1), byChild: const {})];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PointsChart(days: days, children: const [])),
      ),
    );

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.maxY, greaterThan(10));
  });
}
