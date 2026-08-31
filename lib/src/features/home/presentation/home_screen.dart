import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/roadmap_provider.dart';

/// Tela inicial provisória. Serve de _placeholder_ até a navegação real
/// (seleção de perfil / login) existir, e confirma que o scaffold,
/// o tema e o Riverpod estão ligados.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmap = ref.watch(roadmapProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tarefas das Crianças')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Projeto em bootstrap',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'O scaffold Flutter está pronto. Próximas entregas do backlog:',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              for (final item in roadmap)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${item.issue}')),
                    title: Text(item.title),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
