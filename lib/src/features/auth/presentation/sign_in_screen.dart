import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/brand.dart';
import '../../../common/spacing.dart';
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
            padding: AppSpacing.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 88),
                const Gap.lg(),
                Text(
                  'Tarefas das Crianças',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const Gap.sm(),
                Text(
                  'Entre com sua conta Google para gerenciar a rotina da família.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap.xl(),
                GoogleSignInButton(
                  loading: state.isLoading,
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithGoogle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
