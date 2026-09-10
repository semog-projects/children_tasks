/// Conversões do câmbio de pontos ↔ dinheiro (issue #66). A troca é sempre
/// em **múltiplos de 5 pontos** (5 pts = R$ 0,08 na cotação padrão), para o
/// valor em centavos nunca cair numa fração.
library;

/// Múltiplo usado no arredondamento dos pontos.
const int cashOutPointsStep = 5;

/// Arredonda [rawPoints] para o múltiplo de [cashOutPointsStep] mais próximo.
/// Nunca devolve valor negativo; devolve 0 só quando [rawPoints] <= 0.
int snapPoints(int rawPoints) {
  if (rawPoints <= 0) return 0;
  final snapped = ((rawPoints / cashOutPointsStep).round()) * cashOutPointsStep;
  return snapped < cashOutPointsStep ? cashOutPointsStep : snapped;
}

/// Quantos pontos (múltiplo de 5) correspondem a [wantCents] centavos de BRL,
/// dada a cotação [rateCents] (centavos por ponto).
int pointsForCents(int wantCents, double rateCents) {
  if (wantCents <= 0 || rateCents <= 0) return 0;
  return snapPoints((wantCents / rateCents).round());
}

/// Valor em centavos de BRL de [points] pontos, dada a cotação [rateCents].
int centsForPoints(int points, double rateCents) {
  if (points <= 0 || rateCents <= 0) return 0;
  return (points * rateCents).round();
}

/// Formata centavos como `R$ 3,20`.
String formatBrlCents(int cents) {
  final reais = cents ~/ 100;
  final rest = (cents % 100).toString().padLeft(2, '0');
  return 'R\$ $reais,$rest';
}

/// Lê os centavos de um texto de campo de moeda (`R$ 2,00`, `200`, `2,00` → 200).
int centsFromText(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}
