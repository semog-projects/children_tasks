import 'package:childrentasks/src/features/investment/domain/investment_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weeksBetween: frações e negativo', () {
    final t0 = DateTime(2026, 1, 1);
    expect(weeksBetween(t0, t0.add(const Duration(days: 7))), 1.0);
    expect(weeksBetween(t0, t0.add(const Duration(days: 14))), 2.0);
    expect(weeksBetween(t0, t0.subtract(const Duration(days: 3))), 0);
  });

  group('grossYield (juros compostos)', () {
    test('2%/semana por 1 semana = 2 pts sobre 100', () {
      expect(grossYield(100, 1, 2), 2);
    });

    test('2%/semana por 4 semanas compõe (> 8)', () {
      // 100 * 1.02^4 ≈ 108.24 -> 8
      expect(grossYield(100, 4, 2), 8);
    });

    test('2%/semana por 52 semanas ≈ +181%', () {
      // 1000 * 1.02^52 ≈ 2800 -> ~1800 de rendimento
      final y = grossYield(1000, 52, 2);
      expect(y, greaterThan(1700));
      expect(y, lessThan(1900));
    });

    test('entradas inválidas -> 0', () {
      expect(grossYield(0, 5, 2), 0);
      expect(grossYield(100, 0, 2), 0);
      expect(grossYield(100, 5, 0), 0);
    });
  });

  group('netYield: carência', () {
    final since = DateTime(2026, 1, 1);
    test('antes da carência paga metade', () {
      final now = since.add(const Duration(days: 3)); // < 7
      final gross = grossYield(100, weeksBetween(since, now), 2);
      expect(netYield(100, since, now, 2, 7), (gross * 0.5).round());
    });

    test('depois da carência paga cheio', () {
      final now = since.add(const Duration(days: 21)); // >= 7
      final gross = grossYield(100, weeksBetween(since, now), 2);
      expect(netYield(100, since, now, 2, 7), gross);
    });
  });

  test('payoutNow soma principal + rendimento líquido de cada lote', () {
    final now = DateTime(2026, 2, 1);
    final lots = <InvestmentLotValue>[
      (points: 300, since: now.subtract(const Duration(days: 40))), // fora da carência
      (points: 500, since: now.subtract(const Duration(days: 5))), // dentro
    ];
    expect(principalOf(lots), 800);

    final expected = 300 +
        netYield(300, lots[0].since, now, 2, 7) +
        500 +
        netYield(500, lots[1].since, now, 2, 7);
    expect(payoutNow(lots, now, 2, 7), expected);
    expect(payoutNow(lots, now, 2, 7), greaterThan(800));

    // o lote recente (na carência) rende metade do bruto
    final gross1 = grossYield(500, weeksBetween(lots[1].since, now), 2);
    expect(netYield(500, lots[1].since, now, 2, 7), (gross1 * 0.5).round());
  });

  test('projectedTotal soma principal + rendimento cheio', () {
    expect(projectedTotal(100, 1, 2), 100 + grossYield(100, 1, 2));
  });
}
