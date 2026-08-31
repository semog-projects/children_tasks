import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/home_screen.dart';
import '../../tasks/application/task_instances_providers.dart';
import '../application/family_providers.dart';
import 'family_onboarding_screen.dart';

/// Depois do login: sem família -> onboarding; com família -> app.
/// Também mantém o perfil do responsável logado atualizado no doc da família.
class FamilyGate extends ConsumerStatefulWidget {
  const FamilyGate({super.key});

  @override
  ConsumerState<FamilyGate> createState() => _FamilyGateState();
}

class _FamilyGateState extends ConsumerState<FamilyGate> {
  bool _healed = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(currentFamilyProvider, (_, next) {
      if (!_healed && next.asData?.value != null) {
        _healed = true;
        ref.read(familyControllerProvider.notifier).healOwnProfile();
        requestTodayInstances(ref);
      }
    });

    return ref.watch(currentFamilyProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro ao carregar a família:\n$error', textAlign: TextAlign.center),
              ),
            ),
          ),
          data: (family) =>
              family == null ? const FamilyOnboardingScreen() : const HomeScreen(),
        );
  }
}
