import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../data/auth_repository.dart';

/// Tela de login do responsável. Único método: conta Google.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null && error is! AuthCancelledException) {
        final message = error is AuthException
            ? error.message
            : 'Não foi possível entrar. Tente novamente.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.family_restroom_rounded, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Tarefas das Crianças',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Entre com sua conta Google para gerenciar a rotina da família.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: state.isLoading
                      ? null
                      : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                  icon: state.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(state.isLoading ? 'Entrando…' : 'Entrar com Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
