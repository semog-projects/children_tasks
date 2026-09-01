import 'package:flutter/widgets.dart';

/// Escala de espaçamento do app. Use no lugar de números soltos em
/// `SizedBox`/`EdgeInsets` para manter o ritmo vertical consistente.
abstract final class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Padding padrão de conteúdo de tela.
  static const EdgeInsets screen = EdgeInsets.all(lg);

  /// Padding padrão de conteúdo de card.
  static const EdgeInsets card = EdgeInsets.all(md);
}

/// Espaço fixo entre widgets de uma [Column]/[Row]. Mais legível que
/// `SizedBox(height: ...)` repetido.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  const Gap.xs({super.key}) : size = AppSpacing.xs;
  const Gap.sm({super.key}) : size = AppSpacing.sm;
  const Gap.md({super.key}) : size = AppSpacing.md;
  const Gap.lg({super.key}) : size = AppSpacing.lg;
  const Gap.xl({super.key}) : size = AppSpacing.xl;

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}
