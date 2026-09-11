import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/empty_hint.dart';
import '../../../common/pull_refresh.dart';
import '../../../data/models/investment_request.dart';
import '../../../data/models/member.dart';
import '../../family/application/family_providers.dart';
import '../application/investment_providers.dart';

/// Fila do responsável: pedidos de aporte/resgate da poupança para aprovar ou
/// recusar, e a configuração de rendimento/carência.
class InvestmentRequestsScreen extends ConsumerWidget {
  const InvestmentRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(investmentControllerProvider, (_, next) {
      final error = next.error;
      if (error == null || next.isLoading) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error is InvestmentException
              ? error.message
              : 'Não foi possível concluir.'),
        ));
    });

    final pending = ref.watch(pendingInvestmentRequestsProvider);
    final cfg = ref.watch(investmentConfigProvider);
    final children =
        ref.watch(familyChildrenProvider).asData?.value ?? const <Member>[];
    final names = {for (final c in children) c.id: c.displayName};

    return Scaffold(
      appBar: AppBar(title: const Text('Poupança')),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.trending_up),
            title: Text('${_fmtPct(cfg.weeklyRatePct)}% por semana · '
                'carência de ${cfg.graceDays} dias'),
            subtitle: const Text('Toque para mudar'),
            onTap: () => _editConfig(context, ref, cfg),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => pullRefresh(
                ref,
                invalidate: (r) {
                  r.invalidate(pendingInvestmentRequestsProvider);
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
                            icon: Icons.trending_up,
                            message: 'Nenhum pedido de poupança no momento.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _RequestCard(
                          request: list[i],
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

  Future<void> _editConfig(
    BuildContext context,
    WidgetRef ref,
    ({double weeklyRatePct, int graceDays}) cfg,
  ) async {
    final rateController =
        TextEditingController(text: _fmtPct(cfg.weeklyRatePct));
    final graceController =
        TextEditingController(text: cfg.graceDays.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configuração da poupança'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rateController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Rendimento por semana',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: graceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Carência',
                suffixText: 'dias',
                helperText: 'Rendimento cheio só depois desse prazo',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (saved != true) return;
    final rate = double.tryParse(rateController.text.replaceAll(',', '.'));
    final grace = int.tryParse(graceController.text.trim());
    await ref.read(familyControllerProvider.notifier).setInvestmentConfig(
          weeklyRatePct: (rate != null && rate > 0) ? rate : null,
          graceDays: (grace != null && grace >= 0) ? grace : null,
        );
  }
}

String _fmtPct(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.childName});

  final InvestmentRequest request;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final busy = ref.watch(investmentControllerProvider).isLoading;
    final controller = ref.read(investmentControllerProvider.notifier);
    final what = request.isDeposit
        ? 'quer investir ${request.points} pontos'
        : 'quer resgatar a poupança';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$childName $what', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : () => _reject(context, controller),
                  child: const Text('Recusar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : () => controller.approve(request.id),
                  child: const Text('Aprovar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(
      BuildContext context, InvestmentController controller) async {
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
      await controller.reject(request.id, note: noteController.text);
    }
  }
}
