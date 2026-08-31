import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/env.dart';
import '../../../app/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../application/roadmap_provider.dart';

/// Tela inicial provisória (usuário já autenticado). Placeholder até a
/// navegação real (seleção de perfil) existir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmap = ref.watch(roadmapProvider);
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final user = ref.watch(currentUserProvider);
    final signingOut = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas das Crianças'),
        actions: [
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
              const SizedBox(height: 16),
              if (user != null)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      foregroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      onForegroundImageError:
                          user.photoURL != null ? (_, __) {} : null,
                      child: const Icon(Icons.person),
                    ),
                    title: Text(user.displayName ?? 'Responsável'),
                    subtitle: Text(user.email ?? user.uid),
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                color: firebaseReady
                    ? theme.colorScheme.secondaryContainer
                    : theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    firebaseReady ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  ),
                  title: Text(
                    firebaseReady
                        ? 'Firebase conectado'
                        : 'Firebase indisponível',
                  ),
                  subtitle: Text(
                    firebaseReady
                        ? 'Backend disponível (${AppFlavor.current.name}).'
                        : 'Backend não inicializado nesta plataforma/ambiente.',
                  ),
                ),
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
