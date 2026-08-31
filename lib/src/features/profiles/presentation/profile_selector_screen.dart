import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/avatar_colors.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../application/profile_providers.dart';
import 'pin_prompt_screen.dart';

/// Quem está usando o app agora?
class ProfileSelectorScreen extends ConsumerWidget {
  const ProfileSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(familyChildrenProvider).asData?.value ?? const [];
    final signingOut = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quem é você?'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout),
            onPressed: signingOut
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.shield_outlined)),
                  title: const Text('Responsável'),
                  subtitle: const Text('Protegido por PIN'),
                  onTap: () async {
                    final ok = await askForPin(context);
                    if (ok) {
                      await ref.read(activeProfileProvider.notifier).selectGuardian();
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text('Crianças', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              for (final child in children)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorFromHex(child.avatarColor),
                      child: Text(
                        child.displayName.isNotEmpty
                            ? child.displayName.characters.first.toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(child.displayName),
                    onTap: () =>
                        ref.read(activeProfileProvider.notifier).selectChild(child.id),
                  ),
                ),
              if (children.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Nenhuma criança ainda — entre como responsável para adicionar.'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
