import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/ledger_entry.dart';
import '../../../data/models/member.dart';
import '../../auth/application/auth_providers.dart';
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

/// Erro de negócio ao ajustar pontos, com mensagem pt-BR pronta pra SnackBar.
class PointsAdjustmentException implements Exception {
  const PointsAdjustmentException(this.message);
  final String message;
}

/// Ajuste manual de saldo pelo responsável: descontar ou adicionar pontos
/// sempre com um motivo. Grava um lançamento `adjustment`/`manual` no ledger.
class PointsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// [points] com sinal (negativo desconta, positivo credita); [reason] é
  /// obrigatório e vira o `note` do lançamento.
  Future<void> adjust({
    required Member child,
    required int points,
    required String reason,
  }) async {
    final family = ref.read(currentFamilyProvider).asData?.value;
    final uid = ref.read(currentUserProvider)?.uid;
    final note = reason.trim();
    if (family == null || uid == null) {
      state = AsyncError(
        const PointsAdjustmentException('Sessão sem família ativa.'),
        StackTrace.current,
      );
      return;
    }
    if (points == 0 || note.isEmpty) {
      state = AsyncError(
        const PointsAdjustmentException('Informe um valor e um motivo.'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ledgerRepositoryProvider).addAdjustment(
            family.id,
            memberId: child.id,
            memberUid: child.linkedUid,
            points: points,
            createdByUid: uid,
            note: note,
          ),
    );
  }
}

final pointsControllerProvider =
    AsyncNotifierProvider<PointsController, void>(PointsController.new);
