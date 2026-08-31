import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/centered_message.dart';
import '../../../data/models/family.dart';
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
  void initState() {
    super.initState();
    // `fireImmediately` cobre o caso normal: quando este shell monta, o
    // `RoleGate` já resolveu a família, então um `ref.listen` sem isso nunca
    // dispararia.
    ref.listenManual<AsyncValue<Family?>>(
      currentFamilyProvider,
      (_, next) => _maybeStart(next.asData?.value),
      fireImmediately: true,
    );
  }

  void _maybeStart(Family? family) {
    if (_started || family == null) return;
    _started = true;
    ref.read(familyControllerProvider.notifier).healOwnProfile();
    requestTodayInstances(ref);
    ref.read(notificationsServiceProvider).start();
  }

  @override
  Widget build(BuildContext context) {
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
