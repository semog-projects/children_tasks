import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/avatar_colors.dart';
import '../../../data/models/member.dart';
import '../application/family_providers.dart';

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
                ],
              ),
            ),
          ),
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
        child: selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }
}
