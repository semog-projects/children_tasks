import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/member.dart';
import '../../family/application/family_providers.dart';
import '../application/approval_providers.dart';
import 'instance_tile.dart';

/// Fila de aprovações pendentes do responsável.
class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingApprovalsProvider);
    final childList =
        ref.watch(familyChildrenProvider).asData?.value ?? const <Member>[];
    final children = {for (final c in childList) c.id: c.displayName};

    return Scaffold(
      appBar: AppBar(title: const Text('Aprovações pendentes')),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Erro ao carregar')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Nada para aprovar 🎉'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => InstanceTile(
                  instance: list[i],
                  showChildHint: children[list[i].memberId] ?? 'Criança',
                ),
              ),
      ),
    );
  }
}
