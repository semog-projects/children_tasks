import 'package:flutter/material.dart';

/// Tema visual do app. Um único _seed_ gera as variantes clara e escura;
/// os temas de componente ficam todos aqui, para que as telas nunca
/// precisem hardcodar cor, raio de borda ou elevação.
abstract final class AppTheme {
  const AppTheme._();

  /// Cor-semente da identidade (um índigo amigável). Toda a paleta deriva daqui.
  static const Color seed = Color(0xFF4C6FFF);

  /// Raio de borda padrão de superfícies (cards, campos, botões grandes).
  static const double radius = 16;

  /// Raio menor, para itens de lista e chips.
  static const double radiusSm = 12;

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      // Paleta um pouco mais viva/colorida que o padrão — combina melhor com
      // o tom "família" do app, sem sair da harmonia do Material 3.
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final shapeSm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
    );

    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerLow,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: shape,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: shapeSm,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shapeSm,
      ),
      dialogTheme: DialogThemeData(shape: shape),
    );
  }
}
