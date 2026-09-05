import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/child_avatar.dart';
import '../../../common/pull_refresh.dart';
import '../../../data/models/member.dart';
import '../../family/application/family_providers.dart';
import '../../points/application/points_providers.dart';
import '../../tasks/application/task_instances_providers.dart';
import '../application/dashboard_providers.dart';
import 'history_screen.dart';
import 'points_chart.dart';

/// Painel do responsável: estado do dia de todas as crianças + pontos ao longo
/// dos dias.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(familyChildrenProvider).asData?.value ?? const [];
    final days = ref.watch(dailyEarningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel'),
        actions: [
          IconButton(
            tooltip: 'Histórico',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => pullRefresh(
          ref,
          invalidate: (r) {
            r.invalidate(familyChildrenProvider);
            r.invalidate(dailyEarningsProvider);
            r.invalidate(weekPointsProvider);
            r.invalidate(childBalanceProvider);
            r.invalidate(childTodayInstancesProvider);
          },
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            for (final child in children) _ChildSummary(child: child),
            const SizedBox(height: 16),
            if (children.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PointsChart(days: days, children: children),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChildSummary extends ConsumerWidget {
  const _ChildSummary({required this.child});
  final Member child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instances = ref.watch(childTodayInstancesProvider(child.id)).asData?.value ?? const [];
    final done = instances.where((i) => i.isApproved).length;
    final balance = ref.watch(childBalanceProvider(child.id)).asData?.value ?? 0;
    final week = ref.watch(weekPointsProvider(child.id));
    final theme = Theme.of(context);

    final rate = instances.isEmpty ? 0.0 : done / instances.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChildAvatar(
                  name: child.displayName,
                  colorHex: child.avatarColor,
                ),
                const SizedBox(width: 12),
                Text(child.displayName, style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('$balance pts', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: rate,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (instances.isEmpty)
                  'Sem tarefas hoje'
                else
                  '$done de ${instances.length} tarefas hoje',
                '+$week pts na semana',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
