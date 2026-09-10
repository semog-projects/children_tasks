import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/empty_hint.dart';
import '../../../common/pull_refresh.dart';
import '../../../data/models/cash_out.dart';
import '../../../data/models/member.dart';
import '../../family/application/family_providers.dart';
import '../application/cashout_providers.dart';
import '../domain/cash_out_math.dart';

/// Fila do responsável: pedidos de câmbio para aprovar, recusar ou marcar pago.
class CashOutRequestsScreen extends ConsumerWidget {
  const CashOutRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(cashOutControllerProvider, (_, next) {
      final error = next.error;
      if (error == null || next.isLoading) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error is CashOutException
              ? error.message
              : 'Não foi possível concluir.'),
        ));
    });

    final pending = ref.watch(pendingCashOutsProvider);
    final rate = ref.watch(pointValueCentsProvider);
    final children =
        ref.watch(familyChildrenProvider).asData?.value ?? const <Member>[];
    final names = {for (final c in children) c.id: c.displayName};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trocas por dinheiro'),
        actions: [
          IconButton(
            tooltip: 'Valor do ponto',
            icon: const Icon(Icons.tune),
            onPressed: () => _editRate(context, ref, rate),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.savings_outlined),
            title: Text('100 pontos = ${formatBrlCents((rate * 100).round())}'),
            subtitle: const Text('Toque para mudar a cotação'),
            onTap: () => _editRate(context, ref, rate),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => pullRefresh(
                ref,
                invalidate: (r) {
                  r.invalidate(pendingCashOutsProvider);
                  r.invalidate(familyChildrenProvider);
                },
              ),
              child: pending.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Center(child: Text('Erro ao carregar')),
                data: (list) => list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          EmptyHint(
                            icon: Icons.payments_outlined,
                            message: 'Nenhum pedido de troca no momento.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _RequestCard(
                          cashOut: list[i],
                          childName: names[list[i].memberId] ?? 'Criança',
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editRate(
      BuildContext context, WidgetRef ref, double currentCents) async {
    final per100 = (currentCents * 100).round();
    final controller = TextEditingController(
      text: '${per100 ~/ 100},${(per100 % 100).toString().padLeft(2, '0')}',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valor de 100 pontos'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: 'R\$ ',
            helperText: 'Ex.: 1,60 → cada ponto vale R\$ 0,016',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final reais =
                  double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
              Navigator.pop(ctx, reais <= 0 ? null : reais);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (value != null) {
      // reais por 100 pontos -> centavos por ponto
      await ref
          .read(familyControllerProvider.notifier)
          .setPointValueCents(value);
    }
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.cashOut, required this.childName});

  final CashOut cashOut;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final busy = ref.watch(cashOutControllerProvider).isLoading;
    final controller = ref.read(cashOutControllerProvider.notifier);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$childName · ${cashOut.amountLabel}',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${cashOut.points} pontos',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (cashOut.isRequested)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _reject(context, controller),
                    child: const Text('Recusar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: busy ? null : () => controller.approve(cashOut.id),
                    child: const Text('Aprovar'),
                  ),
                ],
              )
            else if (cashOut.isApproved)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: busy ? null : () => controller.markPaid(cashOut.id),
                  child: const Text('Marcar pago'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context, CashOutController controller) async {
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recusar pedido'),
        content: TextField(
          controller: noteController,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Recusar')),
        ],
      ),
    );
    if (ok ?? false) {
      await controller.reject(cashOut.id, note: noteController.text);
    }
  }
}
