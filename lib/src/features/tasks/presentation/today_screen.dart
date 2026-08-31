import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/avatar_colors.dart';
import '../../../data/models/member.dart';
import '../../../data/models/task_instance.dart';
import '../../family/application/family_providers.dart';
import '../application/approval_providers.dart';
import '../application/task_instances_providers.dart';
import 'instance_tile.dart';

/// Tarefas de hoje, agrupadas por criança. Enquanto não existe "modo criança"
/// (issue #8), o responsável vê e opera tudo aqui.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.onlyChildId});

  final String? onlyChildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(approvalControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Não foi possível atualizar a tarefa.')));
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
            return const Center(child: Text('Nenhuma criança na família.'));
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final child in visibleChildren)
                _ChildSection(
                  child: child,
                  instances: list.where((i) => i.memberId == child.id).toList(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: colorFromHex(child.avatarColor),
            child: Text(
              child.displayName.isNotEmpty
                  ? child.displayName.characters.first.toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(child.displayName),
          subtitle: Text(
            instances.isEmpty ? 'Sem tarefas hoje' : '$done de ${instances.length} concluídas',
          ),
        ),
        for (final instance in instances)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: InstanceTile(instance: instance),
          ),
        const Divider(height: 24),
      ],
    );
  }
}
