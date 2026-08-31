import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/avatar_colors.dart';
import '../../../common/br_timezones.dart';
import '../../../data/models/family.dart';
import '../../../data/models/member.dart';
import '../../auth/application/auth_providers.dart';
import '../../notifications/presentation/notifications_settings_screen.dart';
import '../application/family_providers.dart';
import 'child_form_screen.dart';

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
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('Adicionar responsável'),
            onTap: () => _showAddGuardianDialog(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificações'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NotificationsSettingsScreen()),
            ),
          ),
          const Divider(height: 1),
          const _SectionTitle('Crianças'),
          children.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const ListTile(title: Text('Erro ao carregar as crianças')),
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

  Future<void> _showAddGuardianDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar responsável'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Peça para a outra pessoa entrar no app e copiar o "ID da conta" '
              'na tela de conta. Cole aqui.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'ID da conta'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (uid != null && uid.isNotEmpty) {
      await ref.read(familyControllerProvider.notifier).addGuardianByUid(uid);
    }
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
        content: TextField(controller: controller, autofocus: true, maxLength: 60),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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
      subtitle: isMe ? Text('ID: $uid', style: const TextStyle(fontSize: 12)) : null,
      trailing: isMe
          ? IconButton(
              tooltip: 'Copiar meu ID',
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: uid));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ID copiado')),
                );
              },
            )
          : null,
    );
  }
}

class _ChildTile extends ConsumerWidget {
  const _ChildTile({required this.child});
  final Member child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorFromHex(child.avatarColor),
        child: Text(
          child.displayName.isNotEmpty ? child.displayName.characters.first.toUpperCase() : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(child.displayName),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'edit') {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ChildFormScreen(child: child)),
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
          'A criança sai da família. O histórico de pontos já registrado é mantido.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
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
