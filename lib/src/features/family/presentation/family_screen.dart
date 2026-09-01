import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/br_timezones.dart';
import '../../../common/child_avatar.dart';
import '../../../data/models/family.dart';
import '../../../data/models/member.dart';
import '../../auth/application/auth_providers.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/family_providers.dart';
import '../application/invite_providers.dart';
import '../data/invites_repository.dart';
import 'child_form_screen.dart';
import 'invite_widgets.dart';

/// Gestão da família: nome, fuso, responsáveis e crianças.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider).asData?.value;
    final children = ref.watch(familyChildrenProvider);

    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Família')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ChildFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Criança'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _FamilyHeader(family: family),
          const Divider(height: 1),
          const _SectionTitle('Responsáveis'),
          for (final uid in family.guardianUids)
            _GuardianTile(family: family, uid: uid),
          _GuardianInvites(familyId: family.id),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('Convidar responsável'),
            subtitle: const Text('Gera um código para outra conta Google entrar'),
            onTap: () => _showInviteGuardianDialog(context, ref, family.id),
          ),
          ListTile(
            leading: const Icon(Icons.key_rounded),
            title: const Text('Entrar em outra família com código'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const InviteCodeDialog(),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Ajustes'),
            subtitle: const Text('Notificações e aparência'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const Divider(height: 1),
          const _SectionTitle('Crianças'),
          children.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                const ListTile(title: Text('Erro ao carregar as crianças')),
            data: (list) => list.isEmpty
                ? const ListTile(
                    title: Text('Nenhuma criança ainda'),
                    subtitle: Text('Use o botão "Criança" para adicionar.'),
                  )
                : Column(
                    children: [
                      for (final child in list) _ChildTile(child: child),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInviteGuardianDialog(
    BuildContext context,
    WidgetRef ref,
    String familyId,
  ) async {
    final emailController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => _InviteGuardianDialog(
        familyId: familyId,
        emailController: emailController,
      ),
    );
    ref.invalidate(pendingInvitesProvider(familyId));
  }
}

/// Diálogo: e-mail (opcional) -> gera o código e mostra para compartilhar.
class _InviteGuardianDialog extends ConsumerStatefulWidget {
  const _InviteGuardianDialog({
    required this.familyId,
    required this.emailController,
  });

  final String familyId;
  final TextEditingController emailController;

  @override
  ConsumerState<_InviteGuardianDialog> createState() =>
      _InviteGuardianDialogState();
}

class _InviteGuardianDialogState extends ConsumerState<_InviteGuardianDialog> {
  bool _loading = false;
  String? _error;
  FamilyInvite? _invite;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite =
          await ref.read(invitesRepositoryProvider).createGuardianInvite(
                familyId: widget.familyId,
                email: widget.emailController.text,
              );
      if (mounted) setState(() => _invite = invite);
    } on InviteException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Convidar responsável'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_invite == null) ...[
            const Text(
              'Opcional: informe o e-mail Google da pessoa. Se informar, só '
              'essa conta poderá usar o código.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.emailController,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail (opcional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ] else
            InviteCodeBox(
              invite: _invite!,
              hint: 'A outra pessoa entra com o Google e digita este código '
                  'em "Tenho um código de convite".',
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_invite == null ? 'Cancelar' : 'Fechar'),
        ),
        if (_invite == null)
          FilledButton(
            onPressed: _loading ? null : _generate,
            child: Text(_loading ? 'Gerando…' : 'Gerar código'),
          ),
      ],
    );
  }
}

/// Convites de responsável em aberto, com opção de revogar.
class _GuardianInvites extends ConsumerWidget {
  const _GuardianInvites({required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(pendingInvitesProvider(familyId)).asData?.value ??
        const <PendingInvite>[];
    final guardianInvites = invites.where((i) => i.isGuardian).toList();
    if (guardianInvites.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final invite in guardianInvites)
          ListTile(
            leading: const Icon(Icons.hourglass_top),
            title: Text('Código ${invite.code}'),
            subtitle: Text(invite.email == null
                ? 'Convite pendente'
                : 'Convite para ${invite.email}'),
            trailing: TextButton(
              onPressed: () async {
                await ref.read(invitesRepositoryProvider).revoke(invite.code);
                ref.invalidate(pendingInvitesProvider(familyId));
              },
              child: const Text('Revogar'),
            ),
          ),
      ],
    );
  }
}

class _FamilyHeader extends ConsumerWidget {
  const _FamilyHeader({required this.family});
  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.home_rounded),
          title: Text(family.name),
          subtitle: const Text('Nome da família'),
          trailing: const Icon(Icons.edit),
          onTap: () => _editName(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: Text(timezoneLabel(family.timezone)),
          subtitle: const Text('Fuso horário'),
          trailing: const Icon(Icons.edit),
          onTap: () => _editTimezone(context, ref),
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: family.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome da família'),
        content:
            TextField(controller: controller, autofocus: true, maxLength: 60),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(familyControllerProvider.notifier).rename(name);
    }
  }

  Future<void> _editTimezone(BuildContext context, WidgetRef ref) async {
    final tz = await showDialog<String>(
      context: context,
      builder: (ctx) => RadioGroup<String>(
        groupValue: family.timezone,
        onChanged: (v) {
          if (v != null) Navigator.pop(ctx, v);
        },
        child: SimpleDialog(
          title: const Text('Fuso horário'),
          children: [
            for (final option in brTimezones)
              RadioListTile<String>(
                value: option.id,
                title: Text(option.label),
              ),
          ],
        ),
      ),
    );
    if (tz != null) {
      await ref.read(familyControllerProvider.notifier).setTimezone(tz);
    }
  }
}

class _GuardianTile extends ConsumerWidget {
  const _GuardianTile({required this.family, required this.uid});
  final Family family;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final isMe = me?.uid == uid;
    final profile = family.guardianFor(uid);
    final name = isMe
        ? '${profile?.displayName ?? me?.displayName ?? 'Você'} (você)'
        : profile?.displayName ?? 'Responsável';

    return ListTile(
      leading: CircleAvatar(
        foregroundImage:
            profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
        onForegroundImageError: profile?.photoUrl != null ? (_, _) {} : null,
        child: const Icon(Icons.person),
      ),
      title: Text(name),
    );
  }
}

class _ChildTile extends ConsumerWidget {
  const _ChildTile({required this.child});
  final Member child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: ChildAvatar(
        name: child.displayName,
        colorHex: child.avatarColor,
      ),
      title: Text(child.displayName),
      subtitle: child.linkedUid != null ? const Text('Conta vinculada') : null,
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'edit') {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => ChildFormScreen(child: child)),
            );
          } else if (action == 'remove') {
            await _confirmRemove(context, ref);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(value: 'remove', child: Text('Remover')),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ChildFormScreen(child: child)),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remover ${child.displayName}?'),
        content: const Text(
          'A criança sai da família. O histórico de pontos já registrado é '
          'mantido.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(memberControllerProvider.notifier).removeChild(child.id);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1,
            ),
      ),
    );
  }
}
