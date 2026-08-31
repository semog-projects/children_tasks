import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/avatar_colors.dart';
import '../../family/application/family_providers.dart';
import '../../family/presentation/family_screen.dart';
import '../../points/application/points_providers.dart';
import '../../profiles/application/profile_providers.dart';
import '../../rewards/presentation/catalog_screen.dart';
import '../../rewards/presentation/rewards_screen.dart';
import '../../tasks/application/approval_providers.dart';
import '../../tasks/application/task_instances_providers.dart';
import '../../tasks/presentation/approvals_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../../tasks/presentation/today_screen.dart';

/// Tela inicial do responsável: crianças, tarefas de hoje e aprovações.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider).asData?.value;
    final children = ref.watch(familyChildrenProvider);
    final pendingCount = ref.watch(pendingApprovalsProvider).asData?.value.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(family?.name ?? 'Tarefas das Crianças'),
        actions: [
          IconButton(
            tooltip: 'Aprovações',
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.rule),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ApprovalsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Definição de tarefas',
            icon: const Icon(Icons.checklist_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TasksScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Recompensas',
            icon: const Icon(Icons.card_giftcard),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RewardsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Família',
            icon: const Icon(Icons.group),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FamilyScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Trocar de perfil',
            icon: const Icon(Icons.switch_account),
            onPressed: () =>
                ref.read(activeProfileProvider.notifier).backToSelector(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: children.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(child: Text('Erro ao carregar a família')),
            data: (list) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (list.isEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.child_care),
                      title: const Text('Adicione as crianças da família'),
                      subtitle: const Text('Toque para abrir a gestão da família.'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const FamilyScreen()),
                      ),
                    ),
                  )
                else ...[
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const TodayScreen()),
                    ),
                    icon: const Icon(Icons.today),
                    label: const Text('Tarefas de hoje'),
                  ),
                  const SizedBox(height: 16),
                  Text('Crianças', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final child in list)
                    _ChildCard(
                      childId: child.id,
                      name: child.displayName,
                      colorHex: child.avatarColor,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.childId, required this.name, this.colorHex});

  final String childId;
  final String name;
  final String? colorHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instances = ref.watch(childTodayInstancesProvider(childId)).asData?.value;
    final balance = ref.watch(childBalanceProvider(childId)).asData?.value;

    final done = instances?.where((i) => i.isApproved).length;
    final total = instances?.length;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorFromHex(colorHex),
          child: Text(
            name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(name),
        subtitle: Text(
          total == null
              ? '…'
              : total == 0
                  ? 'Sem tarefas hoje'
                  : '$done de $total tarefas hoje',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (balance != null)
              Text('$balance pts', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              tooltip: 'Recompensas de $name',
              icon: const Icon(Icons.card_giftcard),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CatalogScreen(memberId: childId, childName: name),
                ),
              ),
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TodayScreen(onlyChildId: childId)),
        ),
      ),
    );
  }
}
