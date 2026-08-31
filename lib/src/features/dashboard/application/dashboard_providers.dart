import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/ledger_entry.dart';
import '../../../data/models/reward.dart';
import '../../family/application/family_providers.dart';
import '../../points/application/points_providers.dart';
import '../../rewards/application/reward_providers.dart';

/// Meia-noite local de hoje.
DateTime _todayLocal() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Ledger da família nos últimos [days] dias.
final _familyLedgerProvider =
    StreamProvider.family<List<LedgerEntry>, int>((ref, days) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  final since = _todayLocal().subtract(Duration(days: days - 1));
  return ref.watch(ledgerRepositoryProvider).watchFamily(family.id, since: since);
});

/// Pontos ganhos por uma criança nos últimos 7 dias (só créditos).
final weekPointsProvider = Provider.family<int, String>((ref, memberId) {
  final entries = ref.watch(_familyLedgerProvider(7)).asData?.value ?? const [];
  return entries
      .where((e) => e.memberId == memberId && e.points > 0)
      .fold<int>(0, (sum, e) => sum + e.points);
});

class DayEarnings {
  const DayEarnings({required this.date, required this.byChild});

  final DateTime date;

  /// memberId -> pontos ganhos (créditos) no dia.
  final Map<String, int> byChild;

  int get total => byChild.values.fold(0, (a, b) => a + b);
}

/// Série de pontos ganhos por dia (últimos 14), por criança — para o gráfico.
final dailyEarningsProvider = Provider<List<DayEarnings>>((ref) {
  const days = 14;
  final entries = ref.watch(_familyLedgerProvider(days)).asData?.value ?? const [];
  final today = _todayLocal();

  final buckets = <DateTime, Map<String, int>>{};
  for (var i = 0; i < days; i++) {
    buckets[today.subtract(Duration(days: days - 1 - i))] = {};
  }

  for (final e in entries) {
    if (e.points <= 0 || e.createdAt == null) continue;
    final d = DateTime(e.createdAt!.year, e.createdAt!.month, e.createdAt!.day);
    final bucket = buckets[d];
    if (bucket == null) continue;
    bucket[e.memberId] = (bucket[e.memberId] ?? 0) + e.points;
  }

  return [
    for (final entry in buckets.entries)
      DayEarnings(date: entry.key, byChild: entry.value),
  ];
});

/// A recompensa ativa mais barata que a criança ainda não consegue pagar.
final nextRewardProvider = Provider.family<({Reward reward, int missing})?, String>(
  (ref, memberId) {
    final balance = ref.watch(childBalanceProvider(memberId)).asData?.value ?? 0;
    final rewards = ref.watch(activeRewardsProvider).asData?.value ?? const [];
    final upcoming = rewards.where((r) => r.inStock && r.cost > balance).toList()
      ..sort((a, b) => a.cost.compareTo(b.cost));
    if (upcoming.isEmpty) return null;
    final r = upcoming.first;
    return (reward: r, missing: r.cost - balance);
  },
);
