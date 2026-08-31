import 'package:flutter/material.dart';

/// Tema visual do app. Um único _seed_ gera as variantes clara e escura,
/// mantendo a identidade consistente entre os modos responsável e criança.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF4C6FFF);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}
