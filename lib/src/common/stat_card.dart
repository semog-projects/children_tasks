import 'package:flutter/material.dart';

import 'spacing.dart';

/// Card de destaque para um número (saldo de pontos, total…), no tom
/// `primaryContainer`. Opcionalmente com uma barra de progresso.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.progress,
  });

  final IconData icon;
  final String value;
  final String label;

  /// 0..1 — quando presente, mostra uma barra de progresso abaixo.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.onPrimaryContainer),
                const Gap.sm(),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const Gap.xs(),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            if (progress != null) ...[
              const Gap.sm(),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  backgroundColor: scheme.onPrimaryContainer.withValues(alpha: 0.15),
                  color: scheme.onPrimaryContainer,
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
