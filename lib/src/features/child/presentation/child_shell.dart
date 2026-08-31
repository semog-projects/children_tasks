import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/member.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../notifications/application/notifications_service.dart';
import '../../tasks/application/task_instances_providers.dart';
import '../application/child_providers.dart';
import 'child_home_screen.dart';

/// Raiz da sessão de uma criança logada com a própria conta. Resolve qual
/// `member` da família corresponde ao usuário e abre a home simplificada.
class ChildShell extends ConsumerStatefulWidget {
  const ChildShell({super.key});

  @override
  ConsumerState<ChildShell> createState() => _ChildShellState();
}

class _ChildShellState extends ConsumerState<ChildShell> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // `fireImmediately`: quando este shell monta, o `RoleGate` já resolveu o
    // vínculo, então um `ref.listen` sem isso nunca dispararia.
    ref.listenManual<Member?>(
      currentChildMemberProvider,
      (_, next) => _maybeStart(next),
      fireImmediately: true,
    );
  }

  void _maybeStart(Member? member) {
    if (_started || member == null) return;
    _started = true;
    requestTodayInstances(ref);
    ref.read(notificationsServiceProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(currentChildMemberProvider);
    if (member != null) {
      return ChildHomeScreen(memberId: member.id);
    }

    // Sem vínculo resolvido: se as crianças já carregaram, o vínculo se perdeu.
    final children = ref.watch(familyChildrenProvider);
    if (children.isLoading || children.hasError) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _UnlinkedNotice(
      onSignOut: () => ref.read(authControllerProvider.notifier).signOut(),
    );
  }
}

class _UnlinkedNotice extends StatelessWidget {
  const _UnlinkedNotice({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                'Esta conta não está mais vinculada a uma criança.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onSignOut, child: const Text('Sair')),
            ],
          ),
        ),
      ),
    );
  }
}
