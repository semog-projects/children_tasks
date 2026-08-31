import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/profile_providers.dart';
import 'pin_field.dart';

/// Pede o PIN. Retorna `true` (via `Navigator.pop`) se confere.
class PinPromptScreen extends ConsumerStatefulWidget {
  const PinPromptScreen({super.key, this.title = 'Modo responsável'});

  final String title;

  @override
  ConsumerState<PinPromptScreen> createState() => _PinPromptScreenState();
}

class _PinPromptScreenState extends ConsumerState<PinPromptScreen> {
  final _fieldKey = GlobalKey<PinFieldState>();
  String? _error;
  bool _checking = false;

  Future<void> _onPin(String pin) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await ref.read(pinCheckProvider.notifier).verify(pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    final check = ref.read(pinCheckProvider);
    setState(() {
      _checking = false;
      _error = check.isLocked
          ? 'Muitas tentativas. Aguarde ${check.remainingLock.inSeconds}s.'
          : 'PIN incorreto.';
    });
    _fieldKey.currentState?.clear();
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(pinCheckProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text('Digite o PIN do responsável', style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              PinField(
                key: _fieldKey,
                enabled: !_checking && !check.isLocked,
                onCompleted: _onPin,
              ),
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

/// Abre o prompt de PIN. `true` se o usuário digitou o PIN certo.
Future<bool> askForPin(BuildContext context, {String title = 'Modo responsável'}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => PinPromptScreen(title: title)),
  );
  return result ?? false;
}
