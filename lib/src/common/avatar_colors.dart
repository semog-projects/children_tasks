import 'package:flutter/material.dart';

/// Paleta fixa para o avatar de cada criança. Guardada como hex `#RRGGBB`.
/// As cores são escolhidas para ter contraste suficiente com texto branco
/// **ou** preto — use [onAvatarColor] para o texto/ícone por cima.
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

const Color _fallbackAvatarColor = Color(0xFF42A5F5);

Color colorFromHex(String? hex) {
  final value = (hex ?? defaultAvatarColorHex).replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return _fallbackAvatarColor;
  return Color(0xFF000000 | parsed);
}

/// Cor legível (preto ou branco) para texto/ícone sobre [background].
Color onAvatarColor(Color background) =>
    background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

/// Atalho: cor de contraste para o hex de avatar informado.
Color onAvatarColorHex(String? hex) => onAvatarColor(colorFromHex(hex));
