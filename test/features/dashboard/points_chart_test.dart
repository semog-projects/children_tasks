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

  group('chartDateLabelIndices (#79 — datas coladas)', () {
    test('14 dias (caso real do painel): no máximo 5, nunca duas seguidas', () {
      final idx = chartDateLabelIndices(14).toList()..sort();
      expect(idx.length, lessThanOrEqualTo(5));
      expect(idx.first, 0);
      expect(idx.last, 13);
      for (var i = 1; i < idx.length; i++) {
        expect(idx[i] - idx[i - 1], greaterThan(1),
            reason: 'índices $idx têm vizinhos colados');
      }
    });

    test('poucos dias: mostra todos (sem por que reduzir)', () {
      expect(chartDateLabelIndices(3), {0, 1, 2});
      expect(chartDateLabelIndices(1), {0});
      expect(chartDateLabelIndices(0), isEmpty);
    });

    test('qualquer tamanho: no máximo 5 rótulos, sem vizinhos colados', () {
      for (final length in [6, 7, 8, 9, 10, 13, 14, 20, 30, 100]) {
        final idx = chartDateLabelIndices(length).toList()..sort();
        expect(idx.length, lessThanOrEqualTo(5));
        expect(idx.first, 0);
        expect(idx.last, length - 1);
        for (var i = 1; i < idx.length; i++) {
          expect(idx[i] - idx[i - 1], greaterThan(1));
        }
      }
    });
  });

  group('formatChartAxisValue (#79 — números sobrepondo)', () {
    test('abaixo de mil: número cru', () {
      expect(formatChartAxisValue(0), '0');
      expect(formatChartAxisValue(23), '23');
      expect(formatChartAxisValue(999), '999');
    });

    test('milhares: compacta com "mil"', () {
      expect(formatChartAxisValue(1000), '1 mil');
      expect(formatChartAxisValue(1200), '1,2 mil');
      expect(formatChartAxisValue(45000), '45 mil');
    });

    test('milhões: compacta com "mi"', () {
      expect(formatChartAxisValue(1000000), '1 mi');
      expect(formatChartAxisValue(3400000), '3,4 mi');
    });

    test('nunca passa de ~7 caracteres (cabe no eixo)', () {
      for (final v in [999, 999999, 999999999]) {
        expect(formatChartAxisValue(v).length, lessThanOrEqualTo(7));
      }
    });
  });
}
