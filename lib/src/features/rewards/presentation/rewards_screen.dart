import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/reward_providers.dart';
import 'reward_form_screen.dart';

/// Gestão das recompensas (responsável).
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(allRewardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recompensas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RewardFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Recompensa'),
      ),
      body: rewards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Erro ao carregar')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Nenhuma recompensa ainda.\nUse o botão "Recompensa".'))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final reward = list[i];
                  return ListTile(
                    title: Text(reward.title),
                    subtitle: Text(
                      '${reward.cost} pts'
                      '${reward.stock != null ? ' · estoque ${reward.stock}' : ''}'
                      '${reward.active ? '' : ' · inativa'}',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RewardFormScreen(reward: reward),
                      ),
                    ),
                    trailing: Switch(
                      value: reward.active,
                      onChanged: (v) => ref
                          .read(rewardControllerProvider.notifier)
                          .setActive(reward, active: v),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
