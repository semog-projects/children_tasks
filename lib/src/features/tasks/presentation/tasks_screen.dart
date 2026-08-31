import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/category_style.dart';
import '../../../data/models/member.dart';
import '../../../data/models/task.dart';
import '../../family/application/family_providers.dart';
import '../application/task_providers.dart';
import 'task_form_screen.dart';

/// Lista de tarefas do responsável, com filtros e ações de CRUD.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    final tasks = ref.watch(visibleTasksProvider);
    final children = ref.watch(familyChildrenProvider).asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas'),
        actions: [
          IconButton(
            tooltip: filter.showArchived ? 'Ver ativas' : 'Ver arquivadas',
            icon: Icon(filter.showArchived ? Icons.inventory_2 : Icons.archive_outlined),
            onPressed: () => ref.read(taskFilterProvider.notifier).toggleArchived(),
          ),
        ],
      ),
      floatingActionButton: filter.showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TaskFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Tarefa'),
            ),
      body: Column(
        children: [
          _Filters(children: children, filter: filter),
          const Divider(height: 1),
          Expanded(
            child: tasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('Erro ao carregar as tarefas')),
              data: (list) => list.isEmpty
                  ? _EmptyState(archived: filter.showArchived)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _TaskTile(task: list[i], children: children),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.children, required this.filter});

  final List<Member> children;
  final TaskFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: filter.childId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Criança', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                for (final child in children)
                  DropdownMenuItem(value: child.id, child: Text(child.displayName)),
              ],
              onChanged: (v) => ref.read(taskFilterProvider.notifier).setChild(v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<TaskCategory?>(
              initialValue: filter.category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoria', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                for (final c in TaskCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (v) => ref.read(taskFilterProvider.notifier).setCategory(v),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.children});

  final Task task;
  final List<Member> children;

  String get _assigneeLabel {
    if (task.assigneeMemberId == null) return 'Todas';
    for (final child in children) {
      if (child.id == task.assigneeMemberId) return child.displayName;
    }
    return 'Criança removida';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: task.category.accent.withValues(alpha: 0.16),
        foregroundColor: task.category.accent,
        child: Icon(task.category.icon),
      ),
      title: Text(task.title),
      subtitle: Text(
        '${task.category.label} · ${task.points} pts · ${task.recurrence.summary} · $_assigneeLabel',
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TaskFormScreen(task: task)),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          final controller = ref.read(taskControllerProvider.notifier);
          switch (action) {
            case 'edit':
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => TaskFormScreen(task: task)),
              );
            case 'archive':
              await controller.setActive(task.id, active: false);
            case 'restore':
              await controller.setActive(task.id, active: true);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
          if (task.active)
            const PopupMenuItem(value: 'archive', child: Text('Arquivar'))
          else
            const PopupMenuItem(value: 'restore', child: Text('Reativar')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.archived});
  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          archived ? 'Nenhuma tarefa arquivada' : 'Nenhuma tarefa ainda.\nUse o botão "Tarefa".',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
