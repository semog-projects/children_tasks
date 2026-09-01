import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/br_timezones.dart';
import '../../../common/spacing.dart';
import '../application/family_providers.dart';

/// Primeiro acesso: o responsável cria a família.
class FamilyOnboardingScreen extends ConsumerStatefulWidget {
  const FamilyOnboardingScreen({super.key});

  @override
  ConsumerState<FamilyOnboardingScreen> createState() => _FamilyOnboardingScreenState();
}

class _FamilyOnboardingScreenState extends ConsumerState<FamilyOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _timezone = defaultTimezone;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(familyControllerProvider.notifier).createFamily(
          name: _nameController.text,
          timezone: _timezone,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(familyControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Não foi possível criar a família.')));
      }
    });

    // Assim que a família passa a existir, o `RoleGate` troca a raiz por si só;
    // se esta tela foi empilhada pela [WelcomeScreen], sai da pilha.
    ref.listen(guardianFamiliesProvider, (_, next) {
      final hasFamily = (next.asData?.value ?? const []).isNotEmpty;
      if (hasFamily && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    final busy = ref.watch(familyControllerProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sua família')),
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.screen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Vamos criar sua família', style: theme.textTheme.headlineSmall),
                  const Gap.sm(),
                  Text(
                    'Depois você adiciona as crianças e as tarefas.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Gap.lg(),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da família',
                      hintText: 'ex.: Família Silva',
                    ),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    maxLength: 60,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
                  ),
                  const Gap.sm(),
                  DropdownButtonFormField<String>(
                    initialValue: _timezone,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Fuso horário'),
                    items: [
                      for (final tz in brTimezones)
                        DropdownMenuItem(
                          value: tz.id,
                          child: Text(tz.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _timezone = v ?? defaultTimezone),
                  ),
                  const Gap.lg(),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Text(busy ? 'Criando…' : 'Criar família'),
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
