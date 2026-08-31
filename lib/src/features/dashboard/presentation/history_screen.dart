import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/ledger_entry.dart';
import '../../../data/models/member.dart';
import '../../family/application/family_providers.dart';

enum _Period {
  week(7, 'Últimos 7 dias'),
  month(30, 'Últimos 30 dias'),
  quarter(90, 'Últimos 90 dias');

  const _Period(this.days, this.label);
  final int days;
  final String label;
}

class _Filter {
  const _Filter({this.childId, this.period = _Period.month});
  final String? childId;
  final _Period period;

  _Filter copyWith({Object? childId = _keep, _Period? period}) => _Filter(
        childId: childId == _keep ? this.childId : childId as String?,
        period: period ?? this.period,
      );

  static const _keep = Object();
}

class _FilterNotifier extends Notifier<_Filter> {
  @override
  _Filter build() => const _Filter();

  void setChild(String? id) => state = state.copyWith(childId: id);
  void setPeriod(_Period p) => state = state.copyWith(period: p);
}

final _historyFilterProvider =
    NotifierProvider<_FilterNotifier, _Filter>(_FilterNotifier.new);

final _historyProvider = StreamProvider<List<LedgerEntry>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  final filter = ref.watch(_historyFilterProvider);
  final since = DateTime.now().subtract(Duration(days: filter.period.days));
  return ref
      .watch(ledgerRepositoryProvider)
      .watchFamily(family.id, since: since)
      .map((all) => filter.childId == null
          ? all
          : all.where((e) => e.memberId == filter.childId).toList());
});

/// Linha do tempo de pontos ganhos, resgatados e ajustados, com filtros.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(familyChildrenProvider).asData?.value ?? const <Member>[];
    final names = {for (final c in children) c.id: c.displayName};
    final filter = ref.watch(_historyFilterProvider);
    final entries = ref.watch(_historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: filter.childId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Criança', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      for (final c in children)
                        DropdownMenuItem(value: c.id, child: Text(c.displayName)),
                    ],
                    onChanged: (v) =>
                        ref.read(_historyFilterProvider.notifier).setChild(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<_Period>(
                    initialValue: filter.period,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Período', isDense: true),
                    items: [
                      for (final p in _Period.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (v) => ref
                        .read(_historyFilterProvider.notifier)
                        .setPeriod(v ?? _Period.month),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('Erro ao carregar')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('Nada no período.'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => _EntryTile(
                        entry: list[i],
                        childName: names[list[i].memberId] ?? 'Criança removida',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.childName});
  final LedgerEntry entry;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = entry.points > 0;
    final (icon, label) = switch (entry.type) {
      LedgerEntryType.earn => (Icons.check_circle_outline, 'Tarefa aprovada'),
      LedgerEntryType.redeem => (Icons.card_giftcard, 'Recompensa resgatada'),
      LedgerEntryType.adjustment => (Icons.tune, 'Ajuste manual'),
    };
    final date = entry.createdAt;

    return ListTile(
      leading: Icon(icon),
      title: Text('$label · $childName'),
      subtitle: date == null
          ? null
          : Text('${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}'),
      trailing: Text(
        '${positive ? '+' : ''}${entry.points}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: positive ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
      ),
    );
  }
}
