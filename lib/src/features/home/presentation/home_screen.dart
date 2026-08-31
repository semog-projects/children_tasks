import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/avatar_colors.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/presentation/family_screen.dart';

/// Tela inicial do responsável autenticado, com a família já criada.
/// Ainda provisória — as tarefas do dia entram nas próximas issues.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider).asData?.value;
    final children = ref.watch(familyChildrenProvider);
    final signingOut = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(family?.name ?? 'Tarefas das Crianças'),
        actions: [
          IconButton(
            tooltip: 'Família',
            icon: const Icon(Icons.group),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FamilyScreen()),
            ),
          ),
          IconButton(
            onPressed: signingOut
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
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
                  Text(
                    'Crianças',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final child in list)
                    Card(
                      child: ListTile(
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
                        subtitle: const Text('Tarefas do dia em breve'),
                      ),
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
