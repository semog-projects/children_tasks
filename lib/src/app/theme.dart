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

  /// Família de fonte do app (ver `pubspec.yaml` e `assets/fonts/`).
  static const String fontFamily = 'Nunito';

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    // Esquema padrão do Material 3 (tonalSpot) — melhor contraste dos neutros
    // (`onSurfaceVariant` etc.) que as variantes mais coloridas.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final shapeSm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
    );

    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: _textTheme(brightness),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        scrolledUnderElevation: 2,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerLow,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
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

  /// Escala tipográfica: parte da base do Material 3 e reforça a hierarquia —
  /// títulos mais encorpados (Nunito fica bem em peso alto) e corpo um pouco
  /// maior para leitura confortável, inclusive nas telas da criança.
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;

    return base
        .apply(
          fontFamily: fontFamily,
          bodyColor: base.bodyMedium?.color,
          displayColor: base.bodyMedium?.color,
        )
        .copyWith(
          headlineSmall: base.headlineSmall?.copyWith(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w800,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.bodyLarge?.copyWith(fontFamily: fontFamily, fontSize: 16, height: 1.4),
          bodyMedium: base.bodyMedium?.copyWith(fontFamily: fontFamily, fontSize: 15, height: 1.4),
          labelLarge: base.labelLarge?.copyWith(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        );
  }
}
