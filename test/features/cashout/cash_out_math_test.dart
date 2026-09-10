import 'package:childrentasks/src/features/cashout/domain/cash_out_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('snapPoints', () {
    test('arredonda para o múltiplo de 5 mais próximo', () {
      expect(snapPoints(0), 0);
      expect(snapPoints(1), 5);
      expect(snapPoints(7), 5);
      expect(snapPoints(8), 10);
      expect(snapPoints(122), 120);
      expect(snapPoints(123), 125);
    });

    test('nunca devolve negativo', () {
      expect(snapPoints(-10), 0);
    });
  });

  group('pointsForCents (cotação padrão 1.6 c/ponto)', () {
    test('R\$ 2,00 = 125 pontos', () {
      expect(pointsForCents(200, 1.6), 125);
    });

    test('R\$ 1,00 ≈ 62,5 pts → snap para 65', () {
      expect(pointsForCents(100, 1.6), 65);
    });

    test('valor zero ou cotação inválida → 0', () {
      expect(pointsForCents(0, 1.6), 0);
      expect(pointsForCents(200, 0), 0);
    });
  });

  group('centsForPoints', () {
    test('125 pts * 1.6 = 200 centavos', () {
      expect(centsForPoints(125, 1.6), 200);
    });

    test('cotação diferente (1 centavo/ponto)', () {
      expect(centsForPoints(300, 1.0), 300);
      expect(pointsForCents(305, 1.0), 305);
    });

    test('arredonda para centavo inteiro', () {
      expect(centsForPoints(5, 1.6), 8);
    });
  });

  test('formatBrlCents', () {
    expect(formatBrlCents(0), r'R$ 0,00');
    expect(formatBrlCents(8), r'R$ 0,08');
    expect(formatBrlCents(320), r'R$ 3,20');
    expect(formatBrlCents(1005), r'R$ 10,05');
  });
}
