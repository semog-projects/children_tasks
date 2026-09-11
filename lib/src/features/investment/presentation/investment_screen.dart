import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/empty_hint.dart';
import '../../../common/pull_refresh.dart';
import '../../../common/spacing.dart';
import '../../../common/stat_card.dart';
import '../../../common/sync/sync_providers.dart';
import '../../../data/models/investment_lot.dart';
import '../../../data/models/investment_request.dart';
import '../../../data/models/member.dart';
import '../../child/application/child_providers.dart';
import '../../family/application/family_providers.dart';
import '../../points/application/points_providers.dart';
import '../application/investment_providers.dart';
import '../domain/investment_math.dart';

/// Poupança da criança (issue #73): investe pontos que rendem juros compostos.
/// Aberta pela própria criança (`childMode: true`) ou pelo responsável.
class InvestmentScreen extends ConsumerStatefulWidget {
  const InvestmentScreen({
    super.key,
    required this.memberId,
    required this.childName,
    this.childMode = false,
  });

  final String memberId;
  final String childName;
  final bool childMode;

  @override
  ConsumerState<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends ConsumerState<InvestmentScreen> {
  Member _member() {
    final children =
        ref.read(familyChildrenProvider).asData?.value ?? const <Member>[];
    return children.firstWhere(
      (c) => c.id == widget.memberId,
      orElse: () => Member(
        id: widget.memberId,
        type: MemberType.child,
        displayName: widget.childName,
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _afterRequest(String ok) async {
    if (!mounted) return;
    final error = ref.read(investmentControllerProvider).error;
    if (error != null) {
      _snack(error is InvestmentException
          ? error.message
          : 'Não foi possível concluir.');
      return;
    }
    _snack(ok);
  }

  Future<void> _investMore(int spendable) async {
    final points = await showDialog<int>(
      context: context,
      builder: (_) => _AmountDialog(max: spendable),
    );
    if (points == null) return;
    await ref
        .read(investmentControllerProvider.notifier)
        .requestDeposit(child: _member(), points: points);
    await _afterRequest('Pedido de investimento enviado!');
  }

  Future<void> _withdrawAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resgatar tudo?'),
        content: const Text(
          'Toda a poupança (o que você investiu + o que rendeu) volta pro seu '
          'saldo, depois que o responsável aprovar.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Resgatar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(investmentControllerProvider.notifier)
        .requestWithdraw(child: _member());
    await _afterRequest('Pedido de resgate enviado!');
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(investmentConfigProvider);
    final spendable = (widget.childMode
            ? ref.watch(myChildBalanceProvider)
            : ref.watch(childBalanceProvider(widget.memberId)))
        .asData
        ?.value ??
        0;
    final lotsAsync = widget.childMode
        ? ref.watch(myInvestmentLotsProvider)
        : ref.watch(childInvestmentLotsProvider(widget.memberId));
    final requests = widget.childMode
        ? ref.watch(myInvestmentRequestsProvider)
        : ref.watch(childInvestmentRequestsProvider(widget.memberId));
    final busy = ref.watch(investmentControllerProvider).isLoading;
    final online = ref.watch(isOnlineProvider);
    final theme = Theme.of(context);
    final lots = lotsAsync.asData?.value ?? const <InvestmentLot>[];

    final now = DateTime.now();
    final lotValues = [
      for (final l in lots)
        (points: l.points, since: l.createdAt ?? now),
    ];
    final principal = principalOf(lotValues);
    final valueNow = payoutNow(lotValues, now, cfg.weeklyRatePct, cfg.graceDays);
    final yieldNow = valueNow - principal;
    final hasLots = principal > 0;

    DateTime? nextFullYield;
    for (final l in lotValues) {
      final full = l.since.add(Duration(days: cfg.graceDays));
      if (full.isAfter(now) && (nextFullYield == null || full.isBefore(nextFullYield))) {
        nextFullYield = full;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Poupança — ${widget.childName}')),
      body: RefreshIndicator(
        onRefresh: () => pullRefresh(
          ref,
          invalidate: (r) {
            if (widget.childMode) {
              r.invalidate(myChildBalanceProvider);
              r.invalidate(myInvestmentLotsProvider);
              r.invalidate(myInvestmentRequestsProvider);
            } else {
              r.invalidate(childBalanceProvider);
              r.invalidate(childInvestmentLotsProvider);
              r.invalidate(childInvestmentRequestsProvider);
            }
          },
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
          children: [
            StatCard(
              icon: Icons.trending_up_rounded,
              value: '$principal pontos',
              label: 'Investido · rende '
                  '${_fmtPct(cfg.weeklyRatePct)}% por semana',
            ),
            if (hasLots) ...[
              const Gap.sm(),
              Card(
                child: Padding(
                  padding: AppSpacing.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vale agora', style: theme.textTheme.labelMedium),
                      const Gap.xs(),
                      Text('$valueNow pontos',
                          style: theme.textTheme.headlineSmall),
                      if (yieldNow > 0)
                        Text('+$yieldNow de rendimento',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            )),
                      if (nextFullYield != null) ...[
                        const Gap.xs(),
                        Text(
                          'Resgatar agora paga metade do rendimento dos aportes '
                          'recentes. Rendimento cheio a partir de '
                          '${_fmtDate(nextFullYield)}.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const Gap.md(),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: (online && !busy && spendable > 0)
                        ? () => _investMore(spendable)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Investir mais'),
                  ),
                ),
                const Gap.sm(),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (online && !busy && hasLots) ? _withdrawAll : null,
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('Resgatar tudo'),
                  ),
                ),
              ],
            ),
            if (!online) ...[
              const Gap.sm(),
              Text('A poupança precisa de internet.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            const Gap.lg(),
            _Projection(principal: principal, ratePct: cfg.weeklyRatePct),
            const Gap.lg(),
            _Lesson(ratePct: cfg.weeklyRatePct, graceDays: cfg.graceDays),
            const Divider(height: AppSpacing.xl),
            Text('Meus pedidos', style: theme.textTheme.titleMedium),
            const Gap.sm(),
            requests.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) => list.isEmpty
                  ? const EmptyHint(
                      icon: Icons.history_rounded,
                      message: 'Nenhum pedido ainda.',
                    )
                  : Column(
                      children: [
                        for (final r in list)
                          _RequestTile(
                            request: r,
                            childMode: widget.childMode,
                            busy: busy,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtPct(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.max});
  final int max;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n <= 0) {
      setState(() => _error = 'Informe um número maior que zero.');
      return;
    }
    if (n > widget.max) {
      setState(() => _error = 'Você só tem ${widget.max} pontos pra investir.');
      return;
    }
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Investir pontos'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Quantos pontos',
          helperText: 'Você tem ${widget.max} disponíveis',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Pedir')),
      ],
    );
  }
}

class _Projection extends StatelessWidget {
  const _Projection({required this.principal, required this.ratePct});
  final int principal;
  final double ratePct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = principal > 0 ? principal : 100;
    final rows = <(String, int)>[
      ('Em 1 semana', projectedTotal(base, 1, ratePct)),
      ('Em 1 mês', projectedTotal(base, 4.345, ratePct)),
      ('Em 3 meses', projectedTotal(base, 13.04, ratePct)),
      ('Em 1 ano', projectedTotal(base, 52.14, ratePct)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          principal > 0
              ? 'Se você deixar seus $principal pontos parados:'
              : 'Se você investir 100 pontos e deixar parados:',
          style: theme.textTheme.titleMedium,
        ),
        const Gap.sm(),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                Text('$value pts',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    )),
              ],
            ),
          ),
      ],
    );
  }
}

class _Lesson extends StatelessWidget {
  const _Lesson({required this.ratePct, required this.graceDays});
  final double ratePct;
  final int graceDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: theme.colorScheme.onSecondaryContainer),
                const Gap.sm(),
                Text('Como a poupança funciona',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    )),
              ],
            ),
            const Gap.sm(),
            Text(
              'Cada semana seus pontos rendem ${_fmtPct(ratePct)}%. Na semana '
              'seguinte, o rendimento também rende — isso se chama juros '
              'compostos: quanto mais tempo você espera, mais rápido cresce.\n\n'
              'Se resgatar antes de $graceDays dias, você recebe só metade do '
              'que rendeu. Paciência vale pontos!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({
    required this.request,
    required this.childMode,
    required this.busy,
  });

  final InvestmentRequest request;
  final bool childMode;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kindLabel = request.isDeposit
        ? 'Investir ${request.points} pts'
        : 'Resgatar tudo';
    final (icon, statusLabel) = switch (request.status) {
      InvestmentRequestStatus.requested => (
          Icons.hourglass_top,
          'Aguardando aprovação'
        ),
      InvestmentRequestStatus.approved => request.isWithdraw
          ? (Icons.check_circle_outline,
              'Resgatado: ${request.payoutPoints ?? 0} pts'
              '${(request.yieldPoints ?? 0) > 0 ? ' (+${request.yieldPoints} de rendimento)' : ''}')
          : (Icons.check_circle_outline, 'Investido'),
      InvestmentRequestStatus.rejected => (Icons.cancel_outlined, 'Recusado'),
      InvestmentRequestStatus.canceled => (Icons.block, 'Cancelado'),
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(kindLabel),
      subtitle: Text([
        statusLabel,
        if (request.status == InvestmentRequestStatus.rejected &&
            request.note != null)
          request.note!,
      ].join(' · ')),
      trailing: (childMode && request.isRequested)
          ? TextButton(
              onPressed: busy
                  ? null
                  : () => ref
                      .read(investmentControllerProvider.notifier)
                      .cancel(request.id),
              child: const Text('Cancelar'),
            )
          : null,
    );
  }
}
