import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/centered_message.dart';
import '../../child/presentation/child_shell.dart';
import '../../family/application/family_providers.dart';
import '../../family/presentation/guardian_shell.dart';
import '../../family/presentation/welcome_screen.dart';

/// Depois do login, resolve o papel do usuário na família e monta a navegação:
/// responsável de alguma família -> [GuardianShell]; criança com login
/// vinculado -> [ChildShell]; nenhum dos dois -> [WelcomeScreen].
class RoleGate extends ConsumerWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guardianFamilies = ref.watch(guardianFamiliesProvider);
    final childFamily = ref.watch(childFamilyProvider);

    if (guardianFamilies.isLoading || childFamily.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final error = guardianFamilies.error ?? childFamily.error;
    if (error != null) {
      return CenteredMessage(
        icon: Icons.error_outline_rounded,
        title: 'Erro ao carregar a família',
        message: '$error',
      );
    }

    if ((guardianFamilies.asData?.value ?? const []).isNotEmpty) {
      return const GuardianShell();
    }
    if (childFamily.asData?.value != null) {
      return const ChildShell();
    }
    return const WelcomeScreen();
  }
}
