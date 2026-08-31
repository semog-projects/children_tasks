import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: theme.colorScheme.primaryContainer,
                        child: ListTile(
                          leading: const Icon(Icons.stars_rounded),
                          title: Text('$balance pontos',
                              style: theme.textTheme.titleLarge),
                          subtitle: Text(
                            list.isEmpty
                                ? 'Nenhuma tarefa hoje'
                                : '$done de ${list.length} tarefas de hoje',
                          ),
                        ),
                      ),
                      const _NextRewardCard(),
                      const SizedBox(height: 8),
                      for (final instance in list)
                        InstanceTile(instance: instance, childMode: true),
                      if (list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Aproveite o dia! 🎉',
                              textAlign: TextAlign.center),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próxima recompensa',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(next.reward.title,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 6),
            Text('Faltam ${next.missing} pontos',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
