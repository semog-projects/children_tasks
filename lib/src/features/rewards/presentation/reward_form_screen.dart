import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/reward.dart';
import '../application/reward_providers.dart';

class RewardFormScreen extends ConsumerStatefulWidget {
  const RewardFormScreen({super.key, this.reward});

  final Reward? reward;
  bool get isEditing => reward != null;

  @override
  ConsumerState<RewardFormScreen> createState() => _RewardFormScreenState();
}

class _RewardFormScreenState extends ConsumerState<RewardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleCtrl = TextEditingController(text: widget.reward?.title ?? '');
  late final _descCtrl = TextEditingController(text: widget.reward?.description ?? '');
  late final _costCtrl =
      TextEditingController(text: (widget.reward?.cost ?? 50).toString());
  late bool _limitedStock = widget.reward?.stock != null;
  late final _stockCtrl =
      TextEditingController(text: (widget.reward?.stock ?? 1).toString());
  late bool _active = widget.reward?.active ?? true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final desc = _descCtrl.text.trim();
    final reward = Reward(
      id: widget.reward?.id ?? '',
      title: _titleCtrl.text.trim(),
      description: desc.isEmpty ? null : desc,
      cost: int.parse(_costCtrl.text),
      active: _active,
      stock: _limitedStock ? int.parse(_stockCtrl.text) : null,
      createdAt: widget.reward?.createdAt,
      updatedAt: widget.reward?.updatedAt,
    );
    await ref.read(rewardControllerProvider.notifier).save(reward);
    if (!ref.read(rewardControllerProvider).hasError && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rewardControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Não foi possível salvar.')));
      }
    });
    final busy = ref.watch(rewardControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar recompensa' : 'Nova recompensa'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Título'),
                    textCapitalization: TextCapitalization.sentences,
                    autofocus: true,
                    maxLength: 80,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe um título' : null,
                  ),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                    maxLines: 2,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _costCtrl,
                    decoration: const InputDecoration(labelText: 'Custo em pontos'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n <= 0) ? 'Informe um número maior que zero' : null;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Estoque limitado'),
                    value: _limitedStock,
                    onChanged: (v) => setState(() => _limitedStock = v),
                  ),
                  if (_limitedStock)
                    TextFormField(
                      controller: _stockCtrl,
                      decoration: const InputDecoration(labelText: 'Quantidade disponível'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (!_limitedStock) return null;
                        final n = int.tryParse(v ?? '');
                        return (n == null || n < 0) ? 'Informe um número válido' : null;
                      },
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ativa'),
                    subtitle: const Text('Aparece no catálogo das crianças'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const SizedBox(height: 20),
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
