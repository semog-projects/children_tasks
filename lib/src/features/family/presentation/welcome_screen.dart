import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import 'family_onboarding_screen.dart';
import 'invite_widgets.dart';

/// Usuário logado que ainda não faz parte de nenhuma família: pode criar a
/// própria (vira responsável) ou entrar em uma existente por convite.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signingOut = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout),
            onPressed: signingOut
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.family_restroom_rounded,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Você ainda não faz parte de uma família',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Crie a sua para gerenciar a rotina das crianças, ou entre '
                  'em uma que já existe com um código de convite.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FamilyOnboardingScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add_home_rounded),
                  label: const Text('Criar uma família'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const InviteCodeDialog(),
                  ),
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Tenho um código de convite'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
