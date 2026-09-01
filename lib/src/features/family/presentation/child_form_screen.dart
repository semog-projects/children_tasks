import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/avatar_colors.dart';
import '../../../data/models/member.dart';
import '../application/family_providers.dart';
import '../application/invite_providers.dart';
import '../data/invites_repository.dart';
import 'invite_widgets.dart';

/// Formulário de adicionar/editar uma criança.
class ChildFormScreen extends ConsumerStatefulWidget {
  const ChildFormScreen({super.key, this.child});

  final Member? child;

  bool get isEditing => child != null;

  @override
  ConsumerState<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends ConsumerState<ChildFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.child?.displayName ?? '');
  late String _colorHex = widget.child?.avatarColor ?? defaultAvatarColorHex;
  late DateTime? _birthDate = widget.child?.birthDate;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 8),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(memberControllerProvider.notifier);
    if (widget.isEditing) {
      await controller.updateChild(
        widget.child!.copyWith(
          displayName: _nameController.text,
          avatarColor: _colorHex,
          birthDate: _birthDate,
        ),
      );
    } else {
      await controller.addChild(
        displayName: _nameController.text,
        avatarColor: _colorHex,
        birthDate: _birthDate,
      );
    }
    if (!ref.read(memberControllerProvider).hasError && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(memberControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Não foi possível salvar.')));
      }
    });

    final busy = ref.watch(memberControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar criança' : 'Nova criança'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    maxLength: 60,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Cor'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final hex in avatarColorHexes)
                        _ColorSwatch(
                          hex: hex,
                          selected: hex == _colorHex,
                          onTap: () => setState(() => _colorHex = hex),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data de nascimento (opcional)'),
                    subtitle: Text(
                      _birthDate == null
                          ? 'Não informada'
                          : '${_birthDate!.day.toString().padLeft(2, '0')}/'
                              '${_birthDate!.month.toString().padLeft(2, '0')}/'
                              '${_birthDate!.year}',
                    ),
                    trailing: Wrap(
                      children: [
                        if (_birthDate != null)
                          IconButton(
                            onPressed: () => setState(() => _birthDate = null),
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          onPressed: _pickBirthDate,
                          icon: const Icon(Icons.calendar_today),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Text(busy ? 'Salvando…' : 'Salvar'),
                  ),
                  if (widget.isEditing) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    _ChildInviteCard(child: widget.child!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vínculo de conta da criança: mostra o estado e gera um código de convite
/// para a criança entrar com a própria conta Google (issue #33).
class _ChildInviteCard extends ConsumerStatefulWidget {
  const _ChildInviteCard({required this.child});

  final Member child;

  @override
  ConsumerState<_ChildInviteCard> createState() => _ChildInviteCardState();
}

class _ChildInviteCardState extends ConsumerState<_ChildInviteCard> {
  bool _loading = false;
  FamilyInvite? _invite;

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final invite = await ref.read(invitesRepositoryProvider).createChildInvite(
            familyId: ref.read(currentFamilyIdProvider),
            memberId: widget.child.id,
          );
      if (mounted) setState(() => _invite = invite);
    } on InviteException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.child.linkedUid != null) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.verified_user_rounded,
              color: theme.colorScheme.primary),
          title: const Text('Conta vinculada'),
          subtitle: const Text('A criança já entra com a própria conta Google.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Login da criança', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Gere um código para ${widget.child.displayName} entrar no app '
              'com a própria conta Google.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_invite == null)
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key_rounded),
                label: Text(_loading ? 'Gerando…' : 'Gerar convite'),
              )
            else
              InviteCodeBox(
                invite: _invite!,
                hint: 'A criança abre o app, entra com o Google e '
                    'digita este código.',
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.hex, required this.selected, required this.onTap});

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorFromHex(hex),
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
              : null,
        ),
        child: selected
            ? Icon(Icons.check, color: onAvatarColorHex(hex), size: 20)
            : null,
      ),
    );
  }
}
