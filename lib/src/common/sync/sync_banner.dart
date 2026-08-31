import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_providers.dart';

/// Faixa fina no topo das telas principais avisando sobre estado offline /
/// alterações pendentes. Some quando está tudo sincronizado.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(syncBannerProvider);
    if (message == null) return const SizedBox.shrink();

    final online = ref.watch(isOnlineProvider);
    final scheme = Theme.of(context).colorScheme;
    final bg = online ? scheme.secondaryContainer : scheme.errorContainer;
    final fg = online ? scheme.onSecondaryContainer : scheme.onErrorContainer;

    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(online ? Icons.sync : Icons.cloud_off, size: 16, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
