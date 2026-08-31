import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase/firebase_providers.dart';
import '../../../common/centered_message.dart';
import '../application/auth_providers.dart';
import 'role_gate.dart';
import 'sign_in_screen.dart';

/// Decide a tela raiz conforme o estado de autenticação:
/// backend indisponível -> aviso; carregando -> splash; deslogado -> login;
/// logado -> resolve o papel (responsável/criança/sem família).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(firebaseReadyProvider)) {
      return const CenteredMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Backend indisponível',
        message: 'O Firebase não foi inicializado neste ambiente.',
      );
    }

    return ref.watch(authStateChangesProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => CenteredMessage(
            icon: Icons.error_outline_rounded,
            title: 'Erro de autenticação',
            message: '$error',
          ),
          data: (user) =>
              user == null ? const SignInScreen() : const RoleGate(),
        );
  }
}
