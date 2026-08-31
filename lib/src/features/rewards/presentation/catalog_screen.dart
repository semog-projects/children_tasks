import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/sync/sync_providers.dart';
import '../../../data/models/redemption.dart';
import '../../../data/models/reward.dart';
import '../../points/application/points_providers.dart';
import '../application/reward_providers.dart';

/// Catálogo de recompensas de uma criança: o que dá pra resgatar com o saldo,
/// mais o histórico de resgates. Enquanto não há "modo criança" (#8), o
/// responsável opera aqui.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({
    super.key,
    required this.memberId,
    required this.childName,
    this.childMode = false,
  });

  final String memberId;
  final String childName;

  /// No modo criança some o botão "Entregar".
  final bool childMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(redemptionControllerProvider, (_, next) {
      final error = next.error;
      final messenger = ScaffoldMessenger.of(context);
      if (error is RedeemException) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      } else if (error != null && !next.isLoading) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Não foi possível resgatar.')));
      }
    });

    final balance = ref.watch(childBalanceProvider(memberId)).asData?.value ?? 0;
    final rewards = ref.watch(activeRewardsProvider);
    final redemptions = ref.watch(childRedemptionsProvider(memberId));
    final busy = ref.watch(redemptionControllerProvider).isLoading;
    final online = ref.watch(isOnlineProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Recompensas — $childName')),
      body: rewards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Erro ao carregar')),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              color: theme.colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.stars_rounded),
                title: Text('$balance pontos', style: theme.textTheme.titleLarge),
                subtitle: const Text('Saldo disponível'),
              ),
            ),
            if (!online)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'O resgate precisa de internet — tente de novo quando a conexão voltar.',
                ),
              ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhuma recompensa disponível.'),
              )
            else
              for (final reward in list)
                _RewardCard(
                  reward: reward,
                  affordable: online && balance >= reward.cost && reward.inStock,
                  busy: busy,
                  onRedeem: () => _confirmRedeem(context, ref, reward),
                ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Histórico', style: theme.textTheme.titleMedium),
            ),
            redemptions.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (history) => history.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nenhum resgate ainda.'),
                    )
                  : Column(
                      children: [
                        for (final r in history)
                          _RedemptionTile(redemption: r, childMode: childMode),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRedeem(
    BuildContext context,
    WidgetRef ref,
    Reward reward,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resgatar "${reward.title}"?'),
        content: Text('Vai custar ${reward.cost} pontos de $childName.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resgatar')),
        ],
      ),
    );
    if (ok ?? false) {
      await ref
          .read(redemptionControllerProvider.notifier)
          .redeem(rewardId: reward.id, memberId: memberId);
    }
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.affordable,
    required this.busy,
    required this.onRedeem,
  });

  final Reward reward;
  final bool affordable;
  final bool busy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(reward.title),
        subtitle: Text([
          '${reward.cost} pts',
          if (reward.stock != null) 'restam ${reward.stock}',
          if (reward.description != null) reward.description!,
        ].join(' · ')),
        trailing: FilledButton(
          onPressed: (affordable && !busy) ? onRedeem : null,
          child: const Text('Resgatar'),
        ),
      ),
    );
  }
}

class _RedemptionTile extends ConsumerWidget {
  const _RedemptionTile({required this.redemption, this.childMode = false});
  final Redemption redemption;
  final bool childMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        redemption.isDelivered ? Icons.check_circle : Icons.hourglass_top,
      ),
      title: Text(redemption.rewardTitleSnapshot),
      subtitle: Text(
        '${redemption.cost} pts · ${redemption.isDelivered ? 'entregue' : 'aguardando entrega'}',
      ),
      trailing: (redemption.isRequested && !childMode)
          ? TextButton(
              onPressed: () => ref
                  .read(redemptionControllerProvider.notifier)
                  .markDelivered(redemption.id),
              child: const Text('Entregar'),
            )
          : null,
    );
  }
}
