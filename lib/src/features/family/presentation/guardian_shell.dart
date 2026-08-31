import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/centered_message.dart';
import '../../home/presentation/home_screen.dart';
import '../../notifications/application/notifications_service.dart';
import '../../tasks/application/task_instances_providers.dart';
import '../application/family_providers.dart';

/// Raiz da sessão do responsável. Quando a família aparece, mantém o perfil do
/// responsável atualizado no doc, pede a materialização das tarefas de hoje e
/// liga as notificações. A existência da família é garantida pelo `RoleGate`.
class GuardianShell extends ConsumerStatefulWidget {
  const GuardianShell({super.key});

  @override
  ConsumerState<GuardianShell> createState() => _GuardianShellState();
}

class _GuardianShellState extends ConsumerState<GuardianShell> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(currentFamilyProvider, (_, next) {
      if (!_started && next.asData?.value != null) {
        _started = true;
        ref.read(familyControllerProvider.notifier).healOwnProfile();
        requestTodayInstances(ref);
        ref.read(notificationsServiceProvider).start();
      }
    });

    return ref.watch(currentFamilyProvider).when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => CenteredMessage(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar a família',
            message: '$error',
          ),
          data: (_) => const HomeScreen(),
        );
  }
}
