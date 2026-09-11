/// Matemática da poupança (issue #73): juros compostos por semana, com carência.
///
/// A MESMA fórmula está em `functions/src/investment/yield.ts` — qualquer
/// mudança aqui precisa ser espelhada lá (a Cloud Function é a autoridade no
/// resgate; o app usa isto só para a projeção ao vivo).
library;

import 'dart:math' as math;

/// Fração do rendimento paga quando o aporte é resgatado antes da carência.
const double kEarlyYieldFactor = 0.5;

const int _weekSeconds = 7 * 24 * 3600;

/// Semanas (fracionárias) entre [from] e [to]. Negativo vira 0.
double weeksBetween(DateTime from, DateTime to) {
  final secs = to.difference(from).inSeconds;
  return secs <= 0 ? 0 : secs / _weekSeconds;
}

/// Rendimento bruto de um aporte de [principal] pontos que ficou [weeks]
/// semanas rendendo a [weeklyRatePct]% compostos por semana.
int grossYield(int principal, double weeks, double weeklyRatePct) {
  if (principal <= 0 || weeks <= 0 || weeklyRatePct <= 0) return 0;
  final r = weeklyRatePct / 100;
  final value = principal * math.pow(1 + r, weeks);
  return (value - principal).round();
}

/// Rendimento líquido de um aporte: cheio se já passou da carência
/// ([graceDays] dias desde [since]), metade se resgatado antes.
int netYield(
  int principal,
  DateTime since,
  DateTime now,
  double weeklyRatePct,
  int graceDays,
) {
  final gross = grossYield(principal, weeksBetween(since, now), weeklyRatePct);
  final pastGrace = !now.isBefore(since.add(Duration(days: graceDays)));
  return pastGrace ? gross : (gross * kEarlyYieldFactor).round();
}

/// Um aporte da poupança: quantos pontos e desde quando.
typedef InvestmentLotValue = ({int points, DateTime since});

/// Quanto a criança recebe ao resgatar a posição inteira agora.
int payoutNow(
  List<InvestmentLotValue> lots,
  DateTime now,
  double weeklyRatePct,
  int graceDays,
) {
  return lots.fold<int>(
    0,
    (sum, lot) =>
        sum +
        lot.points +
        netYield(lot.points, lot.since, now, weeklyRatePct, graceDays),
  );
}

/// Soma dos pontos investidos (principal, sem rendimento).
int principalOf(List<InvestmentLotValue> lots) =>
    lots.fold<int>(0, (sum, lot) => sum + lot.points);

/// Projeção do valor total de [principal] daqui a [weeksAhead] semanas,
/// com o rendimento cheio (para a tabela "1 semana / 1 mês / 3 meses").
int projectedTotal(int principal, double weeksAhead, double weeklyRatePct) =>
    principal + grossYield(principal, weeksAhead, weeklyRatePct);
