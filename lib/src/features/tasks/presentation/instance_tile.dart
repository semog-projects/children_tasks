import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/task_instance.dart';
import '../application/approval_providers.dart';

/// Tile de uma ocorrência com as ações conforme o estado. Usado na tela de
/// hoje e na fila de aprovação.
class InstanceTile extends ConsumerWidget {
  const InstanceTile({
    super.key,
    required this.instance,
    this.showChildHint,
    this.childMode = false,
  });

  final TaskInstance instance;
  final String? showChildHint;

  /// No modo criança, some com as ações de aprovar/rejeitar.
  final bool childMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(approvalControllerProvider.notifier);
    final busy = ref.watch(approvalControllerProvider).isLoading;
    final theme = Theme.of(context);

    final subtitleParts = <String>['${instance.pointsSnapshot} pts'];
    if (showChildHint != null) subtitleParts.add(showChildHint!);
    if (instance.isPending && instance.rejectionReason != null) {
      subtitleParts.add('Refazer: ${instance.rejectionReason}');
    }

    return ListTile(
      leading: _StatusIcon(status: instance.status),
      title: Text(instance.titleSnapshot),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: switch (instance.status) {
        TaskInstanceStatus.pending => FilledButton.tonal(
            onPressed: busy ? null : () => controller.markDone(instance),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Feita'),
          ),
        TaskInstanceStatus.awaitingApproval => childMode
            ? const Text('Aguardando')
            : Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Rejeitar',
                    icon: const Icon(Icons.close),
                    onPressed: busy ? null : () => _reject(context, controller),
                  ),
                  IconButton.filled(
                    tooltip: 'Aprovar',
                    icon: const Icon(Icons.check),
                    onPressed: busy ? null : () => controller.approve(instance.id),
                  ),
                ],
              ),
        TaskInstanceStatus.approved => Text(
            '+${instance.pointsAwarded ?? instance.pointsSnapshot}',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        TaskInstanceStatus.rejected => const Text('Rejeitada'),
      },
    );
  }

  Future<void> _reject(BuildContext context, ApprovalController controller) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeitar tarefa'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'ex.: a cama ainda está bagunçada',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rejeitar')),
        ],
      ),
    );
    if (confirmed ?? false) {
      final reason = reasonController.text.trim();
      await controller.reject(instance.id, reason: reason.isEmpty ? null : reason);
    }
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final TaskInstanceStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (status) {
      TaskInstanceStatus.pending => (
          Icons.radio_button_unchecked,
          scheme.outline,
        ),
      TaskInstanceStatus.awaitingApproval => (
          Icons.hourglass_top,
          scheme.tertiary,
        ),
      TaskInstanceStatus.approved => (Icons.check_circle, scheme.primary),
      TaskInstanceStatus.rejected => (Icons.cancel, scheme.error),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.14),
      foregroundColor: color,
      child: Icon(icon),
    );
  }
}
