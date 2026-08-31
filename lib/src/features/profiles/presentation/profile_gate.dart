import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_providers.dart';
import '../../home/presentation/home_screen.dart';
import '../application/profile_providers.dart';
import '../domain/active_profile.dart';
import 'child_home_screen.dart';
import 'pin_setup_screen.dart';
import 'profile_selector_screen.dart';

/// Depois de ter família: exige criar o PIN, mostra o seletor de perfil e
/// roteia para a visão do perfil ativo.
class ProfileGate extends ConsumerWidget {
  const ProfileGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(hasPinProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            body: Center(child: Text('Erro: $error')),
          ),
          data: (hasPin) {
            if (!hasPin) return const PinSetupScreen();

            final profile = ref.watch(activeProfileProvider);
            return switch (profile) {
              ProfileNone() => const ProfileSelectorScreen(),
              ProfileGuardian() => const HomeScreen(),
              ProfileChild(:final memberId) => _childOrSelector(ref, memberId),
            };
          },
        );
  }

  Widget _childOrSelector(WidgetRef ref, String memberId) {
    final children = ref.watch(familyChildrenProvider).asData?.value;
    if (children != null && children.every((c) => c.id != memberId)) {
      // Criança removida — volta ao seletor.
      Future.microtask(
        () => ref.read(activeProfileProvider.notifier).backToSelector(),
      );
      return const ProfileSelectorScreen();
    }
    return ChildHomeScreen(memberId: memberId);
  }
}
