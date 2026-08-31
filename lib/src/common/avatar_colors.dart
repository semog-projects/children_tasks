import 'package:flutter/material.dart';

/// Paleta fixa para o avatar de cada criança. Guardado como hex `#RRGGBB`.
const List<String> avatarColorHexes = [
  '#EF5350', // vermelho
  '#EC407A', // rosa
  '#AB47BC', // roxo
  '#5C6BC0', // índigo
  '#42A5F5', // azul
  '#26A69A', // verde-água
  '#66BB6A', // verde
  '#FFA726', // laranja
  '#8D6E63', // marrom
];

const String defaultAvatarColorHex = '#42A5F5';

Color colorFromHex(String? hex) {
  final value = (hex ?? defaultAvatarColorHex).replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return const Color(0xFF42A5F5);
  return Color(0xFF000000 | parsed);
}
