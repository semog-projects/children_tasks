import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/empty_hint.dart';
import '../../../common/pull_refresh.dart';
import '../../../common/spacing.dart';
import '../../../common/stat_card.dart';
import '../../../common/sync/sync_providers.dart';
import '../../../data/models/cash_out.dart';
import '../../../data/models/member.dart';
import '../../child/application/child_providers.dart';
import '../../family/application/family_providers.dart';
import '../../points/application/points_providers.dart';
import '../application/cashout_providers.dart';
import '../domain/cash_out_math.dart';

/// Câmbio de pontos por dinheiro real (issue #66). Aberta pela própria criança
/// (`childMode: true`) ou pelo responsável para uma criança (`childMode: false`).
class CashOutScreen extends ConsumerStatefulWidget {
  const CashOutScreen({
    super.key,
    required this.memberId,
    required this.childName,
    this.childMode = false,
  });

  final String memberId;
  final String childName;
  final bool childMode;

  @override
  ConsumerState<CashOutScreen> createState() => _CashOutScreenState();
}

/// Reformata o que a criança digita como moeda: cada dígito entra pelos
/// centavos (`2` → R$ 0,02, `200` → R$ 2,00), com o cursor sempre no fim.
class _BrlCentsFormatter extends TextInputFormatter {
  const _BrlCentsFormatter();

  static const int _maxCents = 9999999; // R$ 99.999,99

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final cents = centsFromText(newValue.text).clamp(0, _maxCents).toInt();
    if (cents == 0) return const TextEditingValue();
    final text = formatBrlCents(cents);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _CashOutScreenState extends ConsumerState<CashOutScreen> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _wantCents => centsFromText(_amount.text);

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

  Future<void> _request(int points) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(cashOutControllerProvider.notifier)
        .request(child: _member(), points: points);
    if (!mounted) return;
    final error = ref.read(cashOutControllerProvider).error;
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error is CashOutException
              ? error.message
              : 'Não foi possível pedir a troca.'),
        ));
      return;
    }
    _amount.clear();
    setState(() {});
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
          const SnackBar(content: Text('Pedido enviado! Aguarde a aprovação.')));
  }

  @override
  Widget build(BuildContext context) {
    final rate = ref.watch(pointValueCentsProvider);
    final balance = (widget.childMode
            ? ref.watch(myChildBalanceProvider)
            : ref.watch(childBalanceProvider(widget.memberId)))
        .asData
        ?.value ??
        0;
    final history = widget.childMode
        ? ref.watch(myCashOutsProvider)
        : ref.watch(childCashOutsProvider(widget.memberId));
    final busy = ref.watch(cashOutControllerProvider).isLoading;
    final online = ref.watch(isOnlineProvider);
    final theme = Theme.of(context);

    final points = pointsForCents(_wantCents, rate);
    final actualCents = centsForPoints(points, rate);
    final canRequest = online &&
        !busy &&
        points > 0 &&
        points <= balance;

    return Scaffold(
      appBar: AppBar(title: Text('Trocar por dinheiro — ${widget.childName}')),
      body: RefreshIndicator(
        onRefresh: () => pullRefresh(
          ref,
          invalidate: (r) {
            if (widget.childMode) {
              r.invalidate(myChildBalanceProvider);
              r.invalidate(myCashOutsProvider);
            } else {
              r.invalidate(childBalanceProvider);
              r.invalidate(childCashOutsProvider);
            }
          },
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
          children: [
            StatCard(
              icon: Icons.savings_rounded,
              value: '$balance pontos',
              label: 'Vale até ${formatBrlCents(centsForPoints(balance, rate))}',
            ),
            const Gap.md(),
            Text('Quanto você quer trocar?', style: theme.textTheme.titleMedium),
            const Gap.sm(),
            TextField(
              controller: _amount,
              enabled: !busy,
              autofocus: false,
              keyboardType: TextInputType.number,
              inputFormatters: const [_BrlCentsFormatter()],
              onChanged: (_) => setState(() {}),
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(
                labelText: 'Valor em reais',
                hintText: 'R\$ 0,00',
                helperText: 'Cada dígito entra pelos centavos: 200 = R\$ 2,00',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap.sm(),
            if (_wantCents > 0)
              _Conversion(
                points: points,
                actualCents: actualCents,
                wantCents: _wantCents,
                enoughBalance: points <= balance,
              ),
            if (!online) ...[
              const Gap.sm(),
              Text(
                'A troca precisa de internet.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const Gap.md(),
            FilledButton.icon(
              onPressed: canRequest ? () => _request(points) : null,
              icon: const Icon(Icons.send_rounded),
              label: Text(points > 0
                  ? 'Pedir troca de $points pontos'
                  : 'Pedir troca'),
            ),
            const Divider(height: AppSpacing.xl),
            Text('Meus pedidos', style: theme.textTheme.titleMedium),
            const Gap.sm(),
            history.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) => list.isEmpty
                  ? const EmptyHint(
                      icon: Icons.payments_outlined,
                      message: 'Nenhuma troca ainda.',
                    )
                  : Column(
                      children: [
                        for (final c in list)
                          _CashOutTile(
                            cashOut: c,
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

class _Conversion extends StatelessWidget {
  const _Conversion({
    required this.points,
    required this.actualCents,
    required this.wantCents,
    required this.enoughBalance,
  });

  final int points;
  final int actualCents;
  final int wantCents;
  final bool enoughBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points <= 0) {
      return Text('Valor muito baixo.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.error));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custa $points pontos',
          style: theme.textTheme.titleMedium?.copyWith(
            color: enoughBalance
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (actualCents != wantCents)
          Text('Ajustado para ${formatBrlCents(actualCents)}',
              style: theme.textTheme.bodySmall),
        if (!enoughBalance)
          Text('Saldo insuficiente.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error)),
      ],
    );
  }
}

class _CashOutTile extends ConsumerWidget {
  const _CashOutTile({
    required this.cashOut,
    required this.childMode,
    required this.busy,
  });

  final CashOut cashOut;
  final bool childMode;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, label) = switch (cashOut.status) {
      CashOutStatus.requested => (Icons.hourglass_top, 'Aguardando aprovação'),
      CashOutStatus.approved => (Icons.check_circle_outline, 'Aprovado — a pagar'),
      CashOutStatus.paid => (Icons.paid, 'Pago'),
      CashOutStatus.rejected => (Icons.cancel_outlined, 'Recusado'),
      CashOutStatus.canceled => (Icons.block, 'Cancelado'),
    };
    return ListTile(
      leading: Icon(icon),
      title: Text('${cashOut.amountLabel} · ${cashOut.points} pts'),
      subtitle: Text([
        label,
        if (cashOut.status == CashOutStatus.rejected && cashOut.note != null)
          cashOut.note!,
      ].join(' · ')),
      trailing: (childMode && cashOut.isRequested)
          ? TextButton(
              onPressed: busy
                  ? null
                  : () => ref
                      .read(cashOutControllerProvider.notifier)
                      .cancel(cashOut.id),
              child: const Text('Cancelar'),
            )
          : null,
    );
  }
}
