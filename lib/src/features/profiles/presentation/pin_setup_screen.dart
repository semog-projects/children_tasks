import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../application/profile_providers.dart';
import 'pin_field.dart';

/// Define o PIN do responsável no primeiro uso (obrigatório: é o cadeado do
/// modo criança).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _fieldKey = GlobalKey<PinFieldState>();
  String? _first;
  String? _error;
  bool _saving = false;

  Future<void> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      _fieldKey.currentState?.clear();
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'Os PINs não conferem. Tente de novo.';
      });
      _fieldKey.currentState?.clear();
      return;
    }
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    await ref.read(pinRepositoryProvider).setPin(uid, pin);
    ref.invalidate(hasPinProvider);
    // Depois de criar, entra como responsável.
    await ref.read(activeProfileProvider.notifier).selectGuardian();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Criar PIN')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                _first == null
                    ? 'Escolha um PIN de 4 dígitos'
                    : 'Digite o PIN de novo para confirmar',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ele protege a troca do modo criança para o modo responsável.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PinField(key: _fieldKey, enabled: !_saving, onCompleted: _onPin),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
