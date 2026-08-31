import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../application/invite_providers.dart';
import '../data/invites_repository.dart';
import 'family_onboarding_screen.dart';

/// Usuário logado que ainda não faz parte de nenhuma família: pode criar a
/// própria (vira responsável) ou entrar em uma existente por convite.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signingOut = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo'),
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.family_restroom_rounded,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Você ainda não faz parte de uma família',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Crie a sua para gerenciar a rotina das crianças, ou entre '
                  'em uma que já existe com um código de convite.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FamilyOnboardingScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add_home_rounded),
                  label: const Text('Criar uma família'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _InviteCodeDialog(),
                  ),
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Tenho um código de convite'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteCodeDialog extends ConsumerStatefulWidget {
  const _InviteCodeDialog();

  @override
  ConsumerState<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends ConsumerState<_InviteCodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _error = null);
    final ok =
        await ref.read(acceptInviteControllerProvider.notifier).accept(code);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    final err = ref.read(acceptInviteControllerProvider).error;
    setState(() => _error = err is InviteException
        ? err.message
        : 'Não foi possível entrar com este código.');
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(acceptInviteControllerProvider).isLoading;

    return AlertDialog(
      title: const Text('Código de convite'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !busy,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              UpperCaseFormatter(),
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: const InputDecoration(
              labelText: 'Código',
              hintText: 'ex.: ABCD2345',
            ),
            onSubmitted: (_) => busy ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: Text(busy ? 'Entrando…' : 'Entrar'),
        ),
      ],
    );
  }
}

/// Deixa o texto sempre em maiúsculas (códigos de convite).
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
