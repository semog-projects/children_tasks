import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/child_avatar.dart';
import '../../../common/spacing.dart';
import '../../../common/sync/sync_banner.dart';
import '../../auth/application/auth_providers.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../family/application/family_providers.dart';
import '../../family/presentation/family_screen.dart';
import '../../points/application/points_providers.dart';
import '../../rewards/presentation/catalog_screen.dart';
import '../../rewards/presentation/rewards_screen.dart';
import '../../tasks/application/approval_providers.dart';
import '../../tasks/application/task_instances_providers.dart';
import '../../tasks/presentation/approvals_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../../tasks/presentation/today_screen.dart';

enum _HomeMenu { tasks, rewards, dashboard, family, signOut }

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// Tela inicial do responsável: crianças, tarefas de hoje e aprovações.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _onMenu(BuildContext context, WidgetRef ref, _HomeMenu item) {
    final nav = Navigator.of(context);
    switch (item) {
      case _HomeMenu.tasks:
        nav.push(MaterialPageRoute<void>(builder: (_) => const TasksScreen()));
      case _HomeMenu.rewards:
        nav.push(MaterialPageRoute<void>(builder: (_) => const RewardsScreen()));
      case _HomeMenu.dashboard:
        nav.push(
            MaterialPageRoute<void>(builder: (_) => const DashboardScreen()));
      case _HomeMenu.family:
        nav.push(MaterialPageRoute<void>(builder: (_) => const FamilyScreen()));
      case _HomeMenu.signOut:
        ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider).asData?.value;
    final children = ref.watch(familyChildrenProvider);
    final pendingCount = ref.watch(pendingApprovalsProvider).asData?.value.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          family?.name ?? 'Tarefas das Crianças',
          overflow: TextOverflow.ellipsis,
        ),
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
          PopupMenuButton<_HomeMenu>(
            tooltip: 'Mais',
            onSelected: (item) => _onMenu(context, ref, item),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _HomeMenu.tasks,
                child: _MenuRow(Icons.checklist_rounded, 'Definição de tarefas'),
              ),
              PopupMenuItem(
                value: _HomeMenu.rewards,
                child: _MenuRow(Icons.card_giftcard, 'Recompensas'),
              ),
              PopupMenuItem(
                value: _HomeMenu.dashboard,
                child: _MenuRow(Icons.insights, 'Painel'),
              ),
              PopupMenuItem(
                value: _HomeMenu.family,
                child: _MenuRow(Icons.group, 'Família'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _HomeMenu.signOut,
                child: _MenuRow(Icons.logout, 'Sair da conta'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: children.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const Center(child: Text('Erro ao carregar a família')),
                  data: (list) => ListView(
                    padding: AppSpacing.screen,
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
                        const Gap.md(),
                        Text('Crianças', style: Theme.of(context).textTheme.titleMedium),
                        const Gap.sm(),
                        for (final child in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _ChildCard(
                              childId: child.id,
                              name: child.displayName,
                              colorHex: child.avatarColor,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => TodayScreen(onlyChildId: childId)),
        ),
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChildAvatar(name: name, colorHex: colorHex),
                  const Gap.sm(),
                  Expanded(
                    child: Text(name, style: theme.textTheme.titleMedium),
                  ),
                  if (balance != null)
                    Text('$balance pts', style: theme.textTheme.titleMedium),
                  IconButton(
                    tooltip: 'Recompensas de $name',
                    icon: const Icon(Icons.card_giftcard),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CatalogScreen(memberId: childId, childName: name),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap.xs(),
              if (total != null && total > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (done ?? 0) / total,
                    minHeight: 6,
                  ),
                ),
                const Gap.xs(),
              ],
              Text(
                total == null
                    ? '…'
                    : total == 0
                        ? 'Sem tarefas hoje'
                        : '$done de $total tarefas hoje',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
