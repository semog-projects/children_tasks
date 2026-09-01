import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/empty_hint.dart';
import '../../../common/spacing.dart';
import '../../../common/stat_card.dart';
import '../../../common/sync/sync_banner.dart';
import '../../auth/application/auth_providers.dart';
import '../../rewards/presentation/catalog_screen.dart';
import '../../tasks/presentation/instance_tile.dart';
import '../application/child_providers.dart';
import 'child_notifications_screen.dart';

/// Visão simplificada de uma criança logada com a própria conta: só as tarefas
/// de hoje dela e o catálogo de recompensas. Sem acesso a configurações da
/// família nem a outras crianças.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentChildMemberProvider);
    final name = me?.displayName ?? 'Criança';
    final balance = ref.watch(myChildBalanceProvider).asData?.value ?? 0;
    final instances = ref.watch(myChildInstancesProvider);
    final signingOut = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, $name!'),
        actions: [
          IconButton(
            tooltip: 'Recompensas',
            icon: const Icon(Icons.card_giftcard),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CatalogScreen(
                  memberId: memberId,
                  childName: name,
                  childMode: true,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notificações',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChildNotificationsScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout),
            onPressed: signingOut
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(children: [
        const SyncBanner(),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: instances.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Center(child: Text('Erro ao carregar')),
                data: (list) {
                  final done = list.where((i) => i.isApproved).length;
                  return ListView(
                    padding: AppSpacing.screen,
                    children: [
                      StatCard(
                        icon: Icons.stars_rounded,
                        value: '$balance pontos',
                        label: list.isEmpty
                            ? 'Nenhuma tarefa hoje'
                            : '$done de ${list.length} tarefas de hoje',
                        progress: list.isEmpty ? null : done / list.length,
                      ),
                      const Gap.sm(),
                      const _NextRewardCard(),
                      if (list.isNotEmpty) ...[
                        const Gap.md(),
                        Text('Tarefas de hoje',
                            style: theme.textTheme.titleMedium),
                        const Gap.sm(),
                        for (final instance in list)
                          InstanceTile(instance: instance, childMode: true),
                      ] else
                        const EmptyHint(
                          icon: Icons.celebration_rounded,
                          message: 'Aproveite o dia! 🎉',
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// "Próxima recompensa alcançável" — motiva a criança a juntar mais pontos.
class _NextRewardCard extends ConsumerWidget {
  const _NextRewardCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(myNextRewardProvider);
    if (next == null) return const SizedBox.shrink();
    final balance = ref.watch(myChildBalanceProvider).asData?.value ?? 0;
    final progress = next.reward.cost == 0 ? 1.0 : balance / next.reward.cost;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próxima recompensa', style: theme.textTheme.labelMedium),
            const Gap.xs(),
            Text(next.reward.title, style: theme.textTheme.titleMedium),
            const Gap.sm(),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
            const Gap.xs(),
            Text('Faltam ${next.missing} pontos',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
