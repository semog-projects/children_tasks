import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase/firebase_providers.dart';
import '../../home/presentation/home_screen.dart';
import '../application/auth_providers.dart';
import 'sign_in_screen.dart';

/// Decide a tela raiz conforme o estado de autenticação:
/// backend indisponível -> aviso; carregando -> splash; deslogado -> login;
/// logado -> app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(firebaseReadyProvider)) {
      return const _CenteredMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Backend indisponível',
        message: 'O Firebase não foi inicializado neste ambiente.',
      );
    }

    return ref.watch(authStateChangesProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _CenteredMessage(
            icon: Icons.error_outline_rounded,
            title: 'Erro de autenticação',
            message: '$error',
          ),
          data: (user) => user == null ? const SignInScreen() : const HomeScreen(),
        );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(message, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
