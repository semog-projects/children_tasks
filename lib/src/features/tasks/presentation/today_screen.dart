import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/child_avatar.dart';
import '../../../common/empty_hint.dart';
import '../../../common/spacing.dart';
import '../../../data/models/member.dart';
import '../../../data/models/task_instance.dart';
import '../../family/application/family_providers.dart';
import '../application/approval_providers.dart';
import '../application/task_instances_providers.dart';
import 'instance_tile.dart';

/// Tarefas de hoje, agrupadas por criança. O responsável vê e opera tudo aqui.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.onlyChildId});

  final String? onlyChildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(approvalControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Não foi possível atualizar a tarefa.')));
      }
    });

    final children = ref.watch(familyChildrenProvider).asData?.value ?? const [];
    final instances = ref.watch(todayInstancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tarefas de hoje')),
      body: instances.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Erro ao carregar')),
        data: (list) {
          final visibleChildren = onlyChildId == null
              ? children
              : children.where((c) => c.id == onlyChildId).toList();
          if (visibleChildren.isEmpty) {
            return const EmptyHint(
              icon: Icons.group_outlined,
              message: 'Nenhuma criança na família.',
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              for (final child in visibleChildren)
                _ChildSection(
                  child: child,
                  instances:
                      list.where((i) => i.memberId == child.id).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChildSection extends StatelessWidget {
  const _ChildSection({required this.child, required this.instances});

  final Member child;
  final List<TaskInstance> instances;

  @override
  Widget build(BuildContext context) {
    final done = instances.where((i) => i.isApproved).length;
    final total = instances.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: ChildAvatar(
            name: child.displayName,
            colorHex: child.avatarColor,
          ),
          title: Text(child.displayName),
          subtitle: total == 0
              ? const Text('Sem tarefas hoje')
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: done / total,
                      minHeight: 6,
                    ),
                  ),
                ),
          trailing: total == 0 ? null : Text('$done/$total'),
        ),
        for (final instance in instances)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: InstanceTile(instance: instance),
          ),
        const Divider(height: AppSpacing.lg),
      ],
    );
  }
}
