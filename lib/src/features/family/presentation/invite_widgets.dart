import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/invite_providers.dart';
import '../data/invites_repository.dart';

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

/// Diálogo para entrar numa família com um código de convite (criança ou 2º
/// responsável). No sucesso, o `RoleGate` reage sozinho à mudança de papel.
class InviteCodeDialog extends ConsumerStatefulWidget {
  const InviteCodeDialog({super.key});

  @override
  ConsumerState<InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends ConsumerState<InviteCodeDialog> {
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
      Navigator.of(context).pop(true);
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

/// Mostra um código de convite recém-gerado: o código (selecionável), botão de
/// copiar, validade e uma dica de uso.
class InviteCodeBox extends StatelessWidget {
  const InviteCodeBox({super.key, required this.invite, required this.hint});

  final FamilyInvite invite;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = invite.expiresAt.difference(DateTime.now()).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SelectableText(
                invite.code,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(letterSpacing: 4, fontFamily: 'monospace'),
              ),
            ),
            IconButton(
              tooltip: 'Copiar',
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invite.code));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                      const SnackBar(content: Text('Código copiado')));
              },
            ),
          ],
        ),
        Text(
          days > 0 ? 'Válido por $days dias.' : 'Válido por menos de 1 dia.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(hint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
