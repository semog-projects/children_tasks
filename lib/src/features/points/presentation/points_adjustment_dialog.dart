import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/member.dart';
import '../application/points_providers.dart';

/// Diálogo do responsável para ajustar o saldo de uma criança: descontar ou
/// adicionar pontos, sempre com um motivo. Retorna `true` quando o lançamento
/// foi gravado.
class PointsAdjustmentDialog extends ConsumerStatefulWidget {
  const PointsAdjustmentDialog({super.key, required this.child});

  final Member child;

  static Future<bool?> show(BuildContext context, Member child) {
    return showDialog<bool>(
      context: context,
      builder: (_) => PointsAdjustmentDialog(child: child),
    );
  }

  @override
  ConsumerState<PointsAdjustmentDialog> createState() =>
      _PointsAdjustmentDialogState();
}

class _PointsAdjustmentDialogState
    extends ConsumerState<PointsAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _remove = true;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = widget.child.displayName;
    final magnitude = int.parse(_amount.text.trim());
    final signed = _remove ? -magnitude : magnitude;

    setState(() => _submitting = true);
    await ref.read(pointsControllerProvider.notifier).adjust(
          child: widget.child,
          points: signed,
          reason: _reason.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    final error = ref.read(pointsControllerProvider).error;
    if (error != null) {
      final message = error is PointsAdjustmentException
          ? error.message
          : 'Não foi possível ajustar os pontos.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    navigator.pop(true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_remove
            ? 'Descontados $magnitude pts de $name.'
            : 'Adicionados $magnitude pts para $name.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajustar pontos de ${widget.child.displayName}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Descontar'),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Adicionar'),
                ),
              ],
              selected: {_remove},
              onSelectionChanged: _submitting
                  ? null
                  : (s) => setState(() => _remove = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              enabled: !_submitting,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Pontos',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Informe um número maior que zero.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Ex: não guardou os brinquedos',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'O motivo é obrigatório.' : null,
            ),
          ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Salvando…' : 'Confirmar'),
        ),
      ],
    );
  }
}
