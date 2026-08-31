import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/ledger_entry.dart';
import '../../family/application/family_providers.dart';

/// Saldo de pontos de uma criança (soma do ledger). `0` sem família.
final childBalanceProvider = StreamProvider.family<int, String>((ref, memberId) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(0);
  return ref.watch(ledgerRepositoryProvider).watchBalance(family.id, memberId);
});

/// Extrato de uma criança (mais recente primeiro).
final childLedgerProvider =
    StreamProvider.family<List<LedgerEntry>, String>((ref, memberId) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(ledgerRepositoryProvider).watchForMember(family.id, memberId);
});
